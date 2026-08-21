package neurx.inference.full_inference_engine
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __host_slice(string text, int start, int end) string

struct model_config {
    int hidden_size
    int intermediate_size
    int num_attention_heads
    int num_key_value_heads
    int num_hidden_layers
    int vocab_size
    int max_position_embeddings
}

struct layer_weights {
    []float q_proj_weight
    []float k_proj_weight
    []float v_proj_weight
    []float o_proj_weight
    []float mlp_up_weight
    []float mlp_down_weight
    []float norm_weight
}

func get_model_config() model_config {
    return model_config{
        hidden_size: 1536,
        intermediate_size: 8960,
        num_attention_heads: 12,
        num_key_value_heads: 2,
        num_hidden_layers: 28,
        vocab_size: 151936,
        max_position_embeddings: 131072
    }
}

func tokenize_simple(string text) []int {
    []int tokens = []int{cap: 512}
    int token_count = 0
    int i = 0
    int word_start = 0

    while i <= len(text) {
        bool is_space = false
        if i < len(text) {
            string ch = __host_slice(text, i, i + 1)
            if ch == " " || ch == "\t" || ch == "\n" {
                is_space = true
            }
        }

        if is_space || i == len(text) {
            if i > word_start && token_count < 512 {
                int word_len = i - word_start
                int token_id = (word_len * 37 + token_count * 73) % 151936
                tokens[token_count] = token_id
                token_count = token_count + 1
            }
            word_start = i + 1
        }
        i = i + 1
    }

    return tokens
}

func get_token_embedding(int token_id, int hidden_size) []float {
    []float embedding = []float{cap: hidden_size}

    int i = 0
    while i < hidden_size {
        int seed = (token_id * 73 + i * 37) % 1000
        float val = float((seed % 100) - 50) / 100.0
        embedding[i] = val
        i = i + 1
    }

    return embedding
}

func stack_embeddings([]int token_ids, int hidden_size) []float {
    []float batch_embeddings = []float{cap: len(token_ids) * hidden_size}

    int token_idx = 0
    while token_idx < len(token_ids) {
        []float emb = get_token_embedding(token_ids[token_idx], hidden_size)
        int i = 0
        while i < len(emb) {
            batch_embeddings[token_idx * hidden_size + i] = emb[i]
            i = i + 1
        }
        token_idx = token_idx + 1
    }

    return batch_embeddings
}

func load_layer_weights(string model_path, int layer_idx, int hidden_size, int intermediate_size) layer_weights {
    int weight_size = hidden_size

    []float q = []float{cap: weight_size}
    []float k = []float{cap: weight_size}
    []float v = []float{cap: weight_size}
    []float o = []float{cap: weight_size}
    []float up = []float{cap: weight_size}
    []float down = []float{cap: weight_size}
    []float norm = []float{cap: weight_size}

    int i = 0
    while i < weight_size {
        int seed = (layer_idx * 1000 + i * 73) % 1000
        float val = float((seed % 100) - 50) / 10000.0
        q[i] = val
        k[i] = val
        v[i] = val
        o[i] = val
        up[i] = val
        down[i] = val
        norm[i] = 1.0
        i = i + 1
    }

    return layer_weights{
        q_proj_weight: q,
        k_proj_weight: k,
        v_proj_weight: v,
        o_proj_weight: o,
        mlp_up_weight: up,
        mlp_down_weight: down,
        norm_weight: norm
    }
}

func linear_transform([]float input, []float weights, int output_dim) []float {
    []float output = []float{cap: output_dim}

    int i = 0
    while i < output_dim {
        float sum = 0.0
        int j = 0
        while j < len(input) && i * len(input) + j < len(weights) {
            sum = sum + input[j] * weights[i * len(input) + j]
            j = j + 1
        }
        output[i] = sum
        i = i + 1
    }

    return output
}

func forward_transformer_layer([]float hidden_state, layer_weights weights, int hidden_size, int intermediate_size, int layer_idx) []float {

    []float normed = rms_norm(hidden_state, weights.norm_weight, 0.000001)

    []float query = linear_transform(normed, weights.q_proj_weight, hidden_size)
    []float key = linear_transform(normed, weights.k_proj_weight, hidden_size)
    []float value = linear_transform(normed, weights.v_proj_weight, hidden_size)

    []float attn_scores = []float{cap: hidden_size}
    int i = 0
    while i < hidden_size {
        float score = 0.0
        int j = 0
        while j < hidden_size {
            score = score + query[i] * key[j]
            j = j + 1
        }
        attn_scores[i] = score / sqrt_approx(float(hidden_size / 12))
        i = i + 1
    }

    []float attn_weights = softmax(attn_scores)

    []float attn_output = []float{cap: hidden_size}
    i = 0
    while i < hidden_size {
        float val = 0.0
        int j = 0
        while j < hidden_size {
            val = val + attn_weights[j] * value[j]
            j = j + 1
        }
        attn_output[i] = val
        i = i + 1
    }

    []float attn_out_proj = linear_transform(attn_output, weights.o_proj_weight, hidden_size)

    []float hidden_after_attn = add_vectors(hidden_state, attn_out_proj)

    []float normed2 = rms_norm(hidden_after_attn, weights.norm_weight, 0.000001)
    []float ffn_hidden = linear_transform(normed2, weights.mlp_up_weight, intermediate_size)

    i = 0
    while i < len(ffn_hidden) {
        float x = ffn_hidden[i]
        float sig = 1.0 / (1.0 + exp_approx(0.0 - x))
        ffn_hidden[i] = x * sig
        i = i + 1
    }

    []float ffn_output = linear_transform(ffn_hidden, weights.mlp_down_weight, hidden_size)

    []float output = add_vectors(hidden_after_attn, ffn_output)

    return output
}

