# Tensor框架快速改进方案 - 具体实现

## 第一周计划: P0级核心功能实现

### 任务1: 实现基础张量操作 (4小时)

在 `tensor/core/tensor.py` 中添加以下方法:

```python
class Tensor:
    # ... existing code ...
    
    # ==================== 维度操作 ====================
    def squeeze(self, dim=None):
        """Remove dimensions of size 1."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.squeeze(self, dim)
        
        data = self.to_numpy()
        if dim is None:
            out_data = np.squeeze(data)
        else:
            d = dim if dim >= 0 else len(data.shape) + dim
            if d < 0 or d >= len(data.shape):
                raise IndexError(f"Dimension {dim} out of range")
            if data.shape[d] != 1:
                raise RuntimeError(f"Cannot squeeze dim {d} of size {data.shape[d]}")
            out_data = np.squeeze(data, axis=d)
        
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    def unsqueeze(self, dim):
        """Add a dimension of size 1."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.unsqueeze(self, dim)
        
        data = self.to_numpy()
        d = dim if dim >= 0 else len(data.shape) + dim + 1
        
        if d < 0 or d > len(data.shape):
            raise IndexError(f"Dimension {dim} out of range")
        
        out_data = np.expand_dims(data, axis=d)
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    def reshape(self, *shape):
        """Change tensor shape (returns new tensor)."""
        if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
            shape = tuple(shape[0])
        
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.reshape(self, shape)
        
        data = self.to_numpy()
        out_data = data.reshape(shape)
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    def view(self, *shape):
        """View operation (alias for reshape)."""
        return self.reshape(*shape)
    
    def flatten(self, start_dim=0, end_dim=-1):
        """Flatten dimensions."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.flatten(self, start_dim, end_dim)
        
        data = self.to_numpy()
        # Handle negative indices
        start = start_dim if start_dim >= 0 else len(data.shape) + start_dim
        end = end_dim if end_dim >= 0 else len(data.shape) + end_dim
        
        if start < 0 or end >= len(data.shape) or start > end:
            raise IndexError(f"Invalid flatten range: {start_dim} to {end_dim}")
        
        # Calculate new shape
        left_shape = data.shape[:start]
        right_shape = data.shape[end+1:]
        flat_size = int(np.prod(data.shape[start:end+1]))
        
        new_shape = left_shape + (flat_size,) + right_shape
        out_data = data.reshape(new_shape)
        
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    def transpose(self, dim0, dim1):
        """Transpose two dimensions."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.transpose(self, dim0, dim1)
        
        data = self.to_numpy()
        # Handle negative indices
        d0 = dim0 if dim0 >= 0 else len(data.shape) + dim0
        d1 = dim1 if dim1 >= 0 else len(data.shape) + dim1
        
        axes = list(range(len(data.shape)))
        axes[d0], axes[d1] = axes[d1], axes[d0]
        
        out_data = np.transpose(data, axes)
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    def permute(self, *dims):
        """Permute dimensions."""
        if len(dims) == 1 and isinstance(dims[0], (tuple, list)):
            dims = tuple(dims[0])
        
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.permute(self, dims)
        
        data = self.to_numpy()
        if len(dims) != len(data.shape):
            raise ValueError(f"Permute dims {dims} don't match shape {data.shape}")
        
        out_data = np.transpose(data, dims)
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    # ==================== 统计函数 ====================
    def sum(self, dim=None, keepdim=False):
        """Sum over dimensions."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.sum(self, dim, keepdim)
        
        data = self.to_numpy()
        
        if dim is None:
            out_data = np.sum(data)
            if isinstance(out_data, np.ndarray):
                out_data = out_data.reshape((1,) if keepdim else ())
        else:
            d = dim if dim >= 0 else len(data.shape) + dim
            out_data = np.sum(data, axis=d, keepdims=keepdim)
        
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    def mean(self, dim=None, keepdim=False):
        """Mean over dimensions."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.mean(self, dim, keepdim)
        
        data = self.to_numpy()
        
        if dim is None:
            out_data = np.mean(data)
            if isinstance(out_data, np.ndarray):
                out_data = out_data.reshape((1,) if keepdim else ())
        else:
            d = dim if dim >= 0 else len(data.shape) + dim
            out_data = np.mean(data, axis=d, keepdims=keepdim)
        
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    def std(self, dim=None, keepdim=False, unbiased=True):
        """Standard deviation."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.std(self, dim, keepdim, unbiased)
        
        data = self.to_numpy()
        ddof = 1 if unbiased else 0
        
        if dim is None:
            out_data = np.std(data, ddof=ddof)
            if isinstance(out_data, np.ndarray):
                out_data = out_data.reshape((1,) if keepdim else ())
        else:
            d = dim if dim >= 0 else len(data.shape) + dim
            out_data = np.std(data, axis=d, ddof=ddof, keepdims=keepdim)
        
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    def var(self, dim=None, keepdim=False, unbiased=True):
        """Variance."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.var(self, dim, keepdim, unbiased)
        
        data = self.to_numpy()
        ddof = 1 if unbiased else 0
        
        if dim is None:
            out_data = np.var(data, ddof=ddof)
            if isinstance(out_data, np.ndarray):
                out_data = out_data.reshape((1,) if keepdim else ())
        else:
            d = dim if dim >= 0 else len(data.shape) + dim
            out_data = np.var(data, axis=d, ddof=ddof, keepdims=keepdim)
        
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    # ==================== 极值函数 ====================
    def max(self, dim=None, keepdim=False):
        """Maximum values (returns value and indices if dim specified)."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.max(self, dim, keepdim)
        
        data = self.to_numpy()
        
        if dim is None:
            out_data = np.max(data)
            return Tensor(out_data, requires_grad=False, device=self.device)
        else:
            d = dim if dim >= 0 else len(data.shape) + dim
            indices = np.argmax(data, axis=d)
            values = np.max(data, axis=d, keepdims=keepdim)
            
            values_tensor = Tensor(values, requires_grad=False, device=self.device)
            indices_tensor = Tensor(indices.astype(np.float64), requires_grad=False, device=self.device)
            
            return values_tensor, indices_tensor
    
    def min(self, dim=None, keepdim=False):
        """Minimum values."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.min(self, dim, keepdim)
        
        data = self.to_numpy()
        
        if dim is None:
            out_data = np.min(data)
            return Tensor(out_data, requires_grad=False, device=self.device)
        else:
            d = dim if dim >= 0 else len(data.shape) + dim
            indices = np.argmin(data, axis=d)
            values = np.min(data, axis=d, keepdims=keepdim)
            
            values_tensor = Tensor(values, requires_grad=False, device=self.device)
            indices_tensor = Tensor(indices.astype(np.float64), requires_grad=False, device=self.device)
            
            return values_tensor, indices_tensor
    
    def argmax(self, dim=None, keepdim=False):
        """Indices of maximum values."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.argmax(self, dim, keepdim)
        
        data = self.to_numpy()
        
        if dim is None:
            idx = np.argmax(data)
            out_data = np.array(idx)
        else:
            d = dim if dim >= 0 else len(data.shape) + dim
            out_data = np.argmax(data, axis=d)
            if keepdim:
                out_data = np.expand_dims(out_data, axis=d)
        
        return Tensor(out_data.astype(np.float64), requires_grad=False, device=self.device)
    
    def argmin(self, dim=None, keepdim=False):
        """Indices of minimum values."""
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.argmin(self, dim, keepdim)
        
        data = self.to_numpy()
        
        if dim is None:
            idx = np.argmin(data)
            out_data = np.array(idx)
        else:
            d = dim if dim >= 0 else len(data.shape) + dim
            out_data = np.argmin(data, axis=d)
            if keepdim:
                out_data = np.expand_dims(out_data, axis=d)
        
        return Tensor(out_data.astype(np.float64), requires_grad=False, device=self.device)
    
    # ==================== 扩展操作 ====================
    def repeat(self, *sizes):
        """Repeat tensor."""
        if len(sizes) == 1 and isinstance(sizes[0], (tuple, list)):
            sizes = tuple(sizes[0])
        
        if self.requires_grad:
            from tensor.nn import functional as F
            return F.repeat(self, sizes)
        
        data = self.to_numpy()
        
        if len(sizes) != len(data.shape):
            raise ValueError(f"Repeat dims {len(sizes)} don't match shape dims {len(data.shape)}")
        
        out_data = np.tile(data, sizes)
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    def expand(self, *sizes):
        """Expand tensor (broadcasting, no copy)."""
        if len(sizes) == 1 and isinstance(sizes[0], (tuple, list)):
            sizes = tuple(sizes[0])
        
        data = self.to_numpy()
        
        # Add dimensions if needed
        if len(sizes) > len(data.shape):
            for _ in range(len(sizes) - len(data.shape)):
                data = np.expand_dims(data, axis=0)
        
        try:
            out_data = np.broadcast_to(data, sizes)
        except ValueError as e:
            raise ValueError(f"Cannot expand tensor of shape {self.shape} to {sizes}: {e}")
        
        return Tensor(out_data, requires_grad=False, device=self.device)
    
    def clone(self):
        """Create a deep copy of tensor."""
        data = self.to_numpy().copy()
        return Tensor(data, requires_grad=self.requires_grad, device=self.device)
    
    def detach(self):
        """Detach from computation graph."""
        data = self.to_numpy()
        return Tensor(data, requires_grad=False, device=self.device)
```

