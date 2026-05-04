# NeurX Tensor 新功能使用指南

## 快速开始

### 1. 张量创建

```python
import neurx as nx

# 创建零张量
x = nx.zeros((3, 4))
x = nx.zeros(3, 4)  # 也可以这样

# 创建全1张量
y = nx.ones((2, 3))

# 创建指定值张量
z = nx.full((2, 3), 5.0)

# 创建随机张量
r1 = nx.rand(3, 4)          # Uniform [0, 1)
r2 = nx.randn(3, 4)         # Standard normal
r3 = nx.normal(0, 1, (3, 4))  # Normal with mean, std
r4 = nx.uniform(-1, 1, (3, 4))  # Uniform [a, b)

# 创建特殊张量
identity = nx.eye(3)        # 3x3 单位矩阵
range_t = nx.arange(10)     # [0, 1, 2, ..., 9]
range_t = nx.arange(2, 10, 2)  # [2, 4, 6, 8]
linspace = nx.linspace(0, 1, 5)  # [0, 0.25, 0.5, 0.75, 1]
logspace = nx.logspace(0, 2, 5)  # [1, 10, 100]（以10为底）

# 创建与现有张量形状相同的张量
a = nx.Tensor([1, 2, 3])
zeros_like_a = nx.zeros_like(a)
ones_like_a = nx.ones_like(a)
full_like_a = nx.full_like(a, 5.0)

# 随机排列
perm = nx.randperm(10)  # 0-9的随机排列
```

### 2. 高级索引操作

```python
import neurx as nx

x = nx.Tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]])

# 按索引选择
indices = nx.Tensor([0, 2])
selected = nx.index_select(x, dim=1, indices=indices)  # 选择第0和第2列

# 按掩码选择
mask = nx.Tensor([True, False, True])
masked = nx.masked_select(x[:, 0], mask)  # 选择满足条件的元素

# 按掩码填充
mask = nx.Tensor([True, False, True, False, True])
filled = nx.masked_fill(x[0], mask, 0)  # 掩码位置填充为0

# 条件选择
cond = nx.Tensor([[True, False], [False, True]])
result = nx.where(cond, x[:2, :2], 0)  # 条件为True取x，否则取0

# 获取非零元素的索引
indices = nx.nonzero(x)

# 连接张量
x1 = nx.Tensor([1, 2, 3])
x2 = nx.Tensor([4, 5, 6])
concatenated = nx.cat([x1, x2], dim=0)  # [1, 2, 3, 4, 5, 6]

# 分割张量
split_list = nx.split(concatenated, 2, dim=0)  # 分成2个张量

# 分块张量
chunks = nx.chunk(x, 3, dim=0)  # 分成3块

# 堆叠张量
stacked = nx.stack([x1, x2], dim=0)  # [[1,2,3], [4,5,6]]
```

### 3. 统计与排序

```python
import neurx as nx

x = nx.Tensor([3, 1, 4, 1, 5, 9, 2, 6])

# 排序
sorted_vals, sorted_indices = nx.sort(x)
sorted_vals, sorted_indices = nx.sort(x, descending=True)

# 排序索引
indices = nx.argsort(x)

# 前k大元素
top_vals, top_indices = nx.topk(x, k=3)
top_vals, top_indices = nx.topk(x, k=3, largest=False)  # 前3小

# 唯一值
unique_vals = nx.unique(x)
unique_vals, inverse = nx.unique(x, return_inverse=True)
unique_vals, counts = nx.unique(x, return_counts=True)

# 中位数
median_val = nx.median(x)
median_val, median_idx = nx.median(x, dim=0)

# 众数
mode_val, mode_idx = nx.mode(x)

# 分位数
q25 = nx.quantile(x, 0.25)
quartiles = nx.quantile(x, [0.25, 0.5, 0.75])

# 累积和/乘积
cumsum_x = nx.cumsum(x)
cumprod_x = nx.cumprod(x)

# 乘积
prod_x = nx.prod(x)
```

### 4. 线性代数

```python
import neurx as nx

A = nx.Tensor([[1.0, 2.0], [3.0, 4.0]])
B = nx.Tensor([[1.0, 0.0], [0.0, 1.0]])

# 矩阵求逆
A_inv = nx.linalg.inv(A)

# 行列式
det_A = nx.linalg.det(A)

# 矩阵秩
rank_A = nx.linalg.matrix_rank(A)

# 特征值分解
eigenvalues, eigenvectors = nx.linalg.eigh(A)  # 对称矩阵

# 奇异值分解
U, S, Vh = nx.linalg.svd(A)

# QR分解
Q, R = nx.linalg.qr(A)

# Cholesky分解（需要正定矩阵）
L = nx.linalg.cholesky(B)

# 求解线性系统
x = nx.linalg.solve(A, nx.Tensor([1.0, 2.0]))

# 最小二乘解
A_rect = nx.Tensor([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]])
b = nx.Tensor([1.0, 2.0, 3.0])
x_ls = nx.linalg.lstsq(A_rect, b)

# 向量叉积
u = nx.Tensor([1.0, 0.0, 0.0])
v = nx.Tensor([0.0, 1.0, 0.0])
cross_prod = nx.linalg.cross(u, v)  # [0, 0, 1]

# 向量内积
u = nx.Tensor([1.0, 2.0, 3.0])
v = nx.Tensor([4.0, 5.0, 6.0])
inner_prod = nx.linalg.inner(u, v)  # 32

# 外积
outer_prod = nx.linalg.outer(u, v)  # 3x3 矩阵

# 矩阵幂
A_squared = nx.linalg.matrix_power(A, 2)
```

