package config

type model_architecture string

const (
    arch_transformer    model_architecture = "transformer"
    arch_llama          model_architecture = "llama"
    arch_qwen           model_architecture = "qwen"
    arch_mistral        model_architecture = "mistral"
    arch_deepseek       model_architecture = "deepseek"
    arch_baichuan       model_architecture = "baichuan"
    arch_moe            model_architecture = "moe"
)

type activation_function string

const (
    activation_gelu         activation_function = "gelu"
    activation_gelu_tanh    activation_function = "gelu_tanh"
    activation_gelu_approx  activation_function = "gelu_approximate"
    activation_silu         activation_function = "silu"
    activation_relu         activation_function = "relu"
    activation_mish         activation_function = "mish"
)

struct model_config {
    string model_id
    string model_name
    string model_path
    model_architecture architecture
    int32 hidden_size
    int32 num_hidden_layers
    int32 num_attention_heads
    int32 num_kv_heads
    int32 intermediate_size
    int32 vocab_size
    int32 max_seq_length
    int32 max_position_embeddings
    int32 context_window
    
    activation_function hidden_act
    float32 initializer_range
    float32 layer_norm_eps
    float32 rms_norm_eps
    
    bool use_cache
    bool is_training
    bool use_reentrant_checkpointing
    
    float32 rope_theta
    float32 rope_scaling
    bool use_sliding_window
    int32 sliding_window
    
    int32 bos_token_id
    int32 eos_token_id
    int32 pad_token_id
    int32 unk_token_id
    
    bool tie_word_embeddings
    bool pretraining_tp
    
    map[string]interface{} extra_config
}

func create_default_model_config() model_config {
    return model_config{
        model_id: "default",
        model_name: "default-model",
        model_path: "",
        architecture: arch_transformer,
        hidden_size: 768,
        num_hidden_layers: 12,
        num_attention_heads: 12,
        num_kv_heads: 12,
        intermediate_size: 3072,
        vocab_size: 30522,
        max_seq_length: 2048,
        max_position_embeddings: 2048,
        context_window: 2048,
        hidden_act: activation_gelu,
        initializer_range: 0.02,
        layer_norm_eps: 1e-6,
        rms_norm_eps: 1e-6,
        use_cache: true,
        is_training: false,
        use_reentrant_checkpointing: false,
        rope_theta: 10000.0,
        rope_scaling: 1.0,
        use_sliding_window: false,
        sliding_window: 0,
        bos_token_id: 0,
        eos_token_id: 2,
        pad_token_id: 0,
        unk_token_id: 0,
        tie_word_embeddings: true,
        pretraining_tp: 1,
        extra_config: make(map[string]interface{}),
    }
}

func (model_config* cfg) validate() bool {
    if cfg.hidden_size <= 0 {
        return false
    }
    if cfg.num_hidden_layers <= 0 {
        return false
    }
    if cfg.num_attention_heads <= 0 {
        return false
    }
    if cfg.vocab_size <= 0 {
        return false
    }
    if cfg.max_seq_length <= 0 {
        return false
    }
    return true
}

func (model_config* cfg) get_head_dim() int32 {
    return cfg.hidden_size / cfg.num_attention_heads
}

func (model_config* cfg) get_num_kv_heads() int32 {
    if cfg.num_kv_heads == 0 {
        return cfg.num_attention_heads
    }
    return cfg.num_kv_heads
}

func (model_config* cfg) supports_flash_attention() bool {
    return true
}

func (model_config* cfg) supports_paged_attention() bool {
    return true
}

func (model_config* cfg) get_total_params() int64 {
    embedding_params := int64(cfg.vocab_size) * int64(cfg.hidden_size)
    attention_params := int64(cfg.num_hidden_layers) * int64(cfg.hidden_size) * int64(cfg.hidden_size) * int64(3)
    mlp_params := int64(cfg.num_hidden_layers) * int64(cfg.hidden_size) * int64(cfg.intermediate_size) * int64(2)
    norm_params := int64(cfg.num_hidden_layers) * int64(2) * int64(cfg.hidden_size)
    output_params := int64(cfg.hidden_size) * int64(cfg.vocab_size)
    
    return embedding_params + attention_params + mlp_params + norm_params + output_params
}

func (model_config* cfg) to_string() string {
    return "ModelConfig{" + cfg.model_id + ", " + string(cfg.architecture) + "}"
}
