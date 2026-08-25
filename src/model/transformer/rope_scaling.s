package neurx.model.transformer.rope_scaling

    ROPE_SCALING_LINEAR
    ROPE_SCALING_NTK
    ROPE_SCALING_YARN
}

struct rope_scaling_config {
    rope_scaling_type method
    int original_max_seq_len
    int target_max_seq_len
    float base
    int dim
    float yarn_scale
    float yarn_original_scale
    float yarn_beta_fast
    float yarn_beta_slow
    float yarn_mscale
    bool ntk_use_log_space
}

func default_rope_scaling_4k_to_32k(int head_dim) rope_scaling_config {
    rope_scaling_config {
        method: ROPE_SCALING_YARN,
        original_max_seq_len: 4096,
        target_max_seq_len: 32768,
        base: 10000.0,
        dim: head_dim,
        yarn_scale: 8.0,
        yarn_original_scale: 1.0,
        yarn_beta_fast: 32.0,
        yarn_beta_slow: 1.0,
        yarn_mscale: 0.7,
        ntk_use_log_space: true,
    }
}

func default_rope_scaling_4k_to_128k(int head_dim) rope_scaling_config {
    rope_scaling_config {
        method: ROPE_SCALING_YARN,
        original_max_seq_len: 4096,
        target_max_seq_len: 131072,
        base: 10000.0,
        dim: head_dim,
        yarn_scale: 32.0,
        yarn_original_scale: 1.0,
        yarn_beta_fast: 64.0,
        yarn_beta_slow: 0.1,
        yarn_mscale: 0.65,
        ntk_use_log_space: true,
    }
}

func pow_float(float base, float exp) float {
    if exp == 0.0 { return 1.0 }
    if base <= 0.0 { return 0.0 }
    float result = 1.0
    bool negative = exp < 0.0
    if negative { exp = -exp }
    float e = 0.0
    while e < exp {
        result = result * base
        e = e + 1.0
    }
    if negative { result = 1.0 / result }
    return result
}

func log_approx(float x) float {
    if x <= 0.0 { return -1000000.0 }
    float y = 0.0
    if x > 1.5 {
        while x > 1.5 {
            x = x * 0.5
            y = y + 0.6931471805599453
        }
    } else if x < 0.7 && x > 0.0 {
        while x < 0.7 {
            x = x * 2.0
            y = y - 0.6931471805599453
        }
    }
    float z = (x - 1.0) / (x + 1.0)
    float z2 = z * z
    float series = z
    float term = z
    int i = 3
    while i <= 15 {
        term = term * z2
        series = series + term / float_of_int(i)
        i = i + 2
    }
    return 2.0 * series + y
}

func float_of_int(int n) float {
    float result = 0.0
    int i = 0
    while i < n {
        result = result + 1.0
        i = i + 1
    }
    return result
}

func min_int(int a, int b) int {
    if a < b { return a }
    return b
}

func max_int(int a, int b) int {
    if a > b { return a }
    return b
}

func min_float(float a, float b) float {
    if a < b { return a }
    return b
}

func max_float(float a, float b) float {
    if a > b { return a }
    return b
}

func compute_rope_frequencies(int seq_len, int dim, float base) []float {
    int half_dim = dim / 2
    []float freqs = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        float exponent = float_of_int(i * 2) / float_of_int(dim)
        freqs[i] = 1.0 / pow_float(base, exponent)
        i = i + 1
    }
    return freqs
}

func rope_linear_scaling(
    rope_scaling_config cfg,
    int position
) []float {
    int half_dim = cfg.dim / 2
    float scale = float_of_int(cfg.original_max_seq_len) / float_of_int(cfg.target_max_seq_len)
    float scaled_pos = float_of_int(position) * scale
    []float freqs = compute_rope_frequencies(cfg.original_max_seq_len, cfg.dim, cfg.base)
    []float angles = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        angles[i] = scaled_pos * freqs[i]
        i = i + 1
    }
    return angles
}

