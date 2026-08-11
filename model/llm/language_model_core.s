package neurx.model.llm.neurx
import neurx.model.transformer.*
import neurx.model.transformer.rope_scaling.*
import neurx.tensor.*
import neurx.nn.*
enum neurx_version {
    NEURX_130B
    NEURX_4_9B
    NEURX_4_34B
    MULTIMODAL_VISION
    NEURX_4_LONG
    NEURX_5_2
}
struct neurx_config {
    neurx_version version
    string name
    string description
    int vocab_size
    int hidden_size
    int num_layers
    int num_attention_heads
    int num_key_value_heads
    int intermediate_size
    bool use_moe
    int moe_num_experts
    int moe_top_k
    float moe_router_z_loss_coef
    int max_seq_len
    int max_position_embeddings
    string position_encoding_type
    float rope_theta
    int rope_scaling_type
    float rope_factor
    int pad_token_id
    int bos_token_id
    int eos_token_id
    int mask_token_id
    int gmask_token_id
    int sop_token_id
    int eop_token_id
    float dropout
    float attention_dropout
    float layer_norm_epsilon
    bool use_bias
    bool tied_embeddings
    float init_std
    bool is_vision_model
    int image_size
    int patch_size
    int vision_hidden_size
    int vision_num_layers
    int vision_intermediate_size
    bool enable_long_context
    int long_context_max_len
}

struct neurx_state {
    neurx_config config
    string model_path
    int total_parameters
    int training_step
    float training_loss
    float validation_loss
    bool is_loaded
    bool is_training
    struct stats {
        float avg_tokens_per_sec
        float peak_memory_mb
        int total_flops
    } stats
}

func create_neurx_200b_config_200b() neurx_config {
    neurx_config {
        version: NEURX_5_2,
        name: "NEURX-5.2-200B",
        description: "General Language model v5.2 with 200B parameters",
        vocab_size: 200000,
        hidden_size: 12288,
        num_layers: 96,
        num_attention_heads: 96,
        num_key_value_heads: 8,
        intermediate_size: 32768,
        use_moe: false,
        max_seq_len: 131072,
        max_position_embeddings: 131072,
        position_encoding_type: "rope",
        rope_theta: 500000.0,
        rope_scaling_type: 3,
        rope_factor: 32.0,
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
        enable_long_context: true,
        long_context_max_len: 131072,
    }
}

