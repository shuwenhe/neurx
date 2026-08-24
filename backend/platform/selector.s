package neurx.platform

import (
    "neurx.platform.registry" as registry
    "neurx.platform.config" as config
    "neurx.platform.diagnostics" as diagnostics
    "neurx.platform.errors" as errors
    "neurx.platform.logging" as logging
)

struct platform_backend {
    string name
    string device_type
    bool available
}

func get_platform_capability(string platform_name) registry.platform_capability {
    registry.platform_capability_for(platform_name)
}

func select_platform_backend(string platform_name, int requirements) registry.platform_selection {
    request = registry.platform_request { platform: platform_name, requirements: requirements }
    registry.select_platform(request)
}

func list_available_platforms() []string {
    ["cuda", "rocm", "xpu", "tpu", "ascend", "cpu"]
}

func get_device_type(string platform_name) string {
    cap = get_platform_capability(platform_name)
    cap.device_type
}

func is_platform_available(string platform_name) bool {
    cap = get_platform_capability(platform_name)
    cap.available
}

func get_distributed_backend(string platform_name) string {
    cap = get_platform_capability(platform_name)
    cap.distributed_backend
}

func supports_feature(string platform_name, int feature_flag) bool {
    cap = get_platform_capability(platform_name)
    
    if feature_flag == 1 {
        return cap.supports_graph_capture
    }
    if feature_flag == 2 {
        return cap.supports_speculative_decode
    }
    if feature_flag == 4 {
        return cap.supports_multimodal
    }
    if feature_flag == 8 {
        return cap.supports_fp8
    }
    if feature_flag == 16 {
        return cap.supports_int4
    }
    
    false
}

func detect_best_platform() string {
    if get_platform_capability("cuda").available {
        return "cuda"
    }
    if get_platform_capability("rocm").available {
        return "rocm"
    }
    if get_platform_capability("xpu").available {
        return "xpu"
    }
    if get_platform_capability("tpu").available {
        return "tpu"
    }
    if get_platform_capability("ascend").available {
        return "ascend"
    }
    "cpu"
}

func validate_platform_for_task(string platform_name, int required_features) bool {
    request = registry.platform_request { platform: platform_name, requirements: required_features }
    selection = registry.select_platform(request)
    selection.supported
}
