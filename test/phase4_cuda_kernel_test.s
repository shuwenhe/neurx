package test_phase4_cuda_kernels

// Phase 4 Test Suite: CUDA Kernel Execution Verification

extern "intrinsic" func __host_slice(string text, int start, int end) string

// CUDA FFI functions
extern "libc:neurx_s_cuda_device_count" func cuda_device_count() int
extern "libc:neurx_s_cuda_device_name" func cuda_device_name() string
extern "libc:neurx_s_cuda_last_error" func cuda_last_error() string
extern "libc:neurx_s_cuda_initialize" func cuda_initialize(string model_path, int device_id) int
extern "libc:neurx_s_cuda_begin" func cuda_begin(string prompt, int max_tokens) int
extern "libc:neurx_s_cuda_next" func cuda_next() int
extern "libc:neurx_s_cuda_result" func cuda_result() string

func int_to_string(int n) string {
    if n == 0 { return "0" }
    if n < 0 { return "-" + int_to_string(-n) }
    
    digits := "0123456789"
    result := ""
    num := n
    for num > 0 {
        result = __host_slice(digits, num % 10, num % 10 + 1) + result
        num = num / 10
    }
    result
}

func test_device_detection() bool {
    print("Test 1: CUDA Device Detection\n")
    count := cuda_device_count()
    if count <= 0 {
        print("  FAILED: No CUDA devices detected\n")
        return false
    }
    print("  PASSED: Detected ")
    print(int_to_string(count))
    print(" device(s)\n")
    
    device_name := cuda_device_name()
    print("  GPU: ")
    print(device_name)
    print("\n")
    return true
}

func test_model_initialization() bool {
    print("Test 2: Model Initialization\n")
    
    model_path := "/home/shuwen/model/Qwen2.5-0.5B-Instruct"
    result := cuda_initialize(model_path, 0)
    
    if result != 0 {
        error := cuda_last_error()
        print("  FAILED: ")
        print(error)
        print("\n")
        return false
    }
    
    print("  PASSED: Model initialized\n")
    return true
}

func test_inference_basic() bool {
    print("Test 3: Inference Execution\n")
    
    prompt := "What is AI?"
    result := cuda_begin(prompt, 16)
    if result < 0 {
        error := cuda_last_error()
        print("  FAILED: ")
        print(error)
        print("\n")
        return false
    }
    
    print("  PASSED: Inference started\n")
    return true
}

func test_token_generation() bool {
    print("Test 4: Token Generation\n")
    
    token_count := 0
    for token_count < 3 {
        token_id := cuda_next()
        if token_id < 0 {
            error := cuda_last_error()
            print("  FAILED: ")
            print(error)
            print("\n")
            return false
        }
        if token_id == 0 {
            break
        }
        token_count = token_count + 1
    }
    
    print("  PASSED: Generated ")
    print(int_to_string(token_count))
    print(" tokens\n")
    return true
}

func test_result_retrieval() bool {
    print("Test 5: Result Retrieval\n")
    
    result := cuda_result()
    if len(result) == 0 {
        print("  FAILED: Empty result\n")
        return false
    }
    
    print("  PASSED: Result length = ")
    print(int_to_string(len(result)))
    print("\n")
    return true
}

func main() {
    print("Phase 4: CUDA Kernel Execution Tests\n\n")
    
    passed := 0
    total := 5
    
    if test_device_detection() { passed = passed + 1 }
    print("\n")
    
    if test_model_initialization() { passed = passed + 1 }
    print("\n")
    
    if test_inference_basic() { passed = passed + 1 }
    print("\n")
    
    if test_token_generation() { passed = passed + 1 }
    print("\n")
    
    if test_result_retrieval() { passed = passed + 1 }
    
    print("\nPassed: ")
    print(int_to_string(passed))
    print("/")
    print(int_to_string(total))
    print("\n")
}
