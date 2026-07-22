

package neurx.attention.mla

struct mla_config {
    int hidden_dim
    int num_q_heads
    int num_kv_heads
    int head_dim
    int kv_lora_rank
    int q_lora_rank
    int rope_head_dim
    float softmax_scale
    bool causal
}

func new_mla_config(int hidden_dim, int num_heads, int kv_lora_rank, int q_lora_rank) mla_config {
    int head_dim = hidden_dim / num_heads
    int rope_dim = 64

    mla_config {
        hidden_dim: hidden_dim,
        num_q_heads: num_heads,
        num_kv_heads: num_heads,
        head_dim: head_dim,
        kv_lora_rank: kv_lora_rank,
        q_lora_rank: q_lora_rank,
        rope_head_dim: rope_dim,
        softmax_scale: 1.0 / sqrt_approx(head_dim + rope_dim),
        causal: true,
    }
}

struct mla_weights {
    mla_config config

    []float w_dq
    []float w_uq
    []float q_norm

    []float w_dkv
    []float w_uk
    []float w_uv
    []float kv_norm

    []float w_qr
    []float w_kr

    []float w_o
}

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    while i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func zeros(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = 0.0
        i = i + 1
    }
    out
}

func fill_ramp(int n, float scale) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = scale * (i + 1) as float / (n + 1) as float
        i = i + 1
    }
    out
}

func exp_approx(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 12 {
        term = term * x / i as float
        result = result + term
        i = i + 1
    }
    result
}

