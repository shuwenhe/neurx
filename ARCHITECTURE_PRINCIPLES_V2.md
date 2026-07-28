# NeurX 架构原则 V2 - 12 条不可违反的设计约束

这些原则指导了整个 Phase -1 V2 的 16 个核心 Contract 的设计。
遵守这些原则会让系统具备世界级框架（PyTorch、JAX、Megatron-Core）的素质。

## 1. 严格分层与隔离 (Layering & Isolation)

**原则**: 架构必须有明确的层级，只能向下调用，不能向上调用。

```
Layer 6: User API (Training Loop)
Layer 5: Runtime (Operator, Autograd, Optimizer) ← 设备无关
Layer 4: Execution Planning (ExecutionPlan, Scheduler)
Layer 3: Dispatcher & Routing (DType Promotion)
Layer 2: Kernels (Device-Specific Implementation)
Layer 1: Device Abstraction (Memory, Stream, Event)
Layer 0: Storage & Memory (TensorImpl, Storage, Allocator)
```

## 2. 设备无关性 (Device Agnosticism)

**原则**: Operator 层必须完全设备无关。

```
✅ 正确模式：
  kernel := dispatcher.select_kernel("op_name", device)
  kernel.forward(inputs, outputs)

❌ 禁止模式：
  if device == CUDA { cuda_specific() }
  CUDA_API_CALL()
  cudaMemcpy()
```

## 3. PyTorch 参考系统 (Reference System)

**原则**: 所有操作都要与 PyTorch 对齐（数值精度 < 1e-3）。

Phase 0 的全部职责是建立这个系统。

## 4. 梯度支持强制 (Gradient Support Mandatory)

**原则**: 每个 Tensor 操作都必须支持反向传播。

- 每个 Kernel 必须实现 backward()
- 梯度必须通过数值检查
- 没有例外

## 5. Operator 纯度约束 (Operator Determinism)

**原则**: Operator 必须是纯函数。

```
❌ 禁止:
  malloc() / new()
  printf()
  File I/O
  sleep() / timing
  Random (unseeded)
  Global state

✅ 必须:
  Pure math
  Pre-allocated tensors
  Dispatcher for kernels
  Deterministic execution
```

## 6. 可观测性从 Day 1 (Observability)

**原则**: Profiler 是架构的一部分，不是后补。

- Profiler 不在 Kernel 中（会污染实现）
- Profiler 在 Dispatcher/Executor 统一记录
- 导出到 Chrome Trace, TensorBoard, Perfetto

## 7. 四层测试金字塔 (Test Coverage)

**原则**: 每个阶段都必须通过所有层级的测试。

```
Tier 4: Integration Tests (完整训练)
Tier 3: Gradient Tests (反向传播正确)
Tier 2: Numerical Tests (vs PyTorch)
Tier 1: Functional Tests (基本正确)
```

## 8. Checkpoint/Resume 连续性 (Loss Curve Continuity)

**原则**: 这是最严格的约束。

在 Checkpoint/Resume 后，Loss 曲线必须连续（误差 < epsilon）。
如果跳跃，说明有严重 Bug（optimizer state、scheduler、seed、gradient）。

## 9. 最小 API 表面 (Minimal API Surface)

**原则**: Phase 1-8 的公开接口 < 50 个。

这迫使我们做好设计，用最少的接口表达最多的功能。

## 10. 新设备隔离 (Device Isolation)

**原则**: 新硬件的添加不能修改 Operator 层。

```
Adding new device (e.g., MI300X):
1. Define Device type
2. Implement Device & Memory management
3. Implement Kernels (MatMul, Add, etc.)
4. Register with Registry
5. Profit: 所有现有 Operator 自动工作
```

## 11. 演进不重写 (Evolution, not Rewrite)

**原则**: 不应该有 > 1000 行的重写。

- Phase 1-8: 逐步实现功能
- Phase 11: 优化而不是改写
- 接口保持稳定

## 12. 并发与异步 (Concurrency & Async)

**原则**: 虽然 Phase 1-8 单线程，接口要为多线程准备。

Stream 和 Event 的设计就是为此。
Phase 11+ 可以直接利用已有的接口。

---

这 12 条原则是 NeurX 稳定和可扩展的基础。
