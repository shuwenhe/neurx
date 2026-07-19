# GPU Training Architecture: S Language + CUDA

## English text

NeurX GPUtrainingEnglish text**English text**:

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

## English textS + CUDAEnglish text?

### ✅ SlanguageEnglish text
- fileI/OEnglish textShardEnglish text
- English text
- trainingEnglish text(CPUEnglish text)
- English textmanagementEnglish text
- English textlanguage(English textrunEnglish text)

### ✅ CUDAEnglish text
- English textGPUEnglish textfunction(`__global__`)
- English text(`atomicAdd`)
- GPUEnglish textstep(`cudaDeviceSynchronize()`)
- WARPEnglish text

### ❌ Slanguage**English text**English text
- English text`__global__` kernelEnglish text
- GPUEnglish text
- CUDAEnglish textmanagement
- WARPEnglish textstepEnglish text

## English text

### 1. S Language Training Loop (`scripts/legacy/gpu_train.s`)

```s
// English text - English textSimplementation
func main() {
    // parameterEnglish text(S)
    int batch_size = parse_int(...)

    // GPUEnglish textinitialize(SEnglish textC)
    GPUContext ctx = init_gpu_context(...)

    // loadShard(S)
    string shard_content = runtime_read_text_file(...)

    // English textShard(SEnglish textCUDA)
    process_shard_gpu(ctx, shard_path)

    // English text(SEnglish textC)
    cleanup_gpu_context(ctx)
}
```

**English text:**
- English texttrainingpipeline
- English textexternfunctionEnglish textCUDAEnglish text
- English textI/OEnglish textSEnglish text

### 2. CUDA Kernels (`cuda/cuda_kernels.cu`)

```cuda
// GPUEnglish text - **English textCUDA**
__global__ void relu_forward_kernel(float *out, const float *in, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;
    out[idx] = (in[idx] > 0.0f) ? in[idx] : 0.0f;
}

// CEnglish textfunction - English textSEnglish text
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

**English text:**
- GPUEnglish text`__global__`English text
- English textnvcccompile
- English textCEnglish textfunctionEnglish textSEnglish text

### 3. FFIEnglish text (`cuda/cublas_bindings.s`)

```s
// SEnglish textCfunction
extern func cuda_relu_forward(int64 out, int64 in, int size) int

// SEnglish text
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

**English text:**
- English textFFIEnglish text
- SlanguageEnglish textCUDAfunction
- English textsafety(int64, floatEnglish text)

## compilepipeline

### Step 1: compileCUDAEnglish textfunctionEnglish text
```bash
cd /home/shuwen/shuwen/train/neurx
bash cuda/build_kernels.sh
# Output: artifacts/build/cuda_kernels/libcuda_kernels.so
```

**English text:**
- `libcuda_kernels.so` - English textGPU kernels
- `env.sh` - English text

### Step 2: compileCUDA RuntimeEnglish text
```bash
bash cuda/build_cuda_runtime_alt.sh
# Output: artifacts/build/cuda_runtime/libcuda_runtime.so
```

**English text:**
- `libcuda_runtime.so` - CUDArunEnglish text

### Step 3: compileSlanguagetrainingEnglish text
```bash
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:./artifacts/build/cuda_runtime:$LD_LIBRARY_PATH"
s ir scripts/legacy/gpu_train.s -o artifacts/build/gpu_train/gpu_train.ir
```

**English text:**
- `gpu_train.ir` - SrunEnglish text

### Step 4: run
```bash
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:./artifacts/build/cuda_runtime:$LD_LIBRARY_PATH"
s_runner artifacts/build/gpu_train/gpu_train.ir
```

## English text

### 1. ShardEnglish text(SEnglish textimplementation)

```s
func process_shard_gpu(GPUContext ctx, string shard_path, ...) int {
    // S: fileEnglish text
    string content = runtime_read_text_file(shard_path)

    // S: English text
    int lines = count_lines(content)

    // S: batchEnglish text
    while batch_idx < lines {
        // S: English textGPUEnglish text
        GPUBuffer input = allocate_gpu_buffer(...)

        // S: English textGPU kernel - English textcompute
        cublasSgemm(ctx.cublas_handle, ...)

        // S: English textlossEnglish text
        float loss = cuda_error_loss_kernel(...)

        // S: English text
        cuda_relu_backward(...)

        // S: English textoptimizeEnglish text
        cuda_sgd_update_kernel(...)

        // S: English textGPUEnglish text
        free_gpu_buffer(input)
    }
}
```

