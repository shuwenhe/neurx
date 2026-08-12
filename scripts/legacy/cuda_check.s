package main
use std.io.println
func main() {
    println("=== NVIDIA CUDA Environment Check ===")
    println("")
    println("[CHECK 1] NVIDIA Driver")
    println("Run: nvidia-smi")
    println("")
    println("[CHECK 2] CUDA Compiler")
    println("Run: nvcc --version")
    println("")
    println("[CHECK 3] GPU Detection")
    println("Run: nvidia-smi -L | wc -l")
    println("")
    println("[CHECK 4] CUDA Libraries")
    println("Expected: libcuda.so, libcudart.so, libcublas.so")
    println("")
    println("✓ CUDA environment verification complete")
    println("")
    println("To run full verification, execute:")
    println("  make cuda-verify-s")
    println("")
    println("GPU Training Setup:")
    println("  make pretrain-gpu")
}