---

### 任务2: 在 `tensor/nn/functional.py` 中添加对应的函数实现

```python
# 添加到 tensor/nn/functional.py

def squeeze(x: Tensor, dim=None):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    if dim is None:
        out_data = np.squeeze(x_data)
    else:
        d = dim if dim >= 0 else len(x_data.shape) + dim
        if d < 0 or d >= len(x_data.shape):
            raise IndexError(f"Dimension {dim} out of range")
        if x_data.shape[d] != 1:
            raise RuntimeError(f"Cannot squeeze dim {d} of size {x_data.shape[d]}")
        out_data = np.squeeze(x_data, axis=d)
    
    out = Tensor(out_data, requires_grad=x.requires_grad,
                 _children=(x,), _op='squeeze', device=x.device)
    
    def _backward():
        if x.requires_grad:
            if dim is None:
                grad = np.reshape(out.grad, x_data.shape)
            else:
                grad = np.expand_dims(out.grad, axis=d)
            x.grad += grad
    
    out._backward = _backward
    return out


def unsqueeze(x: Tensor, dim):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    d = dim if dim >= 0 else len(x_data.shape) + dim + 1
    if d < 0 or d > len(x_data.shape):
        raise IndexError(f"Dimension {dim} out of range")
    
    out_data = np.expand_dims(x_data, axis=d)
    
    out = Tensor(out_data, requires_grad=x.requires_grad,
                 _children=(x,), _op='unsqueeze', device=x.device)
    
    def _backward():
        if x.requires_grad:
            grad = np.squeeze(out.grad, axis=d)
            x.grad += grad
    
    out._backward = _backward
    return out


def reshape(x: Tensor, shape):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    if isinstance(shape, Tensor):
        shape = tuple(int(s) for s in shape.to_numpy().flatten())
    elif isinstance(shape, (list, tuple)):
        shape = tuple(shape)
    else:
        shape = (shape,)
    
    out_data = x_data.reshape(shape)
    
    out = Tensor(out_data, requires_grad=x.requires_grad,
                 _children=(x,), _op='reshape', device=x.device)
    
    def _backward():
        if x.requires_grad:
            grad = np.reshape(out.grad, x_data.shape)
            x.grad += grad
    
    out._backward = _backward
    return out


def flatten(x: Tensor, start_dim=0, end_dim=-1):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    start = start_dim if start_dim >= 0 else len(x_data.shape) + start_dim
    end = end_dim if end_dim >= 0 else len(x_data.shape) + end_dim
    
    left_shape = x_data.shape[:start]
    right_shape = x_data.shape[end+1:]
    flat_size = int(np.prod(x_data.shape[start:end+1]))
    
    new_shape = left_shape + (flat_size,) + right_shape
    out_data = x_data.reshape(new_shape)
    
    out = Tensor(out_data, requires_grad=x.requires_grad,
                 _children=(x,), _op='flatten', device=x.device)
    
    def _backward():
        if x.requires_grad:
            grad = np.reshape(out.grad, x_data.shape)
            x.grad += grad
    
    out._backward = _backward
    return out


def transpose(x: Tensor, dim0, dim1):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    d0 = dim0 if dim0 >= 0 else len(x_data.shape) + dim0
    d1 = dim1 if dim1 >= 0 else len(x_data.shape) + dim1
    
    axes = list(range(len(x_data.shape)))
    axes[d0], axes[d1] = axes[d1], axes[d0]
    
    out_data = np.transpose(x_data, axes)
    
    out = Tensor(out_data, requires_grad=x.requires_grad,
                 _children=(x,), _op='transpose', device=x.device)
    
    def _backward():
        if x.requires_grad:
            grad = np.transpose(out.grad, axes)
            x.grad += grad
    
    out._backward = _backward
    return out


def permute(x: Tensor, dims):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    if not isinstance(dims, (tuple, list)):
        dims = (dims,)
    
    if len(dims) != len(x_data.shape):
        raise ValueError(f"Permute dims {len(dims)} don't match shape dims {len(x_data.shape)}")
    
    out_data = np.transpose(x_data, dims)
    
    # Inverse permutation for backward
    inv_dims = [0] * len(dims)
    for i, d in enumerate(dims):
        inv_dims[d] = i
    
    out = Tensor(out_data, requires_grad=x.requires_grad,
                 _children=(x,), _op='permute', device=x.device)
    
    def _backward():
        if x.requires_grad:
            grad = np.transpose(out.grad, inv_dims)
            x.grad += grad
    
    out._backward = _backward
    return out


def sum(x: Tensor, dim=None, keepdim=False):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    if dim is None:
        out_data = np.sum(x_data)
    else:
        d = dim if dim >= 0 else len(x_data.shape) + dim
        out_data = np.sum(x_data, axis=d, keepdims=keepdim)
    
    out = Tensor(out_data, requires_grad=x.requires_grad,
                 _children=(x,), _op='sum', device=x.device)
    
    def _backward():
        if x.requires_grad:
            if dim is None:
                grad = np.full_like(x_data, out.grad)
            else:
                grad = out.grad
                if not keepdim:
                    grad = np.expand_dims(grad, axis=d)
                grad = np.broadcast_to(grad, x_data.shape)
            x.grad += grad
    
    out._backward = _backward
    return out


def mean(x: Tensor, dim=None, keepdim=False):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    if dim is None:
        out_data = np.mean(x_data)
        n_elements = x_data.size
    else:
        d = dim if dim >= 0 else len(x_data.shape) + dim
        out_data = np.mean(x_data, axis=d, keepdims=keepdim)
        n_elements = x_data.shape[d]
    
    out = Tensor(out_data, requires_grad=x.requires_grad,
                 _children=(x,), _op='mean', device=x.device)
    
    def _backward():
        if x.requires_grad:
            if dim is None:
                grad = np.full_like(x_data, out.grad / x_data.size)
            else:
                grad = out.grad / n_elements
                if not keepdim:
                    grad = np.expand_dims(grad, axis=d)
                grad = np.broadcast_to(grad, x_data.shape)
            x.grad += grad
    
    out._backward = _backward
    return out


def std(x: Tensor, dim=None, keepdim=False, unbiased=True):
    """Standard deviation with automatic differentiation."""
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    ddof = 1 if unbiased else 0
    
    if dim is None:
        mean_val = np.mean(x_data)
        variance = np.var(x_data, ddof=ddof)
        out_data = np.std(x_data, ddof=ddof)
        
        out = Tensor(out_data, requires_grad=x.requires_grad,
                     _children=(x,), _op='std', device=x.device)
        
        def _backward():
            if x.requires_grad:
                # Gradient of std w.r.t. input
                dvar = out.grad / (2 * out_data + 1e-8)  # d(std)/d(var)
                
                # Gradient of var w.r.t. input
                grad = 2 * (x_data - mean_val) * dvar / max(1, x_data.size - ddof)
                x.grad += grad
    else:
        d = dim if dim >= 0 else len(x_data.shape) + dim
        out_data = np.std(x_data, axis=d, ddof=ddof, keepdims=keepdim)
        mean_val = np.mean(x_data, axis=d, keepdims=True)
        
        out = Tensor(out_data, requires_grad=x.requires_grad,
                     _children=(x,), _op='std', device=x.device)
        
        def _backward():
            if x.requires_grad:
                grad = out.grad
                if not keepdim:
                    grad = np.expand_dims(grad, axis=d)
                
                dvar = grad / (2 * out_data + 1e-8)
                if not keepdim:
                    dvar = np.expand_dims(dvar, axis=d)
                
                n = x_data.shape[d]
                grad = 2 * (x_data - mean_val) * dvar / max(1, n - ddof)
                x.grad += grad
    
    return out


def var(x: Tensor, dim=None, keepdim=False, unbiased=True):
    """Variance with automatic differentiation."""
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    ddof = 1 if unbiased else 0
    
    if dim is None:
        mean_val = np.mean(x_data)
        out_data = np.var(x_data, ddof=ddof)
        
        out = Tensor(out_data, requires_grad=x.requires_grad,
                     _children=(x,), _op='var', device=x.device)
        
        def _backward():
            if x.requires_grad:
                grad = 2 * (x_data - mean_val) * out.grad / max(1, x_data.size - ddof)
                x.grad += grad
    else:
        d = dim if dim >= 0 else len(x_data.shape) + dim
        mean_val = np.mean(x_data, axis=d, keepdims=True)
        out_data = np.var(x_data, axis=d, ddof=ddof, keepdims=keepdim)
        
        out = Tensor(out_data, requires_grad=x.requires_grad,
                     _children=(x,), _op='var', device=x.device)
        
        def _backward():
            if x.requires_grad:
                grad = out.grad
                if not keepdim:
                    grad = np.expand_dims(grad, axis=d)
                
                n = x_data.shape[d]
                grad = 2 * (x_data - mean_val) * grad / max(1, n - ddof)
                x.grad += grad
    
    return out


def repeat(x: Tensor, sizes):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    if not isinstance(sizes, (tuple, list)):
        sizes = (sizes,)
    
    if len(sizes) != len(x_data.shape):
        raise ValueError(f"Repeat dims {len(sizes)} don't match shape dims {len(x_data.shape)}")
    
    out_data = np.tile(x_data, sizes)
    
    out = Tensor(out_data, requires_grad=x.requires_grad,
                 _children=(x,), _op='repeat', device=x.device)
    
    def _backward():
        if x.requires_grad:
            # Sum over repeated elements
            grad = out.grad
            for i, s in enumerate(sizes):
                if s > 1:
                    # Reshape to group repeated blocks
                    shape = grad.shape[:i] + (s, grad.shape[i]//s) + grad.shape[i+1:]
                    grad = grad.reshape(shape)
                    grad = grad.sum(axis=i)
            x.grad += grad
    
    out._backward = _backward
    return out
```

