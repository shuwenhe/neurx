package neurx.platform.diagnostics
use neurx.platform.config.{runtime_config_parse_result, get_runtime_config}
struct runtime_info_state {
    string tensor_version
    string runtime_name
    string default_device
    bool fallback_to_cpu
    bool strict_checks
    bool deterministic
    int seed
    bool has_seed
    bool cuda_available
    bool mps_available
    bool npu_available
    string env_tensor_device
    string env_fallback_to_cpu
    string env_log_level
}

struct check_result {
    string name
    bool passed
    string detail
}

func runtime_info() runtime_info_state {
    runtime_config_parse_result cfg_out = get_runtime_config()
    runtime_info_state {
        tensor_version: env_get("NEURX_VERSION", "unknown"),
        runtime_name: env_get("NEURX_RUNTIME", "s-runtime"),
        default_device: cfg_out.config.default_device,
        fallback_to_cpu: cfg_out.config.fallback_to_cpu,
        strict_checks: cfg_out.config.strict_checks,
        deterministic: cfg_out.config.deterministic,
        seed: cfg_out.config.seed,
        has_seed: cfg_out.config.has_seed,
        cuda_available: env_get("NEURX_CUDA_AVAILABLE", "0") == "1",
        mps_available: env_get("NEURX_MPS_AVAILABLE", "0") == "1",
        npu_available: env_get("NEURX_NPU_AVAILABLE", "0") == "1",
        env_tensor_device: env_get("TENSOR_DEVICE", ""),
        env_fallback_to_cpu: env_get("TENSOR_FALLBACK_TO_CPU", ""),
        env_log_level: env_get("TENSOR_LOG_LEVEL", ""),
    }
}

func new_check_result(string name, bool passed, string detail) check_result {
    check_result {
        name: name,
        passed: passed,
        detail: detail,
    }
}

func doctor(bool require_cuda, bool require_mps) []check_result {
    runtime_info_state info = runtime_info()
    []check_result out = []check_result{}
    out.push(new_check_result("runtime", true, info.runtime_name))
    out.push(new_check_result("config.default_device", true, info.default_device))
    out.push(new_check_result("cuda.extension", info.cuda_available, "available=" + string(info.cuda_available)))
    out.push(new_check_result("mps.runtime", info.mps_available, "available=" + string(info.mps_available)))
    out.push(new_check_result("npu.runtime", info.npu_available, "available=" + string(info.npu_available)))
    if require_cuda && !info.cuda_available {
        out.push(new_check_result("require_cuda", false, "CUDA is required but unavailable"))
    } else {
        out.push(new_check_result("require_cuda", true, "require_cuda=" + string(require_cuda)))
    }
    if require_mps && !info.mps_available {
        out.push(new_check_result("require_mps", false, "MPS is required but unavailable"))
    } else {
        out.push(new_check_result("require_mps", true, "require_mps=" + string(require_mps)))
    }
    out
}

func format_doctor_report([]check_result results) string {
    string out = "neurx doctor report"
    int i = 0
    while i < len(results) {
        check_result item = results[i]
        string status = "FAIL"
        if item.passed {
            status = "PASS"
        }
        out = out + "\n- [" + status + "] " + item.name + ": " + item.detail
        i = i + 1
    }
    out
}
