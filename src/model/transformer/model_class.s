package neurx.model.transformer.transformer
struct model_preset {
    string name
    string family
    string size_label
    int estimated_parameters_b
}
struct foundation_model {
    model_preset preset
    transformer_config config
    transformer_config runtime_config
    transformer_model backbone
}
func intermediate_dim_4x(int hidden_dim) int {
    hidden_dim * 4
}
func new_7b_transformer_config() transformer_config {
    transformer_config cfg = new_transformer_config()
    cfg.vocab_size = 32000
    cfg.hidden_dim = 4096
    cfg.num_layers = 32
    cfg.num_attention_heads = 32
    cfg.num_key_value_heads = 8
    cfg.intermediate_dim = intermediate_dim_4x(cfg.hidden_dim)
    cfg.max_seq_len = 4096
    cfg.position_embedding_type = "rope"
    cfg
}
func new_13b_transformer_config() transformer_config {
    transformer_config cfg = new_transformer_config()
    cfg.vocab_size = 32000
    cfg.hidden_dim = 5120
    cfg.num_layers = 40
    cfg.num_attention_heads = 40
    cfg.num_key_value_heads = 8
    cfg.intermediate_dim = intermediate_dim_4x(cfg.hidden_dim)
    cfg.max_seq_len = 4096
    cfg.position_embedding_type = "rope"
    cfg
}
func new_70b_transformer_config() transformer_config {
    transformer_config cfg = new_transformer_config()
    cfg.vocab_size = 32000
    cfg.hidden_dim = 8192
    cfg.num_layers = 80
    cfg.num_attention_heads = 64
    cfg.num_key_value_heads = 8
    cfg.intermediate_dim = intermediate_dim_4x(cfg.hidden_dim)
    cfg.max_seq_len = 8192
    cfg.position_embedding_type = "rope"
    cfg
}
func preset_from_size(string size_label) model_preset {
    if size_label == "13B" {
        return model_preset {
            name: "neurx-transformer-13b",
            family: "decoder-only-transformer",
            size_label: "13B",
            estimated_parameters_b: 13,
        }
    }
    if size_label == "70B" {
        return model_preset {
            name: "neurx-transformer-70b",
            family: "decoder-only-transformer",
            size_label: "70B",
            estimated_parameters_b: 70,
        }
    }
    model_preset {
        name: "neurx-transformer-7b",
        family: "decoder-only-transformer",
        size_label: "7B",
        estimated_parameters_b: 7,
    }
}
func config_from_size(string size_label, string position_embedding_type) transformer_config {
    transformer_config cfg = new_7b_transformer_config()
    if size_label == "13B" {
        cfg = new_13b_transformer_config()
    } else if size_label == "70B" {
        cfg = new_70b_transformer_config()
    }
    cfg.position_embedding_type = position_embedding_type
    cfg
}
func min_int(int a, int b) int {
    if a < b {
        return a
    }
    b
}
func compact_runtime_config(transformer_config cfg) transformer_config {
    transformer_config runtime = cfg
    runtime.hidden_dim = min_int(cfg.hidden_dim, 8)
    runtime.num_layers = min_int(cfg.num_layers, 1)
    runtime.num_attention_heads = min_int(cfg.num_attention_heads, 2)
    if runtime.num_attention_heads <= 0 {
        runtime.num_attention_heads = 1
    }
    runtime.num_key_value_heads = min_int(cfg.num_key_value_heads, runtime.num_attention_heads)
    if runtime.num_key_value_heads <= 0 {
        runtime.num_key_value_heads = 1
    }
    runtime.vocab_size = min_int(cfg.vocab_size, 16)
    runtime.max_seq_len = min_int(cfg.max_seq_len, 4)
    runtime.intermediate_dim = runtime.hidden_dim * 4
    runtime
}
func new_foundation_model(string size_label, string position_embedding_type) foundation_model {
    transformer_config cfg = config_from_size(size_label, position_embedding_type)
    transformer_config runtime_cfg = compact_runtime_config(cfg)
    foundation_model {
        preset: preset_from_size(size_label),
        config: cfg,
        runtime_config: runtime_cfg,
        backbone: new_transformer_model(runtime_cfg),
    }
}
func foundation_model_forward(
    foundation_model model,
    float[] hidden_states,
    int batch_size,
    int seq_len
) transformer_output {
    forward_transformer(model.backbone, hidden_states, batch_size, seq_len)
}
func foundation_model_summary(foundation_model model) string {
    model.preset.name + ":" + model.preset.size_label + ":layers=" + string(model.config.num_layers) + ":hidden=" + string(model.config.hidden_dim) + ":runtime_hidden=" + string(model.runtime_config.hidden_dim)
}
