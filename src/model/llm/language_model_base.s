package neurx.model.llm.base
use neurx.attention.{
    attention_config, multi_head_attention,
    new_attention_config, new_multi_head_attention,
    project_qkv, project_qkv_result
}
use neurx.model.transformer.ffn.{
    ffn_config, feed_forward_network,
    new_ffn_config, new_standard_ffn, new_glu_ffn,
    forward_swiglu_ffn, forward_standard_ffn
}
use neurx.model.transformer.norm.{
    rms_norm, layer_norm_config, new_rms_norm, rms_normalize,
    rope_embedding, new_rope_embedding, apply_rope, rope_apply_result,
    position_embedding_config
}

struct model_config {
    string name
    int vocab_size
    int n_embd
    int n_layer
    int n_head
    int n_kv_head
    int ffn_dim
    int block_size
    float rope_base
    float dropout
    bool use_bias
    string activation
    bool tie_embeddings
}

struct transformer_layer {
    multi_head_attention attn
    feed_forward_network ffn
    rms_norm norm1
    rms_norm norm2
    int hidden_dim
    int n_head
    int n_kv_head
    int head_dim
    string activation
}

struct language_model {
    model_config config
    float[] wte
    float[] wpe
    []transformer_layer layers
    rms_norm final_norm
    float[] lm_head
    rope_embedding rope
    int n_layer
    int vocab_size
    int n_embd
    int block_size
}

struct model_output {
    float[] logits
    float[] last_hidden
    float loss
}

func model_small() model_config {
    model_config {
        name: "model-small",
        vocab_size: 50257,
        n_embd: 768,
        n_layer: 12,
        n_head: 12,
        n_kv_head: 12,
        ffn_dim: 3072,
        block_size: 1024,
        rope_base: 10000.0,
        dropout: 0.0,
        use_bias: true,
        activation: "gelu",
        tie_embeddings: true,
    }
}

func model_medium() model_config {
    model_config {
        name: "model-medium",
        vocab_size: 50257,
        n_embd: 1024,
        n_layer: 24,
        n_head: 16,
        n_kv_head: 16,
        ffn_dim: 4096,
        block_size: 1024,
        rope_base: 10000.0,
        dropout: 0.0,
        use_bias: true,
        activation: "gelu",
        tie_embeddings: true,
    }
}

func model_large_config() model_config {
    model_config {
        name: "model-large-config",
        vocab_size: 50257,
        n_embd: 1280,
        n_layer: 36,
        n_head: 20,
        n_kv_head: 20,
        ffn_dim: 5120,
        block_size: 1024,
        rope_base: 10000.0,
        dropout: 0.0,
        use_bias: true,
        activation: "gelu",
        tie_embeddings: true,
    }
}

func model_xl() model_config {
    model_config {
        name: "model-xl",
        vocab_size: 50257,
        n_embd: 1600,
        n_layer: 48,
        n_head: 25,
        n_kv_head: 25,
        ffn_dim: 6400,
        block_size: 1024,
        rope_base: 10000.0,
        dropout: 0.0,
        use_bias: true,
        activation: "gelu",
        tie_embeddings: true,
    }
}

func model_6b() model_config {
    model_config {
        name: "model-6.7b",
        vocab_size: 50257,
        n_embd: 4096,
        n_layer: 32,
        n_head: 32,
        n_kv_head: 32,
        ffn_dim: 11008,
        block_size: 2048,
        rope_base: 10000.0,
        dropout: 0.0,
        use_bias: false,
        activation: "swiglu",
        tie_embeddings: false,
    }
}

func model_13b() model_config {
    model_config {
        name: "model-13b",
        vocab_size: 50257,
        n_embd: 5120,
        n_layer: 40,
        n_head: 40,
        n_kv_head: 8,
        ffn_dim: 13696,
        block_size: 4096,
        rope_base: 10000.0,
        dropout: 0.0,
        use_bias: false,
        activation: "swiglu",
        tie_embeddings: false,
    }
}

func model_35_level() model_config {
    model_config {
        name: "model-35-level",
        vocab_size: 100256,
        n_embd: 5120,
        n_layer: 40,
        n_head: 40,
        n_kv_head: 8,
        ffn_dim: 13696,
        block_size: 8192,
        rope_base: 500000.0,
        dropout: 0.0,
        use_bias: false,
        activation: "swiglu",
        tie_embeddings: false,
    }
}

