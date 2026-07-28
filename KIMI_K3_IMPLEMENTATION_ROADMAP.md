# NeurX 世界级 ML Runtime - 最终路线图 (2026-07-28 Final Version)

**目标**: 构建对标 PyTorch、JAX、MindSpore 的自主训练框架

**核心理念**: Interface First（接口优先） + Hardware Abstraction（硬件抽象） + Device-Agnostic Operators（硬件无关算子）

**指导原则**:
- 接口设计 > 实现细节
- 硬件抽象 > 硬件适配
- 性能可观测 > 性能黑盒
- 完整测试 > 功能堆积
- 清晰架构 > 快速功能

---

## 项目最终架构（世界级框架标准）

```
neurx/
├── contracts/                        # ⭐⭐⭐⭐⭐ Phase -1: 架构契约（接口定义）
│   ├── tensor_api.s                  # Tensor 接口定义
│   ├── device_api.s                  # Device 接口定义
│   ├── memory_api.s                  # Memory 接口定义
│   ├── kernel_api.s                  # Kernel 接口定义
│   ├── operator_api.s                # Operator 接口定义
│   ├── dispatcher_api.s              # Dispatcher 接口定义
│   ├── autograd_api.s                # Autograd 接口定义
│   ├── optimizer_api.s               # Optimizer 接口定义
│   └── executor_api.s                # Executor 接口定义
│
├── runtime/                          # ⭐⭐⭐⭐⭐ Runtime 核心
│   │
│   ├── core/                         # Layer 1: 最底层 Tensor
│   │   ├── tensor.s                  # Tensor 数据结构
│   │   ├── storage.s                 # 数据存储（内存指针）
│   │   └── dtypes.s                  # 数据类型（float32, int32, etc.）
│   │
│   ├── device/                       # Layer 2: 设备抽象（最关键）
│   │   ├── device.s                  # Device 基类
│   │   ├── cpu/
│   │   │   ├── cpu_device.s
│   │   │   └── cpu_allocator.s
│   │   ├── cuda/
│   │   │   ├── cuda_device.s
│   │   │   ├── cuda_allocator.s
│   │   │   ├── cuda_stream.s
│   │   │   └── cuda_properties.s
│   │   ├── cann/
│   │   │   ├── cann_device.s
│   │   │   └── cann_allocator.s
│   │   └── metal/
│   │       └── metal_device.s
│   │
│   ├── memory/                       # Layer 3: 内存管理
│   │   ├── allocator.s               # 内存分配器接口
│   │   ├── pool_allocator.s          # 内存池分配
│   │   ├── cache.s                   # KV Cache 管理
│   │   └── fragmentation.s           # 碎片管理
│   │
│   ├── kernel/                       # Layer 4: 硬件内核（Device-specific）
│   │   ├── cpu/
│   │   │   ├── cpu_matmul.s
│   │   │   ├── cpu_softmax.s
│   │   │   ├── cpu_layernorm.s
│   │   │   └── cpu_*.s
│   │   ├── cuda/
│   │   │   ├── cuda_matmul.s
│   │   │   ├── cuda_softmax.s
│   │   │   ├── cuda_layernorm.s
│   │   │   └── cuda_*.s              # 可选：调用 CUDA kernels
│   │   ├── cann/
│   │   │   └── cann_*.s
│   │   └── metal/
│   │       └── metal_*.s
│   │
│   ├── operator/                     # Layer 5: 高层算子（Device-agnostic）
│   │   ├── linear.s                  # MatMul + Bias（调 Dispatcher）
│   │   ├── attention.s               # Attention 算子（调 Dispatcher）
│   │   ├── norm.s                    # LayerNorm（调 Dispatcher）
│   │   ├── activation.s              # ReLU, SwiGLU（调 Dispatcher）
│   │   ├── loss.s                    # CrossEntropy（调 Dispatcher）
│   │   ├── rope.s                    # RoPE（调 Dispatcher）
│   │   └── broadcast.s               # Reshape, Transpose, View（调 Dispatcher）
│   │
│   ├── dispatcher/                   # Layer 6: 调度器（最核心）
│   │   ├── dispatcher.s              # 根据 Device 选择 Kernel
│   │   └── registry.s                # Kernel 注册表
│   │
│   ├── compiler/                     # Layer 7: 编译优化
│   │   ├── graph_optimizer.s         # 图优化（常数折叠、死代码删除）
│   │   ├── fusion.s                  # 算子融合（多个 Op → 1 Kernel）
│   │   ├── memory_planner.s          # 内存规划
│   │   ├── layout_optimizer.s        # 数据布局优化
│   │   └── compiler.s                # 编译主逻辑
│   │
│   ├── executor/                     # Layer 8: 执行引擎
│   │   ├── eager.s                   # Eager 执行
│   │   ├── compiled.s                # 编译执行
│   │   ├── aot.s                     # AOT (Ahead-Of-Time)
│   │   └── jit.s                     # JIT (Just-In-Time)
│   │
│   ├── graph/                        # Layer 9: 计算图与自动求导
│   │   ├── node.s                    # 计算节点
│   │   ├── graph.s                   # 计算图
│   │   ├── autograd.s                # 自动求导（Chain Rule）
│   │   └── scheduler.s               # 执行调度
│   │
│   ├── optimizer/                    # Layer 10: 优化器
│   │   ├── adamw.s
│   │   ├── sgd.s
│   │   ├── lamb.s
│   │   └── shampoo.s
│   │
│   ├── checkpoint/                   # 检查点与恢复
│   │   ├── saver.s
│   │   ├── loader.s
│   │   └── resume.s                  # Resume 一致性验证
│   │
│   ├── distributed/                  # 分布式运行时（Phase 9）
│   │   ├── process_group.s
│   │   ├── communicator.s
│   │   ├── tensor_parallel.s
│   │   ├── pipeline_parallel.s
│   │   └── zero.s
│   │
│   └── profiler/                     # ⭐⭐⭐⭐⭐ 性能分析（从 Phase 0 开始）
│       ├── profiler.s                # 性能分析主程序
│       ├── kernel_timer.s            # Kernel 耗时
│       ├── memory_tracker.s          # 内存使用
│       ├── bandwidth.s               # 带宽统计
│       ├── flops.s                   # FLOPS 计算
│       └── throughput.s              # Tokens/s
│
├── interface/                        # 可插拔接口（应用层）
│   ├── attention/
│   │   ├── interface.s
│   │   ├── standard.s
│   │   ├── mla.s
│   │   └── kda.s
│   ├── ffn/
│   │   ├── interface.s
│   │   ├── dense.s
│   │   ├── moe.s
│   │   └── latent_moe.s
│   └── optimizer/
│       ├── interface.s
│       └── *.s
│
├── model/                            # 模型应用层（简单编排）
│   ├── transformer_block.s
│   ├── transformer.s
│   ├── qwen.s
│   ├── llama.s
│   └── kimi.s
│
├── test/                             # 测试体系（从 Phase 0 开始）
│   ├── functional/
│   │   ├── test_tensor.s
│   │   ├── test_operators.s
│   │   └── test_autograd.s
│   ├── numerical/
│   │   ├── test_forward_alignment.s     # vs HF
│   │   ├── test_backward_alignment.s    # vs HF
│   │   └── test_numerical_stability.s
│   ├── stress/
│   │   ├── test_oom.s
│   │   ├── test_resume.s
│   │   ├── test_random_shape.s
│   │   ├── test_large_batch.s
│   │   └── test_multi_gpu.s
│   └── golden/
│       ├── golden_test.s
│       └── golden_dataset.s
│
├── reference/                        # 参考实现与验证
│   ├── export/
│   │   ├── export_tensor.py
│   │   ├── export_forward.py
│   │   ├── export_gradient.py
│   │   ├── export_optimizer.py
│   │   └── export_checkpoint.py
│   └── compare/
│       ├── compare_forward.s
│       ├── compare_backward.s
│       ├── compare_optimizer.s
│       └── compare_resume.s
│
├── ci/                               # CI 流程
│   ├── Makefile.test
│   ├── benchmark.s
│   └── profiler.s
│
└── config.yaml                       # 配置文件
```

