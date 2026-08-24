package neurx.platform.registry

struct platform_capability {
    string platform
    string device_type
    bool available
    bool supports_graph_capture
    bool supports_speculative_decode
    bool supports_multimodal
    bool supports_fp8
    bool supports_int4
    bool supports_distributed
    string distributed_backend
}

struct platform_request {
    string platform
    int requirements
}

struct platform_selection {
    int distributed_backend
    bool supported
    int error_code
}

func platform_require_graph_capture() int { 1 }

func platform_require_speculative_decode() int { 2 }

func platform_require_multimodal() int { 4 }

func platform_require_fp8() int { 8 }

func platform_require_distributed() int { 16 }

func platform_backend_none() int { 0 }

func platform_backend_nccl() int { 1 }

func platform_backend_rccl() int { 2 }

func platform_backend_ccl() int { 3 }

func platform_backend_xla() int { 4 }

func platform_backend_hccl() int { 5 }

func platform_backend_gloo() int { 6 }

func platform_requirement_enabled(int requirements, int flag) bool {
    int quotient = requirements / flag
    quotient - (quotient / 2) * 2 == 1
}

func platform_capability_for(string platform) platform_capability {
    if platform == "cuda" {
        return platform_capability {platform: platform, device_type: "gpu", available: true, supports_graph_capture: true, supports_speculative_decode: true, supports_multimodal: true, supports_fp8: true, supports_int4: true, supports_distributed: true, distributed_backend: "nccl"}
    }
    if platform == "rocm" {
        return platform_capability {platform: platform, device_type: "gpu", available: true, supports_graph_capture: true, supports_speculative_decode: true, supports_multimodal: true, supports_fp8: true, supports_int4: true, supports_distributed: true, distributed_backend: "rccl"}
    }
    if platform == "xpu" {
        return platform_capability {platform: platform, device_type: "gpu", available: true, supports_graph_capture: false, supports_speculative_decode: true, supports_multimodal: true, supports_fp8: true, supports_int4: true, supports_distributed: true, distributed_backend: "ccl"}
    }
    if platform == "tpu" {
        return platform_capability {platform: platform, device_type: "tpu", available: true, supports_graph_capture: false, supports_speculative_decode: true, supports_multimodal: true, supports_fp8: false, supports_int4: true, supports_distributed: true, distributed_backend: "xla"}
    }
    if platform == "ascend" {
        return platform_capability {platform: platform, device_type: "npu", available: true, supports_graph_capture: true, supports_speculative_decode: false, supports_multimodal: true, supports_fp8: true, supports_int4: true, supports_distributed: true, distributed_backend: "hccl"}
    }
    if platform == "cpu" {
        return platform_capability {platform: platform, device_type: "cpu", available: true, supports_graph_capture: false, supports_speculative_decode: false, supports_multimodal: true, supports_fp8: false, supports_int4: true, supports_distributed: true, distributed_backend: "gloo"}
    }
    if platform == "npu" {
        return platform_capability {platform: platform, device_type: "npu", available: true, supports_graph_capture: true, supports_speculative_decode: false, supports_multimodal: true, supports_fp8: true, supports_int4: true, supports_distributed: true, distributed_backend: "hccl"}
    }
    if platform == "musa" {
        return platform_capability {platform: platform, device_type: "gpu", available: true, supports_graph_capture: false, supports_speculative_decode: true, supports_multimodal: true, supports_fp8: true, supports_int4: true, supports_distributed: true, distributed_backend: "nccl_musa"}
    }
    if platform == "mlx" {
        return platform_capability {platform: platform, device_type: "accelerator", available: true, supports_graph_capture: false, supports_speculative_decode: true, supports_multimodal: true, supports_fp8: false, supports_int4: true, supports_distributed: false, distributed_backend: ""}
    }
    if platform == "zen" {
        return platform_capability {platform: platform, device_type: "cpu", available: true, supports_graph_capture: false, supports_speculative_decode: false, supports_multimodal: true, supports_fp8: false, supports_int4: true, supports_distributed: true, distributed_backend: "gloo"}
    }
    platform_capability {platform: platform, device_type: "unknown", available: false, supports_graph_capture: false, supports_speculative_decode: false, supports_multimodal: false, supports_fp8: false, supports_int4: false, supports_distributed: false, distributed_backend: ""}
}

func select_platform(platform_request request) platform_selection {
    if request.platform == "cuda" { return platform_selection {distributed_backend: platform_backend_nccl(), supported: true, error_code: 0} }
    if request.platform == "rocm" { return platform_selection {distributed_backend: platform_backend_rccl(), supported: true, error_code: 0} }
    if request.platform == "xpu" {
        if platform_requirement_enabled(request.requirements, platform_require_graph_capture()) { return platform_selection {distributed_backend: platform_backend_ccl(), supported: false, error_code: 2} }
        return platform_selection {distributed_backend: platform_backend_ccl(), supported: true, error_code: 0}
    }
    if request.platform == "tpu" {
        if platform_requirement_enabled(request.requirements, platform_require_graph_capture()) || platform_requirement_enabled(request.requirements, platform_require_fp8()) { return platform_selection {distributed_backend: platform_backend_xla(), supported: false, error_code: 2} }
        return platform_selection {distributed_backend: platform_backend_xla(), supported: true, error_code: 0}
    }
    if request.platform == "ascend" {
        if platform_requirement_enabled(request.requirements, platform_require_speculative_decode()) { return platform_selection {distributed_backend: platform_backend_hccl(), supported: false, error_code: 2} }
        return platform_selection {distributed_backend: platform_backend_hccl(), supported: true, error_code: 0}
    }
    if request.platform == "cpu" {
        if platform_requirement_enabled(request.requirements, platform_require_graph_capture()) || platform_requirement_enabled(request.requirements, platform_require_speculative_decode()) || platform_requirement_enabled(request.requirements, platform_require_fp8()) { return platform_selection {distributed_backend: platform_backend_gloo(), supported: false, error_code: 2} }
        return platform_selection {distributed_backend: platform_backend_gloo(), supported: true, error_code: 0}
    }
    if request.platform == "npu" {
        if platform_requirement_enabled(request.requirements, platform_require_speculative_decode()) { return platform_selection {distributed_backend: platform_backend_hccl(), supported: false, error_code: 2} }
        return platform_selection {distributed_backend: platform_backend_hccl(), supported: true, error_code: 0}
    }
    if request.platform == "musa" {
        return platform_selection {distributed_backend: platform_backend_nccl(), supported: true, error_code: 0}
    }
    if request.platform == "mlx" {
        if platform_requirement_enabled(request.requirements, platform_require_distributed()) { return platform_selection {distributed_backend: platform_backend_none(), supported: false, error_code: 2} }
        return platform_selection {distributed_backend: platform_backend_none(), supported: true, error_code: 0}
    }
    if request.platform == "zen" {
        if platform_requirement_enabled(request.requirements, platform_require_graph_capture()) || platform_requirement_enabled(request.requirements, platform_require_fp8()) { return platform_selection {distributed_backend: platform_backend_gloo(), supported: false, error_code: 2} }
        return platform_selection {distributed_backend: platform_backend_gloo(), supported: true, error_code: 0}
    }
    platform_selection {distributed_backend: platform_backend_none(), supported: false, error_code: 1}
}
