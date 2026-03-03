# 张量创建函数使用指南

本文档展示如何使用新实现的张量创建函数。

## 基础创建函数

### 1. zeros - 创建全零张量

```python
import tensor

# 创建 2x3 的全零张量
t1 = tensor.zeros(2, 3)
# 或使用元组
t2 = tensor.zeros((2, 3))

# 指定数据类型
t3 = tensor.zeros(3, 4, dtype=np.int32)

# 在 GPU 上创建
t4 = tensor.zeros(2, 3, device='cuda')

# 启用梯度跟踪
t5 = tensor.zeros(2, 3, requires_grad=True)
```

### 2. ones - 创建全一张量

```python
# 创建 2x3 的全一张量
t = tensor.ones(2, 3)

# 所有参数与 zeros 相同
t = tensor.ones((3, 4), dtype=np.float32, device='cpu')
```

### 3. full - 创建填充特定值的张量

```python
# 创建 2x3 张量，填充值为 7.5
t = tensor.full((2, 3), 7.5)

# 填充整数
t = tensor.full((2, 3), 42, dtype=np.int32)
```

### 4. empty - 创建未初始化张量

```python
# 创建未初始化的张量（速度快，但值不确定）
t = tensor.empty(2, 3)
```

## 随机数创建函数

### 5. rand - 均匀分布 [0, 1)

```python
# 创建 2x3 张量，值在 [0, 1) 之间
t = tensor.rand(2, 3)

# 多维张量
t = tensor.rand(2, 3, 4)
```

### 6. randn - 标准正态分布

```python
# 创建标准正态分布的随机张量
t = tensor.randn(2, 3)

# 用于权重初始化
weights = tensor.randn(128, 64, requires_grad=True)
```

### 7. randint - 随机整数

```python
# 创建 [0, 10) 范围的随机整数
t = tensor.randint(0, 10, (2, 3))

# 用于生成标签
labels = tensor.randint(0, 10, (100,))  # 100个类别标签
```

## 序列创建函数

### 8. arange - 等差序列

```python
# 创建 [0, 1, 2, ..., 9]
t1 = tensor.arange(10)

# 指定起始和结束
t2 = tensor.arange(2, 10)  # [2, 3, 4, ..., 9]

# 指定步长
t3 = tensor.arange(2, 10, 2)  # [2, 4, 6, 8]

# 浮点数
t4 = tensor.arange(0, 1, 0.1)  # [0.0, 0.1, 0.2, ..., 0.9]
```

### 9. linspace - 线性间隔

```python
# 创建 5 个均匀分布在 [0, 1] 的值
t = tensor.linspace(0, 1, 5)  # [0.0, 0.25, 0.5, 0.75, 1.0]

# 用于生成坐标网格
x = tensor.linspace(-1, 1, 100)
```

### 10. logspace - 对数间隔

```python
# 创建 10^0 到 10^3 之间的 4 个值
t = tensor.logspace(0, 3, 4)  # [1, 10, 100, 1000]
```

## 特殊矩阵

### 11. eye - 单位矩阵

```python
# 创建 3x3 单位矩阵
I = tensor.eye(3)
# [[1, 0, 0],
#  [0, 1, 0],
#  [0, 0, 1]]

# 非方阵
t = tensor.eye(3, 4)
```

### 12. diag - 对角矩阵

```python
# 从向量创建对角矩阵
t = tensor.diag([1, 2, 3])
# [[1, 0, 0],
#  [0, 2, 0],
#  [0, 0, 3]]

# 提取矩阵的对角线
mat = tensor.ones(3, 3)
diag_values = tensor.diag(mat)
```

## _like 函数 - 匹配形状

### 13. zeros_like, ones_like, etc.

```python
x = tensor.rand(2, 3)

# 创建与 x 相同形状的张量
t1 = tensor.zeros_like(x)
t2 = tensor.ones_like(x)
t3 = tensor.full_like(x, 7.5)
t4 = tensor.rand_like(x)
t5 = tensor.randn_like(x)
```

## 实用示例

### 示例 1: 初始化神经网络权重

