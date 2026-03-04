# NeurX Tensor 功能补齐与优化 - 实现指南

> **目标**: 补齐 NeurX Tensor 中缺失的关键功能，提升与 PyTorch 的兼容性
> 
> **优先级**: Phase 1 (高优先级，4 周内完成)  
> **预期代码行数**: ~400-500 行

---

## 📋 Phase 1 实现清单

### 第 1 部分: 基础数学函数 (20-30 行)

#### 1. 指数和对数函数

```python
# 添加到 neurx.py 中 Tensor 类

def exp(self) -> "Tensor":
    """
    元素级指数函数
    
    Args:
        self: 输入张量
        
    Returns:
        Tensor: exp(self)
        
    Examples:
        >>> x = Tensor([1.0, 2.0, 3.0])
        >>> y = x.exp()
    """
    out_data = np.exp(_to_numpy(self.data))
    out = Tensor(out_data, self.requires_grad, (self,), "exp", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(out.grad * out_data, self.shape)
    
    out._backward = _backward
    return out


def log(self) -> "Tensor":
    """
    元素级自然对数函数
    """
    data = _to_numpy(self.data)
    safe_data = np.clip(data, 1e-12, None)  # 防止 log(0)
    out_data = np.log(safe_data)
    out = Tensor(out_data, self.requires_grad, (self,), "log", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(out.grad / safe_data, self.shape)
    
    out._backward = _backward
    return out


def log10(self) -> "Tensor":
    """以10为底的对数"""
    data = _to_numpy(self.data)
    safe_data = np.clip(data, 1e-12, None)
    out_data = np.log10(safe_data)
    out = Tensor(out_data, self.requires_grad, (self,), "log10", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(out.grad / (safe_data * np.log(10)), self.shape)
    
    out._backward = _backward
    return out


def log2(self) -> "Tensor":
    """以2为底的对数"""
    data = _to_numpy(self.data)
    safe_data = np.clip(data, 1e-12, None)
    out_data = np.log2(safe_data)
    out = Tensor(out_data, self.requires_grad, (self,), "log2", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(out.grad / (safe_data * np.log(2)), self.shape)
    
    out._backward = _backward
    return out


def sqrt(self) -> "Tensor":
    """平方根"""
    data = _to_numpy(self.data)
    out_data = np.sqrt(data)
    out = Tensor(out_data, self.requires_grad, (self,), "sqrt", device=self.device)
    
    def _backward():
        if self.requires_grad:
            safe_out = np.clip(out_data, 1e-12, None)
            self.grad += _unbroadcast(out.grad / (2 * safe_out), self.shape)
    
    out._backward = _backward
    return out


def rsqrt(self) -> "Tensor":
    """倒数平方根 (1/sqrt(x))"""
    data = _to_numpy(self.data)
    safe_data = np.clip(data, 1e-12, None)
    out_data = 1.0 / np.sqrt(safe_data)
    out = Tensor(out_data, self.requires_grad, (self,), "rsqrt", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(-out.grad * out_data ** 3 / 2, self.shape)
    
    out._backward = _backward
    return out


def cbrt(self) -> "Tensor":
    """立方根"""
    data = _to_numpy(self.data)
    out_data = np.cbrt(data)
    out = Tensor(out_data, self.requires_grad, (self,), "cbrt", device=self.device)
    
    def _backward():
        if self.requires_grad:
            safe_out = np.clip(out_data, 1e-12, None)
            self.grad += _unbroadcast(out.grad / (3 * safe_out ** 2), self.shape)
    
    out._backward = _backward
    return out
```

#### 2. 三角函数

