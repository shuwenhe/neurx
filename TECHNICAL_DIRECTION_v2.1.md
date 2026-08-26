# NeurX AI OS: 从原型到生产 - 技术路线调整 v2.1

## 🔴 关键调整：冻结横向扩展，专注纵向贯通

### 原始计划的陷阱
```
继续增加 OS 模块：
  ├─ BPF / eBPF
  ├─ namespace
  ├─ hypervisor
  ├─ device tree
  └─ ...更多 Linux 功能

❌ 问题：模块多≠执行能力强
```

### 新方向（已定）
```
🔒 冻结新模块开发
✅ 13+ kernel subsystems 已完成
✅ 6-layer control plane 已验证
➡️  NOW: 打穿真实硬件执行链
```

---

## 🎯 最高优先级：Phase 2 - Real GPU Integration

不是从 Virtual Memory 开始，而是**立即启动 CUDA 驱动集成**。

### Milestone: S → GPU → Result

```
S Program
    │
    ├─ compile → IR
    │
    ▼
NeurX Runtime
    │
    ├─ workload_dispatcher
    │
    ▼
Device ABI
    │
    ├─ init_device(device_id)
    ├─ allocate_device_memory(size)
    ├─ load_kernel(kernel_binary)
    ├─ launch_kernel(grid, block)
    ├─ synchronize()
    ├─ copy_device_to_host()
    │
    ▼
CUDA Driver API
    │
    ├─ cuCtxCreate
    ├─ cuMemAlloc
    ├─ cuMemcpyHtoD
    ├─ cuLaunchKernel
    ├─ cuCtxSynchronize
    ├─ cuMemcpyDtoH
    │
    ▼
GPU Hardware (H100 / A100)
    │
    ├─ ALU Execution
    ├─ Memory Bandwidth
    │
    ▼
Result Back to S
    │
    ├─ Verify result correct
    ├─ Check nvidia-smi metrics
    ├─ Record execution latency
```

### 验收标准：三层证据

#### Level 1: Functional Correctness
```
Input:  A = [1, 2, 3, 4]
        B = [5, 6, 7, 8]

Kernel: C[i] = A[i] + B[i]

Expected: C = [6, 8, 10, 12]

✅ Validation: memcmp(C_gpu, C_expected) == 0
```

#### Level 2: Physical Verification
```
Before:
  $ nvidia-smi | grep "Free"
  GPU 0 Free: 79.8 GB

After cuMemAlloc(20GB):
  $ nvidia-smi | grep "Free"
  GPU 0 Free: 59.8 GB  ← 确实减少了 20GB

✅ Validation: NVML + nvidia-smi 观察到真实显存变化
```

#### Level 3: Runtime Metrics
```
Kernel Execution Metrics:
  ├─ kernel_launch_count: 1
  ├─ kernel_execution_time_us: 234
  ├─ gpu_memory_allocated_bytes: 20971520
  ├─ gpu_memory_freed_bytes: 20971520
  ├─ cuda_error_code: 0  (CUDA_SUCCESS)
  └─ bandwidth_gb_s: 850

✅ Validation: 所有指标无异常，内存平衡
```

### 第一个真实 GPU 测试用例

**File**: `test/gpu_basic_add.s`

```s
package neurx.test.gpu_basic

use std.vec.vec

func main() int {
    A := vec[int]()
    B := vec[int]()
    C := vec[int]()
    
    A.push(1)  A.push(2)  A.push(3)  A.push(4)
    B.push(5)  B.push(6)  B.push(7)  B.push(8)
    
    gpu_device := init_device(0)
    
    gpu_A_addr := allocate_device_memory(gpu_device, 16)
    gpu_B_addr := allocate_device_memory(gpu_device, 16)
    gpu_C_addr := allocate_device_memory(gpu_device, 16)
    
    copy_host_to_device(gpu_device, gpu_A_addr, A)
    copy_host_to_device(gpu_device, gpu_B_addr, B)
    
    kernel_id := load_kernel(gpu_device, "vector_add")
    
    launch_kernel(gpu_device, kernel_id, gpu_A_addr, gpu_B_addr, gpu_C_addr, 4)
    
    synchronize(gpu_device)
    
    copy_device_to_host(gpu_device, gpu_C_addr, C)
    
    expected := vec[int]()
    expected.push(6)  expected.push(8)  expected.push(10)  expected.push(12)
    
    verified := verify_result(C, expected)
    
    free_device_memory(gpu_device, gpu_A_addr)
    free_device_memory(gpu_device, gpu_B_addr)
    free_device_memory(gpu_device, gpu_C_addr)
    
    destroy_device(gpu_device)
    
    if verified { 1 } else { 0 }
}
```

