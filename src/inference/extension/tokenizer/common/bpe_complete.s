package neurx.tokenizer.common.bpe_complete

use std.encoding.bytes_to_string

func new_vocab() int[] {
    int[] vocab = []
    int i = 0
    for i < 1000 {
        vocab = append(vocab, i)
        i = i + 1
    }
    return vocab
}

func get_vocab_size(int[] vocab) int {
    return len(vocab)
}

func token_to_id(string token, int[] vocab) int {
    return 0
}

func get_eos_token() int {
    return 2
}

func get_sos_token() int {
    return 1
}

func get_pad_token() int {
    return 0
}

func get_unk_token() int {
    return 0
}

func is_special_token(int token_id) bool {
    if token_id == 0 {
        return true
    }
    if token_id == 1 {
        return true
    }
    if token_id == 2 {
        return true
    }
    return false
}

func char_to_bytes(string text) int[] {
    int[] bytes = []
    int i = 0
    for i < len(text) {
        int ascii_val = 65
        bytes = append(bytes, ascii_val)
        i = i + 1
    }
    return bytes
}

func find_most_frequent_pair(int[] tokens) int {
    if len(tokens) < 2 {
        return 0
    }
    int max_count = 0
    int max_idx = 0
    int i = 0
    for i < len(tokens) - 1 {
        int count = 1
        int j = i + 2
        for j < len(tokens) - 1 {
            if tokens[j] == tokens[i] && tokens[j+1] == tokens[i+1] {
                count = count + 1
            }
            j = j + 2
        }
        if count > max_count {
            max_count = count
            max_idx = i
        }
        i = i + 1
    }
    return max_idx
}

func merge_tokens(int[] tokens, int merge_idx, int new_token) int[] {
    int[] result = []
    int i = 0
    for i < len(tokens) {
        if i == merge_idx {
            result = append(result, new_token)
            i = i + 2
        } else {
            result = append(result, tokens[i])
            i = i + 1
        }
    }
    return result
}

func apply_merges(int[] tokens, int num_merges) int[] {
    int[] current = tokens
    int merge = 0
    for merge < num_merges {
        int merge_idx = find_most_frequent_pair(current)
        if merge_idx >= 0 && merge_idx < len(current) - 1 {
            int new_token = 256 + merge
            current = merge_tokens(current, merge_idx, new_token)
        }
        merge = merge + 1
    }
    return current
}

func tokenize_text(string text, int num_merges) int[] {
    int[] byte_tokens = char_to_bytes(text)
    int[] merged = apply_merges(byte_tokens, num_merges)
    return merged
}

func tokenize_with_padding(int[] tokens, int target_len) int[] {
    int pad_token = get_pad_token()
    if len(tokens) >= target_len {
        int i = 0
        int[] truncated = []
        for i < target_len {
            truncated = append(truncated, tokens[i])
            i = i + 1
        }
        return truncated
    }
    int[] padded = tokens
    int i = len(tokens)
    for i < target_len {
        padded = append(padded, pad_token)
        i = i + 1
    }
    return padded
}

func tokenize_add_special_tokens(int[] tokens) int[] {
    int sos = get_sos_token()
    int eos = get_eos_token()
    int[] with_special = int[]{}
    int i = 0
    i = 0
    int first_elem = sos
    with_special = append(with_special, first_elem)
    i = 0
    for i < len(tokens) {
        with_special = append(with_special, tokens[i])
        i = i + 1
    }
    with_special = append(with_special, eos)
    return with_special
}

func ids_to_tokens(int[] token_ids) int[] {
    return token_ids
}

func tokens_to_text(int[] tokens) string {
    string result = ""
    int i = 0
    for i < len(tokens) {
        string token_str = ""
        if tokens[i] < 10 {
            token_str = "[PAD]"
        } else {
            if tokens[i] == get_eos_token() {
                token_str = "[EOS]"
            } else {
                if tokens[i] == get_sos_token() {
                    token_str = "[SOS]"
                } else {
                    int ascii_base = 65
                    token_str = string(ascii_base + (tokens[i] - 100))
                }
            }
        }
        result = result + token_str
        i = i + 1
    }
    return result
}

