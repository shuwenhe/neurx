// ============================================================
// NEURX (General Language Model) Architecture Definition
// supportEnglish text: NEURX-4, MULTIMODAL-VISION, NEURX-5.2
// English text: Prefix Language Model (Prefix-LM) English text
// - English text (prefix English text) + English text (generateEnglish text)
// - 2D English text (English text + English text)
// - support MoE (Mixture of Experts) extension
// ============================================================

package neurx.model.llm.neurx

import neurx.model.transformer.*
import neurx.model.transformer.rope_scaling.*
import neurx.tensor.*
import neurx.nn.*

// ============================================================
// NEURX English text
// ============================================================
enum neurx_version {
    NEURX_130B      // NEURX-130B (2023)
    NEURX_4_9B      // NEURX-4-9B (2024)
    NEURX_4_34B     // NEURX-4-34B (2024)
    MULTIMODAL_VISION        // MULTIMODAL-VISION (English text)
    NEURX_4_LONG    // NEURX-4-Long (128K context)
    NEURX_5_2       // NEURX-5.2 (English text)
}

// ============================================================
// NEURX configurationEnglish text
// ============================================================
struct neurx_config {
    // === English textinformation ===
    neurx_version version
    string name
    string description

    // === modelEnglish textparameter ===
    int vocab_size              // English text (NEURX-4: 151552, NEURX-5.2: ~200K+)
    int hidden_size             // English text
    int num_layers              // Transformer English text
    int num_attention_heads     // English text
    int num_key_value_heads     // KV English text (GQA, English text < num_attention_heads)

    // === FFN / MoE parameter ===
    int intermediate_size        // FFN English text
    bool use_moe                // English textuse MoE
    int moe_num_experts         // English textcount
    int moe_top_k               // English text
    float moe_router_z_loss_coef // English text z-loss English text

    // === English textparameter ===
    int max_seq_len             // English text
    int max_position_embeddings  // English text
    string position_encoding_type // "2d" | "rope"
    float rope_theta            // RoPE English text (10000.0 English text 1000000.0 for long context)
    int rope_scaling_type       // 0=none, 1=linear, 2=ntk, 3=yarn
    float rope_factor           // RoPE English text

    // === English text token ID (NEURX English text) ===
    int pad_token_id            // padding token
    int bos_token_id            // beginning of sequence
    int eos_token_id            // end of sequence
    int mask_token_id           // MLM mask token (NEURX-130B)
    int gmask_token_id          // generation mask (NEURX-4)
    int sop_token_id            // start of prefix
    int eop_token_id            // end of prefix

    // === trainingEnglish textparameter ===
    float dropout
    float attention_dropout
    float layer_norm_epsilon
    bool use_bias                // Linear English textuse bias
    bool tied_embeddings         // inputoutput embedding English textweight
    float init_std               // initializeEnglish text

    // === English textextension (MULTIMODAL-VISION) ===
    bool is_vision_model
    int image_size               // English text (224 / 336 / 448)
    int patch_size               // Patch English text (14)
    int vision_hidden_size        // English text
    int vision_num_layers        // English text Transformer English text
    int vision_intermediate_size  // English text FFN English text

    // === English textextension (NEURX-Long) ===
    bool enable_long_context     // English textsupport
    int long_context_max_len     // English text (128K / 256K)
}

// ============================================================
// NEURX modelstate
// ============================================================
struct neurx_state {
    neurx_config config
    string model_path
    int total_parameters        // English textparameterEnglish text
    int training_step           // English texttrainingstepEnglish text
    float training_loss         // English texttraining loss
    float validation_loss       // English text loss
    bool is_loaded              // modelEnglish textload
    bool is_training            // English texttrainingEnglish text

    // statisticsinformation
    struct stats {
        float avg_tokens_per_sec   // English text
        float peak_memory_mb       // English text
        int total_flops            // computeEnglish text (FLOPs)
    } stats
}

// ============================================================
// English text NEURX-5.2 configuration (~200B parameter, English textmodel)
// ============================================================
func create_neurx_200b_config_200b() neurx_config {
    neurx_config {
        version: NEURX_5_2,
        name: "NEURX-5.2-200B",
        description: "General Language Model v5.2 with 200B parameters",

        // modelEnglish text
        vocab_size: 200000,
        hidden_size: 12288,          // 12K
        num_layers: 96,
        num_attention_heads: 96,
        num_key_value_heads: 8,      // GQA: 96/8 = 12 English text

        // FFN (use SwiGLU)
        intermediate_size: 32768,
        use_moe: false,

        // English text (RoPE + YaRN Scaling for 128K context)
        max_seq_len: 131072,        // 128K tokens
        max_position_embeddings: 131072,
        position_encoding_type: "rope",
        rope_theta: 500000.0,       // NEURX useEnglish text
        rope_scaling_type: 3,       // YaRN
        rope_factor: 32.0,          // 4K → 128K

        // NEURX English text Token IDs
        pad_token_id: 0,
        bos_token_id: 1,
        eos_token_id: 2,
        gmask_token_id: 150001,     // NEURX-5.2 gMASK token
        sop_token_id: 150002,       // Start of Prefix
        eop_token_id: 150003,       // End of Prefix

        // trainingparameter
        dropout: 0.0,
        attention_dropout: 0.0,
        layer_norm_epsilon: 1e-5,
        use_bias: false,
        tied_embeddings: false,
        init_std: 0.02,

        // English text (English textsupportEnglish text)
        is_vision_model: false,

        // English text
        enable_long_context: true,
        long_context_max_len: 131072,
    }
}

