// NeurX Runtime Contracts - 完整接口规范
//
// 这 16 个 Contract 定义了世界级训练框架的核心架构。
// 对标：PyTorch + JAX + Megatron-Core

## 📋 16 个核心 Contract

### Layer 0: 存储与内存
```
contracts/storage_api.s          存储容器（数据实际所在）
contracts/memory_api.s           原始内存管理（allocate/deallocate）
contracts/allocator_api.s        内存分配策略（Caching/Arena/etc）
contracts/tensor_impl_api.s      Tensor 内部实现（Handle 之下）
```

### Layer 1: 硬件抽象
```
contracts/device_api.s           设备资源（仅内存和属性）
contracts/stream_api.s           异步执行流
contracts/event_api.s            同步点（记录和等待）
```

### Layer 2: 类型系统
```
contracts/dtype_api.s            数据类型 + 集中式类型提升
contracts/layout_api.s           数据排布（NCHW/NHWC/Blocked）
```

### Layer 3: 内核与调度
```
contracts/kernel_api.s           Forward + Backward（分离设计）
contracts/dispatcher_api.s       内核选择和路由
contracts/operator_api.s         设备无关算子（纯数学）
```

### Layer 4: 执行
```
contracts/execution_plan_api.s   执行计划（融合、CUDA Graph）
contracts/executor_api.s         执行引擎（Eager/Compiled/JIT）
```

### Layer 5: 训练
```
contracts/autograd_api.s         自动求导（完整 Node/Edge/Engine）
contracts/optimizer_api.s        优化器（SGD/Adam/AdamW + state_dict）
contracts/serialization_api.s    模型和检查点持久化
```

### Layer 6: 基础设施
```
contracts/profiler_api.s         性能监测（不在 Kernel 中）
contracts/registry_api.s         插件和扩展系统
```

## 🏗️ 分层架构图

```
┌─────────────────────────────────────────────────────┐
│           User APIs (Training Loop)                 │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│  Layer 5: Operator + Autograd + Optimizer (Device-Agnostic)
│                                                     │
│  ├─ operator_api.s   (MatMul, Add, Softmax, ...)  │
│  ├─ autograd_api.s   (Backward + GradFlow)        │
│  ├─ optimizer_api.s  (SGD, Adam, AdamW + state_dict)
│  └─ executor_api.s   (Eager, Compiled, JIT)       │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│  Layer 4: Dispatcher + Execution Planning           │
│                                                     │
│  ├─ dispatcher_api.s        (select_kernel)        │
│  ├─ execution_plan_api.s    (fusion, CUDA graph)   │
│  ├─ dtype_api.s             (type promotion)       │
│  └─ profiler_api.s          (record metrics)       │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│  Layer 3: Kernels (Device-Specific)                 │
│                                                     │
│  ├─ kernel_api.s (Forward + Backward)              │
│  └─ CPU/CUDA/CANN/Metal implementations            │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│  Layer 2: Device Abstraction                        │
│                                                     │
│  ├─ device_api.s      (memory, properties)         │
│  ├─ stream_api.s      (async execution)            │
│  ├─ event_api.s       (synchronization)            │
│  └─ layout_api.s      (data arrangement)           │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│  Layer 1: Memory & Allocators                       │
│                                                     │
│  ├─ memory_api.s      (raw allocation)             │
│  └─ allocator_api.s   (caching, arena, ...)        │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│  Layer 0: Storage & Tensor Implementation           │
│                                                     │
│  ├─ tensor_api.s      (public Handle)              │
│  ├─ tensor_impl_api.s (internal Implementation)    │
│  └─ storage_api.s     (data container)             │
└─────────────────────────────────────────────────────┘
```

## 🔗 关键依赖关系

```
operator_api.s
  ↓
  dispatcher_api.s
  ↓
  kernel_api.s
  ↓
  device_api.s + allocator_api.s + stream_api.s
  ↓
  memory_api.s
  ↓
  tensor_impl_api.s + storage_api.s
```

```
autograd_api.s
  ├─ requires forward() outputs
  └─ implements backward() via chain rule

optimizer_api.s
  ├─ requires gradient (from autograd)
  └─ requires state_dict (from serialization)

executor_api.s
  ├─ uses dispatcher_api.s
  ├─ uses profiler_api.s
  └─ uses execution_plan_api.s

serialization_api.s
  └─ requires state_dict (optimizer state)
```

