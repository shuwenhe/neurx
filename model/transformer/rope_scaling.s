package neurx.model.transformer.rope_scaling

// ============================================================================
// RoPE 上下文长度扩展
//
// 基础 RoPE (Su et al., 2021): 旋转位置编码，用复数乘法在 Q/K 上注入位置信息
// 问题: 训练时 context_len=4096，推理时若超过 4096 精度严重退化
//
// 扩展方法:
//   1. Linear Scaling (Meta, 2023): θ_i → θ_i / scale, 简单但插值质量差
//   2. NTK-by-Parts (neural tangent kernel, 2023): 高频维度不插值，低频线性缩放
//   3. YaRN (Peng et al., 2023): 动态温度 + 频率混合插值，最优质量
//   4. LongRoPE (Ding et al., 2024): 非均匀位置插值，支持 2M tokens
//
// 本实现:
//   • 基础 RoPE 前向/反向
//   • Linear Scaling
//   • NTK-by-Parts
//   • YaRN (动态 NTK + 注意力温度缩放)
// ============================================================================

// ============================================================================
// 1. 基础 RoPE
// ============================================================================

struct rope_config {
    int dim          // head_dim (必须为偶数)
    int max_seq_len  // 训练时最大序列长度
    float base       // 频率基数 (通常 10000, Llama3: 500000)
    string method    // "standard" | "linear" | "ntk" | "yarn"

    // 扩展参数
    float scale_factor   // Linear/NTK: 缩放倍数 (e.g. 8.0 → 8× 上下文)
    float yarn_attn_factor  // YaRN: 注意力温度因子 (通常 0.1)
    float yarn_beta_fast // YaRN: 高频分界 (通常 32)
    float yarn_beta_slow // YaRN: 低频分界 (通常 1)
    int   original_max_seq // 原始训练长度 (YaRN 需要)
}

func default_rope_config(int dim, int max_seq_len) rope_config {
    rope_config {
        dim: dim,
        max_seq_len: max_seq_len,
        base: 10000.0,
        method: "standard",
        scale_factor: 1.0,
        yarn_attn_factor: 0.1,
        yarn_beta_fast: 32.0,
        yarn_beta_slow: 1.0,
        original_max_seq: max_seq_len,
    }
}

func yarn_rope_config(int dim, int original_max_seq, int target_max_seq) rope_config {
    float scale = float_rope(target_max_seq) / float_rope(original_max_seq)
    rope_config {
        dim: dim,
        max_seq_len: target_max_seq,
        base: 10000.0,
        method: "yarn",
        scale_factor: scale,
        yarn_attn_factor: 0.1,
        yarn_beta_fast: 32.0,
        yarn_beta_slow: 1.0,
        original_max_seq: original_max_seq,
    }
}

func llama3_rope_config(int dim, int max_seq_len) rope_config {
    // LLaMA-3: 使用更大 base=500000 + NTK
    rope_config {
        dim: dim,
        max_seq_len: max_seq_len,
        base: 500000.0,
        method: "ntk",
        scale_factor: 8.0,
        yarn_attn_factor: 0.1,
        yarn_beta_fast: 32.0,
        yarn_beta_slow: 1.0,
        original_max_seq: 8192,
    }
}

// ============================================================================
// 2. 频率计算
// ============================================================================

// 标准 RoPE 频率: θ_i = base^(-2i/dim)
func compute_rope_freqs(rope_config cfg) []float {
    int half_dim = cfg.dim / 2
    []float freqs = []
    int i = 0
    for i < half_dim {
        float exp = float_rope(2 * i) / float_rope(cfg.dim)
        float theta = pow_rope(cfg.base, 0.0 - exp)
        freqs = append(freqs, theta)
        i = i + 1
    }
    freqs
}

// Linear Scaling: θ_i → θ_i / scale
func compute_linear_scaled_freqs(rope_config cfg) []float {
    []float base_freqs = compute_rope_freqs(cfg)
    []float scaled = []
    int i = 0
    for i < len(base_freqs) {
        scaled = append(scaled, base_freqs[i] / cfg.scale_factor)
        i = i + 1
    }
    scaled
}

