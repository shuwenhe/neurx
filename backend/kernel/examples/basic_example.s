package neurx.kernels.examples.basic_example

import (
    "neurx.kernels.types"
    "neurx.kernels.matrix_kernels"
    "neurx.kernels.activation_kernels"
    "neurx.kernels.norm_kernels"
    "neurx.kernels.kernel_launcher"
)

func BasicMatrixExample() {
    println("\n=== Basic Matrix Operations Example ===\n")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    matrix_kernel := matrix_kernels.NewMatrixKernels(config)

    m := i32(512)
    n := i32(512)
    k := i32(512)

    A := make([]f32, m * k)
    B := make([]f32, k * n)
    C := make([]f32, m * n)

    for i := 0; i < len(A); i += 1 {
        A[i] = f32(1.0)
    }

    for i := 0; i < len(B); i += 1 {
        B[i] = f32(1.0)
    }

    println("Executing GEMM...")
    result := matrix_kernel.GEMM(m, n, k, 1.0, A, k, B, n, 0.0, *C, n)

    if result.success {
        println("✅ GEMM succeeded")
        println("  Execution Time: ", result.execution_time_ms, " ms")
        println("  FLOPs: ", result.stats.flops)
    } else {
        println("❌ GEMM failed: ", result.error_message)
    }
}

func ActivationExample() {
    println("\n=== Activation Function Example ===\n")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    activation_kernel := activation_kernels.NewActivationKernels(config)

    input := make([]f32, 1024)
    output := make([]f32, 1024)

    for i := 0; i < len(input); i += 1 {
        input[i] = f32(i) / 512.0 - f32(1.0)
    }

    activations := [6]types.ActivationType{
        types.ActivationType.relu,
        types.ActivationType.gelu,
        types.ActivationType.silu,
        types.ActivationType.sigmoid,
        types.ActivationType.tanh,
        types.ActivationType.softmax
    }

    activation_names := [6]string{
        "ReLU",
        "GELU",
        "SiLU",
        "Sigmoid",
        "Tanh",
        "Softmax"
    }

    for i := 0; i < 6; i += 1 {
        println("Testing ", activation_names[i], "...")
        result := activation_kernel.ApplyActivation(activations[i], input, *output)

        if result.success {
            println("  ✅ Success, time: ", result.execution_time_ms, " ms")
        } else {
            println("  ❌ Failed: ", result.error_message)
        }
    }
}

func NormalizationExample() {
    println("\n=== Normalization Example ===\n")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    norm_kernel := norm_kernels.NewNormKernels(config)

    m := i32(64)
    n := i32(256)

    input := make([]f32, m * n)
    output := make([]f32, m * n)
    gamma := make([]f32, n)
    beta := make([]f32, n)

    for i := 0; i < len(input); i += 1 {
        input[i] = f32(i % 100) / 50.0 - 1.0
    }

    for i := 0; i < len(gamma); i += 1 {
        gamma[i] = 1.0
        beta[i] = 0.0
    }

    println("Executing LayerNorm...")
    norm_params := types.NormParams{
        epsilon: 1e-5,
        momentum: 0.1,
        affine: true,
        true track_running_stats
    }

    result := norm_kernel.LayerNorm(m, n, input, gamma, beta, norm_params, *output)

    if result.success {
        println("✅ LayerNorm succeeded")
        println("  Execution Time: ", result.execution_time_ms, " ms")
    } else {
        println("❌ LayerNorm failed: ", result.error_message)
    }
}

func KernelLauncherExample() {
    println("\n=== Kernel Launcher Example ===\n")

    launcher := kernel_launcher.NewKernelLauncher(0)

    problem_size := i32(1048576)
    block_size := launcher.ComputeOptimalBlockSize(problem_size, 1)
    grid_size := launcher.ComputeGridSize(problem_size, block_size)

    println("Problem size: ", problem_size)
    println("Optimal block size: ", block_size)
    println("Grid size: ", grid_size)

    launch_config := launcher.CreateLaunchConfig(problem_size, 1, 0)

    println("Launch Configuration:")
    println("  Block Dim: [", launch_config.block_dim[0], ", ", launch_config.block_dim[1], ", ", launch_config.block_dim[2], "]")
    println("  Grid Dim: [", launch_config.grid_dim[0], ", ", launch_config.grid_dim[1], ", ", launch_config.grid_dim[2], "]")
}

func main() {
    println("========================================")
    println("CUDA Kernels Basic Examples")
    println("========================================")

    BasicMatrixExample()
    ActivationExample()
    NormalizationExample()
    KernelLauncherExample()

    println("\n========================================")
    println("✅ All examples completed")
    println("========================================\n")
}
