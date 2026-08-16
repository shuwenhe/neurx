package config

enum precision_type {
    float32
    float16
    bfloat16
    int8
    int4
    auto
}

enum memory_allocator {
    default
    cumem
    pytorch_default
    custom
}

struct device_config {
    device_type device
    int32 device_id
    string device_name
    precision_type default_dtype
    bool use_unified_memory
    bool use_managed_memory
    memory_allocator allocator_type
    bool pin_memory
    bool use_cuda_graphs
    float tensor_parallelism_degree
    int32 pipeline_parallelism_stages
}

struct memory_config {
    int64 max_memory
    int64 gpu_memory_utilization
    bool enable_prefix_caching
    bool enable_kv_cache
    float kv_cache_ratio
    int32 block_size
    int32 num_blocks
    bool use_sliding_window
}

struct computation_config {
    bool enable_flash_attn
    bool enable_triton
    bool enable_torch_compile
    string compile_backend
    bool use_tensor_parallelism
    bool use_pipeline_parallelism
    bool enable_async_processing
    int32 max_batch_size
}

struct attention_config {
    string backend
    bool use_causal_mask
    bool use_flash_attn
    bool use_paged_attn
    float attention_dropout
    int32 num_attention_heads
    int32 head_dim
}

struct optimization_config {
    bool enable_kernel_fusion
    bool enable_memory_optimization
    bool enable_computation_optimization
    vec[string] enabled_optimizations
    float compute_utilization_target
    float memory_utilization_target
}

struct device_config_full {
    device_config* dev_cfg
    memory_config* mem_cfg
    computation_config* comp_cfg
    attention_config* attn_cfg
    optimization_config* opt_cfg
}

interface device_config_manager {
    func create_default_config(device device_type) (device_config*)
    func create_memory_config(max_mem int64) (memory_config*)
    func create_computation_config() (computation_config*)
    func create_attention_config() (attention_config*)
    func create_optimization_config() (optimization_config*)
    func apply_config(cfg device_config_full*) (bool)
    func get_current_config() (device_config_full*)
    func validate_config(cfg device_config_full*) (vec[string])
}

struct device_config_manager_impl {
    device_config_full* current_config
    bool config_applied
}

func create_device_config_manager() (device_config_manager_impl*) {
    mgr := &device_config_manager_impl{
        current_config: nil,
        config_applied: false,
    }
    return mgr
}

func (m* device_config_manager_impl) create_default_config(device device_type) (device_config*) {
    cfg := &device_config{
        device: device,
        device_id: 0,
        device_name: device_type_to_string(device),
        default_dtype: precision_type.float16,
        use_unified_memory: false,
        use_managed_memory: true,
        allocator_type: memory_allocator.default,
        pin_memory: true,
        use_cuda_graphs: true,
        tensor_parallelism_degree: 1.0,
        pipeline_parallelism_stages: 1,
    }
    return cfg
}

func (m* device_config_manager_impl) create_memory_config(max_mem int64) (memory_config*) {
    cfg := &memory_config{
        max_memory: max_mem,
        gpu_memory_utilization: 90,
        enable_prefix_caching: true,
        enable_kv_cache: true,
        kv_cache_ratio: 0.9,
        block_size: 16,
        num_blocks: int32(max_mem / 65536),
        use_sliding_window: false,
    }
    return cfg
}

func (m* device_config_manager_impl) create_computation_config() (computation_config*) {
    cfg := &computation_config{
        enable_flash_attn: true,
        enable_triton: true,
        enable_torch_compile: false,
        compile_backend: "inductor",
        use_tensor_parallelism: false,
        use_pipeline_parallelism: false,
        enable_async_processing: true,
        max_batch_size: 128,
    }
    return cfg
}

func (m* device_config_manager_impl) create_attention_config() (attention_config*) {
    cfg := &attention_config{
        backend: "flash_attn",
        use_causal_mask: true,
        use_flash_attn: true,
        use_paged_attn: true,
        attention_dropout: 0.0,
        num_attention_heads: 32,
        head_dim: 128,
    }
    return cfg
}

