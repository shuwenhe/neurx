package neurx.tokenizer.model_bpe

use neurx.strings
use neurx.runtime.io.{io_println}

// ============================================================================
// BPE tokenizer
//
// This file keeps the public tokenizer surface simple and compile-safe:
// - vocabulary and special tokens
// - char-level tokenization
// - optional pair-merge pass
// - encode / decode / batch helpers
// - cache statistics
// ============================================================================

struct token_config {
    int vocab_size
    int min_frequency
    bool add_eos_token
    bool add_bos_token
    bool add_space_prefix
}

struct bpe_vocab {
    []string tokens
    int vocab_size
}

struct bpe_tokenizer {
    bpe_vocab vocab
    token_config config
    []int merge_lefts
    []int merge_rights
    int num_merges
    int pad_token_id
    int eos_token_id
    int bos_token_id
    int unk_token_id
    int cache_hits
    int cache_misses
}

struct bpe_batch_result {
    []int token_ids
    int batch_size
    int seq_length
}

struct bpe_cache_stats {
    int cache_hits
    int cache_misses
}

// ============================================================================
// Init
// ============================================================================

func new_tokenizer_config() token_config {
    token_config {
        vocab_size: 16000,
        min_frequency: 2,
        add_eos_token: true,
        add_bos_token: true,
        add_space_prefix: true,
    }
}

func new_bpe_tokenizer([]string vocab_list, token_config cfg) bpe_tokenizer {
    bpe_vocab vocab
    vocab.tokens = copy_strings(vocab_list)
    vocab.vocab_size = len(vocab_list)

    int pad_id = find_token_id(vocab_list, "<pad>")
    int eos_id = find_token_id(vocab_list, "<eos>")
    int bos_id = find_token_id(vocab_list, "<bos>")
    int unk_id = find_token_id(vocab_list, "<unk>")

    if pad_id < 0 {
        pad_id = 0
    }
    if eos_id < 0 {
        eos_id = 1
    }
    if bos_id < 0 {
        bos_id = 2
    }
    if unk_id < 0 {
        unk_id = 3
    }

    bpe_tokenizer {
        vocab: vocab,
        config: cfg,
        merge_lefts: []int{cap: 0},
        merge_rights: []int{cap: 0},
        num_merges: 0,
        pad_token_id: pad_id,
        eos_token_id: eos_id,
        bos_token_id: bos_id,
        unk_token_id: unk_id,
        cache_hits: 0,
        cache_misses: 0,
    }
}

func find_token_id([]string vocab_list, string token_str) int {
    int i = 0
    while i < len(vocab_list) {
        if neurx.strings.strings_eq(vocab_list[i], token_str) {
            return i
        }
        i = i + 1
    }
    -1
}

// ============================================================================
// Encode
// ============================================================================

func encode(bpe_tokenizer tokenizer, string text) []int {
    tokenizer.cache_misses = tokenizer.cache_misses + 1

    string normalized = text
    if tokenizer.config.add_space_prefix && len(text) > 0 {
        normalized = " " + text
    }

    []int token_ids = text_to_char_ids(normalized, tokenizer)
    token_ids = apply_bpe_merges(token_ids, tokenizer.merge_lefts, tokenizer.merge_rights, tokenizer.num_merges)

    if tokenizer.config.add_bos_token {
        token_ids = prepend_int(token_ids, tokenizer.bos_token_id)
    }
    if tokenizer.config.add_eos_token {
        token_ids = append_int(token_ids, tokenizer.eos_token_id)
    }

    token_ids
}

func text_to_char_ids(string text, bpe_tokenizer tokenizer) []int {
    int n = len(text)
    []int ids = []int{cap: n}
    int i = 0
    while i < n {
        string ch = neurx.strings.substring(text, i, i + 1)
        int id = find_token_id(tokenizer.vocab.tokens, ch)
        if id < 0 {
            id = tokenizer.unk_token_id
        }
        ids.push(id)
        i = i + 1
    }
    ids
}

func apply_bpe_merges([]int tokens, []int merge_lefts, []int merge_rights, int num_merges) []int {
    []int current_tokens = copy_ints(tokens)
    int merge_idx = 0
    while merge_idx < num_merges && merge_idx < len(merge_lefts) && merge_idx < len(merge_rights) {
        int left = merge_lefts[merge_idx]
        int right = merge_rights[merge_idx]
        current_tokens = merge_token_pair(current_tokens, left, right, merge_idx)
        merge_idx = merge_idx + 1
    }
    current_tokens
}

func merge_token_pair([]int tokens, int left, int right, int merge_id) []int {
    []int result = []int{cap: len(tokens)}
    int i = 0
    while i < len(tokens) {
        if i + 1 < len(tokens) && tokens[i] == left && tokens[i + 1] == right {
            result.push(50000 + merge_id)
            i = i + 2
        } else {
            result.push(tokens[i])
            i = i + 1
        }
    }
    result
}

// ============================================================================
// Decode
// ============================================================================

func decode(bpe_tokenizer tokenizer, []int token_ids) string {
    []string out_tokens = []string{cap: len(token_ids)}
    int i = 0
    while i < len(token_ids) {
        int id = token_ids[i]
        if id >= 0 && id < tokenizer.vocab.vocab_size {
            string token = tokenizer.vocab.tokens[id]
            if id != tokenizer.pad_token_id && id != tokenizer.eos_token_id && id != tokenizer.bos_token_id && id != tokenizer.unk_token_id {
                out_tokens.push(token)
            }
        }
        i = i + 1
    }
    join_tokens(out_tokens, tokenizer.config.add_space_prefix)
}