---

## 核心架构层次（最重要）

```
Model Layer
    ↓ 调用
Interface Layer (Attention / FFN)
    ↓ 调用
Operator Layer (hardware-agnostic)
    ↓ 调用
Dispatcher (选择 Kernel)
    ↓ 调用
Kernel Layer (CPU/CUDA/CANN)
    ↓ 操作
Device & Memory Layer
    ↓ 底层
Tensor Core

关键设计:
  ✓ Model 完全不知道硬件
  ✓ Operator 完全不知道硬件
  ✓ Dispatcher 做决策（CPU 选 CPU Kernel，CUDA 选 CUDA Kernel）
  ✓ 新增硬件只需: Device + Kernel + 注册到 Dispatcher
  ✓ 新增 Operator 只需: Device-agnostic 实现 + Dispatcher 调度
```

---

## 完整训练闭环（所有阶段围绕这个）

```
JSONL Dataset
    ↓
HF-compatible Tokenizer
    ↓ 
DataLoader (batching)
    ↓
Tensor (Device: CPU/CUDA)
    ↓
Forward Pass (Transformer)
    ├─ Operator (device-agnostic)
    ├─ Dispatcher (choose kernel)
    └─ Kernel (CPU/CUDA implementation)
    ↓
Loss Computation
    ↓
Backward Pass (Autograd)
    ├─ Chain Rule
    ├─ Gradient accumulation
    └─ Device dispatch
    ↓
Optimizer Step (AdamW)
    ↓
Checkpoint Save
    ├─ Model state
    ├─ Optimizer state
    ├─ Training state
    └─ Device state
    ↓
Resume Training (一致性验证)
    ├─ Load all state
    ├─ Verify loss continuity
    └─ Continue training
    ↓
Inference
```

