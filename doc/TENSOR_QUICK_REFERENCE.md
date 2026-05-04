# NeurX Tensor API 快速参考

## 张量创建 (Tensor Creation)

```python
# 常数张量
zeros((3, 4))                    # 全0张量
ones((3, 4))                     # 全1张量
full((3, 4), 5.0)                # 填充指定值
eye(3)                           # 单位矩阵
empty((3, 4))                    # 未初始化张量

# 序列张量
arange(10)                       # [0, 1, ..., 9]
arange(2, 10, 2)                 # [2, 4, 6, 8]
linspace(0, 1, 5)                # [0, 0.25, 0.5, 0.75, 1]
logspace(0, 2, 5)                # [1, 10, 100, ...]

# 随机张量
rand((3, 4))                     # U(0, 1)
randn((3, 4))                    # N(0, 1)
normal(0, 1, (3, 4))             # N(mean, std)
uniform(-1, 1, (3, 4))           # U(a, b)
randint(0, 10, (3, 4))           # 随机整数
randperm(10)                     # 随机排列

# 相似张量
zeros_like(x)                    # 与x形状相同的全0
ones_like(x)                     # 与x形状相同的全1
full_like(x, 5.0)                # 与x形状相同的填充张量
empty_like(x)                    # 与x形状相同的未初始化
```

## 索引与选择 (Indexing & Selection)

```python
# 高级索引
index_select(x, dim=1, indices)  # 按索引选择
masked_select(x, mask)           # 按掩码选择
nonzero(x)                       # 非零元素索引

# 条件和修改
where(cond, x, y)                # 条件选择
masked_fill(x, mask, value)      # 掩码填充
masked_scatter(x, mask, source)  # 掩码散列

# 形状变换
cat([x1, x2], dim=0)             # 连接
split(x, 2, dim=0)               # 分割
chunk(x, 3, dim=0)               # 分块
stack([x1, x2], dim=0)           # 堆叠
repeat_interleave(x, 2)          # 重复元素
```

## 统计与排序 (Statistics & Sorting)

```python
# 排序
sort(x, dim=-1)                  # 排序 -> (values, indices)
argsort(x, dim=-1)               # 排序索引
topk(x, k=3, dim=-1)             # 前k大 -> (values, indices)

# 统计
unique(x)                        # 唯一值
median(x, dim=0)                 # 中位数 -> (value, index)
mode(x, dim=0)                   # 众数 -> (value, index)
quantile(x, q=0.5, dim=0)        # 分位数

# 累积
cumsum(x, dim=0)                 # 累加和
cumprod(x, dim=0)                # 累乘积
prod(x, dim=0)                   # 乘积
```

## 线性代数 (Linear Algebra)

### 基础操作
```python
import neurx.core.linalg as linalg

# 矩阵性质
linalg.det(A)                    # 行列式
linalg.matrix_rank(A)            # 矩阵秩
linalg.inv(A)                    # 矩阵求逆

# 向量操作
linalg.cross(u, v)               # 叉积
linalg.outer(u, v)               # 外积
linalg.inner(u, v)               # 内积
```

### 矩阵分解
```python
U, S, Vh = linalg.svd(A)         # 奇异值分解
eigenvals, eigenvecs = linalg.eig(A)   # 特征值分解
eigenvals, eigenvecs = linalg.eigh(A)  # 对称矩阵特征值
Q, R = linalg.qr(A)              # QR分解
L = linalg.cholesky(A)           # Cholesky分解
```

### 求解
```python
x = linalg.solve(A, b)           # 求解 Ax = b
x = linalg.lstsq(A, b)           # 最小二乘解
```

## 常用模式 (Common Patterns)

### 数据预处理
```python
# 标准化
data = randn(1000, 100)
mean = data.mean(dim=0)
std = data.std(dim=0)
normalized = (data - mean) / std

# 分割数据
indices = randperm(1000)
train_idx = indices[:800]
test_idx = indices[800:]
train_data = index_select(data, 0, train_idx)
test_data = index_select(data, 0, test_idx)
```

### 特征选择
```python
# 获取最重要的特征
feature_importance = abs(data).mean(dim=0)
top_features, top_idx = topk(feature_importance, k=50)
selected_data = index_select(data, 1, top_idx)
```

### 矩阵求解
```python
# 求解线性系统
A = Tensor([[3.0, 1.0], [1.0, 2.0]])
b = Tensor([9.0, 8.0])
x = linalg.solve(A, b)
```

## 梯度计算 (Gradients)

```python
# 启用梯度
x = randn(3, requires_grad=True)
y = randn(3, requires_grad=True)

# 前向传播
z = sum(x * y)

# 反向传播
z.backward()

# 访问梯度
print(x.grad)
print(y.grad)

# 清除梯度
x.grad = zeros_like(x)
```

## 设备与类型 (Device & Dtype)

```python
import numpy as np

# 指定设备
x = zeros((3, 4), device='cpu')
y = zeros((3, 4), device='cuda')

# 指定数据类型
x = zeros((3, 4), dtype=np.float32)
y = zeros((3, 4), dtype=np.float64)

# 混合
z = zeros((3, 4), dtype=np.float32, device='cuda')
```

## 批量操作 (Batch Operations)

```python
# 批量拼接
batches = [randn(10, 3, 4) for _ in range(5)]
combined = cat(batches, dim=0)  # (50, 3, 4)

# 批量分割
parts = split(combined, 5, dim=0)
```

## 性能提示 (Performance Tips)

```python
# ✅ 好的做法：向量化操作
result = cat(tensors, dim=0)
sorted_x, _ = sort(x)

# ❌ 不好的做法：循环操作
for t in tensors:
    result = cat([result, t], dim=0)

# ✅ 节省内存：禁用梯度
with nx.no_grad():
    predictions = model(data)

# ❌ 浪费内存：不必要的中间变量
temp1 = randn(1000, 1000)
temp2 = sum(temp1)
result = sort(temp1)  # temp2未使用
```

## 常见错误 (Common Mistakes)

```python
# ❌ 错误：维度不匹配
index_select(x, dim=1, Tensor([0, 10]))  # x可能没有这么多列

# ✅ 正确：检查维度
if indices.shape[0] <= x.shape[dim]:
    result = index_select(x, dim, indices)

# ❌ 错误：形状不兼容
cat([Tensor((3, 4)), Tensor((5, 4))], dim=1)  # 应该用dim=0

# ✅ 正确：匹配的维度
cat([Tensor((3, 4)), Tensor((3, 5))], dim=1)  # dim=1可行
```

## 参考资源

| 文档 | 用途 |
|-----|------|
| [TENSOR_ANALYSIS_AND_IMPROVEMENTS.md](./TENSOR_ANALYSIS_AND_IMPROVEMENTS.md) | 详细功能分析 |
| [TENSOR_NEW_FEATURES_GUIDE.md](./TENSOR_NEW_FEATURES_GUIDE.md) | 完整使用指南 |
| [TENSOR_IMPLEMENTATION_SUMMARY.md](./TENSOR_IMPLEMENTATION_SUMMARY.md) | 实施总结 |
| [tests/test_tensor_new_features.py](./tests/test_tensor_new_features.py) | 单元测试 |

---

**最后更新**: 2024-03-04
**版本**: 1.0
**API稳定性**: ✅ Stable
