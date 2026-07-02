package neurx.pretrain.tokenizer.bpe

use neurx.strings

func string_char(int c) string {
    string(c)
}

struct bpe_split_state {
    []string train_documents
    []string valid_documents
    float valid_ratio
    int seed
}

struct bpe_tokenizer_state {
    int vocab_limit
    int min_pair_frequency
    []string vocab
    []string merge_lefts
    []string merge_rights
    []string merge_tokens
    bool trained
}

struct bpe_tokenized_corpus_state {
    bpe_split_state split
    bpe_tokenizer_state tokenizer
    []int train_token_ids
    []int valid_token_ids
}

struct bpe_pair_choice {
    string left
    string right
    int count
}

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

func positive_mod(int value, int modulus) int {
    if modulus <= 0 {
        return 0
    }
    int div_result = value / modulus
    int result = value - div_result * modulus
    if result < 0 {
        result = result + modulus
    }
    result
}

func has_string([]string values, string target) bool {
    int i = 0
    while i < len(values) {
        if neurx.strings.strings_eq(values[i], target) {
            return true
        }
        i = i + 1
    }
    false
}

func append_unique_string([]string values, string value) []string {
    if has_string(values, value) {
        return values
    }
    values.push(value)
    values
}

func join_documents([]string documents) string {
    string out = ""
    int i = 0
    while i < len(documents) {
        string doc = trim(documents[i])
        if doc != "" {
            if out != "" {
                out = out + "\n\n"
            }
            out = out + doc
        }
        i = i + 1
    }
    out
}

func split_documents([]string documents, float valid_ratio, int seed) bpe_split_state {
    []string train_documents = []string{cap: 0}
    []string valid_documents = []string{cap: 0}
    int i = 0
    while i < len(documents) {
        string doc = trim(documents[i])
        if doc != "" {
            int bucket = positive_mod(seed + i * 1103515245, 1000)
            float bucket_value = bucket * 1.0
            float threshold = valid_ratio * 1000.0
            if bucket_value < threshold {
                valid_documents.push(doc)
            } else {
                train_documents.push(doc)
            }
        }
        i = i + 1
    }
    if len(train_documents) == 0 && len(valid_documents) > 0 {
        train_documents.push(valid_documents[0])
    }
    if len(valid_documents) == 0 && len(train_documents) > 1 {
        valid_documents.push(train_documents[len(train_documents) - 1])
    }
    bpe_split_state {
        train_documents: train_documents,
        valid_documents: valid_documents,
        valid_ratio: valid_ratio,
        seed: seed,
    }
}

func bpe_tokenizer_new(int vocab_limit, int min_pair_frequency) bpe_tokenizer_state {
    bpe_tokenizer_state {
        vocab_limit: vocab_limit,
        min_pair_frequency: min_pair_frequency,
        vocab: []string{cap: 0},
        merge_lefts: []string{cap: 0},
        merge_rights: []string{cap: 0},
        merge_tokens: []string{cap: 0},
        trained: false,
    }
}

func tokenize_chars(string text) []string {
    int n = len(text)
    []string tokens = []string{cap: n}
    int i = 0
    while i < n {
        string ch = neurx.strings.substring(text, i, i + 1)
        if ch != "\r" {
            tokens.push(ch)
        }
        i = i + 1
    }
    tokens
}

func apply_merge_pass([]string tokens, string left, string right, string merged) []string {
    []string out = []string{cap: len(tokens)}
    int i = 0
    while i < len(tokens) {
        if i + 1 < len(tokens) && neurx.strings.strings_eq(tokens[i], left) && neurx.strings.strings_eq(tokens[i + 1], right) {
            out.push(merged)
            i = i + 2
        } else {
            out.push(tokens[i])
            i = i + 1
        }
    }
    out
}

// Getter helpers avoid field-index inference issues in the S compiler.
func bpe_merge_left(bpe_tokenizer_state tokenizer, int index) string {
    tokenizer.merge_lefts[index]
}

func bpe_merge_right(bpe_tokenizer_state tokenizer, int index) string {
    tokenizer.merge_rights[index]
}

