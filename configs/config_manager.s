package config

type optimization_target string

const (
    target_latency      optimization_target = "latency"
    target_throughput   optimization_target = "throughput"
    target_memory       optimization_target = "memory"
    target_balanced     optimization_target = "balanced"
)

struct config_manager {
    model_config* model_cfg
    attention_config* attention_cfg
    parallel_config* parallel_cfg
    quantization_config* quant_cfg
    scheduler_config* scheduler_cfg
    speculative_config* spec_cfg
    lora_config* lora_cfg
    kv_transfer_config* kv_cfg
    cache_config* cache_cfg
    device_config* device_cfg
    kernel_config* kernel_cfg
    
    optimization_target target
    bool initialized
}

func create_config_manager() config_manager* {
    return &config_manager{
        model_cfg: nil,
        attention_cfg: nil,
        parallel_cfg: nil,
        quant_cfg: nil,
        scheduler_cfg: nil,
        spec_cfg: nil,
        lora_cfg: nil,
        kv_cfg: nil,
        cache_cfg: nil,
        device_cfg: nil,
        kernel_cfg: nil,
        target: target_balanced,
        initialized: false,
    }
}

func (config_manager* mgr) initialize_all_defaults() {
    mgr.model_cfg = &create_default_model_config()
    mgr.attention_cfg = &create_default_attention_config()
    mgr.parallel_cfg = &create_default_parallel_config()
    mgr.quant_cfg = &create_default_quantization_config()
    mgr.scheduler_cfg = &create_default_scheduler_config()
    mgr.spec_cfg = &create_default_speculative_config()
    mgr.lora_cfg = &create_default_lora_config()
    mgr.kv_cfg = &create_default_kv_transfer_config()
    mgr.cache_cfg = &create_default_cache_config()
    mgr.device_cfg = &create_default_device_config()
    mgr.kernel_cfg = &create_default_kernel_config()
    mgr.initialized = true
}

func (config_manager* mgr) validate_all() bool {
    if mgr.model_cfg == nil || !mgr.model_cfg.validate() {
        return false
    }
    if mgr.attention_cfg == nil || !mgr.attention_cfg.validate() {
        return false
    }
    if mgr.parallel_cfg == nil || !mgr.parallel_cfg.validate() {
        return false
    }
    if mgr.quant_cfg == nil || !mgr.quant_cfg.validate() {
        return false
    }
    if mgr.scheduler_cfg == nil || !mgr.scheduler_cfg.validate() {
        return false
    }
    if mgr.device_cfg == nil || !mgr.device_cfg.validate() {
        return false
    }
    return true
}

func (config_manager* mgr) optimize_for_latency() {
    mgr.target = target_latency
    mgr.scheduler_cfg.optimize_for_latency()
    mgr.kernel_cfg.optimize_for_latency()
    mgr.cache_cfg.optimize_for_performance()
}

func (config_manager* mgr) optimize_for_throughput() {
    mgr.target = target_throughput
    mgr.scheduler_cfg.optimize_for_throughput()
    mgr.kernel_cfg.optimize_for_throughput()
    mgr.cache_cfg.optimize_for_performance()
}

func (config_manager* mgr) optimize_for_memory() {
    mgr.target = target_memory
    mgr.quant_cfg.enable_int8()
    mgr.kernel_cfg.optimize_for_memory()
    mgr.cache_cfg.optimize_for_memory()
    mgr.device_cfg.optimize_for_memory()
}

func (config_manager* mgr) optimize_balanced() {
    mgr.target = target_balanced
    mgr.scheduler_cfg.optimize_for_throughput()
    mgr.kernel_cfg.optimize_for_performance()
    mgr.cache_cfg.optimize_for_performance()
}

func (config_manager* mgr) get_model_config() model_config* {
    return mgr.model_cfg
}

func (config_manager* mgr) get_attention_config() attention_config* {
    return mgr.attention_cfg
}

func (config_manager* mgr) get_parallel_config() parallel_config* {
    return mgr.parallel_cfg
}

func (config_manager* mgr) get_quantization_config() quantization_config* {
    return mgr.quant_cfg
}

func (config_manager* mgr) get_scheduler_config() scheduler_config* {
    return mgr.scheduler_cfg
}

func (config_manager* mgr) get_speculative_config() speculative_config* {
    return mgr.spec_cfg
}

func (config_manager* mgr) get_lora_config() lora_config* {
    return mgr.lora_cfg
}

func (config_manager* mgr) get_kv_transfer_config() kv_transfer_config* {
    return mgr.kv_cfg
}

func (config_manager* mgr) get_cache_config() cache_config* {
    return mgr.cache_cfg
}

func (config_manager* mgr) get_device_config() device_config* {
    return mgr.device_cfg
}

func (config_manager* mgr) get_kernel_config() kernel_config* {
    return mgr.kernel_cfg
}

func (config_manager* mgr) get_optimization_target() optimization_target {
    return mgr.target
}

func (config_manager* mgr) is_initialized() bool {
    return mgr.initialized
}

func (config_manager* mgr) export_config() map[string]interface{} {
    config_map := make(map[string]interface{})
    if mgr.model_cfg != nil {
        config_map["model"] = mgr.model_cfg
    }
    if mgr.attention_cfg != nil {
        config_map["attention"] = mgr.attention_cfg
    }
    if mgr.parallel_cfg != nil {
        config_map["parallel"] = mgr.parallel_cfg
    }
    if mgr.quant_cfg != nil {
        config_map["quantization"] = mgr.quant_cfg
    }
    if mgr.scheduler_cfg != nil {
        config_map["scheduler"] = mgr.scheduler_cfg
    }
    if mgr.spec_cfg != nil {
        config_map["speculative"] = mgr.spec_cfg
    }
    if mgr.lora_cfg != nil {
        config_map["lora"] = mgr.lora_cfg
    }
    if mgr.kv_cfg != nil {
        config_map["kv_transfer"] = mgr.kv_cfg
    }
    if mgr.cache_cfg != nil {
        config_map["cache"] = mgr.cache_cfg
    }
    if mgr.device_cfg != nil {
        config_map["device"] = mgr.device_cfg
    }
    if mgr.kernel_cfg != nil {
        config_map["kernel"] = mgr.kernel_cfg
    }
    return config_map
}

func (config_manager* mgr) print_summary() {
    _ = mgr
}
