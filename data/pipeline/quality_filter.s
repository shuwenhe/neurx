package neurx.data.pipeline.quality_filter
use neurx.strings
struct quality_filter_config:
    float min_quality_score
    int min_length_chars
    int max_length_chars
    int min_tokens
    int max_tokens
    bool enable_dedup
    string dedup_method
    int bloom_filter_size_mb
    float max_false_positive_rate
    int num_hash_functions
    bool enable_near_dedup
    float similarity_threshold
    int ngram_size
    bool filter_toxic_content
    bool filter_pii
    bool filter_code_heavy
    float max_code_ratio
    string target_language
    float min_language_confidence
    bool async_processing
    int batch_size_for_scoring
func default_2t_quality_filter_config() quality_filter_config:
    quality_filter_config cfg
    cfg.min_quality_score = 0.3
    cfg.min_length_chars = 10
    cfg.max_length_chars = 100000
    cfg.min_tokens = 3
    cfg.max_tokens = 8192
    cfg.enable_dedup = true
    cfg.dedup_method = "bloom_filter"
    cfg.bloom_filter_size_mb = 512
    cfg.max_false_positive_rate = 0.001
    cfg.num_hash_functions = 7
    cfg.enable_near_dedup = true
    cfg.similarity_threshold = 0.85
    cfg.ngram_size = 9
    cfg.filter_toxic_content = true
    cfg.filter_pii = true
    cfg.filter_code_heavy = true
    cfg.max_code_ratio = 0.8
    cfg.target_language = "auto"
    cfg.min_language_confidence = 0.7
    cfg.async_processing = true
    cfg.batch_size_for_scoring = 1000
    return cfg
struct bloom_filter:
    []byte bit_array
    int64 size_bits
    int64 num_items_inserted
    int num_hash_functions
    float expected_fpr
func calculate_bloom_params(
    int64 expected_items,
    float desired_fpr
) (int64, int):
    float ln_p = log(desired_fpr)
    float ln_2_sq = 0.480453
    int64 m = int64(-float(expected_items) * ln_p / ln_2_sq)
    if m < 1024:
        m = 1024
    int k = int(float(m) / float(expected_items) * 0.693147)
    if k < 1:
        k = 1
    if k > 20:
        k = 20
    return (m, k)
func new_bloom_filter(int64 size_bits, int num_hashes) bloom_filter:
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
func bloom_insert(bloom_filter bf, string item) void:
    int h = 0
    while h < bf.num_hash_functions:
        int64 hash_val = compute_hash_with_seed(item, h)
        int64 bit_pos = h(hash_val - (hash_val / bf.size_bits) * bf.size_bits)
        int64 byte_idx = bit_pos / 8
        int bit_idx = b(bit_pos - (bit_pos / 8) * 8)
        if byte_idx >= 0 and byte_idx < len(bf.bit_array):
            bf.bit_array[byte_idx] = bf.bit_array[byte_idx] | (1 << bit_idx)
        h = h + 1
    bf.num_items_inserted = bf.num_items_inserted + 1
func bloom_contains(bloom_filter bf, string item) bool:
    int h = 0
    while h < bf.num_hash_functions:
        int64 hash_val = compute_hash_with_seed(item, h)
        int64 bit_pos = h(hash_val - (hash_val / bf.size_bits) * bf.size_bits)
        int64 byte_idx = bit_pos / 8
        int bit_idx = b(bit_pos - (bit_pos / 8) * 8)
        if byte_idx >= 0 and byte_idx < len(bf.bit_array):
            if (bf.bit_array[byte_idx]  (1 << bit_idx)) == 0:
                return false
        else:
            return false
        h = h + 1
    return true
func calculate_expected_fpr(int64 size_bits, int64 n, int k) float:
    if size_bits == 0 or k == 0:
        return 1.0
    float exponent = -float(k) * float(n) / float(size_bits)
    float base = 1.0 - exp_approx(exponent)
    float fpr = pow_approx(base, float(k))
    return fpr
struct quality_metrics:
    float overall_score
    float length_score
    float content_score
    float language_score
    float toxicity_score
    float uniqueness_score
    float format_score
    int char_count
    int token_count
    int unique_token_ratio
    float avg_word_length
    float punctuation_ratio
    float capitalization_ratio
    float numeric_ratio
    float code_indicator
    string detected_language
    float language_confidence
    bool contains_toxic
    bool contains_pii
    bool is_duplicate
    bool should_keep
struct quality_scorer_state:
    quality_filter_config config
    bloom_filter dedup_filter
    int total_samples_seen
    int total_samples_kept
    int total_samples_rejected
    []string rejection_reasons
