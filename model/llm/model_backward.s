package neurx.model.llm.base_backward
use neurx.model.llm.gpt.{
    model_config, language_model, transformer_layer,
    gpt_alloc, gpt_copy, gpt_add,
    gpt_matmul, gpt_matmul_t, gpt_matmul_kv,
    gpt_exp, gpt_log, gpt_sqrt, gpt_sigmoid, gpt_swish, gpt_cos, gpt_sin,
    gpt_softmax_row, gpt_causal_sdpa, transformer_layer_at,
    gpt_forward_with_loss, gpt_param_count,
    embed_tokens, transformer_layer_forward, gpt_alloc_int,
    gpt_forward
}
use neurx.model.transformer.norm.{rms_norm, rms_normalize}
use neurx.model.transformer.ffn.{forward_swiglu_ffn, forward_standard_ffn}
struct gpt_sdpa_cache {
    []float q
    []float k
    []float v
    []float weights
    int seq_len
    int n_head
    int n_kv_head
    int head_dim
}

struct transformer_layer_cache {
    []float x_in
    []float normed1
    []float q_proj
    []float k_proj
    []float v_proj
    []float q_rope
    []float k_rope
    []float attn_out
    []float attn_proj
    []float h_attn
    []float normed2
    []float ffn_gate_pre
    []float ffn_val_pre
    []float ffn_out
    []gpt_sdpa_cache sdpa_per_batch
    int batch_size
    int seq_len
}

struct gpt_forward_cache {
    []float embedding
    []transformer_layer_cache layers
    []float final_normed
    []float logits
    int batch_size
    int seq_len
    int n_layer
}

struct transformer_layer_grads {
    []float d_norm1_gamma
    []float d_norm2_gamma
    []float d_wq
    []float d_wk
    []float d_wv
    []float d_wo
    []float d_wq_bias
    []float d_wk_bias
    []float d_wv_bias
    []float d_wo_bias
    []float d_ffn_gate_w
    []float d_ffn_val_w
    []float d_ffn_down_w
}

struct gpt_param_grads {
    []float d_wte
    []float d_wpe
    []float d_final_gamma
    []float d_lm_head
    []transformer_layer_grads layers
    int n_layer
}

struct gpt_adamw_state {
    []float m_wte
    []float v_wte
    []float m_wpe
    []float v_wpe
    []float m_lm_head
    []float v_lm_head
    []float m_final_gamma
    []float v_final_gamma
    []transformer_layer_adamw layers
    int step
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
}

struct transformer_layer_adamw {
    []float m_norm1_gamma  []float v_norm1_gamma
    []float m_norm2_gamma  []float v_norm2_gamma
    []float m_wq           []float v_wq
    []float m_wk           []float v_wk
    []float m_wv           []float v_wv
    []float m_wo           []float v_wo
    []float m_ffn_gate_w   []float v_ffn_gate_w
    []float m_ffn_val_w    []float v_ffn_val_w
    []float m_ffn_down_w   []float v_ffn_down_w
}

func bk_alloc(int n) []float {
    []float v = []float{cap: n}
    int i = 0
    while i < n { v[i] = 0.0; i = i + 1 }
    v
}

func bk_copy([]float src) []float {
    []float out = bk_alloc(len(src))
    int i = 0
    while i < len(src) { out[i] = src[i]; i = i + 1 }
    out
}

func bk_add_inplace([]float a, []float b) []float {
    int i = 0
    while i < len(a) { a[i] = a[i] + b[i]; i = i + 1 }
    a
}

func bk_scale([]float v, float s) []float {
    []float out = bk_alloc(len(v))
    int i = 0
    while i < len(v) { out[i] = v[i] * s; i = i + 1 }
    out
}

func bk_matmul_da([]float d_c, []float b, int m, int k, int n) []float {
    []float d_a = bk_alloc(m * k)
    int i = 0
    while i < m {
        int l = 0
        while l < k {
            float s = 0.0
            int j = 0
            while j < n {
                s = s + d_c[i * n + j] * b[l * n + j]
                j = j + 1
            }
            d_a[i * k + l] = s
            l = l + 1
        }
        i = i + 1
    }
    d_a
}

func bk_matmul_db([]float a, []float d_c, int m, int k, int n) []float {
    []float d_b = bk_alloc(k * n)
    int l = 0
    while l < k {
        int j = 0
        while j < n {
            float s = 0.0
            int i = 0
            while i < m {
                s = s + a[i * k + l] * d_c[i * n + j]
                i = i + 1
            }
            d_b[l * n + j] = d_b[l * n + j] + s
            j = j + 1
        }
        l = l + 1
    }
    d_b
}

func bk_matmul_t_da([]float d_c, []float b, int m, int k, int n) []float {
    []float d_a = bk_alloc(m * k)
    int i = 0
    while i < m {
        int l = 0
        while l < k {
            float s = 0.0
            int j = 0
            while j < n {
                s = s + d_c[i * n + j] * b[j * k + l]
                j = j + 1
            }
            d_a[i * k + l] = s
            l = l + 1
        }
        i = i + 1
    }
    d_a
}

func bk_matmul_t_db([]float a, []float d_c, int m, int k, int n) []float {
    []float d_b = bk_alloc(n * k)
    int j = 0
    while j < n {
        int l = 0
        while l < k {
            float s = 0.0
            int i = 0
            while i < m {
                s = s + d_c[i * n + j] * a[i * k + l]
                i = i + 1
            }
            d_b[j * k + l] = d_b[j * k + l] + s
            l = l + 1
        }
        j = j + 1
    }
    d_b
}

