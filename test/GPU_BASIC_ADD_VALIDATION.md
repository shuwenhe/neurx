# gpu_basic_add: 真实 GPU 执行验证路径

## 🎯 目标
验证 S → Device ABI → CUDA Driver → NVIDIA GPU 的完整执行链路，收集三层不可伪造的证据。

---

## 📋 执行清单

### Phase 1: 代码准备
- [x] test/gpu_basic_add.s 创建 ✅
- [x] sys/device_abi_cuda.s 创建 ✅
- [ ] CUDA 驱动绑定实现
  - [ ] cuInit() binding
  - [ ] cuDeviceGet() binding
  - [ ] cuCtxCreate() binding
  - [ ] cuMemAlloc() binding
  - [ ] cuMemFree() binding
  - [ ] cuModuleLoad() binding
  - [ ] cuModuleGetFunction() binding
  - [ ] cuLaunchKernel() binding
  - [ ] cuCtxSynchronize() binding
  - [ ] cuMemcpyHtoD() binding
  - [ ] cuMemcpyDtoH() binding

### Phase 2: 编译
- [ ] S compiler 处理 gpu_basic_add.s
  ```bash
  cd /home/shuwen/shuwen/neurx
  /home/shuwen/.local/bin/s test/gpu_basic_add.s
  ```
- [ ] 生成 IR 文件（无编译错误）
- [ ] 如果支持，生成可执行二进制

### Phase 3: CUDA Kernel 准备
- [ ] 编写 vector_add kernel
  ```cuda
  __global__ void vector_add(int* A, int* B, int* C, int N) {
      int idx = blockIdx.x * blockDim.x + threadIdx.x;
      if (idx < N) C[idx] = A[idx] + B[idx];
  }
  ```
- [ ] 编译为 .cubin 或 .ptx
- [ ] 放在 gpu_basic_add 能找到的位置

### Phase 4: 运行测试
- [ ] 准备 NVIDIA GPU（H100/A100）
- [ ] 验证 CUDA 工具链
  ```bash
  nvidia-smi
  nvcc --version
  ```
- [ ] 启动测试
  ```bash
  # 如果 S 编译为二进制
  ./gpu_basic_add
  
  # 或通过 IR 解释器运行
  ```

### Phase 5: 实时验证（三层证据）

#### 证据 1️⃣ : Functional Correctness
```
在 stdout 中应该看到：
Input A: [1, 2, 3, 4]
Input B: [5, 6, 7, 8]
GPU Output C: [6, 8, 10, 12]
Expected C:  [6, 8, 10, 12]
VERIFY: PASS ✅
```

**验收标准**: 数值完全匹配，小数精度正确

#### 证据 2️⃣ : Physical Memory Verification
```
执行前：
$ nvidia-smi | grep "Free"
GPU 0 Free: 79.8 GB

执行中（内存分配后）：
$ nvidia-smi | grep "Free"
GPU 0 Free: 59.8 GB  ← 显示减少 48 bytes（3×16）

执行后（内存释放后）：
$ nvidia-smi | grep "Free"
GPU 0 Free: 79.8 GB  ← 完全恢复
```

**验收标准**: VRAM 变化与程序分配/释放完全对应

#### 证据 3️⃣ : Runtime Metrics
```
程序输出日志：
[NeurX] CUDA Driver Version: 12.2
[NeurX] GPU Device: NVIDIA H100-80GB
[NeurX] GPU Compute Capability: 9.0

[NeurX] cuMemAlloc(16 bytes) → addr=0x1000 CUDA_SUCCESS
[NeurX] cuMemAlloc(16 bytes) → addr=0x2000 CUDA_SUCCESS
[NeurX] cuMemAlloc(16 bytes) → addr=0x3000 CUDA_SUCCESS

[NeurX] cuMemcpyHtoD(0x1000, host_A, 16) → CUDA_SUCCESS
[NeurX] cuMemcpyHtoD(0x2000, host_B, 16) → CUDA_SUCCESS

[NeurX] cuModuleLoad("vector_add.cubin") → CUDA_SUCCESS
[NeurX] cuModuleGetFunction("vector_add") → CUDA_SUCCESS

[NeurX] cuLaunchKernel(grid=(1,1,1), block=(4,1,1)) → CUDA_SUCCESS
[NeurX] kernel execution time: 234 microseconds

[NeurX] cuCtxSynchronize() → CUDA_SUCCESS
[NeurX] Total kernel time: 234 microseconds

[NeurX] cuMemcpyDtoH(host_C, 0x3000, 16) → CUDA_SUCCESS

[NeurX] cuMemFree(0x1000) → CUDA_SUCCESS
[NeurX] cuMemFree(0x2000) → CUDA_SUCCESS
[NeurX] cuMemFree(0x3000) → CUDA_SUCCESS

[NeurX] Memory accounting:
├─ Allocated: 48 bytes
├─ Freed: 48 bytes
└─ Leak check: PASS ✅

[NeurX] CUDA error codes: 0 (all CUDA_SUCCESS)
```

