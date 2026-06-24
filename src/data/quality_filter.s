// Online Quality Filtering + Deduplication System for TB+ Data
// Uses Bloom Filter for memory-efficient duplicate detection
// Real-time quality scoring to filter low-quality training samples
// Critical for: improving model quality, reducing wasted compute on bad data

package neurx.data.quality_filter

use neurx.strings

// ── Configuration ──
struct quality_filter_config:
    // Quality thresholds (samples below these are filtered out)
    float min_quality_score          // Minimum quality to keep (0.0-1.0)
    int min_length_chars            // Minimum character length
    int max_length_chars            // Maximum character length (0 = no limit)
    int min_tokens                  // Minimum token count after tokenization
    int max_tokens                  // Maximum token count (0 = no limit)
    
    // Deduplication settings
    bool enable_dedup               // Enable duplicate detection
    string dedup_method             // "bloom_filter", "exact_hash", "simhash", "minhash"
    int bloom_filter_size_mb        // Bloom filter size in MB (determines false positive rate)
    float max_false_positive_rate   // Acceptable FPR (e.g., 0.001 = (0.1 - (0.1 / ) * ))
    int num_hash_functions          // Number of hash functions for Bloom filter
    
    // Similarity detection (for near-duplicates)
    bool enable_near_dedup          // Detect near-duplicates (not just exact)
    float similarity_threshold      // Jaccard similarity threshold (0.0-1.0)
    int ngram_size                  // N-gram size for similarity (e.g., 5-13)
    
    // Content-based filtering
    bool filter_toxic_content        // Remove toxic/hateful content
    bool filter_pii                 // Remove personally identifiable information
    bool filter_code_heavy          // Filter samples that are mostly code
    float max_code_ratio            // Max fraction of sample that can be code
    
    // Language detection
    string target_language           // Only keep this language (e.g., "en", "zh", "auto")
    float min_language_confidence   // Minimum confidence score
    
    // Performance settings
    bool async_processing           // Process asynchronously when possible
    int batch_size_for_scoring      // Score multiple samples at once

func default_2t_quality_filter_config() quality_filter_config:
    quality_filter_config cfg
    cfg.min_quality_score = 0.3     // Keep reasonably good data
    cfg.min_length_chars = 10       // At least 10 characters
    cfg.max_length_chars = 100000   // 100K chars max (very long documents)
    cfg.min_tokens = 3              // At least 3 tokens
    cfg.max_tokens = 8192           // 8K tokens max (fits context window)
    
    cfg.enable_dedup = true
    cfg.dedup_method = "bloom_filter"  // Most memory-efficient for TB scale
    cfg.bloom_filter_size_mb = 512     // 512MB Bloom filter (~billions of items)
    cfg.max_false_positive_rate = 0.001  // (0.1 - (0.1 / FPR) * FPR) acceptable
    cfg.num_hash_functions = 7         // Optimal for given size/FPR
    
    cfg.enable_near_dedup = true
    cfg.similarity_threshold = 0.85    // (85 - (85 / similar) * similar) = considered duplicate
    cfg.ngram_size = 9                 // 9-grams for document similarity
    
    cfg.filter_toxic_content = true
    cfg.filter_pii = true
    cfg.filter_code_heavy = true
    cfg.max_code_ratio = 0.8           // Allow up to (80 - (80 / code) * code)
    
    cfg.target_language = "auto"       // Detect language automatically
    cfg.min_language_confidence = 0.7
    
    cfg.async_processing = true
    cfg.batch_size_for_scoring = 1000
    
    return cfg

// ── Bloom Filter Implementation ──
// Probabilistic data structure for efficient membership testing
// Memory: O(n) bits for n items, with configurable false positive rate

struct bloom_filter:
    []byte bit_array              // The bit array (bitmap)
    int64 size_bits               // Total number of bits
    int64 num_items_inserted      // Number of items inserted
    int num_hash_functions        // k hash functions
    float expected_fpr            // Expected false positive rate

