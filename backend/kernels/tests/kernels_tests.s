package neurx.kernels.tests.kernels_tests

import (
    "neurx.kernels.types"
    "neurx.kernels.matrix_kernels"
    "neurx.kernels.activation_kernels"
    "neurx.kernels.norm_kernels"
    "neurx.kernels.utils"
)

struct TestResult {
    name: string,
    passed: bool,
    message: string,
    execution_time: f32
}

var test_results: []TestResult = make([]TestResult, 0)

func LogTest(name: string, passed: bool, message: string, time: f32) {
    result := TestResult{
        name: name,
        passed: passed,
        message: message,
        execution_time: time
    }
    test_results = append(test_results, result)

    status := "✅ PASS"
    if !passed {
        status = "❌ FAIL"
    }

    println(status, " - ", name)
    if message != "" {
        println("    ", message)
    }
}

func TestMatrixGEMM() {
    println("\n[Test] Matrix GEMM Operations")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    kernel := matrix_kernels.NewMatrixKernels(config)

    m := i32(128)
    n := i32(128)
    k := i32(128)

    A := make([]f32, m * k)
    B := make([]f32, k * n)
    C := make([]f32, m * n)

    for i := 0; i < len(A); i += 1 {
        A[i] = 1.0
        B[i] = 1.0
    }

    result := kernel.GEMM(m, n, k, 1.0, A, k, B, n, 0.0, &C, n)

    LogTest("GEMM", result.success, "", result.execution_time_ms)
}

func TestMatrixTranspose() {
    println("\n[Test] Matrix Transpose")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    kernel := matrix_kernels.NewMatrixKernels(config)

    m := i32(64)
    n := i32(64)

    A := make([]f32, m * n)
    B := make([]f32, m * n)

    for i := 0; i < m; i += 1 {
        for j := 0; j < n; j += 1 {
            A[i * n + j] = f32(i * n + j)
        }
    }

    result := kernel.Transpose(m, n, A, &B)

    valid := true
    for i := 0; i < m && valid; i += 1 {
        for j := 0; j < n && valid; j += 1 {
            if B[j * m + i] != A[i * n + j] {
                valid = false
            }
        }
    }

    LogTest("Transpose", result.success && valid, "", result.execution_time_ms)
}

func TestReLU() {
    println("\n[Test] ReLU Activation")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    kernel := activation_kernels.NewActivationKernels(config)

    input := make([]f32, 1000)
    output := make([]f32, 1000)

    for i := 0; i < len(input); i += 1 {
        input[i] = f32(i) / 500.0 - 1.0
    }

    result := kernel.ReLU(input, &output)

    valid := true
    for i := 0; i < len(output) && valid; i += 1 {
        if input[i] > 0.0 {
            if output[i] != input[i] {
                valid = false
            }
        } else {
            if output[i] != 0.0 {
                valid = false
            }
        }
    }

    LogTest("ReLU", result.success && valid, "", result.execution_time_ms)
}

func TestGELU() {
    println("\n[Test] GELU Activation")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    kernel := activation_kernels.NewActivationKernels(config)

    input := make([]f32, 1000)
    output := make([]f32, 1000)

    for i := 0; i < len(input); i += 1 {
        input[i] = f32(i) / 500.0 - 1.0
    }

    result := kernel.GELU(input, true, &output)

    valid := len(output) > 0
    LogTest("GELU", result.success && valid, "", result.execution_time_ms)
}

func TestSoftmax() {
    println("\n[Test] Softmax")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    kernel := activation_kernels.NewActivationKernels(config)

    input := make([]f32, 100)
    output := make([]f32, 100)

    for i := 0; i < len(input); i += 1 {
        input[i] = f32(i) / 100.0
    }

    result := kernel.Softmax(input, 0, &output)

    sum := f32(0.0)
    for i := 0; i < len(output); i += 1 {
        sum += output[i]
    }

    valid := result.success && sum > 0.99 && sum < 1.01
    LogTest("Softmax", valid, "", result.execution_time_ms)
}

func TestLayerNorm() {
    println("\n[Test] Layer Normalization")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    kernel := norm_kernels.NewNormKernels(config)

    m := i32(32)
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

    params := types.NormParams{
        epsilon: 1e-5,
        momentum: 0.1,
        affine: true,
        track_running_stats: false
    }

    result := kernel.LayerNorm(m, n, input, gamma, beta, params, &output)

    LogTest("LayerNorm", result.success, "", result.execution_time_ms)
}

func TestRMSNorm() {
    println("\n[Test] RMS Normalization")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    kernel := norm_kernels.NewNormKernels(config)

    m := i32(32)
    n := i32(256)

    input := make([]f32, m * n)
    output := make([]f32, m * n)
    weight := make([]f32, n)

    for i := 0; i < len(input); i += 1 {
        input[i] = f32(i % 100) / 50.0 - 1.0
    }

    for i := 0; i < len(weight); i += 1 {
        weight[i] = 1.0
    }

    result := kernel.RMSNorm(m, n, input, weight, 1e-5, &output)

    LogTest("RMSNorm", result.success, "", result.execution_time_ms)
}

func TestUtilityFunctions() {
    println("\n[Test] Utility Functions")

    utils := utils.NewKernelUtils()

    valid_shape := []i32{4, 64, 256}
    valid := utils.ValidateTensorShape(valid_shape)
    LogTest("ValidateShape", valid, "", 0.0)

    size := utils.ComputeTensorSize(valid_shape)
    expected_size := i64(4) * i64(64) * i64(256)
    LogTest("ComputeTensorSize", size == expected_size, "", 0.0)

    f32_size := utils.GetDataTypeSize(types.DataType.float32)
    f16_size := utils.GetDataTypeSize(types.DataType.float16)
    LogTest("GetDataTypeSize", f32_size == 4 && f16_size == 2, "", 0.0)

    shape1 := []i32{4, 64, 256}
    shape2 := []i32{1, 64, 256}
    broadcast := utils.BroadcastShapes(shape1, shape2)
    compatible := len(broadcast) == 3 && broadcast[0] == 4
    LogTest("BroadcastShapes", compatible, "", 0.0)
}

func PrintTestReport() {
    println("\n========================================")
    println("Test Report")
    println("========================================\n")

    passed_count := 0
    failed_count := 0
    total_time := f32(0.0)

    for i := 0; i < len(test_results); i += 1 {
        if test_results[i].passed {
            passed_count += 1
        } else {
            failed_count += 1
        }
        total_time += test_results[i].execution_time
    }

    total := len(test_results)
    pass_rate := f32(passed_count) / f32(total) * 100.0

    println("Summary:")
    println("  Total Tests: ", total)
    println("  Passed: ", passed_count)
    println("  Failed: ", failed_count)
    println("  Pass Rate: ", pass_rate, "%")
    println("  Total Execution Time: ", total_time, " ms")
    println("\n========================================")
}

func main() {
    println("========================================")
    println("CUDA Kernels Unit Tests")
    println("========================================")

    TestMatrixGEMM()
    TestMatrixTranspose()
    TestReLU()
    TestGELU()
    TestSoftmax()
    TestLayerNorm()
    TestRMSNorm()
    TestUtilityFunctions()

    PrintTestReport()
}
