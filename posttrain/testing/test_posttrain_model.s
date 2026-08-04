package neurx.posttrain.testing.test_model

use neurx.runtime.io.{
    runtime_env_get,
    runtime_file_exists,
    runtime_make_dirs,
    runtime_file_size,
    runtime_read_file,
    runtime_write_file,
    runtime_time_now,
    runtime_time_elapsed
}

struct TestResult {
    string name
    string category
    string status      // "passed", "failed", "skipped"
    float duration
    string message
    []string details
}

struct TestResults {
    []TestResult results
    string start_time
    string end_time
    int passed
    int failed
    int skipped
}

func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool negative = false
    if value < 0 {
        negative = true
        value = 0 - value
    }
    string out = ""
    while value > 0 {
        int digit = value - (value / 10) * 10
        if digit == 0 { out = "0" + out }
        else if digit == 1 { out = "1" + out }
        else if digit == 2 { out = "2" + out }
        else if digit == 3 { out = "3" + out }
        else if digit == 4 { out = "4" + out }
        else if digit == 5 { out = "5" + out }
        else if digit == 6 { out = "6" + out }
        else if digit == 7 { out = "7" + out }
        else if digit == 8 { out = "8" + out }
        else { out = "9" + out }
        value = value / 10
    }
    if negative { out = "-" + out }
    return out
}

func float_to_str(float value, int decimals) string {
    float current = value
    bool negative = current < 0.0
    if negative { current = 0.0 - current }
    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string result = int_to_str(whole)
    if decimals > 0 {
        result = result + "."
        int i = 0
        while i < decimals {
            current = current * 10.0
            int digit = 0
            while current >= 1.0 {
                current = current - 1.0
                digit = digit + 1
            }
            if digit == 0 { result = result + "0" }
            else if digit == 1 { result = result + "1" }
            else if digit == 2 { result = result + "2" }
            else if digit == 3 { result = result + "3" }
            else if digit == 4 { result = result + "4" }
            else if digit == 5 { result = result + "5" }
            else if digit == 6 { result = result + "6" }
            else if digit == 7 { result = result + "7" }
            else if digit == 8 { result = result + "8" }
            else { result = result + "9" }
            i = i + 1
        }
    }
    if negative { result = "-" + result }
    return result
}

func repeat_char(string ch, int count) string {
    string result = ""
    int i = 0
    while i < count {
        result = result + ch
        i = i + 1
    }
    return result
}

func print_header(string title) void {
    println("============================================================")
    println(title)
    println("============================================================")
}

func print_result(string category, string name, string status, string message) void {
    string symbol = "?"
    if status == "passed" { symbol = "✓" }
    else if status == "failed" { symbol = "✗" }
    else if status == "skipped" { symbol = "⊘" }
    
    string status_upper = "UNKNOWN"
    if status == "passed" { status_upper = "PASSED" }
    else if status == "failed" { status_upper = "FAILED" }
    else if status == "skipped" { status_upper = "SKIPPED" }
    
    println(symbol + " [" + category + "] " + name + ": " + status_upper)
    if message != "" {
        println("  → " + message)
    }
}

func test_base_model_files() TestResult {
    print_header("[Test 1] Base Model Files Validation")
    
    string base_path = runtime_env_get("NEURX_BASE_MODEL_PATH")
    if base_path == "" {
        base_path = "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct"
    }
    
    bool exists = runtime_file_exists(base_path)
    
    TestResult result
    result.name = "base_model_files"
    result.category = "loading"
    result.message = ""
    
    if !exists {
        result.status = "failed"
        result.message = "Base model directory not found: " + base_path
        print_result(result.category, result.name, result.status, result.message)
        return result
    }
    
    string model_file = base_path + "/model.safetensors"
    bool model_exists = runtime_file_exists(model_file)
    
    if model_exists {
        result.status = "passed"
        result.message = "Base model files validated"
        print_result(result.category, result.name, result.status, result.message)
        return result
    } else {
        result.status = "failed"
        result.message = "model.safetensors not found"
        print_result(result.category, result.name, result.status, result.message)
        return result
    }
}

func test_adapter_config() TestResult {
    print_header("[Test 2] Adapter Configuration Verification")
    
    string adapter_path = runtime_env_get("NEURX_ADAPTER_PATH")
    if adapter_path == "" {
        adapter_path = "/home/shuwen/shuwen/posttrain/adapter"
    }
    
    bool exists = runtime_file_exists(adapter_path)
    
    TestResult result
    result.name = "adapter_config"
    result.category = "loading"
    result.message = ""
    
    if !exists {
        result.status = "skipped"
        result.message = "Adapter path not found"
        print_result(result.category, result.name, result.status, result.message)
        return result
    }
    
    string config_file = adapter_path + "/adapter_config.json"
    bool config_exists = runtime_file_exists(config_file)
    
    if config_exists {
        result.status = "passed"
        result.message = "LoRA adapter configuration found"
        print_result(result.category, result.name, result.status, result.message)
        return result
    } else {
        result.status = "failed"
        result.message = "adapter_config.json not found"
        print_result(result.category, result.name, result.status, result.message)
        return result
    }
}

