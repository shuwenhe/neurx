import numpy as np
from contextlib import ContextDecorator

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


def _to_data_on_device(arr, device):
    if device == "cuda":
        return _cuda_ops.to_device(arr.astype(np.float32, copy=False))
    return arr


def _unbroadcast(grad, shape):
    while len(grad.shape) > len(shape):
        grad = grad.sum(axis=0)
    for axis, (gdim, sdim) in enumerate(zip(grad.shape, shape)):
        if sdim == 1 and gdim != 1:
            grad = grad.sum(axis=axis, keepdims=True)
    return grad


def _normalize_axis(axis, ndim):
    if axis is None:
        return None
    if isinstance(axis, tuple):
        out = []
        for a in axis:
            out.append(a + ndim if a < 0 else a)
        return tuple(out)
    return axis + ndim if axis < 0 else axis


def _resolve_default_device(data):
    if _is_cuda_device(data):
        return "cuda"
    try:
        from tensor.platform import get_runtime_config

        return get_runtime_config().default_device
    except Exception:
        return "cpu"


def _should_fallback_cuda_to_cpu():
    try:
        from tensor.platform import get_runtime_config

        return get_runtime_config().fallback_to_cpu
    except Exception:
        return True


_GRAD_ENABLED = True


def is_grad_enabled():
    return _GRAD_ENABLED


class _GradMode(ContextDecorator):
    def __init__(self, mode: bool):
        self.mode = bool(mode)
        self.prev = None

    def __enter__(self):
        global _GRAD_ENABLED
        self.prev = _GRAD_ENABLED
        _GRAD_ENABLED = self.mode
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        global _GRAD_ENABLED
        _GRAD_ENABLED = self.prev
        return False


def set_grad_enabled(mode: bool):
    return _GradMode(mode)


def no_grad():
    return _GradMode(False)


def enable_grad():
    return _GradMode(True)


