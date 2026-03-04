# PyTorch vs Tensor Library - 功能对比分析

## 📋 对比总结

本文档对比了当前tensor库的`nn.Module`实现与PyTorch的功能，并列出了新增的功能。

---

## ✅ 已实现的功能

### 核心Module系统
| 功能 | PyTorch | Tensor库 | 状态 |
|------|---------|---------|------|
| `parameters()` | ✓ | ✓ | ✓ |
| `named_parameters()` | ✓ | ✓ | ✓ |
| `buffers()` / `named_buffers()` | ✓ | ✓ | ✓ |
| `children()` / `named_children()` | ✓ | ✓ | ✓ |
| `modules()` / `named_modules()` | ✓ | ✓ | ✓ |
| `train()` / `eval()` | ✓ | ✓ | ✓ |
| `zero_grad()` | ✓ | ✓ | ✓ |
| `state_dict()` / `load_state_dict()` | ✓ | ✓ | ✓ |
| `register_buffer()` | ✓ | ✓ | ✓ |

### 基础层
| 层 | PyTorch | Tensor库 | 状态 |
|----|---------|---------|------|
| `Linear` | ✓ | ✓ | ✓ |
| `Conv2d` | ✓ | ✓ | ✓ |
| `Embedding` | ✓ | ✓ | ✓ |
| `BatchNorm1d` | ✓ | - | ⭐ 新增 |
| `BatchNorm2d` | ✓ | - | ⭐ 新增 |

### 归一化层
| 层 | PyTorch | Tensor库 | 状态 |
|----|---------|---------|------|
| `LayerNorm` | ✓ | ✓ | ✓ |
| `RMSNorm` | - | ✓ | 独有 |
| `Dropout` | ✓ | ✓ | ✓ |

### 激活函数
| 激活 | PyTorch | Tensor库 | 状态 |
|-----|---------|---------|------|
| `GELU` | ✓ | ✓ | ✓ |
| `Sigmoid` | ✓ | ✓ | ✓ |
| `SiLU/Swish` | ✓ | ✓ | ✓ |

### 池化层
| 层 | PyTorch | Tensor库 | 状态 |
|----|---------|---------|------|
| `MaxPool2d` | ✓ | - | ⭐ 新增 |
| `AvgPool2d` | ✓ | - | ⭐ 新增 |

### 容器模块
| 容器 | PyTorch | Tensor库 | 状态 |
|-----|---------|---------|------|
| `Sequential` | ✓ | - | ⭐ 新增 |
| `ModuleList` | ✓ | ✓ | ✓ |
| `ModuleDict` | ✓ | ✓ | ✓ |

### 注意力机制
| 模块 | PyTorch | Tensor库 | 状态 |
|-----|---------|---------|------|
| `MultiHeadAttention` | - | ✓ | 独有 |
| RoPE支持 | - | ✓ | 独有 |
| KV缓存 | - | ✓ | 独有 |

### 高级模块
| 模块 | PyTorch | Tensor库 | 状态 |
|-----|---------|---------|------|
| `MLP` | - | ✓ | 独有 |
| `MoE` (Mixture of Experts) | - | ✓ | 独有 |
| `TransformerBlock` | - | ✓ | 独有 |

### 权重初始化函数
| 初始化 | PyTorch | Tensor库 | 状态 |
|------|---------|---------|------|
| `kaiming_uniform_()` | ✓ | - | ⭐ 新增 |
| `kaiming_normal_()` | ✓ | - | ⭐ 新增 |
| `xavier_uniform_()` | ✓ | - | ⭐ 新增 |
| `xavier_normal_()` | ✓ | - | ⭐ 新增 |

### Module工具方法
| 方法 | PyTorch | Tensor库 | 状态 |
|-----|---------|---------|------|
| `requires_grad_(bool)` | ✓ | - | ⭐ 新增 |
| `to(device)` | ✓ | - | ⭐ 新增 |
| `cpu()` | ✓ | - | ⭐ 新增 |
| `cuda()` | ✓ | - | ⭐ 新增 |
| `float()` | ✓ | - | ⭐ 新增 |
| `double()` | ✓ | - | ⭐ 新增 |

