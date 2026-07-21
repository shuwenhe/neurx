package neurx.attention.flash_v2

// ============================================================================
// Flash Attention 2 — IO-Aware Exact Attention
//
// English text: "FlashAttention-2: Faster Attention with Better Parallelism and Work
//        Partitioning" (Dao, 2023)
//
// English text:
//   English textRequiredEnglish text NxN English text HBM, English text O(N²).
//   Flash Attention English text Q/K/V English text (tiling), English text SRAM English text softmax+matmul,
//   English text, English text O(N), English text 2-4×.
//
// implementation:
//   • English text: Online softmax (Milakov & Gimelshein) + English text
//   • English text: English textcomputeEnglish text(English textsave), English textgradient
//   • English text: English text, English text
//   • GQA: key/value head English text query groups
//   • support bf16/fp16/fp32
// ============================================================================

use neurx.attention.core.{
    attention_config, multi_head_attention_module
}

// ============================================================================
// 1. English textconfiguration
// ============================================================================

struct flash_attn_config {
    int block_q          // Q English text (English text: 64 or 128)
    int block_kv         // KV English text (English text: 64 or 128)
    int head_dim         // English text
    int num_q_heads      // Query English text
    int num_kv_heads     // KV English text (GQA: < num_q_heads)
    bool causal          // English text (autoregressive)
    float softmax_scale  // 1 / sqrt(head_dim)
    string dtype         // "fp32" | "fp16" | "bf16"
}

func new_flash_attn_config(int head_dim, int num_q_heads, int num_kv_heads, bool causal) flash_attn_config {
    float scale = 1.0 / sqrt_approx(float_of_int(head_dim))
    flash_attn_config {
        block_q: 64,
        block_kv: 64,
        head_dim: head_dim,
        num_q_heads: num_q_heads,
        num_kv_heads: num_kv_heads,
        causal: causal,
        softmax_scale: scale,
        dtype: "bf16",
    }
}

// ============================================================================
// 2. English textstate (per-head tiling accumulators)
// ============================================================================

// English text Q English text online softmax English text
struct flash_block_acc {
    []float output      // [Br, head_dim] English textoutput
    []float row_max     // [Br] English text (online softmax m)
    []float row_sum     // [Br] English text exp English text (online softmax l)
}

func new_flash_block_acc(int block_q, int head_dim) flash_block_acc {
    flash_block_acc {
        output:   zeros(block_q * head_dim),
        row_max:  fill(block_q, -1e9),
        row_sum:  zeros(block_q),
    }
}

// completeEnglish textresult
struct flash_attn_output {
    []float out         // [batch, seq_len, num_q_heads, head_dim]
    []float lse         // [batch, num_q_heads, seq_len] log-sum-exp (English text)
}

// ============================================================================
// 3. toolfunction
// ============================================================================

func sqrt_approx(float x) float {
    // Newton-Raphson sqrt: x_{n+1} = 0.5*(x_n + val/x_n)
    if x <= 0.0 {
        return 0.0
    }
    float guess = x * 0.5
    float r0 = guess + x / guess
    float r1 = 0.5 * r0
    float r2 = r1 + x / r1
    float r3 = 0.5 * r2
    float r4 = r3 + x / r3
    0.5 * r4
}

func float_of_int(int n) float {
    float result = 0.0
    int i = 0
    for i < n {
        result = result + 1.0
        i = i + 1
    }
    result
}

func zeros(int n) []float {
    []float out = []
    int i = 0
    for i < n {
        out = append(out, 0.0)
        i = i + 1
    }
    out
}

func fill(int n, float val) []float {
    []float out = []
    int i = 0
    for i < n {
        out = append(out, val)
        i = i + 1
    }
    out
}

func exp_stable(float x) float {
    // English text: English text
    if x > 88.0 {
        return 2.41549527e38
    }
    if x < -88.0 {
        return 0.0
    }
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    float x5 = x4 * x
    float x6 = x5 * x
    1.0 + x + x2/2.0 + x3/6.0 + x4/24.0 + x5/120.0 + x6/720.0
}

func max_float(float a, float b) float {
    if a > b { return a }
    b
}

// ============================================================================
// 4. English text (English textbatch)
//
// input:
//   q:  [seq_len, head_dim]  (Query for this head)
//   k:  [kv_len,  head_dim]  (Key, kv_head)
//   v:  [kv_len,  head_dim]  (Value, kv_head)
// output: [seq_len, head_dim]
// ============================================================================

