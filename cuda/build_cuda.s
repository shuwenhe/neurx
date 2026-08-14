package main
use std.io.println
use neurx.runtime.io.{
    runtime_env_get,
    runtime_file_exists,
    runtime_run_command_output,
}
func main() {
    println("[CUDA Manager] NeurX GPU Build System")
    println("")
    string target = runtime_env_get("CUDA_TARGET", "build-all")
    if eq_string(target, "build-kernels") {
        build_kernels()
    } else if eq_string(target, "build-runtime") {
        build_runtime()
    } else if eq_string(target, "build-verify") {
        build_verify()
    } else if eq_string(target, "build-all") {
        build_all()
    } else if eq_string(target, "clean") {
        clean_all()
    } else if eq_string(target, "verify-env") {
        verify_environment()
    } else {
        println("[INFO] Usage: CUDA_TARGET=[build-all|build-kernels|build-runtime|clean|verify-env]")
        build_all()
    }
}

func build_all() {
    println("[BUILD] Complete CUDA System")
    build_kernels()
    build_runtime()
    build_verify()
}

func build_kernels() {
    println("[BUILD] CUDA Kernels")
    execute_s_script("cuda/build_kernels_simple.s")
}

func build_runtime() {
    println("[BUILD] CUDA Runtime")
    execute_s_script("cuda/build_cuda_runtime.s")
}

func build_verify() {
    println("[BUILD] Environment Verification")
    execute_s_script("cuda/verify_environment.s")
}

func clean_all() {
    println("[CLEAN] CUDA Build Artifacts")
    execute_s_script("cuda/clean_build.s")
}

func verify_environment() {
    println("[VERIFY] CUDA Environment")
    string nvcc_out = runtime_run_command_output("which nvcc 2>/dev/null || echo 'not_found'")
    if contains_string(nvcc_out, "not_found") {
        println("[ERROR] nvcc not found")
        println("  Install CUDA Toolkit from:")
        println("  https:
        return
    }
    println("[OK] nvcc found: " + trim(nvcc_out))
    string cuda_home = get_cuda_home()
    if !runtime_file_exists(cuda_home + "/lib64/libcudart.so") &&
       !runtime_file_exists("/usr/local/cuda/lib64/libcudart.so") {
        println("[ERROR] CUDA Runtime library not found")
        return
    }
    println("[OK] CUDA Runtime library found")
    string cublas_check = runtime_run_command_output("ldconfig -p 2>/dev/null | grep cublas || echo 'not_found'")
    if contains_string(cublas_check, "not_found") {
        println("[WARNING] cuBLAS may not be installed")
    } else {
        println("[OK] cuBLAS found")
    }
    string gpu_check = runtime_run_command_output("nvidia-smi -L 2>/dev/null | head -1 || echo 'not_found'")
    if contains_string(gpu_check, "not_found") {
        println("[WARNING] GPU not detected")
    } else {
        println("[OK] GPU detected: " + trim(gpu_check))
    }
    println("[SUCCESS] CUDA environment verified")
}

func execute_s_script(string script_path) {
    string s_compiler = runtime_env_get("S_COMPILER", "/home/shuwen/.local/bin/s")
    if !runtime_file_exists(s_compiler) {
        println("[ERROR] S compiler not found at " + s_compiler)
        println("  Set S_COMPILER environment variable")
        return
    }
    if !runtime_file_exists(script_path) {
        println("[ERROR] Script not found: " + script_path)
        return
    }
    string ir_file = script_path
    string cmd = s_compiler + " ir " + script_path + " -o " + ir_file + ".ir && s_runner " + ir_file + ".ir"
    string output = runtime_run_command_output(cmd)
    if str_len(trim(output)) > 0 {
        println(output)
    }
}

func get_cuda_home() string {
    string cuda_home = trim(runtime_env_get("CUDA_HOME", ""))
    if str_len(cuda_home) > 0 {
        return cuda_home
    }
    if runtime_file_exists("/usr/local/cuda/include/cuda.h") {
        return "/usr/local/cuda"
    }
    "/usr"
}

func contains_string(string haystack, string needle) bool {
    int h_len = str_len(haystack)
    int n_len = str_len(needle)
    if n_len == 0 || n_len > h_len {
        return false
    }
    int i = 0
    while i <= h_len - n_len {
        int j = 0
        bool match = true
        while j < n_len && match {
            if haystack[i + j] != needle[j] {
                match = false
            }
            j = j + 1
        }
        if match {
            return true
        }
        i = i + 1
    }
    false
}

func eq_string(string a, string b) bool {
    int a_len = str_len(a)
    int b_len = str_len(b)
    if a_len != b_len {
        return false
    }
    int i = 0
    while i < a_len {
        if a[i] != b[i] {
            return false
        }
        i = i + 1
    }
    true
}

func str_len(string s) int {
    int n = 0
    while n < 10000000 && s[n] != 0 {
        n = n + 1
    }
    n
}

func trim(string s) string {
    int len = str_len(s)
    int i = 0
    while i < len && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = len - 1
    while j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    substring(s, i, j + 1)
}

func substring(string s, int start, int end) string {
    string out = ""
    int i = start
    int len = str_len(s)
    while i < end && i < len {
        out = out + chr(s[i])
        i = i + 1
    }
    out
}

func chr(int code) string {
    string(code)
}
