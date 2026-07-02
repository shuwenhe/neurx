package neurx.model.llm.gpt_moe

// ============================================================================
// Sparse GPT-MoE — interleaves dense + MoE transformer layers
//
// Architecture: N transformer blocks where every moe_frequency-th block
// replaces the dense FFN with a Mixture-of-Experts FFN.
// The attention mechanism, RMSNorm, RoPE, and residuals are identical to
// dense GPT; only the FFN sub-layer differs for MoE blocks.
//
// Examples:
//   • Mixtral-8x7B: every block is MoE (moe_frequency=1), 8 experts, top-2
//   • GPT-4 style:  every 2nd block is MoE (moe_frequency=2)
//   • DeepSeek-MoE: every block MoE, 64 fine-grained experts, top-6
// ============================================================================

use neurx.model.llm.gpt.{
    gpt_config, gpt_model, gpt_layer, gpt_output,
    new_gpt_model, new_gpt_layer, gpt_layer_at,
    gpt_alloc, gpt_copy, gpt_add, gpt_matmul, gpt_matmul_t,
    gpt_matmul_kv, gpt_cos, gpt_sin, gpt_swish, gpt_sigmoid,
    gpt_softmax_row, gpt_causal_sdpa, gpt_alloc_int,
    embed_tokens, gpt_perplexity, gpt_param_count
}
use neurx.model.transformer.moe.{
    moe_config, moe_layer, moe_output,
    new_moe_layer, moe_forward,
    moe_mixtral_config, moe_large_config, moe_fine_grained_config
}
use neurx.model.transformer.norm.{rms_norm, rms_normalize, layer_norm_config, new_rms_norm}

// ============================================================================
// 1. 구성 구조체
// ============================================================================

struct gpt_moe_config {
    gpt_config base             // 基础 GPT 配置 (含 n_layer, n_embd, …)
    moe_config moe              // MoE 配置 (expert_dim, num_experts, top_k, …)
    int moe_frequency           // 每几层使用一个 MoE 层 (1 = 全 MoE, 2 = 每隔一层)
    float moe_aux_loss_weight   // aux loss 在总损失中的权重
}

// 预设: Mixtral-8x7B 风格 (全 MoE, 8 专家, top-2)
func gpt_moe_mixtral(gpt_config base) gpt_moe_config {
    gpt_moe_config {
        base: base,
        moe: moe_mixtral_config(base.n_embd),
        moe_frequency: 1,
        moe_aux_loss_weight: 0.01,
    }
}

// 预设: GPT-4 风格 (每隔一层, 16 专家, top-2)
func gpt_moe_gpt4_style(gpt_config base) gpt_moe_config {
    gpt_moe_config {
        base: base,
        moe: moe_large_config(base.n_embd),
        moe_frequency: 2,
        moe_aux_loss_weight: 0.01,
    }
}

// 预设: DeepSeek-V3 风格 (全 MoE, 64 细粒度专家, top-6)
func gpt_moe_deepseek(gpt_config base) gpt_moe_config {
    gpt_moe_config {
        base: base,
        moe: moe_fine_grained_config(base.n_embd),
        moe_frequency: 1,
        moe_aux_loss_weight: 0.003,
    }
}

// ============================================================================
// 2. GPT-MoE 块 (注意力相同; FFN 替换为 MoE)
// ============================================================================

struct gpt_moe_block {
    gpt_layer dense_block       // 注意力、norm1、norm2 取自标准 GPT 层
    moe_layer moe_ffn           // MoE FFN
    bool is_moe                 // 此层是否为 MoE (false = 使用 dense_block.ffn)
    int layer_idx
}

// ============================================================================
// 3. 完整模型
// ============================================================================

struct gpt_moe_model {
    gpt_moe_config config
    []float wte                 // [vocab, n_embd]
    []float wpe                 // [block, n_embd]
    []gpt_moe_block blocks
    rms_norm final_norm
    []float lm_head
    []float rope_freqs          // 从 gpt_model.rope.frequencies 提取
    int n_layer
    int vocab_size
    int n_embd
    int block_size
    int num_moe_layers          // 统计 MoE 层数量
}

struct gpt_moe_output {
    []float logits
    []float last_hidden
    float lm_loss               // 语言模型交叉熵损失
    float aux_loss              // MoE 负载均衡辅助损失 (加权)
    float total_loss            // lm_loss + aux_loss
}

// ============================================================================
// 4. 初始化
// ============================================================================