func new_quality_scorer(quality_filter_config config) quality_scorer_state:
    quality_scorer_state scorer
    scorer.config = config
    scorer.total_samples_seen = 0
    scorer.total_samples_kept = 0
    scorer.total_samples_rejected = 0
    scorer.rejection_reasons = []string{cap: 1000}
    if config.enable_dedup and config.dedup_method == "bloom_filter":
        int64 estimated_items = int64(10 * 1024 * 1024 * 1024)
        (int64 bits, int hashes) = calculate_bloom_params(
            estimated_items,
            config.max_false_positive_rate
        )
        if config.bloom_filter_size_mb > 0:
            bits = int64(config.bloom_filter_size_mb) * 1024 * 1024 * 8
        scorer.dedup_filter = new_bloom_filter(bits, config.num_hash_functions)
    return scorer
func score_sample(
    quality_scorer_state scorer,
    string text,
    []int token_ids
) quality_metrics:
    scorer.total_samples_seen = scorer.total_samples_seen + 1
    quality_metrics metrics
    metrics.char_count = len(text)
    metrics.token_count = len(token_ids)
    metrics.length_score = compute_length_score(metrics.char_count, metrics.token_count, scorer.config)
    metrics.content_score = compute_content_quality(text, token_ids, metrics)
    (metrics.detected_language, metrics.language_confidence) = detect_language(text)
    metrics.language_score = compute_language_score(metrics.detected_language, metrics.language_confidence, scorer.config)
    (metrics.contains_toxic, metrics.toxicity_score) = detect_toxicity(text)
    metrics.contains_pii = detect_pii(text)
    metrics.code_indicator = detect_code_content(text)
    metrics.format_score = compute_format_score(text, metrics.code_indicator)
    if scorer.config.enable_dedup:
        string normalized = normalize_for_dedup(text, token_ids)
        bool maybe_dup = bloom_contains(scorer.dedup_filter, normalized)
        if maybe_dup:
            metrics.is_duplicate = true
            metrics.uniqueness_score = 0.0
        else:
            bloom_insert(scorer.dedup_filter, normalized)
            metrics.is_duplicate = false
            metrics.uniqueness_score = 1.0
    else:
        metrics.is_duplicate = false
        metrics.uniqueness_score = 1.0
    metrics.overall_score = compute_overall_score(metrics, scorer.config)
    metrics.should_keep = make_filter_decision(metrics, scorer.config)
    if metrics.should_keep:
        scorer.total_samples_kept = scorer.total_samples_kept + 1
    else:
        scorer.total_samples_rejected = scorer.total_samples_rejected + 1
        record_rejection_reason(scorer, metrics)
    return metrics
func compute_length_score(int char_count, int token_count, quality_filter_config cfg) float:
    if char_count < cfg.min_length_chars:
        return float(char_count) / float(cfg.min_length_chars)
    if cfg.max_length_chars > 0 and char_count > cfg.max_length_chars:
        return 0.9
    if token_count < cfg.min_tokens:
        return float(token_count) / float(cfg.min_tokens)
    if cfg.max_tokens > 0 and token_count > cfg.max_tokens:
        return 0.85
    return 1.0
func compute_content_quality(string text, []int token_ids, quality_metrics metrics) float:
    if len(token_ids) == 0:
        return 0.0
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
    float repetition_penalty = measure_repetition(token_freq, len(token_ids))
    float diversity_component = metrics.unique_token_ratio
    float repetition_component = 1.0 - repetition_penalty
    return (diversity_component * 0.6 + repetition_component * 0.4)
func compute_language_score(string detected_lang, float confidence, quality_filter_config cfg) float:
    if cfg.target_language == "auto":
        if confidence >= cfg.min_language_confidence:
            return 1.0
        else:
            return confidence / cfg.min_language_confidence
    else:
        if detected_lang == cfg.target_language and confidence >= cfg.min_language_confidence:
            return 1.0
        elif detected_lang == cfg.target_language:
            return confidence
        else:
            return 0.0
func detect_toxicity(string text) (bool, float):
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
    if score > 1.0:
        score = 1.0
    return (toxic_count > 2, score)