// NTK-by-Parts 频率:
//   • 高频 (小 wavelength): 不缩放 (保持精度)
//   • 低频 (大 wavelength): 线性缩放
//   • 中间: 平滑插值
func compute_ntk_freqs(rope_config cfg) []float {
    []float base_freqs = compute_rope_freqs(cfg)
    int half_dim = cfg.dim / 2
    float scale = cfg.scale_factor
    float orig_len = float_rope(cfg.original_max_seq)

    []float ntk_freqs = []
    int i = 0
    for i < half_dim {
        float freq = base_freqs[i]
        // wavelength = 2π / freq
        float wavelength = 6.283185 / freq

        // 判断频率区间
        float lo = orig_len / cfg.yarn_beta_fast  // 高频截断
        float hi = orig_len / cfg.yarn_beta_slow  // 低频截断

        float new_freq = freq
        if wavelength < lo {
            // 高频: 不缩放
            new_freq = freq
        } else {
            if wavelength > hi {
                // 低频: 线性缩放
                new_freq = freq / scale
            } else {
                // 中间: ramp 插值
                float ramp = (wavelength - lo) / (hi - lo)
                if ramp > 1.0 { ramp = 1.0 }
                // new_freq = freq * (1 - ramp) + (freq/scale) * ramp
                new_freq = freq * (1.0 - ramp) + (freq / scale) * ramp
            }
        }

        ntk_freqs = append(ntk_freqs, new_freq)
        i = i + 1
    }
    ntk_freqs
}

// YaRN 频率: NTK-by-Parts + 注意力温度缩放
// YaRN 还需要修正 softmax 温度: scale = 0.1*ln(s) + 1
func compute_yarn_freqs(rope_config cfg) []float {
    // YaRN 使用 NTK-by-Parts 频率
    compute_ntk_freqs(cfg)
}

func yarn_attn_scale(rope_config cfg) float {
    // YaRN 注意力温度: 1 / sqrt(1 + cfg.yarn_attn_factor * ln(scale))
    float ln_scale = log_approx(cfg.scale_factor)
    float factor = 1.0 + cfg.yarn_attn_factor * ln_scale
    1.0 / sqrt_rope(factor)
}

// ============================================================================
// 3. 旋转矩阵 cos/sin 缓存
// ============================================================================

struct rope_cache {
    []float cos_table    // [max_seq_len, half_dim]
    []float sin_table    // [max_seq_len, half_dim]
    int max_seq_len
    int half_dim
    float attn_scale     // YaRN 注意力温度
}

func build_rope_cache(rope_config cfg) rope_cache {
    []float freqs = []
    if cfg.method == "standard" {
        freqs = compute_rope_freqs(cfg)
    } else {
        if cfg.method == "linear" {
            freqs = compute_linear_scaled_freqs(cfg)
        } else {
            if cfg.method == "ntk" {
                freqs = compute_ntk_freqs(cfg)
            } else {
                // yarn
                freqs = compute_yarn_freqs(cfg)
            }
        }
    }

    int half_dim = cfg.dim / 2
    int seq = cfg.max_seq_len
    []float cos_t = zeros_rope(seq * half_dim)
    []float sin_t = zeros_rope(seq * half_dim)

    int pos = 0
    for pos < seq {
        int i = 0
        for i < half_dim {
            float angle = float_rope(pos) * freqs[i]
            cos_t[pos * half_dim + i] = cos_approx(angle)
            sin_t[pos * half_dim + i] = sin_approx(angle)
            i = i + 1
        }
        pos = pos + 1
    }

    float attn_s = 1.0
    if cfg.method == "yarn" {
        attn_s = yarn_attn_scale(cfg)
    }

    rope_cache {
        cos_table: cos_t,
        sin_table: sin_t,
        max_seq_len: seq,
        half_dim: half_dim,
        attn_scale: attn_s,
    }
}

// ============================================================================
// 4. RoPE 应用 (前向)
// ============================================================================

