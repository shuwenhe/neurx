package config

type attention_backend string

const (
    attention_flash_attention_v2  attention_backend = "flash_attention_v2"
    attention_flash_attention_v3  attention_backend = "flash_attention_v3"
    attention_paged_attention     attention_backend = "paged_attention"
    attention_torch_sdpa          attention_backend = "torch_sdpa"
    attention_triton              attention_backend = "triton"
    attention_xformers            attention_backend = "xformers"
)

type attention_dtype string

const (
    attention_dtype_float32    attention_dtype = "float32"
    attention_dtype_float16    attention_dtype = "float16"
    attention_dtype_bfloat16   attention_dtype = "bfloat16"
)

struct attention_config {
    attention_backend backend
    attention_dtype dtype

    bool use_flash_attention
    bool use_paged_attention
    bool use_sliding_window_attention

    int32 block_size
    int32 num_kv_blocks

    float32 attention_dropout
    bool use_attention_dropout

    bool enable_fused_qkv
    bool enable_fused_output_projection

    bool use_rope
    float32 rope_theta
    float32 rope_scaling_factor

    int32 max_context_length
    bool use_dynamic_context_length

    bool enable_attention_fusion
    int32 attention_fusion_threshold

    map[string]interface{} extra_config
}

func create_default_attention_config() attention_config {
    return attention_config{
        backend: attention_flash_attention_v2,
        dtype: attention_dtype_float16,
        use_flash_attention: true,
        use_paged_attention: true,
        use_sliding_window_attention: false,
        block_size: 16,
        num_kv_blocks: 128,
        attention_dropout: 0.0,
        use_attention_dropout: false,
        enable_fused_qkv: true,
        enable_fused_output_projection: true,
        use_rope: true,
        rope_theta: 10000.0,
        rope_scaling_factor: 1.0,
        max_context_length: 8192,
        use_dynamic_context_length: true,
        enable_attention_fusion: true,
        attention_fusion_threshold: 256,
        extra_config: make(map[string]interface{}),
    }
}

func (attention_config* cfg) validate() bool {
    if cfg.block_size <= 0 {
        return false
    }
    if cfg.num_kv_blocks <= 0 {
        return false
    }
    if cfg.attention_dropout < 0.0 || cfg.attention_dropout > 1.0 {
        return false
    }
    if cfg.max_context_length <= 0 {
        return false
    }
    return true
}

func (attention_config* cfg) supports_flash_attention() bool {
    return cfg.use_flash_attention &&
           (cfg.backend == attention_flash_attention_v2 ||
            cfg.backend == attention_flash_attention_v3)
}

func (attention_config* cfg) supports_paged_attention() bool {
    return cfg.use_paged_attention && cfg.backend == attention_paged_attention
}

func (attention_config* cfg) get_backend_name() string {
    return string(cfg.backend)
}

func (attention_config* cfg) get_dtype_name() string {
    return string(cfg.dtype)
}

func (attention_config* cfg) enable_all_optimizations() {
    cfg.use_flash_attention = true
    cfg.use_paged_attention = true
    cfg.enable_fused_qkv = true
    cfg.enable_fused_output_projection = true
    cfg.enable_attention_fusion = true
}

func (attention_config* cfg) disable_all_optimizations() {
    cfg.use_flash_attention = false
    cfg.use_paged_attention = false
    cfg.enable_fused_qkv = false
    cfg.enable_fused_output_projection = false
    cfg.enable_attention_fusion = false
}

func (attention_config* cfg) get_estimated_memory_mb(int32 batch_size, int32 seq_len, int32 hidden_size) int32 {
    bytes_per_attention := batch_size * seq_len * seq_len * hidden_size
    return int32(bytes_per_attention / (1024 * 1024))
}