---

## 12 个阶段的新路线（Phase -1 开始）

### Phase -1 ⭐⭐⭐⭐⭐: 架构契约（Interface First） (3-5 天)

**为什么这么早？** PyTorch、JAX、MindSpore 都是这样做的。先定义接口，再写代码，避免未来推倒重来。

**关键组件**:

```s
// contracts/tensor_api.s
interface Tensor {
    shape: []int
    stride: []int
    dtype: DataType
    device: Device
    requires_grad: bool
    
    func reshape(shape: []int) → Tensor
    func transpose(axes: []int) → Tensor
    // ...
}

// contracts/device_api.s
interface Device {
    name: string
    type: string  // "cpu", "cuda", "cann", "metal"
    
    func allocate(size: int) → Buffer
    func deallocate(buffer: Buffer)
    func synchronize()
    // ...
}

// contracts/kernel_api.s
interface Kernel {
    func execute(inputs: []Tensor) → []Tensor
}

// contracts/dispatcher_api.s
interface Dispatcher {
    func select_kernel(op_name: string, device: Device) → Kernel
}

// contracts/operator_api.s
interface Operator {
    // 调 Dispatcher 执行
    func forward(inputs: []Tensor) → Tensor
}

// contracts/autograd_api.s
interface Operation {
    func backward(grad: Tensor) → []Tensor
}

// ... 其他接口
```

**验收标准**:
```
✓ 所有关键接口已定义
✓ 接口之间的依赖关系清晰
✓ 能对标 PyTorch/JAX 的接口设计
```

**好处**:
- 团队对未来架构有清晰共识
- 新成员能快速理解框架设计
- 避免后期推倒重来

---

### Phase 0 ⭐⭐⭐⭐⭐: CI、测试、基准、性能分析 (3-4 天)

**关键组件**:

1. **Functional Test** (结果一致)
```s
test/functional/test_tensor.s
test/functional/test_operators.s
```

2. **Numerical Test** (数值精度)
```s
test/numerical/test_forward_alignment.s    # vs HF (误差 < 1e-4)
test/numerical/test_backward_alignment.s   # vs HF (误差 < 1e-3)
test/numerical/test_numerical_stability.s
```

3. **Stress Test** (极限条件)
```s
test/stress/test_oom.s              # 内存溢出恢复
test/stress/test_resume.s           # 10000 步后恢复一致
test/stress/test_random_shape.s     # 随机 shape
test/stress/test_large_batch.s      # 大 batch
test/stress/test_multi_gpu.s        # 多卡一致性
```

4. **Profiler** (性能分析)
```s
runtime/profiler/kernel_timer.s     # 每个 Kernel 耗时
runtime/profiler/memory_tracker.s   # 内存使用曲线
runtime/profiler/throughput.s       # Tokens/s
```

**验收标准**:
```
✓ make test 运行所有测试
✓ make benchmark 生成报告
✓ make profile 生成性能分析
✓ Regression detection 工作
```

---

### Phase 1 ⭐⭐⭐⭐⭐: Tensor + Memory + Device (4-5 天)

**目标**: Tensor 能正确操作，支持多种 Device

**关键实现**:

1. **Tensor 核心**
```s
runtime/core/tensor.s
  ├─ shape, stride, dtype, device
  ├─ reshape (stride 变，不 copy)
  ├─ transpose (stride 重排)
  └─ view / slice / contiguous
```

2. **Device 抽象** (最关键)
```s
runtime/device/device.s
  ├─ CPU Device (基础实现)
  ├─ CUDA Device (GPU 支持)
  ├─ CANN Device (昇腾支持)
  └─ Metal Device (Apple 支持)
```

3. **Memory 管理**
```s
runtime/memory/allocator.s
  ├─ Pool allocator (预分配)
  ├─ Cache management
  └─ Fragmentation handling
```

**验收标准**:
```
✓ Tensor 支持 reshape/transpose 不 copy 数据
✓ Device 抽象能支持 CPU/CUDA
✓ Memory allocation 正确
✓ make test-tensor 全部通过
```

---

### Phase 2 ⭐⭐⭐⭐⭐: Kernel + Dispatcher (4-5 天)

**目标**: Kernel 与 Operator 分离，Dispatcher 智能调度

**关键实现**:

1. **Kernel 层** (Device-specific)
```s
runtime/kernel/cpu/
  ├─ cpu_matmul.s
  ├─ cpu_softmax.s
  ├─ cpu_layernorm.s
  └─ ... (CPU 实现)

runtime/kernel/cuda/
  ├─ cuda_matmul.s
  └─ ... (CUDA 实现或 kernel wrapper)
```

2. **Dispatcher** (最核心)
```s
runtime/dispatcher/dispatcher.s
  // MatMul(A, B) 调用
  // ↓
  // if device == CPU_DEVICE
  //     kernel = registry.get("matmul", CPU_DEVICE)
  // else if device == CUDA_DEVICE
  //     kernel = registry.get("matmul", CUDA_DEVICE)
  // ↓
  // kernel.execute(A, B)
```

**验收标准**:
```
✓ CPU Kernel 正确
✓ CUDA Kernel 正确（或 wrapper）
✓ Dispatcher 能正确选择
✓ 同一 Op 在不同 Device 结果一致
```

---

### Phase 3 ⭐⭐⭐⭐⭐: Operator Library (4-5 天)

**目标**: 所有算子与 HF 数值对齐，且通过 Dispatcher

**关键算子** (都调 Dispatcher):
```
Linear (MatMul + Bias)
Softmax
LayerNorm / RMSNorm
Activation (ReLU, SwiGLU, etc.)
Loss (CrossEntropy)
RoPE
Broadcast / Reshape / Transpose
```