func bk_matmul_kv_da([]float d_c, []float b, int m, int k, int n, int full_n) []float {
    []float d_a = bk_alloc(m * k)
    int i = 0
    while i < m {
        int l = 0
        while l < k {
            float s = 0.0
            int j = 0
            while j < n {
                s = s + d_c[i * n + j] * b[l * full_n + j]
                j = j + 1
            }
            d_a[i * k + l] = d_a[i * k + l] + s
            l = l + 1
        }
        i = i + 1
    }
    d_a
}

func bk_matmul_kv_db([]float a, []float d_c, int m, int k, int n, int full_n) []float {
    []float d_b = bk_alloc(k * full_n)
    int l = 0
    while l < k {
        int j = 0
        while j < n {
            float s = 0.0
            int i = 0
            while i < m {
                s = s + a[i * k + l] * d_c[i * n + j]
                i = i + 1
            }
            d_b[l * full_n + j] = d_b[l * full_n + j] + s
            j = j + 1
        }
        l = l + 1
    }
    d_b
}

func bk_softmax_row([]float d_weights, []float weights, int size) []float {
    float dot = 0.0
    int i = 0
    while i < size { dot = dot + d_weights[i] * weights[i]; i = i + 1 }
    []float d_scores = bk_alloc(size)
    i = 0
    while i < size {
        d_scores[i] = weights[i] * (d_weights[i] - dot)
        i = i + 1
    }
    d_scores
}

func bk_swish_grad(float z) float {
    float s = gpt_sigmoid(z)
    s + z * s * (1.0 - s)
}

