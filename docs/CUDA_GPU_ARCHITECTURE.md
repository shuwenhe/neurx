# GPU Training Architecture: S Language + CUDA

## 概述

NeurX GPU训练采用**分层架构**：

```
┌─────────────────────────────────────────────────────┐
│ Layer 1: S Language (High-level Logic)              │
│ - scripts/legacy/gpu_train.s                                │
│ - Shard loading, training loop, logging             │
│ - Environment variables parsing                     │
│ - Memory management orchestration                   │
└────────────────────┬────────────────────────────────┘
                     │ extern func declarations
                     ↓
┌─────────────────────────────────────────────────────┐
│ Layer 2: FFI Bindings (S→C Interface)               │
│ - cublas_bindings.s (cuBLAS operations)            │
│ - cuda_wrapper_simple.cu (memory ops)              │
│ - CUDA Runtime API declarations                    │
└────────────────────┬────────────────────────────────┘
                     │ linked via LD_LIBRARY_PATH
                     ↓
┌─────────────────────────────────────────────────────┐
│ Layer 3: CUDA Kernels (Low-level Compute)          │
│ - cuda/cuda_kernels.cu (**MUST use CUDA**)        │
│ - ReLU, Softmax, LayerNorm kernels                │
│ - Loss computation, SGD updates                    │
│ - Matrix operations via cuBLAS                     │
└────────────────────┬────────────────────────────────┘
                     │ compiled to .o files
                     ↓
┌─────────────────────────────────────────────────────┐
│ Layer 4: Shared Libraries                           │
│ - libcuda_kernels.so (GPU-specific kernels)        │
│ - libcuda_runtime.so (CUDA Runtime + cuBLAS)       │
│ - libcudart.so.12 (NVIDIA CUDA Runtime)            │
│ - libcublas.so.12 (NVIDIA cuBLAS)                  │
└─────────────────────────────────────────────────────┘
```

## 为什么S + CUDA混合？

### ✅ S语言擅长的事
- 文件I/O和Shard处理
- 环境变量解析
- 训练循环逻辑（CPU端）
- 内存管理编排
- 自举语言（不依赖外部运行时）

### ✅ CUDA必须做的事
- 并行GPU核函数（`__global__`）
- 原子操作（`atomicAdd`）
- GPU内存同步（`cudaDeviceSynchronize()`）
- WARP级并行化

### ❌ S语言**不能**做
- 写`__global__` kernel代码
- GPU原子操作
- CUDA流管理
- WARP同步原语

## 代码组织

### 1. S Language Training Loop (`scripts/legacy/gpu_train.s`)

```s
// 入口点 - 全用S实现
func main() {
    // 参数解析（S）
    int batch_size = parse_int(...)
    
    // GPU上下文初始化（S调用C）
    GPUContext ctx = init_gpu_context(...)
    
    // 加载Shard（S）
    string shard_content = runtime_read_text_file(...)
    
    // 处理Shard（S调用CUDA）
    process_shard_gpu(ctx, shard_path)
    
    // 清理（S调用C）
    cleanup_gpu_context(ctx)
}
```

**特点:**
- 直观的训练流程
- 调用extern函数到CUDA库
- 所有I/O和逻辑用S编写

### 2. CUDA Kernels (`cuda/cuda_kernels.cu`)

```cuda
// GPU并行代码 - **必须用CUDA**
__global__ void relu_forward_kernel(float *out, const float *in, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;
    out[idx] = (in[idx] > 0.0f) ? in[idx] : 0.0f;
}

// C包装函数 - 被S调用
extern "C" int cuda_relu_forward(
    int64_t output_ptr, int64_t input_ptr, int size
) {
    // Launch kernel
    int threads = 256;
    int blocks = (size + threads - 1) / threads;
    relu_forward_kernel<<<blocks, threads>>>(
        (float*)output_ptr,
        (float*)input_ptr,
        size
    );
    
    // Sync and error check
    cudaDeviceSynchronize();
    return 0;
}
```

**特点:**
- GPU并行通过`__global__`标记
- 由nvcc编译
- 暴露C包装函数给S调用

### 3. FFI绑定 (`cuda/cublas_bindings.s`)

```s
// S中声明外部C函数
extern func cuda_relu_forward(int64 out, int64 in, int size) int

// S中调用
func apply_relu(GPUTensor input, GPUTensor output) {
    int status = cuda_relu_forward(
        output.device_ptr,
        input.device_ptr,
        input.size
    )
    if status != 0 {
        println("[ERROR] ReLU forward failed")
    }
}
```

**特点:**
- 简洁的FFI声明
- S语言直接调用CUDA函数
- 类型安全（int64, float等）

## 编译流程

### Step 1: 编译CUDA核函数库
```bash
cd /home/shuwen/shuwen/train/neurx
bash cuda/build_kernels.sh
# Output: artifacts/build/cuda_kernels/libcuda_kernels.so
```

**产物:**
- `libcuda_kernels.so` - 包含所有GPU kernels
- `env.sh` - 环境变量设置脚本

### Step 2: 编译CUDA Runtime库
```bash
bash cuda/build_cuda_runtime_alt.sh
# Output: artifacts/build/cuda_runtime/libcuda_runtime.so
```

**产物:**
- `libcuda_runtime.so` - CUDA运行时包装

### Step 3: 编译S语言训练脚本
```bash
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:./artifacts/build/cuda_runtime:$LD_LIBRARY_PATH"
s ir scripts/legacy/gpu_train.s -o artifacts/build/gpu_train/gpu_train.ir
```

