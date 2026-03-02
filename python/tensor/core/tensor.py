import os
import numpy as np

try:
    from tensor.cuda import ops as _cuda_ops
except Exception:
    _cuda_ops = None


def _ensure_array(value, dtype=None):
    if isinstance(value, np.ndarray):
        return value if dtype is None else value.astype(dtype, copy=False)
    return np.array(value, dtype=dtype or np.float64)


def _is_cuda_device(data):
    return _cuda_ops is not None and isinstance(data, _cuda_ops.DeviceArray)


def _shape_of(data):
    return data.shape if _is_cuda_device(data) else data.shape


def _to_numpy(data):
    if _is_cuda_device(data):
        return _cuda_ops.to_host(data)
    return data


def _unbroadcast(grad, shape):
    while len(grad.shape) > len(shape):
        grad = grad.sum(axis=0)
    for axis, (gdim, sdim) in enumerate(zip(grad.shape, shape)):
        if sdim == 1 and gdim != 1:
            grad = grad.sum(axis=axis, keepdims=True)
    return grad


class Tensor:
    def __init__(self, data, requires_grad=False, _children=(), _op="", device=None):
        if device is None:
            if os.environ.get("TENSOR_DEVICE", "cpu").lower() == "cuda":
                device = "cuda"
            else:
                device = "cuda" if _is_cuda_device(data) else "cpu"
        self.device = device

        if self.device == "cuda":
            if _cuda_ops is None:
                raise RuntimeError("CUDA backend not available")
            if _is_cuda_device(data):
                self.data = data
            else:
                arr = _ensure_array(data, dtype=np.float32)
                self.data = _cuda_ops.to_device(arr)
        else:
            self.data = _ensure_array(data)

        self.requires_grad = requires_grad
        if requires_grad:
            if self.device == "cuda":
                self.grad = np.zeros(_shape_of(self.data), dtype=np.float32)
            else:
                self.grad = np.zeros_like(self.data, dtype=np.float64)
        else:
            self.grad = None
        self._backward = lambda: None
        self._prev = set(_children)
        self._op = _op

    @property
    def shape(self):
        return _shape_of(self.data)

    @property
    def ndim(self):
        return len(self.shape)

    def size(self, dim=None):
        if dim is None:
            return self.shape
        return self.shape[dim]

    def numel(self):
        n = 1
        for d in self.shape:
            n *= d
        return n

    @property
    def dtype(self):
        return _to_numpy(self.data).dtype

    def zero_grad(self):
        if self.requires_grad:
            if self.device == "cuda":
                self.grad = np.zeros(self.shape, dtype=np.float32)
            else:
                self.grad = np.zeros_like(self.data, dtype=np.float64)

    def __add__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        if self.device == "cuda" or other.device == "cuda":
            if self.shape == other.shape:
                out_data = _cuda_ops.add(_as_device(self), _as_device(other))
                out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "+", device="cuda")
            elif len(self.shape) == 2 and len(other.shape) == 1:
                out_data = _cuda_ops.add_bias(_as_device(self), _as_device(other))
                out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "+", device="cuda")
            elif len(self.shape) == 1 and len(other.shape) == 2:
                out_data = _cuda_ops.add_bias(_as_device(other), _as_device(self))
                out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "+", device="cuda")
            elif len(self.shape) == 3 and len(other.shape) == 1:
                out_data = _cuda_ops.add_bias_3d(_as_device(self), _as_device(other))
                out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "+", device="cuda")
            elif len(self.shape) == 1 and len(other.shape) == 3:
                out_data = _cuda_ops.add_bias_3d(_as_device(other), _as_device(self))
                out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "+", device="cuda")
            else:
                host = _to_numpy(self.data) + _to_numpy(other.data)
                out = Tensor(host, self.requires_grad or other.requires_grad, (self, other), "+", device="cuda")
        else:
            out = Tensor(self.data + other.data, self.requires_grad or other.requires_grad, (self, other), "+")

        def _backward():
            if self.requires_grad:
                self.grad += _unbroadcast(out.grad, self.shape)
            if other.requires_grad:
                other.grad += _unbroadcast(out.grad, other.shape)

        out._backward = _backward
        return out

    def __radd__(self, other):
        return self + other

    def __sub__(self, other):
        return self + (-other)

    def __rsub__(self, other):
        return other + (-self)

    def __neg__(self):
        out = Tensor(-self.data, self.requires_grad, (self,), "neg")

        def _backward():
            if self.requires_grad:
                self.grad -= out.grad

        out._backward = _backward
        return out

    def __mul__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        if self.device == "cuda" or other.device == "cuda":
            out_data = _cuda_ops.mul(_as_device(self), _as_device(other))
            out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "*", device="cuda")
        else:
            out = Tensor(self.data * other.data, self.requires_grad or other.requires_grad, (self, other), "*")

        def _backward():
            if self.requires_grad:
                self.grad += _unbroadcast(_to_numpy(other.data) * out.grad, self.shape)
            if other.requires_grad:
                other.grad += _unbroadcast(_to_numpy(self.data) * out.grad, other.shape)

        out._backward = _backward
        return out

    def __rmul__(self, other):
        return self * other

    def __matmul__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        if self.device == "cuda" or other.device == "cuda":
            if len(self.shape) == 2 and len(other.shape) == 2:
                out_data = _cuda_ops.matmul(_as_device(self), _as_device(other))
                out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "matmul", device="cuda")
            else:
                out = Tensor(_to_numpy(self.data) @ _to_numpy(other.data), self.requires_grad or other.requires_grad, (self, other), "matmul")
        else:
            out = Tensor(self.data @ other.data, self.requires_grad or other.requires_grad, (self, other), "matmul")

        def _backward():
            if self.requires_grad:
                grad_self = out.grad @ np.swapaxes(_to_numpy(other.data), -1, -2)
                self.grad += _unbroadcast(grad_self, self.shape)
            if other.requires_grad:
                grad_other = np.swapaxes(_to_numpy(self.data), -1, -2) @ out.grad
                other.grad += _unbroadcast(grad_other, other.shape)

        out._backward = _backward
        return out

    def reshape(self, *shape):
        if self.device == "cuda":
            host = _to_numpy(self.data).reshape(*shape)
            out = Tensor(_cuda_ops.to_device(host.astype(np.float32, copy=False)), self.requires_grad, (self,), "reshape", device="cuda")
        else:
            out = Tensor(self.data.reshape(*shape), self.requires_grad, (self,), "reshape")

        def _backward():
            if self.requires_grad:
                self.grad += out.grad.reshape(self.data.shape)

        out._backward = _backward
        return out

    def view(self, *shape):
        return self.reshape(*shape)

    def flatten(self, start_dim=0, end_dim=-1):
        shape = list(self.shape)
        if end_dim < 0:
            end_dim += len(shape)
        if start_dim < 0:
            start_dim += len(shape)
        if start_dim > end_dim:
            raise ValueError("start_dim must be <= end_dim")
        new_dim = 1
        for d in shape[start_dim:end_dim + 1]:
            new_dim *= d
        new_shape = shape[:start_dim] + [new_dim] + shape[end_dim + 1:]
        return self.reshape(*new_shape)

    def transpose(self, dim0, dim1):
        host = _to_numpy(self.data)
        axes = list(range(host.ndim))
        axes[dim0], axes[dim1] = axes[dim1], axes[dim0]
        if self.device == "cuda":
            out_data = _cuda_ops.to_device(host.transpose(axes).astype(np.float32, copy=False))
            out = Tensor(out_data, self.requires_grad, (self,), "transpose", device="cuda")
        else:
            out = Tensor(host.transpose(axes), self.requires_grad, (self,), "transpose")

        def _backward():
            if self.requires_grad:
                inv_axes = np.argsort(axes)
                self.grad += out.grad.transpose(inv_axes)

        out._backward = _backward
        return out

    def permute(self, *dims):
        host = _to_numpy(self.data)
        if len(dims) != host.ndim:
            raise ValueError("permute dims must match tensor ndim")
        if self.device == "cuda":
            out_data = _cuda_ops.to_device(host.transpose(dims).astype(np.float32, copy=False))
            out = Tensor(out_data, self.requires_grad, (self,), "permute", device="cuda")
        else:
            out = Tensor(host.transpose(dims), self.requires_grad, (self,), "permute")

        def _backward():
            if self.requires_grad:
                inv_axes = np.argsort(dims)
                self.grad += out.grad.transpose(inv_axes)

        out._backward = _backward
        return out

    def mean(self, axis=None, keepdims=False, dim=None):
        if dim is not None:
            axis = dim
        host = _to_numpy(self.data)
        denom = host.size
        if self.device == "cuda" and _cuda_ops is not None and axis is None and not keepdims:
            try:
                out_data = _cuda_ops.reduce_mean(self.data, axis=None, keepdims=False)
                out = Tensor(out_data, self.requires_grad, (self,), "mean", device="cuda")
            except Exception:
                out = None
        else:
            out = None

        if out is None:
            out = Tensor(np.array(host.mean(axis=axis, keepdims=keepdims)), self.requires_grad, (self,), "mean", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = out.grad
                if axis is not None and not keepdims:
                    axes = axis if isinstance(axis, tuple) else (axis,)
                    axes = tuple(a if a >= 0 else a + host.ndim for a in axes)
                    for ax in sorted(axes):
                        grad = np.expand_dims(grad, axis=ax)
                if axis is None:
                    denom = host.size
                else:
                    axes = axis if isinstance(axis, tuple) else (axis,)
                    axes = tuple(a if a >= 0 else a + host.ndim for a in axes)
                    denom = 1
                    for ax in axes:
                        denom *= host.shape[ax]
                scale = 1.0 / denom
                self.grad += (np.ones_like(host) * scale) * grad

        out._backward = _backward
        return out

    def sum(self, axis=None, keepdims=False, dim=None):
        if dim is not None:
            axis = dim
        host = _to_numpy(self.data)
        if self.device == "cuda" and _cuda_ops is not None and axis is None and not keepdims:
            try:
                out_data = _cuda_ops.reduce_sum(self.data, axis=axis, keepdims=keepdims)
                out = Tensor(out_data, self.requires_grad, (self,), "sum", device="cuda")
            except Exception:
                out = None
        else:
            out = None

        if out is None:
            out_data = host.sum(axis=axis, keepdims=keepdims)
            out = Tensor(out_data, self.requires_grad, (self,), "sum", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = out.grad
                if axis is not None and not keepdims:
                    axes = axis if isinstance(axis, tuple) else (axis,)
                    axes = tuple(a if a >= 0 else a + host.ndim for a in axes)
                    for ax in sorted(axes):
                        grad = np.expand_dims(grad, axis=ax)
                self.grad += np.ones_like(host) * grad

        out._backward = _backward
        return out

    def max(self, axis=None, keepdims=False, dim=None):
        if dim is not None:
            axis = dim
        host = _to_numpy(self.data)
        if self.device == "cuda" and _cuda_ops is not None and axis is None and not keepdims:
            try:
                out_data = _cuda_ops.reduce_max(self.data, axis=axis, keepdims=keepdims)
                out = Tensor(out_data, self.requires_grad, (self,), "max", device="cuda")
            except Exception:
                out = None
        else:
            out = None

        if out is None:
            out_data = host.max(axis=axis, keepdims=keepdims)
            out = Tensor(out_data, self.requires_grad, (self,), "max", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = out.grad
                expanded = out_data
                if axis is not None and not keepdims:
                    axes = axis if isinstance(axis, tuple) else (axis,)
                    axes = tuple(a if a >= 0 else a + host.ndim for a in axes)
                    for ax in sorted(axes):
                        grad = np.expand_dims(grad, axis=ax)
                        expanded = np.expand_dims(expanded, axis=ax)
                mask = host == expanded
                count = mask.sum(axis=axis, keepdims=True) if axis is not None else mask.sum()
                count = np.maximum(count, 1)
                self.grad += mask * (grad / count)

        out._backward = _backward
        return out

    def min(self, axis=None, keepdims=False, dim=None):
        if dim is not None:
            axis = dim
        host = _to_numpy(self.data)
        if self.device == "cuda" and _cuda_ops is not None and axis is None and not keepdims:
            try:
                out_data = _cuda_ops.reduce_min(self.data, axis=axis, keepdims=keepdims)
                out = Tensor(out_data, self.requires_grad, (self,), "min", device="cuda")
            except Exception:
                out = None
        else:
            out = None

        if out is None:
            out_data = host.min(axis=axis, keepdims=keepdims)
            out = Tensor(out_data, self.requires_grad, (self,), "min", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = out.grad
                expanded = out_data
                if axis is not None and not keepdims:
                    axes = axis if isinstance(axis, tuple) else (axis,)
                    axes = tuple(a if a >= 0 else a + host.ndim for a in axes)
                    for ax in sorted(axes):
                        grad = np.expand_dims(grad, axis=ax)
                        expanded = np.expand_dims(expanded, axis=ax)
                mask = host == expanded
                count = mask.sum(axis=axis, keepdims=True) if axis is not None else mask.sum()
                count = np.maximum(count, 1)
                self.grad += mask * (grad / count)

        out._backward = _backward
        return out

    def backward(self):
        if self.data.size != 1:
            raise ValueError("backward() requires scalar Tensor")

        topo = []
        visited = set()

        def build(v):
            if v not in visited:
                visited.add(v)
                for child in v._prev:
                    build(child)
                topo.append(v)

        build(self)

        if self.device == "cuda":
            self.grad = np.ones(self.shape, dtype=np.float32)
        else:
            self.grad = np.ones_like(self.data, dtype=np.float64)
        for node in reversed(topo):
            node._backward()

    def item(self):
        if self.device == "cuda":
            return float(_to_numpy(self.data).item())
        return float(self.data.item())

    def to_numpy(self):
        return _to_numpy(self.data)

    def numpy(self):
        return self.to_numpy()

    def detach(self):
        return Tensor(self.to_numpy().copy(), requires_grad=False, device=self.device)

    def clone(self):
        return Tensor(self.to_numpy().copy(), requires_grad=self.requires_grad, device=self.device)

    def contiguous(self):
        return self

    def to(self, device=None, dtype=None):
        target_device = device or self.device
        arr = self.to_numpy()
        if dtype is not None:
            arr = arr.astype(dtype, copy=False)
        out = Tensor(arr, requires_grad=self.requires_grad, _children=(self,), _op="to", device=target_device)

        def _backward():
            if self.requires_grad:
                grad = out.grad
                if self.device == "cuda":
                    grad = grad.astype(np.float32, copy=False)
                self.grad += _unbroadcast(grad, self.shape)

        out._backward = _backward
        return out


def _as_device(t: "Tensor"):
    if _is_cuda_device(t.data):
        return t.data
    arr = _ensure_array(t.data, dtype=np.float32)
    return _cuda_ops.to_device(arr)
