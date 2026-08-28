package neurx.attention.core
struct attention_config {
    int hidden_dim
    int num_attention_heads
    int num_kv_heads
    float dropout_rate
    bool use_causal_mask
    string attention_type
}

struct attention_cache {
    float[] key_cache
    float[] value_cache
    int cache_len
}

struct multi_head_attention_module {
    attention_config config
    int head_dim
    int q_proj_dim
    int kv_proj_dim
    float[] wq
    float[] wk
    float[] wv
    float[] wo
    int num_query_groups
}

struct project_qkv_result {
    float[] query
    float[] key
    float[] value
}

func new_multi_head_attention(attention_config cfg) multi_head_attention_module {
    int head_dim = cfg.hidden_dim / cfg.num_attention_heads
    int kv_head_dim = cfg.hidden_dim / cfg.num_kv_heads
    int num_query_groups = cfg.num_attention_heads / cfg.num_kv_heads
    multi_head_attention_module module
    module.config = cfg
    module.head_dim = head_dim
    module.q_proj_dim = cfg.hidden_dim
    module.kv_proj_dim = kv_head_dim * cfg.num_kv_heads
    module.num_query_groups = num_query_groups
    module.wq = allocate_weights(cfg.hidden_dim, cfg.hidden_dim)
    module.wk = allocate_weights(cfg.hidden_dim, cfg.hidden_dim)
    module.wv = allocate_weights(cfg.hidden_dim, cfg.hidden_dim)
    module.wo = allocate_weights(cfg.hidden_dim, cfg.hidden_dim)
    return module
}

func project_qkv(
    multi_head_attention_module attn,
    float[] hidden_states,
    int seq_len,
    int hidden_dim
) project_qkv_result {
    float[] query = matrix_multiply(hidden_states, attn.wq, seq_len, hidden_dim, hidden_dim)
    float[] key = matrix_multiply(hidden_states, attn.wk, seq_len, hidden_dim, hidden_dim)
    float[] value = matrix_multiply(hidden_states, attn.wv, seq_len, hidden_dim, hidden_dim)
    project_qkv_result {
        query: query,
        key: key,
        value: value,
    }
}

func reshape_for_attention(
    float[] x,
    int seq_len,
    int num_heads,
    int head_dim
) float[] {
    int total_size = seq_len * num_heads * head_dim
    float[] reshaped = allocate_vector(total_size, 0.0)
    int idx = 0
    int i = 0
    for i < seq_len * num_heads * head_dim {
        reshaped[i] = x[idx]
        idx = idx + 1
        i = i + 1
    }
    return reshaped
}

func scaled_dot_product_attention(
    float[] query,
    float[] key,
    float[] value,
    int seq_len,
    int num_heads,
    int head_dim,
    bool use_causal_mask
) float[] {
    int size_per_head = seq_len * head_dim
    int total_size = seq_len * num_heads * head_dim
    float[] output = allocate_vector(total_size, 0.0)
    float scale = 1.0 / sqrt_float(head_dim * 1.0)
    int h = 0
    for h < num_heads {
        int q_offset = h * size_per_head
        int k_offset = h * size_per_head
        int v_offset = h * size_per_head
        int i = 0
        for i < seq_len {
            float[] scores = allocate_vector(seq_len, 0.0)
            int j = 0
            for j < seq_len {
                if use_causal_mask && j > i {
                    scores[j] = -10000.0
                } else {
                    float score = 0.0
                    int d = 0
                    for d < head_dim {
                        int q_idx = q_offset + i * head_dim + d
                        int k_idx = k_offset + j * head_dim + d
                        score = score + query[q_idx] * key[k_idx]
                        d = d + 1
                    }
                    scores[j] = score * scale
                }
                j = j + 1
            }
            float[] attn_weights = softmax_stable(scores, seq_len)
            int d = 0
            for d < head_dim {
                float sum_val = 0.0
                j = 0
                for j < seq_len {
                    int v_idx = v_offset + j * head_dim + d
                    sum_val = sum_val + attn_weights[j] * value[v_idx]
                    j = j + 1
                }
                int out_idx = h * size_per_head + i * head_dim + d
                output[out_idx] = sum_val
                d = d + 1
            }
            i = i + 1
        }
        h = h + 1
    }
    return output
}