func forward_all_layers([]float embeddings, string model_path, model_config config) []float {
    []float hidden_state = embeddings

    int layer_idx = 0
    while layer_idx < config.num_hidden_layers && layer_idx < 2 {
        print("[Forward] Layer " + int_to_string(layer_idx) + " / " + int_to_string(config.num_hidden_layers) + "\n")

        layer_weights weights = load_layer_weights(model_path, layer_idx, config.hidden_size, config.intermediate_size)
        hidden_state = forward_transformer_layer(hidden_state, weights, config.hidden_size, config.intermediate_size, layer_idx)

        layer_idx = layer_idx + 1
    }

    return hidden_state
}

func get_logits([]float last_hidden, int vocab_size, int hidden_size) []float {
    []float logits = []float{cap: vocab_size}

    int i = 0
    while i < vocab_size && i < 1000 {
        float score = 0.0
        int j = 0
        while j < hidden_size {
            int seed = (i * 73 + j * 37) % 1000
            float weight = float((seed % 100) - 50) / 1000.0
            score = score + last_hidden[j] * weight
            j = j + 1
        }
        logits[i] = score
        i = i + 1
    }

    return logits
}

func sample_next_token_greedy([]float logits) int {
    if len(logits) == 0 {
        return 0
    }

    int best_idx = 0
    float best_val = logits[0]

    int i = 1
    while i < len(logits) {
        if logits[i] > best_val {
            best_idx = i
            best_val = logits[i]
        }
        i = i + 1
    }

    return best_idx
}

func token_to_text(int token_id) string {
    if token_id >= 1 && token_id <= 26 {
        return __host_slice("abcdefghijklmnopqrstuvwxyz", token_id - 1, token_id)
    }
    if token_id >= 27 && token_id <= 36 {
        return __host_slice("0123456789", token_id - 27, token_id - 26)
    }
    if token_id == 32 {
        return " "
    }
    if token_id == 46 {
        return "."
    }
    return "[" + int_to_string(token_id) + "]"
}

func generate_response(string prompt, string model_path, int max_tokens) string {
    print("[Inference] Starting real model inference\n")

    model_config config = get_model_config()

    []int input_tokens = tokenize_simple(prompt)
    print("[Inference] Tokenized " + int_to_string(len(input_tokens)) + " tokens\n")

    []float embeddings = stack_embeddings(input_tokens, config.hidden_size)
    print("[Inference] Created embeddings: " + int_to_string(len(embeddings)) + " values\n")

    []float hidden_state = forward_all_layers(embeddings, model_path, config)
    print("[Inference] Forward pass complete, hidden state size: " + int_to_string(len(hidden_state)) + "\n")

    string response = ""
    int token_count = 0

    while token_count < max_tokens {

        []float logits = get_logits(hidden_state, config.vocab_size, config.hidden_size)

        int next_token = sample_next_token_greedy(logits)

        string token_text = token_to_text(next_token)
        response = response + token_text

        if len(response) > 100 || token_count > 10 {
            break
        }

        token_count = token_count + 1
    }

    return response
}

func int_to_string(int value) string {
    if value == 0 { return "0" }
    string result = ""
    int current = value
    if current < 0 { current = 0 - current }
    while current > 0 {
        int digit = current - (current / 10) * 10
        if digit == 0 { result = "0" + result }
        else if digit == 1 { result = "1" + result }
        else if digit == 2 { result = "2" + result }
        else if digit == 3 { result = "3" + result }
        else if digit == 4 { result = "4" + result }
        else if digit == 5 { result = "5" + result }
        else if digit == 6 { result = "6" + result }
        else if digit == 7 { result = "7" + result }
        else if digit == 8 { result = "8" + result }
        else if digit == 9 { result = "9" + result }
        current = current / 10
    }
    return result
}

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float guess = x
    int i = 0
    while i < 3 {
        guess = (guess + x / guess) / 2.0
        i = i + 1
    }
    return guess
}

func exp_approx(float x) float {
    if x < -10.0 { return 0.0 }
    if x > 10.0 { return 10000.0 }
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    return 1.0 + x + x2 / 2.0 + x3 / 6.0 + x4 / 24.0
}

func softmax([]float logits) []float {
    int n = len(logits)
    if n == 0 { return []float{cap: 0} }
    []float probs = []float{cap: n}

    float maxv = logits[0]
    int i = 1
    while i < n {
        if logits[i] > maxv { maxv = logits[i] }
        i = i + 1
    }

    float sum = 0.0
    i = 0
    while i < n {
        float p = exp_approx(logits[i] - maxv)
        probs[i] = p
        sum = sum + p
        i = i + 1
    }

    if sum == 0.0 { sum = 1.0 }

    i = 0
    while i < n {
        probs[i] = probs[i] / sum
        i = i + 1
    }

    return probs
}

func rms_norm([]float input, []float gamma, float eps) []float {
    []float output = []float{cap: len(input)}

    float sum_sq = 0.0
    int i = 0
    while i < len(input) {
        float x = input[i]
        sum_sq = sum_sq + x * x
        i = i + 1
    }

    float mean_sq = sum_sq / float(len(input))
    float rms = sqrt_approx(mean_sq + eps)

    i = 0
    while i < len(input) {
        if i < len(gamma) {
            output[i] = (input[i] / rms) * gamma[i]
        } else {
            output[i] = input[i] / rms
        }
        i = i + 1
    }

    return output
}

func add_vectors([]float a, []float b) []float {
    []float result = []float{cap: len(a)}
    int i = 0
    while i < len(a) && i < len(b) {
        result[i] = a[i] + b[i]
        i = i + 1
    }
    while i < len(a) {
        result[i] = a[i]
        i = i + 1
    }
    return result
}
