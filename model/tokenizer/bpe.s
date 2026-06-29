package neurx.model.tokenizer.bpe

// =====================================================================
// BPE (Byte-Pair Encoding) Tokenizer Implementation
// =====================================================================
// Complete tokenizer for text encoding/decoding
// - Character-level byte encoding
// - Merge rules for subword units
// - Vocabulary management
// - Caching for performance
// - Special token support

struct token_config {
    int vocab_size              // Total vocabulary size
    int min_frequency          // Minimum frequency for merge
    bool add_eos_token         // Add end-of-sequence token
    bool add_bos_token         // Add beginning-of-sequence token
    bool add_space_prefix       // Add space before word (for recovery)
}

struct bpe_vocab {
    []string tokens            // Index -> token string mapping
    int vocab_size
}

struct bpe_tokenizer {
    bpe_vocab vocab
    token_config config
    
    // Merge rules: (left_id, right_id) -> merged_id
    [][]int merge_rules        // merge_rules[i] = [left, right]
    int num_merges
    
    // Special token IDs
    int pad_token_id
    int eos_token_id
    int bos_token_id
    int unk_token_id
    
    // Cache for frequently tokenized sequences
    [string][]int token_cache
    int cache_hits
    int cache_misses
}

// =====================================================================
// Initialization
// =====================================================================

func new_tokenizer_config() token_config {
    token_config {
        vocab_size: 50257,
        min_frequency: 2,
        add_eos_token: true,
        add_bos_token: true,
        add_space_prefix: true,
    }
}

// Create tokenizer from vocabulary list
func new_bpe_tokenizer([]string vocab_list, token_config cfg) bpe_tokenizer {
    let vocab = bpe_vocab {
        tokens: vocab_list,
        vocab_size: len(vocab_list),
    }
    
    // Find special token IDs
    let pad_id = find_token_id(vocab_list, "<pad>")
    let eos_id = find_token_id(vocab_list, "<eos>")
    let bos_id = find_token_id(vocab_list, "<bos>")
    let unk_id = find_token_id(vocab_list, "<unk>")
    
    bpe_tokenizer {
        vocab: vocab,
        config: cfg,
        merge_rules: [][]int{cap: cfg.vocab_size},
        num_merges: 0,
        pad_token_id: pad_id,
        eos_token_id: eos_id,
        bos_token_id: bos_id,
        unk_token_id: unk_id,
        token_cache: [string][]int{cap: 10000},
        cache_hits: 0,
        cache_misses: 0,
    }
}

// Find token ID by string
func find_token_id([]string vocab_list, string token_str) int {
    var i = 0
    while i < len(vocab_list) {
        if vocab_list[i] == token_str {
            return i
        }
        i = i + 1
    }
    return -1  // Not found
}

// =====================================================================
// Tokenization: Text -> Token IDs
// =====================================================================

// Main encode function: convert text to token IDs
func encode(bpe_tokenizer tokenizer, string text) []int {
    // Check cache first
    if text in tokenizer.token_cache {
        tokenizer.cache_hits = tokenizer.cache_hits + 1
        return tokenizer.token_cache[text]
    }
    
    tokenizer.cache_misses = tokenizer.cache_misses + 1
    
    // Normalize text: add space before if configured
    var normalized = text
    if tokenizer.config.add_space_prefix && len(text) > 0 {
        normalized = " " + text
    }
    
    // Convert text to token IDs character by character
    []int char_ids = text_to_char_ids(normalized, tokenizer.vocab)
    
    // Apply BPE merges
    []int merged = apply_bpe_merges(char_ids, tokenizer.merge_rules, tokenizer.num_merges)
    
    // Add special tokens if configured
    var token_ids = merged
    if tokenizer.config.add_bos_token {
        token_ids = prepend_int(token_ids, tokenizer.bos_token_id)
    }
    if tokenizer.config.add_eos_token {
        token_ids = append_int(token_ids, tokenizer.eos_token_id)
    }
    
    // Cache result
    tokenizer.token_cache[text] = token_ids
    
    return token_ids
}

// Convert text to character-level token IDs
func text_to_char_ids(string text, bpe_vocab vocab) []int {
    []int ids = []int{cap: len(text)}
    
    var i = 0
    while i < len(text) {
        // Get character and find its ID in vocab
        let char = text[i:i+1]
        let id = find_token_id(vocab.tokens, char)
        
        if id >= 0 {
            ids.push(id)
        } else {
            // Use unknown token ID (index 0)
            ids.push(0)
        }
        
        i = i + 1
    }
    
    return ids
}

// Apply BPE merge rules to token sequence
func apply_bpe_merges(
    []int tokens,
    [][]int merge_rules,
    int num_merges
) []int {
    var current_tokens = tokens
    
    // Apply each merge rule in order
    var merge_idx = 0
    while merge_idx < num_merges {
        let left = merge_rules[merge_idx][0]
        let right = merge_rules[merge_idx][1]
        
        // Find and merge all occurrences of (left, right)
        current_tokens = merge_token_pair(current_tokens, left, right, merge_idx)
        
        merge_idx = merge_idx + 1
    }
    
    return current_tokens
}