**验收标准**: 
- 所有 CUDA API 调用返回 CUDA_SUCCESS (code 0)
- 分配字节数 == 释放字节数（无泄漏）
- Kernel 执行时间 > 0
- 数据交互顺序正确

---

## 🔍 调试清单

### 如果 Functional 失败
```
Functional FAIL: GPU output != expected

诊断步骤：
1. 检查 kernel 是否正确编译
   $ nvcc -ptx vector_add.cu -o vector_add.ptx
   
2. 检查 H2D 是否成功
   用 cuda-memcheck 检查内存访问
   
3. 检查 D2H 是否成功
   在 GPU 上检查 C 的内存内容
   
4. 检查 kernel 逻辑
   单独编译 kernel 进行 unit test
```

### 如果 Physical 失败
```
Physical FAIL: nvidia-smi 显示的 VRAM 没有变化

诊断步骤：
1. 确认 CUDA context 创建成功
   cuCtxCreate 返回 CUDA_SUCCESS?
   
2. 确认 cuMemAlloc 确实分配了内存
   在 Device ABI 中检查 allocated_bytes 计数器
   
3. 确认没有其他进程占用 GPU
   $ nvidia-smi ps
   
4. 尝试用 NVIDIA 官方示例验证 GPU
   vector_add from CUDA Samples
```

### 如果 Runtime 失败
```
Runtime FAIL: CUDA 返回非零 error code

常见错误码：
- CUDA_ERROR_OUT_OF_MEMORY (2): 显存不足
  → 检查分配大小
  
- CUDA_ERROR_INVALID_VALUE (1): 参数无效
  → 检查指针、大小、grid/block 配置
  
- CUDA_ERROR_NO_DEVICE (3): 没有可用设备
  → 检查 nvidia-smi, GPU 驱动

调试方法：
$ cudaGetErrorString(error_code)  // 查询错误信息
```

---

## 📊 预期输出示例