func detect_pii(string text) bool:
    if contains_regex(text, r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"):
        return true
    if contains_regex(text, r"\d{3}[-.]?\d{3}[-.]?\d{4}"):
        return true
    if contains_regex(text, r"\d{3}-\d{2}-\d{4}"):
        return true
    return false
func detect_code_content(string text) float:
    float code_score = 0.0
    int bracket_count = count_char(text, '{') + count_char(text, '}') +
                         count_char(text, '(') + count_char(text, ')')
    int semicolon_count = count_char(text, ';')
    int indent_count = count_char(text, '\t') + count_occurrences(text, "    ")
    if len(text) > 0:
        code_score = code_score + float(bracket_count) / float(len(text)) * 5.0
        code_score = code_score + float(semicolon_count) / float(len(text)) * 3.0
        code_score = code_score + float(indent_count) / float(len(text)) * 2.0
    code_keywords = ["function", "def ", "class ", "import ", "return ", "if ", "else", "for ", "while "]
    int keyword_hits = 0
    int i = 0
    while i < len(code_keywords):
        if contains(text, code_keywords[i]):
            keyword_hits = keyword_hits + 1
        i = i + 1
    code_score = code_score + float(keyword_hits) * 0.05
    if code_score > 1.0:
        code_score = 1.0
    return code_score
func compute_format_score(string text, float code_indicator) float:
    if code_indicator > 0.9:
        return 0.2
    float space_ratio = float(count_char(text, ' ')) / float(max(1, len(text)))
    if space_ratio > 0.05 and space_ratio < 0.3:
        return 1.0
    elif space_ratio > 0.01:
        return 0.8
    else:
        return 0.5
func normalize_for_dedup(string text, []int token_ids) string:
    string normalized = to_lower_case(trim(text))
    if len(normalized) > 500:
        normalized = substring(normalized, 0, 500)
    return normalized
func compute_overall_score(quality_metrics m, quality_filter_config cfg) float:
    float score = 0.0
    float total_weight = 0.0
    score = score + m.length_score * 0.15
    total_weight = total_weight + 0.15
    score = score + m.content_score * 0.25
    total_weight = total_weight + 0.25
    score = score + m.language_score * 0.15
    total_weight = total_weight + 0.15
    score = score + (1.0 - m.toxicity_score) * 0.15
    total_weight = total_weight + 0.15
    score = score + m.uniqueness_score * 0.20
    total_weight = total_weight + 0.20
    score = score + m.format_score * 0.10
    total_weight = total_weight + 0.10
    if total_weight > 0:
        score = score / total_weight
    return score
func make_filter_decision(quality_metrics m, quality_filter_config cfg) bool:
    if m.overall_score < cfg.min_quality_score:
        return false
    if m.char_count < cfg.min_length_chars:
        return false
    if cfg.max_length_chars > 0 and m.char_count > cfg.max_length_chars:
        return false
    if m.token_count < cfg.min_tokens:
        return false
    if cfg.max_tokens > 0 and m.token_count > cfg.max_tokens:
        return false
    if cfg.filter_toxic_content and m.contains_toxic:
        return false
    if cfg.filter_pii and m.contains_pii:
        return false
    if cfg.filter_code_heavy and m.code_indicator > cfg.max_code_ratio:
        return false
    if m.is_duplicate:
        return false
    return true
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
    stats.rejected_by_quality = 0
    stats.rejected_by_length = 0
    stats.rejected_by_dedup = 0
    stats.rejected_by_toxicity = 0
    stats.rejected_by_pii = 0
    stats.rejected_by_code = 0
    stats.rejected_by_language = 0
    stats.bloom_filter_items = scorer.dedup_filter.num_items_inserted
    stats.bloom_filter_fpr_actual = calculate_expected_fpr(
        scorer.dedup_filter.size_bits,
        scorer.dedup_filter.num_items_inserted,
        scorer.dedup_filter.num_hash_functions
    )
    return stats
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
    if len(scorer.rejection_reasons) < 10000:
        scorer.rejection_reasons.push(reason)
func measure_repetition(map<int, int> freq, int total) float:
    if total == 0:
        return 0.0
    float sum_squared = 0.0
    for (int token, int count) in freq:
        float p = float(count) / float(total)
        sum_squared = sum_squared + p * p
    return (sum_squared - 1.0/float(total)) / (1.0 - 1.0/float(total))
func detect_language(string text) (string, float):
    if contains_range(text, 0x_4_e_00, 0x_9_fff):
        return ("zh", 0.9)
    elif contains_range(text, 0x0400, 0x_04_ff):
        return ("ru", 0.8)
    elif contains_range(text, 0x0600, 0x_06_ff):
        return ("ar", 0.8)
    else:
        return ("en", 0.7)
func contains_range(string s, int start, int end) bool:
    int i = 0
    while i < len(s):
        int cp = get_codepoint(s, i)
        if cp >= start and cp <= end:
            return true
        i = i + 1
    return false
func get_codepoint(string s, int pos) int:
    return int(s[pos])
func compute_hash_with_seed(string item, int seed) int64:
    int64 hash = int64(seed) * 2654435761
    int i = 0
    while i < len(item):
        hash = hash + int64(item[i])
        hash = hash * 16777619
        i = i + 1
    if hash < 0:
        hash = -hash
    return hash
func contains(string s, string sub) bool:
    return find_substring(s, sub) >= 0
func find_substring(string s, string sub) int:
    return -1
func to_lower_case(string s) string:
    return s
func trim(string s) string:
    return s
func count_char(string s, char c) int:
    int count = 0
    int i = 0
    while i < len(s):
        if s[i] == c:
            count = count + 1
        i = i + 1
    return count
func count_occurrences(string s, string sub) int:
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
    return false
func max(int a, int b) int:
    if a > b: return a else: return b
func substring(string s, int start, int end) string:
    return ""