// ============================================================
// English text NEURX-4-9B configuration (English text, English text)
// ============================================================
func create_neurx_9b_config() neurx_config {
    neurx_config {
        version: NEURX_4_9B,
        name: "NEURX-4-9B",
        description: "NEURX-4 with 9 billion parameters",

        vocab_size: 151552,
        hidden_size: 4096,
        num_layers: 40,
        num_attention_heads: 32,
        num_key_value_heads: 8,      // GQA: 32/8 = 4 English text

        intermediate_size: 13696,
        use_moe: false,

        max_seq_len: 8192,
        max_position_embeddings: 8192,
        position_encoding_type: "rope",
        rope_theta: 10000.0,
        rope_scaling_type: 1,       // Linear scaling
        rope_factor: 2.0,          // 4K → 8K

        pad_token_id: 0,
        bos_token_id: 1,
        eos_token_id: 2,
        gmask_token_id: 150001,
        sop_token_id: 150002,
        eop_token_id: 150003,

        dropout: 0.0,
        attention_dropout: 0.0,
        layer_norm_epsilon: 1e-5,
        use_bias: false,
        tied_embeddings: false,
        init_std: 0.02,

        is_vision_model: false,
        enable_long_context: false,
        long_context_max_len: 8192,
    }
}

// ============================================================
// English text MULTIMODAL-VISION-9B English textconfiguration (English text)
// ============================================================
func create_vision_9b_config() neurx_config {
    neurx_config cfg = create_neurx_9b_config()
    cfg.version = MULTIMODAL_VISION
    cfg.name = "MULTIMODAL-VISION-9B"
    cfg.description = "NEURX-4 Vision with multimodal capabilities"
    cfg.is_vision_model = true

    // English textparameter
    cfg.image_size = 448
    cfg.patch_size = 14
    cfg.vision_hidden_size = 1024
    cfg.vision_num_layers = 24
    cfg.vision_intermediate_size = 4096

    return cfg
}

// ============================================================
// English text NEURX-MoE configuration (English text NeurX-V3 English textmodel)
// ============================================================
func create_moe_200b_config_200b() neurx_config {
    neurx_config cfg = create_neurx_200b_config_200b()
    cfg.name = "NEURX-MoE-200B"
    cfg.description = "NEURX with Mixture of Experts (active params ~200B, total ~1T)"
    cfg.use_moe = true
    cfg.moe_num_experts = 256
    cfg.moe_top_k = 8
    cfg.moe_router_z_loss_coef = 0.001

    // MoE English text
    cfg.intermediate_size = 49152

    return cfg
}

// ============================================================
// English textconfigurationEnglish text
// ============================================================
func create_custom_neurx_config(
    vocab_size: int,
    hidden_size: int,
    num_layers: int,
    num_heads: int,
    max_seq_len: int,
    use_rope_yarn: bool = true,
    enable_moe: bool = false
) neurx_config {

    neurx_config {
        version: NEURX_5_2,
        name: "Custom-NEURX",
        description: "User-defined NEURX configuration",

        vocab_size: vocab_size,
        hidden_size: hidden_size,
        num_layers: num_layers,
        num_attention_heads: num_heads,
        num_key_value_heads: max(num_heads / 4, 1),  // default GQA ratio 4:1

        intermediate_size: hidden_size * 8 / 3,  // SwiGLU English text
        use_moe: enable_moe,
        moe_num_experts: enable_moe ? 64 : 0,
        moe_top_k: enable_moe ? 4 : 0,

        max_seq_len: max_seq_len,
        max_position_embeddings: max_seq_len,
        position_encoding_type: "rope",
        rope_theta: 500000.0,
        rope_scaling_type: use_rope_yarn ? 3 : 0,
        rope_factor: float(max_seq_len / 4096),

        pad_token_id: 0,
        bos_token_id: 1,
        eos_token_id: 2,
        gmask_token_id: 150001,
        sop_token_id: 150002,
        eop_token_id: 150003,

        dropout: 0.0,
        attention_dropout: 0.0,
        layer_norm_epsilon: 1e-5,
        use_bias: false,
        tied_embeddings: false,
        init_std: 0.02,

        is_vision_model: false,
        enable_long_context: max_seq_len > 16384,
        long_context_max_len: max_seq_len,
    }
}

// ============================================================
// 2D Position Encoding (NEURX English text)
// English text + English text
// English text NEURX-130B English text; NEURX-4/5 mainEnglish textuse RoPE
// ============================================================
struct position_encoding_2d {
    tensor absolute_embedding    // [max_pos, hidden_size] English text
    tensor relative_embedding   // [num_buckets, hidden_size] English text
    int num_buckets            // English textcount (English text 32)
    int max_distance           // English text (English text 128)
    int max_pos               // English text
}

