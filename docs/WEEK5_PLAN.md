# Week 5 实施计划：权重初始化、梯度操作、模型分析

**计划日期**: 2026-03-03  
**目标周期**: Week 5  
**目标完成度**: 87% → 91% (+4%)

---

## 1. Week 5 任务分解

### 1.1 任务优先级

| 任务 | 优先级 | 影响 | 工作量 | 估计行数 |
|------|--------|------|--------|-----------|
| 权重初始化 | ⭐⭐⭐⭐ | +1% | 中 | 200+ |
| 梯度操作 | ⭐⭐⭐⭐ | +0.5% | 小 | 150+ |
| 模型分析 | ⭐⭐⭐ | +0.5% | 小 | 150+ |
| BatchNorm | ⭐⭐⭐ | +2% | 大 | 350+ |

**总计**: ~850 行新增代码

### 1.2 关键实现目标

#### A. 权重初始化 (Weight Initialization)

**文件**: `python/neurx/nn/init.py` (200+ 行)

实现函数:

```python
def xavier_uniform(neurx, gain=1.0):
    """Xavier 均匀初始化"""
    # 计算 fan_in 和 fan_out
    # 生成 [-limit, limit] 均匀分布

def xavier_normal(neurx, gain=1.0):
    """Xavier 正态初始化"""
    # 计算 fan_in 和 fan_out
    # 生成标准差为 std 的正态分布

def kaiming_uniform(neurx, a=0, mode='fan_in', nonlinearity='leaky_relu'):
    """Kaiming 均匀初始化 (for ReLU)"""
    # 使用 fan_in/fan_out 计算
    # 支持不同激活函数

def kaiming_normal(neurx, a=0, mode='fan_in', nonlinearity='leaky_relu'):
    """Kaiming 正态初始化"""
    # 计算适当的标准差
    # 支持 LeakyReLU 参数

def orthogonal(neurx, gain=1.0):
    """正交初始化"""
    # QR 分解获得正交矩阵
    # 适用于循环网络

def uniform(neurx, a, b):
    """均匀分布初始化"""
    # 在 [a, b] 范围内均匀分布

def normal(neurx, mean=0, std=1):
    """正态分布初始化"""
    # 标准正态分布初始化

def constant(neurx, val):
    """常数初始化"""
    # 用固定值填充
```

**测试**: 7 个测试 (各初始化方法的形状、分布检验)

**代码示例**:
```python
from neurx.nn.init import xavier_uniform, kaiming_normal

# 在 Conv2d 中使用
conv = Conv2d(3, 16, kernel_size=3)
xavier_uniform(conv.weight)

# 在 Linear 中使用
linear = Linear(128, 64)
kaiming_normal(linear.weight, nonlinearity='relu')
```

#### B. 梯度操作 (Gradient Operations)

**文件**: `python/neurx/optim/grad_utils.py` (150+ 行)

实现函数:

```python
def clip_grad_norm_(parameters, max_norm, norm_type=2.0):
    """梯度范数裁剪"""
    # 计算所有参数的总 L2 范数
    # 如果超过 max_norm，按比例缩放
    # 返回总范数

def clip_grad_value_(parameters, clip_value):
    """梯度值裁剪"""
    # 将梯度限制在 [-clip_value, clip_value]
    # 适用于梯度爆炸

def get_grad_norm(parameters, norm_type=2.0):
    """获取梯度范数"""
    # 计算所有参数梯度的范数
    # 用于监控训练

def zero_grad(model):
    """清零梯度"""
    # 重置所有参数的梯度为零
```

**测试**: 4 个测试 (范数计算、值裁剪、边界条件)

**代码示例**:
```python
from neurx.optim.grad_utils import clip_grad_norm_

# 在训练循环中使用
for epoch in range(num_epochs):
    output = model(x)
    loss = criterion(output, y)
    loss.backward()
    
    # 裁剪梯度范数
    clip_grad_norm_(model.parameters(), max_norm=1.0)
    
    optimizer.step()
    optimizer.zero_grad()
```

