package neurx.model.transformer.transformer

use neurx.model.transformer.attention.{attention_config, multi_head_attention, new_attention_config, new_multi_head_attention, forward_attention, forward_gqa, forward_mqa, forward_flash_attention}
use neurx.model.transformer.ffn.{ffn_config, feed_forward_network, new_ffn_config, new_standard_ffn, new_glu_ffn, new_moe_ffn, forward_standard_ffn, forward_glu_ffn, forward_swiglu_ffn, forward_moe_ffn}
use neurx.model.transformer.norm.{layer_norm_config, layer_norm, rms_norm, new_layer_norm, new_rms_norm, layer_normalize, rms_normalize, position_embedding_config, new_absolute_position_embedding, get_position_embedding, rope_embedding, new_rope_embedding, apply_rope, alibi_embedding, new_alibi_embedding, apply_alibi_bias}

struct transformer_layer_config {
    int hidden_dim
    int num_attention_heads
    int intermediate_dim
    int num_key_value_heads
    float attention_dropout
    float dropout_rate
    string activation_type
    string norm_type
    string position_embedding_type
    bool use_cache
    bool pre_norm
    bool tie_embeddings
}

struct transformer_layer {
    transformer_layer_config config
    attention_config attn_config
    ffn_config ffn_config
    multi_head_attention attn
    feed_forward_network ffn
    layer_norm ln1
    layer_norm ln2
    rms_norm rn1
    rms_norm rn2
    bool use_rmsnorm
}

struct transformer_config {
    int vocab_size
    int hidden_dim
    int num_layers
    int num_attention_heads
    int num_key_value_heads
    int intermediate_dim
    int max_seq_len
    float attention_dropout
    float dropout_rate
    string activation_type
    string norm_type
    string position_embedding_type
    bool use_cache
    bool pre_norm
    bool tie_embeddings
}

struct transformer_model {
    transformer_config config
    []transformer_layer layers
    int num_layers
    int vocab_size
    []float token_embedding
    []float lm_head_weight
}

struct transformer_output {
    []float logits
    []float hidden_states
}