```python
import tensor
import tensor.nn as nn

# 使用 randn 初始化权重
input_size = 784
hidden_size = 128
output_size = 10

W1 = tensor.randn(input_size, hidden_size, requires_grad=True) * 0.01
b1 = tensor.zeros(hidden_size, requires_grad=True)

W2 = tensor.randn(hidden_size, output_size, requires_grad=True) * 0.01
b2 = tensor.zeros(output_size, requires_grad=True)
```

### 示例 2: 创建批量数据

```python
# 创建小批量输入
batch_size = 32
seq_len = 50
vocab_size = 10000

# 随机输入序列（词索引）
inputs = tensor.randint(0, vocab_size, (batch_size, seq_len))

# 对应的目标
targets = tensor.randint(0, vocab_size, (batch_size, seq_len))
```

### 示例 3: 掩码（Mask）操作

```python
# 创建注意力掩码
seq_len = 10
mask = tensor.ones(seq_len, seq_len)

# 创建对角掩码
for i in range(seq_len):
    mask[i, i+1:] = 0
```

### 示例 4: 位置编码

```python
# 创建位置编码矩阵
max_len = 100
d_model = 512

position = tensor.arange(0, max_len).unsqueeze(1)
div_term = tensor.exp(tensor.arange(0, d_model, 2) * 
                      -(np.log(10000.0) / d_model))

# 使用 sin 和 cos
pe = tensor.zeros(max_len, d_model)
# pe[:, 0::2] = tensor.sin(position * div_term)
# pe[:, 1::2] = tensor.cos(position * div_term)
```

### 示例 5: 数据增强

```python
# 添加随机噪声
def add_noise(image, noise_factor=0.1):
    noise = tensor.randn_like(image) * noise_factor
    return image + noise

# 原始图像
image = tensor.rand(3, 224, 224)  # RGB 图像
noisy_image = add_noise(image)
```

## 与 PyTorch 的兼容性

这些函数的设计与 PyTorch 保持一致：

```python
# PyTorch 风格
import torch
x = torch.zeros(2, 3)
y = torch.randn(2, 3, requires_grad=True)

# Tensor 框架 - 完全兼容！
import tensor
x = tensor.zeros(2, 3)
y = tensor.randn(2, 3, requires_grad=True)
```

## 性能提示

1. **使用 `empty` 而不是 `zeros`**: 如果你马上会填充值，使用 `empty` 更快
2. **指定 dtype**: 明确指定数据类型可以避免不必要的转换
3. **GPU 创建**: 直接在 GPU 上创建张量比先在 CPU 创建再转移更快

```python
# 慢
x = tensor.randn(1000, 1000).cuda()

# 快
x = tensor.randn(1000, 1000, device='cuda')
```

---

## 完整 API 列表

| 函数 | 用途 | 示例 |
|------|------|------|
| `zeros()` | 全零张量 | `tensor.zeros(2, 3)` |
| `ones()` | 全一张量 | `tensor.ones(2, 3)` |
| `full()` | 填充指定值 | `tensor.full((2, 3), 7.5)` |
| `empty()` | 未初始化张量 | `tensor.empty(2, 3)` |
| `rand()` | 均匀分布 [0,1) | `tensor.rand(2, 3)` |
| `randn()` | 标准正态分布 | `tensor.randn(2, 3)` |
| `randint()` | 随机整数 | `tensor.randint(0, 10, (2, 3))` |
| `arange()` | 等差序列 | `tensor.arange(0, 10, 2)` |
| `linspace()` | 线性间隔 | `tensor.linspace(0, 1, 5)` |
| `logspace()` | 对数间隔 | `tensor.logspace(0, 3, 4)` |
| `eye()` | 单位矩阵 | `tensor.eye(3)` |
| `diag()` | 对角矩阵 | `tensor.diag([1,2,3])` |
| `zeros_like()` | 同形状全零 | `tensor.zeros_like(x)` |
| `ones_like()` | 同形状全一 | `tensor.ones_like(x)` |
| `full_like()` | 同形状填充 | `tensor.full_like(x, 7.5)` |
| `rand_like()` | 同形状随机 | `tensor.rand_like(x)` |
| `randn_like()` | 同形状正态 | `tensor.randn_like(x)` |

---

**更新日期**: 2026年3月3日
