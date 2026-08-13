package neurx.platforms.registry

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
    bool require_graph_capture
    bool require_speculative_decode
    bool require_multimodal
    bool require_fp8
    bool require_distributed
}

struct platform_selection {
    platform_capability capability
    bool supported
    string error_message
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
    platform_capability {platform: platform, device_type: "unknown", available: false, supports_graph_capture: false, supports_speculative_decode: false, supports_multimodal: false, supports_fp8: false, supports_int4: false, supports_distributed: false, distributed_backend: ""}
}

func select_platform(platform_request request) platform_selection {
    platform_capability capability = platform_capability_for(request.platform)
    bool supported = capability.available
    if request.require_graph_capture && !capability.supports_graph_capture { supported = false }
    if request.require_speculative_decode && !capability.supports_speculative_decode { supported = false }
    if request.require_multimodal && !capability.supports_multimodal { supported = false }
    if request.require_fp8 && !capability.supports_fp8 { supported = false }
    if request.require_distributed && !capability.supports_distributed { supported = false }
    string error_message = ""
    if !supported { error_message = "platform does not satisfy requested capabilities" }
    platform_selection {capability: capability, supported: supported, error_message: error_message}
}