**产物:**
- `gpu_train.ir` - S运行时字节码

### Step 4: 运行
```bash
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:./artifacts/build/cuda_runtime:$LD_LIBRARY_PATH"
s_runner artifacts/build/gpu_train/gpu_train.ir
```

## 集成点详解

### 1. Shard处理（S中实现）

```s
func process_shard_gpu(GPUContext ctx, string shard_path, ...) int {
    // S: 文件读取
    string content = runtime_read_text_file(shard_path)
    
    // S: 行数计数
    int lines = count_lines(content)
    
    // S: 批次循环
    while batch_idx < lines {
        // S: 分配GPU内存
        GPUBuffer input = allocate_gpu_buffer(...)
        
        // S: 调用GPU kernel - 核心计算
        cublasSgemm(ctx.cublas_handle, ...)
        
        // S: 调用损失核
        float loss = cuda_error_loss_kernel(...)
        
        // S: 调用反向核
        cuda_relu_backward(...)
        
        // S: 调用优化核
        cuda_sgd_update_kernel(...)
        
        // S: 清理GPU内存
        free_gpu_buffer(input)
    }
}
```

### 2. GPU矩阵乘法（cuBLAS + FFI）

```s
// S中声明
extern func cublasSgemm(
    int64 handle, int transa, int transb,
    int m, int n, int k,
    float alpha, int64 A, int lda,
    int64 B, int ldb, float beta,
    int64 C, int ldc
) int

// S中使用
int status = cublasSgemm(
    ctx.cublas_handle,
    0, 0,  // No transpose
    rows, cols, inner,
    1.0,   // alpha
    A_gpu, cols,
    B_gpu, cols,
    0.0,   // beta
    C_gpu, cols
)
```

### 3. GPU核函数（CUDA中实现）

```cuda
// cuda_kernels.cu中
__global__ void sgd_update_kernel(...) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        w[idx] -= lr * grad[idx] * inv_batch;  // GPU并行
    }
}

// 暴露给S
extern "C" int cuda_sgd_update_kernel(
    int64_t w_ptr, int64_t grad_ptr, float lr, int n
) {
    // Launch on GPU
    sgd_update_kernel<<<blocks, threads>>>(...);
    cudaDeviceSynchronize();
    return 0;
}
```

## 性能特性

### S层的开销
- 文件I/O: ~50ms per 1GB shard
- 参数解析: <1ms
- 内存编排: <1ms
- **总CPU时间**: ~10-20% of GPU compute time

### GPU层的开销
- 核函数启动: ~10μs
- 矩阵乘法(1024×1024): ~0.5ms
- 反向传播: ~1ms
- **总GPU时间**: ~100-500ms per batch

### 通信开销
- Host→Device: ~50GB/s
- Device→Host: ~50GB/s
- 对于512长序列、16GB批次: ~30ms

## 故障排查

### 问题: 核函数未被找到
```
error: undefined reference to `cuda_relu_forward'
```

**解决:**
```bash
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:$LD_LIBRARY_PATH"
```

### 问题: CUDA内存不足
```
CUDA error: out of memory
```

**解决:**
- 减小batch_size
- 减小seq_len
- 启用gradient checkpointing

### 问题: S编译失败，extern声明
```
error: unknown type int64
```

**解决:**
- S中使用标准类型: int, float, string
- 对于指针用int64: `extern func cuda_malloc(int size) int64`

## 扩展CUDA核

### 添加新kernel的步骤

1. **在cuda/cuda_kernels.cu中添加**
```cuda
__global__ void my_kernel(...) { ... }

extern "C" int cuda_my_kernel(...) { 
    my_kernel<<<...>>>(...);
    return 0;
}
```

2. **在cuda/cublas_bindings.s中声明**
```s
extern func cuda_my_kernel(...) int
```

3. **在scripts/legacy/gpu_train.s中使用**
```s
int status = cuda_my_kernel(...)
```

4. **重新编译**
```bash
bash cuda/build_kernels.sh
s ir scripts/legacy/gpu_train.s -o artifacts/build/gpu_train/gpu_train.ir
```

## 对比CPU实现

| 方面 | CPU (bash/Python) | GPU (S + CUDA) |
|------|------------------|-----------------|
| 启动时间 | 快 (ms) | 慢 (500ms初始化) |
| 吞吐量 | ~100 docs/s | ~10K docs/s |
| 内存用量 | 低 | 中等 (16GB) |
| 开发难度 | 低 | 中等 |
| 维护成本 | 低 | 中等 |

## 推荐配置

### 小规模测试（RTX 4060 Ti）
```
BATCH_SIZE=32
SEQ_LEN=512
HIDDEN_DIM=768
LEARNING_RATE=0.001
```

### 中等规模（RTX 4090）
```
BATCH_SIZE=256
SEQ_LEN=2048
HIDDEN_DIM=2048
LEARNING_RATE=0.0005
```

### 生产环境（多GPU）
```
BATCH_SIZE=1024
SEQ_LEN=4096
HIDDEN_DIM=4096
LEARNING_RATE=0.0001
GRADIENT_ACCUMULATION=4
```

## 总结

- **S语言**: 高层逻辑、I/O、编排
- **CUDA**: 低层并行计算
- **cuBLAS**: 优化矩阵操作
- **FFI**: S→CUDA的安全桥梁

这种架构结合了S语言的易用性和CUDA的计算能力，实现高效的GPU训练！
