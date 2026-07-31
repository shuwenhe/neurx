package main
use std.io.println
use neurx.runtime.io.{
    runtime_env_get,
    runtime_file_exists,
    runtime_make_dirs,
    runtime_run_command_output,
    runtime_write_text_file,
}
func main() {
    println("[CUDA Runtime] Building CUDA Runtime Library")
    println("")
    string build_dir = "./artifacts/build/cuda_runtime"
    create_dir(build_dir)
    string cuda_home = get_cuda_home()
    string cuda_lib = cuda_home + "/lib64"
    println("[INFO] CUDA Home: " + cuda_home)
    println("[INFO] CUDA Lib: " + cuda_lib)
    println("")
    println("[1/2] Compiling CUDA Runtime wrapper...")
    string cmd = "gcc -shared -fPIC " +
        "-o " + build_dir + "/libcuda_runtime.so " +
        "cuda/cuda_wrapper_simple.cu " +
        "-I" + cuda_home + "/include " +
        "-I/usr/local/cuda/include " +
        "-L" + cuda_lib + " " +
        "-L/usr/local/cuda/lib64 " +
        "-lcudart -lcublas " +
        "-Wl,-rpath," + cuda_lib + " 2>&1"
    string output = runtime_run_command_output(cmd)
    if !runtime_file_exists(build_dir + "/libcuda_runtime.so") {
        println("[ERROR] Compilation failed")
        println("  " + output)
        return
    }
    println("[OK] Runtime compiled")
    println("[2/2] Creating environment metadata...")
    create_runtime_env_metadata(build_dir, cuda_lib)
    println("")
    println("[SUCCESS] libcuda_runtime.so created")
    string size_info = runtime_run_command_output("ls -lh " + build_dir + "/libcuda_runtime.so 2>/dev/null | awk '{print $5}' || echo '?'")
    println("  Size: " + trim(size_info))
}

func get_cuda_home() string {
    string cuda_home = trim(runtime_env_get("CUDA_HOME", ""))
    if str_len(cuda_home) > 0 && runtime_file_exists(cuda_home + "/include/cuda.h") {
        return cuda_home
    }
    if runtime_file_exists("/usr/local/cuda/include/cuda.h") {
        return "/usr/local/cuda"
    }
    if runtime_file_exists("/usr/include/cuda.h") {
        return "/usr"
    }
    "/usr"
}

func create_runtime_env_metadata(string build_dir, string cuda_lib) {
    string text = "CUDA_RUNTIME_LIB=" + build_dir + "/libcuda_runtime.so" + chr(10) +
        "CUDA_LIBRARY_PATH=" + cuda_lib + ":" + build_dir + chr(10)
    runtime_write_text_file(build_dir + "/env.txt", text)
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

func escape_quotes(string s) string {
    s
}
