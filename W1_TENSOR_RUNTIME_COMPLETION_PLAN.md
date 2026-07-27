# W1 Tensor Runtime - 完成计划

**状态**: Framework 50%, Implementation 40%, Validation 0%  
**目标**: Framework 100%, Implementation 100%, Validation 100%  
**预计时间**: 2-3 天  
**关键路径**: W1 阻塞所有 W2-W11

---

## 📋 完成检查清单

### 1️⃣ Framework Completion (50% → 100%)

**已完成** ✅
- `tensor_s` 主结构体设计
- `tensor_metadata_s` 元数据结构
- 基础 API 函数签名

**需完成** 🔴
- [ ] 完整的内存布局文档 (行主 vs 列主)
- [ ] 张量广播规则文档
- [ ] 数据类型转换接口
- [ ] 设备抽象接口 (CPU/CUDA/NPU)
- [ ] 张量池化/缓存接口
- [ ] 异常处理框架

**工作量**: 2 小时

---

### 2️⃣ Implementation Completion (40% → 100%)

**已完成** ✅
- `new_tensor_s()` - 张量创建
- `compute_strides_s()` - stride 计算
- `tensor_reshape_s()` - reshape 变形
- `tensor_transpose_2d_s()` - 2D 转置
- `tensor_slice_s()` - 切片
- `tensor_cat_s()` - 拼接
- `tensor_to_string_s()` - 调试输出

**需完成** 🔴
- [ ] `tensor_transpose_nd_s()` - N维转置
- [ ] `tensor_permute_s()` - 任意排列
- [ ] `tensor_expand_s()` - 广播扩展
- [ ] `tensor_sum_s()` - 按轴求和
- [ ] `tensor_mean_s()` - 均值计算
- [ ] `tensor_var_s()` - 方差计算
- [ ] `tensor_softmax_s()` - softmax
- [ ] `tensor_copy_s()` - 深拷贝
- [ ] `tensor_fill_s()` - 填充初始化
- [ ] `tensor_clone_s()` - 克隆
- [ ] `tensor_memcpy_s()` - 内存复制 (for GPU)
- [ ] `tensor_synchronize_s()` - 同步操作
- [ ] 错误检查增强 (shape 验证、边界检查)
- [ ] 内存泄漏防护

**工作量**: 12 小时

---

### 3️⃣ Validation Completion (0% → 100%)

**已创建** ✅
- `tensor_runtime_test.s` - 80+ 个单元测试框架

**需完成** 🔴

#### 3.1 编译和运行测试
- [ ] 修复编译器架构不匹配 (ARM aarch64 ↔ x86_64)
  - 选项 A: 重新下载 x86_64 编译器
  - 选项 B: 使用容器/QEMU
- [ ] 编译 `tensor_runtime_test.s` 
- [ ] 运行完整测试套件
- [ ] 检查所有 80+ 测试通过

#### 3.2 数值精度验证
- [ ] 对比 Python NumPy 实现
- [ ] 验证 stride 计算正确性
- [ ] 验证 reshape 不改变数据
- [ ] 验证 transpose 正交性
- [ ] 限差: RMSError < 1e-5

#### 3.3 覆盖新实现的测试
- [ ] `tensor_transpose_nd_s()` - 10 个测试
- [ ] `tensor_expand_s()` - 8 个测试
- [ ] `tensor_sum_s()` - 6 个测试
- [ ] `tensor_softmax_s()` - 4 个测试
- [ ] 边界情况 - 10 个测试
- [ ] 性能测试 - 5 个测试

#### 3.4 Golden Tests (与 Python 对标)
- [ ] 创建 `tensor_golden_tests.s`
- [ ] 每个操作都有 Python 基准
- [ ] 逐元素对比结果
- [ ] 梯度检查 (数值 vs 解析)

**工作量**: 16 小时

---

## 📊 详细任务分解

### 任务 1: 修复编译器 (1 小时)

**选项 A: 重新下载 x86_64 编译器**
```bash
# 在用户的系统上运行
uname -m  # 验证 x86_64
# 从官方源下载 x86_64 版本
```

**选项 B: 使用容器/仿真**
```bash
# 或使用 QEMU ARM 支持
sudo apt install qemu-user-static
```

**验证**: `file /home/shuwen/.local/bin/s | grep x86_64`

---

### 任务 2: 强化核心实现 (8 小时)

#### 2.1 `tensor_transpose_nd_s()` - N维转置 (2h)
```
现状: tensor_transpose_2d_s() 仅支持2D
目标: tensor_transpose_s(tensor, []int axes) 支持任意维度

实现步骤:
1. 验证 axes 排列有效性 (无重复，范围有效)
2. 计算新 shape 和 strides
3. 递归/循环处理每一维
4. 验证转置后 total_elements 不变
```

#### 2.2 `tensor_expand_s()` - 广播扩展 (1.5h)
```
目的: 支持广播操作 (e.g., shape [3] → [2, 3])

实现步骤:
1. 检查目标 shape 是否与源兼容
2. 添加维度或扩展维度
3. 调整 strides 支持 0-stride (广播维度)
```

#### 2.3 `tensor_sum_s()` - 按轴求和 (1.5h)
```
目的: 归约操作支持

实现:
1. 接收 axis 参数 (或全局求和)
2. 遍历数据，按 axis 累加
3. 返回新 shape (该维度 = 1)
```

