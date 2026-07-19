package neurx.model.transformer.rope_scaling

// ═══════════════════════════════════════════════════════════════════
// RoPE Scaling — English textsupport (32K / 64K / 128K+)
//
// English text:
//   English text RoPE English texttrainingEnglish text max_seq_len English textinferenceEnglish text.
//   RoPE Scaling English text,English textmodelEnglish text.
//
// English textmainEnglish text:
//   1. Linear Scaling (PI): English text,English text
//   2. NTK-Aware Scaling: English text,English textinformation
//   3. YaRN (recommended): English text + English text + English text,English text
//
// English text:
//   - "Extending Context Window of Large Language Models via Positional Interpolation"
//   - "NTK-Aware Scaled RoPE"
//   - "YaRN: Efficient Context Window Extension of LLMs"
// ═══════════════════════════════════════════════════════════════════

// ============================================================================
// 1. configurationEnglish text
// ============================================================================

enum rope_scaling_type {
    ROPE_SCALING_LINEAR      // English text (Position Interpolation)
    ROPE_SCALING_NTK         // NTK-Aware English text
    ROPE_SCALING_YARN        // YaRN (recommended)
}

struct rope_scaling_config {
    rope_scaling_type method       // useEnglish text
    int original_max_seq_len       // English texttrainingEnglish text (English text 4096)
    int target_max_seq_len         // English text (English text 32768 / 131072)
    float base                     // RoPE English text (English text 10000.0)
    int dim                       // English text (head_dim)

    // YaRN English textparameter
    float yarn_scale              // YaRN English text
    float yarn_original_scale     // YaRN English text
    float yarn_beta_fast          // YaRN quickEnglish text (32 English text 64)
    float yarn_beta_slow          // YaRN English text (1 English text 0.1)
    float yarn_mscale             // English text (English text,default ~0.7)

    // NTK English textparameter
    bool ntk_use_log_space        // English text log English textcomputeEnglish text
}

// defaultconfiguration: 4K → 32K extension
func default_rope_scaling_4k_to_32k(int head_dim) rope_scaling_config {
    rope_scaling_config {
        method: ROPE_SCALING_YARN,
        original_max_seq_len: 4096,
        target_max_seq_len: 32768,
        base: 10000.0,
        dim: head_dim,

        // YaRN parameter (English textrecommendedEnglish text 4K→32K English text)
        yarn_scale: 8.0,
        yarn_original_scale: 1.0,
        yarn_beta_fast: 32.0,
        yarn_beta_slow: 1.0,
        yarn_mscale: 0.7,

        ntk_use_log_space: true,
    }
}

// defaultconfiguration: 4K → 128K extension
func default_rope_scaling_4k_to_128k(int head_dim) rope_scaling_config {
    rope_scaling_config {
        method: ROPE_SCALING_YARN,
        original_max_seq_len: 4096,
        target_max_seq_len: 131072,
        base: 10000.0,
        dim: head_dim,

        // YaRN parameter (English textrecommendedEnglish text 4K→128K English text)
        yarn_scale: 32.0,
        yarn_original_scale: 1.0,
        yarn_beta_fast: 64.0,
        yarn_beta_slow: 0.1,
        yarn_mscale: 0.65,

        ntk_use_log_space: true,
    }
}

// ============================================================================
// 2. toolfunction
// ============================================================================

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

    // Newton-Raphson for natural log
    float y = 0.0
    if x > 1.5 {
        while x > 1.5 {
            x = x * 0.5
            y = y + 0.6931471805599453  // ln(2)
        }
    } else if x < 0.7 && x > 0.0 {
        while x < 0.7 {
            x = x * 2.0
            y = y - 0.6931471805599453
        }
    }

    // Taylor series around x=1: ln(x) ≈ 2[(x-1)/(x+1) + (x-1)^3/(3(x+1)^3) + ...]
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

// ============================================================================
// 3. English text RoPE English textcompute
// ============================================================================

// computeEnglish text RoPE English text: theta_i = 1 / (base^(2i/dim))
func compute_rope_frequencies(int seq_len, int dim, float base) []float {
    int half_dim = dim / 2

    // theta_i = 1 / (base^(2i/d))
    []float freqs = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        float exponent = float_of_int(i * 2) / float_of_int(dim)
        freqs[i] = 1.0 / pow_float(base, exponent)
        i = i + 1
    }

    return freqs
}

