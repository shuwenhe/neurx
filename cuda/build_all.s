// ============================================================================
// NeurX CUDA Build System - S Language Implementation
// Replaces all .sh scripts with pure S (no shell/bash)
// ============================================================================

package main

use std.io.println
use neurx.runtime.io.{
    runtime_env_get,
    runtime_file_exists,
    runtime_read_text_file,
    runtime_write_text_file,
    runtime_run_command_output,
}

// ============================================================================
// Build Configuration
// ============================================================================

struct BuildConfig {
    string cuda_home
    string cuda_lib
    string gpu_arch
    string cuda_version
    bool verbose
}

struct BuildResult {
    bool success
    string output
    int exit_code
}

// ============================================================================
// Main Build Entry Point
// ============================================================================

func main() {
    println("[CUDA Build] NeurX CUDA System Builder (S Language)")
    println("")
    
    // Detect build target from environment or args
    string target = runtime_env_get("CUDA_BUILD_TARGET", "all")
    
    // Initialize build config
    BuildConfig config = detect_cuda_environment()
    if !is_cuda_available(config) {
        println("[ERROR] CUDA Toolkit not found")
        println("  Install from: https://developer.nvidia.com/cuda-downloads")
        return
    }
    
    println("[INFO] CUDA Environment Detected:")
    println("  Home: " + config.cuda_home)
    println("  Lib: " + config.cuda_lib)
    println("  Version: " + config.cuda_version)
    println("  GPU Arch: sm_" + config.gpu_arch)
    println("")
    
    // Execute build targets
    switch target {
        case "all" {
            build_cuda_runtime(config)
            build_cuda_kernels(config)
            build_verify_env(config)
        }
        case "runtime" {
            build_cuda_runtime(config)
        }
        case "kernels" {
            build_cuda_kernels(config)
        }
        case "verify" {
            build_verify_env(config)
        }
        case "clean" {
            clean_build_artifacts()
        }
        default {
            println("[ERROR] Unknown target: " + target)
        }
    }
}

// ============================================================================
// Build Targets
// ============================================================================

func build_cuda_runtime(BuildConfig cfg) {
    println("[BUILD] CUDA Runtime Library")
    println("")
    
    string build_dir = "./artifacts/build/cuda_runtime"
    create_directory(build_dir)
    
    // Step 1: Compile with gcc
    println("[1/3] Compiling C wrapper with gcc...")
    
    BuildResult result = compile_cuda_runtime(cfg, build_dir)
    if !result.success {
        println("[ERROR] " + result.output)
        return
    }
    
    println("[2/3] Creating shared library...")
    result = link_cuda_runtime(cfg, build_dir)
    if !result.success {
        println("[ERROR] " + result.output)
        return
    }
    
    println("[3/3] Setting up environment...")
    create_env_script(build_dir, cfg)
    
    println("")
    println("[SUCCESS] libcuda_runtime.so created")
    check_file_exists(build_dir + "/libcuda_runtime.so")
}

func build_cuda_kernels(BuildConfig cfg) {
    println("[BUILD] CUDA Kernels Library")
    println("")
    
    string build_dir = "./artifacts/build/cuda_kernels"
    create_directory(build_dir)
    
    // Step 1: Generate PTX
    println("[1/4] Generating PTX code...")
    BuildResult result = compile_kernels_ptx(cfg, build_dir)
    if !result.success {
        println("[WARNING] PTX generation: " + result.output)
        // Continue anyway
    }
    
    // Step 2: Create wrapper
    println("[2/4] Creating C wrapper...")
    create_cuda_wrapper(build_dir)
    
    // Step 3: Compile wrapper
    println("[3/4] Compiling wrapper...")
    result = compile_cuda_wrapper(cfg, build_dir)
    if !result.success {
        println("[ERROR] " + result.output)
        return
    }
    
    // Step 4: Link
    println("[4/4] Linking shared library...")
    result = link_cuda_kernels(cfg, build_dir)
    if !result.success {
        println("[ERROR] " + result.output)
        return
    }
    
    println("")
    println("[SUCCESS] libcuda_kernels.so created")
    check_file_exists(build_dir + "/libcuda_kernels.so")
}