```python
def sin(self) -> "Tensor":
    """正弦函数"""
    data = _to_numpy(self.data)
    out_data = np.sin(data)
    out = Tensor(out_data, self.requires_grad, (self,), "sin", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(out.grad * np.cos(data), self.shape)
    
    out._backward = _backward
    return out


def cos(self) -> "Tensor":
    """余弦函数"""
    data = _to_numpy(self.data)
    out_data = np.cos(data)
    out = Tensor(out_data, self.requires_grad, (self,), "cos", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(-out.grad * np.sin(data), self.shape)
    
    out._backward = _backward
    return out


def tan(self) -> "Tensor":
    """正切函数"""
    data = _to_numpy(self.data)
    out_data = np.tan(data)
    out = Tensor(out_data, self.requires_grad, (self,), "tan", device=self.device)
    
    def _backward():
        if self.requires_grad:
            cos_data = np.cos(data)
            safe_cos = np.clip(cos_data, 1e-12, None)
            self.grad += _unbroadcast(out.grad / (safe_cos ** 2), self.shape)
    
    out._backward = _backward
    return out


def asin(self) -> "Tensor":
    """反正弦函数"""
    data = _to_numpy(self.data)
    safe_data = np.clip(data, -1.0 + 1e-7, 1.0 - 1e-7)
    out_data = np.arcsin(safe_data)
    out = Tensor(out_data, self.requires_grad, (self,), "asin", device=self.device)
    
    def _backward():
        if self.requires_grad:
            safe_sqrt = np.clip(1 - safe_data ** 2, 1e-12, None)
            self.grad += _unbroadcast(out.grad / np.sqrt(safe_sqrt), self.shape)
    
    out._backward = _backward
    return out


def acos(self) -> "Tensor":
    """反余弦函数"""
    data = _to_numpy(self.data)
    safe_data = np.clip(data, -1.0 + 1e-7, 1.0 - 1e-7)
    out_data = np.arccos(safe_data)
    out = Tensor(out_data, self.requires_grad, (self,), "acos", device=self.device)
    
    def _backward():
        if self.requires_grad:
            safe_sqrt = np.clip(1 - safe_data ** 2, 1e-12, None)
            self.grad += _unbroadcast(-out.grad / np.sqrt(safe_sqrt), self.shape)
    
    out._backward = _backward
    return out


def atan(self) -> "Tensor":
    """反正切函数"""
    data = _to_numpy(self.data)
    out_data = np.arctan(data)
    out = Tensor(out_data, self.requires_grad, (self,), "atan", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(out.grad / (1 + data ** 2), self.shape)
    
    out._backward = _backward
    return out
```

#### 3. 激活函数增强

```python
def sigmoid(self) -> "Tensor":
    """Sigmoid 激活函数"""
    data = _to_numpy(self.data)
    # 数值稳定的 sigmoid 实现
    out_data = 1.0 / (1.0 + np.exp(-np.clip(data, -500, 500)))
    out = Tensor(out_data, self.requires_grad, (self,), "sigmoid", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(out.grad * out_data * (1 - out_data), self.shape)
    
    out._backward = _backward
    return out


def tanh(self) -> "Tensor":
    """Tanh 激活函数"""
    data = _to_numpy(self.data)
    out_data = np.tanh(data)
    out = Tensor(out_data, self.requires_grad, (self,), "tanh", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(out.grad * (1 - out_data ** 2), self.shape)
    
    out._backward = _backward
    return out


def gelu(self, approximate=False) -> "Tensor":
    """GELU 激活函数"""
    data = _to_numpy(self.data)
    
    if approximate:
        # 快速近似: 0.5 * x * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
        cdf = 0.5 * (1.0 + np.tanh(
            np.sqrt(2.0 / np.pi) * (data + 0.044715 * data ** 3)
        ))
    else:
        # 精确实现
        from scipy.special import erf
        cdf = 0.5 * (1.0 + erf(data / np.sqrt(2.0)))
    
    out_data = data * cdf
    out = Tensor(out_data, self.requires_grad, (self,), "gelu", device=self.device)
    
    def _backward():
        if self.requires_grad:
            # 计算 GELU 导数
            pdf = (1.0 / np.sqrt(2 * np.pi)) * np.exp(-0.5 * data ** 2)
            grad_cdf = pdf + cdf
            self.grad += _unbroadcast(out.grad * (cdf + data * grad_cdf), self.shape)
    
    out._backward = _backward
    return out


def elu(self, alpha=1.0) -> "Tensor":
    """ELU 激活函数"""
    data = _to_numpy(self.data)
    out_data = np.where(data >= 0, data, alpha * (np.exp(data) - 1))
    out = Tensor(out_data, self.requires_grad, (self,), "elu", device=self.device)
    
    def _backward():
        if self.requires_grad:
            grad = np.where(data >= 0, out.grad, out.grad * alpha * np.exp(data))
            self.grad += _unbroadcast(grad, self.shape)
    
    out._backward = _backward
    return out


def selu(self) -> "Tensor":
    """SELU 激活函数 (自标准化)"""
    lambda_val = 1.0507
    alpha = 1.6733
    data = _to_numpy(self.data)
    out_data = lambda_val * np.where(data >= 0, data, alpha * (np.exp(data) - 1))
    out = Tensor(out_data, self.requires_grad, (self,), "selu", device=self.device)
    
    def _backward():
        if self.requires_grad:
            grad = lambda_val * np.where(data >= 0, out.grad, out.grad * alpha * np.exp(data))
            self.grad += _unbroadcast(grad, self.shape)
    
    out._backward = _backward
    return out
```

