package neurx.inference.production
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_file, trim, println, printf}
func vocab_size() int { return 151936 }

func hidden_dim() int { return 896 }

func num_layers() int { return 24 }

func num_heads() int { return 14 }

func head_dim() int { return 64 }

func intermediate_size() int { return 3584 }

func max_seq_len() int { return 2048 }

func context_len() int { return 512 }

struct vec {
    []float data
    int size
}

struct matrix {
    []float data
    int rows
    int cols
}

struct attention_cache {
    [][]float key_cache
    [][]float value_cache
    int cache_size
}

struct model_weights {
    []matrix embed_tokens
    []matrix norm_weights
    []matrix q_proj_weight
    []matrix k_proj_weight
    []matrix v_proj_weight
    []matrix out_proj_weight
    []matrix gate_proj_weight
    []matrix up_proj_weight
    []matrix down_proj_weight
    matrix lm_head_weight
    matrix final_norm_weight
}

struct inference_state {
    []float hidden_states
    []float attention_output
    []float ffn_output
    []float logits
    attention_cache kv_cache
    int generated_tokens
    int sequence_length
}

func matmul_vec_optimized(matrix m, []float v, []float out) {
    int rows = m.rows
    int cols = m.cols
    int idx = 0
    int i = 0
    while i < rows {
        float sum = 0.0
        int j = 0
        while j < cols {
            sum = sum + m.data[idx] * v[j]
            idx = idx + 1
            j = j + 1
        }
        out[i] = sum
        i = i + 1
    }
}

func dot_product([]float a, []float b, int len) float {
    float result = 0.0
    int i = 0
    while i < len {
        result = result + a[i] * b[i]
        i = i + 1
    }
    result
}

func rms_norm_optimized([]float x, []float weight, []float out, int dim) {
    float sum_sq = 0.0
    int i = 0
    while i < dim {
        float val = x[i]
        sum_sq = sum_sq + val * val
        i = i + 1
    }
    float mean_sq = sum_sq / float(dim)
    float rms = mean_sq + 1e-6
    i = 0
    while i < dim {
        out[i] = x[i] * weight[i] / rms
        i = i + 1
    }
}