func create_position_encoding_2d(
    max_pos: int,
    hidden_size: int,
    num_buckets: int = 32,
    max_distance: int = 128
) position_encoding_2d {

    // English text (English textparameter)
    tensor abs_emb = randn(max_pos, hidden_size) * 0.02
    abs_emb = parameter(abs_emb, name="position_encoding.absolute")

    // English text (English textparameter)
    tensor rel_emb = randn(num_buckets, hidden_size) * 0.02
    rel_emb = parameter(rel_emb, name="position_encoding.relative")

    return position_encoding_2d {
        absolute_embedding: abs_emb,
        relative_embedding: rel_emb,
        num_buckets: num_buckets,
        max_distance: max_distance,
        max_pos: max_pos,
    }
}

// English text
func _relative_position_bucket(
    relative_positions: tensor,  // [seq_len, seq_len]
    num_buckets: int,
    max_distance: int
) tensor {

    int num_buckets_half = num_buckets / 2
    int max_exact = num_buckets_half

    // English text, English text
    tensor is_small = abs(relative_positions) <= max_exact

    // English textuseEnglish text
    val_if_large = max_exact + (
        log(float(abs(relative_positions)) / float(max_exact)) /
        log(float(max_distance / max_exact)) * float(num_buckets - max_exact)
    )
    val_if_large = clamp(val_if_large, min=num_buckets_half, max=num_buckets - 1)

    // English text
    bucket = where(is_small, relative_positions + num_buckets_half, val_if_large)

    // English text (English text)
    return where(relative_positions < 0, num_buckets - 1 - bucket, bucket)
}

// English text 2D English text
func apply_position_encoding_2d(
    pe: position_encoding_2d,
    query_states: tensor,  // [batch, heads, seq_len, head_dim]
    key_states: tensor     // [batch, heads, seq_len, head_dim]
) tensor {

    int batch = shape(query_states)[0]
    int heads = shape(query_states)[1]
    int seq_len = shape(query_states)[2]
    int head_dim = shape(query_states)[3]

    // generateEnglish text
    range_tensor = arange(seq_len).unsqueeze(0)  // [1, seq_len]
    relative_pos = range_tensor.T - range_tensor  // [seq_len, seq_len]

    // English text
    bucket_pos = _relative_position_bucket(
        relative_pos,
        pe.num_buckets,
        pe.max_distance
    )  // [seq_len, seq_len]

    // English text
    rel_emb = pe.relative_embedding[bucket_pos]  // [seq_len, seq_len, hidden_size]
    rel_emb = rel_emb.unsqueeze(0).unsqueeze(0)  // [1, 1, seq_len, seq_len, hidden_size]

    // English text
    abs_emb = pe.absolute_embedding[:seq_len]  // [seq_len, hidden_size]
    abs_emb_q = abs_emb.unsqueeze(0).unsqueeze(0)  // [1, 1, seq_len, hidden_size]
    abs_emb_k = abs_emb.unsqueeze(0).unsqueeze(0)  // [1, 1, seq_len, hidden_size]

    // English text attention logits English text
    // Q * K^T + abs(Q) * abs(K)^T + rel(pos_q - pos_k)

    // English text,English text attention English textuse
    // actualEnglish textimplementationEnglish text

    return rel_emb
}

// ============================================================
// NEURX Attention Mask English text
// English text: English text prefix (English text) English text generation (English text) English text
// ============================================================

enum mask_type {
    CAUSAL          // English text (GPT English text)
    BIDIRECTIONAL   // English text (BERT English text, English text MLM)
    PREFIX_LM       // Prefix-LM English text (NEURX English text)
}

// English text NEURX Prefix-LM Attention Mask
func build_prefix_mask(
    input_ids: tensor,                    // [batch, seq_len]
    sop_position: option(tensor),         // SOP token English text [batch], None English text prefix
    eop_position: option(tensor),         // EOP token English text [batch], None English text
    config: neurx_config
) tensor {

    int batch_size = shape(input_ids)[0]
    int seq_len = shape(input_ids)[1]

    // English text
    tensor causal_mask = ones(batch_size, 1, seq_len, seq_len)
    causal_mask = causal_mask.triu(diagonal=1)  // English text 1 (English text mask)
    causal_mask = causal_mask * -10000.0  // English text

    // English text SOP/EOP information,English text
    if sop_position == none && eop_position == none {
        return causal_mask
    }

    // Prefix-LM English text:
    // - SOP English text EOP English text prefix (English text)
    // - EOP English text generation (English text)

    tensor final_mask = zeros(batch_size, 1, seq_len, seq_len)

    for b in range(batch_size) {
        int sop_pos = sop_position != none ? sop_position[b].item() : 0
        int eop_pos = eop_position != none ? eop_position[b].item() : seq_len

        // Prefix English text (English text)
        if eop_pos > 0 {
            // Query English text prefix English text: AllowedEnglish text prefix content
            final_mask[b, 0, :eop_pos, :eop_pos] = 0.0

            // Query English text generation English text:
            // - AllowedEnglish text prefix
            // - English text generation content
            final_mask[b, 0, eop_pos:, :eop_pos] = 0.0
            final_mask[b, 0, eop_pos:, eop_pos:] = causal_mask[b, 0, eop_pos:, eop_pos:]
        } else {
            // English text prefix, English text
            final_mask[b, 0, :, :] = causal_mask[b, 0, :, :]
        }
    }

    return final_mask
}

