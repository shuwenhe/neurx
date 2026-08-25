package neurx.model.transformer.norm

struct layer_norm_config {
    int hidden_dim
    float epsilon
    bool use_bias
    string norm_type
}

struct layer_norm {
    int hidden_dim
    float epsilon
    []float gamma
    []float beta
    bool use_bias
}

struct rms_norm {
    int hidden_dim
    float epsilon
    []float gamma
}

struct position_embedding_config {
    int hidden_dim
    int max_seq_len
    string embed_type
    float rope_base
    bool use_flash_attention
}

struct learned_position_embedding {
    int hidden_dim
    int max_seq_len
    []float weight
}

struct rope_embedding {
    int hidden_dim
    float rope_base
    []float frequencies
    []float cached_cos
    []float cached_sin
    int max_seq_len
}

struct alibi_embedding {
    int num_heads
    []float head_slopes
}

struct rope_apply_result {
    []float query
    []float key
}

struct alibi_apply_result {
    []float scores
}

func allocate_vector(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    for i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func copy_vector([]float src) []float {
    []float out = allocate_vector(len(src), 0.0)
    int i = 0
    for i < len(src) {
        out[i] = src[i]
        i = i + 1
    }
    out
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = x
    int i = 0
    for i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
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
    for i <= 12 {
        term = term * x / (i * 1.0)
        result = result + term
        i = i + 1
    }
    result
}

func cos_approx(float x) float {
    float pi = 3.141592653589793
    float two_pi = 6.283185307179586
    float value = x
    for value > pi {
        value = value - two_pi
    }
    for value < -pi {
        value = value + two_pi
    }
    float x2 = value * value
    float term = 1.0
    float result = 1.0
    int i = 1
    for i <= 10 {
        term = -term * x2 / ((2 * i - 1) * (2 * i) * 1.0)
        result = result + term
        i = i + 1
    }
    result
}

func sin_approx(float x) float {
    float pi = 3.141592653589793
    float two_pi = 6.283185307179586
    float value = x
    for value > pi {
        value = value - two_pi
    }
    for value < -pi {
        value = value + two_pi
    }
    float x2 = value * value
    float term = value
    float result = value
    int i = 1
    for i <= 10 {
        term = -term * x2 / ((2 * i) * (2 * i + 1) * 1.0)
        result = result + term
        i = i + 1
    }
    result
}

func new_layer_norm(layer_norm_config cfg) layer_norm {
    layer_norm {
        hidden_dim: cfg.hidden_dim,
        epsilon: cfg.epsilon,
        gamma: allocate_vector(cfg.hidden_dim, 1.0),
        beta: allocate_vector(cfg.hidden_dim, 0.0),
        use_bias: cfg.use_bias,
    }
}

func new_rms_norm(layer_norm_config cfg) rms_norm {
    rms_norm {
        hidden_dim: cfg.hidden_dim,
        epsilon: cfg.epsilon,
        gamma: allocate_vector(cfg.hidden_dim, 1.0),
    }
}

func layer_normalize(
    layer_norm ln,
    []float input,
    int batch_size,
    int seq_len
) []float {
    int hidden_dim = ln.hidden_dim
    []float output = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    int b = 0
    for b < batch_size {
        int s = 0
        for s < seq_len {
            int base = (b * seq_len + s) * hidden_dim
            float mean = 0.0
            int d = 0
            for d < hidden_dim {
                mean = mean + input[base + d]
                d = d + 1
            }
            mean = mean / (hidden_dim * 1.0)
            float variance = 0.0
            d = 0
            for d < hidden_dim {
                float diff = input[base + d] - mean
                variance = variance + diff * diff
                d = d + 1
            }
            variance = variance / (hidden_dim * 1.0)
            float denom = sqrt_approx(variance + ln.epsilon)
            d = 0
            for d < hidden_dim {
                float normalized = (input[base + d] - mean) / denom
                float scaled = normalized * ln.gamma[d]
                if ln.use_bias {
                    scaled = scaled + ln.beta[d]
                }
                output[base + d] = scaled
                d = d + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    output
}

func rms_normalize(
    rms_norm rn,
    []float input,
    int batch_size,
    int seq_len
) []float {
    int hidden_dim = rn.hidden_dim
    []float output = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    int b = 0
    for b < batch_size {
        int s = 0
        for s < seq_len {
            int base = (b * seq_len + s) * hidden_dim
            float sq_sum = 0.0
            int d = 0
            for d < hidden_dim {
                float x = input[base + d]
                sq_sum = sq_sum + x * x
                d = d + 1
            }
            float rms = sqrt_approx(sq_sum / (hidden_dim * 1.0))
            float denom = rms + rn.epsilon
            d = 0
            for d < hidden_dim {
                output[base + d] = (input[base + d] / denom) * rn.gamma[d]
                d = d + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    output
}

func new_absolute_position_embedding(position_embedding_config cfg) []float {
    int total = cfg.max_seq_len * cfg.hidden_dim
    []float embedding = allocate_vector(total, 0.0)
    int pos = 0
    for pos < cfg.max_seq_len {
        int d = 0
        for d < cfg.hidden_dim {
            float exponent = (d * 1.0) / (cfg.hidden_dim * 1.0)
            float div_term = exp_approx(-exponent * 9.210340371976184)
            float angle = pos * 1.0 * div_term
            int idx = pos * cfg.hidden_dim + d
            if d % 2 == 0 {
                embedding[idx] = sin_approx(angle)
            } else {
                embedding[idx] = cos_approx(angle)
            }
            d = d + 1
        }
        pos = pos + 1
    }
    embedding
}

func new_learned_position_embedding(position_embedding_config cfg) learned_position_embedding {
    int total = cfg.max_seq_len * cfg.hidden_dim
    []float weight = allocate_vector(total, 0.0)
    int pos = 0
    for pos < cfg.max_seq_len {
        int d = 0
        for d < cfg.hidden_dim {
            int idx = pos * cfg.hidden_dim + d
            weight[idx] = ((pos + 1) * (d + 3) * 1.0) / ((cfg.max_seq_len + cfg.hidden_dim + 1) * 1.0)
            d = d + 1
        }
        pos = pos + 1
    }
    learned_position_embedding {
        hidden_dim: cfg.hidden_dim,
        max_seq_len: cfg.max_seq_len,
        weight: weight,
    }
}

func get_position_embedding(
    []float embedding,
    int hidden_dim,
    int seq_len
) []float {
    int total = seq_len * hidden_dim
    []float out = allocate_vector(total, 0.0)
    int i = 0
    for i < total {
        out[i] = embedding[i]
        i = i + 1
    }
    out
}

func get_learned_position_embedding(
    learned_position_embedding embedding,
    int seq_len
) []float {
    int total = seq_len * embedding.hidden_dim
    []float out = allocate_vector(total, 0.0)
    int i = 0
    for i < total && i < len(embedding.weight) {
        out[i] = embedding.weight[i]
        i = i + 1
    }
    out
}

func new_rope_embedding(position_embedding_config cfg) rope_embedding {
    int half_dim = cfg.hidden_dim / 2
    []float frequencies = allocate_vector(half_dim, 0.0)
    int i = 0
    for i < half_dim {
        float ratio = (2 * i * 1.0) / (cfg.hidden_dim * 1.0)
        frequencies[i] = exp_approx(-ratio * 9.210340371976184)
        i = i + 1
    }
    int cache_size = cfg.max_seq_len * half_dim
    rope_embedding {
        hidden_dim: cfg.hidden_dim,
        rope_base: cfg.rope_base,
        frequencies: frequencies,
        cached_cos: allocate_vector(cache_size, 0.0),
        cached_sin: allocate_vector(cache_size, 0.0),
        max_seq_len: cfg.max_seq_len,
    }
}

func apply_rope(
    rope_embedding rope,
    []float query,
    []float key,
    int batch_size,
    int num_heads,
    int seq_len,
    int head_dim
) rope_apply_result {
    []float rotated_query = copy_vector(query)
    []float rotated_key = copy_vector(key)
    int pair_dim = head_dim / 2
    int b = 0
    for b < batch_size {
        int h = 0
        for h < num_heads {
            int s = 0
            for s < seq_len {
                int pair = 0
                for pair < pair_dim {
                    int token_base = (b * seq_len + s) * (num_heads * head_dim)
                    int base = token_base + h * head_dim + pair * 2
                    int cache_idx = s * pair_dim + pair
                    float angle = s * 1.0 * rope.frequencies[pair]
                    float c = cos_approx(angle)
                    float si = sin_approx(angle)
                    float q0 = query[base]
                    float q1 = query[base + 1]
                    float k0 = key[base]
                    float k1 = key[base + 1]
                    rotated_query[base] = q0 * c - q1 * si
                    rotated_query[base + 1] = q0 * si + q1 * c
                    rotated_key[base] = k0 * c - k1 * si
                    rotated_key[base + 1] = k0 * si + k1 * c
                    rope.cached_cos[cache_idx] = c
                    rope.cached_sin[cache_idx] = si
                    pair = pair + 1
                }
                s = s + 1
            }
            h = h + 1
        }
        b = b + 1
    }
    rope_apply_result {
        query: rotated_query,
        key: rotated_key,
    }
}

func new_alibi_embedding(position_embedding_config cfg, int num_heads) alibi_embedding {
    []float slopes = allocate_vector(num_heads, 0.0)
    int h = 0
    for h < num_heads {
        slopes[h] = exp_approx(-(h + 1) * 0.5 * 0.6931471805599453)
        h = h + 1
    }
    alibi_embedding {
        num_heads: num_heads,
        head_slopes: slopes,
    }
}

func apply_alibi_bias(
    alibi_embedding alibi,
    []float attention_scores,
    int batch_size,
    int num_heads,
    int seq_len
) alibi_apply_result {
    []float out = copy_vector(attention_scores)
    int b = 0
    for b < batch_size {
        int h = 0
        for h < num_heads {
            int i = 0
            for i < seq_len {
                int j = 0
                for j < seq_len {
                    int idx = (((b * num_heads + h) * seq_len + i) * seq_len) + j
                    float distance = i - j
                    if distance < 0.0 {
                        distance = -distance
                    }
                    out[idx] = out[idx] - distance * alibi.head_slopes[h]
                    j = j + 1
                }
                i = i + 1
            }
            h = h + 1
        }
        b = b + 1
    }
    alibi_apply_result {
        scores: out,
    }
}

func get_embedding_stats(position_embedding_config cfg) map[string]double {
    map[string]double{}
}