### 2. GPUEnglish text(cuBLAS + FFI)

```s
// SEnglish text
extern func cublasSgemm(
    int64 handle, int transa, int transb,
    int m, int n, int k,
    float alpha, int64 A, int lda,
    int64 B, int ldb, float beta,
    int64 C, int ldc
) int

// SEnglish textuse
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

### 3. GPUEnglish textfunction(CUDAEnglish textimplementation)

```cuda
// cuda_kernels.cuEnglish text
__global__ void sgd_update_kernel(...) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        w[idx] -= lr * grad[idx] * inv_batch;  // GPUEnglish text
    }
}

// English textS
extern "C" int cuda_sgd_update_kernel(
    int64_t w_ptr, int64_t grad_ptr, float lr, int n
) {
    // Launch on GPU
    sgd_update_kernel<<<blocks, threads>>>(...);
    cudaDeviceSynchronize();
    return 0;
}
```

## English text

### SEnglish text
- fileI/O: ~50ms per 1GB shard
- parameterEnglish text: <1ms
- English text: <1ms
- **English textCPUtime**: ~10-20% of GPU compute time

### GPUEnglish text
- English textfunctionstart: ~10μs
- English text(1024×1024): ~0.5ms
- English text: ~1ms
- **English textGPUtime**: ~100-500ms per batch

### English text
- Host→Device: ~50GB/s
- Device→Host: ~50GB/s
- English text512English text, 16GBbatch: ~30ms

## English text

### English text: English textfunctionEnglish text
```
error: undefined reference to `cuda_relu_forward'
```

**English text:**
```bash
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:$LD_LIBRARY_PATH"
```

### English text: CUDAEnglish text
```
CUDA error: out of memory
```

**English text:**
- English textbatch_size
- English textseq_len
- English textgradient checkpointing

### English text: Scompilefailure, externEnglish text
```
error: unknown type int64
```

**English text:**
- SEnglish textuseEnglish text: int, float, string
- English textint64: `extern func cuda_malloc(int size) int64`

## extensionCUDAEnglish text

### English textkernelEnglish textstepEnglish text

1. **English textcuda/cuda_kernels.cuEnglish text**
```cuda
__global__ void my_kernel(...) { ... }

extern "C" int cuda_my_kernel(...) {
    my_kernel<<<...>>>(...);
    return 0;
}
```

2. **English textcuda/cublas_bindings.sEnglish text**
```s
extern func cuda_my_kernel(...) int
```

3. **English textscripts/legacy/gpu_train.sEnglish textuse**
```s
int status = cuda_my_kernel(...)
```

4. **English textcompile**
```bash
bash cuda/build_kernels.sh
s ir scripts/legacy/gpu_train.s -o artifacts/build/gpu_train/gpu_train.ir
```

## English textCPUimplementation

| English text | CPU (bash/Python) | GPU (S + CUDA) |
|------|------------------|-----------------|
| starttime | English text (ms) | English text (500msinitialize) |
| English text | ~100 docs/s | ~10K docs/s |
| English text | English text | English text (16GB) |
| English text | English text | English text |
| English text | English text | English text |

## recommendedconfiguration

### English texttest(RTX 4060 Ti)
```
BATCH_SIZE=32
SEQ_LEN=512
HIDDEN_DIM=768
LEARNING_RATE=0.001
```

### English text(RTX 4090)
```
BATCH_SIZE=256
SEQ_LEN=2048
HIDDEN_DIM=2048
LEARNING_RATE=0.0005
```

### English text(English textGPU)
```
BATCH_SIZE=1024
SEQ_LEN=4096
HIDDEN_DIM=4096
LEARNING_RATE=0.0001
GRADIENT_ACCUMULATION=4
```

## English text

- **Slanguage**: English text, I/O, English text
- **CUDA**: English textcompute
- **cuBLAS**: optimizeEnglish text
- **FFI**: S→CUDAEnglish textsafetyEnglish text

English textSlanguageEnglish textCUDAEnglish textcomputeEnglish text, implementationEnglish textGPUtraining!