**实现模式**:
```s
// runtime/operator/linear.s
func linear(x: Tensor, weight: Tensor, bias: Tensor) → Tensor {
    // 1. 选择 Kernel
    kernel = dispatcher.select_kernel("matmul", x.device)
    
    // 2. 执行
    output = kernel.execute(x, weight)
    output = output + bias
    
    // 3. 追踪梯度
    output.op = LinearOp(x, weight, bias)
    
    return output
}
```

**验收标准**:
```
✓ 每个算子与 HF 对齐 (误差 < 1e-4)
✓ 每个算子支持 backward
✓ CPU 和 CUDA 结果一致
✓ make test-operators 全部通过
```

---

### Phase 4 ⭐⭐⭐⭐⭐: Autograd Engine (2-3 天)

**目标**: 自动求导完整工作

**关键实现**:
```s
runtime/graph/autograd.s
  ├─ Chain Rule
  ├─ Gradient accumulation
  ├─ Topological sort
  └─ Device dispatch (梯度也要 dispatch)
```

**验收标准**:
```
✓ 梯度计算与 PyTorch 一致 (误差 < 1e-3)
✓ 支持复杂计算图
✓ 梯度也通过 Dispatcher 执行
✓ make test-autograd 全部通过
```

---

### Phase 5 ⭐⭐⭐⭐⭐: Optimizer + Checkpoint + Resume (2-3 天)

**目标**: 能保存/加载训练状态，Resume 一致性验证通过

**关键验证** (最重要):
```
Step 100: loss = 0.047398
  ↓ save checkpoint
  ↓
Load checkpoint
  ↓
Step 101: loss should = 0.047397
Step 102: loss should = 0.047396
  ↓
test/stress/test_resume.s: Loss 曲线是否连续？
```

**验收标准**:
```
✓ Checkpoint 包含完整状态
✓ Resume 后 loss 曲线连续
✓ 参数、Optimizer 状态完全一致
✓ 多次 Resume 结果相同
✓ make test-checkpoint-resume 通过
```

---

### Phase 6 ⭐⭐⭐⭐: Compiler (2-3 天)

**目标**: 图优化与算子融合

**关键组件**:
```s
runtime/compiler/graph_optimizer.s
  ├─ Constant folding (常数折叠)
  ├─ Dead code elimination (死代码删除)
  └─ Layout optimization (布局优化)

runtime/compiler/fusion.s
  ├─ LayerNorm + Add fusion
  ├─ Attention + Softmax fusion
  └─ MLP fusion
```

**好处**:
- 减少 Kernel 调用次数
- 提升性能 20-30%

**验收标准**:
```
✓ 融合后结果一致 (数值精度)
✓ 性能提升 > 10%
✓ make benchmark 显示改进
```

---

### Phase 7 ⭐⭐⭐⭐: Transformer Block 验证 (2-3 天)

**目标**: 单个 Block 与 HF 完全对齐

**验证**:
```
Forward ✓ (误差 < 1e-4)
Backward ✓ (误差 < 1e-3)
Optimizer Update ✓
Resume ✓
```

---

### Phase 8 ⭐⭐⭐⭐⭐: Qwen 完整训练闭环 (3-4 天)

**目标**: 能完整训练 24 层 Qwen

**验证**:
```
JSONL → Forward → Loss → Backward → Optimizer → Checkpoint → Resume → Inference
```

---

### Phase 9 ⭐⭐⭐⭐: LoRA / PEFT (1-2 天)

---

### Phase 10 ⭐⭐⭐⭐⭐: Distributed Runtime (5-7 天)

**目标**: 多卡训练

**关键**:
```
AllReduce (梯度同步)
Tensor Parallel
Pipeline Parallel
ZeRO 优化
```

---

### Phase 11 ⭐⭐⭐: 插件系统 (3-5 天)

**目标**: Attention / FFN 可切换

```
interface/attention/
  ├─ Standard
  ├─ MLA
  └─ KDA

interface/ffn/
  ├─ Dense
  ├─ MoE
  └─ LatentMoE
```

