package neurx.inference.serve.lora_router
func lora_unloaded_status() int { 1 }
func lora_loading_status() int { 2 }
func lora_ready_status() int { 3 }
func lora_failed_status() int { 4 }
struct lora_adapter {
    string adapter_id
    string base_model
    string path
    int rank
    float alpha
    int status
    int active_requests
    int last_used_ms
    string error_message
}

struct lora_router_state {
    []lora_adapter adapters
    int max_loaded_adapters
    int max_lora_rank
}

struct lora_route_result {
    lora_router_state state
    lora_adapter adapter
    bool accepted
    string error_message
}

func new_lora_route_result(lora_router_state state, lora_adapter adapter, bool accepted, string error_message) lora_route_result {
    lora_route_result result
    result.state = state
    result.adapter = adapter
    result.accepted = accepted
    result.error_message = error_message
    result
}

func new_lora_router(int max_loaded_adapters, int max_lora_rank) lora_router_state {
    int loaded_limit = max_loaded_adapters
    if loaded_limit <= 0 {
        loaded_limit = 1
    }
    int rank_limit = max_lora_rank
    if rank_limit <= 0 {
        rank_limit = 1
    }
    lora_router_state {adapters: [], max_loaded_adapters: loaded_limit, max_lora_rank: rank_limit}
}

func lora_find_adapter(lora_router_state state, string adapter_id) int {
    int i = 0
    while i < len(state.adapters) {
        if state.adapters[i].adapter_id == adapter_id {
            return i
        }
        i = i + 1
    }
    -1
}

func lora_adapter_at(lora_router_state state, int index) lora_adapter {
    state.adapters[index]
}

func lora_loaded_count(lora_router_state state) int {
    int count = 0
    int i = 0
    while i < len(state.adapters) {
        if state.adapters[i].status == lora_ready_status() || state.adapters[i].status == lora_loading_status() {
            count = count + 1
        }
        i = i + 1
    }
    count
}

func empty_lora_adapter() lora_adapter {
    lora_adapter {
        adapter_id: "",
        base_model: "",
        path: "",
        rank: 0,
        alpha: 0.0,
        status: lora_unloaded_status(),
        active_requests: 0,
        last_used_ms: 0,
        error_message: "",
    }
}

func lora_register(lora_router_state state, string adapter_id, string base_model, string path, int rank, float alpha) lora_route_result {
    if adapter_id == "" || base_model == "" || path == "" {
        return new_lora_route_result(state, empty_lora_adapter(), false, "invalid adapter metadata")
    }
    if lora_find_adapter(state, adapter_id) >= 0 {
        return new_lora_route_result(state, empty_lora_adapter(), false, "adapter already registered")
    }
    if rank <= 0 || rank > state.max_lora_rank {
        return new_lora_route_result(state, empty_lora_adapter(), false, "adapter rank exceeds limit")
    }
    if lora_loaded_count(state) >= state.max_loaded_adapters {
        return new_lora_route_result(state, empty_lora_adapter(), false, "loaded adapter limit reached")
    }
    lora_adapter adapter
    adapter.adapter_id = adapter_id
    adapter.base_model = base_model
    adapter.path = path
    adapter.rank = rank
    adapter.alpha = alpha
    adapter.status = lora_loading_status()
    adapter.active_requests = 0
    adapter.last_used_ms = 0
    adapter.error_message = ""
    state.adapters = append(state.adapters, adapter)
    new_lora_route_result(state, adapter, true, "")
}

func lora_mark_loaded(lora_router_state state, string adapter_id, bool success, string error_message) lora_router_state {
    int index = lora_find_adapter(state, adapter_id)
    if index < 0 {
        return state
    }
    lora_adapter adapter = lora_adapter_at(state, index)
    if success {
        adapter.status = lora_ready_status()
        adapter.error_message = ""
    } else {
        adapter.status = lora_failed_status()
        adapter.error_message = error_message
    }
    state.adapters[index] = adapter
    state
}

func lora_acquire(lora_router_state state, string base_model, string adapter_id, int now_ms) lora_route_result {
    int index = lora_find_adapter(state, adapter_id)
    if index < 0 {
        return new_lora_route_result(state, empty_lora_adapter(), false, "adapter not found")
    }
    lora_adapter adapter = lora_adapter_at(state, index)
    if adapter.status != lora_ready_status() {
        return new_lora_route_result(state, adapter, false, "adapter is not ready")
    }
    if adapter.base_model != base_model {
        return new_lora_route_result(state, adapter, false, "adapter base model mismatch")
    }
    adapter.active_requests = adapter.active_requests + 1
    adapter.last_used_ms = now_ms
    state.adapters[index] = adapter
    new_lora_route_result(state, adapter, true, "")
}

func lora_release(lora_router_state state, string adapter_id, int now_ms) lora_router_state {
    int index = lora_find_adapter(state, adapter_id)
    if index < 0 {
        return state
    }
    lora_adapter adapter = lora_adapter_at(state, index)
    if adapter.active_requests > 0 {
        adapter.active_requests = adapter.active_requests - 1
    }
    adapter.last_used_ms = now_ms
    state.adapters[index] = adapter
    state
}

func lora_unload(lora_router_state state, string adapter_id) lora_route_result {
    int index = lora_find_adapter(state, adapter_id)
    if index < 0 {
        return new_lora_route_result(state, empty_lora_adapter(), false, "adapter not found")
    }
    lora_adapter adapter = lora_adapter_at(state, index)
    if adapter.active_requests > 0 {
        return new_lora_route_result(state, adapter, false, "adapter is in use")
    }
    adapter.status = lora_unloaded_status()
    state.adapters[index] = adapter
    new_lora_route_result(state, adapter, true, "")
}

func apply_lora_linear([]float input, []float base_output, []float lora_a, []float lora_b, int input_dim, int output_dim, int rank, float alpha) []float {
    []float output = []float{cap: output_dim}
    int i = 0
    while i < output_dim {
        if i < len(base_output) {
            output[i] = base_output[i]
        } else {
            output[i] = 0.0
        }
        i = i + 1
    }
    if input_dim <= 0 || output_dim <= 0 || rank <= 0 || len(input) < input_dim || len(lora_a) < rank * input_dim || len(lora_b) < output_dim * rank {
        return output
    }
    []float low_rank = []float{cap: rank}
    int r = 0
    while r < rank {
        float sum = 0.0
        i = 0
        while i < input_dim {
            sum = sum + lora_a[r * input_dim + i] * input[i]
            i = i + 1
        }
        low_rank[r] = sum
        r = r + 1
    }
    float scale = alpha / float(rank)
    int o = 0
    while o < output_dim {
        float delta = 0.0
        r = 0
        while r < rank {
            delta = delta + lora_b[o * rank + r] * low_rank[r]
            r = r + 1
        }
        output[o] = output[o] + scale * delta
        o = o + 1
    }
    output
}
