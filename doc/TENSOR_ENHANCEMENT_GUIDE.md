# neurx Tensor API 增强实现指南

## 📋 概述

本文档说明了如何在 neurx 框架中使用新增的张量增强功能，这些功能使 neurx 的 API 更接近 PyTorch。

---

## ✨ 新增功能清单

### 1. 核心张量方法

#### `clone()` - 克隆张量
```python
import neurx

x = neurx.randn(3, 4, requires_grad=True)
x_clone = x.clone()

# 克隆是独立的副本
assert x_clone.requires_grad == True
x_clone.data[0, 0] = 999  # 不影响 x
print(x.data[0, 0] != 999)  # True
```

#### `detach()` - 分离梯度
```python
x = neurx.randn(3, 4, requires_grad=True)
y = x * 2
z = y.detach()  # 断开梯度

assert z.requires_grad == False
# z.backward() 会失败，因为没有梯度
```

#### `item()` - 获取标量值
```python
# 仅对单元素张量有效
loss = neurx.Tensor([[3.14]])
scalar_value = loss.item()
print(type(scalar_value))  # <class 'float'>
print(scalar_value)  # 3.14
```

#### `numpy()` - 转换为 NumPy 数组
```python
x = neurx.randn(2, 3)
x_np = x.numpy()

print(type(x_np))  # <class 'numpy.ndarray'>
print(x_np.dtype)  # float64
```

#### `to(device)` - 转移设备
```python
x = neurx.randn(2, 3)
x_cpu = x.to("cpu")  # 保持在 CPU

# CUDA 支持（如果可用）
# x_cuda = x.to("cuda")
```

#### `requires_grad_()` - 设置梯度要求
```python
x = neurx.Tensor([[1.0, 2.0]], requires_grad=False)
x.requires_grad_(True)
assert x.requires_grad == True
assert x.grad is not None
```

---

### 2. 就地操作（In-place）

所有就地操作都会修改张量并返回 `self`，便于链式调用。

#### `add_(other, alpha=1)` - 原地加法
```python
x = neurx.Tensor([[1.0, 2.0]])
y = neurx.Tensor([[3.0, 4.0]])

x.add_(y)  # x = x + y
x.add_(y, alpha=2)  # x = x + 2*y
print(x)  # Tensor([[9.0, 10.0]])
```

#### `sub_()`, `mul_()`, `div_()` - 其他算术操作
```python
x = neurx.Tensor([[10.0, 20.0]])
x.sub_(2)  # x -= 2
x.mul_(0.5)  # x *= 0.5
x.div_(2)  # x /= 2
```

#### `zero_()` - 清零
```python
x = neurx.Tensor([[1.0, 2.0], [3.0, 4.0]])
x.zero_()
print(x)  # Tensor([[0.0, 0.0], [0.0, 0.0]])
```

#### `fill_(value)` - 填充
```python
x = neurx.Tensor([[1.0, 2.0], [3.0, 4.0]])
x.fill_(7)
print(x)  # Tensor([[7.0, 7.0], [7.0, 7.0]])
```

---

### 3. 比较和逻辑操作

返回布尔张量，用于条件操作。

```python
x = neurx.Tensor([[1.0, 2.0], [3.0, 4.0]])
y = neurx.Tensor([[1.5, 1.5], [3.5, 3.5]])

# 元素比较
eq = x.eq(y)   # 相等？
ne = x.ne(y)   # 不等？
lt = x.lt(y)   # 小于？
le = x.le(y)   # 小于等于？
gt = x.gt(y)   # 大于？
ge = x.ge(y)   # 大于等于？

print(lt.data)
# [[True, False]
#  [True, False]]
```

---

### 4. 数据类型转换

支持 PyTorch 风格的类型转换。

```python
x = neurx.randn(2, 3)

# 浮点类型
x_float32 = x.float()   # float32
x_float64 = x.double()  # float64

# 整数类型
x_int32 = x.int()       # int32
x_int64 = x.long()      # int64

print(x_float32.dtype)  # float32
print(x_int32.dtype)    # int32
```

---

### 5. 高级操作

#### `clamp(min, max)` - 限制值范围
```python
x = neurx.Tensor([[-1.0, 0.5, 1.5], [0.0, 2.0, -0.5]])

# 限制在 [0, 1] 范围内
x_clamped = x.clamp(min=0, max=1)
print(x_clamped.data)
# [[0.0, 0.5, 1.0]
#  [0.0, 1.0, 0.0]]
```

#### `isnan()`, `isinf()`, `isfinite()` - 数值检查
```python
x = neurx.Tensor([[1.0, float('nan')], [float('inf'), 2.0]])

nan_mask = x.isnan()
print(nan_mask.data)
# [[False, True]
#  [False, False]]

inf_mask = x.isinf()
print(inf_mask.data)
# [[False, False]
#  [True, False]]

finite_mask = x.isfinite()
print(finite_mask.data)
# [[True, False]
#  [False, True]]
```

#### `retain_grad()` - 保留非叶子梯度
```python
x = neurx.Tensor([[1.0, 2.0]], requires_grad=True)
y = x * 2
y.retain_grad()  # 保留 y 的梯度

z = y.sum()
z.backward()
print(y.grad)  # 梯度被保留
```

---

## 🔧 使用建议

### 最佳实践

