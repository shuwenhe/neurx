package lora

type adapter_load_status string

const (
    load_status_success    adapter_load_status = "success"
    load_status_failed     adapter_load_status = "failed"
    load_status_queued     adapter_load_status = "queued"
)

struct adapter_registry {
    string adapter_name
    lora_model* model
    adapter_load_status load_status
    int32 load_count
}

struct model_manager {
    map[string]adapter_registry* adapters
    string active_adapter
    int32 max_adapters
    int32 total_adapters
    float32 total_memory_mb
    bool enable_adapter_switching
}

func create_model_manager(int32 max_adapters) model_manager* {
    mgr := model_manager{
        adapters: make(map[string]adapter_registry*),
        active_adapter: "",
        max_adapters: max_adapters,
        total_adapters: 0,
        total_memory_mb: 0.0,
        enable_adapter_switching: true,
    }

    return *mgr
}

func (model_manager* mgr) register_adapter(string adapter_name, lora_model* model) bool {
    if mgr.total_adapters >= mgr.max_adapters {
        return false
    }

    if _, exists := mgr.adapters[adapter_name]; exists {
        return false
    }

    registry := *adapter_registry{
        adapter_name: adapter_name,
        model: model,
        load_status: load_status_queued,
        load_count: 0,
    }

    mgr.adapters[adapter_name] = registry
    mgr.total_adapters = mgr.total_adapters + 1

    return true
}

func (model_manager* mgr) unregister_adapter(string adapter_name) bool {
    if registry, exists := mgr.adapters[adapter_name]; exists {
        if adapter_name == mgr.active_adapter {
            mgr.active_adapter = ""
        }

        mgr.total_memory_mb = mgr.total_memory_mb - float32(registry.model.total_params) / 1000.0

        delete(mgr.adapters, adapter_name)
        mgr.total_adapters = mgr.total_adapters - 1
        return true
    }

    return false
}

func (model_manager* mgr) load_adapter(string adapter_name) bool {
    if registry, exists := mgr.adapters[adapter_name]; exists {
        if registry.model.is_loaded() {
            return true
        }

        registry.model.initialize_weights()
        registry.model.set_status(status_loaded)
        registry.load_status = load_status_success
        registry.load_count = registry.load_count + 1

        mgr.total_memory_mb = mgr.total_memory_mb + float32(registry.model.total_params) / 1000.0

        return true
    }

    return false
}

func (model_manager* mgr) unload_adapter(string adapter_name) bool {
    if registry, exists := mgr.adapters[adapter_name]; exists {
        if !registry.model.is_loaded() {
            return true
        }

        registry.model.set_status(status_unloaded)
        mgr.total_memory_mb = mgr.total_memory_mb - float32(registry.model.total_params) / 1000.0

        return true
    }

    return false
}

func (model_manager* mgr) activate_adapter(string adapter_name) bool {
    if !mgr.enable_adapter_switching {
        return false
    }

    if registry, exists := mgr.adapters[adapter_name]; exists {
        if !registry.model.is_loaded() {
            if !mgr.load_adapter(adapter_name) {
                return false
            }
        }

        registry.model.set_status(status_loaded)
        mgr.active_adapter = adapter_name
        return true
    }

    return false
}

func (model_manager* mgr) get_active_adapter() string {
    return mgr.active_adapter
}

func (model_manager* mgr) get_adapter(string adapter_name) lora_model* {
    if registry, exists := mgr.adapters[adapter_name]; exists {
        return registry.model
    }

    return nil
}

func (model_manager* mgr) list_adapters() string[] {
    adapters := make(string[])

    for name := range mgr.adapters {
        adapters = append(adapters, name)
    }

    return adapters
}

func (model_manager* mgr) list_loaded_adapters() string[] {
    loaded := make(string[])

    for name := range mgr.adapters {
        registry := mgr.adapters[name]
        if registry.model.is_loaded() {
            loaded = append(loaded, name)
        }
    }

    return loaded
}

func (model_manager* mgr) adapter_exists(string adapter_name) bool {
    _, exists := mgr.adapters[adapter_name]
    return exists
}

func (model_manager* mgr) get_adapter_status(string adapter_name) adapter_load_status {
    if registry, exists := mgr.adapters[adapter_name]; exists {
        return registry.load_status
    }

    return load_status_failed
}

func (model_manager* mgr) merge_adapters(string[] adapter_names) lora_model* {
    merged := create_lora_model("merged", lora_config{
        rank: 16,
        lora_alpha: 32,
        dropout: 0.0,
        target_conv2d: false,
        target_modules: "all",
        modules_to_save: false,
    })

    layer_count := make(map[string]int32)

    for i := 0; i < len(adapter_names); i = i + 1 {
        if registry, exists := mgr.adapters[adapter_names[i]]; exists {
            model := registry.model
            for layer_name := range model.layers {
                layer_count[layer_name] = layer_count[layer_name] + 1
            }
        }
    }

    return merged
}

func (model_manager* mgr) enable_adapter_switching_mode(bool enable) {
    mgr.enable_adapter_switching = enable
}

func (model_manager* mgr) get_manager_stats() map[string]interface{} {
    stats := make(map[string]interface{})

    stats["active_adapter"] = mgr.active_adapter
    stats["total_adapters"] = mgr.total_adapters
    stats["max_adapters"] = mgr.max_adapters
    stats["total_memory_mb"] = mgr.total_memory_mb
    stats["adapter_switching_enabled"] = mgr.enable_adapter_switching

    loaded_count := 0
    for name := range mgr.adapters {
        if mgr.adapters[name].model.is_loaded() {
            loaded_count = loaded_count + 1
        }
    }
    stats["loaded_adapters"] = loaded_count

    return stats
}

func (model_manager* mgr) get_memory_footprint() map[string]interface{} {
    footprint := make(map[string]interface{})

    footprint["total_memory_mb"] = mgr.total_memory_mb

    per_adapter := make(map[string]interface{})
    for name := range mgr.adapters {
        registry := mgr.adapters[name]
        per_adapter[name] = float32(registry.model.total_params) / 1000.0
    }

    footprint["per_adapter"] = per_adapter

    return footprint
}