func custom_model_config(int n_embd, int n_layer, int n_head, int block_size, string activation) model_config {
    model_config {
        name: "custom",
        vocab_size: 50257,
        n_embd: n_embd,
        n_layer: n_layer,
        n_head: n_head,
        n_kv_head: n_head,
        ffn_dim: n_embd * 4,
        block_size: block_size,
        rope_base: 10000.0,
        dropout: 0.0,
        use_bias: true,
        activation: activation,
        tie_embeddings: true,
    }
}

func alloc_tensor(int size, float init_val) []float {
    float[] v = make([]float, size)
    int i = 0
    for i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func copy_tensor(float[] src) []float {
    float[] out = gpt_alloc(len(src), 0.0)
    int i = 0
    for i < len(src) {
        out[i] = src[i]
        i = i + 1
    }
    out
}

func add_tensors(float[] a, float[] b) []float {
    float[] out = gpt_copy(a)
    int i = 0
    for i < len(out) {
        out[i] = out[i] + b[i]
        i = i + 1
    }
    out
}

func matmul_transposefloat[] a, float[] b, int m, int k, int n) []float {
    float[] result = gpt_alloc(m * n, 0.0)
    int i = 0
    for i < m {
        int j = 0
        for j < n {
            float sum = 0.0
            int l = 0
            for l < k {
                sum = sum + a[i * k + l] * b[j * k + l]
                l = l + 1
            }
            result[i * n + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    result
}

func matmulfloat[] a, float[] b, int m, int k, int n) []float {
    float[] result = gpt_alloc(m * n, 0.0)
    int i = 0
    for i < m {
        int j = 0
        for j < n {
            float sum = 0.0
            int l = 0
            for l < k {
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

func tensor_expfloat x) float {
    if x > 20.0 {
        return 485165195.4
    }
    if x < -20.0 {
        return 0.0
    }
    float term = 1.0
    float result = 1.0
    int i = 1
    for i <= 14 {
        term = term * x / (i * 1.0)
        result = result + term
        i = i + 1
    }
    result
}

func tensor_logfloat x) float {
    if x <= 0.0 {
        return -1e9
    }
    float y = x
    float adj = 0.0
    float ln2 = 0.6931471805599453
    for y >= 2.0 {
        y = y * 0.5
        adj = adj + ln2
    }
    for y < 1.0 {
        y = y * 2.0
        adj = adj - ln2
    }
    float z = y - 1.0
    float s = z
    float term = z
    int i = 2
    for i <= 20 {
        term = term * (-z)
        s = s + term / (i * 1.0)
        i = i + 1
    }
    s + adj
}

func tensor_sqrtfloat x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = x
    int i = 0
    for i < 15 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func tensor_cosfloat x) float {
    float pi = 3.141592653589793
    float two_pi = 6.283185307179586
    float v = x
    for v > pi {
        v = v - two_pi
    }
    for v < -pi {
        v = v + two_pi
    }
    float x2 = v * v
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

func tensor_sinfloat x) float {
    float pi = 3.141592653589793
    float two_pi = 6.283185307179586
    float v = x
    for v > pi {
        v = v - two_pi
    }
    for v < -pi {
        v = v + two_pi
    }
    float x2 = v * v
    float term = v
    float result = v
    int i = 1
    for i <= 10 {
        term = -term * x2 / ((2 * i) * (2 * i + 1) * 1.0)
        result = result + term
        i = i + 1
    }
    result
}

func tensor_sigmoidfloat x) float {
    1.0 / (1.0 + gpt_exp(-x))
}

func swish_activationfloat x) float {
    x * gpt_sigmoid(x)
}

func gelu_activationfloat x) float {
    float x3 = x * x * x
    float inner = x + 0.044715 * x3
    0.5 * x * (1.0 + inner * 0.7978845608)
}