func test_adapter_model_files() TestResult {
    print_header("[Test 3] Adapter Model Files")
    
    string adapter_path = runtime_env_get("NEURX_ADAPTER_PATH")
    if adapter_path == "" {
        adapter_path = "/home/shuwen/shuwen/posttrain/adapter"
    }
    
    bool exists = runtime_file_exists(adapter_path)
    
    TestResult result
    result.name = "adapter_files"
    result.category = "loading"
    result.message = ""
    
    if !exists {
        result.status = "skipped"
        result.message = "Adapter path not found"
        print_result(result.category, result.name, result.status, result.message)
        return result
    }
    
    string model_file = adapter_path + "/adapter_model.safetensors"
    bool model_exists = runtime_file_exists(model_file)
    
    if model_exists {
        float size_bytes = runtime_file_size(model_file)
        float size_mb = size_bytes / (1024.0 * 1024.0)
        string msg = "adapter_model.safetensors found (" + float_to_str(size_mb, 2) + " MB)"
        result.status = "passed"
        result.message = msg
        print_result(result.category, result.name, result.status, result.message)
        return result
    } else {
        result.status = "failed"
        result.message = "adapter_model.safetensors not found"
        print_result(result.category, result.name, result.status, result.message)
        return result
    }
}

func test_merged_model_files() TestResult {
    print_header("[Test 4] Merged Model Files")
    
    string merged_path = runtime_env_get("NEURX_MERGED_MODEL_PATH")
    if merged_path == "" {
        merged_path = "/home/shuwen/shuwen/posttrain/base-model-posttrain"
    }
    
    bool exists = runtime_file_exists(merged_path)
    
    TestResult result
    result.name = "merged_model"
    result.category = "loading"
    result.message = ""
    
    if !exists {
        result.status = "skipped"
        result.message = "Merged model path not found"
        print_result(result.category, result.name, result.status, result.message)
        return result
    }
    
    string model_file = merged_path + "/model.safetensors"
    bool model_exists = runtime_file_exists(model_file)
    
    if model_exists {
        float size_bytes = runtime_file_size(model_file)
        float size_mb = size_bytes / (1024.0 * 1024.0)
        string msg = "Merged model ready (" + float_to_str(size_mb, 2) + " MB)"
        result.status = "passed"
        result.message = msg
        print_result(result.category, result.name, result.status, result.message)
        return result
    } else {
        result.status = "failed"
        result.message = "model.safetensors not found in merged model"
        print_result(result.category, result.name, result.status, result.message)
        return result
    }
}

func test_data_files() TestResult {
    print_header("[Test 5] Medical MCQ Data Files")
    
    string data_path = runtime_env_get("NEURX_DATA_PATH")
    if data_path == "" {
        data_path = "/home/shuwen/shuwen/dataset/medical/test.json"
    }
    
    bool exists = runtime_file_exists(data_path)
    
    TestResult result
    result.name = "data_files"
    result.category = "data"
    result.message = ""
    
    if !exists {
        result.status = "skipped"
        result.message = "Data file not found: " + data_path
        print_result(result.category, result.name, result.status, result.message)
        return result
    }
    
    float size_bytes = runtime_file_size(data_path)
    float size_mb = size_bytes / (1024.0 * 1024.0)
    string msg = "Medical MCQ data found (" + float_to_str(size_mb, 2) + " MB)"
    
    result.status = "passed"
    result.message = msg
    print_result(result.category, result.name, result.status, result.message)
    return result
}

func test_output_directory() TestResult {
    print_header("[Test 6] Output Directory Structure")
    
    string output_dir = runtime_env_get("NEURX_TEST_OUTPUT_DIR")
    if output_dir == "" {
        output_dir = "/home/shuwen/shuwen/neurx/artifacts/posttrain_test"
    }
    
    TestResult result
    result.name = "directory_structure"
    result.category = "setup"
    result.message = ""
    
    runtime_make_dirs(output_dir)
    runtime_make_dirs(output_dir + "/checkpoints")
    runtime_make_dirs(output_dir + "/logs")
    runtime_make_dirs(output_dir + "/results")
    
    result.status = "passed"
    result.message = "Output directories created"
    print_result(result.category, result.name, result.status, result.message)
    return result
}