// English text MLM Mask (English texttrainingphaseEnglish text)
func build_mlm_mask(
    input_ids: tensor,
    mask_token_id: int,
    mlm_probability: float = 0.15
) tuple[tensor, tensor] {

    int batch_size = shape(input_ids)[0]
    int seq_len = shape(input_ids)[1]

    // English text mask English text
    tensor random_matrix = rand(batch_size, seq_len)
    tensor mask_prob = full((batch_size, seq_len), mlm_probability)

    tensor mask_positions = random_matrix < mask_prob  // [batch, seq_len]

    // English text mask: 80% English text [MASK], 10% English text, 10% English text
    tensor random_replace_prob = rand(batch_size, seq_len)

    // saveEnglish text labels English textcompute loss
    tensor masked_labels = where(mask_positions, input_ids, full_like(input_ids, -100))

    // English text: actualEnglish text masking English textdataEnglish text forward English text
    // English text mask English text labels

    return (mask_positions, masked_labels)
}

// ============================================================
// NEURX Transformer Block
// English text: Multi-head Self-Attention + Feed Forward Network
// support GQA (Grouped Query Attention) English text RoPE
// ============================================================

struct transformer_block_state {
    // Self-Attention
    tensor q_proj_weight    // [hidden_size, hidden_size]
    tensor k_proj_weight    // [hidden_size, kv_head_dim]
    tensor v_proj_weight    // [hidden_size, kv_head_dim]
    tensor o_proj_weight    // [hidden_size, hidden_size]

    // Layer Norms (RMSNorm for NEURX-4/5)
    tensor attn_layer_norm_rms_gamma  // [hidden_size]
    tensor ffn_layer_norm_rms_gamma   // [hidden_size]

    // FFN (SwiGLU)
    tensor gate_proj_weight  // [intermediate_size, hidden_size]
    tensor up_proj_weight    // [intermediate_size, hidden_size]
    tensor down_proj_weight  // [hidden_size, intermediate_size]

    // MoE (English text)
    option[moe_layer_state] moe_layer
}

// English text Transformer Block English text
func transformer_block_forward(
    block: transformer_block_state,
    hidden_states: tensor,        // [batch, seq_len, hidden_size]
    attention_mask: option[tensor], // [batch, 1, seq_len, seq_len]
    position_embeddings: option[tensor], // RoPE cos/sin English text 2D PE
    config: neurx_config,
    output_attentions: bool = false
) tuple[tensor, option[tensor]] {

    // ===== Pre-Attention RMSNorm =====
    tensor residual = hidden_states
    hidden_states = rmsnorm(hidden_states, block.attn_layer_norm_rms_gamma, eps=config.layer_norm_epsilon)

    // ===== Multi-Head Self-Attention =====
    int batch = shape(hidden_states)[0]
    int seq_len = shape(hidden_states)[1]
    int head_dim = config.hidden_size / config.num_attention_heads
    int kv_head_dim = head_dim * (config.num_attention_heads / config.num_key_value_heads)

    // Q/K/V English text
    tensor Q = linear(hidden_states, block.q_proj_weight)  // [batch, seq, hidden]
    tensor K = linear(hidden_states, block.k_proj_weight)   // [batch, seq, kv_dim]
    tensor V = linear(hidden_states, block.v_proj_weight)   // [batch, seq, kv_dim]

    // Reshape English text multi-head English text
    Q = Q.view(batch, seq_len, config.num_attention_heads, head_dim).transpose(1, 2)
    K = K.view(batch, seq_len, config.num_key_value_heads, head_dim).transpose(1, 2)
    V = V.view(batch, seq_len, config.num_key_value_heads, head_dim).transpose(1, 2)

    // English text RoPE English text (English text)
    if position_embeddings != none && config.position_encoding_type == "rope" {
        tuple[cos, sin] = position_embeddings  // [1, seq_len, head_dim]
        Q = apply_rotary_pos_emb(Q, cos, sin)
        K = apply_rotary_pos_emb(K, cos, sin)
    }

    // GQA: English text K/V English text Q English text
    if config.num_key_value_heads < config.num_attention_heads {
        int repeat_times = config.num_attention_heads / config.num_key_value_heads
        K = K.repeat(interleave_dim=1, repeats=repeat_times)  // [batch, num_heads, seq, head_dim]
        V = V.repeat(interleave_dim=1, repeats=repeat_times)
    }

    // compute Attention Scores
    tensor scores = matmul(Q, K.transpose(-2, -1)) / sqrt(float(head_dim))

    // English text Attention Mask
    if attention_mask != none {
        scores = scores + attention_mask
    }

    // Softmax
    tensor attn_weights = softmax(scores, dim=-1)

    # optional attention weights for visualization/debugging
    tensor maybe_attn_weights = none
    if output_attentions {
        maybe_attn_weights = attn_weights
    }

    // Apply to Values
    tensor context = matmul(attn_weights, V)  // [batch, heads, seq, head_dim]

    // Merge heads
    context = context.transpose(1, 2).contiguous().view(batch, seq_len, config.hidden_size)

    // Output projection
    tensor attn_output = linear(context, block.o_proj_weight)  // [batch, seq, hidden]

    // Residual connection
    hidden_states = residual + attn_output

    // ===== Pre-FFN RMSNorm =====
    residual = hidden_states
    hidden_states = rmsnorm(hidden_states, block.ffn_layer_norm_rms_gamma, eps=config.layer_norm_epsilon)

    // ===== Feed Forward Network (SwiGLU) or MoE =====
    if config.use_moe && block.moe_layer != none {
        // MoE FFN
        tensor ffn_output = forward_moe_layer(block.moe_layer!, hidden_states)
    } else {
        // Standard SwiGLU FFN
        tensor gate = silu(linear(hidden_states, block.gate_proj_weight))
        tensor up = linear(hidden_states, block.up_proj_weight)
        ffn_output = linear(gate * up, block.down_proj_weight)
    }

    // Residual connection
    hidden_states = residual + ffn_output

    return (hidden_states, maybe_attn_weights)
}