func bpe_merge_token(bpe_tokenizer_state tokenizer, int index) string {
    tokenizer.merge_tokens[index]
}

func bpe_has_merge_token(bpe_tokenizer_state tokenizer, string token) bool {
    int i = 0
    while i < len(tokenizer.merge_tokens) {
        if neurx.strings.strings_eq(bpe_merge_token(tokenizer, i), token) {
            return true
        }
        i = i + 1
    }
    false
}

func bpe_tokenize_text(string text, bpe_tokenizer_state tokenizer) []string {
    []string tokens = tokenize_chars(text)
    int i = 0
    while i < len(tokenizer.merge_tokens) {
        string left = bpe_merge_left(tokenizer, i)
        string right = bpe_merge_right(tokenizer, i)
        string merged = bpe_merge_token(tokenizer, i)
        tokens = apply_merge_pass(tokens, left, right, merged)
        i = i + 1
    }
    tokens
}

func token_pair_key(string left, string right) string {
    left + "||" + right
}

func token_pair_index([]string pair_keys, string key) int {
    int i = 0
    while i < len(pair_keys) {
        if neurx.strings.strings_eq(pair_keys[i], key) {
            return i
        }
        i = i + 1
    }
    -1
}

func count_pair_occurrences([]string documents, bpe_tokenizer_state tokenizer, []string pair_keys, []string pair_lefts, []string pair_rights, []int pair_counts) {
    int d = 0
    while d < len(documents) {
        []string tokens = bpe_tokenize_text(documents[d], tokenizer)
        int i = 0
        while i + 1 < len(tokens) {
            string left = tokens[i]
            string right = tokens[i + 1]
            string key = token_pair_key(left, right)
            int idx = token_pair_index(pair_keys, key)
            if idx < 0 {
                pair_keys.push(key)
                pair_lefts.push(left)
                pair_rights.push(right)
                pair_counts.push(1)
            } else {
                pair_counts[idx] = pair_counts[idx] + 1
            }
            i = i + 1
        }
        d = d + 1
    }
}

func find_best_pair([]string pair_lefts, []string pair_rights, []int pair_counts, int min_pair_frequency) bpe_pair_choice {
    string best_left = ""
    string best_right = ""
    int best_count = 0
    int i = 0
    while i < len(pair_counts) {
        int count = pair_counts[i]
        if count > best_count && count >= min_pair_frequency {
            best_left = pair_lefts[i]
            best_right = pair_rights[i]
            best_count = count
        }
        i = i + 1
    }
    bpe_pair_choice {
        left: best_left,
        right: best_right,
        count: best_count,
    }
}

func bpe_tokenizer_train([]string documents, int vocab_limit, int min_pair_frequency) bpe_tokenizer_state {
    bpe_tokenizer_state tokenizer = bpe_tokenizer_new(vocab_limit, min_pair_frequency)
    []string vocab = []string{cap: 0}
    int d = 0
    while d < len(documents) {
        []string tokens = tokenize_chars(documents[d])
        int i = 0
        while i < len(tokens) {
            vocab = append_unique_string(vocab, tokens[i])
            i = i + 1
        }
        d = d + 1
    }

    tokenizer.vocab = copy_strings(vocab)
    int current_vocab_size = len(tokenizer.vocab)
    while current_vocab_size < vocab_limit {
        []string pair_keys = []string{cap: 0}
        []string pair_lefts = []string{cap: 0}
        []string pair_rights = []string{cap: 0}
        []int pair_counts = []int{cap: 0}
        count_pair_occurrences(documents, tokenizer, pair_keys, pair_lefts, pair_rights, pair_counts)
        bpe_pair_choice best = find_best_pair(pair_lefts, pair_rights, pair_counts, min_pair_frequency)
        string best_left = best.left
        string best_right = best.right
        int best_count = best.count
        if best_count < min_pair_frequency || best_left == "" {
            break
        }
        string merged = token_pair_key(best_left, best_right)
        tokenizer.merge_lefts.push(best_left)
        tokenizer.merge_rights.push(best_right)
        tokenizer.merge_tokens.push(merged)
        tokenizer.vocab = append_unique_string(tokenizer.vocab, merged)
        current_vocab_size = len(tokenizer.vocab)
    }
    tokenizer.trained = true
    tokenizer
}

