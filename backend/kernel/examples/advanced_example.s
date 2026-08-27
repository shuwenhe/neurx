package neurx.kernels.examples.advanced_example

import (
    "neurx.kernels.types"
    "neurx.kernels.attention_kernels"
    "neurx.kernels.dtype_conversion"
    "neurx.kernels.memory_manager"
    "neurx.kernels.utils"
)

func AttentionExample() {
    println("\n=== Multi-Head Attention Example ===\n")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    attn_kernel := attention_kernels.NewAttentionKernels(config)

    batch_size := i32(4)
    num_heads := i32(8)
    seq_len := i32(64)
    head_dim := i32(64)

    total_elements := batch_size * seq_len * num_heads * head_dim
    Q := make([]f32, total_elements)
    K := make([]f32, total_elements)
    V := make([]f32, total_elements)
    output := make([]f32, total_elements)

    for i := 0; i < len(Q); i += 1 {
        Q[i] = f32(i % 100) / 100.0
        K[i] = f32((i + 1) % 100) / 100.0
        V[i] = f32((i + 2) % 100) / 100.0
    }

    println("Running Multi-Head Attention:")
    println("  Batch Size: ", batch_size)
    println("  Num Heads: ", num_heads)
    println("  Sequence Length: ", seq_len)
    println("  Head Dimension: ", head_dim)

    params := types.AttentionParams{
        batch_size: batch_size,
        num_heads: num_heads,
        seq_len: seq_len,
        head_dim: head_dim,
        is_causal: false,
        dropout_p: 0.0,
        scale: f32(1.0) / f32(head_dim) ^ 0.5
    }

    result := attn_kernel.MultiHeadAttention(batch_size, num_heads, seq_len, head_dim, Q, K, V, *output)

    if result.success {
        println("✅ Attention succeeded")
        println("  Execution Time: ", result.execution_time_ms, " ms")
        println("  Output Size: ", len(output), " elements")
    } else {
        println("❌ Attention failed: ", result.error_message)
    }
}

func CausalAttentionExample() {
    println("\n=== Causal Attention Example ===\n")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    attn_kernel := attention_kernels.NewAttentionKernels(config)

    batch_size := i32(2)
    num_heads := i32(4)
    seq_len := i32(32)
    head_dim := i32(32)

    total_elements := batch_size * seq_len * num_heads * head_dim
    Q := make([]f32, total_elements)
    K := make([]f32, total_elements)
    V := make([]f32, total_elements)
    output := make([]f32, total_elements)

    for i := 0; i < len(Q); i += 1 {
        Q[i] = f32(i % 50) / 50.0
        K[i] = f32((i + 1) % 50) / 50.0
        V[i] = f32((i + 2) % 50) / 50.0
    }

    println("Running Causal Attention...")

    params := types.AttentionParams{
        batch_size: batch_size,
        num_heads: num_heads,
        seq_len: seq_len,
        head_dim: head_dim,
        is_causal: true,
        dropout_p: 0.0,
        scale: f32(1.0) / f32(head_dim) ^ 0.5
    }

    result := attn_kernel.CausalAttention(params, Q, K, V, *output)

    if result.success {
        println("✅ Causal Attention succeeded")
        println("  Execution Time: ", result.execution_time_ms, " ms")
    } else {
        println("❌ Causal Attention failed")
    }
}

func DataTypeConversionExample() {
    println("\n=== Data Type Conversion Example ===\n")

    config := types.KernelConfig{
        block_size: 256,
        grid_size: 128,
        shared_memory: 0,
        stream_id: 0,
        device: types.DeviceType.cuda
    }

    conversion := dtype_conversion.NewDTypeConversionKernels(config)

    println("Converting Float32 to Float16...")
    input_f32 := make([]f32, 1024)
    output_f16 := make([]i16, 1024)

    for i := 0; i < len(input_f32); i += 1 {
        input_f32[i] = f32(i) / 512.0 - 1.0
    }

    result := conversion.Float32ToFloat16(input_f32, *output_f16)
    if result.success {
        println("✅ Float32.Float16 succeeded")
    }

    println("Converting Float16 back to Float32...")
    output_f32 := make([]f32, 1024)
    result = conversion.Float16ToFloat32(output_f16, *output_f32)
    if result.success {
        println("✅ Float16.Float32 succeeded")
    }

    println("Quantizing to Int8...")
    quantized := make([]i8, 1024)
    scale := f32(0.01)
    zero_point := i8(0)

    result = conversion.Float32ToInt8(input_f32, scale, zero_point, *quantized)
    if result.success {
        println("✅ Quantization succeeded")
    }

    println("Dequantizing from Int8...")
    dequantized := make([]f32, 1024)
    result = conversion.Int8ToFloat32(quantized, scale, zero_point, *dequantized)
    if result.success {
        println("✅ Dequantization succeeded")
    }
}

func MemoryManagementExample() {
    println("\n=== Memory Management Example ===\n")

    mem_manager := memory_manager.NewMemoryManager(types.DeviceType.cuda, i64(1000000000))

    println("Memory Manager initialized")
    println("Total Memory: ", mem_manager.total_memory, " bytes")

    addr1 := mem_manager.Allocate(i64(10000000))
    println("Allocated 10MB at address: ", addr1)

    addr2 := mem_manager.Allocate(i64(20000000))
    println("Allocated 20MB at address: ", addr2)

    addr3 := mem_manager.Allocate(i64(30000000))
    println("Allocated 30MB at address: ", addr3)

    info := mem_manager.GetMemoryInfo()
    println("\nMemory Status:")
    println("  Allocated: ", info.allocated, " bytes")
    println("  Free: ", info.free, " bytes")
    println("  Used: ", info.used, " bytes")

    mem_manager.Free(addr2)
    println("\nFreed 20MB")

    frag := mem_manager.ComputeFragmentation()
    println("Fragmentation Ratio: ", frag)
}

func UtilityFunctionsExample() {
    println("\n=== Utility Functions Example ===\n")

    utils := utils.NewKernelUtils()

    shape1 := []i32{4, 64, 256}
    println("Testing Shape Operations:")
    println("  Shape: [4, 64, 256]")

    size := utils.ComputeTensorSize(shape1)
    println("  Total Elements: ", size)

    shape2 := []i32{1, 64, 256}
    broadcast_shape := utils.BroadcastShapes(shape1, shape2)
    println("\n  Broadcast [4,64,256] with [1,64,256]:")
    println("    Result: [", broadcast_shape[0], ",", broadcast_shape[1], ",", broadcast_shape[2], "]")

    data := make([]f32, 1000)
    for i := 0; i < len(data); i += 1 {
        data[i] = f32(i) / 500.0 - 1.0
    }

    min, max, mean, std := utils.ComputeStats(data)
    println("\n  Data Statistics:")
    println("    Min: ", min)
    println("    Max: ", max)
    println("    Mean: ", mean)
    println("    Std Dev: ", std)

    info := utils.FormatTensorInfo("example_tensor", shape1, types.DataType.float32)
    println("\n" + info)
}

func main() {
    println("========================================")
    println("CUDA Kernels Advanced Examples")
    println("========================================")

    AttentionExample()
    CausalAttentionExample()
    DataTypeConversionExample()
    MemoryManagementExample()
    UtilityFunctionsExample()

    println("\n========================================")
    println("✅ All advanced examples completed")
    println("========================================\n")
}