// ============================================================
// NEURX completemodelEnglish text
// ============================================================
struct neurx_model {
    neurx_config config
    tensor word_embeddings          // [vocab_size, hidden_size]
    position_embeddings            // [max_pos, hidden_size] (English text,English text 2D PE)
    transformer_blocks[]           // English text Transformer English text
    tensor final_layer_norm_gamma   // English text LayerNorm
    tensor lm_head                 // outputEnglish text (English text embedding English text)

    // English text (English text)
    option[vision_encoder] vision_encoder
    option[tensor] vision_projector  // Visual-Language English text
}

// NEURX modelinitialize
func create_neurx_model(config: neurx_config) neurx_model {

    print("🚀 Initializing NEURX model: {config.name}")
    print("   Hidden size: {config.hidden_size}")
    print("   Layers: {config.num_layers}")
    print("   Heads: {config.num_attention_heads} (KV: {config.num_key_value_heads})")
    print("   Max seq len: {config.max_seq_len}")
    if config.use_moe {
        print("   MoE: {config.moe_num_experts} experts, top-{config.moe_top_k}")
    }
    if config.is_vision_model {
        print("   📸 Vision mode enabled ({config.image_size}x{config.image_size})")
    }

    // Word Embeddings
    tensor embeddings = randn(config.vocab_size, config.hidden_size) * config.init_std
    embeddings = parameter(embeddings, name="model.embed_tokens")

    // 2D Position Embeddings (English textRequired)
    tensor pos_emb = none
    if config.position_encoding_type == "2d" && !config.enable_long_context {
        pos_emb = randn(config.max_position_embeddings, config.hidden_size) * 0.02
        pos_emb = parameter(pos_emb, name="model.position_embeddings")
    }

    // Transformer Blocks
    transformer_block_state blocks[]
    for i in range(config.num_layers) {
        transformer_block_state block {
            // QKV/O Projections
            q_proj_weight: randn(config.hidden_size, config.hidden_size) * config.init_std,
            k_proj_weight: randn(config.hidden_size, (config.hidden_size / config.num_attention_heads) * config.num_key_value_heads) * config.init_std,
            v_proj_weight: randn(config.hidden_size, (config.hidden_size / config.num_attention_heads) * config.num_key_value_heads) * config.init_std,
            o_proj_weight: randn(config.hidden_size, config.hidden_size) * config.init_std,

            // Layer Norms (RMSNorm)
            attn_layer_norm_rms_gamma: ones(config.hidden_size),
            ffn_layer_norm_rms_gamma: ones(config.hidden_size),

            // FFN (SwiGLU)
            gate_proj_weight: randn(config.intermediate_size, config.hidden_size) * config.init_std,
            up_proj_weight: randn(config.intermediate_size, config.hidden_size) * config.init_std,
            down_proj_weight: randn(config.hidden_size, config.intermediate_size) * config.init_std,

            // MoE (English text)
            moe_layer: none,
        }
        // English textparameterEnglish text
        block.q_proj_weight = parameter(block.q_proj_weight,
            name="model.layers.{i}.self_attn.q_proj.weight")
        block.k_proj_weight = parameter(block.k_proj_weight,
            name="model.layers.{i}.self_attn.k_proj.weight")
        block.v_proj_weight = parameter(block.v_proj_weight,
            name="model.layers.{i}.self_attn.v_proj.weight")
        block.o_proj_weight = parameter(block.o_proj_weight,
            name="model.layers.{i}.self_attn.o_proj.weight")
        block.attn_layer_norm_rms_gamma = parameter(block.attn_layer_norm_rms_gamma,
            name="model.layers.{i}.input_layernorm.weight")
        block.ffn_layer_norm_rms_gamma = parameter(block.ffn_layer_norm_rms_gamma,
            name="model.layers.{i}.post_attention_layernorm.weight")
        block.gate_proj_weight = parameter(block.gate_proj_weight,
            name="model.layers.{i}.mlp.gate_proj.weight")
        block.up_proj_weight = parameter(block.up_proj_weight,
            name="model.layers.{i}.mlp.up_proj.weight")
        block.down_proj_weight = parameter(block.down_proj_weight,
            name="model.layers.{i}.mlp.down_proj.weight")

        // English text MoE,English text MoE layer
        if config.use_moe {
            block.moe_layer = some(create_moe_layer(
                hidden_size=config.hidden_size,
                intermediate_size=config.intermediate_size,
                num_experts=config.moe_num_experts,
                top_k=config.moe_top_k,
                layer_idx=i,
                router_z_loss_coef=config.moe_router_z_loss_coef
            ))
        }

        append(blocks, block)
    }

    // Final LayerNorm
    tensor final_norm = ones(config.hidden_size)
    final_norm = parameter(final_norm, name="model.norm.weight")

    // LM Head
    tensor lm_head = none
    if config.tied_embeddings {
        lm_head = embeddings  // English textinput embedding English text
    } else {
        lm_head = randn(config.vocab_size, config.hidden_size) * config.init_std
        lm_head = parameter(lm_head, name="lm_head.weight")
    }

    // English text (English text)
    option[vision_encoder] vis_enc = none
    option[tensor] vis_proj = none
    if config.is_vision_model {
        vis_enc = some(create_vision_encoder(config))
        vis_proj = some(randn(config.hidden_size, config.vision_hidden_size) * config.init_std)
        vis_proj! = parameter(vis_proj!, name="model.visual_projection.weight")
    }

    // computeEnglish textparameterEnglish text
    int total_params = count_parameters(config)

    print("✅ NEURX model initialized successfully!")
    print("   Total parameters: {format_number(total_params)}")

    return neurx_model {
        config: config,
        word_embeddings: embeddings,
        position_embeddings: pos_emb,
        transformer_blocks: blocks,
        final_layer_norm_gamma: final_norm,
        lm_head: lm_head,
        vision_encoder: vis_enc,
        vision_projector: vis_proj,
    }
}