func bpe_token_to_id(bpe_tokenizer_state tokenizer, string token) int {
    int i = 0
    while i < len(tokenizer.vocab) {
        if neurx.strings.strings_eq(tokenizer.vocab[i], token) {
            return i
        }
        i = i + 1
    }
    0
}

func bpe_encode_text(string text, bpe_tokenizer_state tokenizer) []int {
    []string tokens = bpe_tokenize_text(text, tokenizer)
    []int out = []int{cap: len(tokens)}
    int i = 0
    while i < len(tokens) {
        out.push(bpe_token_to_id(tokenizer, tokens[i]))
        i = i + 1
    }
    out
}

func bpe_encode_documents([]string documents, bpe_tokenizer_state tokenizer) []int {
    string corpus = join_documents(documents)
    if trim(corpus) == "" {
        return []int{cap: 0}
    }
    bpe_encode_text(corpus, tokenizer)
}

func bpe_tokenized_corpus_from_documents([]string documents, int vocab_limit, int min_pair_frequency, float valid_ratio, int seed) bpe_tokenized_corpus_state {
    bpe_split_state split = split_documents(documents, valid_ratio, seed)
    bpe_tokenizer_state tokenizer = bpe_tokenizer_train(split.train_documents, vocab_limit, min_pair_frequency)
    bpe_tokenized_corpus_state {
        split: split,
        tokenizer: tokenizer,
        train_token_ids: bpe_encode_documents(split.train_documents, tokenizer),
        valid_token_ids: bpe_encode_documents(split.valid_documents, tokenizer),
    }
}

func bpe_find_substring(string text, string pattern) int {
    if len(pattern) == 0 {
        return 0
    }
    int i = 0
    while i + len(pattern) <= len(text) {
        int j = 0
        while j < len(pattern) && text[i + j] == pattern[j] {
            j = j + 1
        }
        if j == len(pattern) {
            return i
        }
        i = i + 1
    }
    -1
}

func bpe_trim(string s) string {
    int left = 0
    while left < len(s) && (s[left] == 32 || s[left] == 9 || s[left] == 10 || s[left] == 13) {
        left = left + 1
    }

    int right = len(s) - 1
    while right >= left && (s[right] == 32 || s[right] == 9 || s[right] == 10 || s[right] == 13) {
        right = right - 1
    }

    if right < left {
        return ""
    }

    string out = ""
        int i = left
        while i <= right {
            out = out + string_char(s[i])
            i = i + 1
        }
    out
}

func bpe_normalize_text(string text) string {
    string out = ""
    bool in_space = false
    int i = 0
    while i < len(text) {
        int c = text[i]
        if c == 9 || c == 10 || c == 13 || c == 32 {
            if len(out) > 0 && !in_space {
                out = out + " "
            }
            in_space = true
        } else {
                out = out + string_char(c)
            in_space = false
        }
        i = i + 1
    }
    bpe_trim(out)
}

func bpe_extract_jsonl_text(string line) string {
    string text = bpe_trim(line)
    if text == "" {
        return ""
    }

    int key_idx = bpe_find_substring(text, "\"text\"")
    if key_idx < 0 {
        return bpe_normalize_text(text)
    }

    int colon_idx = key_idx
    while colon_idx < len(text) && text[colon_idx] != 58 {
        colon_idx = colon_idx + 1
    }
    if colon_idx >= len(text) {
        return bpe_normalize_text(text)
    }

    int i = colon_idx + 1
    while i < len(text) && (text[i] == 32 || text[i] == 9) {
        i = i + 1
    }
    if i >= len(text) {
        return ""
    }

    string value = ""
    if text[i] == 34 {
        i = i + 1
        while i < len(text) {
            if text[i] == 92 && i + 1 < len(text) {
                i = i + 1
                value = value + string_char(text[i])
            } else if text[i] == 34 {
                break
            } else {
                value = value + string_char(text[i])
            }
            i = i + 1
        }
        return bpe_normalize_text(value)
    }

    while i < len(text) && text[i] != 44 && text[i] != 125 {
            value = value + string_char(text[i])
        i = i + 1
    }
    bpe_normalize_text(value)
}