func softmax_rowfloat[] scores, int size) []float {
    float[] out = gpt_alloc(size, 0.0)
    float max_val = scores[0]
    int i = 1
    for i < size {
        if scores[i] > max_val {
            max_val = scores[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    for i < size {
        float e = gpt_exp(scores[i] - max_val)
        out[i] = e
        sum_exp = sum_exp + e
        i = i + 1
    }
    if sum_exp > 0.0 {
        i = 0
        for i < size {
            out[i] = out[i] / sum_exp
            i = i + 1
        }
    }
    out
}

func matmul_kvfloat[] a, float[] b, int m, int k, int n, int full_n) []float {
    float[] result = gpt_alloc(m * n, 0.0)
    int i = 0
    for i < m {
        int j = 0
        for j < n {
            float sum = 0.0
            int l = 0
            for l < k {
                sum = sum + a[i * k + l] * b[l * full_n + j]
                l = l + 1
            }
            result[i * n + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    result
}

func init_weightsint size, float scale) []float {
    float[] w = gpt_alloc(size, 0.0)
    int i = 0
    for i < size {
        float t = (i * 1.0 + 1.0) / ((size + 1) * 1.0)
        float val = gpt_exp(-t) * scale * (1.0 - 2.0 * t)
        w[i] = val
        i = i + 1
    }
    w
}

func new_transformer_layermodel_config cfg) transformer_layer {
    int hidden_dim = cfg.n_embd
    int head_dim = hidden_dim / cfg.n_head
    int kv_dim = head_dim * cfg.n_kv_head
    attention_config attn_cfg = new_attention_config(hidden_dim, cfg.n_head, cfg.n_kv_head, "causal")
    attn_cfg.use_qkv_bias = cfg.use_bias
    ffn_config ffn_cfg = new_ffn_config(hidden_dim, cfg.ffn_dim, cfg.activation, "standard")
    feed_forward_network ffn_mod
    if cfg.activation == "swiglu" || cfg.activation == "geglu" {
        ffn_mod = new_glu_ffn(ffn_cfg)
    } else {
        ffn_mod = new_standard_ffn(ffn_cfg)
    }
    layer_norm_config ln_cfg = layer_norm_config {
        hidden_dim: hidden_dim,
        epsilon: 1e-6,
        use_bias: false,
        norm_type: "rmsnorm",
    }
    transformer_layer {
        attn: new_multi_head_attention(attn_cfg),
        ffn: ffn_mod,
        norm1: new_rms_norm(ln_cfg),
        norm2: new_rms_norm(ln_cfg),
        hidden_dim: hidden_dim,
        n_head: cfg.n_head,
        n_kv_head: cfg.n_kv_head,
        head_dim: head_dim,
        activation: cfg.activation,
    }
}

func new_language_modelmodel_config cfg) language_model {
    int hidden_dim = cfg.n_embd
    float wte_scale = gpt_sqrt(2.0 / (hidden_dim * 1.0)) * 0.02
    float[] wte = gpt_init_weights(cfg.vocab_size * hidden_dim, wte_scale)
    float wpe_scale = 0.01
    float[] wpe = gpt_init_weights(cfg.block_size * hidden_dim, wpe_scale)
    []transformer_layer layers = make([]transformer_layer, cfg.n_layer)
    int i = 0
    for i < cfg.n_layer {
        layers[i] = new_transformer_layer(cfg)
        i = i + 1
    }
    layer_norm_config final_ln_cfg = layer_norm_config {
        hidden_dim: hidden_dim,
        epsilon: 1e-6,
        use_bias: false,
        norm_type: "rmsnorm",
    }
    float[] lm_head_w
    if cfg.tie_embeddings {
        lm_head_w = gpt_copy(wte)
    } else {
        float lm_scale = gpt_sqrt(2.0 / (hidden_dim * 1.0)) * 0.02
        lm_head_w = gpt_init_weights(hidden_dim * cfg.vocab_size, lm_scale)
    }
    int head_dim = hidden_dim / cfg.n_head
    position_embedding_config rope_cfg = position_embedding_config {
        hidden_dim: head_dim,
        max_seq_len: cfg.block_size,
        embed_type: "rope",
        rope_base: cfg.rope_base,
        use_flash_attention: false,
    }
    language_model {
        config: cfg,
        wte: wte,
        wpe: wpe,
        layers: layers,
        final_norm: new_rms_norm(final_ln_cfg),
        lm_head: lm_head_w,
        rope: new_rope_embedding(rope_cfg),
        n_layer: cfg.n_layer,
        vocab_size: cfg.vocab_size,
        n_embd: hidden_dim,
        block_size: cfg.block_size,
    }
}

func embed_tokens(
    float[] wte,
    float[] wpe,
    int[] token_ids,
    int batch_size,
    int seq_len,
    int n_embd
) []float {
    int total = batch_size * seq_len
    float[] out = gpt_alloc(total * n_embd, 0.0)
    int b = 0
    for b < batch_size {
        int s = 0
        for s < seq_len {
            int idx = b * seq_len + s
            int tok_id = token_ids[idx]
            if tok_id < 0 {
                tok_id = 0
            }
            if tok_id >= len(wte) / n_embd {
                tok_id = len(wte) / n_embd - 1
            }
            int src_tok = tok_id * n_embd
            int src_pos = s * n_embd
            int dst = idx * n_embd
            int d = 0
            for d < n_embd {
                float tok_emb = wte[src_tok + d]
                float pos_emb = 0.0
                if src_pos + d < len(wpe) {
                    pos_emb = wpe[src_pos + d]
                }
                out[dst + d] = tok_emb + pos_emb
                d = d + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    out
}

func causal_sdpa
    float[] query,
    float[] key,
    float[] value,
    int seq_len,
    int num_heads,
    int num_kv_heads,
    int head_dim
) []float {
    int total = seq_len
    int out_size = total * num_heads * head_dim
    float[] output = gpt_alloc(out_size, 0.0)
    float scale = 1.0 / gpt_sqrt(head_dim * 1.0)
    float NEG_INF = -1000000.0
    int h = 0
    for h < num_heads {
        int hk = h
        if num_kv_heads > 0 {
            hk = h - (h / num_kv_heads) * num_kv_heads
        }
        int i = 0
        for i < total {
            float[] scores = gpt_alloc(total, 0.0)
            int j = 0
            for j < total {
                if j > i {
                    scores[j] = NEG_INF
                } else {
                    float score = 0.0
                    int d = 0
                    for d < head_dim {
                        float q_val = query[i * (num_heads * head_dim) + h * head_dim + d]
                        float k_val = key[j * (num_kv_heads * head_dim) + hk * head_dim + d]
                        score = score + q_val * k_val
                        d = d + 1
                    }
                    scores[j] = score * scale
                }
                j = j + 1
            }
            float[] weights = gpt_softmax_row(scores, total)
            int d = 0
            for d < head_dim {
                float sum_val = 0.0
                j = 0
                for j <= i {
                    float v_val = value[j * (num_kv_heads * head_dim) + hk * head_dim + d]
                    sum_val = sum_val + weights[j] * v_val
                    j = j + 1
                }
                output[i * (num_heads * head_dim) + h * head_dim + d] = sum_val
                d = d + 1
            }
            i = i + 1
        }
        h = h + 1
    }
    output
}

func transformer_layer_at([]transformer_layer layers, int idx) transformer_layer {
    transformer_layer val = layers[0]
    int i = 0
    for i < len(layers) {
        if i == idx {
            val = layers[i]
        }
        i = i + 1
    }
    val
}

func transformer_layer_forward(
    transformer_layer layer,
    float[] x,
    int batch_size,
    int seq_len,
    rope_embedding rope
) []float {
    int total_tokens = batch_size * seq_len
    int hidden_dim = layer.hidden_dim
    int n_head = layer.n_head
    int n_kv_head = layer.n_kv_head
    int head_dim = layer.head_dim
    int kv_hidden = n_kv_head * head_dim
    float[] normed1 = rms_normalize(layer.norm1, x, batch_size, seq_len)
    float[] q_out = gpt_matmul(normed1, layer.attn.query_weight, total_tokens, hidden_dim, hidden_dim)
    float[] k_out = gpt_matmul_kv(normed1, layer.attn.key_weight,   total_tokens, hidden_dim, kv_hidden, hidden_dim)
    float[] v_out = gpt_matmul_kv(normed1, layer.attn.value_weight, total_tokens, hidden_dim, kv_hidden, hidden_dim)
    if layer.attn.config.use_qkv_bias {
        int i = 0
        for i < total_tokens {
            int d = 0
            for d < hidden_dim {
                q_out[i * hidden_dim + d] = q_out[i * hidden_dim + d] + layer.attn.query_bias[d]
                d = d + 1
            }
            d = 0
            for d < kv_hidden {
                k_out[i * kv_hidden + d] = k_out[i * kv_hidden + d] + layer.attn.key_bias[d]
                v_out[i * kv_hidden + d] = v_out[i * kv_hidden + d] + layer.attn.value_bias[d]
                d = d + 1
            }
            i = i + 1
        }
    }
    float[] q_rope = gpt_copy(q_out)
    float[] k_rope = gpt_copy(k_out)
    int b = 0
    for b < batch_size {
        int s = 0
        for s < seq_len {
            int tok_idx = b * seq_len + s
            int pair_dim = head_dim / 2
            int h = 0
            for h < n_head {
                int pair = 0
                for pair < pair_dim {
                    float freq = rope.frequencies[pair]
                    float angle = (s * 1.0) * freq
                    float cos_val = gpt_cos(angle)
                    float sin_val = gpt_sin(angle)
                    int q_base = tok_idx * hidden_dim + h * head_dim
                    float q0 = q_rope[q_base + 2 * pair]
                    float q1 = q_rope[q_base + 2 * pair + 1]
                    q_rope[q_base + 2 * pair]     = q0 * cos_val - q1 * sin_val
                    q_rope[q_base + 2 * pair + 1] = q0 * sin_val + q1 * cos_val
                    pair = pair + 1
                }
                h = h + 1
            }
            int hk = 0
            for hk < n_kv_head {
                int pair = 0
                for pair < pair_dim {
                    float freq = rope.frequencies[pair]
                    float angle = (s * 1.0) * freq
                    float cos_val = gpt_cos(angle)
                    float sin_val = gpt_sin(angle)
                    int k_base = tok_idx * kv_hidden + hk * head_dim
                    float k0 = k_rope[k_base + 2 * pair]
                    float k1 = k_rope[k_base + 2 * pair + 1]
                    k_rope[k_base + 2 * pair]     = k0 * cos_val - k1 * sin_val
                    k_rope[k_base + 2 * pair + 1] = k0 * sin_val + k1 * cos_val
                    pair = pair + 1
                }
                hk = hk + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    float[] attn_out = gpt_alloc(total_tokens * hidden_dim, 0.0)
    b = 0
    for b < batch_size {
        int batch_offset = b * seq_len
        int q_offset = batch_offset * hidden_dim
        int k_offset = batch_offset * kv_hidden
        int v_offset = batch_offset * kv_hidden
        float[] q_batch = gpt_alloc(seq_len * hidden_dim, 0.0)
        float[] k_batch = gpt_alloc(seq_len * kv_hidden, 0.0)
        float[] v_batch = gpt_alloc(seq_len * kv_hidden, 0.0)
        int i = 0
        for i < seq_len * hidden_dim {
            q_batch[i] = q_rope[q_offset + i]
            i = i + 1
        }
        i = 0
        for i < seq_len * kv_hidden {
            k_batch[i] = k_rope[k_offset + i]
            v_batch[i] = v_out[v_offset + i]
            i = i + 1
        }
        float[] sdpa_out = gpt_causal_sdpa(q_batch, k_batch, v_batch, seq_len, n_head, n_kv_head, head_dim)
        int o = 0
        for o < seq_len * hidden_dim {
            attn_out[batch_offset * hidden_dim + o] = sdpa_out[o]
            o = o + 1
        }
        b = b + 1
    }
    float[] attn_proj = gpt_matmul(attn_out, layer.attn.output_weight, total_tokens, hidden_dim, hidden_dim)
    if layer.attn.config.use_qkv_bias {
        int i = 0
        for i < total_tokens {
            int d = 0
            for d < hidden_dim {
                attn_proj[i * hidden_dim + d] = attn_proj[i * hidden_dim + d] + layer.attn.output_bias[d]
                d = d + 1
            }
            i = i + 1
        }
    }
    float[] h_attn = gpt_add(x, attn_proj)
    float[] normed2 = rms_normalize(layer.norm2, h_attn, batch_size, seq_len)
    float[] ffn_out
    if layer.activation == "swiglu" || layer.activation == "geglu" {
        ffn_out = forward_swiglu_ffn(layer.ffn, normed2, total_tokens)
    } else {
        ffn_out = forward_standard_ffn(layer.ffn, normed2, total_tokens)
    }
    gpt_add(h_attn, ffn_out)
}

func model_forward
    language_model model,
    int[] token_ids,
    int batch_size,
    int seq_len
) model_output {
    int n_embd = model.n_embd
    int vocab_size = model.vocab_size
    int total = batch_size * seq_len
    float[] hidden = embed_tokens(model.wte, model.wpe, token_ids, batch_size, seq_len, n_embd)
    int l = 0
    for l < model.n_layer {
        transformer_layer layer = transformer_layer_at(model.layers, l)
        hidden = transformer_layer_forward(layer, hidden, batch_size, seq_len, model.rope)
        l = l + 1
    }
    float[] normed_final = rms_normalize(model.final_norm, hidden, batch_size, seq_len)
    float[] logits
    if model.config.tie_embeddings {
        logits = gpt_matmul_t(normed_final, model.lm_head, total, n_embd, vocab_size)
    } else {
        logits = gpt_matmul(normed_final, model.lm_head, total, n_embd, vocab_size)
    }
    model_output {
        logits: logits,
        last_hidden: normed_final,
        loss: -1.0,
    }
}

func gpt_loss(
    float[] logits,
    int[] targets,
    int total_tokens,
    int vocab_size
) float {
    float loss = 0.0
    int count = 0
    int i = 0
    for i < total_tokens {
        int tgt = targets[i]
        if tgt < 0 {
            i = i + 1
            continue
        }
        if tgt >= vocab_size {
            tgt = vocab_size - 1
        }
        int base = i * vocab_size
        float max_logit = logits[base]
        int j = 1
        for j < vocab_size {
            if logits[base + j] > max_logit {
                max_logit = logits[base + j]
            }
            j = j + 1
        }
        float lse = 0.0
        j = 0
        for j < vocab_size {
            lse = lse + gpt_exp(logits[base + j] - max_logit)
            j = j + 1
        }
        float log_lse = gpt_log(lse) + max_logit
        float target_logit = logits[base + tgt]
        loss = loss + (log_lse - target_logit)
        count = count + 1
        i = i + 1
    }
    if count == 0 {
        return 0.0
    }
    loss / (count * 1.0)
}

func gpt_generate_greedy(
    language_model model,
    int[] prompt,
    int max_new_tokens
) []int {
    int prompt_len = len(prompt)
    int max_total = prompt_len + max_new_tokens
    int[] context = gpt_alloc_int(max_total)
    int i = 0
    for i < prompt_len {
        context[i] = prompt[i]
        i = i + 1
    }
    int cur_len = prompt_len
    for cur_len < max_total {
        int start = cur_len - model.block_size
        if start < 0 {
            start = 0
        }
        int input_len = cur_len - start
        int[] input_ids = gpt_alloc_int(input_len)
        int s = 0
        for s < input_len {
            input_ids[s] = context[start + s]
            s = s + 1
        }
        model_output out = gpt_forward(model, input_ids, 1, input_len)
        int last_base = (input_len - 1) * model.vocab_size
        int best_tok = 0
        float best_logit = out.logits[last_base]
        int v = 1
        for v < model.vocab_size {
            if out.logits[last_base + v] > best_logit {
                best_logit = out.logits[last_base + v]
                best_tok = v
            }
            v = v + 1
        }
        context[cur_len] = best_tok
        cur_len = cur_len + 1
        if best_tok == 50256 || best_tok == 128001 || best_tok == 2 {
            break
        }
    }
    int new_len = cur_len - prompt_len
    int[] result = gpt_alloc_int(new_len)
    i = 0
    for i < new_len {
        result[i] = context[prompt_len + i]
        i = i + 1
    }
    result
}

func gpt_generate_topk(
    language_model model,
    int[] prompt,
    int max_new_tokens,
    int top_k,
    float temperature,
    int seed
) []int {
    int prompt_len = len(prompt)
    int max_total = prompt_len + max_new_tokens
    int[] context = gpt_alloc_int(max_total)
    int i = 0
    for i < prompt_len {
        context[i] = prompt[i]
        i = i + 1
    }
    int cur_len = prompt_len
    int rng_state = seed + 42
    for cur_len < max_total {
        int start = cur_len - model.block_size
        if start < 0 {
            start = 0
        }
        int input_len = cur_len - start
        int[] input_ids = gpt_alloc_int(input_len)
        int s = 0
        for s < input_len {
            input_ids[s] = context[start + s]
            s = s + 1
        }
        model_output out = gpt_forward(model, input_ids, 1, input_len)
        int last_base = (input_len - 1) * model.vocab_size
        float[] scaled = gpt_alloc(model.vocab_size, 0.0)
        if temperature > 0.0001 {
            int v = 0
            for v < model.vocab_size {
                scaled[v] = out.logits[last_base + v] / temperature
                v = v + 1
            }
        } else {
            int v = 0
            for v < model.vocab_size {
                scaled[v] = out.logits[last_base + v]
                v = v + 1
            }
        }
        int actual_k = top_k
        if actual_k <= 0 || actual_k > model.vocab_size {
            actual_k = model.vocab_size
        }
        int[] top_indices = gpt_alloc_int(actual_k)
        float[] top_vals = gpt_alloc(actual_k, -1000000.0)
        int v = 0
        for v < model.vocab_size {
            int min_pos = 0
            int k = 1
            for k < actual_k {
                if top_vals[k] < top_vals[min_pos] {
                    min_pos = k
                }
                k = k + 1
            }
            if scaled[v] > top_vals[min_pos] {
                top_vals[min_pos] = scaled[v]
                top_indices[min_pos] = v
            }
            v = v + 1
        }
        float[] top_probs = gpt_softmax_row(top_vals, actual_k)
        rng_state = rng_state * 1664525 + 1013904223
        int rng_abs = rng_state
        if rng_abs < 0 {
            rng_abs = -rng_abs
        }
        int rng_mod = rng_abs - (rng_abs / 1000000000) * 1000000000
        float r = (rng_mod * 1.0) / 1000000000.0
        float cumulative = 0.0
        int chosen = top_indices[0]
        int k = 0
        for k < actual_k {
            cumulative = cumulative + top_probs[k]
            if r <= cumulative {
                chosen = top_indices[k]
                break
            }
            k = k + 1
        }
        context[cur_len] = chosen
        cur_len = cur_len + 1
        if chosen == 50256 || chosen == 128001 || chosen == 2 {
            break
        }
    }
    int new_len = cur_len - prompt_len
    int[] result = gpt_alloc_int(new_len)
    i = 0
    for i < new_len {
        result[i] = context[prompt_len + i]
        i = i + 1
    }
    result
}

func gpt_generate_nucleus(
    language_model model,
    int[] prompt,
    int max_new_tokens,
    float top_p,
    float temperature,
    int seed
) []int {
    int prompt_len = len(prompt)
    int max_total = prompt_len + max_new_tokens
    int[] context = gpt_alloc_int(max_total)
    int i = 0
    for i < prompt_len {
        context[i] = prompt[i]
        i = i + 1
    }
    int cur_len = prompt_len
    int rng_state = seed + 137
    for cur_len < max_total {
        int start = cur_len - model.block_size
        if start < 0 {
            start = 0
        }
        int input_len = cur_len - start
        int[] input_ids = gpt_alloc_int(input_len)
        int s = 0
        for s < input_len {
            input_ids[s] = context[start + s]
            s = s + 1
        }
        model_output out = gpt_forward(model, input_ids, 1, input_len)
        int last_base = (input_len - 1) * model.vocab_size
        float[] scaled = gpt_alloc(model.vocab_size, 0.0)
        float temp = temperature
        if temp < 0.0001 {
            temp = 1.0
        }
        int v = 0
        for v < model.vocab_size {
            scaled[v] = out.logits[last_base + v] / temp
            v = v + 1
        }
        float[] probs = gpt_softmax_row(scaled, model.vocab_size)
        int[] sorted_idx = gpt_alloc_int(model.vocab_size)
        v = 0
        for v < model.vocab_size {
            sorted_idx[v] = v
            v = v + 1
        }
        int nucleus_size = 0
        float cumulative = 0.0
        v = 0
        for v < model.vocab_size && cumulative < top_p {
            int max_idx = v
            int w = v + 1
            for w < model.vocab_size {
                if probs[sorted_idx[w]] > probs[sorted_idx[max_idx]] {
                    max_idx = w
                }
                w = w + 1
            }
            int tmp = sorted_idx[v]
            sorted_idx[v] = sorted_idx[max_idx]
            sorted_idx[max_idx] = tmp
            cumulative = cumulative + probs[sorted_idx[v]]
            nucleus_size = nucleus_size + 1
            v = v + 1
        }
        if nucleus_size == 0 {
            nucleus_size = 1
        }
        rng_state = rng_state * 22695477 + 1
        int rng_abs2 = rng_state
        if rng_abs2 < 0 {
            rng_abs2 = -rng_abs2
        }
        int rng_mod2 = rng_abs2 - (rng_abs2 / 1000000000) * 1000000000
        float r = (rng_mod2 * 1.0) / 1000000000.0 * cumulative
        float cum2 = 0.0
        int chosen = sorted_idx[0]
        v = 0
        for v < nucleus_size {
            cum2 = cum2 + probs[sorted_idx[v]]
            if r <= cum2 {
                chosen = sorted_idx[v]
                break
            }
            v = v + 1
        }
        context[cur_len] = chosen
        cur_len = cur_len + 1
        if chosen == 50256 || chosen == 128001 || chosen == 2 {
            break
        }
    }
    int new_len = cur_len - prompt_len
    int[] result = gpt_alloc_int(new_len)
    i = 0
    for i < new_len {
        result[i] = context[prompt_len + i]
        i = i + 1
    }
    result
}

func gpt_alloc_int(int size) []int {
    int[] v = make([]int, size)
    int i = 0
    for i < size {
        v[i] = 0
        i = i + 1
    }
    v
}

func gpt_param_count(model_config cfg) int {
    int d = cfg.n_embd
    int v = cfg.vocab_size
    int l = cfg.n_layer
    int h = cfg.n_head
    int kv_h = cfg.n_kv_head
    int ffn = cfg.ffn_dim
    int ctx = cfg.block_size
    int wte_params = v * d
    int wpe_params = ctx * d
    int kv_dim = kv_h * (d / h)
    int attn_params = d * d + d * kv_dim + d * kv_dim + d * d
    if cfg.use_bias {
        attn_params = attn_params + d + kv_dim + kv_dim + d
    }
    int ffn_params = d * ffn + d * ffn + ffn * d
    if cfg.use_bias {
        ffn_params = ffn_params + ffn + ffn + d
    }
    int norm_params = 2 * d
    int layer_params = attn_params + ffn_params + norm_params
    int all_layer_params = l * layer_params
    int final_params = d
    int lm_head_params = 0
    if !cfg.tie_embeddings {
        lm_head_params = d * v
    }
    wte_params + wpe_params + all_layer_params + final_params + lm_head_params
}

func gpt_describe(model_config cfg) string {
    int params = gpt_param_count(cfg)
    int params_m = params / 1000000
    string desc = cfg.name + " | "
    desc = desc + "English text=" + int_to_str_simple(cfg.n_layer) + " | "
    desc = desc + "English text=" + int_to_str_simple(cfg.n_embd) + " | "
    desc = desc + "English text=" + int_to_str_simple(cfg.n_head) + " | "
    desc = desc + "KVEnglish text=" + int_to_str_simple(cfg.n_kv_head) + " | "
    desc = desc + "English text=" + int_to_str_simple(cfg.block_size) + " | "
    desc = desc + "English text=" + cfg.activation + " | "
    desc = desc + "English text " + int_to_str_simple(params_m) + "M parameter"
    desc
}

func int_to_str_simple(int n) string {
    if n == 0 {
        return "0"
    }
    bool neg = n < 0
    int value = n
    if neg {
        value = -value
    }
    string s = ""
    for value > 0 {
        int digit = value - (value / 10) * 10
        s = string(digit + 48) + s
        value = value / 10
    }
    if neg {
        s = "-" + s
    }
    s
}

func gpt_perplexity(float loss) float {
    gpt_exp(loss)
}

func gpt_forward_with_loss(
    language_model model,
    int[] token_ids,
    int[] targets,
    int batch_size,
    int seq_len
) model_output {
    model_output out = gpt_forward(model, token_ids, batch_size, seq_len)
    int total = batch_size * seq_len
    float loss = gpt_loss(out.logits, targets, total, model.vocab_size)
    model_output {
        logits: out.logits,
        last_hidden: out.last_hidden,
        loss: loss,
    }
}
