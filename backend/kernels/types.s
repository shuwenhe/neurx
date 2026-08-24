package neurx.kernels.types

import (
    "neurx.tensor.types" as ttypes
)

enum DeviceType {
    cpu,
    cuda,
    rocm,
    npu
}

enum DataType {
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
    device: DeviceType
}

struct MemoryInfo {
    allocated: i64,
    reserved: i64,
    free: i64,
    used: i64,
    total: i64
}

struct KernelStats {
    name: string,
    execution_time_ms: f32,
    flops: i64,
    bytes_read: i64,
    bytes_written: i64,
    gpu_time_ms: f32,
    launch_count: i32
}

struct CUDAStream {
    stream_id: i32,
    device: DeviceType,
    priority: i32,
    is_active: bool
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
    ldc: i32
}

struct NormParams {
    epsilon: f32,
    momentum: f32,
    affine: bool,
    track_running_stats: bool
}

enum ActivationType {
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
    dim: i32
}

struct AttentionParams {
    batch_size: i32,
    num_heads: i32,
    seq_len: i32,
    head_dim: i32,
    is_causal: bool,
    dropout_p: f32,
    scale: f32
}

struct DTypeConversionParams {
    src_dtype: DataType,
    dst_dtype: DataType,
    scale_factor: f32,
    zero_point: i32
}

enum MemoryLayout {
    nchw,
    nhwc,
    ncwh,
    contiguous
}

struct KernelCacheConfig {
    enable_cache: bool,
    max_cache_entries: i32,
    cache_eviction_policy: string,
    cache_hit_threshold: i32
}

struct KernelCompileOptions {
    optimization_level: i32,
    enable_ptx_cache: bool,
    enable_graph_capture: bool,
    max_registers: i32,
    use_fast_math: bool
}

struct KernelResult {
    success: bool,
    error_code: i32,
    error_message: string,
    execution_time_ms: f32,
    stats: KernelStats
}

struct CUDAEvent {
    event_id: i32,
    device: DeviceType,
    is_recorded: bool,
    timestamp: i64
}

struct LaunchConfig {
    block_dim: [3]i32,
    grid_dim: [3]i32,
    shared_memory_bytes: i32,
    stream: &CUDAStream
}

func main() {
    println("CUDA Kernels Types Module")
    println("✅ Type definitions for CUDA kernel operations")
}