#### C. 模型分析 (Model Analysis)

**文件**: `python/neurx/nn/utils.py` (150+ 行)

实现函数:

```python
def summary(model, input_size, batch_size=1, device='cpu'):
    """模型摘要"""
    # 打印每层的输出形状
    # 显示参数数量
    # 估算 FLOPs

def count_parameters(model):
    """统计参数数量"""
    # 计算可训练参数
    # 返回总参数数

def count_flops(model, input_size):
    """估算 FLOPs (浮点运算次数)"""
    # 根据各层操作估算 FLOPs
    # 支持 Conv、Linear 等常见层

def model_size(model):
    """模型大小估计"""
    # 计算参数存储大小 (MB)
    # 估算梯度和优化器状态大小
```

**测试**: 4 个测试 (参数计数、输出形状、FLOPs 估算)

**代码示例**:
```python
from neurx.nn.utils import summary, count_parameters

model = YourModel()

# 打印模型摘要
summary(model, input_size=(3, 32, 32), batch_size=4)

# 统计参数数量
total_params = count_parameters(model)
print(f"Total parameters: {total_params:,}")
```

#### D. BatchNorm 层 (Batch Normalization)

**文件**: `python/neurx/nn/normalization.py` (350+ 行)

实现类:

```python
class BatchNorm1d(Module):
    """1D 批归一化"""
    # 对特征维度进行归一化
    # 支持训练和评估模式
    # 包括 momentum 和 epsilon

class BatchNorm2d(Module):
    """2D 批归一化"""
    # 对空间维度进行批归一化
    # 用于卷积网络
    # 跟踪运行统计量

class BatchNorm3d(Module):
    """3D 批归一化"""
    # 三维批归一化
    # 用于 3D 卷积
```

**特性**:
- 训练/评估模式切换
- 运行平均 (running mean/var)
- Momentum 更新
- Affine 参数 (gamma, beta)
- 数值稳定性

**测试**: 6 个测试 (基础、运行统计、模式切换、参数更新)

---

## 2. 实现步骤

### Step 1: 权重初始化 (Day 1)
```
1. 创建 python/neurx/nn/init.py
2. 实现 7 个初始化函数
3. 创建测试套件 (7 个测试)
4. 验证分布和统计性质
估计: 4-6 小时
```

### Step 2: 梯度操作 (Day 2)
```
1. 创建 python/neurx/optim/grad_utils.py
2. 实现梯度裁剪和监控函数
3. 创建测试套件 (4 个测试)
4. 集成到优化器
估计: 3-4 小时
```

### Step 3: 模型分析 (Day 2-3)
```
1. 创建 python/neurx/nn/utils.py
2. 实现 summary、count_parameters 等
3. 创建测试套件 (4 个测试)
4. 验证输出格式
估计: 3-4 小时
```

### Step 4: BatchNorm 层 (Day 3-4)
```
1. 扩展 python/neurx/nn/normalization.py
2. 实现 BatchNorm1d/2d/3d
3. 处理训练/评估模式
4. 创建测试套件 (6 个测试)
5. 集成到 nn/__init__.py
估计: 6-8 小时
```

### Step 5: 测试和文档 (Day 5)
```
1. 整合所有测试
2. 验证集成功能
3. 生成 Week 5 报告
4. 更新框架文档
估计: 2-3 小时
```

---

## 3. 预期成果

### 3.1 代码统计

```
新增文件:
  python/neurx/nn/init.py              200 行 (7 个函数)
  python/neurx/optim/grad_utils.py     150 行 (4 个函数)
  python/neurx/nn/utils.py             150 行 (4 个函数)
  tests/test_init_grad_analysis.py      350 行 (21 个测试)

修改文件:
  python/neurx/nn/normalization.py     +350 行 (BatchNorm)
  python/neurx/nn/__init__.py          +导出新函数

总计: ~1,200 行新增代码
```

