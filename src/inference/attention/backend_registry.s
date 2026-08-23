package neurx.inference.attention.backend_registry

func attention_cpu() int { 1 }

func attention_flash() int { 2 }

func attention_flashinfer() int { 3 }

func attention_triton() int { 4 }

func attention_flashmla() int { 5 }

func attention_rocm_aiter() int { 6 }

func attention_linear() int { 7 }

func attention_mamba() int { 8 }

func attention_sparse_mla() int { 9 }

struct attention_backend_capability {
    int backend
    string name
    string platform
    int minimum_compute_capability
    bool supports_paged_kv
    bool supports_prefix_cache
    bool supports_chunked_prefill
    bool supports_cuda_graph
    bool supports_mla
    bool supports_fp8_kv
}

struct attention_backend_request {
    string platform
    int compute_capability
    bool require_paged_kv
    bool require_mla
    bool require_fp8_kv
    bool require_cuda_graph
}

struct attention_backend_selection {
    attention_backend_capability capability
    bool found
    string error_message
}

func attention_backend_capability_for(int backend) attention_backend_capability {
    if backend == attention_cpu() {
        return attention_backend_capability {backend: backend, name: "cpu", platform: "cpu", minimum_compute_capability: 0, supports_paged_kv: true, supports_prefix_cache: true, supports_chunked_prefill: true, supports_cuda_graph: false, supports_mla: false, supports_fp8_kv: false}
    }
    if backend == attention_flash() {
        return attention_backend_capability {backend: backend, name: "flash_attention", platform: "cuda", minimum_compute_capability: 80, supports_paged_kv: true, supports_prefix_cache: true, supports_chunked_prefill: true, supports_cuda_graph: true, supports_mla: false, supports_fp8_kv: true}
    }
    if backend == attention_flashinfer() {
        return attention_backend_capability {backend: backend, name: "flashinfer", platform: "cuda", minimum_compute_capability: 80, supports_paged_kv: true, supports_prefix_cache: true, supports_chunked_prefill: true, supports_cuda_graph: true, supports_mla: true, supports_fp8_kv: true}
    }
    if backend == attention_triton() {
        return attention_backend_capability {backend: backend, name: "triton", platform: "cuda", minimum_compute_capability: 70, supports_paged_kv: true, supports_prefix_cache: true, supports_chunked_prefill: true, supports_cuda_graph: true, supports_mla: true, supports_fp8_kv: true}
    }
    if backend == attention_flashmla() {
        return attention_backend_capability {backend: backend, name: "flashmla", platform: "cuda", minimum_compute_capability: 90, supports_paged_kv: true, supports_prefix_cache: true, supports_chunked_prefill: true, supports_cuda_graph: true, supports_mla: true, supports_fp8_kv: true}
    }
    if backend == attention_rocm_aiter() {
        return attention_backend_capability {backend: backend, name: "rocm_aiter", platform: "rocm", minimum_compute_capability: 0, supports_paged_kv: true, supports_prefix_cache: true, supports_chunked_prefill: true, supports_cuda_graph: true, supports_mla: true, supports_fp8_kv: true}
    }
    if backend == attention_linear() {
        return attention_backend_capability {backend: backend, name: "linear_attention", platform: "any", minimum_compute_capability: 0, supports_paged_kv: false, supports_prefix_cache: false, supports_chunked_prefill: true, supports_cuda_graph: true, supports_mla: false, supports_fp8_kv: false}
    }
    if backend == attention_mamba() {
        return attention_backend_capability {backend: backend, name: "mamba", platform: "any", minimum_compute_capability: 0, supports_paged_kv: false, supports_prefix_cache: true, supports_chunked_prefill: true, supports_cuda_graph: true, supports_mla: false, supports_fp8_kv: false}
    }
    attention_backend_capability {backend: attention_sparse_mla(), name: "sparse_mla", platform: "cuda", minimum_compute_capability: 90, supports_paged_kv: true, supports_prefix_cache: true, supports_chunked_prefill: true, supports_cuda_graph: true, supports_mla: true, supports_fp8_kv: true}
}

func attention_backend_matches(attention_backend_capability capability, attention_backend_request request) bool {
    if capability.platform != "any" && capability.platform != request.platform { return false }
    if capability.minimum_compute_capability > request.compute_capability { return false }
    if request.require_paged_kv && !capability.supports_paged_kv { return false }
    if request.require_mla && !capability.supports_mla { return false }
    if request.require_fp8_kv && !capability.supports_fp8_kv { return false }
    if request.require_cuda_graph && !capability.supports_cuda_graph { return false }
    true
}

func select_attention_backend(attention_backend_request request) attention_backend_selection {
    int candidate = attention_cpu()
    if request.platform == "cuda" {
        if request.require_mla && request.compute_capability >= 90 { candidate = attention_flashmla() }
        else if request.compute_capability >= 80 { candidate = attention_flashinfer() }
        else { candidate = attention_triton() }
    } else if request.platform == "rocm" {
        candidate = attention_rocm_aiter()
    }
    attention_backend_capability capability = attention_backend_capability_for(candidate)
    bool found = attention_backend_matches(capability, request)
    string error_message = ""
    if !found { error_message = "no attention backend satisfies the requested capabilities" }
    attention_backend_selection {capability: capability, found: found, error_message: error_message}
}