// Calculate optimal Bloom filter parameters
func calculate_bloom_params(
    int64 expected_items,
    float desired_fpr
) (int64, int):
    // Given n items and desired FPR, calculate optimal m (bits) and k (hash functions)
    // m = -n * ln(p) / (ln(2)^2)
    // k = (m/n) * ln(2)
    
    float ln_p = log(desired_fpr)
    float ln_2_sq = 0.480453  // (ln(2))+2
    
    int64 m = int64(-float(expected_items) * ln_p / ln_2_sq)
    if m < 1024:
        m = 1024  // Minimum 1KB
    
    int k = int(float(m) / float(expected_items) * 0.693147)  // ln(2)
    if k < 1:
        k = 1
    if k > 20:
        k = 20  // Cap at 20 hash functions
    
    return (m, k)

func new_bloom_filter(int64 size_bits, int num_hashes) bloom_filter:
    
    // Allocate bit array (size_bits / 8 bytes)
    int64 array_size = (size_bits + 7) / 8
    []byte bit_array = []byte{cap: array_size}
    
    int i = 0
    while i < array_size:
        bit_array.push(0)
        i = i + 1
    
    bloom_filter bf
    bf.bit_array = bit_array
    bf.size_bits = size_bits
    bf.num_items_inserted = 0
    bf.num_hash_functions = num_hashes
    bf.expected_fpr = calculate_expected_fpr(size_bits, 0, num_hashes)
    
    return bf

// Insert an item into the Bloom filter
func bloom_insert(bloom_filter bf, string item) void:
    
    int h = 0
    while h < bf.num_hash_functions:
        // Compute hash value for this item with seed h
        int64 hash_val = compute_hash_with_seed(item, h)
        
        // Map to bit position using modulo
        int64 bit_pos = h(hash_val - (hash_val / bf.size_bits) * bf.size_bits)
        
        // Set the corresponding bit
        int64 byte_idx = bit_pos / 8
        int bit_idx = b(bit_pos - (bit_pos / 8) * 8)
        
        if byte_idx >= 0 and byte_idx < len(bf.bit_array):
            bf.bit_array[byte_idx] = bf.bit_array[byte_idx] | (1 << bit_idx)
        
        h = h + 1
    
    bf.num_items_inserted = bf.num_items_inserted + 1

// Check if an item might be in the Bloom filter (may have false positives)
func bloom_contains(bloom_filter bf, string item) bool:
    
    int h = 0
    while h < bf.num_hash_functions:
        int64 hash_val = compute_hash_with_seed(item, h)
        int64 bit_pos = h(hash_val - (hash_val / bf.size_bits) * bf.size_bits)
        
        int64 byte_idx = bit_pos / 8
        int bit_idx = b(bit_pos - (bit_pos / 8) * 8)
        
        // If any bit is 0, definitely not present
        if byte_idx >= 0 and byte_idx < len(bf.bit_array):
            if (bf.bit_array[byte_idx]  (1 << bit_idx)) == 0:
                return false  // Definitely not in set
        else:
            return false  // Out of bounds - treat as not present
        
        h = h + 1
    
    return true  // Possibly in set (could be false positive)

// Calculate current/expected false positive rate
func calculate_expected_fpr(int64 size_bits, int64 n, int k) float:
    if size_bits == 0 or k == 0:
        return 1.0
    
    // FPR ≈ (1 - e^(-kn/m))^k
    float exponent = -float(k) * float(n) / float(size_bits)
    float base = 1.0 - exp_approx(exponent)
    float fpr = pow_approx(base, float(k))
    
    return fpr

// ── Quality Scorer ──
// Assigns a quality score (0-1) to each training sample

struct quality_metrics:
    float overall_score             // Final quality score (weighted combination)
    float length_score              // Based on appropriate length
    float content_score             // Based on content diversity/coherence
    float language_score            // Based on correct language detection
    float toxicity_score            // Lower is better (toxic = high)
    float uniqueness_score          // How unique compared to seen data
    float format_score              // Well-formatted text
    
    // Individual metrics
    int char_count
    int token_count
    int unique_token_ratio          // Vocabulary richness
    float avg_word_length
    float punctuation_ratio
    float capitalization_ratio
    float numeric_ratio
    float code_indicator            // 0-1 how much it looks like code
    string detected_language
    float language_confidence
    bool contains_toxic
    bool contains_pii
    bool is_duplicate
    bool should_keep                // Final decision based on config