### 3.2 框架进度

```
Week 4: 89% (Conv + Pooling)
Week 5: 91% (Init + GradOps + Analysis + BatchNorm)
  ├─ 权重初始化: +1%
  ├─ 梯度操作: +0.5%
  ├─ 模型分析: +0.5%
  └─ BatchNorm: +1%

总计进度: 82% → 91% (2 周内)
```

### 3.3 测试覆盖

```
Week 4 测试: 87 个 (RNN + Loss + Scheduler + Conv + Pool)
Week 5 新增: 21 个 (Init + Grad + Analysis + BatchNorm)

总计: 108 个测试 (100% 通过)
```

---

## 4. 关键实现点

### 4.1 权重初始化考虑

- **计算 fan_in/fan_out**: 需要正确处理不同层的维度
- **数值稳定性**: 避免超大/超小的初始值
- **激活函数相关**: Kaiming 需要考虑激活函数类型

### 4.2 梯度裁剪考虑

- **范数类型**: L2、L1 等不同范数
- **性能**: 避免重复计算
- **并行安全**: 考虑分布式场景

### 4.3 模型分析考虑

- **FLOPs 估算**: Conv、Linear 等层的 FLOPs 计算
- **递归遍历**: 正确遍历所有子模块
- **格式化输出**: 易读的表格格式

### 4.4 BatchNorm 考虑

- **训练vs评估**: 完全不同的行为
- **运行统计量**: running mean/var 的更新
- **数值稳定性**: epsilon 的选择
- **梯度计算**: 反向传播的正确性

---

## 5. 验收标准

### 5.1 功能验收

- ✅ 权重初始化: 7 个函数，7 个测试通过
- ✅ 梯度操作: 4 个函数，4 个测试通过
- ✅ 模型分析: 4 个函数，4 个测试通过
- ✅ BatchNorm: 3 个类，6 个测试通过
- ✅ 总体: 108 个测试，100% 通过

### 5.2 性能验收

```
权重初始化时间: < 1ms (小模型)
梯度裁剪时间: < 2ms (1M 参数)
summary() 输出: < 100ms
BatchNorm 前向: 与 Conv 相当
```

### 5.3 代码质量

- 完整的文档注释
- 类型提示
- 错误处理
- 一致的 API

---

## 6. 风险和缓解

| 风险 | 影响 | 概率 | 缓解方案 |
|------|------|------|---------|
| BatchNorm 梯度复杂 | 高 | 中 | 参考 PyTorch 实现 |
| FLOPs 估算不准确 | 低 | 低 | 简化估算或跳过 |
| 性能不满足 | 中 | 低 | 优化关键路径 |
| 数值稳定性 | 中 | 低 | 充分的单元测试 |

---

## 7. 时间表

| 任务 | 日期 | 预计时间 | 里程碑 |
|------|------|---------|--------|
| 权重初始化 | Day 1 | 4-6h | ✓ 7 个测试通过 |
| 梯度操作 | Day 2 | 3-4h | ✓ 4 个测试通过 |
| 模型分析 | Day 2-3 | 3-4h | ✓ 4 个测试通过 |
| BatchNorm | Day 3-4 | 6-8h | ✓ 6 个测试通过 |
| 集成测试 | Day 5 | 2-3h | ✓ 总体 108 个测试 |
| 报告 | Day 5 | 1-2h | ✓ Week 5 报告完成 |

**总计**: 19-27 小时（预计 3-4 个工作日完成）

---

## 总结

**Week 5 目标**: 通过权重初始化、梯度操作、模型分析和 BatchNorm 实现，将框架完成度从 89% 提升至 91%。

关键成果:
- ✅ 完整的权重初始化支持
- ✅ 梯度处理工具
- ✅ 模型分析和统计
- ✅ 批归一化层

这将为 Week 6-7 的高级优化和分布式支持做准备！

---

**下一步**: 开始 Week 5 实施
