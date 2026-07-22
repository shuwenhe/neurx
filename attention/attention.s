package neurx.attention

use neurx.model.transformer.norm.{rope_embedding, rope_apply_result, apply_rope}
use neurx.attention.flash_compute

struct attention_config {
    int hidden_dim
    int num_heads
    int num_key_value_heads
    float dropout_rate
    float attention_dropout_rate
    bool use_cache
    bool use_qkv_bias
    string attention_type
    bool use_flash_attention
}

struct multi_head_attention {
    attention_config config
    int head_dim
    int kv_head_dim
    []float query_weight
    []float key_weight
    []float value_weight
    []float output_weight
    []float query_bias
    []float key_bias
    []float value_bias
    []float output_bias
}

struct project_qkv_result {
    []float query
    []float key
    []float value
}

func allocate_vector(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    while i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func copy_vector([]float src) []float {
    []float out = allocate_vector(len(src), 0.0)
    int i = 0
    while i < len(src) {
        out[i] = src[i]
        i = i + 1
    }
    out
}

func exp_approx(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 12 {
        term = term * x / (i * 1.0)
        result = result + term
        i = i + 1
    }
    result
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = x
    int i = 0
    while i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func new_attention_config(int hidden_dim, int num_heads, int num_key_value_heads, string attention_type) attention_config {
    attention_config {
        hidden_dim: hidden_dim,
        num_heads: num_heads,
        num_key_value_heads: num_key_value_heads,
        dropout_rate: 0.0,
        attention_dropout_rate: 0.0,
        use_cache: false,
        use_qkv_bias: false,
        attention_type: attention_type,
        use_flash_attention: false,
    }
}

func fill_ramp(int size, float scale) []float {
    []float values = allocate_vector(size, 0.0)
    int i = 0
    while i < size {
        values[i] = scale * ((i + 1) * 1.0) / ((size + 1) * 1.0)
        i = i + 1
    }
    values
}

func new_multi_head_attention(attention_config cfg) multi_head_attention {
    int head_dim = cfg.hidden_dim / cfg.num_heads
    int kv_head_dim = cfg.hidden_dim / cfg.num_key_value_heads
    int weight_size = cfg.hidden_dim * cfg.hidden_dim
    multi_head_attention {
        config: cfg,
        head_dim: head_dim,
        kv_head_dim: kv_head_dim,
        query_weight: fill_ramp(weight_size, 0.02),
        key_weight: fill_ramp(weight_size, 0.018),
        value_weight: fill_ramp(weight_size, 0.019),
        output_weight: fill_ramp(weight_size, 0.02),
        query_bias: allocate_vector(cfg.hidden_dim, 0.0),
        key_bias: allocate_vector(cfg.hidden_dim, 0.0),
        value_bias: allocate_vector(cfg.hidden_dim, 0.0),
        output_bias: allocate_vector(cfg.hidden_dim, 0.0),
    }
}

func matmul_flat([]float a, []float b, int m, int k, int n) []float {
    []float result = allocate_vector(m * n, 0.0)
    int i = 0
    while i < m {
        int j = 0
        while j < n {
            float sum = 0.0
            int l = 0
            while l < k {
                sum = sum + a[i * k + l] * b[l * n + j]
                l = l + 1
            }
            result[i * n + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    result
}

func apply_bias([]float values, []float bias) []float {
    if len(bias) == 0 {
        return copy_vector(values)
    }
    []float out = copy_vector(values)
    int i = 0
    while i < len(out) {
        out[i] = out[i] + bias[i % len(bias)]
        i = i + 1
    }
    out
}

func softmax_row([]float row, int size) []float {
    []float out = allocate_vector(size, 0.0)
    float max_val = row[0]
    int i = 1
    while i < size {
        if row[i] > max_val {
            max_val = row[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    while i < size {
        float e = exp_approx(row[i] - max_val)
        out[i] = e
        sum_exp = sum_exp + e
        i = i + 1
    }
    if sum_exp > 0.0 {
        i = 0
        while i < size {
            out[i] = out[i] / sum_exp
            i = i + 1
        }
    }
    out
}

func project_qkv(
    multi_head_attention attn,
    []float hidden_states,
    int seq_len
) project_qkv_result {
    int hidden_dim = attn.config.hidden_dim
    []float query = apply_bias(matmul_flat(hidden_states, attn.query_weight, seq_len, hidden_dim, hidden_dim), attn.query_bias)
    []float key = apply_bias(matmul_flat(hidden_states, attn.key_weight, seq_len, hidden_dim, hidden_dim), attn.key_bias)
    []float value = apply_bias(matmul_flat(hidden_states, attn.value_weight, seq_len, hidden_dim, hidden_dim), attn.value_bias)
    project_qkv_result {
        query: query,
        key: key,
        value: value,
    }
}

func attention_core(
    multi_head_attention attn,
    []float query,
    []float key,
    []float value,
    int seq_len
) []float {
    int hidden_dim = attn.config.hidden_dim
    int num_heads = attn.config.num_heads
    int num_kv_heads = attn.config.num_key_value_heads
    int head_dim = attn.head_dim
    int q_block = seq_len * head_dim
    []float output = allocate_vector(seq_len * hidden_dim, 0.0)
    float scale = 1.0 / sqrt_approx(head_dim * 1.0)

    int h = 0
    while h < num_heads {
        int kv_head = h
        if num_kv_heads > 0 {
            kv_head = h % num_kv_heads
        }
        int q_offset = h * q_block
        int kv_offset = kv_head * q_block

        int i = 0
        while i < seq_len {
            []float scores = allocate_vector(seq_len, 0.0)
            int j = 0
            while j < seq_len {
                float score = 0.0
                int d = 0
                while d < head_dim {
                    score = score + query[q_offset + i * head_dim + d] * key[kv_offset + j * head_dim + d]
                    d = d + 1
                }
                scores[j] = score * scale
                if attn.config.attention_type == "causal" && j > i {
                    scores[j] = -10000.0
                }
                j = j + 1
            }

            []float weights = softmax_row(scores, seq_len)
            int d = 0
            while d < head_dim {
                float sum_val = 0.0
                j = 0
                while j < seq_len {
                    sum_val = sum_val + weights[j] * value[kv_offset + j * head_dim + d]
                    j = j + 1
                }
                output[h * q_block + i * head_dim + d] = sum_val
                d = d + 1
            }
            i = i + 1
        }
        h = h + 1
    }

    output
}

func forward_attention(
    multi_head_attention attn,
    []float hidden_states,
    int seq_len
) []float {
    project_qkv_result projected = project_qkv(attn, hidden_states, seq_len)
    forward_attention_projected(attn, projected.query, projected.key, projected.value, seq_len)
}

func forward_attention_projected(
    multi_head_attention attn,
    []float query,
    []float key,
    []float value,
    int seq_len
) []float {
    []float attended = attention_core(attn, query, key, value, seq_len)
    int hidden_dim = attn.config.hidden_dim
    []float output = matmul_flat(attended, attn.output_weight, seq_len, hidden_dim, hidden_dim)
    output = apply_bias(output, attn.output_bias)
    output
}

func forward_attention_with_rope(
    multi_head_attention attn,
    []float hidden_states,
    int batch_size,
    int seq_len,
    rope_embedding rope
) []float {
    int total_tokens = batch_size * seq_len
    project_qkv_result projected = project_qkv(attn, hidden_states, total_tokens)
    rope_apply_result rotated = apply_rope(
        rope,
        projected.query,
        projected.key,
        batch_size,
        attn.config.num_heads,
        seq_len,
        attn.head_dim
    )
    forward_attention_projected(attn, rotated.query, rotated.key, projected.value, total_tokens)
}

func forward_gqa(
    multi_head_attention attn,
    []float hidden_states,
    int seq_len
) []float {
    forward_attention(attn, hidden_states, seq_len)
}

func forward_flash_attention(
    multi_head_attention attn,
    []float hidden_states,
    int seq_len
) []float {
    int hidden_dim = attn.config.hidden_dim
    int num_heads = attn.config.num_heads
    int head_dim = attn.head_dim
    int total_tokens = seq_len

    project_qkv_result projected = project_qkv(attn, hidden_states, total_tokens)

    flash_compute.flash_attention_config config = flash_compute.new_flash_attention_config()
    config.enable_sequence_parallel = false

    flash_compute.flash_attention_state state = flash_compute.new_flash_attention_state(
        1, seq_len, num_heads, head_dim, config
    )

    []float causal_mask = allocate_vector(seq_len * seq_len, 1.0)
    int i = 0
    while i < seq_len {
        int j = i + 1
        while j < seq_len {
            causal_mask[i * seq_len + j] = 0.0
            j = j + 1
        }
        i = i + 1
    }

    []float q_reshaped = reshape_for_flash(projected.query, seq_len, num_heads, head_dim)
    []float k_reshaped = reshape_for_flash(projected.key, seq_len, num_heads, head_dim)
    []float v_reshaped = reshape_for_flash(projected.value, seq_len, num_heads, head_dim)

    []float attended = flash_compute.flash_attention_forward(
        q_reshaped, k_reshaped, v_reshaped, causal_mask, state
    )

    []float attended_flat = reshape_from_flash(attended, seq_len, num_heads, head_dim)

    []float output = matmul_flat(attended_flat, attn.output_weight, seq_len, hidden_dim, hidden_dim)
    output = apply_bias(output, attn.output_bias)

    output
}

func reshape_for_flash([]float input, int seq_len, int num_heads, int head_dim) []float {
    int hidden_dim = num_heads * head_dim
    []float output = allocate_vector(seq_len * num_heads * head_dim, 0.0)

    int i = 0
    while i < seq_len {
        int h = 0
        while h < num_heads {
            int d = 0
            while d < head_dim {
                output[h * seq_len * head_dim + i * head_dim + d] = input[i * hidden_dim + h * head_dim + d]
                d = d + 1
            }
            h = h + 1
        }
        i = i + 1
    }

    output
}

func reshape_from_flash([]float input, int seq_len, int num_heads, int head_dim) []float {
    int hidden_dim = num_heads * head_dim
    []float output = allocate_vector(seq_len * hidden_dim, 0.0)

    int i = 0
    while i < seq_len {
        int h = 0
        while h < num_heads {
            int d = 0
            while d < head_dim {
                output[i * hidden_dim + h * head_dim + d] = input[h * seq_len * head_dim + i * head_dim + d]
                d = d + 1
            }
            h = h + 1
        }
        i = i + 1
    }

    output
}

func forward_with_cache(
    multi_head_attention attn,
    []float query_states,
    []float kv_cache_key,
    []float kv_cache_value,
    int cache_position_id
) []float {

    forward_attention(attn, query_states, cache_position_id + 1)
}

func apply_causal_mask(
    []float attention_scores,
    int seq_len
) []float {
    []float out = copy_vector(attention_scores)
    int i = 0
    while i < seq_len {
        int j = i + 1
        while j < seq_len {
            out[i * seq_len + j] = -10000.0
            j = j + 1
        }
        i = i + 1
    }
    out
}

func apply_attention_dropout(
    []float attention_weights,
    float dropout_rate,
    int seed
) []float {
    if dropout_rate <= 0.0 {
        return copy_vector(attention_weights)
    }
    []float out = copy_vector(attention_weights)
    float keep_scale = 1.0 / (1.0 - dropout_rate)
    int i = 0
    while i < len(out) {
        int bucket = (seed + i * 1103515245) % 1000
        if bucket < (dropout_rate * 1000.0) {
            out[i] = 0.0
        } else {
            out[i] = out[i] * keep_scale
        }
        i = i + 1
    }
    out
}

func get_attention_complexity(
    multi_head_attention attn,
    int batch_size,
    int seq_len
) map[string]long {
    map[string]long{}
}