func matmul([]float a, []float b, int m, int k, int n) []float {
    []float result = zeros(m * n)
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

func rms_norm([]float x, int n, float eps) []float {
    []float out = []float{cap: n}
    float sum_sq = 0.0
    int i = 0
    while i < n {
        sum_sq = sum_sq + x[i] * x[i]
        i = i + 1
    }
    float rms = sqrt_approx(sum_sq / n as float + eps)
    i = 0
    while i < n {
        out[i] = x[i] / rms
        i = i + 1
    }
    out
}

func new_mla_weights(mla_config cfg) mla_weights {
    int d = cfg.hidden_dim
    int n_h = cfg.num_q_heads
    int d_h = cfg.head_dim
    int d_c = cfg.kv_lora_rank
    int d_cq = cfg.q_lora_rank
    int d_R = cfg.rope_head_dim

    mla_weights {
        config: cfg,

        w_dq:  fill_ramp(d * d_cq, 0.01),
        w_uq:  fill_ramp(d_cq * n_h * d_h, 0.01),
        q_norm: fill_ramp(d_cq, 1.0),

        w_dkv: fill_ramp(d * d_c, 0.01),
        w_uk:  fill_ramp(d_c * n_h * d_h, 0.01),
        w_uv:  fill_ramp(d_c * n_h * d_h, 0.01),
        kv_norm: fill_ramp(d_c, 1.0),

        w_qr:  fill_ramp(d * n_h * d_R, 0.01),
        w_kr:  fill_ramp(d * n_h * d_R, 0.01),

        w_o:   fill_ramp(n_h * d_h * d, 0.01),
    }
}

func apply_rope([]float x, int seq_len, int head_dim, int start_pos) []float {
    []float out = []float{cap: seq_len * head_dim}
    int s = 0
    while s < seq_len {
        int pos = start_pos + s
        int d = 0
        while d < head_dim {
            int idx = s * head_dim + d
            float theta = pos as float / pow_approx(10000.0, 2.0 * (d / 2) as float / head_dim as float)
            float cos_val = cos_approx(theta)
            float sin_val = sin_approx(theta)

            if d % 2 == 0 {
                int next_idx = s * head_dim + d + 1
                if d + 1 < head_dim {
                    out[idx] = x[idx] * cos_val - x[next_idx] * sin_val
                } else {
                    out[idx] = x[idx] * cos_val
                }
            } else {
                out[idx] = x[idx]
            }
            d = d + 1
        }
        s = s + 1
    }

    s = 0
    while s < seq_len {
        int pos = start_pos + s
        int d = 1
        while d < head_dim {
            int idx = s * head_dim + d
            int prev_idx = s * head_dim + d - 1
            float theta = pos as float / pow_approx(10000.0, 2.0 * ((d - 1) / 2) as float / head_dim as float)
            float cos_val = cos_approx(theta)
            float sin_val = sin_approx(theta)

            out[idx] = x[idx] * cos_val + x[prev_idx] * sin_val
            d = d + 2
        }
        s = s + 1
    }

    out
}

func pow_approx(float base, float exp) float {
    if exp == 0.0 { return 1.0 }
    exp_approx(exp * ln_approx(base))
}

func ln_approx(float x) float {
    if x <= 0.0 { return -1e9 }
    float y = (x - 1.0) / (x + 1.0)
    float y2 = y * y
    float y3 = y2 * y
    float y5 = y3 * y2
    float y7 = y5 * y2
    2.0 * (y + y3 / 3.0 + y5 / 5.0 + y7 / 7.0)
}

func cos_approx(float x) float {
    float x2 = x * x
    float x4 = x2 * x2
    float x6 = x4 * x2
    1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0
}

func sin_approx(float x) float {
    float x2 = x * x
    float x3 = x2 * x
    float x5 = x3 * x2
    float x7 = x5 * x2
    x - x3 / 6.0 + x5 / 120.0 - x7 / 5040.0
}

struct mla_forward_state {
    []float kv_latent
    []float k_rope
}

func mla_forward(mla_weights w, []float h, int seq_len, int start_pos) ([]float, mla_forward_state) {
    mla_config cfg = w.config
    int d = cfg.hidden_dim
    int n_h = cfg.num_q_heads
    int d_h = cfg.head_dim
    int d_c = cfg.kv_lora_rank
    int d_cq = cfg.q_lora_rank
    int d_R = cfg.rope_head_dim
    float scale = cfg.softmax_scale

    []float cq = matmul(h, w.w_dq, seq_len, d, d_cq)
    cq = rms_norm(cq, seq_len * d_cq, 1e-6)
    []float q_main = matmul(cq, w.w_uq, seq_len, d_cq, n_h * d_h)
    []float q_rope = matmul(h, w.w_qr, seq_len, d, n_h * d_R)
    q_rope = apply_rope(q_rope, seq_len, n_h * d_R, start_pos)

    []float c_kv = matmul(h, w.w_dkv, seq_len, d, d_c)
    c_kv = rms_norm(c_kv, seq_len * d_c, 1e-6)
    []float k_main = matmul(c_kv, w.w_uk, seq_len, d_c, n_h * d_h)
    []float v = matmul(c_kv, w.w_uv, seq_len, d_c, n_h * d_h)
    []float k_rope = matmul(h, w.w_kr, seq_len, d, n_h * d_R)
    k_rope = apply_rope(k_rope, seq_len, n_h * d_R, start_pos)

    int total_q_dim = n_h * (d_h + d_R)
    int total_kv_dim = n_h * (d_h + d_R)

    []float q_full = []float{cap: seq_len * total_q_dim}
    []float k_full = []float{cap: seq_len * total_kv_dim}

    int s = 0
    while s < seq_len {
        int h_idx = 0
        while h_idx < n_h {
            int d_idx = 0
            while d_idx < d_h {
                q_full[s * total_q_dim + h_idx * (d_h + d_R) + d_idx] =
                    q_main[s * n_h * d_h + h_idx * d_h + d_idx]
                d_idx = d_idx + 1
            }
            d_idx = 0
            while d_idx < d_R {
                q_full[s * total_q_dim + h_idx * (d_h + d_R) + d_h + d_idx] =
                    q_rope[s * n_h * d_R + h_idx * d_R + d_idx]
                d_idx = d_idx + 1
            }
            h_idx = h_idx + 1
        }

        h_idx = 0
        while h_idx < n_h {
            int d_idx = 0
            while d_idx < d_h {
                k_full[s * total_kv_dim + h_idx * (d_h + d_R) + d_idx] =
                    k_main[s * n_h * d_h + h_idx * d_h + d_idx]
                d_idx = d_idx + 1
            }
            d_idx = 0
            while d_idx < d_R {
                k_full[s * total_kv_dim + h_idx * (d_h + d_R) + d_idx] =
                    k_rope[s * n_h * d_R + h_idx * d_R + d_idx]
                d_idx = d_idx + 1
            }
            h_idx = h_idx + 1
        }
        s = s + 1
    }

    []float attn_out = mla_attention_core(q_full, k_full, v, seq_len, n_h, d_h, d_R, scale, cfg.causal)

    []float output = matmul(attn_out, w.w_o, seq_len, n_h * d_h, d)

    mla_forward_state fwd_state = mla_forward_state {
        kv_latent: c_kv,
        k_rope: k_rope,
    }

    (output, fwd_state)
}

func mla_attention_core(
    []float q, []float k, []float v,
    int seq_len, int n_h, int d_h, int d_R,
    float scale, bool causal
) []float {
    int combined_dim = d_h + d_R
    []float output = zeros(seq_len * n_h * d_h)

    int h = 0
    while h < n_h {
        int h_offset_q = h * combined_dim
        int h_offset_k = h * combined_dim
        int h_offset_o = h * d_h

        int i = 0
        while i < seq_len {
            []float scores = []float{cap: seq_len}
            float max_score = -1e9

            int j = 0
            while j < seq_len {
                float dot = 0.0
                int d_idx = 0
                while d_idx < combined_dim {
                    int q_idx = i * n_h * combined_dim + h_offset_q + d_idx
                    int k_idx = j * n_h * combined_dim + h_offset_k + d_idx
                    dot = dot + q[q_idx] * k[k_idx]
                    d_idx = d_idx + 1
                }
                float score = dot * scale
                if causal && j > i { score = -1e9 }
                scores[j] = score
                if score > max_score { max_score = score }
                j = j + 1
            }

            []float weights = []float{cap: seq_len}
            float sum_exp = 0.0
            j = 0
            while j < seq_len {
                float w = exp_approx(scores[j] - max_score)
                weights[j] = w
                sum_exp = sum_exp + w
                j = j + 1
            }
            if sum_exp > 0.0 {
                j = 0
                while j < seq_len {
                    weights[j] = weights[j] / sum_exp
                    j = j + 1
                }
            }

            int d_idx = 0
            while d_idx < d_h {
                float sum_v = 0.0
                j = 0
                while j < seq_len {
                    int v_idx = j * n_h * d_h + h_offset_o + d_idx
                    sum_v = sum_v + weights[j] * v[v_idx]
                    j = j + 1
                }
                output[i * n_h * d_h + h_offset_o + d_idx] = sum_v
                d_idx = d_idx + 1
            }

            i = i + 1
        }

        h = h + 1
    }

    output
}

struct mla_kv_cache {
    []float kv_latent
    []float k_rope
    int current_len
}

func new_mla_kv_cache(int batch_size, int max_seq_len, mla_config cfg) mla_kv_cache {
    int d_c = cfg.kv_lora_rank
    int d_R = cfg.rope_head_dim
    int n_h = cfg.num_kv_heads

    mla_kv_cache {
        kv_latent: zeros(batch_size * max_seq_len * d_c),
        k_rope: zeros(batch_size * max_seq_len * n_h * d_R),
        current_len: 0,
    }
}

func mla_forward_incremental(
    mla_weights w, []float h, mla_kv_cache cache, int pos
) ([]float, mla_kv_cache) {
    mla_config cfg = w.config
    int d = cfg.hidden_dim
    int n_h = cfg.num_q_heads
    int d_h = cfg.head_dim
    int d_c = cfg.kv_lora_rank
    int d_cq = cfg.q_lora_rank
    int d_R = cfg.rope_head_dim
    float scale = cfg.softmax_scale

    []float cq = matmul(h, w.w_dq, 1, d, d_cq)
    cq = rms_norm(cq, d_cq, 1e-6)
    []float q_main = matmul(cq, w.w_uq, 1, d_cq, n_h * d_h)
    []float q_rope = matmul(h, w.w_qr, 1, d, n_h * d_R)
    q_rope = apply_rope(q_rope, 1, n_h * d_R, pos)

    int total_q_dim = n_h * (d_h + d_R)
    []float q_full = []float{cap: total_q_dim}
    int h_idx = 0
    while h_idx < n_h {
        int d_idx = 0
        while d_idx < d_h {
            q_full[h_idx * (d_h + d_R) + d_idx] = q_main[h_idx * d_h + d_idx]
            d_idx = d_idx + 1
        }
        d_idx = 0
        while d_idx < d_R {
            q_full[h_idx * (d_h + d_R) + d_h + d_idx] = q_rope[h_idx * d_R + d_idx]
            d_idx = d_idx + 1
        }
        h_idx = h_idx + 1
    }

    []float c_kv = matmul(h, w.w_dkv, 1, d, d_c)
    c_kv = rms_norm(c_kv, d_c, 1e-6)
    []float k_rope_new = matmul(h, w.w_kr, 1, d, n_h * d_R)
    k_rope_new = apply_rope(k_rope_new, 1, n_h * d_R, pos)

    int cache_offset = pos * d_c
    int d_idx = 0
    while d_idx < d_c {
        cache.kv_latent[cache_offset + d_idx] = c_kv[d_idx]
        d_idx = d_idx + 1
    }

    int rope_offset = pos * n_h * d_R
    d_idx = 0
    while d_idx < n_h * d_R {
        cache.k_rope[rope_offset + d_idx] = k_rope_new[d_idx]
        d_idx = d_idx + 1
    }

    int cached_len = cache.current_len + 1
    []float k_main = matmul(cache.kv_latent, w.w_uk, cached_len, d_c, n_h * d_h)
    []float v_all = matmul(cache.kv_latent, w.w_uv, cached_len, d_c, n_h * d_h)

    int total_kv_dim = n_h * (d_h + d_R)
    []float k_full = []float{cap: cached_len * total_kv_dim}
    int s = 0
    while s < cached_len {
        h_idx = 0
        while h_idx < n_h {
            d_idx = 0
            while d_idx < d_h {
                k_full[s * total_kv_dim + h_idx * (d_h + d_R) + d_idx] =
                    k_main[s * n_h * d_h + h_idx * d_h + d_idx]
                d_idx = d_idx + 1
            }
            d_idx = 0
            while d_idx < d_R {
                int k_rope_idx = s * n_h * d_R + h_idx * d_R + d_idx
                k_full[s * total_kv_dim + h_idx * (d_h + d_R) + d_h + d_idx] =
                    cache.k_rope[k_rope_idx]
                d_idx = d_idx + 1
            }
            h_idx = h_idx + 1
        }
        s = s + 1
    }

    []float attn_out = mla_attention_single_query(q_full, k_full, v_all, cached_len, n_h, d_h, d_R, scale)

    []float output = matmul(attn_out, w.w_o, 1, n_h * d_h, d)

    mla_kv_cache new_cache = cache
    new_cache.current_len = cached_len

    (output, new_cache)
}

func mla_attention_single_query(
    []float q, []float k, []float v,
    int kv_len, int n_h, int d_h, int d_R, float scale
) []float {
    int combined_dim = d_h + d_R
    []float output = zeros(n_h * d_h)

    int h = 0
    while h < n_h {
        []float scores = []float{cap: kv_len}
        float max_score = -1e9

        int j = 0
        while j < kv_len {
            float dot = 0.0
            int d_idx = 0
            while d_idx < combined_dim {
                int q_idx = h * combined_dim + d_idx
                int k_idx = j * n_h * combined_dim + h * combined_dim + d_idx
                dot = dot + q[q_idx] * k[k_idx]
                d_idx = d_idx + 1
            }
            scores[j] = dot * scale
            if scores[j] > max_score { max_score = scores[j] }
            j = j + 1
        }

        []float weights = []float{cap: kv_len}
        float sum_exp = 0.0
        j = 0
        while j < kv_len {
            float w = exp_approx(scores[j] - max_score)
            weights[j] = w
            sum_exp = sum_exp + w
            j = j + 1
        }
        if sum_exp > 0.0 {
            j = 0
            while j < kv_len {
                weights[j] = weights[j] / sum_exp
                j = j + 1
            }
        }

        int d_idx = 0
        while d_idx < d_h {
            float sum_v = 0.0
            j = 0
            while j < kv_len {
                sum_v = sum_v + weights[j] * v[j * n_h * d_h + h * d_h + d_idx]
                j = j + 1
            }
            output[h * d_h + d_idx] = sum_v
            d_idx = d_idx + 1
        }

        h = h + 1
    }

    output
}

func compute_kv_cache_size(int n_layers, int n_heads, int d_head, int d_lora, int d_rope) (int, int) {

    int standard_size = 2 * n_layers * n_heads * d_head

    int mla_size = 2 * n_layers * (d_lora + n_heads * d_rope)

    (standard_size, mla_size)
}

func compute_savings_ratio(int standard_size, int mla_size) float {
    (standard_size - mla_size) as float / standard_size as float * 100.0
}

func unit_name() string {
    "neurx/model/neurx/mla"
}

func unit_ready() int {
    1
}
