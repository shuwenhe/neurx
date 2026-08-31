package neurx.model.llm.long_context_32k
use neurx.strings
use neurx.runtime.io.{io_println}

struct rope_config {
    int dim
    int max_seq_len
    float base
    string scaling_type
    float alpha
    string pos_interpolation
}

struct rope_state {
    rope_config config
    rope_cache cache
    float[] freqs
    float[] scaled_freqs
    float extrapolation_ratio
    float freq_min
    float freq_max
}

struct rope_cache {
    float[] cos_cache
    float[] sin_cache
    int max_seq_len
    int freq_dim
}

struct rope_qk_result {
    float[] rotated_q
    float[] rotated_k
}

func rope_config_new(
    int dim,
    int max_seq_len
) rope_config {
    rope_config cfg = rope_config {
        dim: dim,
        max_seq_len: max_seq_len,
        base: 500000.0,
        scaling_type: "ntk",
        alpha: 1.0,
        pos_interpolation: "linear",
    }
    cfg
}

func compute_rope_frequencies(
    rope_config config
) []float {
    int dim = config.dim
    float[] freqs = make([]float, dim / 2)
    int i = 0
    for i < dim / 2 {
        float exp = -2.0 * float(i) / float(dim)
        float freq = pow(config.base, exp)
        freqs[i] = freq
        i = i + 1
    }
    freqs
}

func apply_ntk_scaling(
    rope_config config,
    float[] freqs,
    int context_len
) []float {
    float[] scaled_freqs = make([]float, len(freqs))
    float alpha = config.alpha
    if context_len > config.max_seq_len {
        float ratio = float(context_len) / float(config.max_seq_len)
        alpha = pow(ratio, float(config.dim) / float(config.dim - 2))
    }
    int i = 0
    for i < len(freqs) {
        scaled_freqs[i] = freqs[i] / alpha
        i = i + 1
    }
    scaled_freqs
}

func apply_linear_interpolation_scaling(
    rope_config config,
    float[] freqs,
    int context_len
) []float {
    float[] scaled_freqs = make([]float, len(freqs))
    float scale = float(context_len) / float(config.max_seq_len)
    int i = 0
    for i < len(freqs) {
        float freq_idx_normalized = float(i) / float(len(freqs))
        if freq_idx_normalized < 0.25 {
            scaled_freqs[i] = freqs[i]
        } else {
            float interp_alpha = (freq_idx_normalized - 0.25) / 0.75
            scaled_freqs[i] = freqs[i] / (1.0 + interp_alpha * (scale - 1.0))
        }
        i = i + 1
    }
    scaled_freqs
}

func precompute_rope_cache(
    rope_config config,
    float[] scaled_freqs
) rope_cache {
    int max_seq_len = config.max_seq_len
    int freq_dim = len(scaled_freqs)
    int cache_size = max_seq_len * freq_dim
    float[] cos_cache = make([]float, cache_size)
    float[] sin_cache = make([]float, cache_size)
    int m = 0
    for m < max_seq_len {
        int i = 0
        for i < freq_dim {
            float angle = float(m) * scaled_freqs[i]
            int idx = m * freq_dim + i
            cos_cache[idx] = cos(angle)
            sin_cache[idx] = sin(angle)
            i = i + 1
        }
        m = m + 1
    }
    rope_cache {
        cos_cache: cos_cache,
        sin_cache: sin_cache,
        max_seq_len: max_seq_len,
        freq_dim: freq_dim,
    }
}