func new_gpt_moe_model(gpt_moe_config cfg) gpt_moe_model {
    // 先建立标准 GPT 模型用于初始化权重
    gpt_model base = new_gpt_model(cfg.base)

    int nl = cfg.base.n_layer
    int H = cfg.base.n_embd
    int moe_freq = cfg.moe_frequency
    if moe_freq < 1 { moe_freq = 1 }

    []gpt_moe_block blocks = []gpt_moe_block{cap: nl}
    int num_moe = 0
    int l = 0
    while l < nl {
        bool is_moe = (l - (l / moe_freq) * moe_freq == 0)

        gpt_layer_config_local lc = default_moe_layer_config(cfg.base)
        lc.hidden_dim = H
        gpt_layer dense = gpt_layer_at(base.layers, l)

        moe_layer moe_ffn = new_moe_layer(cfg.moe)

        blocks[l] = gpt_moe_block {
            dense_block: dense,
            moe_ffn: moe_ffn,
            is_moe: is_moe,
            layer_idx: l,
        }
        if is_moe { num_moe = num_moe + 1 }
        l = l + 1
    }

    gpt_moe_model {
        config: cfg,
        wte: base.wte,
        wpe: base.wpe,
        blocks: blocks,
        final_norm: base.final_norm,
        lm_head: base.lm_head,
        rope_freqs: base.rope.frequencies,
        n_layer: nl,
        vocab_size: cfg.base.vocab_size,
        n_embd: H,
        block_size: cfg.base.block_size,
        num_moe_layers: num_moe,
    }
}

struct gpt_layer_config_local {
    int hidden_dim
}

func default_moe_layer_config(gpt_config base) gpt_layer_config_local {
    gpt_layer_config_local { hidden_dim: base.n_embd }
}

func gpt_moe_block_at([]gpt_moe_block blocks, int idx) gpt_moe_block {
    gpt_moe_block val = blocks[0]
    int i = 0
    while i < len(blocks) {
        if i == idx { val = blocks[i] }
        i = i + 1
    }
    val
}

// ============================================================================
// 5. 单块前向传播
// ============================================================================

func gpt_moe_block_forward(
    gpt_moe_block block,
    []float x,              // [B*S, H]
    int batch_size,
    int seq_len,
    []float rope_freqs
) ( []float, float ) {        // (output [B*S, H], aux_loss)
    int total = batch_size * seq_len
    int H = block.dense_block.hidden_dim
    int nh = block.dense_block.n_head
    int nkv = block.dense_block.n_kv_head
    int hd = block.dense_block.head_dim
    int kv_D = nkv * hd

    // ── Pre-Attn RMSNorm ──
    []float normed1 = rms_normalize(block.dense_block.norm1, x, batch_size, seq_len)

    // ── QKV 投影 ──
    []float q = gpt_matmul(normed1, block.dense_block.attn.query_weight, total, H, H)
    []float k = gpt_matmul_kv(normed1, block.dense_block.attn.key_weight,   total, H, kv_D, H)
    []float v = gpt_matmul_kv(normed1, block.dense_block.attn.value_weight, total, H, kv_D, H)

    // ── RoPE ──
    int pair_dim = hd / 2
    []float qr = gpt_copy(q)
    []float kr = gpt_copy(k)
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int tok = b * seq_len + s
            int h = 0
            while h < nh {
                int p = 0
                while p < pair_dim {
                    float angle = (s * 1.0) * rope_freqs[p]
                    float cv = gpt_cos(angle)
                    float sv = gpt_sin(angle)
                    int base_q = tok * H + h * hd
                    float q0 = qr[base_q + 2*p]; float q1 = qr[base_q + 2*p+1]
                    qr[base_q + 2*p]   = q0*cv - q1*sv
                    qr[base_q + 2*p+1] = q0*sv + q1*cv
                    p = p + 1
                }
                h = h + 1
            }
            int hk = 0
            while hk < nkv {
                int p = 0
                while p < pair_dim {
                    float angle = (s * 1.0) * rope_freqs[p]
                    float cv = gpt_cos(angle)
                    float sv = gpt_sin(angle)
                    int base_k = tok * kv_D + hk * hd
                    float k0 = kr[base_k + 2*p]; float k1 = kr[base_k + 2*p+1]
                    kr[base_k + 2*p]   = k0*cv - k1*sv
                    kr[base_k + 2*p+1] = k0*sv + k1*cv
                    p = p + 1
                }
                hk = hk + 1
            }
            s = s + 1
        }
        b = b + 1
    }

    // ── 因果 SDPA ──
    []float attn_out = gpt_alloc(total * H, 0.0)
    b = 0
    while b < batch_size {
        int off_q = b * seq_len * H
        int off_k = b * seq_len * kv_D
        []float qb = gpt_alloc(seq_len * H, 0.0)
        []float kb = gpt_alloc(seq_len * kv_D, 0.0)
        []float vb = gpt_alloc(seq_len * kv_D, 0.0)
        int i = 0
        while i < seq_len * H    { qb[i] = qr[off_q + i]; i = i+1 }
        i = 0
        while i < seq_len * kv_D { kb[i] = kr[off_k + i]; vb[i] = v[off_k + i]; i = i+1 }
        []float sdpa = gpt_causal_sdpa(qb, kb, vb, seq_len, nh, nkv, hd)
        i = 0
        while i < seq_len * H { attn_out[b*seq_len*H + i] = sdpa[i]; i = i+1 }
        b = b + 1
    }

    // 输出投影
    []float attn_proj = gpt_matmul(attn_out, block.dense_block.attn.output_weight, total, H, H)
    []float h_attn = gpt_add(x, attn_proj)

    // ── Pre-FFN RMSNorm ──
    []float normed2 = rms_normalize(block.dense_block.norm2, h_attn, batch_size, seq_len)

    // ── FFN (MoE or dense) ──
    []float ffn_out
    float aux_loss = 0.0
    if block.is_moe {
        moe_output mo = moe_forward(block.moe_ffn, normed2, total)
        ffn_out = mo.hidden
        aux_loss = mo.aux_loss
    } else {
        // 用 gpt_layer 原有的 FFN (SwiGLU 重建)
        ffn_out = gpt_dense_ffn_forward(block.dense_block, normed2, total)
    }

    (gpt_add(h_attn, ffn_out), aux_loss)
}