func bpe_jsonl_records_to_documents([]string records) []string {
    []string docs = []string{cap: len(records)}
    int i = 0
    while i < len(records) {
        string doc = bpe_extract_jsonl_text(records[i])
        doc = bpe_trim(doc)
        if doc != "" {
            docs.push(doc)
        }
        i = i + 1
    }
    docs
}

func bpe_pack_token_windows([]int token_ids, int seq_len, int stride) [][]int {
    if seq_len <= 0 {
        return [][]int{cap: 0}
    }
    if stride <= 0 {
        stride = seq_len
    }

    [][]int windows = [][]int{cap: 0}
    int start = 0
    while start < len(token_ids) {
        int end = start + seq_len
        if end > len(token_ids) {
            end = len(token_ids)
        }

        []int window = []int{cap: seq_len}
        int i = 0
        while i < seq_len {
            if start + i < end {
                window[i] = token_ids[start + i]
            } else {
                window[i] = 0
            }
            i = i + 1
        }
        windows.push(window)

        if end >= len(token_ids) {
            break
        }
        start = start + stride
    }
    windows
}

func bpe_tokenized_corpus_from_jsonl_records([]string records, int vocab_limit, int min_pair_frequency, float valid_ratio, int seed) bpe_tokenized_corpus_state {
    bpe_tokenized_corpus_from_documents(bpe_jsonl_records_to_documents(records), vocab_limit, min_pair_frequency, valid_ratio, seed)
}

func bpe_split_state_dict(bpe_split_state state) bpe_split_state {
    bpe_split_state {
        train_documents: copy_strings(state.train_documents),
        valid_documents: copy_strings(state.valid_documents),
        valid_ratio: state.valid_ratio,
        seed: state.seed,
    }
}

func bpe_split_load_state_dict(bpe_split_state state, bpe_split_state other) bpe_split_state {
    bpe_split_state {
        train_documents: copy_strings(other.train_documents),
        valid_documents: copy_strings(other.valid_documents),
        valid_ratio: other.valid_ratio,
        seed: other.seed,
    }
}

func bpe_tokenizer_state_dict(bpe_tokenizer_state state) bpe_tokenizer_state {
    bpe_tokenizer_state {
        vocab_limit: state.vocab_limit,
        min_pair_frequency: state.min_pair_frequency,
        vocab: copy_strings(state.vocab),
        merge_lefts: copy_strings(state.merge_lefts),
        merge_rights: copy_strings(state.merge_rights),
        merge_tokens: copy_strings(state.merge_tokens),
        trained: state.trained,
    }
}

func bpe_tokenizer_load_state_dict(bpe_tokenizer_state state, bpe_tokenizer_state other) bpe_tokenizer_state {
    bpe_tokenizer_state {
        vocab_limit: other.vocab_limit,
        min_pair_frequency: other.min_pair_frequency,
        vocab: copy_strings(other.vocab),
        merge_lefts: copy_strings(other.merge_lefts),
        merge_rights: copy_strings(other.merge_rights),
        merge_tokens: copy_strings(other.merge_tokens),
        trained: other.trained,
    }
}

func bpe_tokenized_corpus_state_dict(bpe_tokenized_corpus_state state) bpe_tokenized_corpus_state {
    bpe_tokenized_corpus_state {
        split: bpe_split_state_dict(state.split),
        tokenizer: bpe_tokenizer_state_dict(state.tokenizer),
        train_token_ids: copy_ints(state.train_token_ids),
        valid_token_ids: copy_ints(state.valid_token_ids),
    }
}

func bpe_tokenized_corpus_load_state_dict(bpe_tokenized_corpus_state state, bpe_tokenized_corpus_state other) bpe_tokenized_corpus_state {
    bpe_tokenized_corpus_state {
        split: bpe_split_load_state_dict(state.split, other.split),
        tokenizer: bpe_tokenizer_load_state_dict(state.tokenizer, other.tokenizer),
        train_token_ids: copy_ints(other.train_token_ids),
        valid_token_ids: copy_ints(other.valid_token_ids),
    }
}
