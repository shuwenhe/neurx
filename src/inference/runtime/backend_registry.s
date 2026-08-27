package neurx.inference.runtime.backend_registry

struct inference_backend_capability {
    string backend_name
    string device_type
    string[] attention_kernels
    string[] dtypes
    bool paged_attention
    bool graph_decode
    bool tensor_parallel
    bool pipeline_parallel
    bool kv_transfer
    bool multimodal
    int priority
    bool available
}

struct backend_requirement {
    string preferred_backend
    string dtype
    string attention_kernel
    bool require_paged_attention
    bool require_graph_decode
    bool require_tensor_parallel
    bool require_kv_transfer
    bool require_multimodal
}

struct backend_registry_state {
    []inference_backend_capability backends
}

struct backend_selection_result {
    inference_backend_capability backend
    bool selected
    string error_message
}

func empty_backend_capability() inference_backend_capability {
    inference_backend_capability backend
    backend.backend_name = ""
    backend.device_type = ""
    backend.attention_kernels = []
    backend.dtypes = []
    backend.paged_attention = false
    backend.graph_decode = false
    backend.tensor_parallel = false
    backend.pipeline_parallel = false
    backend.kv_transfer = false
    backend.multimodal = false
    backend.priority = 0
    backend.available = false
    backend
}

func new_backend_selection_result(inference_backend_capability backend, bool selected, string error_message) backend_selection_result {
    backend_selection_result result
    result.backend = backend
    result.selected = selected
    result.error_message = error_message
    result
}

func new_backend_registry() backend_registry_state {
    backend_registry_state state
    state.backends = []inference_backend_capability{cap: 16}
    state
}

func backend_capability_at(backend_registry_state state, int index) inference_backend_capability {
    state.backends[index]
}

func backend_string_at(string[] values, int index) string {
    values[index]
}

func backend_contains(string[] values, string expected) bool {
    int i = 0
    for i < len(values) {
        string value = backend_string_at(values, i)
        if value == expected {
            return true
        }
        i = i + 1
    }
    false
}

func backend_register(backend_registry_state state, inference_backend_capability backend) backend_registry_state {
    if backend.backend_name == "" {
        return state
    }
    int i = 0
    for i < len(state.backends) {
        inference_backend_capability existing = backend_capability_at(state, i)
        if existing.backend_name == backend.backend_name {
            state.backends[i] = backend
            return state
        }
        i = i + 1
    }
    state.backends = append(state.backends, backend)
    state
}

func backend_set_available(backend_registry_state state, string backend_name, bool available) backend_registry_state {
    int i = 0
    for i < len(state.backends) {
        inference_backend_capability backend = backend_capability_at(state, i)
        if backend.backend_name == backend_name {
            backend.available = available
            state.backends[i] = backend
            return state
        }
        i = i + 1
    }
    state
}

func backend_matches(inference_backend_capability backend, backend_requirement requirement) bool {
    if !backend.available {
        return false
    }
    if requirement.preferred_backend != "" && backend.backend_name != requirement.preferred_backend {
        return false
    }
    if requirement.dtype != "" && !backend_contains(backend.dtypes, requirement.dtype) {
        return false
    }
    if requirement.attention_kernel != "" && !backend_contains(backend.attention_kernels, requirement.attention_kernel) {
        return false
    }
    if requirement.require_paged_attention && !backend.paged_attention {
        return false
    }
    if requirement.require_graph_decode && !backend.graph_decode {
        return false
    }
    if requirement.require_tensor_parallel && !backend.tensor_parallel {
        return false
    }
    if requirement.require_kv_transfer && !backend.kv_transfer {
        return false
    }
    if requirement.require_multimodal && !backend.multimodal {
        return false
    }
    true
}

func backend_select(backend_registry_state state, backend_requirement requirement) backend_selection_result {
    int selected_index = -1
    int selected_priority = -2147483647
    int i = 0
    for i < len(state.backends) {
        inference_backend_capability backend = backend_capability_at(state, i)
        if backend_matches(backend, requirement) && backend.priority > selected_priority {
            selected_index = i
            selected_priority = backend.priority
        }
        i = i + 1
    }
    if selected_index < 0 {
        return new_backend_selection_result(empty_backend_capability(), false, "no backend satisfies request requirements")
    }
    new_backend_selection_result(backend_capability_at(state, selected_index), true, "")
}

func backend_cpu_capability() inference_backend_capability {
    inference_backend_capability backend
    backend.backend_name = "cpu"
    backend.device_type = "cpu"
    backend.attention_kernels = ["reference"]
    backend.dtypes = ["fp32"]
    backend.paged_attention = false
    backend.graph_decode = false
    backend.tensor_parallel = false
    backend.pipeline_parallel = false
    backend.kv_transfer = true
    backend.multimodal = true
    backend.priority = 10
    backend.available = true
    backend
}

func backend_cuda_capability(bool available) inference_backend_capability {
    inference_backend_capability backend
    backend.backend_name = "cuda"
    backend.device_type = "gpu"
    backend.attention_kernels = ["flash_attention", "flashinfer", "paged_attention"]
    backend.dtypes = ["fp16", "bf16", "fp8", "int8", "int4"]
    backend.paged_attention = true
    backend.graph_decode = true
    backend.tensor_parallel = true
    backend.pipeline_parallel = true
    backend.kv_transfer = true
    backend.multimodal = true
    backend.priority = 100
    backend.available = available
    backend
}

func backend_ascend_capability(bool available) inference_backend_capability {
    inference_backend_capability backend
    backend.backend_name = "ascend"
    backend.device_type = "npu"
    backend.attention_kernels = ["cann_paged_attention", "cann_flash_attention"]
    backend.dtypes = ["fp16", "bf16", "int8"]
    backend.paged_attention = true
    backend.graph_decode = true
    backend.tensor_parallel = true
    backend.pipeline_parallel = false
    backend.kv_transfer = true
    backend.multimodal = true
    backend.priority = 90
    backend.available = available
    backend
}

func default_backend_registry(bool cuda_available, bool ascend_available) backend_registry_state {
    backend_registry_state state = new_backend_registry()
    state = backend_register(state, backend_cuda_capability(cuda_available))
    state = backend_register(state, backend_ascend_capability(ascend_available))
    state = backend_register(state, backend_cpu_capability())
    state
}
