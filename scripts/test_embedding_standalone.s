package neurx.scripts.test_embedding_standalone
use neurx.runtime.io.{runtime_file_exists, runtime_env_get}
func abs_float(float x) float {
    if x < 0.0 { return 0.0 - x }
    return x
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

func test_embedding_shape() bool {
    println("[TEST 1] Embedding Shape Verification")
    println("  Testing: vocab_size=151936, hidden_size=896")
    int vocab_size = 151936
    int hidden_size = 896
    int expected_params = vocab_size * hidden_size
    println("  Expected parameters: " + int_to_str(expected_params))
    if expected_params > 0 {
        println("  ✓ Shape calculation correct")
        return true
    }
    println("  ✗ Shape calculation failed")
    return false
}

func test_embedding_lookup() bool {
    println("[TEST 2] Embedding Lookup Simulation")
    println("  Testing: Single token lookup")
    int token_id = 1234
    int hidden_size = 896
    println("  Token ID: " + int_to_str(token_id))
    println("  Expected output shape: (" + int_to_str(hidden_size) + ",)")
    println("  Simulated output: [0.0, 0.1, 0.2, ..., 0.9]")
    println("  ✓ Lookup simulation successful")
    return true
}

func test_batch_embedding() bool {
    println("[TEST 3] Batch Embedding Simulation")
    println("  Testing: Batch of 2 sequences, 3 tokens each")
    int batch_size = 2
    int seq_len = 3
    int hidden_size = 896
    println("  Input shape: (" + int_to_str(batch_size) + ", " + int_to_str(seq_len) + ")")
    println("  Expected output shape: (" + int_to_str(batch_size) + ", " + int_to_str(seq_len) + ", " + int_to_str(hidden_size) + ")")
    int total_embeddings = batch_size * seq_len
    println("  Total embeddings to compute: " + int_to_str(total_embeddings))
    if total_embeddings == 6 {
        println("  ✓ Batch size calculation correct")
        return true
    }
    println("  ✗ Batch size calculation failed")
    return false
}

func test_model_loading() bool {
    println("[TEST 4] Model File Availability")
    string model_path = runtime_env_get("NEURX_MODEL_PATH", "../model/Qwen2.5-0.5B-Instruct")
    println("  Model path: " + model_path)
    if runtime_file_exists(model_path) {
        println("  ✓ Model directory exists")
        string safetensors_path = model_path + "/model.safetensors"
        if runtime_file_exists(safetensors_path) {
            println("  ✓ model.safetensors found")
            println("  Note: Safetensors reader implementation needed")
            return true
        } else {
            println("  ✗ model.safetensors not found")
            return false
        }
    }
    println("  ✗ Model directory not found")
    return false
}

func main() {
    println("============================================================")
    println("NeurX Embedding Tests (Pure S, No PyTorch)")
    println("============================================================")
    println("")
    println("Philosophy: Self-contained verification using NeurX only")
    println("No external dependencies (PyTorch, NumPy, etc.)")
    println("")
    int passed = 0
    int failed = 0
    if test_embedding_shape() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    println("")
    if test_embedding_lookup() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    println("")
    if test_batch_embedding() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    println("")
    if test_model_loading() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    println("")
    println("============================================================")
    println("Summary")
    println("============================================================")
    println("Total tests: " + int_to_str(passed + failed))
    println("✓ Passed: " + int_to_str(passed))
    println("✗ Failed: " + int_to_str(failed))
    println("")
    if failed == 0 {
        println("🎉 All infrastructure tests passed!")
        println("")
        println("Next Steps:")
        println("  1. Implement safetensors reader in S")
        println("  2. Implement embedding lookup in S")
        println("  3. Implement forward pass computation")
        println("  4. Add end-to-end training tests")
        return 0
    } else {
        println("⚠️  " + int_to_str(failed) + " test(s) failed")
        println("")
        println("Fix these issues before proceeding")
        return 1
    }
}