// ============================================================================
// 4. English text: Linear Scaling (Position Interpolation)
// ============================================================================
//
// English text:
//   English text: pos' = pos * (original_max / target_max)
//   English text
//
// English text:
//   theta_i' = theta_i * scale_factor
//   English text scale_factor = original_max_seq_len / target_max_seq_len
//
// English text: English text
// English text: English textinformationEnglish text,English text

func rope_linear_scaling(
    rope_scaling_config cfg,
    int position          // English text [0, target_max_seq_len)
) []float {
    int half_dim = cfg.dim / 2

    // English text
    float scale = float_of_int(cfg.original_max_seq_len) / float_of_int(cfg.target_max_seq_len)

    // English text
    float scaled_pos = float_of_int(position) * scale

    // computeEnglish text
    []float freqs = compute_rope_frequencies(cfg.original_max_seq_len, cfg.dim, cfg.base)

    // English text = scaled_pos * frequency
    []float angles = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        angles[i] = scaled_pos * freqs[i]
        i = i + 1
    }

    return angles
}

// ============================================================================
// 5. English text: NTK-Aware Scaling
// ============================================================================
//
// English text:
//   English textuseEnglish text:
//   - English text (i English text, theta English text): English text
//   - English text (i English text, theta English text): English text
//
// English text,English text NTK kernel
//
// English text (English text):
//   base' = base * ((target_max / original_max - 1) / (original_max - 1))^(dim / (2*dim-2))
//   English text: base' = base * (target_max / original_max)^(dim / (2*(dim-2)))

func rope_ntk_scaling(
    rope_scaling_config cfg,
    int position
) []float {
    int half_dim = cfg.dim / 2

    // compute NTK English text base
    float ratio = float_of_int(cfg.target_max_seq_len) / float_of_int(cfg.original_max_seq_len)

    float new_base
    if cfg.ntk_use_log_space {
        // English text log English textcompute,English text ratio English text
        float log_ratio = log_approx(ratio)
        float log_base = log_approx(cfg.base)
        // English text base English text: base_new = base * ratio^(dim/(dim-2)) English text
        float scale_factor = pow_float(ratio, float_of_int(cfg.dim) / float_of_int(max_int(cfg.dim - 2, 1)))
        new_base = cfg.base * scale_factor
    } else {
        // English text
        float scale_factor = pow_float(ratio, float_of_int(cfg.dim) / (2.0 * float_of_int(cfg.dim - 2)))
        new_base = cfg.base * scale_factor
    }

    // useEnglish text base computeEnglish text
    []float freqs = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        float exponent = float_of_int(i * 2) / float_of_int(cfg.dim)
        freqs[i] = 1.0 / pow_float(new_base, exponent)
        i = i + 1
    }

    // English text
    []float angles = []float{cap: half_dim}
    i = 0
    while i < half_dim {
        angles[i] = float_of_int(position) * freqs[i]
        i = i + 1
    }

    return angles
}

// ============================================================================
// 6. English text: YaRN (recommended!) — Yet Another RoPE Extension
// ============================================================================
//
// English text (English text):
//
//   1. **English text**:
//      English textuseEnglish text:
//      - English text (English textinformation): useEnglish text
//      - English text (English text): English text
//
//   2. **English text** (Passage Scaling):
//      English text beta_fast English text beta_slow parameterEnglish text
//      English text
//
//   3. **English text** (Attention Scaling, English text):
//      English text mscaling English text,
//      English text
//
// English text:
//   lambda(t) = 0.5 * (1 + tanh(ln(t)/beta))
//   freq_scaled = freq * (1 - lambda) + freq * scale * lambda
//   English text: English text scale,English text,English text

