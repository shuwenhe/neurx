# NeurX Architecture Principles (架构原则)

**目的**: 定义约束和原则，确保整个项目长期一致性和可维护性。

不讨论实现细节，只讨论原则。

---

## 核心原则 (Core Principles)

### 1. 分层与隔离 (Layering)

**原则**:
```
Model 层
    ↓ 只能调用
Operator 层
    ↓ 只能调用
Dispatcher 层
    ↓ 只能调用
Kernel 层
    ↓ 只能调用
Device 层
```

**具体规则**:
- ❌ Model 不得直接访问 Device API
- ❌ Model 不得直接调用 Kernel
- ❌ Operator 不得直接访问 CUDA
- ❌ Kernel 不得依赖 Model
- ❌ Device 不得知道 Model 的存在
- ✅ Operator 必须通过 Dispatcher 执行 Kernel

**验证方式**: 
- 代码审查：检查 import 关系
- 单元测试：每层独立测试

---

### 2. 设备无关性 (Device Agnosticism)

**原则**: 所有 Operator 必须硬件无关。硬件选择交给 Dispatcher。

**具体规则**:
- ❌ 不允许在 Operator 中写 `if device == CUDA_DEVICE`
- ❌ 不允许在 Operator 中直接调用 CUDA 函数
- ✅ Operator 调用 Dispatcher，Dispatcher 选择 Kernel
- ✅ 新增硬件（CANN、Metal）不修改任何 Operator

**验证方式**:
- 同一 Operator 在 CPU/CUDA/CANN 上结果一致
- 梯度也一致

---

### 3. 参考系统 (Reference System)

**原则**: 所有 Operator 必须对标参考实现（PyTorch）。

**具体规则**:
```
步骤 1: PyTorch 实现
    x = torch.randn(2, 3)
    y = torch.matmul(x, w)

步骤 2: Export 参考数据
    export_forward(x, w, y)       // 导出前向输出
    export_gradient(x, w, y)      // 导出梯度

步骤 3: S 实现
    y_s = matmul(x_s, w_s)

步骤 4: Compare
    assert_close(y, y_s, eps=1e-4)
    assert_close(grad_x, grad_x_s, eps=1e-3)
```

**具体规则**:
- ❌ Operator 不允许没有 Reference Test
- ❌ Forward 误差 > 1e-4 不许上线
- ❌ Backward 误差 > 1e-3 不许上线
- ✅ 所有 Operator 必须有 PyTorch 对标实现
- ✅ 所有 Operator 必须有 Gradient Check（数值梯度验证）

**验证方式**:
- `reference/pytorch/` - PyTorch 参考代码
- `reference/export/` - 数据导出工具
- `test/numerical/` - 数值对齐测试

---

### 4. 梯度支持 (Gradient Support)

**原则**: 所有 Tensor 操作必须支持自动求导。

**具体规则**:
- ❌ 不允许有"仅支持前向"的 Operator
- ✅ 每个 Operator 必须实现 backward()
- ✅ Backward 计算必须经过 Dispatcher（也支持 Device Dispatch）
- ✅ Gradient Check 必须通过（梯度正确性验证）

**验证方式**:
- 数值梯度 vs 符号梯度
- 误差 < 1e-3

---

### 5. 可观测性 (Observability)

**原则**: 所有计算必须可观测。从 Phase 0 开始就要有 Profiler。

**具体规则**:
- ✅ 每个 Kernel 必须计时
- ✅ 内存分配/释放必须追踪
- ✅ 必须能导出性能报告
- ❌ 不允许"黑盒执行"

**验证方式**:
- `make profile` 生成性能报告
- 对比 CPU/CUDA 性能差异

---

### 6. 测试覆盖 (Test Coverage)

**原则**: 每个新功能必须有完整的测试。

**具体规则**:
```
新增 Operator
    ↓
单元测试 (Functional)
    ↓
数值测试 (Numerical vs PyTorch)
    ↓
梯度检查 (Gradient Check)
    ↓
集成测试 (Integration)
    ↓
性能基准 (Benchmark)
```

- ❌ 不许跳过任何测试
- ✅ 所有测试必须自动化

**验证方式**:
- `make test` 全部通过
- Coverage report

---

### 7. 版本控制与恢复 (Checkpoint & Resume)

**原则**: 训练必须可中断、可恢复。

**具体规则**:
- ❌ 恢复后 Loss 不连续 = 严重 Bug
- ✅ Checkpoint 必须包含：模型参数、Optimizer 状态、训练步数
- ✅ Resume 必须通过一致性验证
- ✅ 支持多次 Resume（Resume 的 Resume）

**验证方式**:
- Loss 曲线连续
- 步长后的梯度相同

---

### 8. 最小化 API 表面 (Minimal API Surface)

**原则**: 初期不要设计过多的 API 和选项。

**具体规则**:
- ❌ Phase 1-3 不允许有超过 50 个公开 API
- ✅ API 必须能覆盖 80% 的使用场景
- ✅ 高级特性放到后期

**验证方式**:
- API 列表审查

---

### 9. 新增 Device 隔离 (New Device Isolation)

**原则**: 新增硬件不应该修改现有代码。

**具体规则**:
- ✅ 新增 Device：只修改 `runtime/device/` 和 `runtime/kernel/`
- ✅ 注册到 Dispatcher，完成
- ❌ 不修改任何 Operator
- ❌ 不修改任何 Model 代码

**验证方式**:
- diff 统计：新增代码行数
- 不应该修改现有 Operator

---

### 10. 演进而非重写 (Evolution, Not Rewrite)

**原则**: 每个阶段都是上一阶段的完善，而不是推倒重来。

**具体规则**:
- ❌ 不允许大规模重构（> 1000 行改动）
- ✅ 小步迭代，保持向后兼容
- ✅ 如果需要大改，说明架构有问题

**验证方式**:
- 代码审查：大改动审批流程

---

## 跨层通信 (Cross-Layer Communication)

### 允许的通信方式

```
Model
    ↓ call
Operator (设备无关)
    ↓ call
Dispatcher.select_kernel(op_name, device)
    ↓ return
Kernel (设备相关)
    ↓ call
Device.allocate() / Device.deallocate()
    ↓
Memory
```

### 禁止的通信方式

```
❌ Model → Device
❌ Model → Kernel  
❌ Operator → Device
❌ Operator → CUDA API directly
❌ Kernel → Model
❌ Device → Model
```

---

## 验证清单 (Checklist)

新增代码时：

- [ ] 遵守分层原则？
- [ ] 设备无关？
- [ ] 有 Reference Test？
- [ ] 支持梯度？
- [ ] 有性能基准？
- [ ] 新增 Device 不修改现有代码？
- [ ] 代码行数 < 1000？
- [ ] 所有测试通过？
- [ ] 文档完整？

---

## 何时修改原则？

可以的情况：
- [ ] 经过 Code Review 讨论
- [ ] 有具体理由（性能、可维护性）
- [ ] 团队达成共识
- [ ] 更新 Git 提交说明

不允许的情况：
- ❌ 为了快速完成功能
- ❌ 没有讨论
- ❌ 单方面改动

---

**最后的话**:

这些原则看起来很严格，但它们是 NeurX 能成为"世界级框架"而不是"研究项目"的关键。

短期：这些原则会减缓开发速度（需要写 Reference Test、Gradient Check）  
长期：这些原则会大幅提升代码质量、可维护性、可扩展性

值得。