func apply_rope_to_qk(
    rope_state rope,
    float[] query,
    float[] key,
    int batch_size,
    int seq_len,
    int num_heads,
    int head_dim
) rope_qk_result {
    float[] rotated_q = make([]float, len(query))
    float[] rotated_k = make([]float, len(key))
    int b = 0
    for b < batch_size {
        int s = 0
        for s < seq_len {
            int pos = b * seq_len + s
            int h = 0
            for h < num_heads {
                int d = 0
                for d < head_dim / 2 {
                    int cache_idx = s * rope.cache.freq_dim + d
                    float cos_val = rope.cache.cos_cache[cache_idx]
                    float sin_val = rope.cache.sin_cache[cache_idx]
                    float q_d0 = query[pos * num_heads * head_dim + h * head_dim + 2 * d]
                    float q_d1 = query[pos * num_heads * head_dim + h * head_dim + 2 * d + 1]
                    float rotated_q_d0 = q_d0 * cos_val - q_d1 * sin_val
                    float rotated_q_d1 = q_d0 * sin_val + q_d1 * cos_val
                    rotated_q[pos * num_heads * head_dim + h * head_dim + 2 * d] = rotated_q_d0
                    rotated_q[pos * num_heads * head_dim + h * head_dim + 2 * d + 1] = rotated_q_d1
                    float k_d0 = key[pos * num_heads * head_dim + h * head_dim + 2 * d]
                    float k_d1 = key[pos * num_heads * head_dim + h * head_dim + 2 * d + 1]
                    float rotated_k_d0 = k_d0 * cos_val - k_d1 * sin_val
                    float rotated_k_d1 = k_d0 * sin_val + k_d1 * cos_val
                    rotated_k[pos * num_heads * head_dim + h * head_dim + 2 * d] = rotated_k_d0
                    rotated_k[pos * num_heads * head_dim + h * head_dim + 2 * d + 1] = rotated_k_d1
                    d = d + 1
                }
                h = h + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    rope_qk_result {
        rotated_q: rotated_q,
        rotated_k: rotated_k,
    }
}

func rope_state_new(
    rope_config config
) rope_state {
    float[] freqs = compute_rope_frequencies(config)
    float[] scaled_freqs = freqs
    if config.scaling_type == "ntk" {
        scaled_freqs = apply_ntk_scaling(config, freqs, config.max_seq_len)
    } else if config.scaling_type == "linear" {
        scaled_freqs = apply_linear_interpolation_scaling(config, freqs, config.max_seq_len)
    }
    rope_cache cache = precompute_rope_cache(config, scaled_freqs)
    rope_state state = rope_state {
        config: config,
        cache: cache,
        freqs: freqs,
        scaled_freqs: scaled_freqs,
        extrapolation_ratio: 0.0,
        freq_min: 0.0,
        freq_max: 0.0,
    }
    if len(scaled_freqs) > 0 {
        state.freq_min = scaled_freqs[len(scaled_freqs) - 1]
        state.freq_max = scaled_freqs[0]
    }
    state
}

func handle_longer_context(
    rope_state rope,
    int actual_seq_len
) {
    if actual_seq_len <= rope.config.max_seq_len {
        return
    }
    rope.extrapolation_ratio = float(actual_seq_len) / float(rope.config.max_seq_len)
    io_println("Handling context longer than max_seq_len: " +
              int_to_string(actual_seq_len) + " > " + int_to_string(rope.config.max_seq_len))
}

func cos(float x) float {
    float x2 = x * x
    float result = 1.0
    float term = 1.0
    int i = 1
    for i < 10 {
        term = term * (-x2) / float(2 * i * (2 * i - 1))
        result = result + term
        i = i + 1
    }
    result
}

func sin(float x) float {
    float x2 = x * x
    float result = x
    float term = x
    int i = 1
    for i < 10 {
        term = term * (-x2) / float((2 * i + 1) * (2 * i))
        result = result + term
        i = i + 1
    }
    result
}

func pow(float base, float exp) float {
    if exp == 0.0 {
        return 1.0
    }
    if base == 0.0 {
        return 0.0
    }
    if exp == 1.0 {
        return base
    }
    float log_base = 0.5
    float result = exp_func(exp * log_base)
    result
}

func exp_func(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    for i < 20 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    result
}

func float(int x) float {
    0.0 + x
}

func int_to_string(int x) string {
    if x == 0 {
        return "0"
    }
    bool neg = false
    int value = x
    if value < 0 {
        neg = true
        value = -value
    }
    string out = ""
    for value > 0 {
        int digit = value % 10
        out = string(digit + 48) + out
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    out
}
