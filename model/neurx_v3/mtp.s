// ============================================================================
// Multi-Token Prediction (MTP) — NeurX reference implementation
//
// Paper: MTP reference architecture used by NeurX
//
// Core idea: predict D future tokens per position, boosting data efficiency.
// Each MTP Module: Embedding + Projection + 1-layer Transformer + Output Head
// Loss: L_MTP = (1/D) * sum CE(p_i, t_i)
// Also enables speculative decoding at inference time.
// ============================================================================

package neurx.model.neurx.mtp

// ============================================================================
// 1. MTP Config
// ============================================================================

struct mtp_config {
    int hidden_dim              // model hidden dim
    int vocab_size              // vocabulary size
    int num_mtp_layers          // D = future tokens to predict (e.g. 2)
    int ff_intermediate_dim     // MTP Transformer Block FFN dim
    int num_attention_heads     // MTP attention heads
    int head_dim                // per-head dim
    float rope_theta            // RoPE base theta
    bool causal                 // causal attention
}

func new_mtp_config() mtp_config {
    mtp_config {
        hidden_dim: 5120,
        vocab_size: 128000,
        num_mtp_layers: 2,
        ff_intermediate_dim: 12288,
        num_attention_heads: 32,
        head_dim: 128,
        rope_theta: 10000.0,
        causal: true,
    }
}

// ============================================================================
// 2. MTP Module Weights (single prediction layer)
// ============================================================================

struct mtp_module_weights {
    []float proj_h              // [hidden_dim, hidden_dim]
    []float emb_norm_weight     // [hidden_dim]
    []float proj_emb            // [hidden_dim, hidden_dim]

    // Transformer Block (1 layer, lightweight)
    []float attn_norm_weight    // [hidden_dim]
    []float q_weight            // [hidden_dim, num_heads * head_dim]
    []float k_weight            // [hidden_dim, num_heads * head_dim]
    []float v_weight            // [hidden_dim, num_heads * head_dim]
    []float o_weight            // [num_heads * head_dim, hidden_dim]

    []float ffn_norm_weight     // [hidden_dim]
    []float ffn_w1              // [hidden_dim, ff_intermediate_dim]
    []float ffn_w2              // [ff_intermediate_dim, hidden_dim]

    []float output_head         // [hidden_dim, vocab_size]
}

// ============================================================================
// 3. Full MTP Weights
// ============================================================================

struct mtp_weights {
    mtp_config config
    []float token_embedding      // [vocab_size, hidden_dim] (shared from main model)
    []mtp_module_weights modules // D MTP modules
}

// ============================================================================
// 4. Math Utilities
// ============================================================================

func zeros(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n { out[i] = 0.0; i = i + 1 }
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

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    while i < 10 { y = 0.5 * (y + x / y); i = i + 1 }
    y
}

func gelu(float x) float {
    float c = 0.7978845608028654
    float x3 = x * x * x
    float inner = c * (x + 0.044715 * x3)
    float e2 = exp_approx(2.0 * inner)
    float tanh_val = (e2 - 1.0) / (e2 + 1.0)
    0.5 * x * (1.0 + tanh_val)
}

func matmul_2d([]float a, []float b, int m, int k, int n) []float {
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

func rms_norm([]float x, int n, []float weight, float eps) []float {
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
        out[i] = x[i] * weight[i] / rms
        i = i + 1
    }
    out
}

// ============================================================================
// 5. MTP Module Weight Initialization
// ============================================================================