func rope_ntk_scaling(
    rope_scaling_config cfg,
    int position
) []float {
    int half_dim = cfg.dim / 2
    float ratio = float_of_int(cfg.target_max_seq_len) / float_of_int(cfg.original_max_seq_len)
    float new_base
    if cfg.ntk_use_log_space {
        float log_ratio = log_approx(ratio)
        float log_base = log_approx(cfg.base)
        float scale_factor = pow_float(ratio, float_of_int(cfg.dim) / float_of_int(max_int(cfg.dim - 2, 1)))
        new_base = cfg.base * scale_factor
    } else {
        float scale_factor = pow_float(ratio, float_of_int(cfg.dim) / (2.0 * float_of_int(cfg.dim - 2)))
        new_base = cfg.base * scale_factor
    }
    []float freqs = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        float exponent = float_of_int(i * 2) / float_of_int(cfg.dim)
        freqs[i] = 1.0 / pow_float(new_base, exponent)
        i = i + 1
    }
    []float angles = []float{cap: half_dim}
    i = 0
    while i < half_dim {
        angles[i] = float_of_int(position) * freqs[i]
        i = i + 1
    }
    return angles
}

func rope_yarn_scaling(
    rope_scaling_config cfg,
    int position
) []float {
    int half_dim = cfg.dim / 2
    []float freqs = compute_rope_frequencies(cfg.original_max_seq_len, cfg.dim, cfg.base)
    []float lambdas = []float{cap: half_dim}
    float inv_beta_fast = 1.0 / cfg.yarn_beta_fast
    float inv_beta_slow = 1.0 / cfg.yarn_beta_slow
    int i = 0
    while i < half_dim {
        float t = freqs[i]
        float log_t = log_approx(max_float(t, 1e-10))
        float decay = 0.5 * (1.0 + tanh_approx(log_t * inv_beta_fast))
        float slow_decay = 0.5 * (1.0 + tanh_approx(log_t * inv_beta_slow))
        lambdas[i] = decay
        i = i + 1
    }
    []float angles = []float{cap: half_dim}
    i = 0
    while i < half_dim {
        float scaled_freq = freqs[i] * (1.0 - lambdas[i]) +
                            freqs[i] * cfg.yarn_scale * lambdas[i]
        angles[i] = float_of_int(position) * scaled_freq
        i = i + 1
    }
    return angles
}

func tanh_approx(float x) float {
    if x > 5.0 { return 1.0 }
    if x < -5.0 { return -1.0 }
    float x2 = x * x
    return x * (27.0 + x2) / (27.0 + 9.0 * x2)
}

struct rope_result {
    []float cos_values
    []float sin_values
    float attention_scale
}

func get_rope_angles(
    rope_scaling_config cfg,
    int position
) rope_result {
    int half_dim = cfg.dim / 2
    []float angles
    if cfg.method == ROPE_SCALING_LINEAR {
        angles = rope_linear_scaling(cfg, position)
    } else if cfg.method == ROPE_SCALING_NTK {
        angles = rope_ntk_scaling(cfg, position)
    } else {
        angles = rope_yarn_scaling(cfg, position)
    }
    []float cos_vals = []float{cap: half_dim}
    []float sin_vals = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        cos_vals[i] = cos_approx(angles[i])
        sin_vals[i] = sin_approx(angles[i])
        i = i + 1
    }
    float attn_scale = 1.0
    if cfg.method == ROPE_SCALING_YARN && cfg.yarn_mscale > 0.0 {
        attn_scale = cfg.yarn_mscale
    }
    rope_result {
        cos_values: cos_vals,
        sin_values: sin_vals,
        attention_scale: attn_scale,
    }
}

struct rope_cache {
    [][]float all_cos
    [][]float all_sin
    float attention_scale
    int cached_seq_len
}

func build_rope_cache(rope_scaling_config cfg, int seq_len) rope_cache {
    int half_dim = cfg.dim / 2
    [][]float cos_table = [][]float{cap: seq_len}
    [][]float sin_table = [][]float{cap: seq_len}
    float attn_scale = 1.0
    int pos = 0
    while pos < seq_len {
        rope_result r = get_rope_angles(cfg, pos)
        cos_table[pos] = r.cos_values
        sin_table[pos] = r.sin_values
        if pos == 0 { attn_scale = r.attention_scale }
        pos = pos + 1
    }
    rope_cache {
        all_cos: cos_table,
        all_sin: sin_table,
        attention_scale: attn_scale,
        cached_seq_len: seq_len,
    }
}

func apply_rope_single(
    []float x,
    rope_result angles
) []float {
    int d = len(x)
    int half_d = d / 2
    []float out = []float{cap: d}
    int i = 0
    while i < half_d {
        float x0 = x[2 * i]
        float x1 = x[2 * i + 1]
        float cos_val = angles.cos_values[i]
        float sin_val = angles.sin_values[i]
        out[2 * i]     = x0 * cos_val - x1 * sin_val
        out[2 * i + 1] = x0 * sin_val + x1 * cos_val
        i = i + 1
    }
    return out
}