```
=== NeurX GPU Basic Add Test ===
[NeurX] Starting gpu_basic_add verification...

[NeurX] Initializing CUDA...
[NeurX] CUDA Driver Version: 12.2
[NeurX] Found GPU: NVIDIA H100-80GB (device 0)
[NeurX] Compute Capability: 9.0

[NeurX] Creating CUDA context...
[NeurX] Context created: CUDA_SUCCESS

[NeurX] Allocating GPU memory...
[NeurX] cuMemAlloc(16 bytes) → 0x7fff00001000 CUDA_SUCCESS
[NeurX] cuMemAlloc(16 bytes) → 0x7fff00001010 CUDA_SUCCESS
[NeurX] cuMemAlloc(16 bytes) → 0x7fff00001020 CUDA_SUCCESS

[NeurX] GPU Memory Stats:
├─ Total: 83886080000 bytes (80 GB)
├─ Allocated: 48 bytes
├─ Free: 83886079952 bytes
└─ Peak: 48 bytes

[NeurX] Transferring host data to device...
[NeurX] cuMemcpyHtoD(0x7fff00001000, [1,2,3,4], 16) → CUDA_SUCCESS
[NeurX] cuMemcpyHtoD(0x7fff00001010, [5,6,7,8], 16) → CUDA_SUCCESS

[NeurX] Loading kernel...
[NeurX] cuModuleLoad("vector_add.cubin") → CUDA_SUCCESS
[NeurX] cuModuleGetFunction("vector_add_kernel") → CUDA_SUCCESS

[NeurX] Launching kernel...
[NeurX] Grid: (1, 1, 1), Block: (4, 1, 1)
[NeurX] cuLaunchKernel → CUDA_SUCCESS
[NeurX] Kernel execution started

[NeurX] Synchronizing GPU...
[NeurX] cuCtxSynchronize → CUDA_SUCCESS
[NeurX] Kernel execution completed in 234 microseconds

[NeurX] Retrieving results from device...
[NeurX] cuMemcpyDtoH(host_C, 0x7fff00001020, 16) → CUDA_SUCCESS

=== VERIFICATION ===
Input A:  [1, 2, 3, 4]
Input B:  [5, 6, 7, 8]
GPU Output C: [6, 8, 10, 12]
Expected C:  [6, 8, 10, 12]

Functional Correctness: PASS ✅
All values match!

=== PHYSICAL VERIFICATION ===
GPU Memory Before: 79.8 GB
GPU Memory After Alloc: 59.8 GB (48 bytes allocated)
GPU Memory After Free: 79.8 GB (fully recovered)

Physical Verification: PASS ✅
VRAM tracked correctly!

[NeurX] Cleaning up...
[NeurX] cuMemFree(0x7fff00001000) → CUDA_SUCCESS
[NeurX] cuMemFree(0x7fff00001010) → CUDA_SUCCESS
[NeurX] cuMemFree(0x7fff00001020) → CUDA_SUCCESS
[NeurX] cuCtxDestroy → CUDA_SUCCESS

=== RUNTIME SUMMARY ===
CUDA Driver Version: 12.2
GPU Model: NVIDIA H100-80GB
Total API Calls: 15
├─ cuMemAlloc: 3
├─ cuMemcpyHtoD: 2
├─ cuModuleLoad: 1
├─ cuModuleGetFunction: 1
├─ cuLaunchKernel: 1
├─ cuCtxSynchronize: 1
├─ cuMemcpyDtoH: 1
├─ cuMemFree: 3
└─ cuCtxDestroy: 1

CUDA Error Codes: 0 (all CUDA_SUCCESS)
Memory allocated: 48 bytes
Memory freed: 48 bytes
Memory leak check: PASS ✅

Kernel Metrics:
├─ Kernels launched: 1
├─ Total execution time: 234 microseconds
├─ Theoretical bandwidth: 850 GB/s
└─ Efficiency: ~100% (simple kernel)

=== FINAL STATUS ===
✅ Functional Correctness: PASS
✅ Physical Verification: PASS
✅ Runtime Metrics: PASS
✅ Memory Leak Check: PASS

OVERALL: HARDWARE-BACKED EXECUTION VERIFIED ✅
NeurX GPU Basic Add Test: SUCCESS

This proves S → Device ABI → CUDA → GPU → Result
No simulation. Real hardware execution verified.
```

---

## 🚀 后续步骤

一旦 gpu_basic_add 完全通过，立即启动：

### Next: GEMM (Tensor Multiply)
```
Tensor A (4×4)
Tensor B (4×4)
Matrix Multiply: C = A × B
Result vs CPU numpy
```

### Then: RoPE (Position Encoding)
### Then: Attention 
### Then: Transformer Block
### Then: Full Qwen-7B

每一步都必须有 CPU reference 验证。

---

## 📝 验收签字

测试完全通过且收集到三层证据后，可以声明：

> **NeurX Level 3: Real GPU Integration - VERIFIED ✅**
> 
> Evidence:
> - ✅ Functional: S → GPU computation matches expected output
> - ✅ Physical: nvidia-smi confirms real VRAM allocation/deallocation
> - ✅ Runtime: CUDA API calls logged, no errors, memory consistent
>
> Date: [YYYY-MM-DD]
> GPU: NVIDIA H100-80GB
> Driver: CUDA 12.x
> Status: PRODUCTION-READY FOR NEXT MILESTONE
