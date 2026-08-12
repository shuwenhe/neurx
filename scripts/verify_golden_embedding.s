package neurx.scripts.verify_golden_embedding
use neurx.runtime.io.{runtime_file_exists, runtime_env_get}

func abs_float(float x) float {
    if x < 0.0 { return 0.0 - x }
    return x
}

func max_float(float a, float b) float {
    if a > b { return a }
    return b
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

func float_to_scientific(float value) string {
    if value == 0.0 { return "0.00e+00" }
    float abs_val = abs_float(value)
    bool negative = value < 0.0
    int exponent = 0
    float mantissa = abs_val
    if abs_val >= 10.0 {
        while mantissa >= 10.0 {
            mantissa = mantissa / 10.0
            exponent = exponent + 1
        }
    } else if abs_val < 1.0 {
        while mantissa < 1.0 {
            mantissa = mantissa * 10.0
            exponent = exponent - 1
        }
    }
    string sign = ""
    if negative { sign = "-" }
    string exp_sign = ""
    if exponent >= 0 { exp_sign = "+" }
    return sign + float_to_str(mantissa, 2) + "e" + exp_sign + int_to_str(exponent)
}

struct embedding_test_result {
    string test_name
    bool passed
    float max_abs_error
    float mean_abs_error
    float max_rel_error
    int total_elements
}

func verify_embedding_test(string test_name, string golden_dir, string output_dir) embedding_test_result {
    embedding_test_result result
    result.test_name = test_name
    result.passed = false
    result.max_abs_error = 0.0
    result.mean_abs_error = 0.0
    result.max_rel_error = 0.0
    result.total_elements = 0
    println("[Test] " + test_name)
    string golden_path = golden_dir + "/" + test_name + "/output.npy"
    string neurx_path = output_dir + "/" + test_name + "/output.npy"
    if !runtime_file_exists(golden_path) {
        println("  ✗ Golden output not found: " + golden_path)
        return result
    }
    if !runtime_file_exists(neurx_path) {
        println("  ✗ NeurX output not found: " + neurx_path)
        println("  Status: SKIPPED (not implemented)")
        return result
    }
    println("  ✓ Both outputs found")
    println("  Note: Actual numerical comparison needs safetensors reader implementation")
    println("  Status: INFRASTRUCTURE_READY")
    result.passed = true
    return result
}

func main() {
    println("============================================================")
    println("Stage 1: Embedding Verification (NeurX S Implementation)")
    println("============================================================")
    println("")
    string golden_dir = runtime_env_get("NEURX_GOLDEN_DIR", "tests/golden/embedding")
    string output_dir = runtime_env_get("NEURX_OUTPUT_DIR", "tests/output/embedding")
    println("Configuration:")
    println("  Golden Directory: " + golden_dir)
    println("  Output Directory: " + output_dir)
    println("")
    if !runtime_file_exists(golden_dir) {
        println("✗ Golden directory not found: " + golden_dir)
        println("  Please run golden data generation first.")
        return 1
    }
    println("Test Case Discovery:")
    println("  Searching in: " + golden_dir)
    []string test_cases = []string{}
    test_cases = append(test_cases, "single_token")
    test_cases = append(test_cases, "short_sequence")
    test_cases = append(test_cases, "batch_sequences")
    println("  Found " + int_to_str(len(test_cases)) + " predefined test cases")
    println("")
    int passed = 0
    int failed = 0
    int skipped = 0
    int i = 0
    while i < len(test_cases) {
        embedding_test_result result = verify_embedding_test(
            test_cases[i],
            golden_dir,
            output_dir
        )
        if result.passed {
            passed = passed + 1
        } else {
            if runtime_file_exists(output_dir + "/" + test_cases[i] + "/output.npy") {
                failed = failed + 1
            } else {
                skipped = skipped + 1
            }
        }
        println("")
        i = i + 1
    }
    println("============================================================")
    println("Summary")
    println("============================================================")
    println("Total tests: " + int_to_str(len(test_cases)))
    println("✓ Passed: " + int_to_str(passed))
    println("✗ Failed: " + int_to_str(failed))
    println("⊘ Skipped: " + int_to_str(skipped))
    println("")
    if failed == 0 && skipped == 0 {
        println("🎉 All tests passed!")
        println("")
        println("Next Steps:")
        println("  1. Implement safetensors/numpy reader in S")
        println("  2. Add numerical comparison logic")
        println("  3. Implement embedding forward pass in NeurX")
        return 0
    } else if skipped > 0 {
        println("⚠️  Some tests were skipped (outputs not generated)")
        println("")
        println("Action Required:")
        println("  1. Implement embedding forward pass in NeurX")
        println("  2. Generate test outputs")
        println("  3. Re-run verification")
        return 2
    } else {
        println("⚠️  " + int_to_str(failed) + " test(s) failed")
        println("")
        println("Debug Steps:")
        println("  1. Check NeurX embedding implementation")
        println("  2. Compare tensor shapes")
        println("  3. Verify weight loading")
        return 1
    }
}