func join_tokens([]string tokens, bool remove_space_prefix) string {
    string result = ""
    int i = 0
    while i < len(tokens) {
        string token = tokens[i]
        if i > 0 && should_add_space_before(token) {
            result = neurx.strings.concat2(result, " ")
        }
        result = neurx.strings.concat2(result, token)
        i = i + 1
    }

    if remove_space_prefix && len(result) > 0 {
        if neurx.strings.substring(result, 0, 1) == " " {
            result = neurx.strings.substring(result, 1, len(result))
        }
    }

    result
}

func is_special_token(string token) bool {
    if neurx.strings.strings_eq(token, "<pad>") { return true }
    if neurx.strings.strings_eq(token, "<eos>") { return true }
    if neurx.strings.strings_eq(token, "<bos>") { return true }
    if neurx.strings.strings_eq(token, "<unk>") { return true }
    false
}

func should_add_space_before(string token) bool {
    if len(token) == 0 {
        return false
    }
    string punct = ".,!?;:"
    string first_char = neurx.strings.substring(token, 0, 1)
    int j = 0
    while j < len(punct) {
        if neurx.strings.substring(punct, j, j + 1) == first_char {
            return false
        }
        j = j + 1
    }
    true
}

// ============================================================================
// Batch Helpers
// ============================================================================

func encode_batch(bpe_tokenizer tokenizer, []string texts, int max_length) bpe_batch_result {
    []int flat_tokens = []int{cap: len(texts) * max_length}
    int i = 0
    while i < len(texts) {
        []int token_ids = encode(tokenizer, texts[i])
        []int padded = pad_sequence(token_ids, max_length, tokenizer.pad_token_id)
        int j = 0
        while j < len(padded) {
            flat_tokens.push(padded[j])
            j = j + 1
        }
        i = i + 1
    }
    bpe_batch_result {
        token_ids: flat_tokens,
        batch_size: len(texts),
        seq_length: max_length,
    }
}

func decode_batch(bpe_tokenizer tokenizer, bpe_batch_result batch) []string {
    []string texts = []string{cap: batch.batch_size}
    int i = 0
    while i < batch.batch_size {
        int start = i * batch.seq_length
        int end = start + batch.seq_length
        []int seq = []int{cap: batch.seq_length}
        int j = start
        while j < end && j < len(batch.token_ids) {
            seq.push(batch.token_ids[j])
            j = j + 1
        }
        texts.push(decode(tokenizer, seq))
        i = i + 1
    }
    texts
}

func pad_sequence([]int tokens, int target_len, int pad_id) []int {
    if len(tokens) >= target_len {
        []int truncated = []int{cap: target_len}
        int i = 0
        while i < target_len {
            truncated.push(tokens[i])
            i = i + 1
        }
        return truncated
    }

    []int padded = []int{cap: target_len}
    int j = 0
    while j < len(tokens) {
        padded.push(tokens[j])
        j = j + 1
    }
    while j < target_len {
        padded.push(pad_id)
        j = j + 1
    }
    padded
}

// ============================================================================
// Stats / Utils
// ============================================================================

func get_vocab_size(bpe_tokenizer tokenizer) int {
    tokenizer.vocab.vocab_size
}

func id_to_token(bpe_tokenizer tokenizer, int token_id) string {
    if token_id >= 0 && token_id < tokenizer.vocab.vocab_size {
        return token_at(tokenizer.vocab.tokens, token_id)
    }
    "<unk>"
}

func token_to_id(bpe_tokenizer tokenizer, string token_str) int {
    find_token_id(tokenizer.vocab.tokens, token_str)
}

func get_cache_stats(bpe_tokenizer tokenizer) bpe_cache_stats {
    bpe_cache_stats {
        cache_hits: tokenizer.cache_hits,
        cache_misses: tokenizer.cache_misses,
    }
}

func print_statistics(bpe_tokenizer tokenizer) string {
    string stats = "tokenizer Statistics:\n"
    stats = stats + "  vocab_size=" + int_to_string(tokenizer.vocab.vocab_size) + "\n"
    stats = stats + "  cache_hits=" + int_to_string(tokenizer.cache_hits) + "\n"
    stats = stats + "  cache_misses=" + int_to_string(tokenizer.cache_misses) + "\n"
    io_println(stats)
    stats
}

// ============================================================================
// Helpers
// ============================================================================

func copy_strings([]string values) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func copy_ints([]int values) []int {
    []int out = []int{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func token_at([]string tokens, int idx) string {
    if idx < 0 || idx >= len(tokens) {
        return "<unk>"
    }
    string token = tokens[idx]
    token
}

func prepend_int([]int tokens, int token_id) []int {
    []int result = []int{cap: len(tokens) + 1}
    result.push(token_id)
    int i = 0
    while i < len(tokens) {
        result.push(tokens[i])
        i = i + 1
    }
    result
}

func append_int([]int tokens, int token_id) []int {
    []int result = []int{cap: len(tokens) + 1}
    int i = 0
    while i < len(tokens) {
        result.push(tokens[i])
        i = i + 1
    }
    result.push(token_id)
    result
}

func int_to_string(int x) string {
    if x == 0 {
        return "0"
    }
    bool neg = false
    int value = x
    if value < 0 {
        neg = true
        value = -value
    }
    string out = ""
    while value > 0 {
        int digit = value % 10
        out = string(digit + 48) + out
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    out
}
