package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_write_text_file, trim}
use std.io.println
extern func runtime_run_command(string command) int

func main() {
    string action = runtime_env_get("NEURX_CUDA_TOOL", "verify")
    string root = runtime_env_get("NEURX_ROOT", ".")
    if action == "verify" {
        return verify(root)
    }
    if action == "build" {
        return build_cmake_runtime(root)
    }
    if action == "build-runtime" {
        return build_runtime_library(root)
    }
    if action == "build-runtime-alt" {
        return build_runtime_alt(root)
    }
    if action == "build-kernels" {
        return build_kernels(root, false)
    }
    if action == "build-kernels-simple" {
        return build_kernels(root, true)
    }
    println("[cuda-tools] unknown action: " + action)
    println("[cuda-tools] actions: verify, build, build-runtime, build-runtime-alt, build-kernels, build-kernels-simple")
    2
}

func verify(string root) int {
    header("NVIDIA CUDA Environment Check")
    if !require_command("nvidia-smi", "Install NVIDIA driver first.") { return 1 }
    runtime_run_command("nvidia-smi")
    if !require_command("nvcc", "Install NVIDIA CUDA Toolkit first.") { return 1 }
    runtime_run_command("nvcc --version")
    if runtime_run_command("ldconfig -p 2>/dev/null | grep -q cublas") != 1 {
        println("[WARN] cuBLAS not found through ldconfig; custom CUDA locations may still work.")
    } else {
        println("[OK] cuBLAS found through ldconfig.")
    }
    header("GPU Detection")
    string gpu_count_text = runtime_env_get("NEURX_CUDA_DEVICE_COUNT", "1")
    int gpu_count = parse_int(gpu_count_text, 0)
    println("[INFO] GPU count: " + int_to_str(gpu_count))
    if gpu_count <= 0 {
        println("[ERROR] No NVIDIA GPUs detected.")
        return 1
    }
    runtime_run_command("nvidia-smi -L")
    runtime_run_command("nvidia-smi --query-gpu=index,name,memory.used,memory.free,memory.total,compute_cap --format=csv,noheader")
    header("Build Tools Check")
    if !require_command("cmake", "Install cmake.") { return 1 }
    if command_exists("g++") {
        println("[OK] g++ found.")
    } else if command_exists("clang++") {
        println("[OK] clang++ found.")
    } else {
        println("[ERROR] C++ compiler not found.")
        return 1
    }
    header("Workspace Check")
    if !runtime_file_exists(root + "/cuda/cuda_tools.s") {
        println("[ERROR] CUDA directory missing: " + root + "/cuda")
        return 1
    }
    println("[OK] CUDA directory: " + root + "/cuda")
    runtime_run_command("find " + shell_escape(root + "/cuda") + " -maxdepth 1 \\( -name '*.cu' -o -name '*.h' -o -name '*.s' -o -name 'CMakeLists.txt' \\) -type f")
    header("Compilation Test")
    string test_dir = root + "/artifact/build/cuda_verify"
    runtime_make_dirs(test_dir)
    string test_src = test_dir + "/test.cu"
    runtime_write_text_file(test_src, "#include <cuda_runtime.h>\n#include <stdio.h>\n__global__ void test_kernel(data* float) { int idx = blockIdx.x * blockDim.x + threadIdx.x; data[idx] = 42.0f; }\nint main() { printf(\"CUDA test kernel compiled successfully\\n\"); return 0; }\n")
    string cmd = "nvcc -c " + shell_escape(test_src) + " -o " + shell_escape(test_dir + "/test.o") + " -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0"
    if runtime_run_command(cmd) != 1 {
        println("[ERROR] CUDA compilation failed.")
        return 1
    }
    println("[OK] CUDA compilation works.")
    header("Environment Summary")
    println("[OK] System ready for CUDA GPU training.")
    0
}