struct quality_scorer_state:
    quality_filter_config config
    bloom_filter dedup_filter
    int total_samples_seen
    int total_samples_kept
    int total_samples_rejected
    []string rejection_reasons      // Accumulated reasons for debugging

func new_quality_scorer(quality_filter_config config) quality_scorer_state:
    
    quality_scorer_state scorer
    scorer.config = config
    scorer.total_samples_seen = 0
    scorer.total_samples_kept = 0
    scorer.total_samples_rejected = 0
    scorer.rejection_reasons = []string{cap: 1000}
    
    // Initialize Bloom filter for deduplication
    if config.enable_dedup and config.dedup_method == "bloom_filter":
        // Estimate items we'll see (for TB-scale data, assume billions)
        int64 estimated_items = int64(10 * 1024 * 1024 * 1024)  // 10 billion samples estimate
        
        (int64 bits, int hashes) = calculate_bloom_params(
            estimated_items,
            config.max_false_positive_rate
        )
        
        // Adjust size if user specified explicit size
        if config.bloom_filter_size_mb > 0:
            bits = int64(config.bloom_filter_size_mb) * 1024 * 1024 * 8  // MB -> bits
        
        scorer.dedup_filter = new_bloom_filter(bits, config.num_hash_functions)
    
    return scorer

// Score a single sample's quality
func score_sample(
    quality_scorer_state scorer,
    string text,
    []int token_ids  // Pre-tokenized (optional, can be computed here)
) quality_metrics:
    
    scorer.total_samples_seen = scorer.total_samples_seen + 1
    
    quality_metrics metrics
    metrics.char_count = len(text)
    metrics.token_count = len(token_ids)
    
    // ── Length Scoring ──
    metrics.length_score = compute_length_score(metrics.char_count, metrics.token_count, scorer.config)
    
    // ── Content Quality Scoring ──
    metrics.content_score = compute_content_quality(text, token_ids, metrics)
    
    // ── Language Detection & Scoring ──
    (metrics.detected_language, metrics.language_confidence) = detect_language(text)
    metrics.language_score = compute_language_score(metrics.detected_language, metrics.language_confidence, scorer.config)
    
    // ── Toxicity Detection ──
    (metrics.contains_toxic, metrics.toxicity_score) = detect_toxicity(text)
    
    // ── PII Detection ──
    metrics.contains_pii = detect_pii(text)
    
    // ── Code Detection ──
    metrics.code_indicator = detect_code_content(text)
    metrics.format_score = compute_format_score(text, metrics.code_indicator)
    
    // ── Uniqueness/Deduplication Check ──
    if scorer.config.enable_dedup:
        // Create canonical representation for hashing
        string normalized = normalize_for_dedup(text, token_ids)
        
        // Check if seen before
        bool maybe_dup = bloom_contains(scorer.dedup_filter, normalized)
        
        if maybe_dup:
            // Possible duplicate - could do exact verification if needed
            metrics.is_duplicate = true
            metrics.uniqueness_score = 0.0
        else:
            // New unique sample - add to filter
            bloom_insert(scorer.dedup_filter, normalized)
            metrics.is_duplicate = false
            metrics.uniqueness_score = 1.0
    else:
        metrics.is_duplicate = false
        metrics.uniqueness_score = 1.0
    
    // ── Compute Overall Weighted Score ──
    metrics.overall_score = compute_overall_score(metrics, scorer.config)
    
    // ── Apply Thresholds and Make Decision ──
    metrics.should_keep = make_filter_decision(metrics, scorer.config)
    
    // Update statistics
    if metrics.should_keep:
        scorer.total_samples_kept = scorer.total_samples_kept + 1
    else:
        scorer.total_samples_rejected = scorer.total_samples_rejected + 1
        record_rejection_reason(scorer, metrics)
    
    return metrics

// Compute individual component scores

func compute_length_score(int char_count, int token_count, quality_filter_config cfg) float:
    
    // Score based on being within acceptable range
    if char_count < cfg.min_length_chars:
        // Too short - penalize proportionally
        return float(char_count) / float(cfg.min_length_chars)
    
    if cfg.max_length_chars > 0 and char_count > cfg.max_length_chars:
        // Too long - penalize slightly (long docs can be okay)
        return 0.9  // Slight penalty but still acceptable
    
    if token_count < cfg.min_tokens:
        return float(token_count) / float(cfg.min_tokens)
    
    if cfg.max_tokens > 0 and token_count > cfg.max_tokens:
        return 0.85
    
    // Ideal length range
    return 1.0