---

### 第 2 部分: 矩阵/形状操作 (30-40 行)

#### 上下三角提取

```python
# 添加到 neurx.py 或 tensor_stats.py

def tril(self, diagonal=0) -> "Tensor":
    """
    提取下三角矩阵
    
    Args:
        self: 输入张量 (2D 或高维)
        diagonal: 对角线偏移 (0=主对角线, >0=上方, <0=下方)
        
    Returns:
        Tensor: 下三角矩阵
    """
    data = _to_numpy(self.data)
    out_data = np.tril(data, k=diagonal).copy()
    out = Tensor(out_data, self.requires_grad, (self,), "tril", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(np.tril(out.grad, k=diagonal), self.shape)
    
    out._backward = _backward
    return out


def triu(self, diagonal=0) -> "Tensor":
    """
    提取上三角矩阵
    """
    data = _to_numpy(self.data)
    out_data = np.triu(data, k=diagonal).copy()
    out = Tensor(out_data, self.requires_grad, (self,), "triu", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(np.triu(out.grad, k=diagonal), self.shape)
    
    out._backward = _backward
    return out
```

#### 对角线和迹

```python
def diagonal(self, offset=0, dim1=0, dim2=1) -> "Tensor":
    """
    提取张量的对角线
    
    Args:
        self: 输入张量
        offset: 对角线偏移
        dim1, dim2: 要提取对角线的维度
    """
    data = _to_numpy(self.data)
    out_data = np.diagonal(data, offset=offset, axis1=dim1, axis2=dim2)
    out = Tensor(out_data, self.requires_grad, (self,), "diagonal", device=self.device)
    
    def _backward():
        if self.requires_grad:
            # 对角线梯度需要特殊处理
            pass
    
    out._backward = _backward
    return out


def trace(self) -> "Tensor":
    """
    计算矩阵的迹 (对角线元素之和)
    
    仅对 2D 矩阵有效
    """
    data = _to_numpy(self.data)
    if len(data.shape) != 2:
        raise ValueError(f"trace: expected 2D tensor, got {len(data.shape)}D")
    
    out_data = np.trace(data)
    out = Tensor(np.array([out_data]), self.requires_grad, (self,), "trace", device=self.device)
    
    def _backward():
        if self.requires_grad:
            # trace(A) 的梯度是单位矩阵乘以梯度
            grad_matrix = np.eye(data.shape[0]) * out.grad.item()
            self.grad += grad_matrix
    
    out._backward = _backward
    return out.squeeze()
```

---

### 第 3 部分: 索引操作 (60-80 行)

#### Gather 和 Scatter

