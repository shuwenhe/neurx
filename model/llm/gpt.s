package neurx.model.llm.gpt

// ============================================================================
// GPT — 完整 Decoder-Only Transformer 实现
//
// 对标: GPT-2 (124M–1.5B) / GPT-3 (6.7B–13B) / GPT-3.5 级别
//
// 架构要点:
//   • 因果注意力 (Causal Self-Attention)  ← 真正的自回归
//   • 旋转位置编码 (RoPE)
//   • SwiGLU 前馈网络
//   • RMSNorm 层归一化 (Pre-Norm)
//   • Weight Tying: 输入嵌入 = LM Head
//   • 支持 GQA (Grouped-Query Attention)
//   • Greedy / Top-K / Nucleus 采样生成
// ============================================================================

use neurx.model.transformer.attention.{
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

// ============================================================================
// 1. GPT 配置结构体
// ============================================================================

struct gpt_config {
    string name               // 模型名称，如 "gpt2-small"
    int vocab_size            // 词表大小 (50257 for GPT-2)
    int n_embd                // 嵌入维度 / 隐藏维度
    int n_layer               // Transformer 层数
    int n_head                // 查询注意力头数
    int n_kv_head             // KV 注意力头数 (=n_head 时为标准 MHA; <n_head 时为 GQA)
    int ffn_dim               // FFN 中间层维度 (通常 = n_embd * 4 / 8/3 for SwiGLU)
    int block_size            // 最大上下文长度
    float rope_base           // RoPE 基底频率 (10000.0)
    float dropout             // Dropout 率 (推理时设为 0.0)
    bool use_bias             // 是否在 QKV / FFN 中使用偏置
    string activation         // "swiglu" | "gelu"
    bool tie_embeddings       // 输入嵌入与 LM Head 共享权重
}

// ============================================================================
// 2. GPT 单层结构体
// ============================================================================

struct gpt_layer {
    multi_head_attention attn    // 注意力模块权重
    feed_forward_network ffn     // 前馈网络权重
    rms_norm norm1               // Pre-Attention RMSNorm
    rms_norm norm2               // Pre-FFN RMSNorm
    int hidden_dim               // = n_embd
    int n_head                   // 查询头数
    int n_kv_head                // KV 头数
    int head_dim                 // = n_embd / n_head
    string activation            // "swiglu" | "gelu"
}

// ============================================================================
// 3. GPT 完整模型结构体
// ============================================================================

struct gpt_model {
    gpt_config config
    []float wte                  // Token Embedding: [vocab_size, n_embd]
    []float wpe                  // 备用 Learned Pos Embedding: [block_size, n_embd]
    []gpt_layer layers           // Transformer 层 [n_layer]
    rms_norm final_norm          // 最终 RMSNorm (在 LM Head 前)
    []float lm_head              // LM Head 权重: [n_embd, vocab_size]
    rope_embedding rope          // RoPE 编码器
    int n_layer
    int vocab_size
    int n_embd
    int block_size
}

struct gpt_output {
    []float logits               // [batch * seq, vocab_size]
    []float last_hidden          // [batch * seq, n_embd]
    float loss                   // -1.0 if targets not provided
}

// ============================================================================
// 4. 模型配置工厂函数 (GPT-2 兼容配置)
// ============================================================================

// GPT-2 Small: 124M 参数 (12 层, 768 维, 12 头)
func gpt2_small() gpt_config {
    gpt_config {
        name: "gpt2-small",
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

// GPT-2 Medium: 355M 参数 (24 层, 1024 维, 16 头)
func gpt2_medium() gpt_config {
    gpt_config {
        name: "gpt2-medium",
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

// GPT-2 Large: 774M 参数 (36 层, 1280 维, 20 头)
func gpt2_large() gpt_config {
    gpt_config {
        name: "gpt2-large",
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

// GPT-2 XL: 1.5B 参数 (48 层, 1600 维, 25 头)
func gpt2_xl() gpt_config {
    gpt_config {
        name: "gpt2-xl",
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

// GPT-3 6.7B 规模: 32 层, 4096 维, 32 头 (SwiGLU + RoPE)
func gpt3_6b() gpt_config {
    gpt_config {
        name: "gpt3-6.7b",
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

// GPT-3 13B 规模: 40 层, 5120 维, 40 头 (SwiGLU + RoPE + GQA)
func gpt3_13b() gpt_config {
    gpt_config {
        name: "gpt3-13b",
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

// GPT-3.5 级别: ~13B 优化配置，支持长上下文 (SwiGLU + RoPE + GQA)
func gpt35_level() gpt_config {
    gpt_config {
        name: "gpt3.5-level",
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

// 自定义配置
func gpt_custom(int n_embd, int n_layer, int n_head, int block_size, string activation) gpt_config {
    gpt_config {
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

// ============================================================================
// 5. 内部工具函数
// ============================================================================

func gpt_alloc(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    while i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func gpt_copy([]float src) []float {
    []float out = gpt_alloc(len(src), 0.0)
    int i = 0
    while i < len(src) {
        out[i] = src[i]
        i = i + 1
    }
    out
}

func gpt_add([]float a, []float b) []float {
    []float out = gpt_copy(a)
    int i = 0
    while i < len(out) {
        out[i] = out[i] + b[i]
        i = i + 1
    }
    out
}

// 转置矩阵乘法: [m, k] @ [n, k]^T -> [m, n]
// 用于 weight-tied LM head: hidden @ wte^T
func gpt_matmul_t([]float a, []float b, int m, int k, int n) []float {
    []float result = gpt_alloc(m * n, 0.0)
    int i = 0
    while i < m {
        int j = 0
        while j < n {
            float sum = 0.0
            int l = 0
            while l < k {
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

// 矩阵乘法: [m, k] @ [k, n] -> [m, n]
func gpt_matmul([]float a, []float b, int m, int k, int n) []float {
    []float result = gpt_alloc(m * n, 0.0)
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

func gpt_exp(float x) float {
    if x > 20.0 {
        return 485165195.4
    }
    if x < -20.0 {
        return 0.0
    }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 14 {
        term = term * x / (i * 1.0)
        result = result + term
        i = i + 1
    }
    result
}

func gpt_log(float x) float {
    if x <= 0.0 {
        return -1e9
    }
    // ln(x) ≈ ln(1 + (x-1)) 展开，映射到 [0.5, 1.0) 区间
    float y = x
    float adj = 0.0
    float ln2 = 0.6931471805599453
    while y >= 2.0 {
        y = y * 0.5
        adj = adj + ln2
    }
    while y < 1.0 {
        y = y * 2.0
        adj = adj - ln2
    }
    // y in [1, 2), compute ln(y) via series
    float z = y - 1.0
    float s = z
    float term = z
    int i = 2
    while i <= 20 {
        term = term * (-z)
        s = s + term / (i * 1.0)
        i = i + 1
    }
    s + adj
}

func gpt_sqrt(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = x
    int i = 0
    while i < 15 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

// 精确 cos/sin (带角度规约，用于 RoPE 旋转)
func gpt_cos(float x) float {
    float pi = 3.141592653589793
    float two_pi = 6.283185307179586
    float v = x
    while v > pi {
        v = v - two_pi
    }
    while v < -pi {
        v = v + two_pi
    }
    float x2 = v * v
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 10 {
        term = -term * x2 / ((2 * i - 1) * (2 * i) * 1.0)
        result = result + term
        i = i + 1
    }
    result
}

func gpt_sin(float x) float {
    float pi = 3.141592653589793
    float two_pi = 6.283185307179586
    float v = x
    while v > pi {
        v = v - two_pi
    }
    while v < -pi {
        v = v + two_pi
    }
    float x2 = v * v
    float term = v
    float result = v
    int i = 1
    while i <= 10 {
        term = -term * x2 / ((2 * i) * (2 * i + 1) * 1.0)
        result = result + term
        i = i + 1
    }
    result
}

func gpt_sigmoid(float x) float {
    1.0 / (1.0 + gpt_exp(-x))
}

func gpt_swish(float x) float {
    x * gpt_sigmoid(x)
}

func gpt_gelu(float x) float {
    float x3 = x * x * x
    float inner = x + 0.044715 * x3
    0.5 * x * (1.0 + inner * 0.7978845608)
}

// 数值稳定 softmax (对单行)
func gpt_softmax_row([]float scores, int size) []float {
    []float out = gpt_alloc(size, 0.0)
    float max_val = scores[0]
    int i = 1
    while i < size {
        if scores[i] > max_val {
            max_val = scores[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    while i < size {
        float e = gpt_exp(scores[i] - max_val)
        out[i] = e
        sum_exp = sum_exp + e
        i = i + 1
    }
    if sum_exp > 0.0 {
        i = 0
        while i < size {
            out[i] = out[i] / sum_exp
            i = i + 1
        }
    }
    out
}

// 初始化权重用 (xavier-like 缩放的小随机值近似)
// 矩阵乘法: [m, k] @ [k, full_n] 取前 n 列 -> [m, n]
// 用于 GQA: weight 按 [hidden_dim, hidden_dim] 存储但只取 kv_dim 列
func gpt_matmul_kv([]float a, []float b, int m, int k, int n, int full_n) []float {
    []float result = gpt_alloc(m * n, 0.0)
    int i = 0
    while i < m {
        int j = 0
        while j < n {
            float sum = 0.0
            int l = 0
            while l < k {
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

func gpt_init_weights(int size, float scale) []float {
    []float w = gpt_alloc(size, 0.0)
    int i = 0
    while i < size {
        // 确定性初始化: 用 sin 散列产生类随机分布
        float t = (i * 1.0 + 1.0) / ((size + 1) * 1.0)
        float val = gpt_exp(-t) * scale * (1.0 - 2.0 * t)
        w[i] = val
        i = i + 1
    }
    w
}

// ============================================================================
// 6. 模型初始化
// ============================================================================

func new_gpt_layer(gpt_config cfg) gpt_layer {
    int hidden_dim = cfg.n_embd
    int head_dim = hidden_dim / cfg.n_head
    int kv_dim = head_dim * cfg.n_kv_head

    // 注意力配置：强制 attention_type = "causal"
    attention_config attn_cfg = new_attention_config(hidden_dim, cfg.n_head, cfg.n_kv_head, "causal")
    attn_cfg.use_qkv_bias = cfg.use_bias

    // FFN 配置
    ffn_config ffn_cfg = new_ffn_config(hidden_dim, cfg.ffn_dim, cfg.activation, "standard")
    feed_forward_network ffn_mod
    if cfg.activation == "swiglu" || cfg.activation == "geglu" {
        ffn_mod = new_glu_ffn(ffn_cfg)
    } else {
        ffn_mod = new_standard_ffn(ffn_cfg)
    }

    // RMSNorm 配置
    layer_norm_config ln_cfg = layer_norm_config {
        hidden_dim: hidden_dim,
        epsilon: 1e-6,
        use_bias: false,
        norm_type: "rmsnorm",
    }

    gpt_layer {
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

func new_gpt_model(gpt_config cfg) gpt_model {
    int hidden_dim = cfg.n_embd

    // Token embedding table
    float wte_scale = gpt_sqrt(2.0 / (hidden_dim * 1.0)) * 0.02
    []float wte = gpt_init_weights(cfg.vocab_size * hidden_dim, wte_scale)

    // Position embedding (learned; used as fallback when RoPE is unavailable)
    float wpe_scale = 0.01
    []float wpe = gpt_init_weights(cfg.block_size * hidden_dim, wpe_scale)

    // 构建所有 Transformer 层
    []gpt_layer layers = []gpt_layer{cap: cfg.n_layer}
    int i = 0
    while i < cfg.n_layer {
        layers[i] = new_gpt_layer(cfg)
        i = i + 1
    }

    // 最终 RMSNorm
    layer_norm_config final_ln_cfg = layer_norm_config {
        hidden_dim: hidden_dim,
        epsilon: 1e-6,
        use_bias: false,
        norm_type: "rmsnorm",
    }

    // LM Head: 默认共享 wte (tied embeddings 时 lm_head = wte^T)
    []float lm_head_w
    if cfg.tie_embeddings {
        lm_head_w = gpt_copy(wte)   // 复制 wte 作为初始 LM head
    } else {
        float lm_scale = gpt_sqrt(2.0 / (hidden_dim * 1.0)) * 0.02
        lm_head_w = gpt_init_weights(hidden_dim * cfg.vocab_size, lm_scale)
    }

    // RoPE 编码器 (head_dim 粒度)
    int head_dim = hidden_dim / cfg.n_head
    position_embedding_config rope_cfg = position_embedding_config {
        hidden_dim: head_dim,
        max_seq_len: cfg.block_size,
        embed_type: "rope",
        rope_base: cfg.rope_base,
        use_flash_attention: false,
    }

    gpt_model {
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

// ============================================================================
// 7. Token + 位置嵌入查找
// ============================================================================

// 将 token ID 序列转换为浮点嵌入向量
// token_ids: [batch_size * seq_len] (先 batch 后 seq)
// 返回: [batch_size * seq_len, n_embd]
func embed_tokens(
    []float wte,
    []float wpe,
    []int token_ids,
    int batch_size,
    int seq_len,
    int n_embd
) []float {
    int total = batch_size * seq_len
    []float out = gpt_alloc(total * n_embd, 0.0)

    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int idx = b * seq_len + s
            int tok_id = token_ids[idx]

            // Clamp token ID 防越界
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
            while d < n_embd {
                // token embedding + position embedding (learned)
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

// ============================================================================
// 8. 因果注意力核心 (Causal Scaled Dot-Product Attention)
//    Q/K/V 布局: [total_tokens, num_heads * head_dim]  (position-first / row-major)
//    其中 total_tokens = batch_size * seq_len
// ============================================================================

func gpt_causal_sdpa(
    []float query,       // [total_tokens, num_heads * head_dim]
    []float key,
    []float value,
    int seq_len,         // 单批序列长度
    int num_heads,
    int num_kv_heads,    // GQA: key/value 头数 (<=num_heads)
    int head_dim
) []float {
    int total = seq_len          // 此处 total_tokens = seq_len (per-batch 处理)
    int out_size = total * num_heads * head_dim
    []float output = gpt_alloc(out_size, 0.0)

    float scale = 1.0 / gpt_sqrt(head_dim * 1.0)
    float NEG_INF = -1000000.0   // 因果掩码负无穷近似

    int h = 0
    while h < num_heads {
        // GQA: key/value 头 hk = h % num_kv_heads
        int hk = h
        if num_kv_heads > 0 {
            hk = h - (h / num_kv_heads) * num_kv_heads
        }

        int i = 0
        while i < total {
            // 计算 query[i] 对所有 key[j] 的注意力得分
            []float scores = gpt_alloc(total, 0.0)
            int j = 0
            while j < total {
                // 因果掩码: j > i 时不可见 (j 是"未来" token)
                if j > i {
                    scores[j] = NEG_INF
                } else {
                    float score = 0.0
                    int d = 0
                    while d < head_dim {
                        // Q: position i, head h, dim d
                        float q_val = query[i * (num_heads * head_dim) + h * head_dim + d]
                        // K: position j, head hk, dim d
                        float k_val = key[j * (num_kv_heads * head_dim) + hk * head_dim + d]
                        score = score + q_val * k_val
                        d = d + 1
                    }
                    scores[j] = score * scale
                }
                j = j + 1
            }

            // Softmax
            []float weights = gpt_softmax_row(scores, total)

            // 加权求和 value
            int d = 0
            while d < head_dim {
                float sum_val = 0.0
                j = 0
                while j <= i {
                    // V: position j, head hk, dim d
                    float v_val = value[j * (num_kv_heads * head_dim) + hk * head_dim + d]
                    sum_val = sum_val + weights[j] * v_val
                    j = j + 1
                }
                // Output: position i, head h, dim d
                output[i * (num_heads * head_dim) + h * head_dim + d] = sum_val
                d = d + 1
            }
            i = i + 1
        }
        h = h + 1
    }

    output
}

// ============================================================================
// 9. 单层 GPT Block 前向传播
//    Pre-Norm 架构: Norm → Attn → Residual → Norm → FFN → Residual
// ============================================================================

func gpt_layer_at([]gpt_layer layers, int idx) gpt_layer {
    gpt_layer val = layers[0]
    int i = 0
    while i < len(layers) {
        if i == idx {
            val = layers[i]
        }
        i = i + 1
    }
    val
}

func gpt_layer_forward(
    gpt_layer layer,
    []float x,           // [batch_size * seq_len, n_embd]
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

    // ── Pre-Attention RMSNorm ──
    []float normed1 = rms_normalize(layer.norm1, x, batch_size, seq_len)

    // ── QKV 投影 ──
    // Q: [total_tokens, hidden_dim]
    []float q_out = gpt_matmul(normed1, layer.attn.query_weight, total_tokens, hidden_dim, hidden_dim)
    // K, V: GQA 时 key_weight/value_weight 存为 [hidden_dim, hidden_dim] 但只用前 kv_hidden 列
    []float k_out = gpt_matmul_kv(normed1, layer.attn.key_weight,   total_tokens, hidden_dim, kv_hidden, hidden_dim)
    []float v_out = gpt_matmul_kv(normed1, layer.attn.value_weight, total_tokens, hidden_dim, kv_hidden, hidden_dim)

    // 加偏置 (若 use_bias)
    if layer.attn.config.use_qkv_bias {
        int i = 0
        while i < total_tokens {
            int d = 0
            while d < hidden_dim {
                q_out[i * hidden_dim + d] = q_out[i * hidden_dim + d] + layer.attn.query_bias[d]
                d = d + 1
            }
            d = 0
            while d < kv_hidden {
                k_out[i * kv_hidden + d] = k_out[i * kv_hidden + d] + layer.attn.key_bias[d]
                v_out[i * kv_hidden + d] = v_out[i * kv_hidden + d] + layer.attn.value_bias[d]
                d = d + 1
            }
            i = i + 1
        }
    }

    // ── 应用 RoPE ──
    // apply_rope 期望布局 [batch, heads, seq, head_dim]；
    // 此处我们按 batch 循环，使每批内按 position-first 布局处理
    []float q_rope = gpt_copy(q_out)
    []float k_rope = gpt_copy(k_out)

    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int tok_idx = b * seq_len + s
            int pair_dim = head_dim / 2

            int h = 0
            while h < n_head {
                int pair = 0
                while pair < pair_dim {
                    float freq = rope.frequencies[pair]
                    float angle = (s * 1.0) * freq
                    float cos_val = gpt_cos(angle)
                    float sin_val = gpt_sin(angle)

                    // Q: position tok_idx, head h, pair [2*pair, 2*pair+1]
                    int q_base = tok_idx * hidden_dim + h * head_dim
                    float q0 = q_rope[q_base + 2 * pair]
                    float q1 = q_rope[q_base + 2 * pair + 1]
                    q_rope[q_base + 2 * pair]     = q0 * cos_val - q1 * sin_val
                    q_rope[q_base + 2 * pair + 1] = q0 * sin_val + q1 * cos_val

                    pair = pair + 1
                }
                h = h + 1
            }

            // Apply RoPE to each KV head
            int hk = 0
            while hk < n_kv_head {
                int pair = 0
                while pair < pair_dim {
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

    // ── 因果注意力 (按 batch 逐条处理) ──
    []float attn_out = gpt_alloc(total_tokens * hidden_dim, 0.0)
    b = 0
    while b < batch_size {
        int batch_offset = b * seq_len
        int q_offset = batch_offset * hidden_dim
        int k_offset = batch_offset * kv_hidden
        int v_offset = batch_offset * kv_hidden

        // 提取本 batch 的 Q/K/V
        []float q_batch = gpt_alloc(seq_len * hidden_dim, 0.0)
        []float k_batch = gpt_alloc(seq_len * kv_hidden, 0.0)
        []float v_batch = gpt_alloc(seq_len * kv_hidden, 0.0)
        int i = 0
        while i < seq_len * hidden_dim {
            q_batch[i] = q_rope[q_offset + i]
            i = i + 1
        }
        i = 0
        while i < seq_len * kv_hidden {
            k_batch[i] = k_rope[k_offset + i]
            v_batch[i] = v_out[v_offset + i]
            i = i + 1
        }

        // 因果 SDPA
        []float sdpa_out = gpt_causal_sdpa(q_batch, k_batch, v_batch, seq_len, n_head, n_kv_head, head_dim)

        // 写回注意力输出
        int o = 0
        while o < seq_len * hidden_dim {
            attn_out[batch_offset * hidden_dim + o] = sdpa_out[o]
            o = o + 1
        }
        b = b + 1
    }

    // ── 输出投影 ──
    []float attn_proj = gpt_matmul(attn_out, layer.attn.output_weight, total_tokens, hidden_dim, hidden_dim)
    if layer.attn.config.use_qkv_bias {
        int i = 0
        while i < total_tokens {
            int d = 0
            while d < hidden_dim {
                attn_proj[i * hidden_dim + d] = attn_proj[i * hidden_dim + d] + layer.attn.output_bias[d]
                d = d + 1
            }
            i = i + 1
        }
    }

    // ── 第一个残差连接 ──
    []float h_attn = gpt_add(x, attn_proj)

    // ── Pre-FFN RMSNorm ──
    []float normed2 = rms_normalize(layer.norm2, h_attn, batch_size, seq_len)

    // ── 前馈网络 (SwiGLU 或 GELU) ──
    []float ffn_out
    if layer.activation == "swiglu" || layer.activation == "geglu" {
        ffn_out = forward_swiglu_ffn(layer.ffn, normed2, total_tokens)
    } else {
        ffn_out = forward_standard_ffn(layer.ffn, normed2, total_tokens)
    }

    // ── 第二个残差连接 ──
    gpt_add(h_attn, ffn_out)
}

// ============================================================================
// 10. 完整 GPT 前向传播
//     输入: token_ids [batch_size * seq_len] (int)
//     输出: gpt_output { logits [batch * seq * vocab], last_hidden, loss }
// ============================================================================

func gpt_forward(
    gpt_model model,
    []int token_ids,
    int batch_size,
    int seq_len
) gpt_output {
    int n_embd = model.n_embd
    int vocab_size = model.vocab_size
    int total = batch_size * seq_len

    // 1. Token + 位置嵌入
    []float hidden = embed_tokens(model.wte, model.wpe, token_ids, batch_size, seq_len, n_embd)

    // 2. 依次通过所有 Transformer 层
    int l = 0
    while l < model.n_layer {
        gpt_layer layer = gpt_layer_at(model.layers, l)
        hidden = gpt_layer_forward(layer, hidden, batch_size, seq_len, model.rope)
        l = l + 1
    }

    // 3. 最终 RMSNorm
    []float normed_final = rms_normalize(model.final_norm, hidden, batch_size, seq_len)

    // 4. LM Head 投影
    //    weight-tied: lm_head 就是 wte [vocab_size, n_embd], 需计算 hidden @ wte^T
    //    独立 LM head: [n_embd, vocab_size], 直接矩阵乘
    []float logits
    if model.config.tie_embeddings {
        logits = gpt_matmul_t(normed_final, model.lm_head, total, n_embd, vocab_size)
    } else {
        logits = gpt_matmul(normed_final, model.lm_head, total, n_embd, vocab_size)
    }

    gpt_output {
        logits: logits,
        last_hidden: normed_final,
        loss: -1.0,
    }
}

// ============================================================================
// 11. 语言模型损失 (Cross-Entropy，数值稳定版)
//     logits: [total_tokens, vocab_size]
//     targets: [total_tokens] (int token IDs; -1 表示忽略)
// ============================================================================

func gpt_loss(
    []float logits,
    []int targets,
    int total_tokens,
    int vocab_size
) float {
    float loss = 0.0
    int count = 0

    int i = 0
    while i < total_tokens {
        int tgt = targets[i]
        if tgt < 0 {
            // -1 表示忽略该位置 (padding)
            i = i + 1
            continue
        }
        if tgt >= vocab_size {
            tgt = vocab_size - 1
        }

        int base = i * vocab_size

        // 找最大值用于数值稳定
        float max_logit = logits[base]
        int j = 1
        while j < vocab_size {
            if logits[base + j] > max_logit {
                max_logit = logits[base + j]
            }
            j = j + 1
        }

        // 计算 log-sum-exp
        float lse = 0.0
        j = 0
        while j < vocab_size {
            lse = lse + gpt_exp(logits[base + j] - max_logit)
            j = j + 1
        }
        float log_lse = gpt_log(lse) + max_logit

        // 交叉熵: -logit[target] + log_sum_exp(logits)
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

// ============================================================================
// 12. 文本生成
// ============================================================================

// 贪心解码: 每步选概率最大的 token
func gpt_generate_greedy(
    gpt_model model,
    []int prompt,
    int max_new_tokens
) []int {
    int prompt_len = len(prompt)
    int max_total = prompt_len + max_new_tokens
    []int context = gpt_alloc_int(max_total)
    int i = 0
    while i < prompt_len {
        context[i] = prompt[i]
        i = i + 1
    }

    int cur_len = prompt_len
    while cur_len < max_total {
        // 裁剪到 block_size
        int start = cur_len - model.block_size
        if start < 0 {
            start = 0
        }
        int input_len = cur_len - start

        []int input_ids = gpt_alloc_int(input_len)
        int s = 0
        while s < input_len {
            input_ids[s] = context[start + s]
            s = s + 1
        }

        // 前向传播
        gpt_output out = gpt_forward(model, input_ids, 1, input_len)

        // 取最后一个 token 的 logits
        int last_base = (input_len - 1) * model.vocab_size
        int best_tok = 0
        float best_logit = out.logits[last_base]
        int v = 1
        while v < model.vocab_size {
            if out.logits[last_base + v] > best_logit {
                best_logit = out.logits[last_base + v]
                best_tok = v
            }
            v = v + 1
        }

        context[cur_len] = best_tok
        cur_len = cur_len + 1

        // EOS token (50256 for GPT-2, 128001 for Llama) 停止
        if best_tok == 50256 || best_tok == 128001 || best_tok == 2 {
            break
        }
    }

    // 返回新生成的部分
    int new_len = cur_len - prompt_len
    []int result = gpt_alloc_int(new_len)
    i = 0
    while i < new_len {
        result[i] = context[prompt_len + i]
        i = i + 1
    }
    result
}

// Top-K + Temperature 采样
func gpt_generate_topk(
    gpt_model model,
    []int prompt,
    int max_new_tokens,
    int top_k,
    float temperature,
    int seed
) []int {
    int prompt_len = len(prompt)
    int max_total = prompt_len + max_new_tokens
    []int context = gpt_alloc_int(max_total)
    int i = 0
    while i < prompt_len {
        context[i] = prompt[i]
        i = i + 1
    }

    int cur_len = prompt_len
    int rng_state = seed + 42

    while cur_len < max_total {
        int start = cur_len - model.block_size
        if start < 0 {
            start = 0
        }
        int input_len = cur_len - start

        []int input_ids = gpt_alloc_int(input_len)
        int s = 0
        while s < input_len {
            input_ids[s] = context[start + s]
            s = s + 1
        }

        gpt_output out = gpt_forward(model, input_ids, 1, input_len)
        int last_base = (input_len - 1) * model.vocab_size

        // 应用 temperature 缩放
        []float scaled = gpt_alloc(model.vocab_size, 0.0)
        if temperature > 0.0001 {
            int v = 0
            while v < model.vocab_size {
                scaled[v] = out.logits[last_base + v] / temperature
                v = v + 1
            }
        } else {
            int v = 0
            while v < model.vocab_size {
                scaled[v] = out.logits[last_base + v]
                v = v + 1
            }
        }

        // Top-K 过滤: 找 top_k 个最大 logit，其余设为 -inf
        int actual_k = top_k
        if actual_k <= 0 || actual_k > model.vocab_size {
            actual_k = model.vocab_size
        }

        // 简单选择排序取 top_k
        []int top_indices = gpt_alloc_int(actual_k)
        []float top_vals = gpt_alloc(actual_k, -1000000.0)
        int v = 0
        while v < model.vocab_size {
            int min_pos = 0
            int k = 1
            while k < actual_k {
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

        // 对 top-k 的 logit 做 softmax
        []float top_probs = gpt_softmax_row(top_vals, actual_k)

        // 按累积概率采样 (LCG 随机数生成器)
        rng_state = rng_state * 1664525 + 1013904223
        int rng_abs = rng_state
        if rng_abs < 0 {
            rng_abs = -rng_abs
        }
        // 取模到 [0, 10^9) 范围
        int rng_mod = rng_abs - (rng_abs / 1000000000) * 1000000000
        float r = (rng_mod * 1.0) / 1000000000.0

        float cumulative = 0.0
        int chosen = top_indices[0]
        int k = 0
        while k < actual_k {
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
    []int result = gpt_alloc_int(new_len)
    i = 0
    while i < new_len {
        result[i] = context[prompt_len + i]
        i = i + 1
    }
    result
}

// Nucleus (Top-P) 采样
func gpt_generate_nucleus(
    gpt_model model,
    []int prompt,
    int max_new_tokens,
    float top_p,
    float temperature,
    int seed
) []int {
    int prompt_len = len(prompt)
    int max_total = prompt_len + max_new_tokens
    []int context = gpt_alloc_int(max_total)
    int i = 0
    while i < prompt_len {
        context[i] = prompt[i]
        i = i + 1
    }

    int cur_len = prompt_len
    int rng_state = seed + 137

    while cur_len < max_total {
        int start = cur_len - model.block_size
        if start < 0 {
            start = 0
        }
        int input_len = cur_len - start

        []int input_ids = gpt_alloc_int(input_len)
        int s = 0
        while s < input_len {
            input_ids[s] = context[start + s]
            s = s + 1
        }

        gpt_output out = gpt_forward(model, input_ids, 1, input_len)
        int last_base = (input_len - 1) * model.vocab_size

        // Temperature 缩放 + softmax
        []float scaled = gpt_alloc(model.vocab_size, 0.0)
        float temp = temperature
        if temp < 0.0001 {
            temp = 1.0
        }
        int v = 0
        while v < model.vocab_size {
            scaled[v] = out.logits[last_base + v] / temp
            v = v + 1
        }
        []float probs = gpt_softmax_row(scaled, model.vocab_size)

        // 对概率降序排列 (insertion sort for small k)
        []int sorted_idx = gpt_alloc_int(model.vocab_size)
        v = 0
        while v < model.vocab_size {
            sorted_idx[v] = v
            v = v + 1
        }
        // Partial bubble sort: 找满足 top_p 所需的 token 数量
        int nucleus_size = 0
        float cumulative = 0.0
        v = 0
        while v < model.vocab_size && cumulative < top_p {
            // 找未处理中最大的
            int max_idx = v
            int w = v + 1
            while w < model.vocab_size {
                if probs[sorted_idx[w]] > probs[sorted_idx[max_idx]] {
                    max_idx = w
                }
                w = w + 1
            }
            // swap
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

        // 在 nucleus 内采样 (LCG 随机数生成器)
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
        while v < nucleus_size {
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
    []int result = gpt_alloc_int(new_len)
    i = 0
    while i < new_len {
        result[i] = context[prompt_len + i]
        i = i + 1
    }
    result
}

// ============================================================================
// 13. 工具函数
// ============================================================================

// 分配整型数组
func gpt_alloc_int(int size) []int {
    []int v = []int{cap: size}
    int i = 0
    while i < size {
        v[i] = 0
        i = i + 1
    }
    v
}

// 估算参数量
func gpt_param_count(gpt_config cfg) int {
    int d = cfg.n_embd
    int v = cfg.vocab_size
    int l = cfg.n_layer
    int h = cfg.n_head
    int kv_h = cfg.n_kv_head
    int ffn = cfg.ffn_dim
    int ctx = cfg.block_size

    // Token embedding: vocab_size * n_embd
    int wte_params = v * d

    // Position embedding (learned): block_size * n_embd
    int wpe_params = ctx * d

    // Per layer:
    //   Attn: Q (d*d) + K (d * kv_h * d/h) + V (...) + O (d*d) + biases
    int kv_dim = kv_h * (d / h)
    int attn_params = d * d + d * kv_dim + d * kv_dim + d * d
    if cfg.use_bias {
        attn_params = attn_params + d + kv_dim + kv_dim + d
    }
    //   FFN: SwiGLU has gate + value + down
    int ffn_params = d * ffn + d * ffn + ffn * d
    if cfg.use_bias {
        ffn_params = ffn_params + ffn + ffn + d
    }
    //   Norms: 2 * n_embd (gamma only, no bias)
    int norm_params = 2 * d

    int layer_params = attn_params + ffn_params + norm_params
    int all_layer_params = l * layer_params

    // Final norm + LM head (if not tied)
    int final_params = d  // final norm gamma
    int lm_head_params = 0
    if !cfg.tie_embeddings {
        lm_head_params = d * v
    }

    wte_params + wpe_params + all_layer_params + final_params + lm_head_params
}

// 以人类可读格式描述模型
func gpt_describe(gpt_config cfg) string {
    int params = gpt_param_count(cfg)
    int params_m = params / 1000000
    string desc = cfg.name + " | "
    desc = desc + "层数=" + int_to_str_simple(cfg.n_layer) + " | "
    desc = desc + "维度=" + int_to_str_simple(cfg.n_embd) + " | "
    desc = desc + "注意力头=" + int_to_str_simple(cfg.n_head) + " | "
    desc = desc + "KV头=" + int_to_str_simple(cfg.n_kv_head) + " | "
    desc = desc + "上下文=" + int_to_str_simple(cfg.block_size) + " | "
    desc = desc + "激活=" + cfg.activation + " | "
    desc = desc + "约 " + int_to_str_simple(params_m) + "M 参数"
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
    while value > 0 {
        int digit = value - (value / 10) * 10
        s = string(digit + 48) + s
        value = value / 10
    }
    if neg {
        s = "-" + s
    }
    s
}

// 计算困惑度 (Perplexity = exp(loss))
func gpt_perplexity(float loss) float {
    gpt_exp(loss)
}

// 交叉熵损失 (含 logits 和 targets 一体的便捷接口)
func gpt_forward_with_loss(
    gpt_model model,
    []int token_ids,
    []int targets,
    int batch_size,
    int seq_len
) gpt_output {
    gpt_output out = gpt_forward(model, token_ids, batch_size, seq_len)
    int total = batch_size * seq_len
    float loss = gpt_loss(out.logits, targets, total, model.vocab_size)
    gpt_output {
        logits: out.logits,
        last_hidden: out.last_hidden,
        loss: loss,
    }
}