func apply_rope_batch(
    [][][]float x,
    rope_cache cache
) [][][]float {
    int seq_len = len(x)
    if seq_len == 0 { return x }
    int num_heads = len(x[0])
    if num_heads == 0 { return x }
    int head_dim = len(x[0][0])
    int half_d = head_dim / 2
    [][][]float out = [][][]float{cap: seq_len}
    int s = 0
    while s < seq_len {
        out[s] = [][][]float{cap: num_heads}
        int h = 0
        while h < num_heads {
            out[s][h] = []float{cap: head_dim}
            int i = 0
            while i < half_d {
                float x0 = x[s][h][2 * i]
                float x1 = x[s][h][2 * i + 1]
                float cos_val = cache.all_cos[s][i]
                float sin_val = cache.all_sin[s][i]
                out[s][h][2 * i]     = x0 * cos_val - x1 * sin_val
                out[s][h][2 * i + 1] = x0 * sin_val + x1 * cos_val
                i = i + 1
            }
            h = h + 1
        }
        s = s + 1
    }
    return out
}

func cos_approx(float x) float {
    float pi = 3.141592653589793
    float two_pi = 2.0 * pi
    while x > pi || x < -pi {
        if x > pi { x = x - two_pi }
        if x < -pi { x = x + two_pi }
    }
    float term = 1.0
    float result = 1.0
    float xx = x * x
    int n = 1
    while n <= 12 {
        term = -term * xx / float_of_int((2 * n - 1) * (2 * n))
        result = result + term
        n = n + 1
    }
    return result
}

func sin_approx(float x) float {
    float pi = 3.141592653589793
    float two_pi = 2.0 * pi
    while x > pi || x < -pi {
        if x > pi { x = x - two_pi }
        if x < -pi { x = x + two_pi }
    }
    float term = x
    float result = x
    float xx = x * x
    int n = 1
    while n <= 12 {
        term = -term * xx / float_of_int((2 * n) * (2 * n + 1))
        result = result + term
        n = n + 1
    }
    return result
}

struct neurx_position_encoding {
    int block_position
    int position
}

func get_neurx_rope_angles(
    rope_scaling_config cfg,
    neurx_position_encoding pos
) rope_result {
    int effective_position = pos.block_position * cfg.original_max_seq_len + pos.position
    return get_rope_angles(cfg, effective_position)
}

func build_neurx_rope_cache(
    rope_scaling_config cfg,
    int num_blocks,
    int block_size
) rope_cache {
    int total_seq_len = num_blocks * block_size
    return build_rope_cache(cfg, total_seq_len)
}

struct rope_stats {
    int total_positions_computed
    float avg_compute_time_us
    float peak_memory_bytes
    string method_used
}

func validate_rope_scaling(
    rope_scaling_config cfg,
    int test_positions_count
) bool {
    bool passed = true
    int p = 0
    while p < test_positions_count {
        rope_result r = get_rope_angles(cfg, p)
        int i = 0
        while i < len(r.cos_values) {
            float val = r.cos_values[i] * r.cos_values[i] +
                        r.sin_values[i] * r.sin_values[i]
            if val < 0.99 || val > 1.01 {
                passed = false
            }
            i = i + 1
        }
        p = p + 1
    }
    return passed
}

func print_rope_config_summary(rope_scaling_config cfg) string {
    string method_name = ""
    if cfg.method == ROPE_SCALING_LINEAR {
        method_name = "Linear (Position Interpolation)"
    } else if cfg.method == ROPE_SCALING_NTK {
        method_name = "NTK-Aware"
    } else {
        method_name = "YaRN (Recommended)"
    }
    "RoPE Scaling config:\n" +
    "  Method: " + method_name + "\n" +
    "  Original Length: " + string(cfg.original_max_seq_len) + "\n" +
    "  Target Length: " + string(cfg.target_max_seq_len) + "\n" +
    "  Scale Factor: " + string(float_of_int(cfg.target_max_seq_len) / float_of_int(cfg.original_max_seq_len)) + "x\n" +
    "  Base: " + string(cfg.base) + "\n" +
    "  Dim: " + string(cfg.dim)
}