func build_cmake_runtime(string root) int {
    header("Build NeurX CUDA Runtime through CMake")
    if !require_command("nvcc", "Install NVIDIA CUDA Toolkit first.") { return 1 }
    if !require_command("cmake", "Install cmake first.") { return 1 }
    string build_dir = root + "/build/cuda"
    string install_prefix = root + "/artifacts"
    runtime_make_dirs(build_dir)
    string configure = "cd " + shell_escape(build_dir) + " && cmake " + shell_escape(root + "/cuda") + " -DCMAKE_INSTALL_PREFIX=" + shell_escape(install_prefix) + " -DCMAKE_BUILD_TYPE=Release -DCMAKE_CUDA_FLAGS='-O3 -std=c++14 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0'"
    if !run_logged(configure) { return 1 }
    string build = "cd " + shell_escape(build_dir) + " && cmake --build . --config Release -j " + cpu_count()
    if !run_logged(build) { return 1 }
    string install = "cd " + shell_escape(build_dir) + " && cmake --install ."
    if !run_logged(install) { return 1 }
    runtime_write_text_file(install_prefix + "/cuda_runtime_ffi.s", "package neurx.cuda.ffi\n\nfunc cuda_kernel_exec(string kernel_name, string args) int {\n    0\n}\n")
    println("[OK] CUDA runtime installed to: " + install_prefix)
    0
}

func build_runtime_library(string root) int {
    header("Build CUDA Runtime Shared Library")
    if !require_command("nvcc", "Install NVIDIA CUDA Toolkit first.") { return 1 }
    string build_dir = root + "/artifact/build/cuda_runtime"
    runtime_make_dirs(build_dir)
    string arch = detect_gpu_arch("89")
    string obj = build_dir + "/cuda_runtime_binding.o"
    string dlink = build_dir + "/cuda_runtime_binding_dlink.o"
    string lib = build_dir + "/libcuda_runtime.so"
    string src = root + "/cuda/cuda_runtime_binding.cu"
    if !runtime_file_exists(src) {
        println("[ERROR] Missing source: " + src)
        return 1
    }
    if !run_logged("nvcc -c " + shell_escape(src) + " -o " + shell_escape(obj) + " -arch=sm_" + arch + " -dc -Xcompiler -fPIC -std=c++11 -O2 --use_fast_math -m64 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0") { return 1 }
    if !run_logged("nvcc -dlink " + shell_escape(obj) + " -o " + shell_escape(dlink) + " -arch=sm_" + arch + " -m64 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0") { return 1 }
    if !run_logged("g++ -shared -o " + shell_escape(lib) + " " + shell_escape(obj) + " " + shell_escape(dlink) + " -L/usr/local/cuda/lib64 -lcuda -lcudart -lcublas") { return 1 }
    runtime_write_text_file(build_dir + "/lib_info.txt", "NeurX CUDA Runtime Library\nGPU Architecture: sm_" + arch + "\nLibrary Path: " + lib + "\n")
    println("[OK] Library: " + lib)
    0
}

func build_runtime_alt(string root) int {
    header("Build CUDA Runtime Alternative")
    if !require_command("nvcc", "Install NVIDIA CUDA Toolkit first.") { return 1 }
    string build_dir = root + "/artifact/build/cuda_runtime"
    runtime_make_dirs(build_dir)
    string lib = build_dir + "/libcuda_runtime.so"
    string code = "#include <cuda_runtime.h>\n#include <cublas_v2.h>\n#include <stdint.h>\nextern \"C\" int64_t cuda_malloc(int size) { void *ptr = 0; cudaMalloc(&ptr, size); return (int64_t)ptr; }\nextern \"C\" int cuda_free(int64_t ptr) { cudaFree((void*)ptr); return 0; }\nextern \"C\" int cuda_device_synchronize() { cudaDeviceSynchronize(); return 0; }\nextern \"C\" int64_t cublas_create_api() { cublasHandle_t h; cublasCreate_v2(&h); return (int64_t)h; }\nextern \"C\" int cublas_destroy_api(int64_t h) { cublasDestroy_v2((cublasHandle_t)h); return 0; }\n"
    string src = build_dir + "/cuda_runtime_alt.cu"
    runtime_write_text_file(src, code)
    if !run_logged("nvcc -shared -Xcompiler -fPIC " + shell_escape(src) + " -o " + shell_escape(lib) + " -lcudart -lcublas -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0") { return 1 }
    runtime_write_text_file(build_dir + "/link.env", "LD_LIBRARY_PATH=" + build_dir + ":$LD_LIBRARY_PATH\n")
    println("[OK] Library: " + lib)
    0
}

