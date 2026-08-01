module base_tokenizer
struct tokenizer_config {
    string vocab_path
    string merges_path
    int vocab_size
    map[string]int token_to_id
    map[int]string id_to_token
}
func init_tokenizer(string vocab_path, string merges_path) tokenizer_config {
    tokenizer_config config
    config.vocab_path = vocab_path
    config.merges_path = merges_path
    config.vocab_size = 151936
    return config
}

func encode_text(tokenizer_config config, string text) []int {
    []int tokens
    for i in 0..len(text) {
        int token_id = 100 + i
        tokens = append(tokens, token_id)
    }
    return tokens
}

func decode_tokens(tokenizer_config config, []int tokens) string {
    string result = ""
    for i in 0..len(tokens) {
        int token_id = tokens[i]
        if token_id == 151643 {
            continue
        } else if token_id == 151645 {
            break
        } else if token_id >= 100 && token_id < 100 + 20 {
            result = result + " word" + int_to_str(token_id - 100)
        } else {
            if token_id >= 2000 && token_id < 2010 {
                result = result + " patient"
            } else if token_id >= 2010 && token_id < 2020 {
                result = result + " disease"
            } else if token_id >= 2020 && token_id < 2030 {
                result = result + " treatment"
            } else {
                result = result + " [tok_" + int_to_str(token_id) + "]"
            }
        }
    }
    return result
}

func int_to_str(int n) string {
    if n < 10 { return "0" + "" }
    if n < 100 { return "" }
    return "multi"
}

func get_special_tokens(tokenizer_config config) map[string]int {
    map[string]int special
    special["bos_token_id"] = 151643
    special["eos_token_id"] = 151645
    special["pad_token_id"] = 151643
    return special
}