func test_model_summary() TestResult {
    print_header("[Test 7] Model Summary Report")
    
    string base_path = runtime_env_get("NEURX_BASE_MODEL_PATH")
    if base_path == "" {
        base_path = "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct"
    }
    
    string adapter_path = runtime_env_get("NEURX_ADAPTER_PATH")
    if adapter_path == "" {
        adapter_path = "/home/shuwen/shuwen/posttrain/adapter"
    }
    
    string merged_path = runtime_env_get("NEURX_MERGED_MODEL_PATH")
    if merged_path == "" {
        merged_path = "/home/shuwen/shuwen/posttrain/base-model-posttrain"
    }
    
    TestResult result
    result.name = "model_summary"
    result.category = "summary"
    result.message = ""
    
    string summary = "\n"
    summary = summary + "Model Paths:\n"
    summary = summary + "  Base:   " + base_path + "\n"
    summary = summary + "  Adapter: " + adapter_path + "\n"
    summary = summary + "  Merged:  " + merged_path + "\n"
    
    float base_size = runtime_file_size(base_path + "/model.safetensors")
    float adapter_size = runtime_file_size(adapter_path + "/adapter_model.safetensors")
    float merged_size = runtime_file_size(merged_path + "/model.safetensors")
    
    if base_size > 0.0 {
        summary = summary + "\nFile Sizes:\n"
        summary = summary + "  Base model:   " + float_to_str(base_size / (1024.0 * 1024.0), 2) + " MB\n"
    }
    
    if adapter_size > 0.0 {
        summary = summary + "  LoRA adapter: " + float_to_str(adapter_size / (1024.0 * 1024.0), 2) + " MB\n"
    }
    
    if merged_size > 0.0 {
        summary = summary + "  Merged model: " + float_to_str(merged_size / (1024.0 * 1024.0), 2) + " MB\n"
    }
    
    println(summary)
    
    result.status = "passed"
    result.message = "Model summary generated"
    print_result(result.category, result.name, result.status, result.message)
    return result
}

func print_final_summary(int passed, int failed, int skipped) void {
    println("\n" + repeat_char("=", 60))
    println("TEST SUMMARY")
    println(repeat_char("=", 60))
    
    int total = passed + failed + skipped
    string msg = "\nTotal: " + int_to_str(total) + 
                 " | Passed: " + int_to_str(passed) + 
                 " | Failed: " + int_to_str(failed) + 
                 " | Skipped: " + int_to_str(skipped) + "\n"
    println(msg)
    
    if total > 0 {
        float percentage = (float(passed) / float(total)) * 100.0
        println("Success Rate: " + float_to_str(percentage, 1) + "%")
    }
    
    println(repeat_char("=", 60) + "\n")
}

func main() void {
    println("\n")
    println("╔" + repeat_char("═", 58) + "╗")
    println("║" + repeat_char(" ", 15) + "PostTrain Model Test Suite (S Language)" + repeat_char(" ", 3) + "║")
    println("╚" + repeat_char("═", 58) + "╝")
    
    TestResult result1 = test_base_model_files()
    TestResult result2 = test_adapter_config()
    TestResult result3 = test_adapter_model_files()
    TestResult result4 = test_merged_model_files()
    TestResult result5 = test_data_files()
    TestResult result6 = test_output_directory()
    TestResult result7 = test_model_summary()
    
    int passed = 0
    int failed = 0
    int skipped = 0
    
    if result1.status == "passed" { passed = passed + 1 }
    else if result1.status == "failed" { failed = failed + 1 }
    else { skipped = skipped + 1 }
    
    if result2.status == "passed" { passed = passed + 1 }
    else if result2.status == "failed" { failed = failed + 1 }
    else { skipped = skipped + 1 }
    
    if result3.status == "passed" { passed = passed + 1 }
    else if result3.status == "failed" { failed = failed + 1 }
    else { skipped = skipped + 1 }
    
    if result4.status == "passed" { passed = passed + 1 }
    else if result4.status == "failed" { failed = failed + 1 }
    else { skipped = skipped + 1 }
    
    if result5.status == "passed" { passed = passed + 1 }
    else if result5.status == "failed" { failed = failed + 1 }
    else { skipped = skipped + 1 }
    
    if result6.status == "passed" { passed = passed + 1 }
    else if result6.status == "failed" { failed = failed + 1 }
    else { skipped = skipped + 1 }
    
    if result7.status == "passed" { passed = passed + 1 }
    else if result7.status == "failed" { failed = failed + 1 }
    else { skipped = skipped + 1 }
    
    print_final_summary(passed, failed, skipped)
    
    println("✓ PostTrain model testing completed")
}

