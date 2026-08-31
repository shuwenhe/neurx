package step5_sampling_step6_decode
struct sampling_config {
    string strategy
    float temperature
    int top_k
    float top_p
}

func create_sampling_config() sampling_config {
    return sampling_config{
        strategy: "top_k",
        temperature: 1.0,
        top_k: 40,
        top_p: 0.9
    }
}

func greedy_sample(float[] logits) int {
    int max_idx = 0
    float max_val = logits[0]
    int i = 1
    for i < len(logits) {
        if logits[i] > max_val {
            max_val = logits[i]
            max_idx = i
        }
        i = i + 1
    }
    return max_idx
}

func top_k_sample(float[] logits, int k) int {
    return greedy_sample(logits)
}

func top_p_sample(float[] logits, float p) int {
    return greedy_sample(logits)
}

func sample(float[] logits, sampling_config config) int {
    if config.strategy == "greedy" {
        return greedy_sample(logits)
    }
    if config.strategy == "top_k" {
        return top_k_sample(logits, config.top_k)
    }
    if config.strategy == "top_p" {
        return top_p_sample(logits, config.top_p)
    }
    return greedy_sample(logits)
}

struct vocab_decoder {
    map[int, string] id_to_token
}

func create_vocab_decoder() vocab_decoder {
    return vocab_decoder{
        id_to_token: map[int, string]{}
    }
}

func load_vocab(string vocab_path) map[int, string] {
    return map[int, string]{}
}

func decode_token(int token_id, map[int, string] vocab) string {
    if token_id == 151643 {
        return ""
    }
    if token_id == 151644 {
        return ""
    }
    if token_id == 151645 {
        return ""
    }
    return "█"
}

func decode_tokens(int[] token_ids) string {
    string result = ""
    int i = 0
    for i < len(token_ids) {
        result = result + decode_token(token_ids[i], map[int, string]{})
        i = i + 1
    }
    return result
}

func generate(int[] prompt_tokens, int max_new_tokens, sampling_config config) []int {
    int[] result = make(int[], len(prompt_tokens))
    int i = 0
    for i < len(prompt_tokens) {
        result[i] = prompt_tokens[i]
        i = i + 1
    }
    int gen_tokens = 0
    for gen_tokens < max_new_tokens {
        float[] logits = make(float[], 4)
        logits[0] = 1.0
        logits[1] = 0.2
        logits[2] = 0.1
        logits[3] = 0.0
        int next_token = sample(logits, config)
        append(result, next_token)
        if next_token == 151643 {
            gen_tokens = max_new_tokens
        }
        gen_tokens = gen_tokens + 1
    }
    return result
}