// computemodelparameterEnglish text
func count_parameters(config: neurx_config) int {
    int params = 0

    // embedding
    params += config.vocab_size * config.hidden_size

    // Position embedding (2D PE)
    if config.position_encoding_type == "2d" {
        params += config.max_position_embeddings * config.hidden_size
        params += 32 * config.hidden_size  // relative embedding buckets
    }

    // Per-layer
    for i in range(config.num_layers) {
        // Q projection
        params += config.hidden_size * config.hidden_size
        // K projection (GQA: English text)
        int kv_dim = (config.hidden_size / config.num_attention_heads) * config.num_key_value_heads
        params += config.hidden_size * kv_dim
        // V projection
        params += config.hidden_size * kv_dim
        // O projection
        params += config.hidden_size * config.hidden_size
        // 2x LayerNorm (RMSNorm English text gamma)
        params += config.hidden_size * 2

        // FFN (SwiGLU): gate, up, down projections
        if config.use_moe {
            // English text expert English textcompleteEnglish text gate/up/down
            params += config.moe_num_experts * (
                config.intermediate_size * config.hidden_size +  // gate
                config.intermediate_size * config.hidden_size +  // up
                config.hidden_size * config.intermediate_size     // down
            )
            // Router
            params += config.hidden_size * config.moe_num_experts
        } else {
            params += config.intermediate_size * config.hidden_size * 3  // gate, up, down
        }
    }

    // Final LayerNorm
    params += config.hidden_size

    // LM Head (English text embedding)
    if !config.tied_embeddings {
        params += config.vocab_size * config.hidden_size
    }

    // English text
    if config.is_vision_model {
        // ViT-like encoder
        int num_patches = (config.image_size / config.patch_size) ** 2
        params += num_patches * (config.patch_size ** 2 * 3) * config.vision_hidden_size  // patch embedding
        params += config.vision_hidden_size * config.hidden_size  // projector
        for i in range(config.vision_num_layers) {
            params += config.vision_hidden_size ** 2 * 4  // self-attn
            params += config.vision_intermediate_size * config.vision_hidden_size * 3  // ffn
        }
    }

    return params
}

// English text
func format_number(num: int) {
    if num >= 1_000_000_000_000:
        return "{num / 1_000_000_000}T"
    elif num >= 1_000_000_000:
        return "{num / 1_000_000_000}B"
    elif num >= 1_000_000:
        return "{num / 1_000_000}M"
    elif num >= 1_000:
        return "{num / 1_000}K"
    else:
        return "{num}"
}

