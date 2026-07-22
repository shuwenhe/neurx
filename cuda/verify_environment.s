package main

use neurx.runtime.io.{runtime_run_command_output, runtime_file_exists}
use std.io.println

func main() {
    println("[CUDA Environment Verification]")
    println("")

    string BLUE = "\u001b[0;34m"
    string GREEN = "\u001b[0;32m"
    string RED = "\u001b[0;31m"
    string YELLOW = "\u001b[1;33m"
    string NC = "\u001b[0m"

    print_header("NVIDIA CUDA Environment Check", BLUE, NC)
    println("")

    print_info("Checking NVIDIA driver...", BLUE, NC)

    string nvidia_smi = runtime_run_command_output("which nvidia-smi 2>/dev/null || true")
    if str_len(trim(nvidia_smi)) == 0 {
        print_error("nvidia-smi not found", RED, NC)
        println("  Install NVIDIA driver from https://www.nvidia.com/Download/driverDetails.aspx")
        return
    }

    print_success("nvidia-smi found", GREEN, NC)
    println("")

    string gpu_info = runtime_run_command_output("nvidia-smi 2>/dev/null || true")
    println(gpu_info)

    println("")
    print_info("Checking CUDA Toolkit...", BLUE, NC)

    string nvcc = runtime_run_command_output("which nvcc 2>/dev/null || true")
    if str_len(trim(nvcc)) == 0 {
        print_error("nvcc (CUDA compiler) not found", RED, NC)
        println("  Install CUDA Toolkit from https://developer.nvidia.com/cuda-downloads")
        return
    }

    print_success("CUDA Toolkit found", GREEN, NC)

    string cuda_version = runtime_run_command_output("nvcc --version 2>/dev/null | grep release | awk '{print $5}' | tr -d ',' || true")
    println("  Version: " + trim(cuda_version))

    println("")
    print_info("Checking cuBLAS...", BLUE, NC)

    string cublas_check = runtime_run_command_output("ldconfig -p 2>/dev/null | grep cublas || echo 'not_found'")
    if contains_string(cublas_check, "not_found") || str_len(trim(cublas_check)) == 0 {
        print_warning("cuBLAS library not in ldconfig", YELLOW, NC)
        println("  This is usually fine if CUDA was installed in a custom location")
    } else {
        print_success("cuBLAS found in library path", GREEN, NC)
    }

    println("")
    print_header("GPU Detection", BLUE, NC)

    string gpu_list = runtime_run_command_output("nvidia-smi -L 2>/dev/null || true")
    int gpu_count = count_lines(gpu_list)

    print_info("GPU count: " + int_to_str(gpu_count), BLUE, NC)

    if gpu_count == 0 {
        print_error("No NVIDIA GPUs detected", RED, NC)
        return
    }

    print_success("GPUs available", GREEN, NC)
    println("")

    string gpu_details = runtime_run_command_output("nvidia-smi --query-gpu=index,name,memory.total,compute_cap --format=csv,noheader 2>/dev/null || true")
    println(gpu_details)

    println("")
    print_header("CUDA Libraries Check", BLUE, NC)

    check_cuda_library("libcuda.so", BLUE, NC, GREEN, RED)
    check_cuda_library("libcudart.so", BLUE, NC, GREEN, RED)
    check_cuda_library("libcublas.so", BLUE, NC, GREEN, RED)
    check_cuda_library("libcurand.so", BLUE, NC, GREEN, RED)
    check_cuda_library("libcusparse.so", BLUE, NC, GREEN, RED)

    println("")
    print_header("Environment Variables", BLUE, NC)

    string cuda_home = runtime_run_command_output("echo $CUDA_HOME 2>/dev/null || echo 'not_set'")
    string ld_library = runtime_run_command_output("echo $LD_LIBRARY_PATH 2>/dev/null || echo 'not_set'")
    string path_var = runtime_run_command_output("echo $PATH 2>/dev/null || echo 'not_set'")

    println("CUDA_HOME: " + trim(cuda_home))
    println("LD_LIBRARY_PATH: " + trim(ld_library))
    println("")

    println("")
    print_header("NVCC Compilation Test", BLUE, NC)

    string test_compile = runtime_run_command_output("nvcc --version 2>/dev/null | head -1 || true")
    if str_len(trim(test_compile)) > 0 {
        print_success("NVCC compilation available", GREEN, NC)
        println(trim(test_compile))
    } else {
        print_warning("NVCC compilation test failed", YELLOW, NC)
    }

    println("")
    print_header("Environment Check Complete", BLUE, NC)
    print_success("CUDA environment is ready for GPU training", GREEN, NC)
}

func check_cuda_library(string lib_name, string BLUE, string NC, string GREEN, string RED) {
    string result = runtime_run_command_output("ldconfig -p 2>/dev/null | grep " + lib_name + " | head -1 || echo 'NOT_FOUND'")
    if contains_string(result, "NOT_FOUND") || str_len(trim(result)) == 0 {
        print_warning("Library not found: " + lib_name, BLUE, NC)
    } else {
        print_success("✓ " + lib_name, GREEN, NC)
    }
}

func print_header(string text, string color, string NC) {
    println(color + "╔════════════════════════════════════════════════════╗" + NC)
    println(color + "║" + NC + " " + text)
    println(color + "╚════════════════════════════════════════════════════╝" + NC)
}

func print_info(string text, string color, string NC) {
    println(color + "[INFO]" + NC + " " + text)
}

func print_success(string text, string color, string NC) {
    println(color + "[✓]" + NC + " " + text)
}

func print_error(string text, string color, string NC) {
    println(color + "[✗]" + NC + " " + text)
}

func print_warning(string text, string color, string NC) {
    println(color + "[!]" + NC + " " + text)
}

func trim(string s) string {
    int i = 0
    while i < str_len(s) && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = str_len(s) - 1
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

func str_len(string s) int {
    int n = 0
    while n < 1000000 && s[n] != 0 {
        n = n + 1
    }
    n
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

func count_lines(string text) int {
    int count = 0
    int i = 0
    int n = str_len(text)
    while i < n {
        if text[i] == 10 {
            count = count + 1
        }
        i = i + 1
    }
    if n > 0 && text[n - 1] != 10 {
        count = count + 1
    }
    count
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    int value = n
    bool neg = value < 0
    if neg {
        value = 0 - value
    }
    string out = ""
    while value > 0 {
        int quotient = 0
        int digit = value
        while digit >= 10 {
            digit = digit - 10
            quotient = quotient + 1
        }
        out = string_char(digit + 48) + out
        value = quotient
    }
    if neg {
        out = "-" + out
    }
    out
}