func allocate_vector(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    while i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func copy_vector([]float src) []float {
    []float out = allocate_vector(len(src), 0.0)
    int i = 0
    while i < len(src) {
        out[i] = src[i]
        i = i + 1
    }
    out
}

func add_vectors([]float a, []float b) []float {
    []float out = copy_vector(a)
    int i = 0
    while i < len(out) {
        out[i] = out[i] + b[i]
        i = i + 1
    }
    out
}

func matmul_flat([]float a, []float b, int m, int k, int n) []float {
    []float result = allocate_vector(m * n, 0.0)
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

func fill_ramp(int size, float scale) []float {
    []float values = allocate_vector(size, 0.0)
    int i = 0
    while i < size {
        values[i] = scale * ((i + 1) * 1.0) / ((size + 1) * 1.0)
        i = i + 1
    }
    values
}

func new_transformer_layer_config() transformer_layer_config {
    transformer_layer_config {
        hidden_dim: 4096,
        num_attention_heads: 32,
        intermediate_dim: 11008,
        num_key_value_heads: 8,
        attention_dropout: 0.0,
        dropout_rate: 0.1,
        activation_type: "swiglu",
        norm_type: "rmsnorm",
        position_embedding_type: "rope",
        use_cache: false,
        pre_norm: true,
        tie_embeddings: true,
    }
}

func new_transformer_config() transformer_config {
    transformer_config {
        vocab_size: 50257,
        hidden_dim: 4096,
        num_layers: 32,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_dim: 11008,
        max_seq_len: 4096,
        attention_dropout: 0.0,
        dropout_rate: 0.1,
        activation_type: "swiglu",
        norm_type: "rmsnorm",
        position_embedding_type: "rope",
        use_cache: false,
        pre_norm: true,
        tie_embeddings: true,
    }
}

func new_transformer_layer(transformer_layer_config cfg) transformer_layer {
    attention_config attn_cfg = new_attention_config(cfg.hidden_dim, cfg.num_attention_heads, cfg.num_key_value_heads, cfg.position_embedding_type)
    attn_cfg.attention_dropout_rate = cfg.attention_dropout
    attn_cfg.use_cache = cfg.use_cache
    attn_cfg.use_flash_attention = cfg.position_embedding_type == "flash"

    ffn_config ffn_cfg = new_ffn_config(cfg.hidden_dim, cfg.intermediate_dim, cfg.activation_type, "standard")
    layer_norm_config ln_cfg = layer_norm_config {
        hidden_dim: cfg.hidden_dim,
        epsilon: 1e-5,
        use_bias: true,
        norm_type: cfg.norm_type,
    }

    transformer_layer {
        config: cfg,
        attn_config: attn_cfg,
        ffn_config: ffn_cfg,
        attn: new_multi_head_attention(attn_cfg),
        ffn: new_standard_ffn(ffn_cfg),
        ln1: new_layer_norm(ln_cfg),
        ln2: new_layer_norm(ln_cfg),
        rn1: new_rms_norm(ln_cfg),
        rn2: new_rms_norm(ln_cfg),
        use_rmsnorm: cfg.norm_type == "rmsnorm",
    }
}

func new_transformer_model(transformer_config cfg) transformer_model {
    []transformer_layer layers = []transformer_layer{cap: cfg.num_layers}
    int i = 0
    while i < cfg.num_layers {
        transformer_layer_config layer_cfg = new_transformer_layer_config()
        layer_cfg.hidden_dim = cfg.hidden_dim
        layer_cfg.num_attention_heads = cfg.num_attention_heads
        layer_cfg.num_key_value_heads = cfg.num_key_value_heads
        layer_cfg.intermediate_dim = cfg.intermediate_dim
        layer_cfg.attention_dropout = cfg.attention_dropout
        layer_cfg.dropout_rate = cfg.dropout_rate
        layer_cfg.activation_type = cfg.activation_type
        layer_cfg.norm_type = cfg.norm_type
        layer_cfg.position_embedding_type = cfg.position_embedding_type
        layer_cfg.use_cache = cfg.use_cache
        layer_cfg.pre_norm = cfg.pre_norm
        layer_cfg.tie_embeddings = cfg.tie_embeddings
        layers[i] = new_transformer_layer(layer_cfg)
        i = i + 1
    }

    int embed_size = cfg.vocab_size * cfg.hidden_dim
    transformer_model {
        config: cfg,
        layers: layers,
        num_layers: cfg.num_layers,
        vocab_size: cfg.vocab_size,
        token_embedding: fill_ramp(embed_size, 0.02),
        lm_head_weight: fill_ramp(embed_size, 0.02),
    }
}

func residual_add([]float a, []float b) []float {
    return add_vectors(a, b)
}

func apply_transformer_norm(transformer_layer layer, []float hidden_states, int batch_size, int seq_len) []float {
    if layer.use_rmsnorm {
        return rms_normalize(layer.rn1, hidden_states, batch_size, seq_len)
    }
    return layer_normalize(layer.ln1, hidden_states, batch_size, seq_len)
}

func apply_transformer_norm2(transformer_layer layer, []float hidden_states, int batch_size, int seq_len) []float {
    if layer.use_rmsnorm {
        return rms_normalize(layer.rn2, hidden_states, batch_size, seq_len)
    }
    return layer_normalize(layer.ln2, hidden_states, batch_size, seq_len)
}

func transformer_layer_at([]transformer_layer layers, int index) transformer_layer {
    transformer_layer value = layers[0]
    int i = 0
    while i < len(layers) {
        if i == index {
            value = layers[i]
        }
        i = i + 1
    }
    value
}

func forward_transformer_layer(
    transformer_layer layer,
    []float hidden_states,
    int batch_size,
    int seq_len
) []float {
    int hidden_dim = layer.config.hidden_dim
    []float x = copy_vector(hidden_states)
    []float attn_input = x
    if layer.config.pre_norm {
        attn_input = apply_transformer_norm(layer, x, batch_size, seq_len)
    }

    []float attn_output = forward_attention(layer.attn, attn_input, seq_len * batch_size)
    []float after_attn = residual_add(x, attn_output)
    if !layer.config.pre_norm {
        after_attn = apply_transformer_norm(layer, after_attn, batch_size, seq_len)
    }

    []float ffn_input = after_attn
    if layer.config.pre_norm {
        ffn_input = apply_transformer_norm2(layer, after_attn, batch_size, seq_len)
    }

    []float ffn_output
    if layer.config.activation_type == "gelu" {
        ffn_output = forward_standard_ffn(layer.ffn, ffn_input, batch_size * seq_len)
    } else if layer.config.activation_type == "swiglu" {
        ffn_output = forward_swiglu_ffn(layer.ffn, ffn_input, batch_size * seq_len)
    } else {
        ffn_output = forward_standard_ffn(layer.ffn, ffn_input, batch_size * seq_len)
    }

    []float out = residual_add(after_attn, ffn_output)
    if !layer.config.pre_norm {
        out = apply_transformer_norm2(layer, out, batch_size, seq_len)
    }
    out
}

func forward_transformer(
    transformer_model model,
    []float hidden_states,
    int batch_size,
    int seq_len
) transformer_output {
    int hidden_dim = model.config.hidden_dim
    []float x = copy_vector(hidden_states)

    if model.config.position_embedding_type == "absolute" {
        position_embedding_config pos_cfg = position_embedding_config {
            hidden_dim: hidden_dim,
            max_seq_len: model.config.max_seq_len,
            embed_type: "absolute",
            rope_base: 10000.0,
            use_flash_attention: false,
        }
        []float pos_embed = get_position_embedding(new_absolute_position_embedding(pos_cfg), hidden_dim, seq_len)
        x = add_vectors(x, pos_embed)
    }

    int layer_idx = 0
    while layer_idx < model.num_layers {
        x = forward_transformer_layer(transformer_layer_at(model.layers, layer_idx), x, batch_size, seq_len)
        layer_idx = layer_idx + 1
    }

    []float logits = matmul_flat(x, model.lm_head_weight, batch_size * seq_len, hidden_dim, model.vocab_size)
    transformer_output {
        logits: logits,
        hidden_states: x,
    }
}

func compute_lm_loss(
    []float logits,
    []int target_ids,
    int batch_size,
    int seq_len,
    int vocab_size
) float {
    float loss = 0.0
    int total = batch_size * seq_len
    int i = 0
    while i < total {
        int base = i * vocab_size
        float max_logit = logits[base]
        int j = 1
        while j < vocab_size {
            if logits[base + j] > max_logit {
                max_logit = logits[base + j]
            }
            j = j + 1
        }
        float sum_exp = 0.0
        j = 0
        while j < vocab_size {
            float value = logits[base + j] - max_logit
            float e = 1.0
            int k = 0
            while k < 8 {
                e = e * value / ((k + 1) * 1.0) + 1.0
                k = k + 1
            }
            sum_exp = sum_exp + e
            j = j + 1
        }
        int target_id = target_ids[i]
        if target_id < 0 {
            target_id = 0
        }
        if target_id >= vocab_size {
            target_id = vocab_size - 1
        }
        float target_logit = logits[base + target_id]
        loss = loss - (target_logit - max_logit - 0.0)
        i = i + 1
    }
    loss / (total * 1.0)
}

func get_model_complexity(
    transformer_model model,
    int batch_size,
    int seq_len
) map[string]long {
    map[string]long{}
}