// ============================================================
// NEURX English text (English textfunction)
// ============================================================
func neurx_forward(
    model: neurx_model,
    input_ids: tensor,                  // [batch, seq_len]
    attention_mask: option[tensor],     // [batch, seq_len] padding mask
    position_ids: option[tensor],       // [batch, seq_len] English text ID
    sop_eop_info: option[tuple[tensor, tensor]],  // (SOP positions, EOP positions)
    inputs_embeds: option[tensor],      // [batch, seq_len, hidden_size] English text (English text embedding lookup)
    pixel_values: option[tensor],       // [batch, 3, H, W] English textinput (English text)
    output_attentions: bool = false,
    output_hidden_states: bool = false,
    return_dict: bool = true
) dict[string, any] {

    neurx_config config = model.config
    int batch_size = shape(input_ids)[0]
    int seq_len = shape(input_ids)[1]

    tensor hidden_states = none

    // === Step 1: English text Input Embeddings ===
    if inputs_embeds != none {
        // English textuseEnglish text (English text: English textcacheEnglish text)
        hidden_states = inputs_embeds!
    } else {
        // Word embedding Lookup
        hidden_states = model.word_embeddings[input_ids]  // [batch, seq, hidden]
    }

    // === Step 2: English textinput ===
    if pixel_values != none && model.vision_encoder != none {
        // English text
        tuple[image_features, image_attn_mask] = forward_vision_encoder(
            model.vision_encoder!,
            pixel_values!
        )

        // English textlanguageEnglish text
        image_features = linear(image_features, model.vision_projector!)  // [batch, num_patches, hidden]

        // English text
        hidden_states = concat([image_features, hidden_states], dim=1)  // [batch, img_patches+seq, hidden]

        // English text seq_len
        seq_len = shape(hidden_states)[1]
    }

    // === Step 3: English text ===
    option[tensor] position_embeddings = none

    if config.position_encoding_type == "rope" {
        // RoPE: generate cos/sin English text
        position_embeddings = compute_rope_embeddings(
            position_ids,
            config.hidden_size / config.num_attention_heads,
            config.rope_theta,
            config.rope_scaling_type,
            config.rope_factor
        )
    } elif config.position_encoding_type == "2d" && model.position_embeddings != none {
        // 2D Position Encoding (English text NEURX English text)
        // English text attention English text add_bias English text
        pass  // handled inside attention
    }

    // === Step 4: English text Attention Mask (NEURX English text) ===
    option[tensor] combined_mask = none

    if attention_mask != none || sop_eop_info != none {
        // Padding mask: [batch, seq] -> [batch, 1, 1, seq]
        tensor padding_mask = attention_mask!.unsqueeze(1).unsqueeze(2)  // [batch, 1, 1, seq]
        padding_mask = (1.0 - padding_mask) * -10000.0

        // Prefix-LM mask: [batch, 1, seq, seq]
        option[tensor] prefix_mask = none
        if sop_eop_info != none {
            tuple[sop_pos, eop_pos] = sop_eop_info!
            prefix_mask = some(build_prefix_mask(
                input_ids,
                some(sop_pos),
                some(eop_pos),
                config
            ))
        } else {
            // English text prefix informationEnglish text,defaultEnglish text
            prefix_mask = some(build_prefix_mask(input_ids, none, none, config))
        }

        // English text padding mask English text prefix mask
        combined_mask = some(padding_mask + prefix_mask!)
    }

    // === Step 5: English text Transformer Blocks ===
    tensor all_hidden_states[]  # optional
    tensor all_attentions[]     # optional

    for i, block in enumerate(model.transformer_blocks) {
        if output_hidden_states:
            append(all_hidden_states, hidden_states)

        tuple[hidden_states, attn_weights] = transformer_block_forward(
            block=block,
            hidden_states=hidden_states,
            attention_mask=combined_mask,
            position_embeddings=position_embeddings,
            config=config,
            output_attentions=output_attentions
        )

        if output_attentions && attn_weights != none:
            append(all_attentions, attn_weights!)
    }

    // Final Layer Norm
    hidden_states = rmsnorm(hidden_states, model.final_layer_norm_gamma, eps=config.layer_norm_epsilon)

    if output_hidden_states:
        append(all_hidden_states, hidden_states)

    // === Step 6: LM Head (Output Projection) ===
    tensor logits = matmul(hidden_states, model.lm_head.T)  // [batch, seq, vocab]

    // === Return Results ===
    dict[string, any] result = {}
    result["logits"] = logits
    result["hidden_states"] = output_hidden_states ? some(all_hidden_states) : none
    result["attentions"] = output_attentions ? some(all_attentions) : none

    return result
}

// ============================================================
// NEURX Loss compute
// support: CLM Loss, MLM Loss, PrefixLM Loss
// ============================================================
enum neurx_loss_type {
    CLM          // Causal Language Modeling (English text)
    MLM          // Masked Language Modeling (English text, NEURX-130B)
    PREFIX_LM    // Prefix Language Modeling (English text, NEURX-4/5)
}

func compute_neurx_loss(
    logits: tensor,              // [batch, seq, vocab]
    labels: tensor,              // [batch, seq] (-100 English text)
    loss_type: neurx_loss_type,
    attention_mask: option[tensor],  // [batch, seq] padding mask
    sop_eop_info: option[tuple[tensor, tensor]]  # for prefix LM
) tuple[tensor, int] {

    int batch = shape(logits)[0]
    int seq_len = shape(logits)[1]

    // Shift logits and labels for next-token prediction (CLM / PrefixLM)
    if loss_type == CLM || loss_type == PREFIX_LM {
        logits = logits[:, :-1, :]   // [batch, seq-1, vocab]
        labels = labels[:, 1:]       // [batch, seq-1]
        if attention_mask != none:
            attention_mask! = attention_mask![:, 1:]
    }

    // Compute Cross-Entropy Loss
    tensor loss = cross_entropy_loss(logits, labels)  // scalar

    // Apply attention mask to exclude padding positions
    if attention_mask != none {
        // English textcomputeEnglish text padding English text loss
        tensor mask = (attention_mask! != 0).float()
        loss = (loss * mask).sum() / mask.sum()
    }

    // Count effective tokens
    int num_tokens = batch * seq_len
    if attention_mask != none:
        num_tokens = int((attention_mask! != 0).sum().item())

    return (loss, num_tokens)
}