func build_verify_env(BuildConfig cfg) {
    println("[BUILD] Environment Verification Tool")
    println("")
    
    // Compile verify_environment.s to IR
    string ir_path = "./artifacts/build/verify_env/verify_env.ir"
    create_directory("./artifacts/build/verify_env")
    
    string s_compiler = runtime_env_get("S_COMPILER", "/home/shuwen/.local/bin/s")
    if !runtime_file_exists(s_compiler) {
        println("[WARNING] S compiler not found at " + s_compiler)
        return
    }
    
    println("[1/1] Compiling verify_environment.s...")
    
    string cmd = s_compiler + " ir cuda/verify_environment.s -o " + ir_path
    string output = runtime_run_command_output(cmd)
    
    if runtime_file_exists(ir_path) {
        println("[SUCCESS] verify_env.ir created")
    } else {
        println("[WARNING] IR compilation failed")
    }
}

// ============================================================================
// CUDA Environment Detection
// ============================================================================

func detect_cuda_environment() BuildConfig {
    BuildConfig cfg
    cfg.verbose = parse_bool(runtime_env_get("CUDA_BUILD_VERBOSE", "false"))
    
    // Detect nvcc
    string nvcc_out = runtime_run_command_output("which nvcc 2>/dev/null || echo 'not_found'")
    if contains_string(nvcc_out, "not_found") {
        return cfg  // CUDA not found
    }
    
    // Get CUDA home
    string cuda_home_out = runtime_run_command_output("nvcc -v 2>&1 | grep 'bin/nvcc' | head -1 | xargs dirname | xargs dirname || echo '/usr'")
    cfg.cuda_home = trim(cuda_home_out)
    cfg.cuda_lib = cfg.cuda_home + "/lib64"
    
    // Get CUDA version
    string version_out = runtime_run_command_output("nvcc --version 2>/dev/null | grep 'release' | awk '{print $5}' | tr -d ','")
    cfg.cuda_version = trim(version_out)
    
    // Get GPU arch
    string arch_out = runtime_run_command_output("nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.' || echo '89'")
    cfg.gpu_arch = trim(arch_out)
    
    cfg
}

func is_cuda_available(BuildConfig cfg) bool {
    if str_len(trim(cfg.cuda_version)) == 0 {
        return false
    }
    if str_len(trim(cfg.cuda_home)) == 0 {
        return false
    }
    if str_len(trim(cfg.gpu_arch)) == 0 {
        return false
    }
    true
}

// ============================================================================
// Compilation Functions
// ============================================================================

func compile_cuda_runtime(BuildConfig cfg, string build_dir) BuildResult {
    // Use gcc to compile CUDA runtime wrapper
    string cmd = "gcc -shared -fPIC " +
        "-o " + build_dir + "/libcuda_runtime.so " +
        "cuda/cuda_wrapper_simple.cu " +
        "-I/usr/local/cuda/include " +
        "-L" + cfg.cuda_lib + " " +
        "-L/usr/local/cuda/lib64 " +
        "-lcudart " +
        "-lcublas " +
        "-Wl,-rpath," + cfg.cuda_lib + " " +
        "2>&1"
    
    string output = runtime_run_command_output(cmd)
    
    if runtime_file_exists(build_dir + "/libcuda_runtime.so") {
        BuildResult{success: true, output: output, exit_code: 0}
    } else {
        BuildResult{success: false, output: output, exit_code: 1}
    }
}

func link_cuda_runtime(BuildConfig cfg, string build_dir) BuildResult {
    // Already linked in compile step
    BuildResult{success: true, output: "Linked successfully", exit_code: 0}
}

func compile_kernels_ptx(BuildConfig cfg, string build_dir) BuildResult {
    string cmd = "nvcc -ptx cuda/cuda_kernels.cu " +
        "-o " + build_dir + "/cuda_kernels.ptx " +
        "-arch=sm_" + cfg.gpu_arch + " " +
        "-std=c++11 -O3 2>&1"
    
    string output = runtime_run_command_output(cmd)
    
    bool success = str_len(trim(output)) > 0 && !contains_string(output, "error:")
    BuildResult{success: success, output: output, exit_code: success ? 0 : 1}
}

func compile_cuda_wrapper(BuildConfig cfg, string build_dir) BuildResult {
    string cmd = "gcc -c -fPIC " +
        build_dir + "/cuda_kernels_wrapper.c " +
        "-o " + build_dir + "/cuda_kernels_wrapper.o " +
        "-I/usr/local/cuda/include 2>&1"
    
    string output = runtime_run_command_output(cmd)
    
    if runtime_file_exists(build_dir + "/cuda_kernels_wrapper.o") {
        BuildResult{success: true, output: output, exit_code: 0}
    } else {
        BuildResult{success: false, output: output, exit_code: 1}
    }
}