func create_neurx_9b_config() neurx_config {
    neurx_config {
        version: NEURX_4_9B,
        name: "NEURX-4-9B",
        description: "NEURX-4 with 9 billion parameters",
        vocab_size: 151552,
        hidden_size: 4096,
        num_layers: 40,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 13696,
        use_moe: false,
        max_seq_len: 8192,
        max_position_embeddings: 8192,
        position_encoding_type: "rope",
        rope_theta: 10000.0,
        rope_scaling_type: 1,
        rope_factor: 2.0,
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

func create_vision_9b_config() neurx_config {
    neurx_config cfg = create_neurx_9b_config()
    cfg.version = MULTIMODAL_VISION
    cfg.name = "MULTIMODAL-VISION-9B"
    cfg.description = "NEURX-4 Vision with multimodal capabilities"
    cfg.is_vision_model = true
    cfg.image_size = 448
    cfg.patch_size = 14
    cfg.vision_hidden_size = 1024
    cfg.vision_num_layers = 24
    cfg.vision_intermediate_size = 4096
    return cfg
}

func create_moe_200b_config_200b() neurx_config {
    neurx_config cfg = create_neurx_200b_config_200b()
    cfg.name = "NEURX-MoE-200B"
    cfg.description = "NEURX with Mixture of Experts (active params ~200B, total ~1T)"
    cfg.use_moe = true
    cfg.moe_num_experts = 256
    cfg.moe_top_k = 8
    cfg.moe_router_z_loss_coef = 0.001
    cfg.intermediate_size = 49152
    return cfg
}

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
        num_key_value_heads: max(num_heads / 4, 1),
        intermediate_size: hidden_size * 8 / 3,
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

struct position_encoding_2d {
    tensor absolute_embedding
    tensor relative_embedding
    int num_buckets
    int max_distance
    int max_pos
}

func create_position_encoding_2d(
    max_pos: int,
    hidden_size: int,
    num_buckets: int = 32,
    max_distance: int = 128
) position_encoding_2d {
    tensor abs_emb = randn(max_pos, hidden_size) * 0.02
    abs_emb = parameter(abs_emb, name="position_encoding.absolute")
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

func _relative_position_bucket(
    relative_positions: tensor,
    num_buckets: int,
    max_distance: int
) tensor {
    int num_buckets_half = num_buckets / 2
    int max_exact = num_buckets_half
    tensor is_small = abs(relative_positions) <= max_exact
    val_if_large = max_exact + (
        log(float(abs(relative_positions)) / float(max_exact)) /
        log(float(max_distance / max_exact)) * float(num_buckets - max_exact)
    )
    val_if_large = clamp(val_if_large, min=num_buckets_half, max=num_buckets - 1)
    bucket = where(is_small, relative_positions + num_buckets_half, val_if_large)
    return where(relative_positions < 0, num_buckets - 1 - bucket, bucket)
}

func apply_position_encoding_2d(
    pe: position_encoding_2d,
    query_states: tensor,
    key_states: tensor
) tensor {
    int batch = shape(query_states)[0]
    int heads = shape(query_states)[1]
    int seq_len = shape(query_states)[2]
    int head_dim = shape(query_states)[3]
    range_tensor = arange(seq_len).unsqueeze(0)
    relative_pos = range_tensor.T - range_tensor
    bucket_pos = _relative_position_bucket(
        relative_pos,
        pe.num_buckets,
        pe.max_distance
    )
    rel_emb = pe.relative_embedding[bucket_pos]
    rel_emb = rel_emb.unsqueeze(0).unsqueeze(0)
    abs_emb = pe.absolute_embedding[:seq_len]
    abs_emb_q = abs_emb.unsqueeze(0).unsqueeze(0)
    abs_emb_k = abs_emb.unsqueeze(0).unsqueeze(0)
    return rel_emb
}
enum mask_type {
    CAUSAL
    BIDIRECTIONAL
    PREFIX_LM
}

func build_prefix_mask(
    input_ids: tensor,
    sop_position: option(tensor),
    eop_position: option(tensor),
    config: neurx_config
) tensor {
    int batch_size = shape(input_ids)[0]
    int seq_len = shape(input_ids)[1]
    tensor causal_mask = ones(batch_size, 1, seq_len, seq_len)
    causal_mask = causal_mask.triu(diagonal=1)
    causal_mask = causal_mask * -10000.0
    if sop_position == none && eop_position == none {
        return causal_mask
    }
    tensor final_mask = zeros(batch_size, 1, seq_len, seq_len)
    for b in range(batch_size) {
        int sop_pos = sop_position != none ? sop_position[b].item() : 0
        int eop_pos = eop_position != none ? eop_position[b].item() : seq_len
        if eop_pos > 0 {
            final_mask[b, 0, :eop_pos, :eop_pos] = 0.0
            final_mask[b, 0, eop_pos:, :eop_pos] = 0.0
            final_mask[b, 0, eop_pos:, eop_pos:] = causal_mask[b, 0, eop_pos:, eop_pos:]
        } else {
            final_mask[b, 0, :, :] = causal_mask[b, 0, :, :]
        }
    }
    return final_mask
}

func build_mlm_mask(
    input_ids: tensor,
    mask_token_id: int,
    mlm_probability: float = 0.15
) tuple[tensor, tensor] {
    int batch_size = shape(input_ids)[0]
    int seq_len = shape(input_ids)[1]
    tensor random_matrix = rand(batch_size, seq_len)
    tensor mask_prob = full((batch_size, seq_len), mlm_probability)
    tensor mask_positions = random_matrix < mask_prob
    tensor random_replace_prob = rand(batch_size, seq_len)
    tensor masked_labels = where(mask_positions, input_ids, full_like(input_ids, -100))
    return (mask_positions, masked_labels)
}

struct transformer_block_state {
    tensor q_proj_weight
    tensor k_proj_weight
    tensor v_proj_weight
    tensor o_proj_weight
    tensor attn_layer_norm_rms_gamma
    tensor ffn_layer_norm_rms_gamma
    tensor gate_proj_weight
    tensor up_proj_weight
    tensor down_proj_weight
    option[moe_layer_state] moe_layer
}

func transformer_block_forward(
    block: transformer_block_state,
    hidden_states: tensor,
    attention_mask: option[tensor],
    position_embeddings: option[tensor],
    config: neurx_config,
    output_attentions: bool = false
) tuple[tensor, option[tensor]] {
    tensor residual = hidden_states
    hidden_states = rmsnorm(hidden_states, block.attn_layer_norm_rms_gamma, eps=config.layer_norm_epsilon)
    int batch = shape(hidden_states)[0]
    int seq_len = shape(hidden_states)[1]
    int head_dim = config.hidden_size / config.num_attention_heads
    int kv_head_dim = head_dim * (config.num_attention_heads / config.num_key_value_heads)
    tensor Q = linear(hidden_states, block.q_proj_weight)
    tensor K = linear(hidden_states, block.k_proj_weight)
    tensor V = linear(hidden_states, block.v_proj_weight)
    Q = Q.view(batch, seq_len, config.num_attention_heads, head_dim).transpose(1, 2)
    K = K.view(batch, seq_len, config.num_key_value_heads, head_dim).transpose(1, 2)
    V = V.view(batch, seq_len, config.num_key_value_heads, head_dim).transpose(1, 2)
    if position_embeddings != none && config.position_encoding_type == "rope" {
        tuple[cos, sin] = position_embeddings
        Q = apply_rotary_pos_emb(Q, cos, sin)
        K = apply_rotary_pos_emb(K, cos, sin)
    }
    if config.num_key_value_heads < config.num_attention_heads {
        int repeat_times = config.num_attention_heads / config.num_key_value_heads
        K = K.repeat(interleave_dim=1, repeats=repeat_times)
        V = V.repeat(interleave_dim=1, repeats=repeat_times)
    }
    tensor scores = matmul(Q, K.transpose(-2, -1)) / sqrt(float(head_dim))
    if attention_mask != none {
        scores = scores + attention_mask
    }
    tensor attn_weights = softmax(scores, dim=-1)
    tensor maybe_attn_weights = none
    if output_attentions {
        maybe_attn_weights = attn_weights
    }
    tensor context = matmul(attn_weights, V)
    context = context.transpose(1, 2).contiguous().view(batch, seq_len, config.hidden_size)
    tensor attn_output = linear(context, block.o_proj_weight)
    hidden_states = residual + attn_output
    residual = hidden_states
    hidden_states = rmsnorm(hidden_states, block.ffn_layer_norm_rms_gamma, eps=config.layer_norm_epsilon)
    if config.use_moe && block.moe_layer != none {
        tensor ffn_output = forward_moe_layer(block.moe_layer!, hidden_states)
    } else {
        tensor gate = silu(linear(hidden_states, block.gate_proj_weight))
        tensor up = linear(hidden_states, block.up_proj_weight)
        ffn_output = linear(gate * up, block.down_proj_weight)
    }
    hidden_states = residual + ffn_output
    return (hidden_states, maybe_attn_weights)
}

struct neurx_model {
    neurx_config config
    tensor word_embeddings
    position_embeddings
    transformer_blocks[]
    tensor final_layer_norm_gamma
    tensor lm_head
    option[vision_encoder] vision_encoder
    option[tensor] vision_projector
}

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
    tensor embeddings = randn(config.vocab_size, config.hidden_size) * config.init_std
    embeddings = parameter(embeddings, name="model.embed_tokens")
    tensor pos_emb = none
    if config.position_encoding_type == "2d" && !config.enable_long_context {
        pos_emb = randn(config.max_position_embeddings, config.hidden_size) * 0.02
        pos_emb = parameter(pos_emb, name="model.position_embeddings")
    }
    transformer_block_state blocks[]
    for i in range(config.num_layers) {
        transformer_block_state block {
            q_proj_weight: randn(config.hidden_size, config.hidden_size) * config.init_std,
            k_proj_weight: randn(config.hidden_size, (config.hidden_size / config.num_attention_heads) * config.num_key_value_heads) * config.init_std,
            v_proj_weight: randn(config.hidden_size, (config.hidden_size / config.num_attention_heads) * config.num_key_value_heads) * config.init_std,
            o_proj_weight: randn(config.hidden_size, config.hidden_size) * config.init_std,
            attn_layer_norm_rms_gamma: ones(config.hidden_size),
            ffn_layer_norm_rms_gamma: ones(config.hidden_size),
            gate_proj_weight: randn(config.intermediate_size, config.hidden_size) * config.init_std,
            up_proj_weight: randn(config.intermediate_size, config.hidden_size) * config.init_std,
            down_proj_weight: randn(config.hidden_size, config.intermediate_size) * config.init_std,
            moe_layer: none,
        }
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
    tensor final_norm = ones(config.hidden_size)
    final_norm = parameter(final_norm, name="model.norm.weight")
    tensor lm_head = none
    if config.tied_embeddings {
        lm_head = embeddings
    } else {
        lm_head = randn(config.vocab_size, config.hidden_size) * config.init_std
        lm_head = parameter(lm_head, name="lm_head.weight")
    }
    option[vision_encoder] vis_enc = none
    option[tensor] vis_proj = none
    if config.is_vision_model {
        vis_enc = some(create_vision_encoder(config))
        vis_proj = some(randn(config.hidden_size, config.vision_hidden_size) * config.init_std)
        vis_proj! = parameter(vis_proj!, name="model.visual_projection.weight")
    }
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

func count_parameters(config: neurx_config) int {
    int params = 0
    params += config.vocab_size * config.hidden_size
    if config.position_encoding_type == "2d" {
        params += config.max_position_embeddings * config.hidden_size
        params += 32 * config.hidden_size
    }
    for i in range(config.num_layers) {
        params += config.hidden_size * config.hidden_size
        int kv_dim = (config.hidden_size / config.num_attention_heads) * config.num_key_value_heads
        params += config.hidden_size * kv_dim
        params += config.hidden_size * kv_dim
        params += config.hidden_size * config.hidden_size
        params += config.hidden_size * 2
        if config.use_moe {
            params += config.moe_num_experts * (
                config.intermediate_size * config.hidden_size +
                config.intermediate_size * config.hidden_size +
                config.hidden_size * config.intermediate_size
            )
            params += config.hidden_size * config.moe_num_experts
        } else {
            params += config.intermediate_size * config.hidden_size * 3
        }
    }
    params += config.hidden_size
    if !config.tied_embeddings {
        params += config.vocab_size * config.hidden_size
    }
    if config.is_vision_model {
        int num_patches = (config.image_size / config.patch_size) ** 2
        params += num_patches * (config.patch_size ** 2 * 3) * config.vision_hidden_size
        params += config.vision_hidden_size * config.hidden_size
        for i in range(config.vision_num_layers) {
            params += config.vision_hidden_size ** 2 * 4
            params += config.vision_intermediate_size * config.vision_hidden_size * 3
        }
    }
    return params
}

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

func neurx_forward(
    model: neurx_model,
    input_ids: tensor,
    attention_mask: option[tensor],
    position_ids: option[tensor],
    sop_eop_info: option[tuple[tensor, tensor]],
    inputs_embeds: option[tensor],
    pixel_values: option[tensor],
    output_attentions: bool = false,
    output_hidden_states: bool = false,
    return_dict: bool = true
) dict[string, any] {
    neurx_config config = model.config
    int batch_size = shape(input_ids)[0]
    int seq_len = shape(input_ids)[1]
    tensor hidden_states = none
    if inputs_embeds != none {
        hidden_states = inputs_embeds!
    } else {
        hidden_states = model.word_embeddings[input_ids]
    }
    if pixel_values != none && model.vision_encoder != none {
        tuple[image_features, image_attn_mask] = forward_vision_encoder(
            model.vision_encoder!,
            pixel_values!
        )
        image_features = linear(image_features, model.vision_projector!)
        hidden_states = concat([image_features, hidden_states], dim=1)
        seq_len = shape(hidden_states)[1]
    }
    option[tensor] position_embeddings = none
    if config.position_encoding_type == "rope" {
        position_embeddings = compute_rope_embeddings(
            position_ids,
            config.hidden_size / config.num_attention_heads,
            config.rope_theta,
            config.rope_scaling_type,
            config.rope_factor
        )
    } elif config.position_encoding_type == "2d" && model.position_embeddings != none {
        pass
    }
    option[tensor] combined_mask = none
    if attention_mask != none || sop_eop_info != none {
        tensor padding_mask = attention_mask!.unsqueeze(1).unsqueeze(2)
        padding_mask = (1.0 - padding_mask) * -10000.0
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
            prefix_mask = some(build_prefix_mask(input_ids, none, none, config))
        }
        combined_mask = some(padding_mask + prefix_mask!)
    }
    tensor all_hidden_states[]
    tensor all_attentions[]
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
    hidden_states = rmsnorm(hidden_states, model.final_layer_norm_gamma, eps=config.layer_norm_epsilon)
    if output_hidden_states:
        append(all_hidden_states, hidden_states)
    tensor logits = matmul(hidden_states, model.lm_head.T)
    dict[string, any] result = {}
    result["logits"] = logits
    result["hidden_states"] = output_hidden_states ? some(all_hidden_states) : none
    result["attentions"] = output_attentions ? some(all_attentions) : none
    return result
}
enum neurx_loss_type {
    CLM
    MLM
    PREFIX_LM
}

func compute_neurx_loss(
    logits: tensor,
    labels: tensor,
    loss_type: neurx_loss_type,
    attention_mask: option[tensor],
    sop_eop_info: option[tuple[tensor, tensor]]
) tuple[tensor, int] {
    int batch = shape(logits)[0]
    int seq_len = shape(logits)[1]
    if loss_type == CLM || loss_type == PREFIX_LM {
        logits = logits[:, :-1, :]
        labels = labels[:, 1:]
        if attention_mask != none:
            attention_mask! = attention_mask![:, 1:]
    }
    tensor loss = cross_entropy_loss(logits, labels)
    if attention_mask != none {
        tensor mask = (attention_mask! != 0).float()
        loss = (loss * mask).sum() / mask.sum()
    }
    int num_tokens = batch * seq_len
    if attention_mask != none:
        num_tokens = int((attention_mask! != 0).sum().item())
    return (loss, num_tokens)
}

func test_neurx_architecture() {
    print("\n" + "="*60)
    print("Testing NEURX Architecture")
    print("="*60)
    print("\n[Test 1] Creating NEURX-5.2-200B configuration...")
    neurx_config cfg_200b = create_neurx_200b_config_200b()
    assert(cfg_200b.vocab_size == 200000)
    assert(cfg_200b.hidden_size == 12288)
    assert(cfg_200b.num_layers == 96)
    assert(cfg_200b.enable_long_context == true)
    assert(cfg_200b.long_context_max_len == 131072)
    print("✅ NEURX-5.2-200B config created successfully!")
    print("\n[Test 2] Creating NEURX-4-9B configuration...")
    neurx_config cfg_9b = create_neurx_9b_config()
    assert(cfg_9b.vocab_size == 151552)
    assert(cfg_9b.hidden_size == 4096)
    assert(!cfg_9b.is_vision_model)
    print("✅ NEURX-4-9B config created successfully!")
    print("\n[Test 3] Creating MULTIMODAL-VISION-9B (multimodal) configuration...")
    neurx_config cfg_vision = create_vision_9b_config()
    assert(cfg_vision.is_vision_model == true)
    assert(cfg_vision.image_size == 448)
    print("✅ MULTIMODAL-VISION-9B config created successfully!")
    print("\n[Test 4] Creating NEURX-MoE-200B configuration...")
    neurx_config cfg_moe = create_moe_200b_config_200b()
    assert(cfg_moe.use_moe == true)
    assert(cfg_moe.moe_num_experts == 256)
    assert(cfg_moe.moe_top_k == 8)
    print("✅ NEURX-MoE-200B config created successfully!")
    print("\n[Test 5] Testing custom config builder...")
    neurx_config custom_cfg = create_custom_neurx_config(
        vocab_size=32000,
        hidden_size=2048,
        num_layers=24,
        num_heads=16,
        max_seq_len=4096
    )
    assert(custom_cfg.hidden_size == 2048)
    assert(custom_cfg.num_key_value_heads == 4)
    print("✅ Custom config created successfully!")
    print("\n[Test 6] Counting parameters...")
    int params_200b = count_parameters(cfg_200b)
    print(f"   NEURX-5.2-200B estimated params: {format_number(params_200b)}")
    assert(params_200b > 180_000_000_000 && params_200b < 250_000_000_000)
    int params_9b = count_parameters(cfg_9b)
    print(f"   NEURX-4-9B estimated params: {format_number(params_9b)}")
    assert(params_9b > 7_000_000_000 && params_9b < 11_000_000_000)
    print("✅ Parameter counts look correct!")
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
    print("\n[Test 8] Testing NEURX Prefix-LM mask construction...")
    tensor test_input = zeros(2, 16)
    tensor sop_pos = tensor([3, 5])
    tensor eop_pos = tensor([8, 10])
    tensor mask = build_prefix_mask(test_input, some(sop_pos), some(eop_pos), cfg_9b)
    assert(shape(mask) == (2, 1, 16, 16))
    assert(mask[0, 0, 3, 0] == 0.0)
    assert(mask[0, 0, 9, 8] == 0.0)
    assert(mask[0, 0, 12, 10] > 0.0)
    assert(mask[0, 0, 10, 12] < 0.0)
    print("✅ NEURX Prefix-LM mask construction correct!")
    print("\n" + "="*60)
    print("All NEURX architecture tests passed! ✨")
    print("="*60 + "\n")
}