class Tensor:
    def __init__(self, data, requires_grad=False, _children=(), _op="", device=None):
        if device is None:
            device = _resolve_default_device(data)
        if device == "cuda" and _cuda_ops is None and _should_fallback_cuda_to_cpu():
            device = "cpu"
        self.device = device

        if self.device == "cuda":
            if _cuda_ops is None:
                try:
                    from tensor.platform import BackendNotAvailableError
                except Exception:
                    BackendNotAvailableError = RuntimeError
                raise BackendNotAvailableError(
                    "CUDA backend not available. "
                    "Set TENSOR_FALLBACK_TO_CPU=1 to auto-fallback or install CUDA extension."
                )
            if _is_cuda_device(data):
                self.data = data
                data_dtype = data.dtype
            else:
                arr = _ensure_array(data)
                if arr.dtype not in (np.float32, np.int32, np.int64):
                    arr = arr.astype(np.float32, copy=False)
                self.data = _cuda_ops.to_device(arr)
                data_dtype = arr.dtype
        else:
            arr = _ensure_array(data)
            self.data = arr
            data_dtype = arr.dtype

        effective_requires_grad = bool(requires_grad)
        if effective_requires_grad and len(_children) > 0 and not _GRAD_ENABLED:
            effective_requires_grad = False

        if effective_requires_grad and not np.issubdtype(np.dtype(data_dtype), np.floating):
            raise ValueError("only floating point tensors can require gradients")

        self.requires_grad = effective_requires_grad
        if self.requires_grad:
            if self.device == "cuda":
                self.grad = np.zeros(_shape_of(self.data), dtype=np.float32)
            else:
                self.grad = np.zeros_like(self.data, dtype=np.float64)
        else:
            self.grad = None
        self._backward = lambda: None
        if self.requires_grad:
            self._prev = {child for child in _children if getattr(child, "requires_grad", False)}
        else:
            self._prev = set()
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

    def __truediv__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        out_device = "cuda" if (self.device == "cuda" or other.device == "cuda") else "cpu"
        out_data = _to_numpy(self.data) / _to_numpy(other.data)
        out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "/", device=out_device)

        def _backward():
            if self.requires_grad:
                self.grad += _unbroadcast(out.grad / _to_numpy(other.data), self.shape)
            if other.requires_grad:
                other.grad += _unbroadcast((-out.grad * _to_numpy(self.data)) / (_to_numpy(other.data) ** 2), other.shape)

        out._backward = _backward
        return out

    def __rtruediv__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        return other / self

    def __pow__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        out_device = "cuda" if (self.device == "cuda" or other.device == "cuda") else "cpu"
        base = _to_numpy(self.data)
        exp = _to_numpy(other.data)
        out_data = base ** exp
        out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "pow", device=out_device)

        def _backward():
            if self.requires_grad:
                self.grad += _unbroadcast(out.grad * exp * (base ** (exp - 1.0)), self.shape)
            if other.requires_grad:
                safe_base = np.clip(base, 1e-12, None)
                other.grad += _unbroadcast(out.grad * out_data * np.log(safe_base), other.shape)

        out._backward = _backward
        return out

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

    def squeeze(self, dim=None):
        host = _to_numpy(self.data)
        if dim is None:
            out_data = np.squeeze(host)
        else:
            dim = dim + host.ndim if dim < 0 else dim
            out_data = np.squeeze(host, axis=dim)
        out = Tensor(out_data, self.requires_grad, (self,), "squeeze", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad.reshape(self.shape)

        out._backward = _backward
        return out

    def unsqueeze(self, dim):
        host = _to_numpy(self.data)
        dim = dim + host.ndim + 1 if dim < 0 else dim
        out = Tensor(np.expand_dims(host, axis=dim), self.requires_grad, (self,), "unsqueeze", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += np.squeeze(out.grad, axis=dim)

        out._backward = _backward
        return out

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

    def mean(self, axis=None, keepdims=False, dim=None, keepdim=None):
        if dim is not None:
            axis = dim
        if keepdim is not None:
            keepdims = keepdim
        axis = _normalize_axis(axis, self.ndim)
        if self.device == "cuda" and _cuda_ops is not None:
            try:
                out_data = _cuda_ops.reduce_mean(self.data, axis=axis, keepdims=keepdims)
                out = Tensor(out_data, self.requires_grad, (self,), "mean", device="cuda")
            except Exception:
                out = None
        else:
            out = None

        if out is None:
            host = _to_numpy(self.data)
            out = Tensor(np.array(host.mean(axis=axis, keepdims=keepdims)), self.requires_grad, (self,), "mean", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = out.grad
                if axis is not None and not keepdims:
                    axes = axis if isinstance(axis, tuple) else (axis,)
                    for ax in sorted(axes):
                        grad = np.expand_dims(grad, axis=ax)
                if axis is None:
                    denom = int(np.prod(self.shape))
                else:
                    axes = axis if isinstance(axis, tuple) else (axis,)
                    denom = 1
                    for ax in axes:
                        denom *= self.shape[ax]
                scale = 1.0 / denom
                self.grad += (np.ones(self.shape, dtype=self.grad.dtype) * scale) * grad

        out._backward = _backward
        return out

    def sum(self, axis=None, keepdims=False, dim=None, keepdim=None):
        if dim is not None:
            axis = dim
        if keepdim is not None:
            keepdims = keepdim
        axis = _normalize_axis(axis, self.ndim)
        if self.device == "cuda" and _cuda_ops is not None:
            try:
                out_data = _cuda_ops.reduce_sum(self.data, axis=axis, keepdims=keepdims)
                out = Tensor(out_data, self.requires_grad, (self,), "sum", device="cuda")
            except Exception:
                out = None
        else:
            out = None

        if out is None:
            host = _to_numpy(self.data)
            out_data = host.sum(axis=axis, keepdims=keepdims)
            out = Tensor(out_data, self.requires_grad, (self,), "sum", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = out.grad
                if axis is not None and not keepdims:
                    axes = axis if isinstance(axis, tuple) else (axis,)
                    for ax in sorted(axes):
                        grad = np.expand_dims(grad, axis=ax)
                self.grad += np.ones(self.shape, dtype=self.grad.dtype) * grad

        out._backward = _backward
        return out

    def max(self, axis=None, keepdims=False, dim=None, keepdim=None):
        if dim is not None:
            axis = dim
        if keepdim is not None:
            keepdims = keepdim
        axis = _normalize_axis(axis, self.ndim)
        if self.device == "cuda" and _cuda_ops is not None:
            try:
                out_data = _cuda_ops.reduce_max(self.data, axis=axis, keepdims=keepdims)
                out = Tensor(out_data, self.requires_grad, (self,), "max", device="cuda")
            except Exception:
                out = None
        else:
            out = None

        if out is None:
            host = _to_numpy(self.data)
            out_data = host.max(axis=axis, keepdims=keepdims)
            out = Tensor(out_data, self.requires_grad, (self,), "max", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = out.grad
                host = _to_numpy(self.data)
                expanded = _to_numpy(out.data)
                if axis is not None and not keepdims:
                    axes = axis if isinstance(axis, tuple) else (axis,)
                    for ax in sorted(axes):
                        grad = np.expand_dims(grad, axis=ax)
                        expanded = np.expand_dims(expanded, axis=ax)
                mask = host == expanded
                count = mask.sum(axis=axis, keepdims=True) if axis is not None else mask.sum()
                count = np.maximum(count, 1)
                self.grad += mask * (grad / count)

        out._backward = _backward
        if axis is not None:
            if self.device == "cuda" and _cuda_ops is not None:
                try:
                    idx = _cuda_ops.argmax(self.data, axis=axis)
                except Exception:
                    idx = np.asarray(_to_numpy(self.data).argmax(axis=axis), dtype=np.int64)
            else:
                idx = np.asarray(_to_numpy(self.data).argmax(axis=axis), dtype=np.int64)
            if _is_cuda_device(idx):
                return out, Tensor(idx, requires_grad=False, device="cuda")
            return out, Tensor(np.asarray(idx, dtype=np.int64), requires_grad=False, device=self.device)
        return out

    def min(self, axis=None, keepdims=False, dim=None, keepdim=None):
        if dim is not None:
            axis = dim
        if keepdim is not None:
            keepdims = keepdim
        axis = _normalize_axis(axis, self.ndim)
        if self.device == "cuda" and _cuda_ops is not None:
            try:
                out_data = _cuda_ops.reduce_min(self.data, axis=axis, keepdims=keepdims)
                out = Tensor(out_data, self.requires_grad, (self,), "min", device="cuda")
            except Exception:
                out = None
        else:
            out = None

        if out is None:
            host = _to_numpy(self.data)
            out_data = host.min(axis=axis, keepdims=keepdims)
            out = Tensor(out_data, self.requires_grad, (self,), "min", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = out.grad
                host = _to_numpy(self.data)
                expanded = _to_numpy(out.data)
                if axis is not None and not keepdims:
                    axes = axis if isinstance(axis, tuple) else (axis,)
                    for ax in sorted(axes):
                        grad = np.expand_dims(grad, axis=ax)
                        expanded = np.expand_dims(expanded, axis=ax)
                mask = host == expanded
                count = mask.sum(axis=axis, keepdims=True) if axis is not None else mask.sum()
                count = np.maximum(count, 1)
                self.grad += mask * (grad / count)

        out._backward = _backward
        if axis is not None:
            if self.device == "cuda" and _cuda_ops is not None:
                try:
                    idx = _cuda_ops.argmin(self.data, axis=axis)
                except Exception:
                    idx = np.asarray(_to_numpy(self.data).argmin(axis=axis), dtype=np.int64)
            else:
                idx = np.asarray(_to_numpy(self.data).argmin(axis=axis), dtype=np.int64)
            if _is_cuda_device(idx):
                return out, Tensor(idx, requires_grad=False, device="cuda")
            return out, Tensor(np.asarray(idx, dtype=np.int64), requires_grad=False, device=self.device)
        return out

    def argmax(self, axis=None, dim=None):
        if dim is not None:
            axis = dim
        axis = _normalize_axis(axis, self.ndim)
        if self.device == "cuda" and _cuda_ops is not None:
            try:
                idx = _cuda_ops.argmax(self.data, axis=axis)
            except Exception:
                idx = np.asarray(_to_numpy(self.data).argmax(axis=axis), dtype=np.int64)
        else:
            idx = np.asarray(_to_numpy(self.data).argmax(axis=axis), dtype=np.int64)
        if _is_cuda_device(idx):
            return Tensor(idx, requires_grad=False, device="cuda")
        return Tensor(np.asarray(idx, dtype=np.int64), requires_grad=False, device=self.device)

    def argmin(self, axis=None, dim=None):
        if dim is not None:
            axis = dim
        axis = _normalize_axis(axis, self.ndim)
        if self.device == "cuda" and _cuda_ops is not None:
            try:
                idx = _cuda_ops.argmin(self.data, axis=axis)
            except Exception:
                idx = np.asarray(_to_numpy(self.data).argmin(axis=axis), dtype=np.int64)
        else:
            idx = np.asarray(_to_numpy(self.data).argmin(axis=axis), dtype=np.int64)
        if _is_cuda_device(idx):
            return Tensor(idx, requires_grad=False, device="cuda")
        return Tensor(np.asarray(idx, dtype=np.int64), requires_grad=False, device=self.device)

    def std(self, axis=None, keepdims=False, dim=None, keepdim=None, correction=0):
        if dim is not None:
            axis = dim
        if keepdim is not None:
            keepdims = keepdim
        axis = _normalize_axis(axis, self.ndim)
        x = _to_numpy(self.data)
        out_data = np.std(x, axis=axis, keepdims=keepdims, ddof=correction)
        out = Tensor(out_data, self.requires_grad, (self,), "std", device=self.device)

        def _backward():
            if not self.requires_grad:
                return
            grad = out.grad
            axes = tuple(range(self.ndim)) if axis is None else (axis if isinstance(axis, tuple) else (axis,))
            n = 1
            for ax in axes:
                n *= self.shape[ax]
            denom = max(n - correction, 1)
            mean = x.mean(axis=axes, keepdims=True)
            std_keep = np.std(x, axis=axes, keepdims=True, ddof=correction)
            std_keep = np.maximum(std_keep, 1e-12)
            if not keepdims and axis is not None:
                for ax in sorted(axes):
                    grad = np.expand_dims(grad, axis=ax)
            self.grad += ((x - mean) / (denom * std_keep)) * grad

        out._backward = _backward
        return out

    def norm(self, p=2, axis=None, keepdims=False, dim=None, keepdim=None):
        if dim is not None:
            axis = dim
        if keepdim is not None:
            keepdims = keepdim
        axis = _normalize_axis(axis, self.ndim)
        x = _to_numpy(self.data)
        out_data = np.linalg.norm(x, ord=p, axis=axis, keepdims=keepdims)
        out = Tensor(out_data, self.requires_grad, (self,), "norm", device=self.device)

        def _backward():
            if not self.requires_grad:
                return
            grad = out.grad
            axes = tuple(range(self.ndim)) if axis is None else (axis if isinstance(axis, tuple) else (axis,))
            norm_keep = np.linalg.norm(x, ord=p, axis=axes, keepdims=True)
            norm_keep = np.maximum(norm_keep, 1e-12)
            if not keepdims and axis is not None:
                for ax in sorted(axes):
                    grad = np.expand_dims(grad, axis=ax)
            if p == 2:
                self.grad += (x / norm_keep) * grad
            else:
                self.grad += (np.sign(x) * (np.abs(x) ** (p - 1)) / (norm_keep ** (p - 1))) * grad

        out._backward = _backward
        return out

    def exp(self):
        x = _to_numpy(self.data)
        out_data = np.exp(x)
        out = Tensor(out_data, self.requires_grad, (self,), "exp", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad * out_data

        out._backward = _backward
        return out

    def log(self):
        x = _to_numpy(self.data)
        out_data = np.log(x)
        out = Tensor(out_data, self.requires_grad, (self,), "log", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad / x

        out._backward = _backward
        return out

    def sqrt(self):
        x = _to_numpy(self.data)
        out_data = np.sqrt(x)
        out = Tensor(out_data, self.requires_grad, (self,), "sqrt", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad * 0.5 / np.maximum(out_data, 1e-12)

        out._backward = _backward
        return out

    def abs(self):
        x = _to_numpy(self.data)
        out = Tensor(np.abs(x), self.requires_grad, (self,), "abs", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad * np.sign(x)

        out._backward = _backward
        return out

    def sin(self):
        x = _to_numpy(self.data)
        out = Tensor(np.sin(x), self.requires_grad, (self,), "sin", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad * np.cos(x)

        out._backward = _backward
        return out

    def cos(self):
        x = _to_numpy(self.data)
        out = Tensor(np.cos(x), self.requires_grad, (self,), "cos", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad -= out.grad * np.sin(x)

        out._backward = _backward
        return out

    def relu(self):
        x = _to_numpy(self.data)
        out_data = np.maximum(x, 0)
        out = Tensor(out_data, self.requires_grad, (self,), "relu", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad * (x > 0)

        out._backward = _backward
        return out

    def __getitem__(self, idx):
        x = _to_numpy(self.data)
        out = Tensor(x[idx], self.requires_grad, (self,), "getitem", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = np.zeros_like(x, dtype=self.grad.dtype)
                np.add.at(grad, idx, out.grad)
                self.grad += grad

        out._backward = _backward
        return out

    def gather(self, dim, index):
        idx = index.to_numpy().astype(np.int64) if isinstance(index, Tensor) else np.asarray(index, dtype=np.int64)
        x = _to_numpy(self.data)
        out_data = np.take_along_axis(x, idx, axis=dim)
        out = Tensor(out_data, self.requires_grad, (self,), "gather", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = np.zeros_like(x, dtype=self.grad.dtype)
                grid = np.indices(idx.shape)
                target = []
                for axis in range(x.ndim):
                    target.append(idx if axis == dim else grid[axis])
                np.add.at(grad, tuple(target), out.grad)
                self.grad += grad

        out._backward = _backward
        return out

    def scatter(self, dim, index, src):
        idx = index.to_numpy().astype(np.int64) if isinstance(index, Tensor) else np.asarray(index, dtype=np.int64)
        src_t = src if isinstance(src, Tensor) else Tensor(src, device=self.device)
        x = _to_numpy(self.data)
        src_data = _to_numpy(src_t.data)
        out_data = x.copy()
        np.put_along_axis(out_data, idx, src_data, axis=dim)
        out = Tensor(out_data, self.requires_grad or src_t.requires_grad, (self, src_t), "scatter", device=self.device)

        def _backward():
            if self.requires_grad:
                mask = np.zeros_like(x, dtype=bool)
                np.put_along_axis(mask, idx, True, axis=dim)
                self.grad += out.grad * (~mask)
            if src_t.requires_grad:
                src_t.grad += np.take_along_axis(out.grad, idx, axis=dim)

        out._backward = _backward
        return out

    def index_select(self, dim, index):
        idx = index.to_numpy().astype(np.int64) if isinstance(index, Tensor) else np.asarray(index, dtype=np.int64)
        x = _to_numpy(self.data)
        out_data = np.take(x, idx, axis=dim)
        out = Tensor(out_data, self.requires_grad, (self,), "index_select", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = np.zeros_like(x, dtype=self.grad.dtype)
                slicer = [slice(None)] * x.ndim
                for i, pos in enumerate(idx):
                    slicer[dim] = pos
                    grad_slice = [slice(None)] * out.grad.ndim
                    grad_slice[dim] = i
                    grad[tuple(slicer)] += out.grad[tuple(grad_slice)]
                self.grad += grad

        out._backward = _backward
        return out

    def repeat(self, *sizes):
        if len(sizes) == 1 and isinstance(sizes[0], (tuple, list)):
            sizes = tuple(sizes[0])
        x = _to_numpy(self.data)
        out = Tensor(np.tile(x, sizes), self.requires_grad, (self,), "repeat", device=self.device)
        padded_shape = (1,) * (len(sizes) - x.ndim) + x.shape
        reps = tuple(sizes)

        def _backward():
            if self.requires_grad:
                grad = out.grad.reshape([v for pair in zip(reps, padded_shape) for v in pair])
                for axis in reversed(range(0, 2 * len(reps), 2)):
                    grad = grad.sum(axis=axis)
                self.grad += grad.reshape(self.shape)

        out._backward = _backward
        return out

    def expand(self, *shape):
        if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
            shape = tuple(shape[0])
        x = _to_numpy(self.data)
        target = []
        for i, d in enumerate(shape):
            target.append(x.shape[i] if d == -1 else d)
        out = Tensor(np.broadcast_to(x, tuple(target)), self.requires_grad, (self,), "expand", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += _unbroadcast(out.grad, self.shape)

        out._backward = _backward
        return out

    def add_(self, other):
        other_t = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        out = _to_numpy(self.data) + _to_numpy(other_t.data)
        self.data = _to_data_on_device(out, self.device)
        return self

    def mul_(self, other):
        other_t = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        out = _to_numpy(self.data) * _to_numpy(other_t.data)
        self.data = _to_data_on_device(out, self.device)
        return self

    def relu_(self):
        out = np.maximum(_to_numpy(self.data), 0)
        self.data = _to_data_on_device(out, self.device)
        return self

    def __gt__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        return Tensor(_to_numpy(self.data) > _to_numpy(other.data), requires_grad=False, device="cpu")

    def __lt__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        return Tensor(_to_numpy(self.data) < _to_numpy(other.data), requires_grad=False, device="cpu")

    def __ge__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        return Tensor(_to_numpy(self.data) >= _to_numpy(other.data), requires_grad=False, device="cpu")

    def __le__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        return Tensor(_to_numpy(self.data) <= _to_numpy(other.data), requires_grad=False, device="cpu")

    def eq(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        return Tensor(_to_numpy(self.data) == _to_numpy(other.data), requires_grad=False, device="cpu")

    def ne(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        return Tensor(_to_numpy(self.data) != _to_numpy(other.data), requires_grad=False, device="cpu")

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

    def cpu(self):
        return self.to(device="cpu")

    def cuda(self):
        return self.to(device="cuda")

    def float(self):
        return self.to(dtype=np.float32)

    def long(self):
        return self.to(dtype=np.int64)


def where(condition, x, y):
    cond = condition.to_numpy() if isinstance(condition, Tensor) else np.asarray(condition)
    x_t = x if isinstance(x, Tensor) else Tensor(x)
    y_t = y if isinstance(y, Tensor) else Tensor(y)
    out_device = "cuda" if (x_t.device == "cuda" or y_t.device == "cuda") else "cpu"
    out_data = np.where(cond, _to_numpy(x_t.data), _to_numpy(y_t.data))
    out = Tensor(out_data, x_t.requires_grad or y_t.requires_grad, (x_t, y_t), "where", device=out_device)

    def _backward():
        if x_t.requires_grad:
            x_t.grad += _unbroadcast(np.where(cond, out.grad, 0), x_t.shape)
        if y_t.requires_grad:
            y_t.grad += _unbroadcast(np.where(cond, 0, out.grad), y_t.shape)

    out._backward = _backward
    return out


def cat(tensors, axis=0, dim=None):
    if dim is not None:
        axis = dim
    ts = [t if isinstance(t, Tensor) else Tensor(t) for t in tensors]
    out_device = "cuda" if any(t.device == "cuda" for t in ts) else "cpu"
    out_data = np.concatenate([_to_numpy(t.data) for t in ts], axis=axis)
    out = Tensor(out_data, any(t.requires_grad for t in ts), tuple(ts), "cat", device=out_device)
    sizes = [t.shape[axis] for t in ts]

    def _backward():
        if out.grad is None:
            return
        start = 0
        slicer = [slice(None)] * out.grad.ndim
        for t, s in zip(ts, sizes):
            if t.requires_grad:
                slicer[axis] = slice(start, start + s)
                t.grad += out.grad[tuple(slicer)]
            start += s

    out._backward = _backward
    return out


def stack(tensors, axis=0, dim=None):
    if dim is not None:
        axis = dim
    ts = [t if isinstance(t, Tensor) else Tensor(t) for t in tensors]
    out_device = "cuda" if any(t.device == "cuda" for t in ts) else "cpu"
    out_data = np.stack([_to_numpy(t.data) for t in ts], axis=axis)
    out = Tensor(out_data, any(t.requires_grad for t in ts), tuple(ts), "stack", device=out_device)

    def _backward():
        for i, t in enumerate(ts):
            if t.requires_grad:
                t.grad += np.take(out.grad, i, axis=axis)

    out._backward = _backward
    return out


def split(tensor, split_size_or_sections, axis=0, dim=None):
    if dim is not None:
        axis = dim
    t = tensor if isinstance(tensor, Tensor) else Tensor(tensor)
    x = _to_numpy(t.data)
    if isinstance(split_size_or_sections, int):
        n = x.shape[axis]
        sections = list(range(split_size_or_sections, n, split_size_or_sections))
    else:
        sections = np.cumsum(split_size_or_sections)[:-1].tolist()
    arrays = np.split(x, sections, axis=axis)
    outputs = []
    start = 0
    for arr in arrays:
        end = start + arr.shape[axis]
        out = Tensor(arr, t.requires_grad, (t,), "split", device=t.device)

        def _backward(start_idx=start, end_idx=end, out_tensor=out):
            if t.requires_grad:
                slicer = [slice(None)] * t.ndim
                slicer[axis] = slice(start_idx, end_idx)
                t.grad[tuple(slicer)] += out_tensor.grad

        out._backward = _backward
        outputs.append(out)
        start = end
    return tuple(outputs)


def chunk(tensor, chunks, axis=0, dim=None):
    if dim is not None:
        axis = dim
    t = tensor if isinstance(tensor, Tensor) else Tensor(tensor)
    n = t.shape[axis]
    chunk_size = int(np.ceil(n / chunks))
    return split(t, chunk_size, axis=axis)


def matmul(a, b):
    return (a if isinstance(a, Tensor) else Tensor(a)) @ (b if isinstance(b, Tensor) else Tensor(b))


def mm(a, b):
    return matmul(a, b)


def bmm(a, b):
    return matmul(a, b)


def inverse(t):
    x = t if isinstance(t, Tensor) else Tensor(t)
    return Tensor(np.linalg.inv(_to_numpy(x.data)), requires_grad=False, device=x.device)


def svd(t):
    x = t if isinstance(t, Tensor) else Tensor(t)
    u, s, vh = np.linalg.svd(_to_numpy(x.data), full_matrices=False)
    return (
        Tensor(u, requires_grad=False, device=x.device),
        Tensor(s, requires_grad=False, device=x.device),
        Tensor(vh, requires_grad=False, device=x.device),
    )


def eig(t):
    x = t if isinstance(t, Tensor) else Tensor(t)
    w, v = np.linalg.eig(_to_numpy(x.data))
    return Tensor(w, requires_grad=False, device=x.device), Tensor(v, requires_grad=False, device=x.device)


def _as_device(t: "Tensor"):
    if _is_cuda_device(t.data):
        return t.data
    arr = _ensure_array(t.data, dtype=np.float32)
    return _cuda_ops.to_device(arr)


# ============================================================================
# Tensor Creation Functions
# ============================================================================

def zeros(*shape, dtype=None, requires_grad=False, device=None):
    """Create a tensor filled with zeros.
    
    Args:
        *shape: Shape of the tensor (int or tuple)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.zeros(2, 3)
        >>> tensor.zeros((2, 3), device='cuda')
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    dtype = dtype or np.float32
    data = np.zeros(shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def ones(*shape, dtype=None, requires_grad=False, device=None):
    """Create a tensor filled with ones.
    
    Args:
        *shape: Shape of the tensor (int or tuple)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.ones(2, 3)
        >>> tensor.ones((2, 3), dtype=np.int32)
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    dtype = dtype or np.float32
    data = np.ones(shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def full(shape, fill_value, dtype=None, requires_grad=False, device=None):
    """Create a tensor filled with a specific value.
    
    Args:
        shape: Shape of the tensor
        fill_value: Value to fill the tensor with
        dtype: Data type (default: inferred from fill_value)
        requires_grad: Whether to track gradients
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.full((2, 3), 7.5)
    """
    if isinstance(shape, int):
        shape = (shape,)
    data = np.full(shape, fill_value, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def empty(*shape, dtype=None, requires_grad=False, device=None):
    """Create an uninitialized tensor.
    
    Args:
        *shape: Shape of the tensor (int or tuple)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.empty(2, 3)
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    dtype = dtype or np.float32
    data = np.empty(shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def rand(*shape, dtype=None, requires_grad=False, device=None):
    """Create a tensor with random values from uniform distribution [0, 1).
    
    Args:
        *shape: Shape of the tensor (int or tuple)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.rand(2, 3)
        >>> tensor.rand((2, 3), device='cuda')
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    dtype = dtype or np.float32
    data = np.random.rand(*shape).astype(dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def randn(*shape, dtype=None, requires_grad=False, device=None):
    """Create a tensor with random values from standard normal distribution.
    
    Args:
        *shape: Shape of the tensor (int or tuple)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.randn(2, 3)
        >>> tensor.randn((2, 3), device='cuda')
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    dtype = dtype or np.float32
    data = np.random.randn(*shape).astype(dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def randint(low, high, shape, dtype=None, requires_grad=False, device=None):
    """Create a tensor with random integers from [low, high).
    
    Args:
        low: Lowest integer (inclusive)
        high: Highest integer (exclusive)
        shape: Shape of the tensor
        dtype: Data type (default: int64)
        requires_grad: Whether to track gradients (typically False for integers)
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.randint(0, 10, (2, 3))
    """
    if isinstance(shape, int):
        shape = (shape,)
    dtype = dtype or np.int64
    data = np.random.randint(low, high, size=shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def arange(start, end=None, step=1, dtype=None, requires_grad=False, device=None):
    """Create a 1D tensor with evenly spaced values.
    
    Args:
        start: Start value (or end if end is None)
        end: End value (exclusive)
        step: Spacing between values
        dtype: Data type (default: inferred)
        requires_grad: Whether to track gradients
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.arange(10)        # [0, 1, 2, ..., 9]
        >>> tensor.arange(2, 10, 2)  # [2, 4, 6, 8]
    """
    if end is None:
        end = start
        start = 0
    data = np.arange(start, end, step, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def linspace(start, end, steps, dtype=None, requires_grad=False, device=None):
    """Create a 1D tensor with linearly spaced values.
    
    Args:
        start: Start value
        end: End value (inclusive)
        steps: Number of values
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.linspace(0, 1, 5)  # [0.0, 0.25, 0.5, 0.75, 1.0]
    """
    dtype = dtype or np.float32
    data = np.linspace(start, end, steps, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def logspace(start, end, steps, base=10.0, dtype=None, requires_grad=False, device=None):
    """Create a 1D tensor with logarithmically spaced values.
    
    Args:
        start: Start exponent
        end: End exponent
        steps: Number of values
        base: Base of the logarithm (default: 10)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.logspace(0, 3, 4)  # [1, 10, 100, 1000]
    """
    dtype = dtype or np.float32
    data = np.logspace(start, end, steps, base=base, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def eye(n, m=None, dtype=None, requires_grad=False, device=None):
    """Create a 2D identity matrix.
    
    Args:
        n: Number of rows
        m: Number of columns (default: same as n)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.eye(3)
        >>> tensor.eye(3, 4)
    """
    dtype = dtype or np.float32
    data = np.eye(n, m, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def diag(v, k=0, dtype=None, requires_grad=False, device=None):
    """Create a diagonal matrix from a vector or extract diagonal from matrix.
    
    Args:
        v: 1D or 2D tensor/array
        k: Diagonal offset (0=main diagonal, positive=above, negative=below)
        dtype: Data type
        requires_grad: Whether to track gradients
        device: Device to place tensor on ('cpu' or 'cuda')
    
    Example:
        >>> tensor.diag([1, 2, 3])
        >>> tensor.diag(tensor.ones(3, 3), k=1)
    """
    v_data = v.to_numpy() if isinstance(v, Tensor) else np.asarray(v)
    data = np.diag(v_data, k=k)
    if dtype is not None:
        data = data.astype(dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def zeros_like(input, dtype=None, requires_grad=False, device=None):
    """Create a tensor of zeros with the same shape as input.
    
    Args:
        input: Input tensor to match shape
        dtype: Data type (default: same as input)
        requires_grad: Whether to track gradients
        device: Device to place tensor on (default: same as input)
    
    Example:
        >>> x = tensor.rand(2, 3)
        >>> tensor.zeros_like(x)
    """
    shape = input.shape if isinstance(input, Tensor) else np.asarray(input).shape
    device = device or (input.device if isinstance(input, Tensor) else None)
    dtype = dtype or (input.dtype if isinstance(input, Tensor) else np.asarray(input).dtype)
    return zeros(*shape, dtype=dtype, requires_grad=requires_grad, device=device)


def ones_like(input, dtype=None, requires_grad=False, device=None):
    """Create a tensor of ones with the same shape as input.
    
    Args:
        input: Input tensor to match shape
        dtype: Data type (default: same as input)
        requires_grad: Whether to track gradients
        device: Device to place tensor on (default: same as input)
    
    Example:
        >>> x = tensor.rand(2, 3)
        >>> tensor.ones_like(x)
    """
    shape = input.shape if isinstance(input, Tensor) else np.asarray(input).shape
    device = device or (input.device if isinstance(input, Tensor) else None)
    dtype = dtype or (input.dtype if isinstance(input, Tensor) else np.asarray(input).dtype)
    return ones(*shape, dtype=dtype, requires_grad=requires_grad, device=device)


def full_like(input, fill_value, dtype=None, requires_grad=False, device=None):
    """Create a tensor filled with a value, matching the shape of input.
    
    Args:
        input: Input tensor to match shape
        fill_value: Value to fill with
        dtype: Data type (default: same as input)
        requires_grad: Whether to track gradients
        device: Device to place tensor on (default: same as input)
    
    Example:
        >>> x = tensor.rand(2, 3)
        >>> tensor.full_like(x, 7.5)
    """
    shape = input.shape if isinstance(input, Tensor) else np.asarray(input).shape
    device = device or (input.device if isinstance(input, Tensor) else None)
    dtype = dtype or (input.dtype if isinstance(input, Tensor) else np.asarray(input).dtype)
    return full(shape, fill_value, dtype=dtype, requires_grad=requires_grad, device=device)


def rand_like(input, dtype=None, requires_grad=False, device=None):
    """Create a tensor of random values [0, 1) with the same shape as input.
    
    Args:
        input: Input tensor to match shape
        dtype: Data type (default: same as input)
        requires_grad: Whether to track gradients
        device: Device to place tensor on (default: same as input)
    
    Example:
        >>> x = tensor.rand(2, 3)
        >>> tensor.rand_like(x)
    """
    shape = input.shape if isinstance(input, Tensor) else np.asarray(input).shape
    device = device or (input.device if isinstance(input, Tensor) else None)
    dtype = dtype or (input.dtype if isinstance(input, Tensor) else np.asarray(input).dtype)
    return rand(*shape, dtype=dtype, requires_grad=requires_grad, device=device)


def randn_like(input, dtype=None, requires_grad=False, device=None):
    """Create a tensor of random normal values with the same shape as input.
    
    Args:
        input: Input tensor to match shape
        dtype: Data type (default: same as input)
        requires_grad: Whether to track gradients
        device: Device to place tensor on (default: same as input)
    
    Example:
        >>> x = tensor.rand(2, 3)
        >>> tensor.randn_like(x)
    """
    shape = input.shape if isinstance(input, Tensor) else np.asarray(input).shape
    device = device or (input.device if isinstance(input, Tensor) else None)
    dtype = dtype or (input.dtype if isinstance(input, Tensor) else np.asarray(input).dtype)
    return randn(*shape, dtype=dtype, requires_grad=requires_grad, device=device)
