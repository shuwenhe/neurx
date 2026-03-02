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

    def zero_grad(self):
        if self.requires_grad:
            if self.device == "cuda":
                self.grad = np.zeros(self.shape, dtype=np.float32)
            else:
                self.grad = np.zeros_like(self.data, dtype=np.float64)

    def __add__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        if self.device == "cuda" or other.device == "cuda":
            try:
                out_data = _cuda_ops.add(_as_device(self), _as_device(other))
                out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "+", device="cuda")
            except Exception:
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

    def mean(self):
        host = _to_numpy(self.data)
        denom = host.size
        out = Tensor(np.array(host.mean()), self.requires_grad, (self,), "mean")

        def _backward():
            if self.requires_grad:
                self.grad += (np.ones_like(self.data) / denom) * out.grad

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


def _as_device(t: "Tensor"):
    if _is_cuda_device(t.data):
        return t.data
    arr = _ensure_array(t.data, dtype=np.float32)
    return _cuda_ops.to_device(arr)
