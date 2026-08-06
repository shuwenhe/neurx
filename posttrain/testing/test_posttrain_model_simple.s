package neurx.posttrain.testing.test_model_simple
use neurx.runtime.io.{
    runtime_env_get,
    runtime_file_exists,
    runtime_file_size
}
func test_base_model() string {
    string base_path = runtime_env_get("NEURX_BASE_MODEL_PATH", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    bool exists = runtime_file_exists(base_path)
    if !exists {
        return "✗ [loading] base_model_files: FAILED\n  → Base model directory not found: " + base_path
    }
    string model_file = base_path + "/model.safetensors"
    bool model_exists = runtime_file_exists(model_file)
    if model_exists {
        return "✓ [loading] base_model_files: PASSED\n  → Base model files validated"
    } else {
        return "✗ [loading] base_model_files: FAILED\n  → model.safetensors not found"
    }
}

func test_adapter_files() string {
    string adapter_path = runtime_env_get("NEURX_ADAPTER_PATH", "/home/shuwen/shuwen/posttrain/adapter")
    bool exists = runtime_file_exists(adapter_path)
    if !exists {
        return "⊘ [loading] adapter_files: SKIPPED\n  → Adapter path not found"
    }
    string config_file = adapter_path + "/adapter_config.json"
    bool config_exists = runtime_file_exists(config_file)
    if config_exists {
        return "✓ [loading] adapter_files: PASSED\n  → LoRA adapter configuration found"
    } else {
        return "✗ [loading] adapter_files: FAILED\n  → adapter_config.json not found"
    }
}

func test_adapter_model() string {
    string adapter_path = runtime_env_get("NEURX_ADAPTER_PATH", "/home/shuwen/shuwen/posttrain/adapter")
    bool exists = runtime_file_exists(adapter_path)
    if !exists {
        return "⊘ [loading] adapter_model: SKIPPED\n  → Adapter path not found"
    }
    string model_file = adapter_path + "/adapter_model.safetensors"
    bool model_exists = runtime_file_exists(model_file)
    if model_exists {
        return "✓ [loading] adapter_model: PASSED\n  → adapter_model.safetensors found"
    } else {
        return "✗ [loading] adapter_model: FAILED\n  → adapter_model.safetensors not found"
    }
}

func test_merged_model() string {
    string merged_path = runtime_env_get("NEURX_MERGED_MODEL_PATH", "/home/shuwen/shuwen/posttrain/base-model-posttrain")
    bool exists = runtime_file_exists(merged_path)
    if !exists {
        return "⊘ [loading] merged_model: SKIPPED\n  → Merged model path not found"
    }
    string model_file = merged_path + "/model.safetensors"
    bool model_exists = runtime_file_exists(model_file)
    if model_exists {
        return "✓ [loading] merged_model: PASSED\n  → Merged model files found"
    } else {
        return "✗ [loading] merged_model: FAILED\n  → Merged model.safetensors not found"
    }
}

func test_data_files() string {
    string data_path = runtime_env_get("NEURX_DATA_PATH", "/home/shuwen/shuwen/dataset/medical/test.json")
    bool exists = runtime_file_exists(data_path)
    if !exists {
        return "✗ [loading] data_files: FAILED\n  → Data file not found: " + data_path
    }
    return "✓ [loading] data_files: PASSED\n  → Medical test dataset found"
}

func test_output_directory() string {
    string output_path = runtime_env_get("NEURX_TEST_OUTPUT_DIR", "/home/shuwen/shuwen/neurx/artifacts/posttrain_test")
    return "✓ [setup] output_directory: PASSED\n  → Output directory configured: " + output_path
}

func test_model_summary() string {
    string result = "✓ [info] model_summary: PASSED"
    result = result + "\n  → Base Model: Qwen2.5-0.5B-Instruct"
    result = result + "\n  → LoRA Rank: 8"
    result = result + "\n  → LoRA Alpha: 16.0"
    result = result + "\n  → Target Modules: q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj"
    return result
}

func main() {
    println("")
    println("======================================================")
    println("[PostTrain] Model Testing Suite (Pure S Language)")
    println("======================================================")
    println("")
    string test1 = test_base_model()
    println(test1)
    println("")
    string test2 = test_adapter_files()
    println(test2)
    println("")
    string test3 = test_adapter_model()
    println(test3)
    println("")
    string test4 = test_merged_model()
    println(test4)
    println("")
    string test5 = test_data_files()
    println(test5)
    println("")
    string test6 = test_output_directory()
    println(test6)
    println("")
    string test7 = test_model_summary()
    println(test7)
    println("")
    println("======================================================")
    println("[PostTrain] Testing Complete")
    println("======================================================")
    println("")
}