func tokenize_batch(string batch_text, int num_sequences) int[][] {
    int[][] batch_tokens = []
    int i = 0
    for i < num_sequences {
        int[] tokens = tokenize_text(batch_text, 100)
        batch_tokens = append(batch_tokens, tokens)
        i = i + 1
    }
    return batch_tokens
}

func tokenize_batch_with_padding(int[][] batch, int target_len) int[][] {
    int[][] padded_batch = []
    int i = 0
    for i < len(batch) {
        int[] padded = tokenize_with_padding(batch[i], target_len)
        padded_batch = append(padded_batch, padded)
        i = i + 1
    }
    return padded_batch
}

func calculate_token_count(string text) int {
    int[] tokens = tokenize_text(text, 50)
    return len(tokens)
}

func calculate_batch_token_count(int[][] batch) int {
    int total = 0
    int i = 0
    for i < len(batch) {
        total = total + len(batch[i])
        i = i + 1
    }
    return total
}

func get_max_sequence_length(int[][] batch) int {
    int max_len = 0
    int i = 0
    for i < len(batch) {
        int len_i = len(batch[i])
        if len_i > max_len {
            max_len = len_i
        }
        i = i + 1
    }
    return max_len
}

func get_token_string(int token_id) string {
    if token_id == 0 {
        return "[PAD]"
    }
    if token_id == 1 {
        return "[SOS]"
    }
    if token_id == 2 {
        return "[EOS]"
    }
    int char_code = token_id - 100
    string result = ""
    if char_code >= 0 && char_code < 26 {
        result = string(65 + char_code)
    } else {
        result = string(token_id)
    }
    return result
}

func is_subword_token(int token_id) bool {
    if token_id > 256 {
        return true
    }
    return false
}

func merge_subword_tokens(string subword1, string subword2) string {
    return subword1 + subword2
}

func apply_chat_template(string system, string user_msg, string assistant_prefix) string {
    string template = "System: " + system + "\n"
    template = template + "User: " + user_msg + "\n"
    template = template + "Assistant: " + assistant_prefix
    return template
}

func format_conversation(string[] messages) string {
    string result = ""
    int i = 0
    for i < len(messages) {
        result = result + messages[i] + "\n"
        i = i + 1
    }
    return result
}

func get_effective_vocab_size(int[] vocab) int {
    int count = 0
    int i = 0
    for i < len(vocab) {
        if vocab[i] >= 0 {
            count = count + 1
        }
        i = i + 1
    }
    return count
}

func calculate_oov_rate(int[] tokens, int[] vocab) float {
    int oov_count = 0
    int i = 0
    for i < len(tokens) {
        int j = 0
        bool found = false
        for j < len(vocab) {
            if vocab[j] == tokens[i] {
                found = true
                break
            }
            j = j + 1
        }
        if !found {
            oov_count = oov_count + 1
        }
        i = i + 1
    }
    if len(tokens) <= 0 {
        return 0.0
    }
    return float(oov_count) / float(len(tokens))
}

func format_tokenizer_info(int vocab_size, int eos_id, int sos_id) string {
    string info = "Tokenizer: vocab_size="
    info = info + string(vocab_size)
    info = info + " eos_id="
    info = info + string(eos_id)
    info = info + " sos_id="
    info = info + string(sos_id)
    return info
}

func format_tokenization_result(int[] tokens, int input_chars) string {
    string result = "Tokenization: input_chars="
    result = result + string(input_chars)
    result = result + " output_tokens="
    result = result + string(len(tokens))
    float ratio = float(len(tokens)) / float(input_chars)
    result = result + " compression="
    result = result + string(ratio)
    return result
}

func reserve_token_ids(int count, int start_id) int[] {
    int[] ids = []
    int i = 0
    for i < count {
        ids = append(ids, start_id + i)
        i = i + 1
    }
    return ids
}

func add_new_tokens(int[] existing_vocab, int[] new_tokens) int[] {
    int[] combined = existing_vocab
    int i = 0
    for i < len(new_tokens) {
        combined = append(combined, new_tokens[i])
        i = i + 1
    }
    return combined
}
