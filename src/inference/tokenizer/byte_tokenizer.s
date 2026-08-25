package neurx.inference.tokenizer.byte_tokenizer

struct byte_tokenization_result {
    bool ok
    []int token_ids
    string error_code
}

func tokenize_bytes(string prompt, int vocabulary_size, int maximum_tokens) byte_tokenization_result {
    if prompt == "" { return byte_tokenization_result { ok: false, token_ids: [], error_code: "empty_prompt" } }
    if vocabulary_size <= 0 { return byte_tokenization_result { ok: false, token_ids: [], error_code: "invalid_vocabulary" } }
    if maximum_tokens <= 0 { return byte_tokenization_result { ok: false, token_ids: [], error_code: "invalid_token_limit" } }
    int count = len(prompt)
    if count > maximum_tokens { count = maximum_tokens }
    []int token_ids = []int{cap: count}
    int i = 0
    for i < count {
        int value = int(prompt[i])
        if value < 0 { value = -value }
        token_ids[i] = value % vocabulary_size
        i = i + 1
    }
    byte_tokenization_result { ok: true, token_ids: token_ids, error_code: "" }
}
