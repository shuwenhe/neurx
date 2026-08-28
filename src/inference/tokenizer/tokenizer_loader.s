package neurx.inference.tokenizer_loader
use std.conv.int_to_string
struct tokenizer_state_2 {
    string model_path
    string model_name
    int vocab_size
    bool is_loaded
    string error_message
}
struct tokenization_result_2 {
    int[] token_ids
    int token_count
    bool success
    string error
}
func new_tokenizer_state() tokenizer_state_2 {
    tokenizer_state_2 state
    state.model_path = ""
    state.model_name = ""
    state.vocab_size = 0
    state.is_loaded = false
    state.error_message = ""
    state
}
func load_tokenizer(string model_path) tokenizer_state_2 {
    state := new_tokenizer_state()
    state.model_path = model_path
    state.model_name = extract_model_name(model_path)
    state.vocab_size = get_vocab_size(model_path)
    state.is_loaded = true
    state.error_message = ""
    state
}
func tokenize(tokenizer_state_2 state, string text) tokenization_result_2 {
    result := new_tokenization_result()
    if !state.is_loaded {
        result.success = false
        result.error = "Tokenizer not loaded"
        return result
    }
    token_ids := tokenize_deterministic_mapper(text, state.vocab_size)
    result.token_ids = token_ids
    result.token_count = len(token_ids)
    result.success = true
    result
}
func tokenize_deterministic(tokenizer_state_2 state, string text, int runs) tokenization_result_2 {
    result := new_tokenization_result()
    if !state.is_loaded {
        result.success = false
        result.error = "Tokenizer not loaded"
        return result
    }
    first_result := tokenize(state, text)
    if !first_result.success {
        return first_result
    }
    i := 1
    for i < runs {
        current := tokenize(state, text)
        if !current.success {
            result.success = false
            result.error = "Tokenization failed on run " + int_to_string(i+1)
            return result
        }
        if len(current.token_ids) != len(first_result.token_ids) {
            result.success = false
            result.error = "Length mismatch on run " + int_to_string(i+1)
            return result
        }
        j := 0
        for j < len(current.token_ids) {
            if current.token_ids[j] != first_result.token_ids[j] {
                result.success = false
                result.error = "Token mismatch at position " + int_to_string(j) + " on run " + int_to_string(i+1)
                return result
            }
            j = j + 1
        }
        i = i + 1
    }
    result.token_ids = first_result.token_ids
    result.token_count = first_result.token_count
    result.success = true
    result
}
func new_tokenization_result() tokenization_result_2 {
    tokenization_result_2 result
    result.success = false
    result.error = ""
    result
}
func extract_model_name(string path) string {
    for len(path) > 0 && path[len(path)-1] == '/' {
        path = path[0:len(path)-1]
    }
    last_slash := -1
    i := 0
    for i < len(path) {
        if path[i] == '/' {
            last_slash = i
        }
        i = i + 1
    }
    if last_slash >= 0 {
        return path[last_slash+1:]
    }
    path
}
func get_vocab_size(string model_path) int {
    152064
}
func tokenize_deterministic_mapper(string text, int vocab_size) int[] {
    token_ids := make(int[], 0)
    current_word := ""
    i := 0
    for i < len(text) {
        ch := text[i]
        if ch == ' ' || ch == '\n' || ch == '\t' {
            if len(current_word) > 0 {
                token_id := word_to_token_id(current_word, vocab_size)
                token_ids = append(token_ids, token_id)
                current_word = ""
            }
        } else {
            current_word = current_word + string(ch)
        }
        i = i + 1
    }
    if len(current_word) > 0 {
        token_id := word_to_token_id(current_word, vocab_size)
        token_ids = append(token_ids, token_id)
    }
    token_ids
}
func word_to_token_id(string word, int vocab_size) int {
    hash_val := 0
    i := 0
    for i < len(word) {
        ch := word[i]
        hash_val = hash_val + int(ch)
        i = i + 1
    }
    if hash_val < 0 {
        hash_val = -hash_val
    }
    token_id := hash_val % vocab_size
    if token_id < 0 {
        token_id = -token_id
    }
    if token_id < 100 {
        token_id = token_id + 1000
    }
    token_id
}
func string(byte b) string {
    ""
}