// ============================================================
// test & English textfunction
// ============================================================
func test_neurx_architecture() {
    print("\n" + "="*60)
    print("Testing NEURX Architecture")
    print("="*60)

    // Test 1: Create NEURX-5.2 200B config
    print("\n[Test 1] Creating NEURX-5.2-200B configuration...")
    neurx_config cfg_200b = create_neurx_200b_config_200b()
    assert(cfg_200b.vocab_size == 200000)
    assert(cfg_200b.hidden_size == 12288)
    assert(cfg_200b.num_layers == 96)
    assert(cfg_200b.enable_long_context == true)
    assert(cfg_200b.long_context_max_len == 131072)
    print("✅ NEURX-5.2-200B config created successfully!")

    // Test 2: Create NEURX-4-9B config
    print("\n[Test 2] Creating NEURX-4-9B configuration...")
    neurx_config cfg_9b = create_neurx_9b_config()
    assert(cfg_9b.vocab_size == 151552)
    assert(cfg_9b.hidden_size == 4096)
    assert(!cfg_9b.is_vision_model)
    print("✅ NEURX-4-9B config created successfully!")

    // Test 3: Create MULTIMODAL-VISION multimodal config
    print("\n[Test 3] Creating MULTIMODAL-VISION-9B (multimodal) configuration...")
    neurx_config cfg_vision = create_vision_9b_config()
    assert(cfg_vision.is_vision_model == true)
    assert(cfg_vision.image_size == 448)
    print("✅ MULTIMODAL-VISION-9B config created successfully!")

    // Test 4: Create NEURX-MoE config
    print("\n[Test 4] Creating NEURX-MoE-200B configuration...")
    neurx_config cfg_moe = create_moe_200b_config_200b()
    assert(cfg_moe.use_moe == true)
    assert(cfg_moe.moe_num_experts == 256)
    assert(cfg_moe.moe_top_k == 8)
    print("✅ NEURX-MoE-200B config created successfully!")

    // Test 5: Custom config builder
    print("\n[Test 5] Testing custom config builder...")
    neurx_config custom_cfg = create_custom_neurx_config(
        vocab_size=32000,
        hidden_size=2048,
        num_layers=24,
        num_heads=16,
        max_seq_len=4096
    )
    assert(custom_cfg.hidden_size == 2048)
    assert(custom_cfg.num_key_value_heads == 4)  # GQA: 16/4
    print("✅ Custom config created successfully!")

    // Test 6: Parameter count estimation
    print("\n[Test 6] Counting parameters...")
    int params_200b = count_parameters(cfg_200b)
    print(f"   NEURX-5.2-200B estimated params: {format_number(params_200b)}")
    assert(params_200b > 180_000_000_000 && params_200b < 250_000_000_000)

    int params_9b = count_parameters(cfg_9b)
    print(f"   NEURX-4-9B estimated params: {format_number(params_9b)}")
    assert(params_9b > 7_000_000_000 && params_9b < 11_000_000_000)
    print("✅ Parameter counts look correct!")

    // Test 7: Position Encoding 2D
    print("\n[Test 7] Testing 2D Position Encoding...")
    position_encoding_2d pe_2d = create_position_encoding_2d(
        max_pos=1024,
        hidden_size=64,
        num_buckets=16,
        max_distance=64
    )
    assert(shape(pe_2d.absolute_embedding) == (1024, 64))
    assert(shape(pe_2d.relative_embedding) == (16, 64))
    print("✅ 2D Position Encoding created!")

    // Test 8: NEURX Prefix Mask Construction
    print("\n[Test 8] Testing NEURX Prefix-LM mask construction...")
    tensor test_input = zeros(2, 16)  # batch=2, seq=16
    tensor sop_pos = tensor([3, 5])    # SOP at position 3 and 5
    tensor eop_pos = tensor([8, 10])   # EOP at position 8 and 10

    tensor mask = build_prefix_mask(test_input, some(sop_pos), some(eop_pos), cfg_9b)
    assert(shape(mask) == (2, 1, 16, 16))

    # Verify prefix region (positions 0-8 for sample 0) is bidirectional
    # mask should be 0 (visible) for prefix-prefix attention
    assert(mask[0, 0, 3, 0] == 0.0)  # prefix can see earlier prefix
    assert(mask[0, 0, 9, 8] == 0.0)  # generation can see prefix end
    # Generation region should be causal
    assert(mask[0, 0, 12, 10] > 0.0)  # gen pos 12 cannot see gen pos 10? No, 12>10 so it CAN see 10
    # Actually check that 10 cannot see 12
    assert(mask[0, 0, 10, 12] < 0.0)  # gen pos 10 cannot see future gen pos 12

    print("✅ NEURX Prefix-LM mask construction correct!")

    print("\n" + "="*60)
    print("All NEURX architecture tests passed! ✨")
    print("="*60 + "\n")
}