// 对单头单位置应用 RoPE
// x: [head_dim] (前一半和后一半分别做旋转)
// 返回旋转后 [head_dim]
func apply_rope_single([]float x, rope_cache cache, int pos) []float {
    int D = cache.half_dim * 2
    int H = cache.half_dim
    []float out = zeros_rope(D)

    int i = 0
    for i < H {
        float cos_v = cache.cos_table[pos * H + i]
        float sin_v = cache.sin_table[pos * H + i]
        // 旋转: (x_i, x_{i+H}) → (x_i*cos - x_{i+H}*sin, x_i*sin + x_{i+H}*cos)
        float xi   = x[i]
        float xi_H = x[i + H]
        out[i]     = xi * cos_v - xi_H * sin_v
        out[i + H] = xi * sin_v + xi_H * cos_v
        i = i + 1
    }
    out
}

// 批量应用 RoPE: x [seq_len, num_heads, head_dim]
// 每个 token 位置用对应的 cos/sin
func apply_rope_batch(
    []float x,
    rope_cache cache,
    int seq_len, int num_heads, int head_dim,
    int offset   // KV cache 时 offset > 0
) []float {
    int H = head_dim
    []float out = zeros_rope(seq_len * num_heads * H)

    int pos = 0
    for pos < seq_len {
        int h = 0
        for h < num_heads {
            // Slice x[pos, h, :]
            []float xph = zeros_rope(H)
            int d = 0
            for d < H {
                xph[d] = x[pos * num_heads * H + h * H + d]
                d = d + 1
            }

            // Apply rope at position (offset + pos)
            []float rotated = apply_rope_single(xph, cache, offset + pos)

            // Write back
            int d2 = 0
            for d2 < H {
                out[pos * num_heads * H + h * H + d2] = rotated[d2]
                d2 = d2 + 1
            }

            h = h + 1
        }
        pos = pos + 1
    }
    out
}

// ============================================================================
// 5. RoPE 反向 (RoPE 是正交变换，其反向就是转置=逆矩阵)
// ============================================================================

// 梯度直接通过旋转矩阵的转置传递
func apply_rope_backward_single([]float dout, rope_cache cache, int pos) []float {
    int H = cache.half_dim
    []float dx = zeros_rope(H * 2)
    int i = 0
    for i < H {
        float cos_v = cache.cos_table[pos * H + i]
        float sin_v = cache.sin_table[pos * H + i]
        // 旋转矩阵的转置 = 旋转 -angle:
        // (dout_i, dout_{i+H}) → (dout_i*cos + dout_{i+H}*sin, -dout_i*sin + dout_{i+H}*cos)
        float di   = dout[i]
        float di_H = dout[i + H]
        dx[i]     = di * cos_v + di_H * sin_v
        dx[i + H] = 0.0 - di * sin_v + di_H * cos_v
        i = i + 1
    }
    dx
}

func apply_rope_batch_backward(
    []float dout,
    rope_cache cache,
    int seq_len, int num_heads, int head_dim,
    int offset
) []float {
    int H = head_dim
    []float dx = zeros_rope(seq_len * num_heads * H)

    int pos = 0
    for pos < seq_len {
        int h = 0
        for h < num_heads {
            []float doph = zeros_rope(H)
            int d = 0
            for d < H {
                doph[d] = dout[pos * num_heads * H + h * H + d]
                d = d + 1
            }
            []float dx_ph = apply_rope_backward_single(doph, cache, offset + pos)
            int d2 = 0
            for d2 < H {
                dx[pos * num_heads * H + h * H + d2] = dx_ph[d2]
                d2 = d2 + 1
            }
            h = h + 1
        }
        pos = pos + 1
    }
    dx
}

// ============================================================================
// 6. 动态 RoPE 缓存扩展 (推理超出训练长度时)
// ============================================================================

struct dynamic_rope_state {
    rope_config cfg
    rope_cache  cache
    int current_max_len
}

func new_dynamic_rope(rope_config cfg) dynamic_rope_state {
    rope_cache cache = build_rope_cache(cfg)
    dynamic_rope_state {
        cfg: cfg,
        cache: cache,
        current_max_len: cfg.max_seq_len,
    }
}

