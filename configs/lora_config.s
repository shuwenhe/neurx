package config

type lora_init_method string

const (
    lora_init_random      lora_init_method = "random"
    lora_init_gaussian    lora_init_method = "gaussian"
    lora_init_zero        lora_init_method = "zero"
)

struct lora_config {
    bool enable_lora

    string lora_base_model_name_or_path
    []string lora_model_paths

    int32 lora_r
    int32 lora_alpha
    float32 lora_dropout

    bool lora_bias
    string lora_modules_to_save

    bool enable_lora_bias
    bool enable_lora_activation_checkpointing

    float32 lora_scaling_factor
    lora_init_method init_method

    int32 max_lora_rank
    int32 max_lora_count
    int32 max_cpu_lora_rank

    bool enable_lora_weight_merging
    bool enable_lora_quantization

    bool use_rslora
    bool use_dora

    float32 lora_merge_threshold

    map[string]interface{} extra_config
}

func create_default_lora_config() lora_config {
    return lora_config{
        enable_lora: false,
        lora_base_model_name_or_path: "",
        lora_model_paths: make([]string, 0),
        lora_r: 8,
        lora_alpha: 16,
        lora_dropout: 0.05,
        lora_bias: false,
        lora_modules_to_save: "q_proj,v_proj",
        enable_lora_bias: false,
        enable_lora_activation_checkpointing: false,
        lora_scaling_factor: 1.0,
        init_method: lora_init_gaussian,
        max_lora_rank: 256,
        max_lora_count: 64,
        max_cpu_lora_rank: 64,
        enable_lora_weight_merging: true,
        enable_lora_quantization: false,
        use_rslora: false,
        use_dora: false,
        lora_merge_threshold: 0.9,
        extra_config: make(map[string]interface{}),
    }
}

func (lora_config* cfg) validate() bool {
    if cfg.lora_r <= 0 {
        return false
    }
    if cfg.lora_alpha <= 0 {
        return false
    }
    if cfg.lora_dropout < 0.0 || cfg.lora_dropout > 1.0 {
        return false
    }
    if cfg.lora_scaling_factor <= 0.0 {
        return false
    }
    return true
}

func (lora_config* cfg) is_enabled() bool {
    return cfg.enable_lora
}

func (lora_config* cfg) get_lora_a_size(int32 hidden_size) int32 {
    return hidden_size * cfg.lora_r
}

func (lora_config* cfg) get_lora_b_size(int32 hidden_size) int32 {
    return cfg.lora_r * hidden_size
}

func (lora_config* cfg) get_total_lora_params(int32 hidden_size, int32 num_layers) int32 {
    lora_a := cfg.get_lora_a_size(hidden_size)
    lora_b := cfg.get_lora_b_size(hidden_size)
    return (lora_a + lora_b) * num_layers * 4
}

func (lora_config* cfg) enable_dora() {
    cfg.use_dora = true
}

func (lora_config* cfg) enable_rslora() {
    cfg.use_rslora = true
}

func (lora_config* cfg) add_lora_model(string lora_path) {
    cfg.lora_model_paths = append(cfg.lora_model_paths, lora_path)
}

func (lora_config* cfg) clear_lora_models() {
    cfg.lora_model_paths = make([]string, 0)
}