#### 2.4 错误检查增强 (1.5h)
```
- 所有操作前验证 shape 合法性
- 所有索引访问前边界检查
- 清晰的错误消息
- 日志输出模式
```

#### 2.5 边界情况处理 (1h)
```
- 空张量 (total_elements = 0)
- 单元素张量
- 超大张量 (> 1M elements)
- dtype/device 属性验证
```

---

### 任务 3: 完整单元测试 (6 小时)

#### 3.1 编译并运行现有 80 个测试 (1h)
```bash
s compile posttrain/core/tensor_runtime_test.s -o /tmp/tensor_test
./tmp/tensor_test
# 预期: 60+ 个测试通过，0 个失败
```

#### 3.2 增加新实现的测试 (3h)
```
对每个新函数:
- 正常情况 (3-4 个测试)
- 边界情况 (2-3 个测试)
- 错误情况 (1-2 个测试)

总计: +43 个新测试 → 合计 120+ 测试
```

#### 3.3 性能测试 (1h)
```
基准 (mini-batch 10):
✓ reshape: < 1ms
✓ transpose: < 2ms
✓ cat: < 1ms
✓ sum: < 3ms
```

#### 3.4 Golden Tests (1h)
```
创建 Python 参考:
```python
import numpy as np

# 对每个 S 操作有 NumPy 对应
shape = (2, 3, 4)
data = np.random.randn(*shape)

# reshape
result_py = data.reshape((6, 4))
# 对比 S 实现结果
```

---

## 🔧 W1 完成后的依赖解锁

```
W1 ✅ Tensor Runtime
  ├─→ W2: Tokenizer (使用 tensor 表示 token_ids)
  ├─→ W3: Embedding (tensor 输入输出)
  ├─→ W4: RoPE (使用 tensor 操作)
  ├─→ W5: Attention (tensor 矩阵乘法)
  ├─→ W6: Transformer (tensor 组合)
  ├─→ W7: Loss (tensor 输入)
  ├─→ W8: Autograd (tensor 梯度)
  ├─→ W9: Optimizer (tensor 更新)
  ├─→ W10: Checkpoint (tensor 保存)
  └─→ W11: Evaluation (tensor 指标)
```

**关键**: W1 是唯一不被任何东西阻塞的，W2-W11 全部依赖 W1

---

## 📝 提交计划

**提交 1**: 编译器修复 + tensor_runtime_test.s
```
Commit: W1 Testing Framework - 80+ Unit Tests

- Add tensor_runtime_test.s with comprehensive test suite
- Cover: Creation, Strides, Reshape, Transpose, Slice, Concatenation
- Test categories: normal, boundary, error cases
- Ready for validation once compiler issue resolved
```

**提交 2**: 核心实现增强
```
Commit: W1 Implementation Enhancement - N-D Operations

- Add tensor_transpose_nd_s() for arbitrary dimension permutation
- Add tensor_expand_s() for broadcasting support
- Add tensor_sum_s() for reduction operations
- Enhance error checking and boundary validation
- Update tests to cover new functions
```

**提交 3**: 完整验证通过
```
Commit: W1 Complete - Framework 100% Implementation 100% Validation 100%

- All 120+ tests pass on x86_64 system
- Numerical precision verified vs NumPy baseline
- Performance meets <2ms reshape/transpose targets
- Golden tests confirm correctness for downstream W2-W11
```

---

## ⏱️ 时间表

| 任务 | 时间 | 优先级 |
|------|------|--------|
| 编译器修复 | 1h | 🔴 CRITICAL |
| 运行现有测试 | 1h | 🔴 CRITICAL |
| N-D transpose 实现 | 2h | 🟠 HIGH |
| Expand/Sum 实现 | 2h | 🟠 HIGH |
| 错误处理增强 | 1.5h | 🟠 HIGH |
| 新实现测试 | 3h | 🟠 HIGH |
| Golden 测试对标 | 2h | 🟡 MEDIUM |
| 性能优化 | 1h | 🟡 MEDIUM |
| **总计** | **~13.5h** | 可在 1 天内完成 |

---

## ✅ 完成验收标准

**Framework**: ✓
- [ ] 所有公开 API 文档完整
- [ ] 内存布局文档清晰
- [ ] 设备抽象接口定义

**Implementation**: ✓
- [ ] 所有 15+ 操作函数完整实现
- [ ] 无编译警告
- [ ] 代码风格一致

**Validation**: ✓
- [ ] 120+ 单元测试全部通过
- [ ] 数值精度 RMSError < 1e-5
- [ ] 性能基准达成
- [ ] Golden 测试与 NumPy 一致
- [ ] 边界情况全覆盖

**完成标志**: 
```
W1 Tensor Runtime: F100% I100% V100% ✅ → READY FOR W2
```

---

## 🔗 相关文件

- [原始 tensor_runtime.s](tensor_runtime.s) - 框架和初始实现
- [测试套件](tensor_runtime_test.s) - 80+ 个单元测试
- [Python 参考](../../../inference/reference_tensor_ops.py) - NumPy 对标

---

**下一步**: 1. 修复编译器架构问题 2. 运行现有测试 3. 按上述计划完成 W1