// 若需要的位置超过缓存长度，自动重建更大的缓存
func dynamic_rope_ensure_length(dynamic_rope_state state, int required_len) dynamic_rope_state {
    if required_len <= state.current_max_len {
        return state
    }

    // 扩展至 required_len 的 2 倍
    int new_len = required_len * 2
    rope_config new_cfg = state.cfg
    new_cfg.max_seq_len = new_len

    // 若是 YaRN，更新 scale_factor
    if new_cfg.method == "yarn" {
        new_cfg.scale_factor = float_rope(new_len) / float_rope(new_cfg.original_max_seq)
    }

    rope_cache new_cache = build_rope_cache(new_cfg)
    dynamic_rope_state {
        cfg: new_cfg,
        cache: new_cache,
        current_max_len: new_len,
    }
}

// ============================================================================
// 7. 工具函数
// ============================================================================

func zeros_rope(int n) []float {
    []float out = []
    int i = 0
    for i < n {
        out = append(out, 0.0)
        i = i + 1
    }
    out
}

func float_rope(int n) float {
    float v = 0.0
    int i = 0
    for i < n {
        v = v + 1.0
        i = i + 1
    }
    v
}

func sqrt_rope(float x) float {
    if x <= 0.0 { return 0.0 }
    float g = x * 0.5 + 0.5
    g = 0.5 * (g + x / g)
    g = 0.5 * (g + x / g)
    g = 0.5 * (g + x / g)
    g
}

// 整数幂
func pow_int(float base, int exp) float {
    float r = 1.0
    int i = 0
    for i < exp {
        r = r * base
        i = i + 1
    }
    r
}

// base^(-exp) 用于 θ_i = base^(-2i/d)
func pow_rope(float base, float neg_exp) float {
    // base^(-e) = 1 / base^e
    // 近似: e^(neg_exp * ln(base))
    float ln_base = log_approx(base)
    float x = neg_exp * ln_base
    exp_rope(x)
}

func exp_rope(float x) float {
    if x > 20.0  { return 485165195.4 }
    if x < -20.0 { return 0.0 }
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    float x5 = x4 * x
    1.0 + x + x2/2.0 + x3/6.0 + x4/24.0 + x5/120.0
}

func log_approx(float x) float {
    // ln(x) 近似, x > 0
    if x <= 0.0 { return -88.0 }
    if x == 1.0 { return 0.0 }
    // 使用 ln(x) = ln(2) * log2(x), log2 用移位
    // 简化近似: 牛顿迭代 ln(x) ≈ 2*(x-1)/(x+1) for x near 1
    // 对大 x: ln(x) = ln(x/e^k) + k, 先做缩放
    float result = 0.0
    float xn = x
    int k = 0
    for xn > 2.718281828 {
        xn = xn / 2.718281828
        k = k + 1
    }
    for xn < 0.367879441 {
        xn = xn * 2.718281828
        k = k - 1
    }
    // xn in [1/e, e], use Padé: ln(x) ≈ 2*(x-1)/(x+1) + correction
    float t = (xn - 1.0) / (xn + 1.0)
    float t2 = t * t
    float t3 = t2 * t
    float t5 = t3 * t2
    result = 2.0 * (t + t3/3.0 + t5/5.0)
    result + float_rope(k)
}

// 泰勒级数 cos/sin 近似
func cos_approx(float x) float {
    // 规约到 [-π, π]
    float pi = 3.14159265358979
    float two_pi = 6.28318530717959
    // 取模
    float xr = x
    for xr > pi  { xr = xr - two_pi }
    for xr < 0.0 - pi { xr = xr + two_pi }
    // cos(x) ≈ 1 - x²/2 + x⁴/24 - x⁶/720
    float x2 = xr * xr
    float x4 = x2 * x2
    float x6 = x4 * x2
    1.0 - x2/2.0 + x4/24.0 - x6/720.0
}

func sin_approx(float x) float {
    float pi = 3.14159265358979
    float two_pi = 6.28318530717959
    float xr = x
    for xr > pi  { xr = xr - two_pi }
    for xr < 0.0 - pi { xr = xr + two_pi }
    // sin(x) ≈ x - x³/6 + x⁵/120 - x⁷/5040
    float x2 = xr * xr
    float x3 = x2 * xr
    float x5 = x3 * x2
    float x7 = x5 * x2
    xr - x3/6.0 + x5/120.0 - x7/5040.0
}
