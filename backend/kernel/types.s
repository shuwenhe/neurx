package neurx.kernels.types

import (
    "neurx.tensor.types" as ttypes
)


    cpu,
    cuda,
    rocm,
    npu
}


    float32,
    float16,
    bfloat16,
    int8,
    int32,
    int64
}

struct KernelConfig {
    block_size: i32,
    grid_size: i32,
    shared_memory: i32,
    stream_id: i32,
    DeviceType device
}

struct MemoryInfo {
    allocated: i64,
    reserved: i64,
    free: i64,
    used: i64,
    i64 total
}

struct KernelStats {
    name: string,
    execution_time_ms: f32,
    flops: i64,
    bytes_read: i64,
    bytes_written: i64,
    gpu_time_ms: f32,
    i32 launch_count
}

struct CUDAStream {
    stream_id: i32,
    device: DeviceType,
    priority: i32,
    bool is_active
}

struct TensorOpParams {
    output_dtype: DataType,
    alpha: f32,
    beta: f32,
    transpose_a: bool,
    transpose_b: bool,
    batch_size: i32,
    m: i32,
    n: i32,
    k: i32,
    lda: i32,
    ldb: i32,
    i32 ldc
}

struct NormParams {
    epsilon: f32,
    momentum: f32,
    affine: bool,
    bool track_running_stats
}


    relu,
    gelu,
    silu,
    sigmoid,
    tanh,
    softmax,
    log_softmax
}

struct ActivationParams {
    activation_type: ActivationType,
    inplace: bool,
    i32 dim
}

struct AttentionParams {
    batch_size: i32,
    num_heads: i32,
    seq_len: i32,
    head_dim: i32,
    is_causal: bool,
    dropout_p: f32,
    f32 scale
}

struct DTypeConversionParams {
    src_dtype: DataType,
    dst_dtype: DataType,
    scale_factor: f32,
    i32 zero_point
}


    nchw,
    nhwc,
    ncwh,
    contiguous
}

struct KernelCacheConfig {
    enable_cache: bool,
    max_cache_entries: i32,
    cache_eviction_policy: string,
    i32 cache_hit_threshold
}

struct KernelCompileOptions {
    optimization_level: i32,
    enable_ptx_cache: bool,
    enable_graph_capture: bool,
    max_registers: i32,
    bool use_fast_math
}

struct KernelResult {
    success: bool,
    error_code: i32,
    error_message: string,
    execution_time_ms: f32,
    KernelStats stats
}

struct CUDAEvent {
    event_id: i32,
    device: DeviceType,
    is_recorded: bool,
    i64 timestamp
}

struct LaunchConfig {
    block_dim: [3]i32,
    grid_dim: [3]i32,
    shared_memory_bytes: i32,
    *CUDAStream stream
}

func main() {
    println("CUDA Kernels Types Module")
    println("✅ Type definitions for CUDA kernel operations")
}