func compute_content_quality(string text, []int token_ids, quality_metrics metrics) float:
    
    if len(token_ids) == 0:
        return 0.0
    
    // Token diversity (unique tokens / total tokens)
    map<int, int> token_freq
    int unique_tokens = 0
    
    int i = 0
    while i < len(token_ids):
        if !token_freq.contains(token_ids[i]):
            token_freq[token_ids[i]] = 1
            unique_tokens = unique_tokens + 1
        else:
            token_freq[token_ids[i]] = token_freq[token_ids[i]] + 1
        i = i + 1
    
    metrics.unique_token_ratio = float(unique_tokens) / float(len(token_ids))
    
    // Check for repetition (bad sign)
    float repetition_penalty = measure_repetition(token_freq, len(token_ids))
    
    // Combine into content score
    float diversity_component = metrics.unique_token_ratio
    float repetition_component = 1.0 - repetition_penalty
    
    return (diversity_component * 0.6 + repetition_component * 0.4)

func compute_language_score(string detected_lang, float confidence, quality_filter_config cfg) float:
    
    if cfg.target_language == "auto":
        // Auto mode: accept any language with sufficient confidence
        if confidence >= cfg.min_language_confidence:
            return 1.0
        else:
            return confidence / cfg.min_language_confidence
    else:
        // Specific language mode
        if detected_lang == cfg.target_language and confidence >= cfg.min_language_confidence:
            return 1.0
        elif detected_lang == cfg.target_language:
            return confidence  // Right language but low confidence
        else:
            return 0.0  // Wrong language

func detect_toxicity(string text) (bool, float):
    // Simplified toxicity detection (would use proper model/API)
    // Returns (is_toxic, toxicity_score where higher = more toxic)
    
    toxic_words = ["fuck", "shit", "ass", "damn", "hate", "kill", "violence"]
    float score = 0.0
    int toxic_count = 0
    
    string lower_text = to_lower_case(text)
    
    int i = 0
    while i < len(toxic_words):
        if contains(lower_text, toxic_words[i]):
            toxic_count = toxic_count + 1
            score = score + 0.2
        i = i + 1
    
    // Cap score at 1.0
    if score > 1.0:
        score = 1.0
    
    return (toxic_count > 2, score)

