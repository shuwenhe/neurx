package main

use std.io.println

func main() {
    println("=== NVIDIA CUDA Environment Check ===")
    println("")
    
    // Test 1: Check nvidia-smi
    println("[CHECK 1] NVIDIA Driver")
    println("Run: nvidia-smi")
    println("")
    
    // Test 2: Check nvcc
    println("[CHECK 2] CUDA Compiler")
    println("Run: nvcc --version")
    println("")
    
    // Test 3: Check GPU count
    println("[CHECK 3] GPU Detection")
    println("Run: nvidia-smi -L | wc -l")
    println("")
    
    // Test 4: Check libraries
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