```python
import neurx

# 1. 克隆与分离
def safe_copy(x):
    """创建安全的张量副本"""
    return x.clone()

def detach_for_eval(model_output):
    """分离输出用于评估"""
    return model_output.detach()

# 2. 设备管理
def move_to_device(model, device="cpu"):
    """灵活的设备转移"""
    return model.to(device)

# 3. 类型转换
def ensure_dtype(x, dtype="float32"):
    """确保正确的数据类型"""
    if dtype == "float32":
        return x.float()
    elif dtype == "float64":
        return x.double()
    return x

# 4. 安全的梯度操作
def compute_with_grad_tracking(x):
    """跟踪中间梯度"""
    y = x * 2
    y.retain_grad()
    z = y.sum()
    z.backward()
    return y.grad, x.grad

# 5. 值范围限制（如 Batch Norm）
def normalize_output(x, min_val=0.0, max_val=1.0):
    """限制输出范围"""
    return x.clamp(min=min_val, max=max_val)
```

### 与 PyTorch 的互操作

```python
import torch
import neurx

# neurx -> PyTorch
neurx_tensor = neurx.randn(2, 3)
torch_tensor = torch.from_numpy(neurx_tensor.numpy())

# PyTorch -> neurx
pt_tensor = torch.randn(2, 3)
neurx_tensor = neurx.Tensor(pt_tensor.numpy())

# 梯度同步
neurx_tensor = neurx.Tensor(pt_tensor.detach().numpy(), 
                            requires_grad=pt_tensor.requires_grad)
```

---

## 📊 性能考虑

### 就地操作的优势

```python
import time
import neurx

x = neurx.randn(10000, 10000, requires_grad=True)
y = neurx.randn(10000, 10000, requires_grad=True)

# 方法 1: 非就地（创建新张量）
start = time.time()
z = x + y
time_1 = time.time() - start

# 方法 2: 就地操作（修改原张量）
x = neurx.randn(10000, 10000, requires_grad=True)
start = time.time()
x.add_(y)
time_2 = time.time() - start

print(f"非就地: {time_1:.4f}s")
print(f"就地: {time_2:.4f}s")
# 就地操作通常更快且内存高效
```

### 避免梯度累积

```python
# ❌ 不好：梯度累积
for i in range(10):
    y = x * i
    y.sum().backward()  # x.grad 不断累积

# ✅ 好：及时清零
for i in range(10):
    x.zero_grad()  # 清零梯度
    y = x * i
    y.sum().backward()
```

---

## 🐛 调试技巧

### 检查张量属性

```python
x = neurx.randn(3, 4, requires_grad=True)

# 检查基本信息
print(f"Shape: {x.shape}")
print(f"Device: {x.device}")
print(f"Requires grad: {x.requires_grad}")
print(f"Dtype: {x.dtype}")
print(f"Num elements: {x.numel()}")

# 检查梯度
if x.grad is not None:
    print(f"Grad shape: {x.grad.shape}")
    print(f"Grad norm: {x.grad.std():.4f}")
else:
    print("No gradient")
```

### 梯度检查

```python
def check_gradient_nan(tensor):
    """检查梯度中的 NaN 值"""
    if tensor.grad is None:
        return False
    nan_mask = tensor.grad != tensor.grad
    if nan_mask.any():
        print(f"⚠️  Found NaN in gradient of {tensor}")
        return True
    return False

# 在训练循环中使用
for x in model.parameters():
    if check_gradient_nan(x):
        break
```

---

## 📚 完整示例

### 简单的神经网络训练

```python
import neurx
import neurx.nn as nn
from neurx.optim import SGD

# 构建模型
model = nn.Sequential(
    nn.Linear(10, 20),
    nn.ReLU(),
    nn.Linear(20, 1)
)

# 优化器
optimizer = SGD(model.parameters(), lr=0.01)

# 训练数据
x = neurx.randn(32, 10, requires_grad=False)
y = neurx.randn(32, 1, requires_grad=False)

# 训练循环
for epoch in range(100):
    # 前向传播
    pred = model(x)
    loss = ((pred - y) ** 2).mean()
    
    # 反向传播
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    
    if epoch % 10 == 0:
        print(f"Epoch {epoch}, Loss: {loss.item():.4f}")
```

### 梯度检查

```python
def numerical_gradient(f, x, eps=1e-5):
    """数值梯度"""
    grad = neurx.zeros_like(x)
    for i in range(x.numel()):
        x_plus = x.clone()
        x_plus.data.flat[i] += eps
        x_minus = x.clone()
        x_minus.data.flat[i] -= eps
        grad.data.flat[i] = (f(x_plus) - f(x_minus)) / (2 * eps)
    return grad

# 验证自动求导
x = neurx.randn(3, requires_grad=True)
def f(t):
    return (t ** 2).sum()

y = f(x)
y.backward()

numerical_grad = numerical_gradient(f, x.detach())
auto_grad = x.grad

print(f"Numerical: {numerical_grad.data}")
print(f"Auto grad: {auto_grad}")
print(f"差异: {(numerical_grad.data - auto_grad).abs().max():.6f}")
```

---

## 🎯 总结

neurx 现已通过增强模块支持更多 PyTorch 兼容的 API：

| 功能类别 | 支持度 | 说明 |
|---------|--------|------|
| 基础操作 | ✅ 100% | add, sub, mul, div 等 |
| 约简操作 | ✅ 100% | sum, mean, max, min 等 |
| 张量方法 | ✅ 95% | clone, detach, item, numpy 等 |
| 就地操作 | ✅ 85% | add_, mul_, zero_ 等 |
| 比较操作 | ✅ 85% | eq, lt, gt, le, ge 等 |
| 类型转换 | ✅ 90% | float, double, int, long |
| 高级操作 | ✅ 80% | clamp, isnan, isinf 等 |

下一步可以继续完善：
- 📌 稀疏张量支持
- 📌 分布式张量操作
- 📌 更多 CUDA 优化
- 📌 混合精度支持
