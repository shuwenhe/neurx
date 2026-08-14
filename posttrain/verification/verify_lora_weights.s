package neurx.posttrain.verification.lora_weights
use neurx.runtime.io.{
    runtime_file_exists,
    runtime_file_size,
    runtime_file_read_all,
    runtime_env_get
}
struct weight_stats {
    f64 mean
    f64 std_dev
    f64 min_val
    f64 max_val
    i32 total_elements
    i32 non_zero_elements
}

func verify_adapter_files() string {
    string adapter_path = runtime_env_get("NEURX_ADAPTER_PATH", "/home/shuwen/shuwen/posttrain/adapter")
    string result = "[LoRA Adapter Verification]\n"
    result = result + "==============================\n"
    result = result + "Path: " + adapter_path + "\n\n"
    string model_file = adapter_path + "/adapter_model.safetensors"
    if runtime_file_exists(model_file) {
        i64 size = runtime_file_size(model_file)
        f64 size_mb = f64(size) / f64(1048576)
        result = result + "✓ adapter_model.safetensors (" + string(size_mb) + " MB)\n"
    } else {
        result = result + "✗ adapter_model.safetensors NOT FOUND\n"
    }
    string config_file = adapter_path + "/adapter_config.json"
    if runtime_file_exists(config_file) {
        result = result + "✓ adapter_config.json\n"
    } else {
        result = result + "✗ adapter_config.json NOT FOUND\n"
    }
    result = result + "\n"
    return result
}

func verify_adapter_config() string {
    string adapter_path = runtime_env_get("NEURX_ADAPTER_PATH", "/home/shuwen/shuwen/posttrain/adapter")
    string config_file = adapter_path + "/adapter_config.json"
    string result = "[Adapter Configuration]\n"
    result = result + "======================\n"
    if !runtime_file_exists(config_file) {
        result = result + "✗ Config file not found\n"
        return result
    }
    string config_content = runtime_file_read_all(config_file)
    if config_content == "" {
        result = result + "✗ Failed to read config\n"
        return result
    }
    result = result + "Configuration Content:\n"
    result = result + "----------------------\n"
    result = result + config_content + "\n"
    result = result + "\n"
    return result
}

func verify_weight_changes() string {
    string base_model_path = runtime_env_get("NEURX_BASE_MODEL_PATH", "/home/shuwen/shuwen/model/base-model")
    string adapter_path = runtime_env_get("NEURX_ADAPTER_PATH", "/home/shuwen/shuwen/posttrain/adapter")
    string result = "[Weight Analysis]\n"
    result = result + "=================\n"
    string base_model_file = base_model_path + "/model.safetensors"
    if runtime_file_exists(base_model_file) {
        i64 base_size = runtime_file_size(base_model_file)
        f64 base_mb = f64(base_size) / 1048576.0
        result = result + "Base Model Size: " + string(base_mb) + " MB\n"
    }
    string adapter_model_file = adapter_path + "/adapter_model.safetensors"
    if runtime_file_exists(adapter_model_file) {
        i64 adapter_size = runtime_file_size(adapter_model_file)
        f64 adapter_mb = f64(adapter_size) / 1048576.0
        result = result + "Adapter Size: " + adapter_mb + " MB\n"
        result = result + "  → Expected: ~45 MB (LoRA rank 8, 11M params)\n"
        f64 efficiency = (f64(adapter_size) / (f64(base_size) + f64(adapter_size))) * 100.0
        result = result + "  → Parameter Efficiency: " + string(efficiency) + "%\n"
    }
    result = result + "\n"
    return result
}

func verify_lora_integration() string {
    string output = ""
    output = output + "\n════════════════════════════════════════════\n"
    output = output + "  LoRA Integration Verification Suite\n"
    output = output + "════════════════════════════════════════════\n\n"
    output = output + verify_adapter_files()
    output = output + verify_adapter_config()
    output = output + verify_weight_changes()
    output = output + "════════════════════════════════════════════\n"
    output = output + "  Verification Complete\n"
    output = output + "════════════════════════════════════════════\n"
    return output
}

func main() {
    string result = verify_lora_integration()
    println(result)
}