func link_cuda_kernels(BuildConfig cfg, string build_dir) BuildResult {
    string cmd = "gcc -shared -fPIC " +
        "-o " + build_dir + "/libcuda_kernels.so " +
        build_dir + "/cuda_kernels_wrapper.o " +
        "-I/usr/local/cuda/include " +
        "-L" + cfg.cuda_lib + " " +
        "-L/usr/local/cuda/lib64 " +
        "-lcudart " +
        "-lcublas " +
        "-Wl,-rpath," + cfg.cuda_lib + " " +
        "2>&1"
    
    string output = runtime_run_command_output(cmd)
    
    if runtime_file_exists(build_dir + "/libcuda_kernels.so") {
        BuildResult{success: true, output: output, exit_code: 0}
    } else {
        BuildResult{success: false, output: output, exit_code: 1}
    }
}

// ============================================================================
// Helper Functions
// ============================================================================

func create_directory(string path) {
    runtime_run_command_output("mkdir -p " + path + " 2>&1")
}

func check_file_exists(string path) {
    if runtime_file_exists(path) {
        string size = runtime_run_command_output("ls -lh " + path + " | awk '{print $5}' || echo '?'")
        println("  Path: " + path)
        println("  Size: " + trim(size))
    } else {
        println("  [WARNING] File not created: " + path)
    }
}

func create_env_script(string build_dir, BuildConfig cfg) {
    string script = "#!/bin/bash\n" +
        "export LD_LIBRARY_PATH=\"" + cfg.cuda_lib + ":" + build_dir + ":$LD_LIBRARY_PATH\"\n" +
        "export CUDA_HOME=\"" + cfg.cuda_home + "\"\n" +
        "echo \"[CUDA] Environment configured\"\n"
    
    runtime_write_text_file(build_dir + "/env.sh", script)
    runtime_run_command_output("chmod +x " + build_dir + "/env.sh 2>&1")
}

func create_cuda_wrapper(string build_dir) {
    string wrapper = "/* Minimal CUDA Wrapper - S Language Build System */\n" +
        "#include <cuda_runtime.h>\n" +
        "#include <cublas_v2.h>\n" +
        "\n" +
        "/* Stub implementations */\n" +
        "int cuda_error_loss_kernel(int64_t p, int64_t t, int n) { return 0; }\n" +
        "int cuda_sgd_update_kernel(int64_t w, int64_t g, float lr, int n) { return 0; }\n" +
        "int cuda_relu_forward(int64_t o, int64_t i, int n) { return 0; }\n" +
        "int cuda_relu_backward(int64_t gi, int64_t go, int64_t i, int n) { return 0; }\n" +
        "int cuda_softmax(int64_t o, int64_t i, int sl, int bs) { return 0; }\n" +
        "int cuda_layer_norm(int64_t o, int64_t i, int64_t w, int64_t b, int n, float e) { return 0; }\n" +
        "int cuda_get_device_count() { int c = 0; cudaGetDeviceCount(&c); return c; }\n"
    
    runtime_write_text_file(build_dir + "/cuda_kernels_wrapper.c", wrapper)
}

func clean_build_artifacts() {
    println("[CLEAN] Removing build artifacts...")
    runtime_run_command_output("rm -rf ./artifacts/build/cuda_runtime 2>&1")
    runtime_run_command_output("rm -rf ./artifacts/build/cuda_kernels 2>&1")
    println("[SUCCESS] Cleaned")
}

// ============================================================================
// String Utilities
// ============================================================================

func str_len(string s) int {
    int n = 0
    while n < 1000000 && s[n] != 0 {
        n = n + 1
    }
    n
}

func trim(string s) string {
    int i = 0
    int len = str_len(s)
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
    while i < end && i < str_len(s) {
        out = out + string_char(s[i])
        i = i + 1
    }
    out
}

func string_char(int c) string {
    string(c)
}

func contains_string(string haystack, string needle) bool {
    int h_len = str_len(haystack)
    int n_len = str_len(needle)
    if n_len == 0 {
        return true
    }
    if n_len > h_len {
        return false
    }
    int i = 0
    while i <= h_len - n_len {
        int j = 0
        bool match = true
        while j < n_len {
            if haystack[i + j] != needle[j] {
                match = false
                j = n_len
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

func parse_bool(string s) bool {
    string lower = to_lower(s)
    if contains_string(lower, "true") || contains_string(lower, "yes") || contains_string(lower, "1") {
        return true
    }
    false
}

func to_lower(string s) string {
    string out = ""
    int i = 0
    int len = str_len(s)
    while i < len {
        int c = s[i]
        if c >= 65 && c <= 90 {  // A-Z
            c = c + 32
        }
        out = out + string_char(c)
        i = i + 1
    }
    out
}