func transformer_layer_forward_cached(
    transformer_layer layer,
    []float x,
    int batch_size,
    int seq_len,
    []float rope_freqs
) ([]float, transformer_layer_cache) {
    int total = batch_size * seq_len
    int D = layer.hidden_dim
    int nh = layer.n_head
    int nkv = layer.n_kv_head
    int hd = layer.head_dim
    int kv_D = nkv * hd
    int ffn_D = len(layer.ffn.glu_ffn.gate_weight) / D
    []float normed1 = rms_normalize(layer.norm1, x, batch_size, seq_len)
    []float q_proj = gpt_matmul(normed1, layer.attn.query_weight, total, D, D)
    []float k_proj = gpt_matmul_kv(normed1, layer.attn.key_weight,   total, D, kv_D, D)
    []float v_proj = gpt_matmul_kv(normed1, layer.attn.value_weight, total, D, kv_D, D)
    if layer.attn.config.use_qkv_bias {
        int i = 0
        while i < total {
            int d = 0
            while d < D { q_proj[i*D+d] = q_proj[i*D+d] + layer.attn.query_bias[d]; d=d+1 }
            d = 0
            while d < kv_D {
                k_proj[i*kv_D+d] = k_proj[i*kv_D+d] + layer.attn.key_bias[d]
                v_proj[i*kv_D+d] = v_proj[i*kv_D+d] + layer.attn.value_bias[d]
                d = d + 1
            }
            i = i + 1
        }
    }
    []float q_rope = gpt_copy(q_proj)
    []float k_rope = gpt_copy(k_proj)
    int pair_dim = hd / 2
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int tok = b * seq_len + s
            int h = 0
            while h < nh {
                int p = 0
                while p < pair_dim {
                    float freq = rope_freqs[p]
                    float angle = (s * 1.0) * freq
                    float cv = gpt_cos(angle)
                    float sv = gpt_sin(angle)
                    int base = tok * D + h * hd
                    float q0 = q_rope[base + 2*p];     float q1 = q_rope[base + 2*p+1]
                    q_rope[base + 2*p]   = q0*cv - q1*sv
                    q_rope[base + 2*p+1] = q0*sv + q1*cv
                    p = p + 1
                }
                h = h + 1
            }
            int hk = 0
            while hk < nkv {
                int p = 0
                while p < pair_dim {
                    float freq = rope_freqs[p]
                    float angle = (s * 1.0) * freq
                    float cv = gpt_cos(angle)
                    float sv = gpt_sin(angle)
                    int base = tok * kv_D + hk * hd
                    float k0 = k_rope[base + 2*p];   float k1 = k_rope[base + 2*p+1]
                    k_rope[base + 2*p]   = k0*cv - k1*sv
                    k_rope[base + 2*p+1] = k0*sv + k1*cv
                    p = p + 1
                }
                hk = hk + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    []gpt_sdpa_cache sdpa_caches = []gpt_sdpa_cache{cap: batch_size}
    []float attn_out = bk_alloc(total * D)
    b = 0
    while b < batch_size {
        int off_q = b * seq_len * D
        int off_k = b * seq_len * kv_D
        []float qb = bk_alloc(seq_len * D)
        []float kb = bk_alloc(seq_len * kv_D)
        []float vb = bk_alloc(seq_len * kv_D)
        int i = 0
        while i < seq_len * D    { qb[i] = q_rope[off_q + i]; i = i+1 }
        i = 0
        while i < seq_len * kv_D { kb[i] = k_rope[off_k + i]; vb[i] = v_proj[off_k + i]; i = i+1 }
        []float sdpa_out = gpt_causal_sdpa(qb, kb, vb, seq_len, nh, nkv, hd)
        []float weights = bk_compute_attn_weights(qb, kb, seq_len, nh, nkv, hd)
        sdpa_caches[b] = gpt_sdpa_cache {
            q: qb, k: kb, v: vb, weights: weights,
            seq_len: seq_len, n_head: nh, n_kv_head: nkv, head_dim: hd
        }
        int o = 0
        while o < seq_len * D { attn_out[b*seq_len*D + o] = sdpa_out[o]; o = o+1 }
        b = b + 1
    }
    []float attn_proj = gpt_matmul(attn_out, layer.attn.output_weight, total, D, D)
    if layer.attn.config.use_qkv_bias {
        int i = 0
        while i < total {
            int d = 0
            while d < D { attn_proj[i*D+d] = attn_proj[i*D+d] + layer.attn.output_bias[d]; d=d+1 }
            i = i+1
        }
    }
    []float h_attn = gpt_add(x, attn_proj)
    []float normed2 = rms_normalize(layer.norm2, h_attn, batch_size, seq_len)
    []float ffn_gate_pre = gpt_matmul(normed2, layer.ffn.glu_ffn.gate_weight, total, D, ffn_D)
    []float ffn_val_pre  = gpt_matmul(normed2, layer.ffn.glu_ffn.value_weight, total, D, ffn_D)
    int idx = 0
    while idx < total * ffn_D {
        ffn_gate_pre[idx] = ffn_gate_pre[idx] + layer.ffn.glu_ffn.gate_bias[idx % ffn_D]
        ffn_val_pre[idx]  = ffn_val_pre[idx]  + layer.ffn.glu_ffn.value_bias[idx % ffn_D]
        idx = idx + 1
    }
    []float gv_out = bk_alloc(total * ffn_D)
    idx = 0
    while idx < total * ffn_D {
        gv_out[idx] = gpt_swish(ffn_gate_pre[idx]) * ffn_val_pre[idx]
        idx = idx + 1
    }
    []float ffn_out_full = gpt_matmul(gv_out, layer.ffn.glu_ffn.down_weight, total, ffn_D, D)
    idx = 0
    while idx < total * D {
        ffn_out_full[idx] = ffn_out_full[idx] + layer.ffn.glu_ffn.down_bias[idx % D]
        idx = idx + 1
    }
    []float y = gpt_add(h_attn, ffn_out_full)
    transformer_layer_cache cache = transformer_layer_cache {
        x_in: x, normed1: normed1,
        q_proj: q_proj, k_proj: k_proj, v_proj: v_proj,
        q_rope: q_rope, k_rope: k_rope,
        attn_out: attn_out, attn_proj: attn_proj,
        h_attn: h_attn, normed2: normed2,
        ffn_gate_pre: ffn_gate_pre, ffn_val_pre: ffn_val_pre, ffn_out: ffn_out_full,
        sdpa_per_batch: sdpa_caches,
        batch_size: batch_size, seq_len: seq_len,
    }
    (y, cache)
}

func bk_compute_attn_weights(
    []float q, []float k,
    int seq_len, int nh, int nkv, int hd
) []float {
    []float weights = bk_alloc(nh * seq_len * seq_len)
    float scale = 1.0 / gpt_sqrt(hd * 1.0)
    float NEG_INF = -1000000.0
    int h = 0
    while h < nh {
        int hk = h - (h / nkv) * nkv
        int i = 0
        while i < seq_len {
            []float scores = bk_alloc(seq_len)
            int j = 0
            while j < seq_len {
                if j > i { scores[j] = NEG_INF } else {
                    float s = 0.0
                    int d = 0
                    while d < hd {
                        s = s + q[i*(nh*hd)+h*hd+d] * k[j*(nkv*hd)+hk*hd+d]
                        d = d + 1
                    }
                    scores[j] = s * scale
                }
                j = j + 1
            }
            []float w = gpt_softmax_row(scores, seq_len)
            int j2 = 0
            while j2 < seq_len {
                weights[h*seq_len*seq_len + i*seq_len + j2] = w[j2]
                j2 = j2 + 1
            }
            i = i + 1
        }
        h = h + 1
    }
    weights
}

func gpt_forward_cached(
    language_model model,
    []int token_ids,
    int batch_size,
    int seq_len
) (gpt_forward_cache, []float) {
    int D = model.n_embd
    int V = model.vocab_size
    int total = batch_size * seq_len
    []float emb = embed_tokens(model.wte, model.wpe, token_ids, batch_size, seq_len, D)
    []transformer_layer_cache layer_caches = []transformer_layer_cache{cap: model.n_layer}
    []float hidden = gpt_copy(emb)
    int l = 0
    while l < model.n_layer {
        transformer_layer layer = transformer_layer_at(model.layers, l)
        []float next_hidden
        transformer_layer_cache lc
        (next_hidden, lc) = transformer_layer_forward_cached(layer, hidden, batch_size, seq_len, model.rope.frequencies)
        layer_caches[l] = lc
        hidden = next_hidden
        l = l + 1
    }
    []float normed_final = rms_normalize(model.final_norm, hidden, batch_size, seq_len)
    []float logits
    if model.config.tie_embeddings {
        logits = gpt_matmul_t(normed_final, model.lm_head, total, D, V)
    } else {
        logits = gpt_matmul(normed_final, model.lm_head, total, D, V)
    }
    gpt_forward_cache fc = gpt_forward_cache {
        embedding: emb,
        layers: layer_caches,
        final_normed: normed_final,
        logits: logits,
        batch_size: batch_size,
        seq_len: seq_len,
        n_layer: model.n_layer,
    }
    (fc, logits)
}

func gpt_ce_backward(
    []float logits,
    []int targets,
    int total_tokens,
    int vocab_size
) []float {
    []float d_logits = bk_alloc(total_tokens * vocab_size)
    int count = 0
    int i = 0
    while i < total_tokens {
        if targets[i] >= 0 { count = count + 1 }
        i = i + 1
    }
    if count == 0 { return d_logits }
    float inv_count = 1.0 / (count * 1.0)
    i = 0
    while i < total_tokens {
        int tgt = targets[i]
        if tgt < 0 { i = i + 1; continue }
        if tgt >= vocab_size { tgt = vocab_size - 1 }
        int base = i * vocab_size
        float max_l = logits[base]
        int j = 1
        while j < vocab_size {
            if logits[base+j] > max_l { max_l = logits[base+j] }
            j = j + 1
        }
        float sum_exp = 0.0
        j = 0
        while j < vocab_size {
            sum_exp = sum_exp + gpt_exp(logits[base+j] - max_l)
            j = j + 1
        }
        j = 0
        while j < vocab_size {
            float p = gpt_exp(logits[base+j] - max_l) / sum_exp
            d_logits[base+j] = p * inv_count
            j = j + 1
        }
        d_logits[base + tgt] = d_logits[base + tgt] - inv_count
        i = i + 1
    }
    d_logits
}

func bk_rmsn(
    rms_norm rn,
    []float d_out,
    []float input,
    int batch_size,
    int seq_len
) ([]float, []float) {
    int D = rn.hidden_dim
    float eps = rn.epsilon
    []float d_input = bk_alloc(batch_size * seq_len * D)
    []float d_gamma = bk_alloc(D)
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int base = (b * seq_len + s) * D
            float sq_sum = 0.0
            int d = 0
            while d < D { sq_sum = sq_sum + input[base+d] * input[base+d]; d = d+1 }
            float rms = gpt_sqrt(sq_sum / (D * 1.0) + eps)
            float inv_rms = 1.0 / rms
            d = 0
            while d < D {
                float xn = input[base+d] * inv_rms
                d_gamma[d] = d_gamma[d] + d_out[base+d] * xn
                d = d + 1
            }
            float sum_term = 0.0
            d = 0
            while d < D {
                float xn = input[base+d] * inv_rms
                sum_term = sum_term + d_out[base+d] * rn.gamma[d] * xn
                d = d + 1
            }
            sum_term = sum_term / (D * 1.0)
            d = 0
            while d < D {
                float xn = input[base+d] * inv_rms
                d_input[base+d] = inv_rms * rn.gamma[d] * (d_out[base+d] - xn * sum_term)
                d = d + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    (d_input, d_gamma)
}

struct sdpa_bk_result {
    []float d_q
    []float d_k
    []float d_v
}

func bk_causal_sdpa(
    []float d_out,
    gpt_sdpa_cache cache
) sdpa_bk_result {
    int S = cache.seq_len
    int nh = cache.n_head
    int nkv = cache.n_kv_head
    int hd = cache.head_dim
    int D  = nh * hd
    int kv_D = nkv * hd
    float scale = 1.0 / gpt_sqrt(hd * 1.0)
    []float d_q = bk_alloc(S * D)
    []float d_k = bk_alloc(S * kv_D)
    []float d_v = bk_alloc(S * kv_D)
    int h = 0
    while h < nh {
        int hk = h - (h / nkv) * nkv
        int i = 0
        while i < S {
            []float w_row = bk_alloc(S)
            int j = 0
            while j < S { w_row[j] = cache.weights[h*S*S + i*S + j]; j = j+1 }
            int d = 0
            while d < hd {
                j = 0
                while j <= i {
                    float dv = w_row[j] * d_out[i*(D) + h*hd + d]
                    d_v[j*kv_D + hk*hd + d] = d_v[j*kv_D + hk*hd + d] + dv
                    j = j + 1
                }
                d = d + 1
            }
            []float d_w_row = bk_alloc(S)
            d = 0
            while d < hd {
                j = 0
                while j <= i {
                    d_w_row[j] = d_w_row[j] + d_out[i*D + h*hd + d] * cache.v[j*kv_D + hk*hd + d]
                    j = j + 1
                }
                d = d + 1
            }
            []float d_scores = bk_softmax_row(d_w_row, w_row, S)
            d = 0
            while d < hd {
                float dq = 0.0
                j = 0
                while j <= i {
                    float sc = d_scores[j] * scale
                    dq = dq + sc * cache.k[j*kv_D + hk*hd + d]
                    d_k[j*kv_D + hk*hd + d] = d_k[j*kv_D + hk*hd + d] + sc * cache.q[i*D + h*hd + d]
                    j = j + 1
                }
                d_q[i*D + h*hd + d] = d_q[i*D + h*hd + d] + dq
                d = d + 1
            }
            i = i + 1
        }
        h = h + 1
    }
    sdpa_bk_result { d_q: d_q, d_k: d_k, d_v: d_v }
}

func bk_rope_q([]float d_q_rope, int batch_size, int seq_len, int nh, int hd, int D, []float freqs) []float {
    []float d_q = gpt_copy(d_q_rope)
    int pair_dim = hd / 2
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int tok = b * seq_len + s
            int h = 0
            while h < nh {
                int p = 0
                while p < pair_dim {
                    float angle = (s * 1.0) * freqs[p]
                    float cv = gpt_cos(angle)
                    float sv = gpt_sin(angle)
                    int base = tok * D + h * hd
                    float g0 = d_q_rope[base + 2*p]
                    float g1 = d_q_rope[base + 2*p+1]
                    d_q[base + 2*p]   =  g0 * cv + g1 * sv
                    d_q[base + 2*p+1] = -g0 * sv + g1 * cv
                    p = p + 1
                }
                h = h + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    d_q
}

func bk_rope_k([]float d_k_rope, int batch_size, int seq_len, int nkv, int hd, int kv_D, []float freqs) []float {
    []float d_k = gpt_copy(d_k_rope)
    int pair_dim = hd / 2
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int tok = b * seq_len + s
            int hk = 0
            while hk < nkv {
                int p = 0
                while p < pair_dim {
                    float angle = (s * 1.0) * freqs[p]
                    float cv = gpt_cos(angle)
                    float sv = gpt_sin(angle)
                    int base = tok * kv_D + hk * hd
                    float g0 = d_k_rope[base + 2*p]
                    float g1 = d_k_rope[base + 2*p+1]
                    d_k[base + 2*p]   =  g0 * cv + g1 * sv
                    d_k[base + 2*p+1] = -g0 * sv + g1 * cv
                    p = p + 1
                }
                hk = hk + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    d_k
}

func transformer_layer_backward(
    transformer_layer layer,
    transformer_layer_cache cache,
    []float d_out,
    []float rope_freqs
) ([]float, transformer_layer_grads) {
    int total = cache.batch_size * cache.seq_len
    int D = layer.hidden_dim
    int nh = layer.n_head
    int nkv = layer.n_kv_head
    int hd = layer.head_dim
    int kv_D = nkv * hd
    int ffn_D = len(layer.ffn.glu_ffn.gate_weight) / D
    []float d_ffn_out = bk_copy(d_out)
    []float d_h_attn  = bk_copy(d_out)
    []float d_gv = bk_matmul_da(d_ffn_out, layer.ffn.glu_ffn.down_weight, total, ffn_D, D)
    []float d_ffn_down_w = bk_matmul_db(cache.ffn_gate_pre, d_ffn_out, total, ffn_D, D)
    []float gv_out = bk_alloc(total * ffn_D)
    int idx = 0
    while idx < total * ffn_D {
        gv_out[idx] = gpt_swish(cache.ffn_gate_pre[idx]) * cache.ffn_val_pre[idx]
        idx = idx + 1
    }
    d_ffn_down_w = bk_matmul_db(gv_out, d_ffn_out, total, ffn_D, D)
    []float d_swish_gate = bk_alloc(total * ffn_D)
    []float d_val_pre    = bk_alloc(total * ffn_D)
    idx = 0
    while idx < total * ffn_D {
        d_swish_gate[idx] = d_gv[idx] * cache.ffn_val_pre[idx]
        d_val_pre[idx]    = d_gv[idx] * gpt_swish(cache.ffn_gate_pre[idx])
        idx = idx + 1
    }
    []float d_gate_pre = bk_alloc(total * ffn_D)
    idx = 0
    while idx < total * ffn_D {
        d_gate_pre[idx] = d_swish_gate[idx] * bk_swish_grad(cache.ffn_gate_pre[idx])
        idx = idx + 1
    }
    []float d_normed2_from_gate  = bk_matmul_da(d_gate_pre, layer.ffn.glu_ffn.gate_weight,  total, D, ffn_D)
    []float d_normed2_from_value = bk_matmul_da(d_val_pre,  layer.ffn.glu_ffn.value_weight, total, D, ffn_D)
    []float d_normed2 = gpt_add(d_normed2_from_gate, d_normed2_from_value)
    []float d_ffn_gate_w  = bk_matmul_db(cache.normed2, d_gate_pre, total, D, ffn_D)
    []float d_ffn_val_w   = bk_matmul_db(cache.normed2, d_val_pre,  total, D, ffn_D)
    []float d_h_attn2
    []float d_norm2_gamma
    (d_h_attn2, d_norm2_gamma) = bk_rmsn(layer.norm2, d_normed2, cache.h_attn, cache.batch_size, cache.seq_len)
    d_h_attn = bk_add_inplace(d_h_attn, d_h_attn2)
    []float d_attn_proj = bk_copy(d_h_attn)
    []float d_x_residual = bk_copy(d_h_attn)
    []float d_attn_out = bk_matmul_da(d_attn_proj, layer.attn.output_weight, total, D, D)
    []float d_wo       = bk_matmul_db(cache.attn_out, d_attn_proj, total, D, D)
    []float d_q_rope_all = bk_alloc(total * D)
    []float d_k_rope_all = bk_alloc(total * kv_D)
    []float d_v_all      = bk_alloc(total * kv_D)
    int b = 0
    while b < cache.batch_size {
        int off_q = b * cache.seq_len * D
        int off_k = b * cache.seq_len * kv_D
        []float d_out_b = bk_alloc(cache.seq_len * D)
        int i = 0
        while i < cache.seq_len * D { d_out_b[i] = d_attn_out[off_q + i]; i = i+1 }
        gpt_sdpa_cache sc = cache.sdpa_per_batch[b]
        sdpa_bk_result sr = bk_causal_sdpa(d_out_b, sc)
        i = 0
        while i < cache.seq_len * D    { d_q_rope_all[off_q + i] = sr.d_q[i]; i = i+1 }
        i = 0
        while i < cache.seq_len * kv_D {
            d_k_rope_all[off_k + i] = sr.d_k[i]
            d_v_all[off_k + i]      = sr.d_v[i]
            i = i + 1
        }
        b = b + 1
    }
    []float d_q_proj = bk_rope_q(d_q_rope_all, cache.batch_size, cache.seq_len, nh, hd, D,    rope_freqs)
    []float d_k_proj = bk_rope_k(d_k_rope_all, cache.batch_size, cache.seq_len, nkv, hd, kv_D, rope_freqs)
    []float d_wq = bk_matmul_db(cache.normed1, d_q_proj, total, D, D)
    []float d_wk = bk_matmul_kv_db(cache.normed1, d_k_proj, total, D, kv_D, D)
    []float d_wv = bk_matmul_kv_db(cache.normed1, d_v_all,  total, D, kv_D, D)
    []float d_normed1 = bk_matmul_da(d_q_proj, layer.attn.query_weight, total, D, D)
    d_normed1 = bk_add_inplace(d_normed1, bk_matmul_kv_da(d_k_proj, layer.attn.key_weight,   total, D, kv_D, D))
    d_normed1 = bk_add_inplace(d_normed1, bk_matmul_kv_da(d_v_all,  layer.attn.value_weight, total, D, kv_D, D))
    []float d_x_from_norm
    []float d_norm1_gamma
    (d_x_from_norm, d_norm1_gamma) = bk_rmsn(layer.norm1, d_normed1, cache.x_in, cache.batch_size, cache.seq_len)
    []float d_input = bk_add_inplace(d_x_residual, d_x_from_norm)
    transformer_layer_grads grads = transformer_layer_grads {
        d_norm1_gamma: d_norm1_gamma,
        d_norm2_gamma: d_norm2_gamma,
        d_wq: d_wq, d_wk: d_wk, d_wv: d_wv, d_wo: d_wo,
        d_wq_bias: bk_alloc(D), d_wk_bias: bk_alloc(kv_D),
        d_wv_bias: bk_alloc(kv_D), d_wo_bias: bk_alloc(D),
        d_ffn_gate_w: d_ffn_gate_w,
        d_ffn_val_w:  d_ffn_val_w,
        d_ffn_down_w: d_ffn_down_w,
    }
    (d_input, grads)
}

func model_backward
    language_model model,
    gpt_forward_cache fc,
    []int targets
) gpt_param_grads {
    int total = fc.batch_size * fc.seq_len
    int D = model.n_embd
    int V = model.vocab_size
    []float d_logits = gpt_ce_backward(fc.logits, targets, total, V)
    []float d_final_normed
    []float d_lm_head
    []float d_final_gamma
    if model.config.tie_embeddings {
        d_final_normed = bk_matmul_t_da(d_logits, model.lm_head, total, D, V)
        d_lm_head      = bk_matmul_t_db(fc.final_normed, d_logits, total, D, V)
    } else {
        d_final_normed = bk_matmul_da(d_logits, model.lm_head, total, D, V)
        d_lm_head      = bk_matmul_db(fc.final_normed, d_logits, total, D, V)
    }
    transformer_layer_cache last_cache = fc.layers[model.n_layer - 1]
    []float hidden_before_norm = gpt_add(last_cache.h_attn, last_cache.ffn_out)
    []float d_hidden
    (d_hidden, d_final_gamma) = bk_rmsn(model.final_norm, d_final_normed, hidden_before_norm, fc.batch_size, fc.seq_len)
    []transformer_layer_grads layer_grads = []transformer_layer_grads{cap: model.n_layer}
    int l = model.n_layer - 1
    while l >= 0 {
        transformer_layer layer = transformer_layer_at(model.layers, l)
        transformer_layer_cache lc = fc.layers[l]
        []float d_layer_in
        transformer_layer_grads lg
        (d_layer_in, lg) = transformer_layer_backward(layer, lc, d_hidden, model.rope.frequencies)
        layer_grads[l] = lg
        d_hidden = d_layer_in
        l = l - 1
    }
    []float d_wte = bk_alloc(V * D)
    []float d_wpe = bk_alloc(model.block_size * D)
    int b2 = 0
    while b2 < fc.batch_size {
        int s = 0
        while s < fc.seq_len {
            int tok_idx = b2 * fc.seq_len + s
            int d = 0
            while d < D {
                d_wpe[s * D + d] = d_wpe[s * D + d] + d_hidden[tok_idx * D + d]
                d = d + 1
            }
            s = s + 1
        }
        b2 = b2 + 1
    }
    gpt_param_grads {
        d_wte: d_wte,
        d_wpe: d_wpe,
        d_final_gamma: d_final_gamma,
        d_lm_head: d_lm_head,
        layers: layer_grads,
        n_layer: model.n_layer,
    }
}

func new_gpt_adamw_state(language_model model, float lr, float beta1, float beta2, float eps, float wd) gpt_adamw_state {
    int D = model.n_embd
    int V = model.vocab_size
    int B = model.block_size
    int nl = model.n_layer
    []transformer_layer_adamw layer_states = []transformer_layer_adamw{cap: nl}
    int l = 0
    while l < nl {
        transformer_layer layer = transformer_layer_at(model.layers, l)
        int kv_D = layer.n_kv_head * layer.head_dim
        int ffn_D = len(layer.ffn.glu_ffn.gate_weight) / D
        layer_states[l] = transformer_layer_adamw {
            m_norm1_gamma: bk_alloc(D),    v_norm1_gamma: bk_alloc(D),
            m_norm2_gamma: bk_alloc(D),    v_norm2_gamma: bk_alloc(D),
            m_wq: bk_alloc(D*D),           v_wq: bk_alloc(D*D),
            m_wk: bk_alloc(D*D),           v_wk: bk_alloc(D*D),
            m_wv: bk_alloc(D*D),           v_wv: bk_alloc(D*D),
            m_wo: bk_alloc(D*D),           v_wo: bk_alloc(D*D),
            m_ffn_gate_w: bk_alloc(D*ffn_D), v_ffn_gate_w: bk_alloc(D*ffn_D),
            m_ffn_val_w:  bk_alloc(D*ffn_D), v_ffn_val_w:  bk_alloc(D*ffn_D),
            m_ffn_down_w: bk_alloc(ffn_D*D), v_ffn_down_w: bk_alloc(ffn_D*D),
        }
        l = l + 1
    }
    gpt_adamw_state {
        m_wte: bk_alloc(V*D), v_wte: bk_alloc(V*D),
        m_wpe: bk_alloc(B*D), v_wpe: bk_alloc(B*D),
        m_lm_head: bk_alloc(D*V), v_lm_head: bk_alloc(D*V),
        m_final_gamma: bk_alloc(D), v_final_gamma: bk_alloc(D),
        layers: layer_states,
        step: 0,
        lr: lr, beta1: beta1, beta2: beta2, eps: eps, weight_decay: wd,
    }
}

func adamw_update_vec([]float param, []float grad, []float m, []float v, int step, float lr, float b1, float b2, float eps, float wd) []float {
    float bc1 = 1.0 - bk_pow(b1, step)
    float bc2 = 1.0 - bk_pow(b2, step)
    int n = len(param)
    []float p = bk_copy(param)
    int i = 0
    while i < n {
        m[i] = b1 * m[i] + (1.0 - b1) * grad[i]
        v[i] = b2 * v[i] + (1.0 - b2) * grad[i] * grad[i]
        float m_hat = m[i] / bc1
        float v_hat = v[i] / bc2
        float update = lr * m_hat / (gpt_sqrt(v_hat) + eps)
        p[i] = p[i] * (1.0 - lr * wd) - update
        i = i + 1
    }
    p
}

func bk_pow(float base, int exp) float {
    float r = 1.0
    int e = exp
    while e > 0 { r = r * base; e = e - 1 }
    r
}

func gpt_adamw_step(
    language_model model,
    gpt_param_grads grads,
    gpt_adamw_state opt
) (language_model, gpt_adamw_state) {
    gpt_adamw_state o = opt
    o.step = o.step + 1
    int s = o.step
    float lr = o.lr; float b1 = o.beta1; float b2 = o.beta2; float eps = o.eps; float wd = o.weight_decay
    model.wte = adamw_update_vec(model.wte, grads.d_wte, o.m_wte, o.v_wte, s, lr, b1, b2, eps, wd)
    model.wpe = adamw_update_vec(model.wpe, grads.d_wpe, o.m_wpe, o.v_wpe, s, lr, b1, b2, eps, wd)
    model.lm_head = adamw_update_vec(model.lm_head, grads.d_lm_head, o.m_lm_head, o.v_lm_head, s, lr, b1, b2, eps, wd)
    model.final_norm.gamma = adamw_update_vec(model.final_norm.gamma, grads.d_final_gamma, o.m_final_gamma, o.v_final_gamma, s, lr, b1, b2, eps, 0.0)
    int l = 0
    while l < model.n_layer {
        transformer_layer layer = transformer_layer_at(model.layers, l)
        transformer_layer_grads lg = grads.layers[l]
        transformer_layer_adamw lo = o.layers[l]
        layer.attn.query_weight  = adamw_update_vec(layer.attn.query_weight,  lg.d_wq, lo.m_wq, lo.v_wq, s, lr, b1, b2, eps, wd)
        layer.attn.key_weight    = adamw_update_vec(layer.attn.key_weight,    lg.d_wk, lo.m_wk, lo.v_wk, s, lr, b1, b2, eps, wd)
        layer.attn.value_weight  = adamw_update_vec(layer.attn.value_weight,  lg.d_wv, lo.m_wv, lo.v_wv, s, lr, b1, b2, eps, wd)
        layer.attn.output_weight = adamw_update_vec(layer.attn.output_weight, lg.d_wo, lo.m_wo, lo.v_wo, s, lr, b1, b2, eps, wd)
        layer.ffn.glu_ffn.gate_weight  = adamw_update_vec(layer.ffn.glu_ffn.gate_weight,  lg.d_ffn_gate_w, lo.m_ffn_gate_w, lo.v_ffn_gate_w, s, lr, b1, b2, eps, wd)
        layer.ffn.glu_ffn.value_weight = adamw_update_vec(layer.ffn.glu_ffn.value_weight, lg.d_ffn_val_w,  lo.m_ffn_val_w,  lo.v_ffn_val_w,  s, lr, b1, b2, eps, wd)
        layer.ffn.glu_ffn.down_weight  = adamw_update_vec(layer.ffn.glu_ffn.down_weight,  lg.d_ffn_down_w, lo.m_ffn_down_w, lo.v_ffn_down_w, s, lr, b1, b2, eps, wd)
        layer.norm1.gamma = adamw_update_vec(layer.norm1.gamma, lg.d_norm1_gamma, lo.m_norm1_gamma, lo.v_norm1_gamma, s, lr, b1, b2, eps, 0.0)
        layer.norm2.gamma = adamw_update_vec(layer.norm2.gamma, lg.d_norm2_gamma, lo.m_norm2_gamma, lo.v_norm2_gamma, s, lr, b1, b2, eps, 0.0)
        model.layers[l] = layer
        l = l + 1
    }
    (model, o)
}

struct gpt_train_step_result {
    language_model model
    gpt_adamw_state opt
    float loss
    float grad_norm
}

func train_step
    language_model model,
    gpt_adamw_state opt,
    []int token_ids,
    int batch_size,
    int seq_len,
    float grad_clip
) gpt_train_step_result {
    int total = batch_size * seq_len
    []int targets = gpt_alloc_int(total)
    int i = 0
    while i < total {
        int pos_in_seq = i - (i / seq_len) * seq_len
        if pos_in_seq < seq_len - 1 {
            targets[i] = token_ids[i + 1]
        } else {
            targets[i] = -1
        }
        i = i + 1
    }
    gpt_forward_cache fc
    []float logits
    (fc, logits) = gpt_forward_cached(model, token_ids, batch_size, seq_len)
    float loss = gpt_compute_ce_loss(logits, targets, total, model.vocab_size)
    gpt_param_grads grads = gpt_backward(model, fc, targets)
    float total_norm = 0.0
    total_norm = total_norm + bk_vec_norm_sq(grads.d_final_gamma)
    i = 0
    while i < model.n_layer {
        transformer_layer_grads lg = grads.layers[i]
        total_norm = total_norm + bk_vec_norm_sq(lg.d_wq)
        total_norm = total_norm + bk_vec_norm_sq(lg.d_wk)
        total_norm = total_norm + bk_vec_norm_sq(lg.d_wv)
        total_norm = total_norm + bk_vec_norm_sq(lg.d_wo)
        total_norm = total_norm + bk_vec_norm_sq(lg.d_ffn_gate_w)
        total_norm = total_norm + bk_vec_norm_sq(lg.d_ffn_val_w)
        total_norm = total_norm + bk_vec_norm_sq(lg.d_ffn_down_w)
        i = i + 1
    }
    float grad_norm = gpt_sqrt(total_norm)
    if grad_clip > 0.0 && grad_norm > grad_clip {
        float clip_coeff = grad_clip / grad_norm
        grads = scale_all_grads(grads, clip_coeff)
    }
    language_model updated_model
    gpt_adamw_state updated_opt
    (updated_model, updated_opt) = gpt_adamw_step(model, grads, opt)
    gpt_train_step_result {
        model: updated_model,
        opt: updated_opt,
        loss: loss,
        grad_norm: grad_norm,
    }
}

func gpt_compute_ce_loss([]float logits, []int targets, int total, int vocab) float {
    float loss = 0.0
    int count = 0
    int i = 0
    while i < total {
        int tgt = targets[i]
        if tgt < 0 { i = i + 1; continue }
        if tgt >= vocab { tgt = vocab - 1 }
        int base = i * vocab
        float max_l = logits[base]
        int j = 1
        while j < vocab { if logits[base+j] > max_l { max_l = logits[base+j] }; j=j+1 }
        float lse = 0.0
        j = 0
        while j < vocab { lse = lse + gpt_exp(logits[base+j] - max_l); j=j+1 }
        loss = loss + (gpt_log(lse) + max_l - logits[base + tgt])
        count = count + 1
        i = i + 1
    }
    if count == 0 { return 0.0 }
    loss / (count * 1.0)
}

func bk_vec_norm_sq([]float v) float {
    float s = 0.0
    int i = 0
    while i < len(v) { s = s + v[i] * v[i]; i = i + 1 }
    s
}

func scale_all_grads(gpt_param_grads grads, float scale) gpt_param_grads {
    grads.d_wte = bk_scale(grads.d_wte, scale)
    grads.d_wpe = bk_scale(grads.d_wpe, scale)
    grads.d_lm_head = bk_scale(grads.d_lm_head, scale)
    grads.d_final_gamma = bk_scale(grads.d_final_gamma, scale)
    int l = 0
    while l < grads.n_layer {
        transformer_layer_grads lg = grads.layers[l]
        lg.d_wq         = bk_scale(lg.d_wq, scale)
        lg.d_wk         = bk_scale(lg.d_wk, scale)
        lg.d_wv         = bk_scale(lg.d_wv, scale)
        lg.d_wo         = bk_scale(lg.d_wo, scale)
        lg.d_ffn_gate_w = bk_scale(lg.d_ffn_gate_w, scale)
        lg.d_ffn_val_w  = bk_scale(lg.d_ffn_val_w, scale)
        lg.d_ffn_down_w = bk_scale(lg.d_ffn_down_w, scale)
        lg.d_norm1_gamma = bk_scale(lg.d_norm1_gamma, scale)
        lg.d_norm2_gamma = bk_scale(lg.d_norm2_gamma, scale)
        grads.layers[l] = lg
        l = l + 1
    }
    grads
}