---

## ⭐ 新增功能详解

### 1. BatchNorm1d 和 BatchNorm2d

批量归一化层，用于训练稳定性和收敛速度：

```python
from neurx.nn.modules import BatchNorm1d, BatchNorm2d

# 1D批量归一化
bn1d = BatchNorm1d(num_features=64)
x = Tensor(np.random.randn(32, 64))  # (batch, features)
y = bn1d(x)

# 2D批量归一化
bn2d = BatchNorm2d(num_features=64)
x = Tensor(np.random.randn(2, 64, 32, 32))  # (batch, channels, H, W)
y = bn2d(x)
```

**特性：**
- ✓ 训练/评估模式自动切换
- ✓ 运行统计跟踪 (running_mean, running_var)
- ✓ 动量衰减 (momentum)
- ✓ 可选的仿射参数 (weight, bias)
- ✓ 完整的反向传播支持

---

### 2. MaxPool2d 和 AvgPool2d

池化层，用于降维和特征提取：

```python
from neurx.nn.modules import MaxPool2d, AvgPool2d

# 最大值池化
maxpool = MaxPool2d(kernel_size=2, stride=2, padding=0)
x = Tensor(np.random.randn(2, 64, 32, 32))
y = maxpool(x)  # shape: (2, 64, 16, 16)

# 平均值池化
avgpool = AvgPool2d(kernel_size=2, stride=2, padding=0)
y = avgpool(x)  # shape: (2, 64, 16, 16)
```

**特性：**
- ✓ 支持自定义kernel_size, stride, padding
- ✓ MaxPool正确跟踪最大值位置
- ✓ 完整的梯度计算
- ✓ 支持非正方形kernel

---

### 3. Sequential 容器

用于构建顺序网络的容器：

```python
from neurx.nn.modules import Sequential, Linear, GELU

# 构建MLP
model = Sequential(
    Linear(10, 64),
    GELU(),
    Linear(64, 32),
    GELU(),
    Linear(32, 5)
)

x = Tensor(np.random.randn(32, 10))
y = model(x)  # 逐层传播
```

**特性：**
- ✓ 支持按顺序应用多个模块
- ✓ 支持索引和切片访问
- ✓ 自动参数收集
- ✓ 完整的train/eval支持

---

### 4. 权重初始化函数

标准的神经网络初始化方法：

```python
from neurx.nn.modules import (
    kaiming_uniform_, kaiming_normal_,
    xavier_uniform_, xavier_normal_,
    Parameter
)

# Kaiming初始化（适合ReLU等）
w = Parameter(np.empty((64, 32)))
kaiming_normal_(w, mode='fan_in', nonlinearity='leaky_relu')

# Xavier初始化（适合Sigmoid/tanh）
w = Parameter(np.empty((64, 32)))
xavier_normal_(w)

# 支持扇入/扇出模式
kaiming_uniform_(w, mode='fan_out')
```

**特性：**
- ✓ 支持Kaiming和Xavier两种方案
- ✓ 支持均匀和正态分布
- ✓ 自动计算fan_in/fan_out
- ✓ 支持卷积层

---

### 5. Module工具方法

便利的模块操作方法：

```python
from neurx.nn.modules import Sequential, Linear

model = Sequential(Linear(10, 20), Linear(20, 5))

# 控制梯度
model.requires_grad_(False)  # 冻结所有参数
model.requires_grad_(True)   # 解冻所有参数

# 设备转移
model.to('cpu')
model.cuda()

# 数据类型转换
model.float()   # float32
model.double()  # float64
```

**特性：**
- ✓ `requires_grad_(bool)` - 批量设置梯度需求
- ✓ `to(device)` - 设备转移接口
- ✓ `cpu()` / `cuda()` - 快捷方法
- ✓ `float()` / `double()` - 精度转换

---

## 📊 功能矩阵对比

### PyTorch vs Tensor库