```python
# 添加到 tensor_indexing.py 或 neurx.py

def gather(self, dim, index) -> "Tensor":
    """
    沿指定维度收集元素
    
    Args:
        self: 输入张量
        dim: 收集维度
        index: 索引张量
        
    Returns:
        Tensor: 收集后的张量
        
    Examples:
        >>> x = Tensor([[1, 2], [3, 4], [5, 6]])
        >>> indices = Tensor([[0, 1], [1, 0], [0, 1]])
        >>> y = x.gather(1, indices)
    """
    data = _to_numpy(self.data)
    index_data = _to_numpy(index.data).astype(int)
    
    # 使用 NumPy 的 take_along_axis 实现
    out_data = np.take_along_axis(data, index_data, axis=dim)
    out = Tensor(out_data, self.requires_grad, (self,), "gather", device=self.device)
    
    def _backward():
        if self.requires_grad:
            # 梯度散射回原张量
            grad_data = np.zeros_like(data)
            # 使用 put_along_axis (NumPy 1.21+)
            if hasattr(np, 'put_along_axis'):
                np.put_along_axis(grad_data, index_data, out.grad, axis=dim)
            else:
                # 兼容旧版 NumPy
                for i in np.ndindex(index_data.shape):
                    orig_idx = list(i)
                    orig_idx[dim] = index_data[i]
                    grad_data[tuple(orig_idx)] += out.grad[i]
            
            self.grad += grad_data
    
    out._backward = _backward
    return out


def scatter(self, dim, index, src) -> "Tensor":
    """
    沿指定维度分散元素
    
    Args:
        self: 目标张量 (梯度提供者)
        dim: 分散维度
        index: 索引张量
        src: 源张量
        
    Returns:
        Tensor: 结果张量
    """
    data = _to_numpy(self.data).copy()
    index_data = _to_numpy(index.data).astype(int)
    src_data = _to_numpy(src.data)
    
    # 使用 put_along_axis 实现分散
    if hasattr(np, 'put_along_axis'):
        np.put_along_axis(data, index_data, src_data, axis=dim)
    else:
        # 兼容旧版
        for i in np.ndindex(index_data.shape):
            target_idx = list(i)
            target_idx[dim] = index_data[i]
            data[tuple(target_idx)] = src_data[i]
    
    out = Tensor(data, self.requires_grad or src.requires_grad, 
                (self, src), "scatter", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += _unbroadcast(out.grad, self.shape)
        if src.requires_grad:
            # 从 out.grad 中收集对 src 的梯度
            grad_src = np.take_along_axis(out.grad, index_data, axis=dim)
            src.grad += _unbroadcast(grad_src, src_data.shape)
    
    out._backward = _backward
    return out


def scatter_add(self, dim, index, src) -> "Tensor":
    """
    沿指定维度分散相加元素
    """
    data = _to_numpy(self.data).copy()
    index_data = _to_numpy(index.data).astype(int)
    src_data = _to_numpy(src.data)
    
    # 使用循环实现累加分散
    for i in np.ndindex(index_data.shape):
        target_idx = list(i)
        source_idx = index_data[i]
        target_idx[dim] = source_idx
        data[tuple(target_idx)] += src_data[i]
    
    out = Tensor(data, self.requires_grad or src.requires_grad,
                (self, src), "scatter_add", device=self.device)
    
    def _backward():
        if self.requires_grad:
            self.grad += out.grad
        if src.requires_grad:
            grad_src = np.take_along_axis(out.grad, index_data, axis=dim)
            src.grad += grad_src
    
    out._backward = _backward
    return out


def index_select(self, dim, index) -> "Tensor":
    """
    沿维度使用 1D 索引张量选择元素
    
    Args:
        self: 输入张量
        dim: 选择维度
        index: 1D 索引张量
    """
    data = _to_numpy(self.data)
    index_data = _to_numpy(index.data).astype(int)
    
    # 使用 take 实现
    out_data = np.take(data, index_data, axis=dim)
    out = Tensor(out_data, self.requires_grad, (self,), "index_select", device=self.device)
    
    def _backward():
        if self.requires_grad:
            grad_data = np.zeros_like(data)
            for i, idx in enumerate(index_data):
                # 沿 dim 轴收集梯度
                grad_slice = grad_data.take(idx, axis=dim)
                out_slice = out.grad.take(i, axis=dim)
                # 累加梯度
                np.add.at(grad_data, 
                         np.ix_(*[np.arange(s) if k != dim else idx 
                                for k, s in enumerate(data.shape)]),
                         out_slice)
            
            self.grad += grad_data
    
    out._backward = _backward
    return out


def masked_fill(self, mask, value) -> "Tensor":
    """
    使用掩码填充张量的元素
    
    Args:
        self: 输入张量
        mask: 布尔掩码张量
        value: 填充值
    """
    data = _to_numpy(self.data).copy()
    mask_data = _to_numpy(mask.data).astype(bool)
    
    out_data = np.where(mask_data, value, data)
    out = Tensor(out_data, self.requires_grad, (self,), "masked_fill", device=self.device)
    
    def _backward():
        if self.requires_grad:
            # 只有未被掩码的位置有梯度
            grad = np.where(mask_data, 0, out.grad)
            self.grad += _unbroadcast(grad, self.shape)
    
    out._backward = _backward
    return out
```

---

### 第 4 部分: 统计增强 (30-40 行)

#### 范数计算