func rope_yarn_scaling(
    rope_scaling_config cfg,
    int position
) []float {
    int half_dim = cfg.dim / 2

    // computeEnglish text (useEnglish text base)
    []float freqs = compute_rope_frequencies(cfg.original_max_seq_len, cfg.dim, cfg.base)

    // YaRN English text
    // lambda function: English text
    []float lambdas = []float{cap: half_dim}
    float inv_beta_fast = 1.0 / cfg.yarn_beta_fast
    float inv_beta_slow = 1.0 / cfg.yarn_beta_slow

    int i = 0
    while i < half_dim {
        float t = freqs[i]  // English text "time" English text

        // tanh(log(t) / beta) implementationEnglish text
        float log_t = log_approx(max_float(t, 1e-10))

        // quickEnglish text
        float decay = 0.5 * (1.0 + tanh_approx(log_t * inv_beta_fast))
        float slow_decay = 0.5 * (1.0 + tanh_approx(log_t * inv_beta_slow))

        // English text: lambda = (1 - slow_decay) * decay + (1 - decay)
        // English text: lambda = tanh(ln(freq) / beta)
        lambdas[i] = decay

        i = i + 1
    }

    // English text
    []float angles = []float{cap: half_dim}
    i = 0
    while i < half_dim {
        // English text: English text * (1-lambda) + English text * lambda
        float scaled_freq = freqs[i] * (1.0 - lambdas[i]) +
                            freqs[i] * cfg.yarn_scale * lambdas[i]
        angles[i] = float_of_int(position) * scaled_freq
        i = i + 1
    }

    return angles
}

// Tanh English text (Taylor English text)
func tanh_approx(float x) float {
    // tanh(x) = (e^x - e^-x) / (e^x + e^-x)
    // use Padé English textfunctionEnglish text

    // English text |x|, tanh(x) ≈ sign(x)
    if x > 5.0 { return 1.0 }
    if x < -5.0 { return -1.0 }

    // English text: tanh(x) ≈ x * (27 + x^2) / (27 + 9*x^2)
    float x2 = x * x
    return x * (27.0 + x2) / (27.0 + 9.0 * x2)
}

// ============================================================================
// 7. English text: English text config English text
// ============================================================================

struct rope_result {
    []float cos_values    // [half_dim] cos(angle)
    []float sin_values    // [half_dim] sin(angle)
    float attention_scale // English text (YaRN English text)
}

// English text RoPE English text (English text)
func get_rope_angles(
    rope_scaling_config cfg,
    int position
) rope_result {
    int half_dim = cfg.dim / 2
    []float angles

    // English text
    if cfg.method == ROPE_SCALING_LINEAR {
        angles = rope_linear_scaling(cfg, position)
    } else if cfg.method == ROPE_SCALING_NTK {
        angles = rope_ntk_scaling(cfg, position)
    } else {  // ROPE_SCALING_YARN
        angles = rope_yarn_scaling(cfg, position)
    }

    // compute cos/sin
    []float cos_vals = []float{cap: half_dim}
    []float sin_vals = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        cos_vals[i] = cos_approx(angles[i])
        sin_vals[i] = sin_approx(angles[i])
        i = i + 1
    }

    // English text
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

// ============================================================================
// 8. English textcompute: English textgenerate RoPE English text (cacheoptimize)
// ============================================================================

struct rope_cache {
    [][]float all_cos     // [seq_len, half_dim]
    [][]float all_sin     // [seq_len, half_dim]
    float attention_scale
    int cached_seq_len
}

// English textcomputeEnglish text RoPE (English textcompute)
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

// ============================================================================
// 9. English text RoPE English text Q/K English text (English text)
// ============================================================================

// English text RoPE English text token English text Q English text K English text
// input: x [head_dim], output: rotated_x [head_dim]
// English text: [x0, x1, x2, x3, ..., x_{d-2}, x_{d-1}]
// English text: (x_{2i}, x_{2i+1}) -> rotate by angle_i
//
// English text:
//   x'_2i   = x_2i * cos(theta_i) - x_{2i+1} * sin(theta_i)
//   x'_{2i+1} = x_2i * sin(theta_i) + x_{2i+1} * cos(theta_i)