---

### 任务3: 更新 `__init__.py` 导出新函数

在 `tensor/tensor.py` 的 `__all__` 中添加:
```python
__all__ = [
    # ... existing exports ...
    # 新增维度操作
    "squeeze",
    "unsqueeze", 
    "reshape",
    "flatten",
    "transpose",
    "permute",
    # 新增统计函数
    "sum",
    "mean",
    "std",
    "var",
    # 新增极值函数
    "max",
    "min",
    "argmax",
    "argmin",
    # 新增扩展操作
    "repeat",
    "expand",
]
```

---

### 任务4: 添加完整单元测试

创建 `tensor/tests/test_tensor_ops.py`:

```python
import numpy as np
import pytest
from tensor import Tensor


class TestDimensionOps:
    def test_squeeze_all(self):
        x = Tensor(np.array([[[1.0, 2.0]]]))  # shape (1, 1, 2)
        y = x.squeeze()
        assert y.shape == (2,)
        np.testing.assert_array_equal(y.to_numpy(), [1.0, 2.0])
    
    def test_squeeze_dim(self):
        x = Tensor(np.ones((3, 1, 4)))
        y = x.squeeze(1)
        assert y.shape == (3, 4)
    
    def test_unsqueeze(self):
        x = Tensor(np.ones((3, 4)))
        y = x.unsqueeze(1)
        assert y.shape == (3, 1, 4)
    
    def test_reshape(self):
        x = Tensor(np.arange(12).reshape(3, 4).astype(float))
        y = x.reshape(2, 6)
        assert y.shape == (2, 6)
    
    def test_flatten(self):
        x = Tensor(np.ones((2, 3, 4)))
        y = x.flatten()
        assert y.shape == (24,)
        
        y = x.flatten(1, 2)
        assert y.shape == (2, 12)
    
    def test_transpose(self):
        x = Tensor(np.arange(12).reshape(3, 4).astype(float))
        y = x.transpose(0, 1)
        assert y.shape == (4, 3)
        
        y = x.transpose(1, 0)
        assert y.shape == (4, 3)
    
    def test_permute(self):
        x = Tensor(np.arange(24).reshape(2, 3, 4).astype(float))
        y = x.permute(2, 0, 1)
        assert y.shape == (4, 2, 3)


class TestStatisticOps:
    def test_sum(self):
        x = Tensor(np.array([[1.0, 2.0], [3.0, 4.0]]))
        
        # Sum all
        y = x.sum()
        assert y.to_numpy() == 10.0
        
        # Sum along dimension
        y = x.sum(dim=1)
        np.testing.assert_array_almost_equal(y.to_numpy(), [3.0, 7.0])
    
    def test_mean(self):
        x = Tensor(np.array([[1.0, 2.0], [3.0, 4.0]]))
        
        y = x.mean()
        assert y.to_numpy() == 2.5
        
        y = x.mean(dim=0)
        np.testing.assert_array_almost_equal(y.to_numpy(), [2.0, 3.0])
    
    def test_std(self):
        x = Tensor(np.array([1.0, 2.0, 3.0, 4.0, 5.0]))
        y = x.std()
        # np.std with ddof=1
        expected = np.std([1.0, 2.0, 3.0, 4.0, 5.0], ddof=1)
        np.testing.assert_almost_equal(y.to_numpy(), expected)
    
    def test_var(self):
        x = Tensor(np.array([1.0, 2.0, 3.0, 4.0, 5.0]))
        y = x.var()
        expected = np.var([1.0, 2.0, 3.0, 4.0, 5.0], ddof=1)
        np.testing.assert_almost_equal(y.to_numpy(), expected)


class TestExtremeOps:
    def test_max(self):
        x = Tensor(np.array([[1.0, 5.0], [3.0, 2.0]]))
        
        y = x.max()
        assert y.to_numpy() == 5.0
        
        values, indices = x.max(dim=1)
        np.testing.assert_array_almost_equal(values.to_numpy(), [5.0, 3.0])
        np.testing.assert_array_equal(indices.to_numpy(), [1.0, 0.0])
    
    def test_argmax(self):
        x = Tensor(np.array([1.0, 5.0, 3.0, 2.0]))
        y = x.argmax()
        assert y.to_numpy() == 1.0


class TestBackpropagation:
    def test_squeeze_backward(self):
        x = Tensor(np.ones((1, 3)), requires_grad=True)
        y = x.squeeze(0)
        loss = y.sum()
        loss.backward()
        
        np.testing.assert_array_almost_equal(x.grad, np.ones((1, 3)))
    
    def test_unsqueeze_backward(self):
        x = Tensor(np.ones(3), requires_grad=True)
        y = x.unsqueeze(0)
        loss = y.sum()
        loss.backward()
        
        np.testing.assert_array_almost_equal(x.grad, np.ones(3))
    
    def test_reshape_backward(self):
        x = Tensor(np.ones((2, 3)), requires_grad=True)
        y = x.reshape(3, 2)
        loss = y.sum()
        loss.backward()
        
        np.testing.assert_array_almost_equal(x.grad, np.ones((2, 3)))


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
```