func new_mtp_module_weights(mtp_config cfg) mtp_module_weights {
    int d = cfg.hidden_dim
    int v = cfg.vocab_size
    int n_h = cfg.num_attention_heads
    int d_h = cfg.head_dim
    int ff = cfg.ff_intermediate_dim
    int hd = n_h * d_h

    mtp_module_weights {
        proj_h: fill_ramp(d * d, 0.01),
        emb_norm_weight: fill_ramp(d, 1.0),
        proj_emb: fill_ramp(d * d, 0.01),

        attn_norm_weight: fill_ramp(d, 1.0),
        q_weight: fill_ramp(d * hd, 0.02),
        k_weight: fill_ramp(d * hd, 0.02),
        v_weight: fill_ramp(d * hd, 0.02),
        o_weight: fill_ramp(hd * d, 0.02),

        ffn_norm_weight: fill_ramp(d, 1.0),
        ffn_w1: fill_ramp(d * ff, 0.02),
        ffn_w2: fill_ramp(ff * d, 0.02),

        output_head: fill_ramp(d * v, 0.01),
    }
}

func new_mtp_weights(mtp_config cfg) mtp_weights {
    int D = cfg.num_mtp_layers
    int d = cfg.hidden_dim
    int v = cfg.vocab_size

    []mtp_module_weights modules = []mtp_module_weights{cap: D}
    int i = 0
    while i < D {
        modules[i] = new_mtp_module_weights(cfg)
        i = i + 1
    }

    mtp_weights {
        config: cfg,
        token_embedding: fill_ramp(v * d, 0.02),
        modules: modules,
    }
}

// ============================================================================
// 6. MTP Module Single-Layer Forward
// ============================================================================

struct mtp_module_output {
    []float hidden_state        // [seq_len, hidden_dim]
    []float logits              // [seq_len, vocab_size]
}

func mtp_module_forward(
    mtp_module_weights w, []float main_hidden,
    []int prev_tokens, int seq_len, int pos_offset,
    []float shared_embed, mtp_config cfg
) mtp_module_output {
    int d = cfg.hidden_dim
    int v = cfg.vocab_size
    int n_h = cfg.num_attention_heads
    int d_h = cfg.head_dim
    int hd = n_h * d_h

    // Step 1: Combine = Proj_h(h_main) + Proj_emb(RMSNorm(Emb(t)))
    []float emb_input = zeros(seq_len * d)
    int s = 0
    while s < seq_len {
        int token = prev_tokens[s]
        int dim = 0
        while dim < d {
            emb_input[s * d + dim] = shared_embed[token * d + dim]
            dim = dim + 1
        }
        s = s + 1
    }

    []float emb_normed = rms_norm(emb_input, seq_len * d, w.emb_norm_weight, 1e-6)

    []float combined_h = matmul_2d(main_hidden, w.proj_h, seq_len, d, d)
    []float combined_emb = matmul_2d(emb_normed, w.proj_emb, seq_len, d, d)

    []float combined = zeros(seq_len * d)
    int i = 0
    while i < seq_len * d {
        combined[i] = combined_h[i] + combined_emb[i]
        i = i + 1
    }

    // Step 2: Transformer Block (1 layer)
    []float attn_normed = rms_norm(combined, seq_len * d, w.attn_norm_weight, 1e-6)

    []float q = matmul_2d(attn_normed, w.q_weight, seq_len, d, hd)
    []float k = matmul_2d(attn_normed, w.k_weight, seq_len, d, hd)
    []float v = matmul_2d(attn_normed, w.v_weight, seq_len, d, hd)

    []float attn_out = multi_head_attention(q, k, v, seq_len, n_h, d_h, cfg.causal)
    []float attn_proj = matmul_2d(attn_out, w.o_weight, seq_len, hd, d)

    []float attn_residual = zeros(seq_len * d)
    i = 0
    while i < seq_len * d {
        attn_residual[i] = combined[i] + attn_proj[i]
        i = i + 1
    }

    []float ffn_normed = rms_norm(attn_residual, seq_len * d, w.ffn_norm_weight, 1e-6)

    []float ffn_hidden = matmul_2d(ffn_normed, w.ffn_w1, seq_len, d, cfg.ff_intermediate_dim)
    i = 0
    while i < seq_len * cfg.ff_intermediate_dim {
        ffn_hidden[i] = gelu(ffn_hidden[i])
        i = i + 1
    }
    []float ffn_out = matmul_2d(ffn_hidden, w.ffn_w2, seq_len, cfg.ff_intermediate_dim, d)

    []float ffn_residual = zeros(seq_len * d)
    i = 0
    while i < seq_len * d {
        ffn_residual[i] = attn_residual[i] + ffn_out[i]
        i = i + 1
    }

    // Step 3: Output Head -> logits
    []float logits = matmul_2d(ffn_residual, w.output_head, seq_len, d, v)

    mtp_module_output {
        hidden_state: ffn_residual,
        logits: logits,
    }
}

// ============================================================================
// 7. Multi-Head Attention (simplified, for MTP)
// ============================================================================

func multi_head_attention(
    []float q, []float k, []float v,
    int seq_len, int n_h, int d_h, bool causal
) []float {
    int hd = n_h * d_h
    float scale = 1.0 / sqrt_approx(d_h as float)
    []float output = zeros(seq_len * hd)

    int h = 0
    while h < n_h {
        int h_off = h * d_h

        int i = 0
        while i < seq_len {
            []float scores = []float{cap: seq_len}
            float max_s = -1e9

            int j = 0
            while j < seq_len {
                float dot = 0.0
                int d_idx = 0
                while d_idx < d_h {
                    dot = dot + q[i * hd + h_off + d_idx] * k[j * hd + h_off + d_idx]
                    d_idx = d_idx + 1
                }
                float s = dot * scale
                if causal && j > i { s = -1e9 }
                scores[j] = s
                if s > max_s { max_s = s }
                j = j + 1
            }

            float sum_exp = 0.0
            j = 0
            while j < seq_len {
                float w_v = exp_approx(scores[j] - max_s)
                scores[j] = w_v
                sum_exp = sum_exp + w_v
                j = j + 1
            }
            if sum_exp > 0.0 {
                j = 0
                while j < seq_len {
                    scores[j] = scores[j] / sum_exp
                    j = j + 1
                }
            }

            int d_idx = 0
            while d_idx < d_h {
                float sum_v = 0.0
                j = 0
                while j < seq_len {
                    sum_v = sum_v + scores[j] * v[j * hd + h_off + d_idx]
                    j = j + 1
                }
                output[i * hd + h_off + d_idx] = sum_v
                d_idx = d_idx + 1
            }

            i = i + 1
        }

        h = h + 1
    }

    output
}

// ============================================================================
// 8. MTP Full Forward (all D layers)
// ============================================================================

struct mtp_forward_output {
    [][]float all_logits        // [D][seq_len, vocab_size]
    [][]float all_hidden        // [D][seq_len, hidden_dim]
    float total_loss
    []float per_module_loss     // [D]
}

func mtp_forward(
    mtp_weights w, []float main_hidden,
    []int target_tokens, int seq_len
) mtp_forward_output {
    mtp_config cfg = w.config
    int D = cfg.num_mtp_layers

    [][]float all_logits = [][]float{cap: D}
    [][]float all_hidden = [][]float{cap: D}
    []float per_loss = zeros(D)

    []float prev_hidden = main_hidden

    int mtp_idx = 0
    while mtp_idx < D {
        mtp_module_weights mw = w.modules[mtp_idx]

        []int prev_tokens = []int{cap: seq_len}
        int s = 0
        while s < seq_len {
            prev_tokens[s] = target_tokens[s]
            s = s + 1
        }

        mtp_module_output mtp_out = mtp_module_forward(
            mw, prev_hidden, prev_tokens, seq_len, mtp_idx,
            w.token_embedding, cfg
        )

        all_logits[mtp_idx] = mtp_out.logits
        all_hidden[mtp_idx] = mtp_out.hidden_state

        float loss = cross_entropy_loss(mtp_out.logits, target_tokens, seq_len, cfg.vocab_size)
        per_loss[mtp_idx] = loss

        prev_hidden = mtp_out.hidden_state

        mtp_idx = mtp_idx + 1
    }

    float total_loss = 0.0
    mtp_idx = 0
    while mtp_idx < D {
        total_loss = total_loss + per_loss[mtp_idx]
        mtp_idx = mtp_idx + 1
    }
    total_loss = total_loss / D as float

    mtp_forward_output {
        all_logits: all_logits,
        all_hidden: all_hidden,
        total_loss: total_loss,
        per_module_loss: per_loss,
    }
}

// ============================================================================
// 9. Cross-Entropy Loss
// ============================================================================

func cross_entropy_loss([]float logits, []int targets, int seq_len, int vocab_size) float {
    float total_loss = 0.0

    int s = 0
    while s < seq_len {
        int target = targets[s]

        float max_logit = logits[s * vocab_size]
        int i = 1
        while i < vocab_size {
            if logits[s * vocab_size + i] > max_logit {
                max_logit = logits[s * vocab_size + i]
            }
            i = i + 1
        }

        float sum_exp = 0.0
        i = 0
        while i < vocab_size {
            sum_exp = sum_exp + exp_approx(logits[s * vocab_size + i] - max_logit)
            i = i + 1
        }

        float target_logit = logits[s * vocab_size + target] - max_logit
        float ce = target_logit - ln_approx(sum_exp)
        total_loss = total_loss - ce

        s = s + 1
    }

    total_loss / seq_len as float
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

// ============================================================================
// 10. MTP Inference Mode (for speculative decoding)
// ============================================================================

struct mtp_speculative_output {
    [][]int predicted_tokens     // [D][seq_len]
    [][]float confidence         // [D][seq_len]
}

func mtp_inference(
    mtp_weights w, []float main_hidden,
    int prev_token, int seq_len
) mtp_speculative_output {
    mtp_config cfg = w.config
    int D = cfg.num_mtp_layers
    int v = cfg.vocab_size

    [][]int predicted = [][]int{cap: D}
    [][]float confidence = [][]float{cap: D}

    []float prev_hidden = main_hidden
    []int prev_tokens = []int{cap: 1}
    prev_tokens[0] = prev_token

    int mtp_idx = 0
    while mtp_idx < D {
        mtp_module_weights mw = w.modules[mtp_idx]

        mtp_module_output mtp_out = mtp_module_forward(
            mw, prev_hidden, prev_tokens, 1, mtp_idx,
            w.token_embedding, cfg
        )

        // Argmax prediction
        int best_token = 0
        float best_logit = -1e9
        int i = 0
        while i < v {
            if mtp_out.logits[i] > best_logit {
                best_logit = mtp_out.logits[i]
                best_token = i
            }
            i = i + 1
        }

        []int pred_row = []int{cap: 1}
        pred_row[0] = best_token
        predicted[mtp_idx] = pred_row

        // Confidence
        float max_logit = mtp_out.logits[0]
        i = 1
        while i < v {
            if mtp_out.logits[i] > max_logit { max_logit = mtp_out.logits[i] }
            i = i + 1
        }
        float sum_exp = 0.0
        i = 0
        while i < v {
            sum_exp = sum_exp + exp_approx(mtp_out.logits[i] - max_logit)
            i = i + 1
        }
        []float conf_row = []float{cap: 1}
        conf_row[0] = exp_approx(best_logit - max_logit) / sum_exp
        confidence[mtp_idx] = conf_row

        prev_tokens = predicted[mtp_idx]
        prev_hidden = mtp_out.hidden_state

        mtp_idx = mtp_idx + 1
    }

    mtp_speculative_output {
        predicted_tokens: predicted,
        confidence: confidence,
    }
}

// ============================================================================
// 11. Combined Loss (for joint training)
// ============================================================================

func compute_combined_loss(
    float main_loss, mtp_forward_output mtp_output,
    float mtp_weight
) float {
    main_loss + mtp_weight * mtp_output.total_loss
}

// ============================================================================
// 12. Module Info
// ============================================================================

func unit_name() string {
    "neurx/model/neurx/mtp"
}

func unit_ready() int {
    1
}