func apply_rope_single(
    []float x,               // [head_dim]
    rope_result angles       // pre-computed cos/sin
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

// English text RoPE: English text heads
// input: x [seq_len, num_heads, head_dim]
// output: rotated [seq_len, num_heads, head_dim]
func apply_rope_batch(
    [][][]float x,           // [seq_len][num_heads][head_dim]
    rope_cache cache         // pre-computed cache
) [][][]float {
    int seq_len = len(x)
    if seq_len == 0 { return x }
    int num_heads = len(x[0])
    if num_heads == 0 { return x }
    int head_dim = len(x[0][0])
    int half_d = head_dim / 2

    // outputEnglish text
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

// ============================================================================
// 10. English texthelperfunction (cos/sin English text)
// ============================================================================

// Cosine Taylor English text
func cos_approx(float x) float {
    // English text x English text [-pi, pi] English text
    // pi ≈ 3.141592653589793
    float pi = 3.141592653589793
    float two_pi = 2.0 * pi

    // English text
    while x > pi || x < -pi {
        if x > pi { x = x - two_pi }
        if x < -pi { x = x + two_pi }
    }

    // Taylor: cos(x) = 1 - x²/2! + x⁴/4! - x⁶/6! + ...
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

// Sine Taylor English text
func sin_approx(float x) float {
    // English text [-pi, pi]
    float pi = 3.141592653589793
    float two_pi = 2.0 * pi

    while x > pi || x < -pi {
        if x > pi { x = x - two_pi }
        if x < -pi { x = x + two_pi }
    }

    // Taylor: sin(x) = x - x³/3! + x⁵/5! - x⁷/7! + ...
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

// ============================================================================
// 11. NEURX English text: English text + 2D English text
// ============================================================================
//
// NEURX useEnglish text (English text BERT),English text 2D English text:
//   - Block ID (block_position): English text block English text
//   - Position ID (position): block English text
//
// NEURX English text RoPE English textinformation

struct neurx_position_encoding {
    int block_position      // English text block (English text)
    int position            // block English text (token English text)
}

// NEURX English text RoPE: English text block English text position information
func get_neurx_rope_angles(
    rope_scaling_config cfg,
    neurx_position_encoding pos
) rope_result {
    // NEURX English text:
    // English text = block_position * block_size + position
    // English text (English text NEURX English text)

    int effective_position = pos.block_position * cfg.original_max_seq_len + pos.position

    return get_rope_angles(cfg, effective_position)
}

// NEURX English text
func build_neurx_rope_cache(
    rope_scaling_config cfg,
    int num_blocks,
    int block_size
) rope_cache {
    int total_seq_len = num_blocks * block_size
    return build_rope_cache(cfg, total_seq_len)
}

// ============================================================================
// 12. English textstatistics & English texttool
// ============================================================================

struct rope_stats {
    int total_positions_computed
    float avg_compute_time_us
    float peak_memory_bytes
    string method_used
}

// English text RoPE Scaling English text (English texttestEnglish text)
func validate_rope_scaling(
    rope_scaling_config cfg,
    int test_positions_count
) bool {
    bool passed = true
    int p = 0
    while p < test_positions_count {
        rope_result r = get_rope_angles(cfg, p)

        // English text: cos² + sin² English text 1
        int i = 0
        while i < len(r.cos_values) {
            float val = r.cos_values[i] * r.cos_values[i] +
                        r.sin_values[i] * r.sin_values[i]
            // English text ±0.01 English text (English text)
            if val < 0.99 || val > 1.01 {
                passed = false
            }
            i = i + 1
        }
        p = p + 1
    }
    return passed
}

// English text RoPE Scaling configurationsummary
func print_rope_config_summary(rope_scaling_config cfg) string {
    string method_name = ""
    if cfg.method == ROPE_SCALING_LINEAR {
        method_name = "Linear (Position Interpolation)"
    } else if cfg.method == ROPE_SCALING_NTK {
        method_name = "NTK-Aware"
    } else {
        method_name = "YaRN (Recommended)"
    }

    "RoPE Scaling Config:\n" +
    "  Method: " + method_name + "\n" +
    "  Original Length: " + string(cfg.original_max_seq_len) + "\n" +
    "  Target Length: " + string(cfg.target_max_seq_len) + "\n" +
    "  Scale Factor: " + string(float_of_int(cfg.target_max_seq_len) / float_of_int(cfg.original_max_seq_len)) + "x\n" +
    "  Base: " + string(cfg.base) + "\n" +
    "  Dim: " + string(cfg.dim)
}