### 5. 梯度计算

所有新功能都支持自动微分：

```python
import neurx as nx

# 启用梯度计算
x = nx.randn(3, requires_grad=True)
y = nx.randn(3, requires_grad=True)

# 前向传播
z = nx.sum(x * y)

# 反向传播
z.backward()

print(x.grad)  # 梯度信息
print(y.grad)

# 清除梯度
x.grad = nx.zeros_like(x)
y.grad = nx.zeros_like(y)
```

### 6. 数据类型控制

```python
import neurx as nx
import numpy as np

# 创建特定数据类型的张量
x_f32 = nx.zeros((3, 4), dtype=np.float32)
x_f64 = nx.zeros((3, 4), dtype=np.float64)
x_int = nx.randint(0, 10, (3, 4), dtype=np.int64)
```

### 7. 设备支持

```python
import neurx as nx

# CPU张量
x_cpu = nx.zeros((3, 4), device='cpu')

# CUDA张量（如果可用）
x_cuda = nx.zeros((3, 4), device='cuda')
```

### 8. 实际应用示例

#### 示例1：数据预处理

```python
import neurx as nx

# 创建数据
data = nx.randn(100, 10)

# 标准化
mean = nx.Tensor(data.mean())
std = nx.Tensor(data.std())
normalized = (data - mean) / std

# 分割训练/测试集
indices = nx.randperm(100)
train_idx = indices[:80]
test_idx = indices[80:]

train_data = nx.index_select(data, 0, train_idx)
test_data = nx.index_select(data, 0, test_idx)
```

#### 示例2：损失函数计算

```python
import neurx as nx
import numpy as np

# 预测值和真实值
predictions = nx.randn(32, 10, requires_grad=True)  # logits
targets = nx.randint(0, 10, (32,), dtype=np.int64)

# 计算top-1准确率
top_preds, _ = nx.topk(predictions, k=1, dim=1)
accuracy = nx.Tensor((top_preds.flatten() == targets).sum()) / 32
```

#### 示例3：特征提取

```python
import neurx as nx

# 输入数据
x = nx.randn(64, 100)

# 特征工程
# 获取最重要的特征
mean_features = nx.sum(x, dim=0)
top_features, top_indices = nx.topk(mean_features, k=50)

# 选择top特征
selected_x = nx.index_select(x, dim=1, indices=top_indices)
```

#### 示例4：矩阵求解

```python
import neurx as nx

# 系统：3x + 2y = 8, x + 4y = 10
A = nx.Tensor([[3.0, 2.0], [1.0, 4.0]])
b = nx.Tensor([8.0, 10.0])

# 求解
x = nx.linalg.solve(A, b)
print(x)  # [x值, y值]

# 验证
result = A @ x  # 应该等于b
```

## 性能建议

1. **批量操作**：使用向量化操作而不是循环
   ```python
   # 好的做法
   result = nx.cat(tensors, dim=0)
   
   # 不好的做法
   result = None
   for t in tensors:
       if result is None:
           result = t
       else:
           result = result + t
   ```

2. **内存效率**：避免不必要的中间张量
   ```python
   # 好的做法
   x = nx.ones((1000, 1000))
   sorted_x, _ = nx.sort(x, dim=0)
   
   # 不好的做法
   x = nx.ones((1000, 1000))
   temp1 = nx.sum(x, dim=0)
   temp2 = nx.mean(temp1)
   result = nx.sort(x, dim=0)
   ```

3. **梯度计算**：在不需要梯度时禁用
   ```python
   with nx.no_grad():
       predictions = model(data)  # 不计算梯度
   ```

## 常见问题

### Q: 如何在CPU和CUDA之间转换？
```python
import neurx as nx

x = nx.zeros((3, 4), device='cpu')
x_cuda = nx.Tensor(x.to_numpy(), device='cuda')
```

### Q: 如何处理不同形状的张量？
```python
# 广播会自动处理
x = nx.zeros((3, 1))
y = nx.ones((1, 4))
z = x + y  # 结果形状为 (3, 4)
```

### Q: 支持哪些数据类型？
目前主要支持float64和float32。其他类型会自动转换为float64。

### Q: 如何调试梯度问题？
```python
x = nx.randn(3, requires_grad=True)
y = x * 2
z = nx.sum(y)
z.backward()

print(f"x.grad: {x.grad}")  # 应该是全2
```

## 更新日志

### v1.1.0 (2024-03-04)
- ✨ 添加张量创建函数（zeros, ones, rand, randn等）
- ✨ 添加高级索引操作（index_select, masked_select, where等）
- ✨ 添加统计函数（sort, topk, unique, quantile等）
- ✨ 添加线性代数函数（inv, det, svd, qr等）
- 🐛 修复梯度计算中的问题
- 📚 完整的文档和示例

## 下一步计划

- [ ] FFT操作
- [ ] 稀疏张量支持
- [ ] 更多CUDA kernel
- [ ] 混合精度训练
- [ ] 分布式训练

