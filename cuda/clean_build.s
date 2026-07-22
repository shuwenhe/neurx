

package main

use std.io.println
use neurx.runtime.io.runtime_run_command_output

func main() {
    println("[CLEAN] Removing CUDA build artifacts...")
    println("")

    remove_dir("./artifacts/build/cuda_kernels")
    remove_dir("./artifacts/build/cuda_runtime")
    remove_dir("./artifacts/build/verify_env")

    println("")
    println("[SUCCESS] Cleaned all CUDA build artifacts")
}

func remove_dir(string path) {
    runtime_run_command_output("rm -rf " + path + " 2>&1")
    println("[OK] Removed: " + path)
}