func (m* device_config_manager_impl) create_optimization_config() (optimization_config*) {
    cfg := &optimization_config{
        enable_kernel_fusion: true,
        enable_memory_optimization: true,
        enable_computation_optimization: true,
        enabled_optimizations: vec[string]{"fusion", "quantization", "pruning"},
        compute_utilization_target: 0.85,
        memory_utilization_target: 0.90,
    }
    return cfg
}

func (m* device_config_manager_impl) apply_config(cfg device_config_full*) (bool) {
    errors := m.validate_config(cfg)
    if len(errors) > 0 {
        return false
    }
    
    m.current_config = cfg
    m.config_applied = true
    
    return true
}

func (m* device_config_manager_impl) get_current_config() (device_config_full*) {
    return m.current_config
}

func (m* device_config_manager_impl) validate_config(cfg device_config_full*) (vec[string]) {
    errors := vec[string]{}
    
    if cfg == nil {
        errors = append(errors, "Config is nil")
        return errors
    }
    
    if cfg.dev_cfg == nil {
        errors = append(errors, "Device config is nil")
    } else {
        if cfg.dev_cfg.device_id < 0 {
            errors = append(errors, "Invalid device_id: must be >= 0")
        }
        if cfg.dev_cfg.tensor_parallelism_degree <= 0.0 {
            errors = append(errors, "Invalid tensor_parallelism_degree: must be > 0")
        }
    }
    
    if cfg.mem_cfg != nil {
        if cfg.mem_cfg.max_memory <= 0 {
            errors = append(errors, "Invalid max_memory: must be > 0")
        }
        if cfg.mem_cfg.gpu_memory_utilization < 0 || cfg.mem_cfg.gpu_memory_utilization > 100 {
            errors = append(errors, "Invalid gpu_memory_utilization: must be 0-100")
        }
        if cfg.mem_cfg.kv_cache_ratio < 0.0 || cfg.mem_cfg.kv_cache_ratio > 1.0 {
            errors = append(errors, "Invalid kv_cache_ratio: must be 0.0-1.0")
        }
    }
    
    if cfg.comp_cfg != nil {
        if cfg.comp_cfg.max_batch_size <= 0 {
            errors = append(errors, "Invalid max_batch_size: must be > 0")
        }
    }
    
    if cfg.attn_cfg != nil {
        if cfg.attn_cfg.attention_dropout < 0.0 || cfg.attn_cfg.attention_dropout > 1.0 {
            errors = append(errors, "Invalid attention_dropout: must be 0.0-1.0")
        }
        if cfg.attn_cfg.num_attention_heads <= 0 {
            errors = append(errors, "Invalid num_attention_heads: must be > 0")
        }
    }
    
    if cfg.opt_cfg != nil {
        if cfg.opt_cfg.compute_utilization_target < 0.0 || cfg.opt_cfg.compute_utilization_target > 1.0 {
            errors = append(errors, "Invalid compute_utilization_target: must be 0.0-1.0")
        }
        if cfg.opt_cfg.memory_utilization_target < 0.0 || cfg.opt_cfg.memory_utilization_target > 1.0 {
            errors = append(errors, "Invalid memory_utilization_target: must be 0.0-1.0")
        }
    }
    
    return errors
}

func precision_type_to_string(pt precision_type) (string) {
    match pt {
        precision_type.float32 => return "float32"
        precision_type.float16 => return "float16"
        precision_type.bfloat16 => return "bfloat16"
        precision_type.int8 => return "int8"
        precision_type.int4 => return "int4"
        precision_type.auto => return "auto"
    }
    return "unknown"
}

func string_to_precision_type(s string) (precision_type) {
    match s {
        "float32" => return precision_type.float32
        "float16" => return precision_type.float16
        "bfloat16" => return precision_type.bfloat16
        "int8" => return precision_type.int8
        "int4" => return precision_type.int4
        "auto" => return precision_type.auto
        _ => return precision_type.auto
    }
}