func forward_attention(
    multi_head_attention_module attn,
    float[] hidden_states,
    int seq_len
) float[] {
    int hidden_dim = attn.config.hidden_dim
    int num_heads = attn.config.num_attention_heads
    int head_dim = attn.head_dim
    project_qkv_result projected = project_qkv(attn, hidden_states, seq_len, hidden_dim)
    float[] query = projected.query
    float[] key = projected.key
    float[] value = projected.value
    float[] query_reshaped = reshape_for_attention(query, seq_len, num_heads, head_dim)
    float[] key_reshaped = reshape_for_attention(key, seq_len, num_heads, head_dim)
    float[] value_reshaped = reshape_for_attention(value, seq_len, num_heads, head_dim)
    float[] attn_output = scaled_dot_product_attention(
        query_reshaped,
        key_reshaped,
        value_reshaped,
        seq_len,
        num_heads,
        head_dim,
        attn.config.use_causal_mask
    )
    float[] concatenated = reshape_from_heads(attn_output, seq_len, num_heads, head_dim)
    float[] output = matrix_multiply(concatenated, attn.wo, seq_len, hidden_dim, hidden_dim)
    return output
}

func softmax_stable(float[] scores, int size) float[] {
    float[] probs = allocate_vector(size, 0.0)
    float max_score = scores[0]
    int i = 1
    for i < size {
        if scores[i] > max_score {
            max_score = scores[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    for i < size {
        float exp_val = exp_float(scores[i] - max_score)
        probs[i] = exp_val
        sum_exp = sum_exp + exp_val
        i = i + 1
    }
    i = 0
    for i < size {
        probs[i] = probs[i] / sum_exp
        i = i + 1
    }
    return probs
}

func matrix_multiply(float[] a, float[] b, int m, int k, int n) float[] {
    float[] result = allocate_vector(m * n, 0.0)
    int i = 0
    for i < m {
        int j = 0
        for j < n {
            float sum = 0.0
            int l = 0
            for l < k {
                int a_idx = i * k + l
                int b_idx = l * n + j
                sum = sum + a[a_idx] * b[b_idx]
                l = l + 1
            }
            int out_idx = i * n + j
            result[out_idx] = sum
            j = j + 1
        }
        i = i + 1
    }
    return result
}

func reshape_from_heads(float[] x, int seq_len, int num_heads, int head_dim) float[] {
    int hidden_dim = num_heads * head_dim
    float[] reshaped = allocate_vector(seq_len * hidden_dim, 0.0)
    int i = 0
    for i < seq_len * hidden_dim {
        reshaped[i] = x[i]
        i = i + 1
    }
    return reshaped
}

func allocate_weights(int rows, int cols) float[] {
    int size = rows * cols
    float[] w = allocate_vector(size, 0.0)
    float limit = sqrt_float(6.0 / (rows + cols * 1.0))
    int i = 0
    for i < size {
        w[i] = limit / 2.0
        i = i + 1
    }
    return w
}

func allocate_vector(int size, float init_val) float[] {
    float[] v = float[]{cap: size}
    int i = 0
    for i < size {
        v = append(v, init_val)
        i = i + 1
    }
    return v
}

func exp_float(float x) float {
    if x > 20.0 {
        return 2147483647.0
    }
    if x < -20.0 {
        return 0.0000001
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    for i <= 15 {
        term = term * x / (i * 1.0)
        result = result + term
        i = i + 1
    }
    return result
}

func sqrt_float(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x / 2.0
    int i = 0
    for i < 10 {
        guess = (guess + x / guess) / 2.0
        i = i + 1
    }
    return guess
}

func len_float(float[] v) int {
    return len(v)
}