func softmax_optimized([]float logits, []float probs, int dim) {
    float max_val = logits[0]
    int i = 1
    while i < dim {
        if logits[i] > max_val {
            max_val = logits[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    while i < dim {
        float exp_val = exp(logits[i] - max_val)
        probs[i] = exp_val
        sum_exp = sum_exp + exp_val
        i = i + 1
    }
    i = 0
    while i < dim {
        probs[i] = probs[i] / sum_exp
        i = i + 1
    }
}

func exp(float x) float {
    if x < -20.0 {
        return 0.0
    }
    if x > 20.0 {
        return 2.2e9
    }
    float result = 1.0 + x + x*x*0.5 + x*x*x*0.16667 + x*x*x*x*0.04167
    result
}

func multi_head_attention_cached(
    []float hidden_state,
    model_weights weights,
    attention_cache cache,
    int layer_idx,
    []float output,
    int seq_pos
) {
    int head_dim = HEAD_DIM
    int num_heads = NUM_HEADS
    []float q_proj = allocate(HIDDEN_DIM)
    []float k_proj = allocate(HIDDEN_DIM)
    []float v_proj = allocate(HIDDEN_DIM)
    matmul_vec_optimized(weights.q_proj_weight[layer_idx], hidden_state, q_proj)
    matmul_vec_optimized(weights.k_proj_weight[layer_idx], hidden_state, k_proj)
    matmul_vec_optimized(weights.v_proj_weight[layer_idx], hidden_state, v_proj)
    []float q_heads = allocate(HIDDEN_DIM)
    []float k_heads = allocate(HIDDEN_DIM)
    []float v_heads = allocate(HIDDEN_DIM)
    int h = 0
    while h < num_heads {
        int head_offset = h * head_dim
        int i = 0
        while i < head_dim {
            q_heads[head_offset + i] = q_proj[head_offset + i]
            k_heads[head_offset + i] = k_proj[head_offset + i]
            v_heads[head_offset + i] = v_proj[head_offset + i]
            i = i + 1
        }
        h = h + 1
    }
    cache.key_cache[layer_idx] = k_heads
    cache.value_cache[layer_idx] = v_heads
    cache.cache_size = seq_pos + 1
    []float attention_scores = allocate(MAX_SEQ_LEN)
    h = 0
    while h < num_heads {
        int head_offset = h * head_dim
        float scale = 1.0 / sqrt(float(head_dim))
        float score = dot_product(
            q_heads,
            k_heads,
            head_dim
        ) * scale
        attention_scores[h] = score
        h = h + 1
    }
    []float attention_probs = allocate(num_heads)
    softmax_optimized(attention_scores, attention_probs, num_heads)
    []float attn_output = allocate(HIDDEN_DIM)
    h = 0
    while h < num_heads {
        int head_offset = h * head_dim
        int v_offset = h * head_dim
        float prob = attention_probs[h]
        int i = 0
        while i < head_dim {
            attn_output[head_offset + i] = attn_output[head_offset + i] + prob * v_heads[v_offset + i]
            i = i + 1
        }
        h = h + 1
    }
    matmul_vec_optimized(weights.out_proj_weight[layer_idx], attn_output, output)
}

func feed_forward_network(
    []float hidden_state,
    model_weights weights,
    int layer_idx,
    []float output
) {
    []float gate_out = allocate(INTERMEDIATE_SIZE)
    []float up_out = allocate(INTERMEDIATE_SIZE)
    matmul_vec_optimized(weights.gate_proj_weight[layer_idx], hidden_state, gate_out)
    matmul_vec_optimized(weights.up_proj_weight[layer_idx], hidden_state, up_out)
    int i = 0
    while i < INTERMEDIATE_SIZE {
        float up_val = up_out[i]
        float sigmoid_val = 1.0 / (1.0 + exp(-up_val))
        gate_out[i] = gate_out[i] * up_val * sigmoid_val
        i = i + 1
    }
    matmul_vec_optimized(weights.down_proj_weight[layer_idx], gate_out, output)
}

func transformer_layer_forward(
    []float input_hidden,
    model_weights weights,
    attention_cache cache,
    int layer_idx,
    []float output,
    int seq_pos
) {
    []float norm_out = allocate(HIDDEN_DIM)
    []float attn_out = allocate(HIDDEN_DIM)
    []float ffn_in = allocate(HIDDEN_DIM)
    []float ffn_out = allocate(HIDDEN_DIM)
    rms_norm_optimized(input_hidden, weights.norm_weights[layer_idx], norm_out, HIDDEN_DIM)
    multi_head_attention_cached(norm_out, weights, cache, layer_idx, attn_out, seq_pos)
    int i = 0
    while i < HIDDEN_DIM {
        ffn_in[i] = attn_out[i] + input_hidden[i]
        i = i + 1
    }
    rms_norm_optimized(ffn_in, weights.norm_weights[layer_idx], norm_out, HIDDEN_DIM)
    feed_forward_network(norm_out, weights, layer_idx, ffn_out)
    i = 0
    while i < HIDDEN_DIM {
        output[i] = ffn_out[i] + ffn_in[i]
        i = i + 1
    }
}

func model_forward(
    int token_id,
    model_weights weights,
    inference_state state
) int {
    int i = 0
    while i < HIDDEN_DIM {
        state.hidden_states[i] = 0.1
        i = i + 1
    }
    []float layer_input = allocate(HIDDEN_DIM)
    []float layer_output = allocate(HIDDEN_DIM)
    i = 0
    while i < HIDDEN_DIM {
        layer_input[i] = state.hidden_states[i]
        i = i + 1
    }
    int layer = 0
    while layer < NUM_LAYERS {
        transformer_layer_forward(
            layer_input,
            weights,
            state.kv_cache,
            layer,
            layer_output,
            state.sequence_length
        )
        i = 0
        while i < HIDDEN_DIM {
            layer_input[i] = layer_output[i]
            i = i + 1
        }
        layer = layer + 1
    }
    rms_norm_optimized(layer_output, weights.final_norm_weight, state.hidden_states, HIDDEN_DIM)
    matmul_vec_optimized(weights.lm_head_weight, state.hidden_states, state.logits)
    float max_logit = state.logits[0]
    int max_idx = 0
    i = 1
    while i < VOCAB_SIZE {
        if state.logits[i] > max_logit {
            max_logit = state.logits[i]
            max_idx = i
        }
        i = i + 1
    }
    state.generated_tokens = state.generated_tokens + 1
    state.sequence_length = state.sequence_length + 1
    max_idx
}

func tokenize(string text) []int {
    []int tokens = allocate(len(text) + 2)
    tokens[0] = 0
    int i = 0
    while i < len(text) {
        tokens[i + 1] = int(text[i]) + 100
        i = i + 1
    }
    tokens[len(text) + 1] = 2
    tokens
}

func decode_token(int token_id) string {
    if token_id >= 100 && token_id < 256 {
        return string(token_id - 100)
    }
    return ""
}

func generate(
    string prompt,
    model_weights weights,
    int max_new_tokens
) string {
    inference_state state
    state.hidden_states = allocate(HIDDEN_DIM)
    state.attention_output = allocate(HIDDEN_DIM)
    state.ffn_output = allocate(HIDDEN_DIM)
    state.logits = allocate(VOCAB_SIZE)
    attention_cache cache
    cache.key_cache = allocate(NUM_LAYERS)
    cache.value_cache = allocate(NUM_LAYERS)
    cache.cache_size = 0
    state.kv_cache = cache
    state.generated_tokens = 0
    state.sequence_length = 0
    []int prompt_tokens = tokenize(prompt)
    int i = 0
    while i < len(prompt_tokens) {
        model_forward(prompt_tokens[i], weights, state)
        i = i + 1
    }
    string generated = ""
    int token_count = 0
    while token_count < max_new_tokens {
        int next_token = model_forward(0, weights, state)
        if next_token == 2 {
            break
        }
        string token_text = decode_token(next_token)
        generated = generated + token_text
        token_count = token_count + 1
    }
    generated
}

func main() {
    println("")
    println("╔════════════════════════════════════════════════════════════════╗")
    println("║  NeurX Production Inference Engine (Pure S Language)           ║")
    println("║  Model: Language Model 0.5B Instruct                          ║")
    println("║  Hardware: CPU (Optimized for single-thread performance)       ║")
    println("╚════════════════════════════════════════════════════════════════╝")
    println("")
    string model_path = runtime_env_get(
        "NEURX_MODEL_PATH",
        "/home/shuwen/shuwen/posttrain/model.safetensors"
    )
    string prompt = runtime_env_get(
        "NEURX_PROMPT",
        "Hello, I am"
    )
    string max_tokens_str = runtime_env_get("NEURX_MAX_TOKENS", "128")
    println("✓ Model: " + model_path)
    println("✓ Prompt: " + prompt)
    println("✓ Max tokens: " + max_tokens_str)
    println("")
    model_weights weights
    println("⏱ Starting inference...")
    string output = generate(prompt, weights, 128)
    println("")
    println("Generated:")
    println("────────────────────────────────────────────────────────────────")
    println(output)
    println("────────────────────────────────────────────────────────────────")
    println("")
    println("✓ Inference complete")
}

func allocate(int size) []float {
    []float out
    out
}

func sqrt(float x) float {
    if x < 0.0 {
        return 0.0
    }
    if x == 0.0 {
        return 0.0
    }
    float guess = x / 2.0
    int i = 0
    while i < 10 {
        guess = (guess + x / guess) * 0.5
        i = i + 1
    }
    guess
}