## 🎯 关键设计决策

### 1️⃣ Tensor = Handle (+ TensorImpl)
```
不要：Tensor 直接包含所有数据
✅ 正确：Tensor 是 Handle，指向 TensorImpl
好处：零复制操作（view, reshape, transpose）
```

### 2️⃣ Memory 与 Allocator 分离
```
不要：单一 MemoryManager
✅ 正确：Memory (资源) + Allocator (策略)
好处：灵活的分配策略（Caching, Arena, Async）
```

### 3️⃣ Device 不创建 Stream
```
不要：Device.create_stream()
✅ 正确：StreamManager 独立管理 Stream
好处：清晰的职责分离，Device 保持简单
```

### 4️⃣ Kernel 分离 Forward + Backward
```
不要：interface Kernel { forward(); backward() }
✅ 正确：IForwardKernel + IBackwardKernel
好处：清晰的职责，易于优化和测试
```

### 5️⃣ Dispatcher 简化（Phase 1）
```
Phase 1: switch(device) { case CPU:..., case CUDA:... }
Phase 11: DispatchKey + Meta + Composite + Autograd
好处：早期简单，后期升级不改接口
```

### 6️⃣ Operator 必须 Deterministic
```
❌ NO malloc, printf, CUDA API, global state
✅ Pure math, pre-allocated, deterministic
好处：可重复性、可测试性、可并行化
```

### 7️⃣ DType Promotion 集中
```
不要：每个 Kernel 自己决定
✅ 正确：Dispatcher 层统一决策
好处：一致的类型提升规则
```

### 8️⃣ Profiler 不在 Kernel 中
```
不要：kernel.profile() 或 @profiler decorator
✅ 正确：Dispatcher/Executor 统一记录
好处：Kernel 干净，Profiler 完整
```

### 9️⃣ Autograd 完整设计（Node/Edge/Engine）
```
Phase 1-2：简单实现（可能不用所有概念）
Phase 3+：完整利用设计（高效反向传播）
好处：接口稳定，实现可以逐步完善
```

### 🔟 Registry 作为插件系统
```
所有组件都通过 Registry 注册：
  - Devices
  - Kernels
  - Operators
  - Optimizers
  - Data formats
好处：插件化架构，易于扩展
```

## 📝 使用模式

### 创建 Tensor
```s
factory := TensorFactory()
x := factory.randn([2, 3, 4], Float32, device_cpu)
```

### 执行 Operator（via Dispatcher）
```s
ctx := OperatorContext{requires_grad: true, dispatcher: disp}
y := matmul_operator(x, w, ctx)
```

### 计算梯度
```s
loss := cross_entropy(y, target)
loss.backward()
```

### 优化器步
```s
optimizer := AdamW(params, lr=0.001)
optimizer.step()
```

### 保存检查点
```s
checkpoint := Checkpoint{
  params: model.state_dict(),
  optimizer_state: optimizer.state_dict(),
  epoch: current_epoch,
}
serializer.save_checkpoint(path, checkpoint)
```

### 恢复检查点
```s
checkpoint := serializer.load_checkpoint(path)
model.load_state_dict(checkpoint.params)
optimizer.load_state_dict(checkpoint.optimizer_state)
```

## ✅ Phase -1 完成标准

- [x] 16 个 Contract 文件完整
- [x] 清晰的分层和依赖
- [x] 详细的接口文档
- [x] 12 条原则文档化
- [x] 生命周期设计明确
- [x] 无循环依赖
- [x] 支持所有必需的概念（Stream, Event, Autograd, etc）
- [x] 设计预留了 Phase 11 的优化空间

## ⏭️ Phase 0 准备

进入 Phase 0 前需要：

1. ✅ 架构评审（6 项评审）
2. ✅ Contract 冻结审批
3. ✅ 构建 PyTorch 参考系统
4. ✅ 建立对比工具
5. ✅ 创建测试框架

然后才能进入 Phase 1 (Tensor Runtime)。

---

**NeurX Runtime Contracts - Ready for Production** ✅