**Validation Output**:
```
✅ Test: gpu_basic_add
├─ Functional: PASS (result [6,8,10,12] correct)
├─ Physical: PASS (GPU 0 VRAM: 79.8GB → 59.8GB → 79.8GB)
├─ Runtime:
│  ├─ Execution time: 234 μs
│  ├─ Memory allocated: 48 bytes
│  ├─ Memory freed: 48 bytes ✅ (no leak)
│  ├─ CUDA errors: 0
│  └─ Bandwidth: 850 GB/s
└─ Status: HARDWARE-BACKED ✅
```

---

## 改进的架构设计

### 1. AI-aware Scheduler（不是 Linux CFS 翻版）

```s
struct ai_workload {
    string workload_id
    string model_id
    int workload_type          // inference | training
    int priority
    int requested_gpu_count
    int requested_gpu_memory_mb
    
    // AI-specific fields
    int tensor_memory_mb
    int kv_cache_memory_mb
    int batch_size
    int sequence_length
    int deadline_ms
    
    // Affinity
    int numa_preference
    int device_affinity
}

struct ai_scheduler_decision {
    int allocated_gpu_id
    int allocated_gpu_memory_mb
    int allocated_numa_node
    int estimated_latency_ms
}

func schedule_ai_workload(ai_workload job) ai_scheduler_decision {
    // Not Linux CFS: AI-aware scheduling
    // Consider: tensor memory, KV cache, batch size
    // Not just CPU time
}
```

**调度决策树**：
```
                AI Workload
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
    GPU Quota Check        Memory Check
    (cgroup)               (tensor VM)
        │                       │
        ├─ Reserved: 40GB   ├─ HBM needed: 20GB
        ├─ Available: 30GB  ├─ KV needed: 10GB
        └─ Sufficient? ✓    └─ Total: 30GB needed
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
                GPU 0                    GPU 1
            HBM: 80GB total         HBM: 80GB total
            Used: 50GB              Used: 30GB
            Free: 30GB  ✓           Free: 50GB  ✓
                    │                       │
                    └───────────┬───────────┘
                                ▼
                    Select GPU 1 (lower contention)
                                │
                                ▼
                        Execute Workload
```

### 2. Tensor Virtual Memory（AI-native VM）

**不是**：Linux-style VA/PA + swapping

**是**：
```
Tensor Virtual Address Space
        │
        ├─ Model Weights Pages (500GB)
        ├─ KV Cache Pages (100GB active)
        ├─ Activation Pages (dynamic)
        ├─ Optimizer State (training only)
        └─ Gradient Pages (training only)

Physical Backing
        │
        ├─ GPU 0 HBM: 80GB (layers 0-10)
        ├─ GPU 1 HBM: 80GB (layers 11-23)
        ├─ CPU DRAM: 256GB (cold weights + KV spill)
        ├─ NVMe: 1TB (frozen weights)
        └─ Remote GPU: (in future multi-node)
```

**核心差异**：
```
Linux VM:        不感知应用内容
    VA → PA (generic pages)

Tensor VM:       感知 AI 对象
    Model Tensor Page → GPU 0 HBM
    KV Cache Page → GPU 0 HBM (hot) / CPU DRAM (cold)
    Weight Page → NVMe (frozen) / CPU DRAM (loading)
```

---

## 新的项目优先级

### ❌ 不做（冻结）
```
BPF / eBPF kernel VM
namespace isolation
hypervisor / KVM
device tree parsing
cgroup v2 new features
...
```
已有 13+ kernel subsystems 足够。

### ✅ 必做（有序）

#### Phase 1: Boot Chain（1 周）
- NeurX kernel 能启动
- Runtime initialization
- Memory allocator 工作
- 日志/追踪基础

**验收**: `print("NeurX Boot OK")`

#### Phase 2: Real GPU Integration（2 周）⭐ 当前最高优先级
- CUDA Driver API 集成
- cuMemAlloc/Free 工作
- cuLaunchKernel 执行
- 三层验证（functional + physical + metrics）

**验收**: gpu_basic_add test PASS + nvidia-smi 验证

#### Phase 3: Tensor Kernel（2 周）
- GEMM 在 GPU 上执行
- Tensor allocator 与 Device ABI 集成
- 数值精度验证

**验收**: Matrix multiply benchmark

#### Phase 4: AI Scheduler Integration（2 周）
- 真实 workload dispatch
- cgroup quota 强制
- Multi-GPU 分配

**验收**: Concurrent workloads, resource isolation

#### Phase 5: Transformer E2E（3 周）
- Qwen-7B model load
- Prefill + Decode loop
- KV Cache paging
- Token generation

**验收**: Model inference, output correctness

#### Phase 6: Multi-GPU + Collective（2 周）
- NCCL AllReduce
- Multi-GPU data parallel
- Synchronization + load balance

**验收**: 4-GPU training, all-reduce bandwidth

#### Phase 7: Production Hardening（4 周）
- OOM handling
- GPU failure recovery
- Memory leak detection
- Long-running stability test
- Performance regression test

**验收**: 72-hour stress test, no crashes

---

## 最终纵向架构