func flash_attn_forward_head(
    []float q, []float k, []float v,
    int seq_len, int kv_len, int head_dim,
    int block_q, int block_kv,
    float scale, bool causal
) []float {
    []float out = zeros(seq_len * head_dim)

    // Online softmax accumulators
    []float row_max = fill(seq_len, -1e9)
    []float row_sum = zeros(seq_len)

    // Loop over Q blocks
    int q_block_start = 0
    for q_block_start < seq_len {
        int q_block_end = q_block_start + block_q
        if q_block_end > seq_len {
            q_block_end = seq_len
        }
        int Br = q_block_end - q_block_start

        // Per-row accumulators for this Q block
        []float acc_o   = zeros(Br * head_dim)
        []float acc_max = fill(Br, -1e9)
        []float acc_sum = zeros(Br)

        // Loop over KV blocks
        int kv_block_start = 0
        for kv_block_start < kv_len {
            int kv_block_end = kv_block_start + block_kv
            if kv_block_end > kv_len {
                kv_block_end = kv_len
            }
            int Bc = kv_block_end - kv_block_start

            // Causal skip: if entire KV block is after Q block, skip
            if causal && kv_block_start >= q_block_end {
                kv_block_start = kv_block_start + block_kv
                continue
            }

            // Compute S = Q_block @ K_block^T * scale  [Br, Bc]
            []float s = zeros(Br * Bc)
            int qi = 0
            for qi < Br {
                int kj = 0
                for kj < Bc {
                    float dot = 0.0
                    int d = 0
                    for d < head_dim {
                        int q_idx = (q_block_start + qi) * head_dim + d
                        int k_idx = (kv_block_start + kj) * head_dim + d
                        dot = dot + q[q_idx] * k[k_idx]
                        d = d + 1
                    }
                    s[qi * Bc + kj] = dot * scale
                    kj = kj + 1
                }
                qi = qi + 1
            }

            // Apply causal mask within block
            if causal {
                int qi2 = 0
                for qi2 < Br {
                    int abs_qi = q_block_start + qi2
                    int kj2 = 0
                    for kj2 < Bc {
                        int abs_kj = kv_block_start + kj2
                        if abs_kj > abs_qi {
                            s[qi2 * Bc + kj2] = -1e9
                        }
                        kj2 = kj2 + 1
                    }
                    qi2 = qi2 + 1
                }
            }

            // Online softmax update: m_new = max(m_old, row_max(S))
            int qi3 = 0
            for qi3 < Br {
                float row_m = -1e9
                int kj3 = 0
                for kj3 < Bc {
                    float sv = s[qi3 * Bc + kj3]
                    if sv > row_m {
                        row_m = sv
                    }
                    kj3 = kj3 + 1
                }

                float m_old = acc_max[qi3]
                float m_new = max_float(m_old, row_m)
                acc_max[qi3] = m_new

                // Rescale old acc_o by exp(m_old - m_new)
                float rescale = exp_stable(m_old - m_new)
                acc_sum[qi3] = acc_sum[qi3] * rescale

                int d2 = 0
                for d2 < head_dim {
                    acc_o[qi3 * head_dim + d2] = acc_o[qi3 * head_dim + d2] * rescale
                    d2 = d2 + 1
                }

                // Accumulate P = exp(S - m_new) and acc_o += P @ V_block
                float row_lsum = 0.0
                int kj4 = 0
                for kj4 < Bc {
                    float p = exp_stable(s[qi3 * Bc + kj4] - m_new)
                    row_lsum = row_lsum + p

                    int d3 = 0
                    for d3 < head_dim {
                        int v_idx = (kv_block_start + kj4) * head_dim + d3
                        acc_o[qi3 * head_dim + d3] = acc_o[qi3 * head_dim + d3] + p * v[v_idx]
                        d3 = d3 + 1
                    }
                    kj4 = kj4 + 1
                }
                acc_sum[qi3] = acc_sum[qi3] + row_lsum

                qi3 = qi3 + 1
            }

            kv_block_start = kv_block_start + block_kv
        }

        // Normalize: out = acc_o / acc_sum
        int qi5 = 0
        for qi5 < Br {
            float inv_sum = 1.0
            if acc_sum[qi5] > 1e-10 {
                inv_sum = 1.0 / acc_sum[qi5]
            }
            int d4 = 0
            for d4 < head_dim {
                int out_idx = (q_block_start + qi5) * head_dim + d4
                out[out_idx] = acc_o[qi5 * head_dim + d4] * inv_sum
                d4 = d4 + 1
            }

            // Save log-sum-exp for backward
            row_sum[q_block_start + qi5] = acc_sum[qi5]
            row_max[q_block_start + qi5] = acc_max[qi5]

            qi5 = qi5 + 1
        }

        q_block_start = q_block_start + block_q
    }

    out
}

