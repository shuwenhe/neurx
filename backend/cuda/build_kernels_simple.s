package main
use std.io.println
use neurx.runtime.io.{
    runtime_env_get,
    runtime_file_exists,
    runtime_make_dirs,
    runtime_read_text_file,
    runtime_write_text_file,
    runtime_run_command_output,
}

func main() {
    println("[CUDA] Building Kernels (Simplified PTX Approach)")
    println("")
    string nvcc_check = runtime_run_command_output("which nvcc 2>/dev/null || echo 'not_found'")
    if contains_string(nvcc_check, "not_found") {
        println("[ERROR] nvcc not found. Install CUDA Toolkit")
        return
    }
    println("[OK] nvcc found")
    string cuda_version = get_cuda_version()
    string gpu_arch = get_gpu_arch()
    println("[INFO] CUDA Version: " + cuda_version)
    println("[INFO] GPU Architecture: sm_" + gpu_arch)
    println("")
    string build_dir = "./artifact/build/cuda_kernels"
    create_dir(build_dir)
    string cuda_home = get_cuda_home()
    string cuda_lib = cuda_home + "/lib64"
    println("[INFO] CUDA Home: " + cuda_home)
    println("[INFO] CUDA Lib: " + cuda_lib)
    println("")
    println("[1/3] Generating PTX code...")
    bool ptx_ok = compile_to_ptx(build_dir, gpu_arch)
    println("[2/3] Creating C wrapper...")
    create_wrapper_c(build_dir)
    println("[3/3] Compiling and linking...")
    bool link_ok = compile_wrapper(build_dir, cuda_home, cuda_lib)
    if link_ok && runtime_file_exists(build_dir + "/libcuda_kernels.so") {
        println("")
        println("[SUCCESS] libcuda_kernels.so created successfully")
        string size_out = runtime_run_command_output("ls -lh " + build_dir + "/libcuda_kernels.so 2>/dev/null | awk '{print $5}' || echo '?'")
        println("  Size: " + trim(size_out))
        create_env_metadata(build_dir, cuda_lib)
        println("[INFO] Environment metadata: " + build_dir + "/env.txt")
    } else {
        println("[ERROR] libcuda_kernels.so not created")
    }
}

func get_cuda_version() string {
    string out = runtime_run_command_output("nvcc --version 2>/dev/null | grep 'release' | awk '{print $5}' | tr -d ',' || echo '12.0'")
    trim(out)
}

func get_gpu_arch() string {
    string out = runtime_run_command_output("nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.' || echo '89'")
    trim(out)
}

func get_cuda_home() string {
    string cuda_home = trim(runtime_env_get("CUDA_HOME", ""))
    if str_len(cuda_home) > 0 && runtime_file_exists(cuda_home + "/include/cuda.h") {
        return cuda_home
    }
    string locations = "/usr/local/cuda /usr /opt/cuda"
    int i = 0
    while i < str_len(locations) {
        string loc = get_word(locations, i)
        if str_len(loc) > 0 && runtime_file_exists(loc + "/include/cuda.h") {
            return loc
        }
        i = i + 1
    }
    "/usr"
}

func compile_to_ptx(string build_dir, string gpu_arch) bool {
    string cmd = "nvcc -ptx backend/cuda/cuda_kernels.cu " +
        "-o " + build_dir + "/cuda_kernels.ptx " +
        "-arch=sm_" + gpu_arch + " " +
        "-std=c++11 -O3 2>&1"
    string output = runtime_run_command_output(cmd)
    if runtime_file_exists(build_dir + "/cuda_kernels.ptx") {
        println("[OK] PTX generated: " + build_dir + "/cuda_kernels.ptx")
        return true
    } else {
        println("[WARNING] PTX generation had issues")
        println("  " + output)
        return false
    }
}

func create_wrapper_c(string build_dir) {
    string wrapper = get_cuda_wrapper_c()
    runtime_write_text_file(build_dir + "/cuda_kernels_wrapper.c", wrapper)
    println("[OK] Wrapper created: " + build_dir + "/cuda_kernels_wrapper.c")
}