// Merge all occurrences of token pair in sequence
func merge_token_pair([]int tokens, int left, int right, int merge_id) []int {
    []int result = []int{cap: len(tokens)}
    
    var i = 0
    while i < len(tokens) {
        if i < len(tokens) - 1 && tokens[i] == left && tokens[i + 1] == right {
            // Merge these two tokens into a new ID
            result.push(50000 + merge_id)  // Use high IDs for merged tokens
            i = i + 2
        } else {
            result.push(tokens[i])
            i = i + 1
        }
    }
    
    return result
}

// =====================================================================
// Detokenization: Token IDs -> Text
// =====================================================================

// Decode token IDs back to text
func decode(bpe_tokenizer tokenizer, []int token_ids) string {
    []string tokens = []string{cap: len(token_ids)}
    
    // Convert token IDs to token strings
    var i = 0
    while i < len(token_ids) {
        let id = token_ids[i]
        if id >= 0 && id < tokenizer.vocab.vocab_size {
            tokens.push(tokenizer.vocab.tokens[id])
        } else {
            tokens.push("<unk>")
        }
        i = i + 1
    }
    
    // Join tokens with appropriate spacing
    return join_tokens(tokens, tokenizer.config.add_space_prefix)
}

// Join token strings back to text
func join_tokens([]string tokens, bool remove_space_prefix) string {
    var result = ""
    var i = 0
    
    while i < len(tokens) {
        let token = tokens[i]
        
        // Skip special tokens
        if is_special_token(token) {
            i = i + 1
            continue
        }
        
        // Add space before if needed (except for first token)
        if i > 0 && should_add_space_before(token) {
            result = result + " "
        }
        
        result = result + token
        i = i + 1
    }
    
    // Remove leading space if configured
    if remove_space_prefix && len(result) > 0 {
        if result[0:1] == " " {
            result = result[1:len(result)]
        }
    }
    
    return result
}

// Check if token is special
func is_special_token(string token) bool {
    if token == "<pad>" {
        return true
    }
    if token == "<eos>" {
        return true
    }
    if token == "<bos>" {
        return true
    }
    if token == "<unk>" {
        return true
    }
    return false
}

// Decide if space should precede token
func should_add_space_before(string token) bool {
    // Punctuation doesn't need space before
    let punct = ".,!?;:"
    if len(token) > 0 {
        let first_char = token[0:1]
        var j = 0
        while j < len(punct) {
            if first_char == punct[j:j+1] {
                return false
            }
            j = j + 1
        }
    }
    return true
}

// =====================================================================
// Batch Operations
// =====================================================================

// Tokenize multiple texts (with padding)
func encode_batch(bpe_tokenizer tokenizer, []string texts, int max_length) [][]int {
    [][]int batch_ids = [][]int{cap: len(texts)}
    
    var i = 0
    while i < len(texts) {
        let token_ids = encode(tokenizer, texts[i])
        
        // Pad or truncate to max_length
        let padded = pad_sequence(token_ids, max_length, tokenizer.pad_token_id)
        batch_ids.push(padded)
        
        i = i + 1
    }
    
    return batch_ids
}

// Decode batch of token sequences
func decode_batch(bpe_tokenizer tokenizer, [][]int batch_ids) []string {
    []string texts = []string{cap: len(batch_ids)}
    
    var i = 0
    while i < len(batch_ids) {
        texts.push(decode(tokenizer, batch_ids[i]))
        i = i + 1
    }
    
    return texts
}

// Pad token sequence to fixed length
func pad_sequence([]int tokens, int target_len, int pad_id) []int {
    if len(tokens) >= target_len {
        // Truncate
        []int truncated = []int{cap: target_len}
        var i = 0
        while i < target_len {
            truncated.push(tokens[i])
            i = i + 1
        }
        return truncated
    }
    
    // Pad
    []int padded = []int{cap: target_len}
    var i = 0
    while i < len(tokens) {
        padded.push(tokens[i])
        i = i + 1
    }
    
    while i < target_len {
        padded.push(pad_id)
        i = i + 1
    }
    
    return padded
}

// =====================================================================
// Vocabulary Operations
// =====================================================================

// Get vocabulary size
func get_vocab_size(bpe_tokenizer tokenizer) int {
    return tokenizer.vocab.vocab_size
}

// Get token string from ID
func id_to_token(bpe_tokenizer tokenizer, int token_id) string {
    if token_id >= 0 && token_id < tokenizer.vocab.vocab_size {
        return tokenizer.vocab.tokens[token_id]
    }
    return "<unk>"
}

// Get token ID from string
func token_to_id(bpe_tokenizer tokenizer, string token_str) int {
    return find_token_id(tokenizer.vocab.tokens, token_str)
}

// Get cache statistics
func get_cache_stats(bpe_tokenizer tokenizer) (int, int) {
    return (tokenizer.cache_hits, tokenizer.cache_misses)
}

// =====================================================================
// Helper Functions
// =====================================================================

func prepend_int([]int tokens, int token_id) []int {
    []int result = []int{cap: len(tokens) + 1}
    result.push(token_id)
    var i = 0
    while i < len(tokens) {
        result.push(tokens[i])
        i = i + 1
    }
    return result
}

func append_int([]int tokens, int token_id) []int {
    []int result = []int{cap: len(tokens) + 1}
    var i = 0
    while i < len(tokens) {
        result.push(tokens[i])
        i = i + 1
    }
    result.push(token_id)
    return result
}

// Print tokenizer statistics
func print_statistics(bpe_tokenizer tokenizer) string {
    string stats = "Tokenizer Statistics:\n"
    // Add stats
    stats
}