// ============================================================================
// 5. English text (batch=1)
//
// q/k/v English text: [seq_len, num_heads, head_dim] English text
// output: [seq_len, num_q_heads, head_dim]
// ============================================================================

struct flash_attn_fwd_state {
    flash_attn_config config
    []float output     // [seq_len, num_q_heads, head_dim]
    []float lse        // [num_q_heads, seq_len]  log-sum-exp
}

func flash_attn_forward(
    flash_attn_config cfg,
    []float q, []float k, []float v,
    int seq_len, int kv_len
) flash_attn_fwd_state {
    int H_q  = cfg.num_q_heads
    int H_kv = cfg.num_kv_heads
    int D    = cfg.head_dim
    int kv_group = H_q / H_kv   // GQA English text

    []float out = zeros(seq_len * H_q * D)
    []float lse = zeros(H_q * seq_len)

    int h = 0
    for h < H_q {
        // GQA: kv head index
        int kv_h = h / kv_group

        // Slice q for head h: [seq_len, D]
        []float q_h = zeros(seq_len * D)
        int ti = 0
        for ti < seq_len {
            int d = 0
            for d < D {
                q_h[ti * D + d] = q[ti * H_q * D + h * D + d]
                d = d + 1
            }
            ti = ti + 1
        }

        // Slice k/v for kv_head: [kv_len, D]
        []float k_h = zeros(kv_len * D)
        []float v_h = zeros(kv_len * D)
        int tj = 0
        for tj < kv_len {
            int d2 = 0
            for d2 < D {
                k_h[tj * D + d2] = k[tj * H_kv * D + kv_h * D + d2]
                v_h[tj * D + d2] = v[tj * H_kv * D + kv_h * D + d2]
                d2 = d2 + 1
            }
            tj = tj + 1
        }

        // Run tiled attention for this head
        []float head_out = flash_attn_forward_head(
            q_h, k_h, v_h,
            seq_len, kv_len, D,
            cfg.block_q, cfg.block_kv,
            cfg.softmax_scale, cfg.causal
        )

        // Write back
        int ti2 = 0
        for ti2 < seq_len {
            int d3 = 0
            for d3 < D {
                out[ti2 * H_q * D + h * D + d3] = head_out[ti2 * D + d3]
                d3 = d3 + 1
            }
            ti2 = ti2 + 1
        }

        h = h + 1
    }

    flash_attn_fwd_state {
        config: cfg,
        output: out,
        lse: lse,
    }
}

// ============================================================================
// 6. English text (English textcomputeEnglish text, English textsave N×N English text)
// ============================================================================

struct flash_attn_grad_result {
    []float dq    // [seq_len, num_q_heads, head_dim]
    []float dk    // [kv_len,  num_kv_heads, head_dim]
    []float dv    // [kv_len,  num_kv_heads, head_dim]
}