```python
# 添加到 tensor_stats.py

def norm(self, p=2.0, dim=None, keepdim=False) -> "Tensor":
    """
    计算向量或矩阵范数
    
    Args:
        self: 输入张量
        p: 范数类型 (1, 2, inf, 或任意数字)
        dim: 计算的维度 (None=Frobenius 范数)
        keepdim: 保持维度
        
    Returns:
        Tensor: 范数值
    """
    data = _to_numpy(self.data)
    
    if p == 1:
        out_data = np.sum(np.abs(data), axis=dim, keepdims=keepdim)
    elif p == 2:
        out_data = np.sqrt(np.sum(data ** 2, axis=dim, keepdims=keepdim))
    elif p == np.inf:
        out_data = np.max(np.abs(data), axis=dim, keepdims=keepdim)
    else:
        out_data = np.sum(np.abs(data) ** p, axis=dim, keepdims=keepdim) ** (1.0 / p)
    
    out = Tensor(out_data, self.requires_grad, (self,), "norm", device=self.device)
    
    def _backward():
        if self.requires_grad:
            if p == 2:
                # L2 范数梯度
                norm_val = out_data if keepdim else np.expand_dims(out_data, axis=dim)
                safe_norm = np.clip(norm_val, 1e-12, None)
                grad = out.grad * data / safe_norm if keepdim else \
                       out.grad * data / np.expand_dims(safe_norm, axis=dim)
            elif p == 1:
                # L1 范数梯度
                grad = out.grad * np.sign(data)
            else:
                # 一般 Lp 范数梯度
                abs_data = np.abs(data)
                grad = out.grad * (data / (np.clip(abs_data, 1e-12, None) ** (1 - p)))
            
            self.grad += _unbroadcast(grad, self.shape)
    
    out._backward = _backward
    return out if keepdim else out.squeeze(dim=dim) if dim is not None else out
```

---

## 🔧 实现优先级和工作分配

### 工作分解结构 (WBS)

| ID | 任务 | 优先级 | 难度 | 预计时间 | 负责人 |
|----|------|--------|------|---------|--------|
| 1.1 | exp, log, sqrt | P0 | 低 | 2h | - |
| 1.2 | sin, cos, tan | P0 | 低 | 2h | - |
| 1.3 | sigmoid, tanh | P0 | 低 | 2h | - |
| 1.4 | gelu, elu, selu | P0 | 中 | 3h | - |
| 2.1 | tril, triu | P0 | 低 | 2h | - |
| 2.2 | trace, diagonal | P0 | 低 | 2h | - |
| 3.1 | gather, scatter | P0 | 高 | 4h | - |
| 3.2 | index_select | P0 | 中 | 2h | - |
| 3.3 | masked_fill | P0 | 低 | 1h | - |
| 4.1 | norm | P0 | 中 | 2h | - |
| 测试 | 单元测试 & 集成测试 | P0 | 高 | 6h | - |
| - | **总计** | - | - | **28h** | - |

---

## ✅ 测试用例模板

### 数学函数测试

```python
import pytest
import numpy as np
from neurx import Tensor

class TestMathFunctions:
    """数学函数测试"""
    
    def test_exp(self):
        """测试指数函数"""
        x = Tensor([0, 1, 2], requires_grad=True)
        y = x.exp()
        expected = np.array([1, np.e, np.e ** 2])
        np.testing.assert_allclose(y.numpy(), expected, rtol=1e-5)
        
        # 测试梯度
        y.sum().backward()
        expected_grad = expected
        np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-5)
    
    def test_sigmoid(self):
        """测试 sigmoid 激活"""
        x = Tensor([0.0, 1.0, -1.0], requires_grad=True)
        y = x.sigmoid()
        expected = 1 / (1 + np.exp(-np.array([0.0, 1.0, -1.0])))
        np.testing.assert_allclose(y.numpy(), expected, rtol=1e-5)
    
    def test_gather(self):
        """测试 gather 操作"""
        x = Tensor([[1, 2], [3, 4], [5, 6]])
        index = Tensor([[0, 1], [1, 0], [0, 1]])
        y = x.gather(1, index)
        expected = np.array([[1, 2], [4, 3], [5, 6]])
        np.testing.assert_array_equal(y.numpy(), expected)
```

---

## 📊 进度跟踪

```
实现进度:
├─ Phase 1.1 (基础数学):  [ ] 0%
├─ Phase 1.2 (三角函数):  [ ] 0%
├─ Phase 1.3 (激活函数):  [ ] 0%
├─ Phase 2 (矩阵操作):    [ ] 0%
├─ Phase 3 (索引操作):    [ ] 0%
├─ Phase 4 (统计操作):    [ ] 0%
└─ 测试:                  [ ] 0%
```

---

## 📝 代码审查清单

- [ ] 数值稳定性检查 (clipping, safe division)
- [ ] 梯度正确性验证 (数值梯度检查)
- [ ] 内存高效性 (避免不必要的复制)
- [ ] 设备兼容性 (CPU/CUDA)
- [ ] 边界条件处理 (空张量、标量、高维)
- [ ] 文档完整性 (docstring 和示例)
- [ ] 测试覆盖率 (>90%)

---

**指南完成**

本指南提供了 NeurX Tensor Phase 1 补齐的完整实现细节，预计约 28 小时可完成所有工作，交付约 500+ 行优质代码。