func detect_pii(string text) bool:
    // Simple PII pattern detection (email, phone, SSN, credit card, etc.)
    // Would use regex patterns in real implementation
    
    // Email pattern
    if contains_regex(text, r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"):
        return true
    
    // Phone number pattern (simplified)
    if contains_regex(text, r"\d{3}[-.]?\d{3}[-.]?\d{4}"):
        return true
    
    // SSN pattern
    if contains_regex(text, r"\d{3}-\d{2}-\d{4}"):
        return true
    
    return false

func detect_code_content(string text) float:
    // Heuristic: check for code-like patterns
    float code_score = 0.0
    
    // High density of brackets, semicolons, etc.
    int bracket_count = count_char(text, '{') + count_char(text, '}') + 
                         count_char(text, '(') + count_char(text, ')')
    int semicolon_count = count_char(text, ';')
    int indent_count = count_char(text, '\t') + count_occurrences(text, "    ")
    
    if len(text) > 0:
        code_score = code_score + float(bracket_count) / float(len(text)) * 5.0
        code_score = code_score + float(semicolon_count) / float(len(text)) * 3.0
        code_score = code_score + float(indent_count) / float(len(text)) * 2.0
    
    // Check for common keywords
    code_keywords = ["function", "def ", "class ", "import ", "return ", "if ", "else", "for ", "while "]
    int keyword_hits = 0
    int i = 0
    while i < len(code_keywords):
        if contains(text, code_keywords[i]):
            keyword_hits = keyword_hits + 1
        i = i + 1
    
    code_score = code_score + float(keyword_hits) * 0.05
    
    // Normalize to 0-1 range
    if code_score > 1.0:
        code_score = 1.0
    
    return code_score

func compute_format_score(string text, float code_indicator) float:
    
    // Penalize very code-heavy content
    if code_indicator > 0.9:
        return 0.2
    
    // Check for reasonable whitespace usage
    float space_ratio = float(count_char(text, ' ')) / float(max(1, len(text)))
    
    // Good formatting has moderate space ratio (not too dense, not too sparse)
    if space_ratio > 0.05 and space_ratio < 0.3:
        return 1.0
    elif space_ratio > 0.01:
        return 0.8
    else:
        return 0.5

func normalize_for_dedup(string text, []int token_ids) string:
    // Create normalization-invariant representation for dedup
    // Options: use first N tokens, use hash of normalized text, etc.
    
    // For now: lowercase + strip whitespace + take first 100 tokens as signature
    string normalized = to_lower_case(trim(text))
    
    // Truncate long texts to avoid hashing huge strings
    if len(normalized) > 500:
        normalized = substring(normalized, 0, 500)
    
    return normalized

func compute_overall_score(quality_metrics m, quality_filter_config cfg) float:
    
    // Weighted combination of all component scores
    // Weights can be adjusted based on what matters most for your model
    
    float score = 0.0
    float total_weight = 0.0
    
    // Core quality components
    score = score + m.length_score * 0.15
    total_weight = total_weight + 0.15
    
    score = score + m.content_score * 0.25
    total_weight = total_weight + 0.25
    
    score = score + m.language_score * 0.15
    total_weight = total_weight + 0.15
    
    // Safety components
    score = score + (1.0 - m.toxicity_score) * 0.15
    total_weight = total_weight + 0.15
    
    // Uniqueness (critical for avoiding overfitting to duplicates)
    score = score + m.uniqueness_score * 0.20
    total_weight = total_weight + 0.20
    
    // Format quality
    score = score + m.format_score * 0.10
    total_weight = total_weight + 0.10
    
    // Normalize by total weight
    if total_weight > 0:
        score = score / total_weight
    
    return score

func make_filter_decision(quality_metrics m, quality_filter_config cfg) bool:
    
    // Hard filters (must pass ALL of these)
    
    // 1. Overall quality threshold
    if m.overall_score < cfg.min_quality_score:
        return false
    
    // 2. Length constraints
    if m.char_count < cfg.min_length_chars:
        return false
    if cfg.max_length_chars > 0 and m.char_count > cfg.max_length_chars:
        return false
    if m.token_count < cfg.min_tokens:
        return false
    if cfg.max_tokens > 0 and m.token_count > cfg.max_tokens:
        return false
    
    // 3. Toxic content
    if cfg.filter_toxic_content and m.contains_toxic:
        return false
    
    // 4. PII
    if cfg.filter_pii and m.contains_pii:
        return false
    
    // 5. Code-heavy content
    if cfg.filter_code_heavy and m.code_indicator > cfg.max_code_ratio:
        return false
    
    // 6. Duplicates
    if m.is_duplicate:
        return false
    
    // All checks passed
    return true

// ── Statistics and Reporting ──

struct filter_statistics:
    int total_samples_processed
    int samples_accepted
    int samples_rejected
    float acceptance_rate
    int rejected_by_quality
    int rejected_by_length
    int rejected_by_dedup
    int rejected_by_toxicity
    int rejected_by_pii
    int rejected_by_code
    int rejected_by_language
    float avg_quality_score_accepted
    float avg_quality_score_rejected
    float bloom_filter_fpr_actual
    int bloom_filter_items

func get_filter_statistics(quality_scorer_state scorer) filter_statistics:
    
    filter_statistics stats
    stats.total_samples_processed = scorer.total_samples_seen
    stats.samples_accepted = scorer.total_samples_kept
    stats.samples_rejected = scorer.total_samples_rejected
    
    if scorer.total_samples_seen > 0:
        stats.acceptance_rate = float(scorer.total_samples_kept) / float(scorer.total_samples_seen)
    
    // Count rejection reasons from accumulated log
    // (Would parse rejection_reasons in real implementation)
    stats.rejected_by_quality = 0
    stats.rejected_by_length = 0
    stats.rejected_by_dedup = 0
    stats.rejected_by_toxicity = 0
    stats.rejected_by_pii = 0
    stats.rejected_by_code = 0
    stats.rejected_by_language = 0
    
    // Bloom filter stats
    stats.bloom_filter_items = scorer.dedup_filter.num_items_inserted
    stats.bloom_filter_fpr_actual = calculate_expected_fpr(
        scorer.dedup_filter.size_bits,
        scorer.dedup_filter.num_items_inserted,
        scorer.dedup_filter.num_hash_functions
    )
    
    return stats

// ── Helper Functions ──

func record_rejection_reason(quality_scorer_state scorer, quality_metrics m) void:
    string reason = ""
    
    if m.overall_score < scorer.config.min_quality_score:
        reason = "low_quality:" + m.overall_score
    elif m.char_count < scorer.config.min_length_chars:
        reason = "too_short"
    elif m.is_duplicate:
        reason = "duplicate"
    elif m.contains_toxic:
        reason = "toxic"
    elif m.contains_pii:
        reason = "contains_pii"
    elif m.code_indicator > scorer.config.max_code_ratio:
        reason = "code_heavy"
    else:
        reason = "other"
    
    if len(scorer.rejection_reasons) < 10000:  // Limit log size
        scorer.rejection_reasons.push(reason)

func measure_repetition(map<int, int> freq, int total) float:
    // Measure how repetitive the text is (high = bad)
    // Use Gini coefficient or similar metric
    
    if total == 0:
        return 0.0
    
    float sum_squared = 0.0
    for (int token, int count) in freq:
        float p = float(count) / float(total)
        sum_squared = sum_squared + p * p
    
    // Gini-like measure: 0 = uniform, 1 = one token dominates
    return (sum_squared - 1.0/float(total)) / (1.0 - 1.0/float(total))

func detect_language(string text) (string, float):
    // Simplified language detection (would use fastText/langdetect library)
    // Returns (language_code, confidence)
    
    // Heuristic: check for common characters/patterns per language
    if contains_range(text, 0x4E00, 0x9FFF):  // CJK Unified Ideographs
        return ("zh", 0.9)
    elif contains_range(text, 0x0400, 0x04FF):  // Cyrillic
        return ("ru", 0.8)
    elif contains_range(text, 0x0600, 0x06FF):  // Arabic
        return ("ar", 0.8)
    else:
        return ("en", 0.7)  // Default to English

func contains_range(string s, int start, int end) bool:
    // Check if string contains characters in Unicode range
    int i = 0
    while i < len(s):
        int cp = get_codepoint(s, i)
        if cp >= start and cp <= end:
            return true
        i = i + 1
    return false

func get_codepoint(string s, int pos) int:
    // Get Unicode code point at position
    return int(s[pos])

// Hash function for Bloom filter
func compute_hash_with_seed(string item, int seed) int64:
    // Use FNV-1a or MurmurHash variant
    // Simplified implementation
    
    int64 hash = int64(seed) * 2654435761  // Golden ratio constant
    
    int i = 0
    while i < len(item):
        hash = hash + int64(item[i])
        hash = hash * 16777619  // FNV prime
        i = i + 1
    
    // Ensure positive
    if hash < 0:
        hash = -hash
    
    return hash

// String utility functions
func contains(string s, string sub) bool:
    // Check if s contains sub
    return find_substring(s, sub) >= 0

func find_substring(string s, string sub) int:
    // Find index of sub in s, or -1 if not found
    return -1

func to_lower_case(string s) string:
    // Convert to lowercase
    return s

func trim(string s) string:
    // Strip leading/trailing whitespace
    return s

func count_char(string s, char c) int:
    // Count occurrences of character c
    int count = 0
    int i = 0
    while i < len(s):
        if s[i] == c:
            count = count + 1
        i = i + 1
    return count

func count_occurrences(string s, string sub) int:
    // Count occurrences of substring
    int count = 0
    int pos = 0
    while pos < len(s):
        int found = find_substring_from(s, sub, pos)
        if found >= 0:
            count = count + 1
            pos = found + len(sub)
        else:
            break
    return count

func contains_regex(string s, string pattern) bool:
    // Regex match (simplified)
    return false

func max(int a, int b) int:
    if a > b: return a else: return b

func substring(string s, int start, int end) string:
    // Extract substring
    return ""