```
┌─────────────────────────────┬──────────┬─────────┬──────────┐
│ 功能类别                    │ PyTorch  │ Tensor  │ 新增功能 │
├─────────────────────────────┼──────────┼─────────┼──────────┤
│ Module系统                   │ ✓✓✓     │ ✓✓✓    │          │
│ 基础层（Linear, Conv）      │ ✓✓✓     │ ✓✓✓    │          │
│ 批量归一化                   │ ✓✓✓     │   -    │ ⭐⭐    │
│ 池化层                       │ ✓✓✓     │   -    │ ⭐⭐    │
│ 容器（Sequential）          │ ✓✓✓     │   -    │ ⭐⭐    │
│ 权重初始化                   │ ✓✓✓     │   -    │ ⭐⭐⭐  │
│ Module工具                   │ ✓✓✓     │   -    │ ⭐⭐    │
│ 注意力机制（带RoPE）        │   -     │ ✓✓✓    │          │
│ MoE支持                     │   -     │ ✓✓✓    │          │
│ Transformer Block           │   -     │ ✓✓✓    │          │
└─────────────────────────────┴──────────┴─────────┴──────────┘
```

---

## 🎯 下一步改进建议

### 高优先级
1. **Functional接口** - 添加`F.relu()`, `F.conv2d()`等
2. **Hooks机制** - 前向/反向钩子用于特征提取
3. **InstanceNorm** - 其他归一化变种
4. **AdaptivePool** - 自适应池化
5. **GroupNorm** - 组归一化（对Transformer有益）

### 中优先级
6. **更多初始化** - uniform, constant, normal等
7. **参数冻结** - freeze/unfreeze接口
8. **Module打印** - 更好的`__repr__`
9. **Clone/Deepcopy** - 模块复制
10. **Weight decay** - 内置权重衰减

### 低优先级
11. **异步执行** - 非阻塞前向传播
12. **图编译** - 计算图优化
13. **混合精度** - 自动混合精度
14. **Profiler** - 性能分析工具

---

## 📈 测试覆盖

所有新增功能都配有完整的单元测试：

```bash
python /home/shuwen/neurx/python/test_new_modules.py
```

测试覆盖：
- ✓ BatchNorm1d (训练/评估模式, 梯度计算)
- ✓ BatchNorm2d (2D张量处理, 梯度计算)
- ✓ MaxPool2d (输出形状, 梯度反向传播)
- ✓ AvgPool2d (平均计算, 梯度正确性)
- ✓ Sequential (模块组合, 参数收集)
- ✓ 权重初始化 (分布检验, 形状兼容)
- ✓ Module工具 (设备转移, 精度转换)
- ✓ 集成测试 (完整网络训练)

---

## 🔗 使用示例

### 完整的CNN模型

```python
from neurx.nn.modules import (
    Sequential, Conv2d, BatchNorm2d, MaxPool2d, 
    Linear, GELU, kaiming_normal_
)
from neurx.neurx import Tensor
import numpy as np

# 定义模型
model = Sequential(
    Conv2d(3, 32, kernel_size=3, padding=1),
    BatchNorm2d(32),
    GELU(),
    MaxPool2d(2, 2),
    
    Conv2d(32, 64, kernel_size=3, padding=1),
    BatchNorm2d(64),
    GELU(),
    MaxPool2d(2, 2),
    
    # 假设输入是32x32，经过两次2x2池化后变为8x8
    # 这里需要flatten，实际应该添加flatten层
)

# 初始化权重
for param in model.parameters():
    if len(param.data.shape) > 1:
        kaiming_normal_(param)

# 训练
model.train()
x = Tensor(np.random.randn(8, 3, 32, 32))
y = model(x)

# 评估
model.eval()
y = model(x)
```

---

## 📝 总结

通过新增**9个主要功能模块**和**3个工具方法集**，tensor库在以下方面显著增强：

| 方面 | 改进 |
|-----|-----|
| **标准化支持** | 从0 → BatchNorm1d/2d |
| **池化能力** | 从0 → MaxPool/AvgPool |
| **模型构建** | 从0 → Sequential容器 |
| **参数初始化** | 从0 → Kaiming/Xavier |
| **设备管理** | 从0 → to/cpu/cuda接口 |

现在tensor库包含了构建现代深度学习模型所需的大部分基础设施，可以与PyTorch进行功能上的直接对比。