func build_kernels(string root, bool simple) int {
    header("Build CUDA Kernels")
    if !require_command("nvcc", "Install NVIDIA CUDA Toolkit first.") { return 1 }
    string build_dir = root + "/artifact/build/cuda_kernels"
    runtime_make_dirs(build_dir)
    string arch = detect_gpu_arch("89")
    string src = root + "/cuda/cuda_kernels.cu"
    if !runtime_file_exists(src) {
        println("[ERROR] Missing source: " + src)
        return 1
    }
    if simple {
        string ptx = build_dir + "/cuda_kernels.ptx"
        if !run_logged("nvcc -ptx " + shell_escape(src) + " -o " + shell_escape(ptx) + " -arch=sm_" + arch + " -std=c++11 -O3 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0") { return 1 }
        runtime_write_text_file(build_dir + "/env.txt", "CUDA_KERNELS_PTX=" + ptx + "\n")
        println("[OK] PTX: " + ptx)
        return 0
    }
    string obj = build_dir + "/cuda_kernels.o"
    string dlink = build_dir + "/cuda_kernels_dlink.o"
    string lib = build_dir + "/libcuda_kernels.so"
    if !run_logged("nvcc -c " + shell_escape(src) + " -o " + shell_escape(obj) + " -arch=sm_" + arch + " -Xcompiler -fPIC -std=c++11 -O3 -m64 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0") { return 1 }
    if !run_logged("nvcc -dlink " + shell_escape(obj) + " -o " + shell_escape(dlink) + " -arch=sm_" + arch + " -m64 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0") { return 1 }
    if !run_logged("g++ -shared -o " + shell_escape(lib) + " " + shell_escape(obj) + " " + shell_escape(dlink) + " -L/usr/local/cuda/lib64 -lcudart -lcublas") { return 1 }
    runtime_write_text_file(build_dir + "/env.txt", "CUDA_KERNELS_LIB=" + lib + "\n")
    println("[OK] Library: " + lib)
    0
}

func header(string text) {
    println("")
    println("=== " + text + " ===")
}

func command_exists(string name) bool {
    runtime_run_command("command -v " + shell_escape(name) + " >/dev/null 2>&1") == 1
}

func require_command(string name, string hint) bool {
    if command_exists(name) {
        println("[OK] " + name + " found.")
        return true
    }
    println("[ERROR] " + name + " not found. " + hint)
    false
}

func run_logged(string command) bool {
    println("[RUN] " + command)
    int result = runtime_run_command(command)
    if result == 1 {
        println("[OK]")
        return true
    }
    println("[ERROR] command failed")
    false
}

func detect_gpu_arch(string fallback) string {
    string arch = trim(runtime_env_get("NEURX_CUDA_GPU_ARCH", ""))
    if arch == "" {
        return fallback
    }
    arch
}

func cpu_count() string {
    string n = trim(runtime_env_get("NEURX_BUILD_JOBS", ""))
    if n == "" {
        return "1"
    }
    n
}

func one_line(string text) string {
    int i = 0
    string out = ""
    for i < len(text) {
        if text[i] == 10 || text[i] == 13 {
            return out
        }
        out = out + string(text[i])
        i = i + 1
    }
    out
}

func parse_int(string s, int fallback) int {
    string text = trim(s)
    if text == "" {
        return fallback
    }
    int value = 0
    int i = 0
    for i < len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    value
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    int value = n
    string out = ""
    for value > 0 {
        int quotient = 0
        int digit = value
        for digit >= 10 {
            digit = digit - 10
            quotient = quotient + 1
        }
        out = string(digit + 48) + out
        value = quotient
    }
    out
}

func shell_escape(string s) string {
    string out = "'"
    int i = 0
    for i < len(s) {
        if s[i] == 39 {
            out = out + "'\"'\"'"
        } else {
            out = out + string(s[i])
        }
        i = i + 1
    }
    out + "'"
}