// 重建稠密 SwiGLU 前向 (用于 is_moe=false 的块)
func gpt_dense_ffn_forward(gpt_layer layer, []float normed2, int total) []float {
    int H = layer.hidden_dim
    int ffn_D = len(layer.ffn.glu_ffn.gate_weight) / H
    []float gate = gpt_matmul(normed2, layer.ffn.glu_ffn.gate_weight, total, H, ffn_D)
    []float val  = gpt_matmul(normed2, layer.ffn.glu_ffn.value_weight, total, H, ffn_D)
    int i = 0
    while i < total * ffn_D {
        gate[i] = gate[i] + layer.ffn.glu_ffn.gate_bias[i % ffn_D]
        val[i]  = val[i]  + layer.ffn.glu_ffn.value_bias[i % ffn_D]
        i = i + 1
    }
    []float gv = gpt_alloc(total * ffn_D, 0.0)
    i = 0
    while i < total * ffn_D {
        gv[i] = gpt_swish(gate[i]) * val[i]
        i = i + 1
    }
    []float down = gpt_matmul(gv, layer.ffn.glu_ffn.down_weight, total, ffn_D, H)
    i = 0
    while i < total * H {
        down[i] = down[i] + layer.ffn.glu_ffn.down_bias[i % H]
        i = i + 1
    }
    down
}

// ============================================================================
// 6. 完整 GPT-MoE 前向传播
// ============================================================================

func gpt_moe_forward(
    gpt_moe_model model,
    []int token_ids,
    int batch_size,
    int seq_len
) gpt_moe_output {
    int H = model.n_embd
    int V = model.vocab_size
    int total = batch_size * seq_len

    // 嵌入
    []float hidden = embed_tokens(model.wte, model.wpe, token_ids, batch_size, seq_len, H)

    // 逐层
    float total_aux = 0.0
    int l = 0
    while l < model.n_layer {
        gpt_moe_block block = gpt_moe_block_at(model.blocks, l)
        []float next_hidden
        float aux
        (next_hidden, aux) = gpt_moe_block_forward(block, hidden, batch_size, seq_len, model.rope_freqs)
        hidden = next_hidden
        total_aux = total_aux + aux
        l = l + 1
    }

    // 最终 norm
    []float normed = rms_normalize(model.final_norm, hidden, batch_size, seq_len)

    // LM head
    []float logits
    if model.config.base.tie_embeddings {
        logits = gpt_matmul_t(normed, model.lm_head, total, H, V)
    } else {
        logits = gpt_matmul(normed, model.lm_head, total, H, V)
    }

    // 平均 aux loss (各 MoE 层 aux 之和 / MoE 层数)
    float avg_aux = 0.0
    if model.num_moe_layers > 0 {
        avg_aux = total_aux / (model.num_moe_layers * 1.0)
    }

    gpt_moe_output {
        logits: logits,
        last_hidden: normed,
        lm_loss: -1.0,
        aux_loss: avg_aux * model.config.moe_aux_loss_weight,
        total_loss: -1.0,
    }
}

// ============================================================================
// 7. 参数量统计
// ============================================================================

func gpt_moe_param_count(gpt_moe_config cfg) int {
    int base = gpt_param_count(cfg.base)   // 注意力 + 非 MoE FFN 部分
    int nl = cfg.base.n_layer
    int H = cfg.base.n_embd
    int moe_freq = cfg.moe_frequency
    if moe_freq < 1 { moe_freq = 1 }

    int moe_count = nl / moe_freq

    // 每个 MoE 层替换掉的稠密 FFN 参数 = 3 * H * ffn_dim
    int dense_ffn = 3 * H * cfg.base.ffn_dim

    // MoE 层参数 = num_experts * per_expert + router
    int per_expert = 3 * H * cfg.moe.expert_dim
    int moe_layer_params = per_expert * cfg.moe.num_experts + H * cfg.moe.num_experts

    // 净增量
    int delta = moe_count * (moe_layer_params - dense_ffn)

    base + delta
}