```
┌──────────────────────────────────────────┐
│        NeurX Serving API / CLI           │
│  submit_inference_request(prompt)        │
└───────────────┬──────────────────────────┘
                │
┌───────────────▼──────────────────────────┐
│      NeurX AI Runtime                    │
│  inference_engine / training_coordinator │
└───────────────┬──────────────────────────┘
                │
┌───────────────▼──────────────────────────┐
│    AI-Aware Scheduler                    │
│  (tensor memory, KV cache, batch size)   │
└───────────────┬──────────────────────────┘
                │
    ┌───────────┼──────────┬────────────┐
    ▼           ▼          ▼            ▼
┌─────────┐ ┌────────┐ ┌────────┐ ┌──────────┐
│ cgroup  │ │Tensor  │ │NUMA    │ │Device    │
│ quota   │ │Virtual │ │topo    │ │affinity  │
│         │ │Memory  │ │        │ │          │
└────┬────┘ └───┬────┘ └────┬───┘ └────┬─────┘
     └──────────┼────────────┼─────────┘
                │
    ┌───────────▼──────────────────────┐
    │    Device Allocator              │
    │  Allocate GPU/CPU memory         │
    └───────────┬──────────────────────┘
                │
    ┌───────────▼──────────────────────┐
    │    Device ABI                    │
    │  init, alloc, launch, sync       │
    └───────────┬──────────────────────┘
                │
    ┌───────────▼──────────────────────┐
    │    CUDA / ROCm / Ascend Driver   │
    │  CUDA API / HIP / CANN           │
    └───────────┬──────────────────────┘
                │
    ┌───────────▼──────────────────────┐
    │    GPU Hardware                  │
    │  H100 / A100 / MI300 / Ascend910 │
    └───────────┬──────────────────────┘
                │
    ┌───────────▼──────────────────────┐
    │    Kernel Execution              │
    │  Matrix Mul, Softmax, Attention  │
    └───────────┬──────────────────────┘
                │
    ┌───────────▼──────────────────────┐
    │    Collective Operations         │
    │  AllReduce, AllGather, Broadcast │
    └───────────┬──────────────────────┘
                │
    ┌───────────▼──────────────────────┐
    │    KV Cache / Paging             │
    │  Manage prefill/decode memory    │
    └───────────┬──────────────────────┘
                │
    ┌───────────▼──────────────────────┐
    │    Sampling / Decoding           │
    │  Top-k, temperature              │
    └───────────┬──────────────────────┘
                │
    ┌───────────▼──────────────────────┐
    │    Output Token                  │
    │  Return to application           │
    └───────────┬──────────────────────┘
                │
    ┌───────────▼──────────────────────┐
    │    Metrics / Tracing             │
    │  perf, trace, profiler           │
    └──────────────────────────────────┘
```

---

## Production 标准（远高于 L5）

```
L1  Compile                     ✅ v2.0
L2  Boot                        → 本周
L3  Real GPU                    → 2周 ⭐
L4  Tensor Kernel               → 4周
L5  AI Scheduler                → 6周
L6  Transformer E2E             → 9周
L7  Multi-GPU Collective        → 11周
L8  OOM / Failure Recovery      → 15周
L9  72h Stability               → 16周
L10 Performance Benchmark       → 17周
    ↓
    Production Ready
```

---

## 核心成功指标

| 指标 | 当前 | 2周目标 | 说明 |
|------|------|--------|------|
| GPU Basic Kernel | ❌ | ✅ | vector_add 在 H100 执行 |
| Physical VRAM Tracking | ❌ | ✅ | nvidia-smi 可验证 |
| CUDA Error Handling | ❌ | ✅ | cuGetErrorString 正确 |
| Tensor GEMM | ❌ | → | Matrix multiply benchmark |
| Multi-Workload Scheduler | ⚠️ (logic only) | → | 真实资源隔离 |
| Qwen Inference | ❌ | ❌ | 后续里程碑 |

---

## 关键改变

1. **❌ 停止说"已实现 BPF、namespace、hypervisor"**
   - 代码存在但未验证
   - 不是优先级

2. **✅ 开始说"已打穿 Device ABI → CUDA → GPU"**
   - 可观测、可验证
   - 是 NeurX 的核心差异

3. **重新定义 Scheduler / Memory**
   - 不是 Linux 翻版
   - 是 AI-native 设计

4. **定义 Production**
   - 远超 Level 5 Qwen
   - 需要稳定性、故障恢复、基准

---

## 总结

> **NeurX 的终极竞争力不是"有多少 OS 模块"，而是"能不能用 S 语言控制一次真实 GPU 执行，并管理多卡、容错、性能"。**

**从今天开始**：
- 🔒 冻结 OS 模块横向扩展
- 🚀 全力推进 S → Device ABI → CUDA → GPU
- 📊 收集三层验证证据（functional + physical + metrics）
- 🎯 两周内通过 gpu_basic_add Level 1, 2, 3 验收

这条线路一旦通，NeurX 的故事就从"我实现了 Linux 功能"变成了"**我用 S 控制 AI 硬件**"。