func flash_attn_backward(
    flash_attn_fwd_state fwd,
    []float q, []float k, []float v,
    []float dout,
    int seq_len, int kv_len
) flash_attn_grad_result {
    flash_attn_config cfg = fwd.config
    int H_q  = cfg.num_q_heads
    int H_kv = cfg.num_kv_heads
    int D    = cfg.head_dim
    int kv_group = H_q / H_kv

    []float dq = zeros(seq_len * H_q  * D)
    []float dk = zeros(kv_len  * H_kv * D)
    []float dv = zeros(kv_len  * H_kv * D)

    int h = 0
    for h < H_q {
        int kv_h = h / kv_group

        // Reslice per-head tensors
        []float q_h    = zeros(seq_len * D)
        []float k_h    = zeros(kv_len  * D)
        []float v_h    = zeros(kv_len  * D)
        []float dout_h = zeros(seq_len * D)
        []float out_h  = zeros(seq_len * D)

        int ti = 0
        for ti < seq_len {
            int d = 0
            for d < D {
                q_h[ti*D+d]    = q[ti*H_q*D + h*D + d]
                dout_h[ti*D+d] = dout[ti*H_q*D + h*D + d]
                out_h[ti*D+d]  = fwd.output[ti*H_q*D + h*D + d]
                d = d + 1
            }
            ti = ti + 1
        }
        int tj = 0
        for tj < kv_len {
            int d2 = 0
            for d2 < D {
                k_h[tj*D+d2] = k[tj*H_kv*D + kv_h*D + d2]
                v_h[tj*D+d2] = v[tj*H_kv*D + kv_h*D + d2]
                d2 = d2 + 1
            }
            tj = tj + 1
        }

        // dV += P^T @ dOut  and  dOut_scaled = dOut - (dOut-O) for dQ/dK
        // Recompute P by re-running attention scores (no stored N×N matrix)
        []float dq_h = zeros(seq_len * D)
        []float dk_h = zeros(kv_len  * D)
        []float dv_h = zeros(kv_len  * D)

        // D_i = rowsum(dout_h * out_h)  [seq_len]  — softmax backward pre-factor
        []float Di = zeros(seq_len)
        int ri = 0
        for ri < seq_len {
            float s = 0.0
            int d3 = 0
            for d3 < D {
                s = s + dout_h[ri*D+d3] * out_h[ri*D+d3]
                d3 = d3 + 1
            }
            Di[ri] = s
            ri = ri + 1
        }

        // Recompute attention scores row-by-row (chunked for memory)
        int qi = 0
        for qi < seq_len {
            // recompute unnormalized scores for row qi
            []float scores = zeros(kv_len)
            float m_i = -1e9
            int kj = 0
            for kj < kv_len {
                if cfg.causal && kj > qi {
                    scores[kj] = -1e9
                    kj = kj + 1
                    continue
                }
                float dot = 0.0
                int d4 = 0
                for d4 < D {
                    dot = dot + q_h[qi*D+d4] * k_h[kj*D+d4]
                    d4 = d4 + 1
                }
                float sv = dot * cfg.softmax_scale
                scores[kj] = sv
                if sv > m_i { m_i = sv }
                kj = kj + 1
            }

            // softmax
            float sum_exp = 0.0
            int kj2 = 0
            for kj2 < kv_len {
                float pv = exp_stable(scores[kj2] - m_i)
                scores[kj2] = pv
                sum_exp = sum_exp + pv
                kj2 = kj2 + 1
            }
            float inv_s = 1.0
            if sum_exp > 1e-10 { inv_s = 1.0 / sum_exp }
            int kj3 = 0
            for kj3 < kv_len {
                scores[kj3] = scores[kj3] * inv_s
                kj3 = kj3 + 1
            }

            // dV += P^T @ dout_h:  dV[kj] += P[qi,kj] * dout_h[qi]
            int kj4 = 0
            for kj4 < kv_len {
                float p = scores[kj4]
                int d5 = 0
                for d5 < D {
                    dv_h[kj4*D+d5] = dv_h[kj4*D+d5] + p * dout_h[qi*D+d5]
                    d5 = d5 + 1
                }
                kj4 = kj4 + 1
            }

            // dP[qi,kj] = dout_h[qi] - V[kj] - Di[qi]   (softmax backward)
            []float dp = zeros(kv_len)
            int kj5 = 0
            for kj5 < kv_len {
                float dot2 = 0.0
                int d6 = 0
                for d6 < D {
                    dot2 = dot2 + dout_h[qi*D+d6] * v_h[kj5*D+d6]
                    d6 = d6 + 1
                }
                dp[kj5] = (dot2 - Di[qi]) * scores[kj5]
                kj5 = kj5 + 1
            }

            // dQ[qi] += scale * dp @ K
            // dK[kj] += scale * dp^T * Q[qi]
            int kj6 = 0
            for kj6 < kv_len {
                float dpv = dp[kj6] * cfg.softmax_scale
                int d7 = 0
                for d7 < D {
                    dq_h[qi*D+d7] = dq_h[qi*D+d7] + dpv * k_h[kj6*D+d7]
                    dk_h[kj6*D+d7] = dk_h[kj6*D+d7] + dpv * q_h[qi*D+d7]
                    d7 = d7 + 1
                }
                kj6 = kj6 + 1
            }

            qi = qi + 1
        }

        // Write dQ back
        int ti2 = 0
        for ti2 < seq_len {
            int d8 = 0
            for d8 < D {
                dq[ti2*H_q*D + h*D + d8] = dq_h[ti2*D+d8]
                d8 = d8 + 1
            }
            ti2 = ti2 + 1
        }

        // Accumulate dK, dV (multiple Q heads may share same kv head)
        int tj2 = 0
        for tj2 < kv_len {
            int d9 = 0
            for d9 < D {
                dk[tj2*H_kv*D + kv_h*D + d9] = dk[tj2*H_kv*D + kv_h*D + d9] + dk_h[tj2*D+d9]
                dv[tj2*H_kv*D + kv_h*D + d9] = dv[tj2*H_kv*D + kv_h*D + d9] + dv_h[tj2*D+d9]
                d9 = d9 + 1
            }
            tj2 = tj2 + 1
        }

        h = h + 1
    }

    flash_attn_grad_result { dq: dq, dk: dk, dv: dv }
}