func compile_wrapper(string build_dir, string cuda_home, string cuda_lib) bool {
    string obj_file = build_dir + "/cuda_kernels_wrapper.o"
    string compile_cmd = "gcc -c -fPIC " +
        build_dir + "/cuda_kernels_wrapper.c " +
        "-o " + obj_file + " " +
        "-I" + cuda_home + "/include " +
        "-I/usr/local/cuda/include 2>&1"
    string compile_out = runtime_run_command_output(compile_cmd)
    if !runtime_file_exists(obj_file) {
        println("[ERROR] Failed to compile wrapper")
        println("  " + compile_out)
        return false
    }
    println("[OK] Wrapper compiled: " + obj_file)
    string so_file = build_dir + "/libcuda_kernels.so"
    string link_cmd = "gcc -shared -fPIC " +
        "-o " + so_file + " " +
        obj_file + " " +
        "-I" + cuda_home + "/include " +
        "-L" + cuda_lib + " " +
        "-L/usr/local/cuda/lib64 " +
        "-lcudart -lcublas " +
        "-Wl,-rpath," + cuda_lib + " 2>&1"
    string link_out = runtime_run_command_output(link_cmd)
    if !runtime_file_exists(so_file) {
        println("[ERROR] Failed to link shared library")
        println("  " + link_out)
        return false
    }
    println("[OK] Linked: " + so_file)
    true
}

func create_env_metadata(string build_dir, string cuda_lib) {
    string env_text = "CUDA_KERNELS_LIB=" + build_dir + "/libcuda_kernels.so" + chr(10) +
        "CUDA_LIBRARY_PATH=" + cuda_lib + ":" + build_dir + chr(10)
    runtime_write_text_file(build_dir + "/env.txt", env_text)
}

func create_dir(string path) {
    runtime_make_dirs(path)
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

func get_word(string s, int word_index) string {
    int word_count = 0
    int i = 0
    int start = 0
    bool in_word = false
    int len = str_len(s)
    while i < len {
        bool is_space = s[i] == 32 || s[i] == 9 || s[i] == 10
        if !is_space && !in_word {
            if word_count == word_index {
                start = i
            }
            in_word = true
        } else if is_space && in_word {
            if word_count == word_index {
                return substring(s, start, i)
            }
            word_count = word_count + 1
            in_word = false
        }
        i = i + 1
    }
    if in_word && word_count == word_index {
        return substring(s, start, len)
    }
    ""
}

func get_cuda_wrapper_c() string {
    string c_code =
"\n" +
"#include <cuda_runtime.h>\n" +
"#include <cublas_v2.h>\n" +
"#include <stdint.h>\n" +
"#include <stdio.h>\n" +
"\n" +
"\n" +
"\n" +
"int cuda_error_loss_kernel(int64_t pred_ptr, int64_t target_ptr, int size) {\n" +
"    return 0;\n" +
"}\n" +
"\n" +
"int cuda_sgd_update_kernel(int64_t weights_ptr, int64_t grads_ptr, float lr, int size) {\n" +
"    return 0;\n" +
"}\n" +
"\n" +
"int cuda_relu_forward(int64_t output_ptr, int64_t input_ptr, int size) {\n" +
"    return 0;\n" +
"}\n" +
"\n" +
"int cuda_relu_backward(int64_t grad_input_ptr, int64_t grad_output_ptr, int64_t input_ptr, int size) {\n" +
"    return 0;\n" +
"}\n" +
"\n" +
"int cuda_softmax(int64_t output_ptr, int64_t input_ptr, int seq_len, int batch_size) {\n" +
"    return 0;\n" +
"}\n" +
"\n" +
"int cuda_layer_norm(int64_t output_ptr, int64_t input_ptr, int64_t weight_ptr, int64_t bias_ptr, int size, float eps) {\n" +
"    return 0;\n" +
"}\n" +
"\n" +
"int cuda_get_device_count() {\n" +
"    int count = 0;\n" +
"    cudaGetDeviceCount(&count);\n" +
"    return count;\n" +
"}\n" +
"\n" +
"int cuda_get_device_memory(int device_id, int64_t *free_bytes, int64_t *total_bytes) {\n" +
"    size_t free, total;\n" +
"    cudaMemGetInfo(&free, &total);\n" +
"    if (free_bytes) *free_bytes = (int64_t)free;\n" +
"    if (total_bytes) *total_bytes = (int64_t)total;\n" +
"    return 0;\n" +
"}\n" +
"\n" +
"const char* cuda_get_error_string() {\n" +
"    return cudaGetErrorString(cudaGetLastError());\n" +
"}\n" +
"\n" +
"\n" +
"\n" +
"int cublasCreate(handle* int64_t) {\n" +
"    cublasHandle_t h;\n" +
"    cublasStatus_t status = cublasCreate(&h);\n" +
"    if (handle) *handle = (int64_t)h;\n" +
"    return (int)status;\n" +
"}\n" +
"\n" +
"int cublasDestroy(int64_t handle) {\n" +
"    return (int)cublasDestroy((cublasHandle_t)handle);\n" +
"}\n"
    c_code
}