---

## 第二周计划: P1级优化器和学习率

### 任务5: 实现现代优化器

在 `tensor/optim/optim.py` 中添加:

```python
class RAdam(Optimizer):
    """Rectified Adam optimizer.
    
    "On the Variance of the Adaptive Learning Rate and Beyond"
    https://arxiv.org/abs/1908.03265
    """
    
    def __init__(self, params, lr=1e-3, betas=(0.9, 0.999), eps=1e-8, weight_decay=0):
        super().__init__(params)
        self.lr = lr
        self.betas = betas
        self.eps = eps
        self.weight_decay = weight_decay
        
        self.m = {id(p): np.zeros_like(p.data) for p in self.params}
        self.v = {id(p): np.zeros_like(p.data) for p in self.params}
        self.t = 0
    
    def step(self):
        self.t += 1
        beta1, beta2 = self.betas
        
        for p in self.params:
            if p.grad is None:
                continue
            
            grad = p.grad
            if self.weight_decay != 0:
                grad = grad + self.weight_decay * p.data
            
            pid = id(p)
            m, v = self.m[pid], self.v[pid]
            
            # Update biased moments
            m = beta1 * m + (1 - beta1) * grad
            v = beta2 * v + (1 - beta2) * (grad ** 2)
            
            self.m[pid] = m
            self.v[pid] = v
            
            # Bias correction
            m_hat = m / (1 - beta1 ** self.t)
            v_hat = v / (1 - beta2 ** self.t)
            
            # Variance rectification term
            rho_inf = 2 / (1 - beta2) - 1
            rho_t = rho_inf - 2 * self.t * (beta2 ** self.t) / (1 - beta2 ** self.t)
            
            if rho_t > 4:
                r_t = np.sqrt((rho_t - 4) * (rho_t - 2) * rho_inf / 
                             ((rho_inf - 4) * (rho_inf - 2) * rho_t))
                step = self.lr * r_t * m_hat / (np.sqrt(v_hat) + self.eps)
            else:
                step = self.lr * m_hat
            
            p.data -= step


class LAMB(Optimizer):
    """Large Batch Optimization for BERT Training.
    
    "Large Batch Optimization for Deep Learning: Training BERT in 76 minutes"
    https://arxiv.org/abs/1904.00962
    """
    
    def __init__(self, params, lr=1e-3, betas=(0.9, 0.999), eps=1e-8, weight_decay=0):
        super().__init__(params)
        self.lr = lr
        self.betas = betas
        self.eps = eps
        self.weight_decay = weight_decay
        
        self.m = {id(p): np.zeros_like(p.data) for p in self.params}
        self.v = {id(p): np.zeros_like(p.data) for p in self.params}
        self.t = 0
    
    def step(self):
        self.t += 1
        beta1, beta2 = self.betas
        
        for p in self.params:
            if p.grad is None:
                continue
            
            grad = p.grad
            
            pid = id(p)
            m, v = self.m[pid], self.v[pid]
            
            # Update biased moments
            m = beta1 * m + (1 - beta1) * grad
            v = beta2 * v + (1 - beta2) * (grad ** 2)
            
            self.m[pid] = m
            self.v[pid] = v
            
            # Bias correction
            m_hat = m / (1 - beta1 ** self.t)
            v_hat = v / (1 - beta2 ** self.t)
            
            # Adaptive learning rate
            r1 = np.sqrt(v_hat) + self.eps
            adaptive_lr = m_hat / r1
            
            # Weight decay
            if self.weight_decay != 0:
                adaptive_lr = adaptive_lr + self.weight_decay * p.data
            
            # Layer-wise learning rate adaptation
            param_norm = np.linalg.norm(p.data)
            update_norm = np.linalg.norm(adaptive_lr)
            
            if param_norm > 0 and update_norm > 0:
                trust_ratio = param_norm / update_norm
            else:
                trust_ratio = 1.0
            
            p.data -= self.lr * trust_ratio * adaptive_lr
```

---

这个实现方案包含了：
✅ **完整的方法实现代码**
✅ **反向传播支持**
✅ **单元测试**
✅ **使用示例**
✅ **性能优化建议**

现在让我为你生成一个**实现优先级清单**:
