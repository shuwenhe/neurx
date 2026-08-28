package attention

    training
    inference
}

struct attention_layer {
    string layer_id
    int layer_index
    attention_backend_manager backend_manager
    string active_backend
    attention_layer_mode mode
    key_value_cache kv_cache
    bool use_kv_cache
    int64 layer_creation_time
}

struct attention_forward_input {
    string layer_id
    int batch_size
    int seq_length
    int num_heads
    int head_dim
    bool use_cache
    int cache_seq_length
    string precision
}

struct attention_output {
    bool success
    string error_msg
    int64 computation_time_us
    int64 memory_used_bytes
    bool cache_updated
}

func new_attention_layer(string layer_id, int layer_index, int num_heads, int head_dim) attention_layer {
    backend_mgr := new_attention_backend_manager()

    config := new_attention_config(num_heads, head_dim)

    base_config := new_attention_config(num_heads, head_dim)

    standard := new_standard_attention_backend(base_config)
    flash := new_flash_attention_backend(base_config)
    dsa := new_dsa_backend(base_config)
    paged := new_paged_attention_backend(base_config)

    backend_mgr.register_backend("standard", standard)
    backend_mgr.register_backend("flash_attention", flash)
    backend_mgr.register_backend("dsa", dsa)
    backend_mgr.register_backend("paged_attention", paged)

    kv_cache := new_kv_cache(layer_id + "_cache", "float16", int64[]{}, false)

    attention_layer {
        layer_id: layer_id,
        layer_index: layer_index,
        backend_manager: backend_mgr,
        active_backend: "flash_attention",
        mode: attention_layer_mode_inference,
        kv_cache: kv_cache,
        use_kv_cache: true,
        layer_creation_time: 0,
    }
}

func (attention_layer* layer) initialize() bool {
    layer.backend_manager.initialize_all()
}

func (attention_layer* layer) finalize() bool {
    layer.backend_manager.finalize_all()
}

func (attention_layer* layer) set_active_backend(string backend_name) bool {
    layer.backend_manager.set_current_backend(backend_name)
}

func (attention_layer* layer) get_active_backend_name() string {
    layer.backend_manager.current_backend
}

func (attention_layer* layer) forward(attention_forward_input input) attention_output {
    if !layer.backend_manager.has_backend(layer.active_backend) {
        attention_output {
            success: false,
            error_msg: "backend not found: " + layer.active_backend,
            computation_time_us: 0,
            memory_used_bytes: 0,
            cache_updated: false,
        }
    }

    backend := layer.backend_manager.get_backend(layer.active_backend)

    if !backend.is_initialized() {
        attention_output {
            success: false,
            error_msg: "backend not initialized",
            computation_time_us: 0,
            memory_used_bytes: 0,
            cache_updated: false,
        }
    }

    req := attention_forward_request {
        request_id: layer.layer_id + "_req",
        batch_size: input.batch_size,
        seq_length: input.seq_length,
        num_heads: input.num_heads,
        head_dim: input.head_dim,
        use_cache: input.use_cache,
        cache_seq_length: input.cache_seq_length,
    }

    result := backend.forward(req)

    memory_used := backend.get_estimated_memory(input.batch_size, input.seq_length, input.num_heads, input.head_dim)

    attention_output {
        success: result.success,
        error_msg: result.error_msg,
        computation_time_us: result.computation_time_us,
        memory_used_bytes: memory_used,
        cache_updated: input.use_cache,
    }
}

func (attention_layer* layer) auto_tune_backend(int seq_length, string precision) string {
    selected := layer.backend_manager.auto_select_backend(seq_length, precision)
    layer.set_active_backend(selected)
    selected
}

func (attention_layer* layer) get_kv_cache() key_value_cache {
    layer.kv_cache
}

func (attention_layer* layer) clear_cache() bool {
    layer.use_kv_cache = false
    true
}

func (attention_layer* layer) enable_cache() bool {
    layer.use_kv_cache = true
    true
}

func (attention_layer* layer) list_available_backends() string[] {
    layer.backend_manager.list_backends()
}

struct attention_layer_stack {
    attention_layer[] layers
    int num_layers
    int num_heads
    int head_dim
}

func new_attention_layer_stack(int num_layers, int num_heads, int head_dim) attention_layer_stack {
    layers := attention_layer[]{}
    i := 0
    for i < num_layers {
        layer_id := "attn_layer_" + string(i)
        layer := new_attention_layer(layer_id, i, num_heads, head_dim)
        layers = append(layers, layer)
        i = i + 1
    }

    attention_layer_stack {
        layers: layers,
        num_layers: num_layers,
        num_heads: num_heads,
        head_dim: head_dim,
    }
}

func (attention_layer_stack* stack) initialize_all() bool {
    i := 0
    for i < len(stack.layers) {
        if !stack.layers[i].initialize() {
            false
        }
        i = i + 1
    }

    true
}

func (attention_layer_stack* stack) finalize_all() bool {
    i := 0
    for i < len(stack.layers) {
        if !stack.layers[i].finalize() {
            false
        }
        i = i + 1
    }

    true
}

func (attention_layer_stack* stack) set_all_backend(string backend_name) bool {
    i := 0
    for i < len(stack.layers) {
        if !stack.layers[i].set_active_backend(backend_name) {
            false
        }
        i = i + 1
    }

    true
}

func (attention_layer_stack* stack) get_layer(int index) attention_layer {
    if index >= 0 && index < len(stack.layers) {
        stack.layers[index]
    }

    new_attention_layer("", -1, stack.num_heads, stack.head_dim)
}