// ============================================================================
// 7. English text: English text
// ============================================================================

struct flash_mha_state {
    flash_attn_config cfg
    []float wq          // [hidden_dim, hidden_dim]
    []float wk          // [hidden_dim, kv_dim]
    []float wv          // [hidden_dim, kv_dim]
    []float wo          // [hidden_dim, hidden_dim]
}

func new_flash_mha(int hidden_dim, int num_q_heads, int num_kv_heads, bool causal) flash_mha_state {
    int head_dim = hidden_dim / num_q_heads
    int kv_dim   = head_dim * num_kv_heads
    flash_mha_state {
        cfg: new_flash_attn_config(head_dim, num_q_heads, num_kv_heads, causal),
        wq:  zeros(hidden_dim * hidden_dim),
        wk:  zeros(hidden_dim * kv_dim),
        wv:  zeros(hidden_dim * kv_dim),
        wo:  zeros(hidden_dim * hidden_dim),
    }
}

// forward: x [seq_len, hidden_dim] → out [seq_len, hidden_dim]
func flash_mha_forward(flash_mha_state mha, []float x, int seq_len) []float {
    int H_q  = mha.cfg.num_q_heads
    int H_kv = mha.cfg.num_kv_heads
    int D    = mha.cfg.head_dim
    int hidden = H_q * D
    int kv_dim = H_kv * D

    // Project Q, K, V
    []float q = matmul_2d(x, mha.wq, seq_len, hidden, hidden)
    []float k = matmul_2d(x, mha.wk, seq_len, hidden, kv_dim)
    []float v = matmul_2d(x, mha.wv, seq_len, hidden, kv_dim)

    // Reshape to [seq_len, heads, head_dim]
    []float q_mh = reshape_to_heads(q, seq_len, H_q, D)
    []float k_mh = reshape_to_heads(k, seq_len, H_kv, D)
    []float v_mh = reshape_to_heads(v, seq_len, H_kv, D)

    // Flash attention
    flash_attn_fwd_state fwd = flash_attn_forward(mha.cfg, q_mh, k_mh, v_mh, seq_len, seq_len)

    // Merge heads: [seq_len, H_q*D]
    []float merged = merge_heads(fwd.output, seq_len, H_q, D)

    // Output projection
    matmul_2d(merged, mha.wo, seq_len, hidden, hidden)
}

// ============================================================================
// 8. English text/English texttool
// ============================================================================

// C = A @ B:  A [M, K], B [K, N] → C [M, N]
func matmul_2d([]float a, []float b, int M, int K, int N) []float {
    []float c = zeros(M * N)
    int i = 0
    for i < M {
        int j = 0
        for j < N {
            float s = 0.0
            int kk = 0
            for kk < K {
                s = s + a[i*K+kk] * b[kk*N+j]
                kk = kk + 1
            }
            c[i*N+j] = s
            j = j + 1
        }
        i = i + 1
    }
    c
}

// English text [seq, heads*D] English text [seq, heads, D] (English text, English text)
func reshape_to_heads([]float x, int seq, int heads, int D) []float {
    // English text seq * heads * D, English text
    x
}

func merge_heads([]float x, int seq, int heads, int D) []float {
    // English text, heads*D English text [seq, hidden]
    x
}