---

### Phase 12 ⭐⭐: RLHF / Agent (5-7 天)

---

## 关键创新：硬件抽象层

**PyTorch**:
```python
# 用户无需知道硬件
x = x + y
# PyTorch 自动 dispatch 到 CPU/CUDA kernel
```

**NeurX 设计**:
```s
// runtime/operator/linear.s
kernel = dispatcher.select_kernel("matmul", device)
// 自动选择 CPU 或 CUDA kernel
```

**新硬件添加**:
1. 实现 Device (allocate, synchronize, etc.)
2. 实现 Kernel (cpu_matmul.s 或 cuda_matmul.s)
3. 注册到 Dispatcher
4. ✅ 所有 Operator 自动支持新硬件

**结果**: 代码复用最大化，维护成本最小化

---

## 时间估算

| Phase | 任务 | 时间 |
|-------|------|------|
| -1 | Architecture Contracts | 3-5 天 |
| 0 | CI/Test/Benchmark/Profiler | 3-4 天 |
| 1 | Tensor + Memory + Device | 4-5 天 |
| 2 | Kernel + Dispatcher | 4-5 天 |
| 3 | Operator Library | 4-5 天 |
| 4 | Autograd | 2-3 天 |
| 5 | Optimizer + Checkpoint | 2-3 天 |
| 6 | Compiler | 2-3 天 |
| 7 | Transformer Block | 2-3 天 |
| 8 | Qwen Training | 3-4 天 |
| 9 | LoRA | 1-2 天 |
| 10 | Distributed | 5-7 天 |
| 11 | Plugins | 3-5 天 |
| 12 | RLHF/Agent | 5-7 天 |
| **总计** | | **45-60 天 (6-8 周)** |

---

## 为什么这个架构能对标 PyTorch？

| 特性 | NeurX | PyTorch |
|------|-------|---------|
| Device 抽象 | ✓ (Phase 1) | ✓ |
| Kernel 与 Operator 分离 | ✓ (Phase 2) | ✓ |
| Dispatcher 智能调度 | ✓ (Phase 2) | ✓ |
| Compiler & Fusion | ✓ (Phase 6) | ✓ (TorchScript) |
| Profiler | ✓ (Phase 0) | ✓ |
| Autograd | ✓ (Phase 4) | ✓ |
| Distributed | ✓ (Phase 10) | ✓ |
| 代码清晰度 | ✓ (纯 S 语言) | ~ (C++/Python) |
| 维护成本 | ✓ (低) | ~ (高) |

---

## 立即开始

```bash
# Step 1: 创建目录
mkdir -p runtime/{core,device,memory,kernel,operator,dispatcher,compiler,executor,graph,optimizer,checkpoint,distributed,profiler}
mkdir -p runtime/kernel/{cpu,cuda,cann,metal}
mkdir -p runtime/device/{cpu,cuda,cann,metal}
mkdir -p contracts test/{functional,numerical,stress,golden} interface/{attention,ffn} ci

# Step 2: Phase -1
touch contracts/tensor_api.s
touch contracts/device_api.s
touch contracts/kernel_api.s
touch contracts/dispatcher_api.s
touch contracts/operator_api.s
touch contracts/autograd_api.s
touch contracts/optimizer_api.s

# Step 3: Phase 0
touch ci/Makefile.test
touch test/functional/test_base.s
touch runtime/profiler/profiler.s
```

**决策**: 先花 3-5 天设计接口（Phase -1），再写代码。这样避免未来 6 个月后发现设计错误，推倒重来。

---

## 核心哲学

> **接口优先，不是功能优先。硬件无关，不是硬件绑定。性能可观测，不是黑盒。**

这是世界级框架与快速原型之间最大的区别。

快速原型: 功能快速 → 代码复杂 → 难以维护 → 最后推倒重来
世界级框架: 接口清晰 → 架构稳健 → 易于扩展 → 长期演进

NeurX 选择后者。
