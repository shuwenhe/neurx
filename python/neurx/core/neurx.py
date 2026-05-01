import os
import numpy as np
from contextlib import ContextDecorator
from scipy import special as _scipy_special

def _load_accelerator_ops():
    preferred = (os.environ.get("TENSOR_DEVICE") or "").strip().lower()
    if preferred == "npu":
        try:
            from cann import npu_ops as accel_ops

            return accel_ops
        except Exception:
            return None
    try:
        from neurx.cuda import ops as accel_ops

        return accel_ops
    except Exception:
        return None


_cuda_ops = _load_accelerator_ops()


def _accelerator_available() -> bool:
    return bool(_cuda_ops is not None and hasattr(_cuda_ops, "available") and _cuda_ops.available())


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
        from neurx.platform import get_runtime_config

        return get_runtime_config().default_device
    except Exception:
        return "cpu"


def _should_fallback_cuda_to_cpu():
    try:
        from neurx.platform import get_runtime_config

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
        if device == "npu":
            # Reuse existing accelerator execution path while selecting Ascend ops at import time.
            device = "cuda"
        if device == "cuda" and not _accelerator_available() and _should_fallback_cuda_to_cpu():
            device = "cpu"
        self.device = device

        if self.device == "cuda":
            if not _accelerator_available():
                try:
                    from neurx.platform import BackendNotAvailableError
                except Exception:
                    BackendNotAvailableError = RuntimeError
                raise BackendNotAvailableError(
                    "Accelerator backend not available. "
                    "Set TENSOR_FALLBACK_TO_CPU=1 to auto-fallback or configure CUDA/CANN runtime."
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
        runtime_backend = "python"
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
            runtime_backend = "cuda"
        else:
            out_data = None
            try:
                from neurx.compile.runtime import try_invoke_ops_function

                out_data = try_invoke_ops_function("add", self.data, other.data)
            except Exception:
                out_data = None
            if out_data is not None:
                out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "+")
                runtime_backend = "s"
            else:
                out = Tensor(self.data + other.data, self.requires_grad or other.requires_grad, (self, other), "+")

        def _backward():
            if self.requires_grad:
                self.grad += _unbroadcast(out.grad, self.shape)
            if other.requires_grad:
                other.grad += _unbroadcast(out.grad, other.shape)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def __radd__(self, other):
        return self + other

    def __sub__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        runtime_backend = "python"
        out_data = None
        if self.device != "cuda" and other.device != "cuda":
            try:
                from neurx.compile.runtime import try_invoke_ops_function

                out_data = try_invoke_ops_function("sub", self.data, other.data)
            except Exception:
                out_data = None
        out_device = "cuda" if (self.device == "cuda" or other.device == "cuda") else "cpu"
        if out_data is not None:
            out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "-", device=out_device)
            runtime_backend = "s"
        else:
            out = Tensor(_to_numpy(self.data) - _to_numpy(other.data), self.requires_grad or other.requires_grad, (self, other), "-", device=out_device)

        def _backward():
            if self.requires_grad:
                self.grad += _unbroadcast(out.grad, self.shape)
            if other.requires_grad:
                other.grad -= _unbroadcast(out.grad, other.shape)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def __rsub__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        return other - self

    def __neg__(self):
        if self.device == "cuda":
            # DeviceArray does not implement unary '-' directly; negate on host then move back.
            out = Tensor(-_to_numpy(self.data), self.requires_grad, (self,), "neg", device="cuda")
        else:
            out = Tensor(-self.data, self.requires_grad, (self,), "neg")

        def _backward():
            if self.requires_grad:
                self.grad -= out.grad

        out._backward = _backward
        return out

    def __mul__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        runtime_backend = "python"
        if self.device == "cuda" or other.device == "cuda":
            out_data = _cuda_ops.mul(_as_device(self), _as_device(other))
            out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "*", device="cuda")
            runtime_backend = "cuda"
        else:
            out_data = None
            try:
                from neurx.compile.runtime import try_invoke_ops_function

                out_data = try_invoke_ops_function("mul", self.data, other.data)
            except Exception:
                out_data = None
            if out_data is not None:
                out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "*")
                runtime_backend = "s"
            else:
                out = Tensor(self.data * other.data, self.requires_grad or other.requires_grad, (self, other), "*")

        def _backward():
            if self.requires_grad:
                self.grad += _unbroadcast(_to_numpy(other.data) * out.grad, self.shape)
            if other.requires_grad:
                other.grad += _unbroadcast(_to_numpy(self.data) * out.grad, other.shape)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def __rmul__(self, other):
        return self * other

    def __truediv__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        runtime_backend = "python"
        out_device = "cuda" if (self.device == "cuda" or other.device == "cuda") else "cpu"
        out_data = None
        if out_device == "cpu":
            try:
                from neurx.compile.runtime import try_invoke_ops_function

                out_data = try_invoke_ops_function("div", self.data, other.data)
            except Exception:
                out_data = None
        if out_data is not None:
            runtime_backend = "s"
        else:
            out_data = _to_numpy(self.data) / _to_numpy(other.data)
        out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "/", device=out_device)

        def _backward():
            if self.requires_grad:
                self.grad += _unbroadcast(out.grad / _to_numpy(other.data), self.shape)
            if other.requires_grad:
                other.grad += _unbroadcast((-out.grad * _to_numpy(self.data)) / (_to_numpy(other.data) ** 2), other.shape)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def __rtruediv__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        return other / self

    def __pow__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        runtime_backend = "python"
        out_device = "cuda" if (self.device == "cuda" or other.device == "cuda") else "cpu"
        base = _to_numpy(self.data)
        exp = _to_numpy(other.data)
        out_data = None
        if out_device == "cpu":
            try:
                from neurx.compile.runtime import try_invoke_ops_function

                out_data = try_invoke_ops_function("pow", self.data, other.data)
            except Exception:
                out_data = None
        if out_data is not None:
            runtime_backend = "s"
        else:
            out_data = base ** exp
        out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "pow", device=out_device)

        def _backward():
            if self.requires_grad:
                self.grad += _unbroadcast(out.grad * exp * (base ** (exp - 1.0)), self.shape)
            if other.requires_grad:
                safe_base = np.clip(base, 1e-12, None)
                other.grad += _unbroadcast(out.grad * out_data * np.log(safe_base), other.shape)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def __matmul__(self, other):
        other = other if isinstance(other, Tensor) else Tensor(other)
        runtime_backend = "python"
        if self.device == "cuda" or other.device == "cuda":
            if len(self.shape) == 2 and len(other.shape) == 2:
                out_data = _cuda_ops.matmul(_as_device(self), _as_device(other))
                out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "matmul", device="cuda")
                runtime_backend = "cuda"
            else:
                out = Tensor(_to_numpy(self.data) @ _to_numpy(other.data), self.requires_grad or other.requires_grad, (self, other), "matmul")
        else:
            out_data = None
            try:
                from neurx.compile.runtime import try_invoke_ops_function

                out_data = try_invoke_ops_function("matmul", self.data, other.data)
            except Exception:
                out_data = None
            if out_data is not None:
                out = Tensor(out_data, self.requires_grad or other.requires_grad, (self, other), "matmul")
                runtime_backend = "s"
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
        out._runtime_backend = runtime_backend
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
            raise ValueError("permute dims must match neurx ndim")
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
            out_data = None
            runtime_backend = "python"
            if isinstance(axis, int):
                try:
                    from neurx.compile.runtime import try_invoke_ops_function

                    out_data = try_invoke_ops_function("mean", self.data, axis, bool(keepdims))
                except Exception:
                    out_data = None
            if out_data is None:
                out_data = np.array(host.mean(axis=axis, keepdims=keepdims))
            else:
                runtime_backend = "s"
            out = Tensor(out_data, self.requires_grad, (self,), "mean", device=self.device)
            out._runtime_backend = runtime_backend

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
            out_data = None
            runtime_backend = "python"
            if isinstance(axis, int):
                try:
                    from neurx.compile.runtime import try_invoke_ops_function

                    out_data = try_invoke_ops_function("sum", self.data, axis, bool(keepdims))
                except Exception:
                    out_data = None
            if out_data is None:
                out_data = host.sum(axis=axis, keepdims=keepdims)
            else:
                runtime_backend = "s"
            out = Tensor(out_data, self.requires_grad, (self,), "sum", device=self.device)
            out._runtime_backend = runtime_backend

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
        axes = tuple(range(self.ndim)) if axis is None else (axis if isinstance(axis, tuple) else (axis,))

        if p in (None, "fro", "frob", 2):
            out_data = np.sqrt(np.sum(x * x, axis=axes, keepdims=keepdims))
            effective_p = 2
        elif p == 1:
            out_data = np.sum(np.abs(x), axis=axes, keepdims=keepdims)
            effective_p = 1
        elif p == np.inf:
            out_data = np.max(np.abs(x), axis=axes, keepdims=keepdims)
            effective_p = np.inf
        elif p == -np.inf:
            out_data = np.min(np.abs(x), axis=axes, keepdims=keepdims)
            effective_p = -np.inf
        else:
            out_data = np.sum(np.abs(x) ** p, axis=axes, keepdims=keepdims) ** (1.0 / p)
            effective_p = p

        out = Tensor(out_data, self.requires_grad, (self,), "norm", device=self.device)

        def _backward():
            if not self.requires_grad:
                return
            grad = out.grad
            norm_keep = np.maximum(np.sum(x * x, axis=axes, keepdims=True) ** 0.5, 1e-12)
            norm_keep = np.maximum(norm_keep, 1e-12)
            if not keepdims and axis is not None:
                for ax in sorted(axes):
                    grad = np.expand_dims(grad, axis=ax)
            if effective_p == 2:
                self.grad += (x / norm_keep) * grad
            elif effective_p == 1:
                self.grad += np.sign(x) * grad
            elif effective_p == np.inf:
                abs_x = np.abs(x)
                max_keep = np.max(abs_x, axis=axes, keepdims=True)
                mask = abs_x == max_keep
                denom = np.maximum(mask.sum(axis=axes, keepdims=True), 1)
                self.grad += (np.sign(x) * mask / denom) * grad
            elif effective_p == -np.inf:
                abs_x = np.abs(x)
                min_keep = np.min(abs_x, axis=axes, keepdims=True)
                mask = abs_x == min_keep
                denom = np.maximum(mask.sum(axis=axes, keepdims=True), 1)
                self.grad += (np.sign(x) * mask / denom) * grad
            else:
                self.grad += (
                    np.sign(x)
                    * (np.abs(x) ** (effective_p - 1))
                    / (norm_keep ** (effective_p - 1))
                ) * grad

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
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("sqrt", x)
        except Exception:
            out_data = None
        if out_data is None:
            out_data = np.sqrt(x)
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "sqrt", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad * 0.5 / np.maximum(out_data, 1e-12)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def exp(self):
        """
        计算元素级的指数 e^x
        
        Returns:
            Tensor: 包含 e^x 的新张量
        
        Example:
            >>> x = Tensor([0, 1, 2])
            >>> y = x.exp()
            >>> print(y.data)  # [1., 2.718..., 7.389...]
        """
        x = _to_numpy(self.data)
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("exp", x)
        except Exception:
            out_data = None
        if out_data is None:
            out_data = np.exp(x)
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "exp", device=self.device)

        def _backward():
            if self.requires_grad:
                # exp(x) 的导数是 exp(x)
                self.grad += out.grad * out_data

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def log(self):
        """
        计算元素级的自然对数 ln(x)
        
        Returns:
            Tensor: 包含 ln(x) 的新张量
        
        Example:
            >>> x = Tensor([1, 2.718, 7.389])
            >>> y = x.log()
            >>> print(y.data)  # [0., 1., 2.]
        
        Note:
            要求 x > 0，对于 x <= 0 的值会产生 NaN 或 -inf
        """
        x = _to_numpy(self.data)
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("log", x)
        except Exception:
            out_data = None
        if out_data is None:
            out_data = np.log(x)
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "log", device=self.device)

        def _backward():
            if self.requires_grad:
                # log(x) 的导数是 1/x
                # 使用 maximum 避免除以 0
                self.grad += out.grad / np.maximum(x, 1e-12)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def log10(self):
        """
        计算元素级的常用对数 log10(x)
        
        Returns:
            Tensor: 包含 log10(x) 的新张量
        
        Example:
            >>> x = Tensor([1, 10, 100])
            >>> y = x.log10()
            >>> print(y.data)  # [0., 1., 2.]
        """
        x = _to_numpy(self.data)
        out_data = np.log10(x)
        out = Tensor(out_data, self.requires_grad, (self,), "log10", device=self.device)

        def _backward():
            if self.requires_grad:
                # log10(x) 的导数是 1/(x * ln(10))
                self.grad += out.grad / (np.maximum(x, 1e-12) * np.log(10))

        out._backward = _backward
        return out

    def log2(self):
        """
        计算元素级的二进制对数 log2(x)
        
        Returns:
            Tensor: 包含 log2(x) 的新张量
        
        Example:
            >>> x = Tensor([1, 2, 4, 8])
            >>> y = x.log2()
            >>> print(y.data)  # [0., 1., 2., 3.]
        """
        x = _to_numpy(self.data)
        out_data = np.log2(x)
        out = Tensor(out_data, self.requires_grad, (self,), "log2", device=self.device)

        def _backward():
            if self.requires_grad:
                # log2(x) 的导数是 1/(x * ln(2))
                self.grad += out.grad / (np.maximum(x, 1e-12) * np.log(2))

        out._backward = _backward
        return out

    def sigmoid(self):
        """Sigmoid 激活函数: σ(x) = 1 / (1 + exp(-x))
        
        数据类型安全的实现，避免数值溢出。
        使用这个技巧: 对于 x > 0，计算 1 / (1 + exp(-x))
                      对于 x <= 0，计算 exp(x) / (1 + exp(x))
        
        梯度: d(sigmoid(x))/dx = sigmoid(x) * (1 - sigmoid(x))
        
        示例:
            >>> x = Tensor([0.0, 1.0, -1.0], requires_grad=True)
            >>> y = x.sigmoid()
            >>> print(y.data)  # [0.5, 0.73105858, 0.26894142]
        """
        x = _to_numpy(self.data)
        runtime_backend = "python"
        sigmoid_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            sigmoid_data = try_invoke_ops_function("sigmoid", x)
        except Exception:
            sigmoid_data = None
        if sigmoid_data is None:
            # 数值稳定实现
            sigmoid_data = np.where(
                x >= 0,
                1.0 / (1.0 + np.exp(-x)),
                np.exp(x) / (1.0 + np.exp(x))
            )
        else:
            runtime_backend = "s"
        
        out = Tensor(sigmoid_data, self.requires_grad, (self,), "sigmoid", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # d(sigmoid(x))/dx = sigmoid(x) * (1 - sigmoid(x))
                grad = sigmoid_data * (1 - sigmoid_data)
                self.grad += out.grad * grad
        
        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def tanh(self):
        """Tanh 激活函数: tanh(x) = (exp(x) - exp(-x)) / (exp(x) + exp(-x))
        
        在 LSTM 和 RNN 中广泛使用的激活函数。
        输出范围: (-1, 1)
        
        梯度: d(tanh(x))/dx = 1 - tanh²(x)
        
        示例:
            >>> x = Tensor([0.0, 1.0, -1.0], requires_grad=True)
            >>> y = x.tanh()
            >>> print(y.data)  # [0.0, 0.76159416, -0.76159416]
        """
        x = _to_numpy(self.data)
        runtime_backend = "python"
        tanh_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            tanh_data = try_invoke_ops_function("tanh", x)
        except Exception:
            tanh_data = None
        if tanh_data is None:
            # 使用 numpy 的 tanh 实现（已经数值稳定）
            tanh_data = np.tanh(x)
        else:
            runtime_backend = "s"
        
        out = Tensor(tanh_data, self.requires_grad, (self,), "tanh", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # d(tanh(x))/dx = 1 - tanh²(x)
                grad = 1.0 - tanh_data ** 2
                self.grad += out.grad * grad
        
        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def gelu(self, approximate=False):
        """GELU (Gaussian Error Linear Unit) 激活函数
        
        精确版本: gelu(x) = x * Φ(x) 其中 Φ(x) 是标准高斯 CDF
        近似版本: gelu(x) ≈ 0.5 * x * (1 + tanh(sqrt(2/π) * (x + 0.044715 * x³)))
        
        GELU 在 BERT、GPT 等 Transformer 模型中广泛使用。
        相比 ReLU，GELU 提供更平滑的激活。
        
        参数:
            approximate (bool): 是否使用快速近似版本（默认：精确版本）
        
        梯度: 根据 x * Φ(x) 的链式法则计算
        
        示例:
            >>> x = Tensor([0.0, 1.0, -1.0], requires_grad=True)
            >>> y = x.gelu()
            >>> print(y.data)  # 接近 [0.0, 0.8413..., -0.1586...]
        """
        x = _to_numpy(self.data)
        runtime_backend = "python"
        gelu_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            gelu_data = try_invoke_ops_function("gelu", x, bool(approximate))
        except Exception:
            gelu_data = None
        if gelu_data is not None:
            runtime_backend = "s"
        
        if gelu_data is None and approximate:
            # 快速近似: gelu(x) ≈ 0.5*x*(1 + tanh(sqrt(2/π)*(x + 0.044715*x³)))
            GELU_COEF_A = np.sqrt(2.0 / np.pi)
            GELU_COEF_B = 0.044715
            
            x_cubed = x ** 3
            tanh_arg = GELU_COEF_A * (x + GELU_COEF_B * x_cubed)
            gelu_data = 0.5 * x * (1.0 + np.tanh(tanh_arg))
        elif gelu_data is None:
            # 精确版本: gelu(x) = x * Φ(x)
            # Φ(x) = 0.5 * (1 + erf(x / sqrt(2)))
            cdf = 0.5 * (1.0 + _scipy_special.erf(x / np.sqrt(2.0)))
            gelu_data = x * cdf
        
        out = Tensor(gelu_data, self.requires_grad, (self,), 
                     "gelu_approx" if approximate else "gelu", 
                     device=self.device)
        
        def _backward():
            if self.requires_grad:
                if approximate:
                    # 近似版本的梯度
                    GELU_COEF_A = np.sqrt(2.0 / np.pi)
                    GELU_COEF_B = 0.044715
                    
                    x_cubed = x ** 3
                    tanh_arg = GELU_COEF_A * (x + GELU_COEF_B * x_cubed)
                    tanh_val = np.tanh(tanh_arg)
                    cosh_arg_sq = 1.0 - tanh_val ** 2
                    
                    # d(gelu_approx)/dx = 0.5 * (1 + tanh(...)) + x * 0.5 * cosh²(...)'
                    sech_sq = cosh_arg_sq  # sech²(x) = 1 - tanh²(x)
                    factor = GELU_COEF_A * (1.0 + 3.0 * GELU_COEF_B * x ** 2)
                    grad = 0.5 * (1.0 + tanh_val) + 0.5 * x * sech_sq * factor
                else:
                    # 精确版本的梯度: d(x*Φ(x))/dx = Φ(x) + x*φ(x)
                    # φ(x) = Φ'(x) = (1/sqrt(2π)) * exp(-x²/2)
                    cdf = 0.5 * (1.0 + _scipy_special.erf(x / np.sqrt(2.0)))
                    pdf = (1.0 / np.sqrt(2.0 * np.pi)) * np.exp(-x ** 2 / 2.0)
                    grad = cdf + x * pdf
                
                self.grad += out.grad * grad
        
        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def abs(self):
        x = _to_numpy(self.data)
        out = Tensor(np.abs(x), self.requires_grad, (self,), "abs", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad * np.sign(x)

        out._backward = _backward
        return out

    def sign(self):
        x = _to_numpy(self.data)
        out = Tensor(np.sign(x), self.requires_grad, (self,), "sign", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += np.zeros_like(x, dtype=self.grad.dtype)

        out._backward = _backward
        return out

    def clamp(self, min=None, max=None):
        if min is None and max is None:
            raise ValueError("clamp: at least one of min/max must be specified")

        min_val = min.item() if isinstance(min, Tensor) and min.shape == () else min
        max_val = max.item() if isinstance(max, Tensor) and max.shape == () else max

        x = _to_numpy(self.data)
        out_data = x
        if min_val is not None:
            out_data = np.maximum(out_data, min_val)
        if max_val is not None:
            out_data = np.minimum(out_data, max_val)
        out = Tensor(out_data, self.requires_grad, (self,), "clamp", device=self.device)

        def _backward():
            if self.requires_grad:
                mask = np.ones_like(x, dtype=self.grad.dtype)
                if min_val is not None:
                    mask = mask * (x >= min_val)
                if max_val is not None:
                    mask = mask * (x <= max_val)
                self.grad += out.grad * mask

        out._backward = _backward
        return out

    def clip(self, min=None, max=None):
        return self.clamp(min=min, max=max)

    def clamp_min(self, min_val):
        """Clamp minimum value: max(x, min_val)
        
        Args:
            min_val: Minimum value (scalar or Tensor)
        
        Returns:
            Tensor with values clamped to >= min_val
        """
        min_value = min_val.item() if isinstance(min_val, Tensor) and min_val.shape == () else min_val
        x = _to_numpy(self.data)
        out_data = np.maximum(x, min_value)
        out = Tensor(out_data, self.requires_grad, (self,), "clamp_min", device=self.device)
        
        def _backward():
            if self.requires_grad:
                mask = (x >= min_value).astype(self.grad.dtype)
                self.grad += out.grad * mask
        
        out._backward = _backward
        return out

    def clamp_max(self, max_val):
        """Clamp maximum value: min(x, max_val)
        
        Args:
            max_val: Maximum value (scalar or Tensor)
        
        Returns:
            Tensor with values clamped to <= max_val
        """
        max_value = max_val.item() if isinstance(max_val, Tensor) and max_val.shape == () else max_val
        x = _to_numpy(self.data)
        out_data = np.minimum(x, max_value)
        out = Tensor(out_data, self.requires_grad, (self,), "clamp_max", device=self.device)
        
        def _backward():
            if self.requires_grad:
                mask = (x <= max_value).astype(self.grad.dtype)
                self.grad += out.grad * mask
        
        out._backward = _backward
        return out

    def log1p(self):
        """Compute log(1 + x) - numerically stable for small x
        
        This is useful for numerical stability when x is close to 0.
        
        Returns:
            Tensor containing log(1 + x)
        
        Example:
            >>> x = Tensor([0.0, 0.5, 1.0])
            >>> y = x.log1p()  # log(1 + x)
        """
        x = _to_numpy(self.data)
        out_data = np.log1p(x)
        out = Tensor(out_data, self.requires_grad, (self,), "log1p", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # d(log1p(x))/dx = 1/(1+x)
                self.grad += out.grad / (1.0 + x)
        
        out._backward = _backward
        return out

    def expm1(self):
        """Compute exp(x) - 1 - numerically stable for small x
        
        This is useful for numerical stability when x is close to 0.
        For small x, expm1(x) ≈ x, whereas exp(x) - 1 loses precision.
        
        Returns:
            Tensor containing exp(x) - 1
        
        Example:
            >>> x = Tensor([0.0, 0.1, 1.0])
            >>> y = x.expm1()  # exp(x) - 1
        """
        x = _to_numpy(self.data)
        out_data = np.expm1(x)
        out = Tensor(out_data, self.requires_grad, (self,), "expm1", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # d(expm1(x))/dx = exp(x)
                self.grad += out.grad * np.exp(x)
        
        out._backward = _backward
        return out

    def reciprocal(self):
        """Compute element-wise reciprocal: 1/x
        
        Returns:
            Tensor containing 1/x for each element
        
        Warning:
            Division by zero is handled by clamping to 1e-12
        
        Example:
            >>> x = Tensor([1.0, 2.0, 4.0])
            >>> y = x.reciprocal()  # [1.0, 0.5, 0.25]
        """
        x = _to_numpy(self.data)
        x_safe = np.maximum(np.abs(x), 1e-12) * np.sign(x)
        out_data = 1.0 / x_safe
        out = Tensor(out_data, self.requires_grad, (self,), "reciprocal", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # d(1/x)/dx = -1/x²
                self.grad += out.grad * (-out_data ** 2)
        
        out._backward = _backward
        return out

    def rsqrt(self):
        """Compute element-wise reciprocal square root: 1/sqrt(x)
        
        Returns:
            Tensor containing 1/sqrt(x) for positive elements
        
        Warning:
            Requires x > 0. Negative values are handled by taking absolute value.
        
        Example:
            >>> x = Tensor([1.0, 4.0, 9.0])
            >>> y = x.rsqrt()  # [1.0, 0.5, 0.333...]
        """
        x = _to_numpy(self.data)
        x_safe = np.maximum(np.abs(x), 1e-12)
        sqrt_x = np.sqrt(x_safe)
        out_data = 1.0 / sqrt_x
        out = Tensor(out_data, self.requires_grad, (self,), "rsqrt", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # d(1/sqrt(x))/dx = -1/(2*x^(3/2))
                self.grad += out.grad * (-0.5 / (x_safe ** 1.5))
        
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
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("relu", x)
        except Exception:
            out_data = None
        if out_data is not None:
            runtime_backend = "s"
        else:
            out_data = np.maximum(x, 0)
        out = Tensor(out_data, self.requires_grad, (self,), "relu", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad * (x > 0)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def leaky_relu(self, negative_slope=0.01):
        x = _to_numpy(self.data)
        negative_slope = float(negative_slope)
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("leaky_relu", x, negative_slope)
        except Exception:
            out_data = None
        if out_data is None:
            out_data = np.where(x > 0, x, negative_slope * x)
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "leaky_relu", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = np.where(x > 0, 1.0, negative_slope)
                self.grad += out.grad * grad

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def elu(self, alpha=1.0):
        x = _to_numpy(self.data)
        alpha = float(alpha)
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("elu", x, alpha)
        except Exception:
            out_data = None
        if out_data is None:
            out_data = np.where(x > 0, x, alpha * (np.exp(x) - 1.0))
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "elu", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = np.where(x > 0, 1.0, alpha * np.exp(x))
                self.grad += out.grad * grad

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def selu(self):
        x = _to_numpy(self.data)
        alpha = 1.6732632423543772
        scale = 1.0507009873554805
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("selu", x)
        except Exception:
            out_data = None
        if out_data is None:
            inner = np.where(x > 0, x, alpha * (np.exp(x) - 1.0))
            out_data = scale * inner
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "selu", device=self.device)

        def _backward():
            if self.requires_grad:
                grad_inner = np.where(x > 0, 1.0, alpha * np.exp(x))
                self.grad += out.grad * (scale * grad_inner)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def silu(self):
        x = _to_numpy(self.data)
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("silu", x)
        except Exception:
            out_data = None
        if out_data is None:
            sigmoid_x = np.where(
                x >= 0,
                1.0 / (1.0 + np.exp(-x)),
                np.exp(x) / (1.0 + np.exp(x)),
            )
            out_data = x * sigmoid_x
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "silu", device=self.device)

        def _backward():
            if self.requires_grad:
                sigmoid_x = np.where(
                    x >= 0,
                    1.0 / (1.0 + np.exp(-x)),
                    np.exp(x) / (1.0 + np.exp(x)),
                )
                self.grad += out.grad * (sigmoid_x + x * sigmoid_x * (1.0 - sigmoid_x))

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def mish(self):
        x = _to_numpy(self.data)
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("mish", x)
        except Exception:
            out_data = None
        if out_data is None:
            softplus = np.where(x > 20, x, np.log(1.0 + np.exp(x)))
            tanh_sp = np.tanh(softplus)
            out_data = x * tanh_sp
        else:
            runtime_backend = "s"
            softplus = np.where(x > 20, x, np.log(1.0 + np.exp(x)))
            tanh_sp = np.tanh(softplus)
        out = Tensor(out_data, self.requires_grad, (self,), "mish", device=self.device)

        def _backward():
            if self.requires_grad:
                sigmoid_x = np.where(
                    x >= 0,
                    1.0 / (1.0 + np.exp(-x)),
                    np.exp(x) / (1.0 + np.exp(x)),
                )
                sech2_sp = 1.0 - tanh_sp ** 2
                grad = tanh_sp + x * sech2_sp * sigmoid_x
                self.grad += out.grad * grad

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def softplus(self, beta=1.0):
        x = _to_numpy(self.data)
        beta = float(beta)
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("softplus", x, beta)
        except Exception:
            out_data = None
        if out_data is None:
            beta_x = beta * x
            out_data = np.where(beta_x > 20, x, np.log1p(np.exp(beta_x)) / beta)
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "softplus", device=self.device)

        def _backward():
            if self.requires_grad:
                beta_x = beta * x
                sigmoid_x = np.where(
                    beta_x >= 0,
                    1.0 / (1.0 + np.exp(-beta_x)),
                    np.exp(beta_x) / (1.0 + np.exp(beta_x)),
                )
                self.grad += out.grad * sigmoid_x

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def softsign(self):
        x = _to_numpy(self.data)
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("softsign", x)
        except Exception:
            out_data = None
        if out_data is None:
            out_data = x / (1.0 + np.abs(x))
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "softsign", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad / ((1.0 + np.abs(x)) ** 2)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def swish(self, beta=1.0):
        x = _to_numpy(self.data)
        beta = float(beta)
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("swish", x, beta)
        except Exception:
            out_data = None
        beta_x = beta * x
        sigmoid_x = np.where(
            beta_x >= 0,
            1.0 / (1.0 + np.exp(-beta_x)),
            np.exp(beta_x) / (1.0 + np.exp(beta_x)),
        )
        if out_data is None:
            out_data = x * sigmoid_x
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "swish", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = sigmoid_x + beta * x * sigmoid_x * (1.0 - sigmoid_x)
                self.grad += out.grad * grad

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def hardtanh(self, min_val=-1.0, max_val=1.0):
        x = _to_numpy(self.data)
        min_val = float(min_val)
        max_val = float(max_val)
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("hardtanh", x, min_val, max_val)
        except Exception:
            out_data = None
        if out_data is None:
            out_data = np.clip(x, min_val, max_val)
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "hardtanh", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = ((x > min_val) & (x < max_val)).astype(self.grad.dtype)
                self.grad += out.grad * grad

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def hardswish(self):
        x = _to_numpy(self.data)
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("hardswish", x)
        except Exception:
            out_data = None
        if out_data is None:
            clipped = np.clip(x + 3.0, 0.0, 6.0) / 6.0
            out_data = x * clipped
        else:
            runtime_backend = "s"
            clipped = np.clip(x + 3.0, 0.0, 6.0) / 6.0
        out = Tensor(out_data, self.requires_grad, (self,), "hardswish", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = np.zeros_like(x)
                mask_mid = (x >= -3) & (x < 3)
                mask_high = x >= 3
                grad[mask_mid] = 2 * x[mask_mid] / 6 + 1
                grad[mask_high] = 1.0
                self.grad += out.grad * grad

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def prelu(self, weight):
        weight = weight if isinstance(weight, Tensor) else Tensor(weight)
        x = _to_numpy(self.data)
        w_data = _to_numpy(weight.data)
        if w_data.ndim == 0 or w_data.size == 1:
            slope = float(w_data.reshape(-1)[0])
        else:
            raise ValueError("prelu currently supports scalar weight only")

        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("prelu", x, slope)
        except Exception:
            out_data = None
        if out_data is None:
            out_data = np.where(x > 0, x, slope * x)
        else:
            runtime_backend = "s"

        out = Tensor(out_data, self.requires_grad or weight.requires_grad, (self, weight), "prelu", device=self.device)

        def _backward():
            if self.requires_grad:
                dx = np.where(x > 0, 1.0, slope)
                self.grad += out.grad * dx
            if weight.requires_grad:
                dw = (out.grad * np.where(x > 0, 0.0, x)).sum()
                weight.grad += np.asarray(dw, dtype=weight.grad.dtype)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def rrelu(self, lower=1.0 / 8.0, upper=1.0 / 3.0, training=False):
        if lower > upper:
            raise ValueError("lower must be <= upper")

        x = _to_numpy(self.data)
        lower = float(lower)
        upper = float(upper)
        training = bool(training)

        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("rrelu", x, lower, upper, training)
        except Exception:
            out_data = None
        if out_data is None:
            slope = (lower + upper) * 0.5
            slope_arr = np.random.uniform(lower, upper, size=x.shape) if training else slope
            out_data = np.where(x > 0, x, slope_arr * x)
        else:
            runtime_backend = "s"

        out = Tensor(out_data, self.requires_grad, (self,), "rrelu", device=self.device)

        def _backward():
            if self.requires_grad:
                avg_slope = (lower + upper) * 0.5
                slope_grad = np.where(
                    x != 0,
                    out_data / x,
                    avg_slope,
                )
                grad = np.where(x > 0, 1.0, slope_grad)
                self.grad += out.grad * grad

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def softmax(self, dim=-1):
        x = _to_numpy(self.data)
        dim = dim + x.ndim if dim < 0 else dim
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("softmax", x, dim)
        except Exception:
            out_data = None
        if out_data is None:
            x_shifted = x - np.max(x, axis=dim, keepdims=True)
            exp_x = np.exp(x_shifted)
            out_data = exp_x / np.sum(exp_x, axis=dim, keepdims=True)
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "softmax", device=self.device)

        def _backward():
            if self.requires_grad:
                g = out.grad
                y = out_data
                self.grad += y * (g - np.sum(g * y, axis=dim, keepdims=True))

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def log_softmax(self, dim=-1):
        x = _to_numpy(self.data)
        dim = dim + x.ndim if dim < 0 else dim
        runtime_backend = "python"
        out_data = None
        try:
            from neurx.compile.runtime import try_invoke_ops_function

            out_data = try_invoke_ops_function("log_softmax", x, dim)
        except Exception:
            out_data = None
        if out_data is None:
            x_shifted = x - np.max(x, axis=dim, keepdims=True)
            logsumexp = np.log(np.sum(np.exp(x_shifted), axis=dim, keepdims=True))
            out_data = x_shifted - logsumexp
        else:
            runtime_backend = "s"
        out = Tensor(out_data, self.requires_grad, (self,), "log_softmax", device=self.device)

        def _backward():
            if self.requires_grad:
                g = out.grad
                y = np.exp(out_data)
                self.grad += g - y * np.sum(g, axis=dim, keepdims=True)

        out._backward = _backward
        out._runtime_backend = runtime_backend
        return out

    def _normalize_index(self, index):
        if isinstance(index, Tensor):
            arr = index.to_numpy()
            if arr.dtype == np.bool_:
                return arr.astype(bool, copy=False)
            if np.issubdtype(arr.dtype, np.floating):
                if np.all(np.isfinite(arr)) and np.all(arr == np.floor(arr)):
                    return arr.astype(np.int64, copy=False)
                raise IndexError("Tensor float indices are invalid; use integer-valued indices or boolean mask")
            return arr.astype(np.int64, copy=False)
        if isinstance(index, tuple):
            return tuple(self._normalize_index(i) for i in index)
        if isinstance(index, list):
            return [self._normalize_index(i) for i in index]
        return index

    def _coerce_mask_like(self, index, shape):
        def maybe_mask(arr, axis):
            if (
                isinstance(arr, np.ndarray)
                and np.issubdtype(arr.dtype, np.integer)
                and arr.ndim == 1
                and axis < len(shape)
                and arr.shape[0] == shape[axis]
                and np.all((arr == 0) | (arr == 1))
            ):
                return arr.astype(bool, copy=False)
            return arr

        if isinstance(index, tuple):
            result = []
            axis = 0
            explicit = sum(1 for item in index if item is not Ellipsis and item is not None)
            for item in index:
                if item is None:
                    result.append(item)
                    continue
                if item is Ellipsis:
                    remaining = len(shape) - explicit
                    axis += max(remaining, 0)
                    result.append(item)
                    continue
                result.append(maybe_mask(item, axis))
                axis += 1
            return tuple(result)
        return maybe_mask(index, 0)

    def __getitem__(self, idx):
        x = _to_numpy(self.data)
        idx = self._coerce_mask_like(self._normalize_index(idx), x.shape)
        out = Tensor(x[idx], self.requires_grad, (self,), "getitem", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = np.zeros_like(x, dtype=self.grad.dtype)
                np.add.at(grad, idx, out.grad)
                self.grad += grad

        out._backward = _backward
        return out

    def __setitem__(self, idx, value):
        x = _to_numpy(self.data).copy()
        idx = self._coerce_mask_like(self._normalize_index(idx), x.shape)
        value_data = _to_numpy(value.data) if isinstance(value, Tensor) else value
        try:
            x[idx] = value_data
        except (ValueError, IndexError, TypeError) as exc:
            raise ValueError(
                f"setitem assignment failed for index {idx}: cannot assign value with shape "
                f"{np.shape(value_data)}"
            ) from exc
        self.data = _to_data_on_device(x, self.device)

    def gather(self, dim, index):
        idx = index.to_numpy().astype(np.int64) if isinstance(index, Tensor) else np.asarray(index, dtype=np.int64)
        x = _to_numpy(self.data)
        dim = dim + x.ndim if dim < 0 else dim
        if dim < 0 or dim >= x.ndim:
            raise IndexError(f"gather: dim {dim} out of range for ndim {x.ndim}")
        if idx.ndim != x.ndim:
            raise ValueError("gather: index must have the same number of dimensions as input")
        for axis in range(x.ndim):
            if axis != dim and idx.shape[axis] != x.shape[axis]:
                raise ValueError("gather: index shape must match input shape on non-gather dimensions")
        if idx.size > 0:
            dim_size = x.shape[dim]
            idx_min = int(np.min(idx))
            idx_max = int(np.max(idx))
            if idx_min < 0 or idx_max >= dim_size:
                raise IndexError(
                    f"gather: index out of bounds for dim {dim} with size {dim_size} "
                    f"(min={idx_min}, max={idx_max})"
                )
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

    def take_along_dim(self, indices, dim=-1):
        return self.gather(dim, indices)

    def scatter(self, dim, index, src):
        """
        Replaces values in self at the indices specified by index along dimension dim with src.
        
        Args:
            dim: Dimension along which to scatter
            index: Indices to scatter to (should have same shape as src)
            src: Source tensor with values to scatter
        
        Returns:
            New tensor with scattered values
        
        Raises:
            IndexError: If dim is out of range or indices are out of bounds
            ValueError: If shapes don't match
        """
        idx = index.to_numpy().astype(np.int64) if isinstance(index, Tensor) else np.asarray(index, dtype=np.int64)
        src_t = src if isinstance(src, Tensor) else Tensor(src, device=self.device)
        x = _to_numpy(self.data)
        src_data = _to_numpy(src_t.data)
        
        # Validate dimensions
        dim = dim + x.ndim if dim < 0 else dim
        if dim < 0 or dim >= x.ndim:
            raise IndexError(f"scatter: dim {dim} out of range for ndim {x.ndim}")
        
        # Validate shapes
        if idx.ndim != src_data.ndim:
            raise ValueError(f"scatter: index must have same number of dimensions as src, got {idx.ndim} vs {src_data.ndim}")
        if idx.shape != src_data.shape:
            raise ValueError(f"scatter: index shape {idx.shape} must match src shape {src_data.shape}")
        
        # Validate non-scatter dimensions
        for axis in range(x.ndim):
            if axis != dim:
                if axis < len(idx.shape) and axis < len(x.shape):
                    if idx.shape[axis] != x.shape[axis]:
                        raise ValueError(
                            f"scatter: index shape mismatch at dim {axis}: "
                            f"got {idx.shape[axis]}, expected {x.shape[axis]}"
                        )
        
        # Validate index bounds
        if idx.size > 0:
            dim_size = x.shape[dim]
            idx_min = int(np.min(idx))
            idx_max = int(np.max(idx))
            if idx_min < -dim_size or idx_max >= dim_size:
                raise IndexError(
                    f"scatter: index out of bounds for dim {dim} with size {dim_size} "
                    f"(min={idx_min}, max={idx_max})"
                )
        
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

    def scatter_add(self, dim, index, src):
        """
        Adds values from src into self at the indices specified by index along dimension dim.
        
        This operation accumulates values from src into self, allowing the same index to be
        used multiple times (values are added rather than replaced).
        
        Args:
            dim: Dimension along which to index
            index: Indices to scatter to (should have same shape as src)
            src: Source tensor with values to add
        
        Returns:
            New tensor with scattered additions
        
        Raises:
            IndexError: If dim is out of range or indices are out of bounds
            ValueError: If shapes don't match
        
        Example:
            >>> t = neurx.ones((3, 5))
            >>> index = neurx.Tensor([[0, 2], [1, 3], [0, 4]])
            >>> src = neurx.ones((3, 2)) * 2
            >>> result = t.scatter_add(1, index, src)  # Adds 2.0 at each indexed position
        """
        idx = index.to_numpy().astype(np.int64) if isinstance(index, Tensor) else np.asarray(index, dtype=np.int64)
        src_t = src if isinstance(src, Tensor) else Tensor(src, device=self.device)
        x = _to_numpy(self.data)
        src_data = _to_numpy(src_t.data)
        
        # Validate dimensions
        dim = dim + x.ndim if dim < 0 else dim
        if dim < 0 or dim >= x.ndim:
            raise IndexError(f"scatter_add: dim {dim} out of range for ndim {x.ndim}")
        
        # Validate shapes
        if idx.ndim != src_data.ndim:
            raise ValueError(f"scatter_add: index must have same number of dimensions as src, got {idx.ndim} vs {src_data.ndim}")
        if idx.shape != src_data.shape:
            raise ValueError(f"scatter_add: index shape {idx.shape} must match src shape {src_data.shape}")
        
        # Validate non-scatter dimensions
        for axis in range(x.ndim):
            if axis != dim:
                if axis < len(idx.shape) and axis < len(x.shape):
                    if idx.shape[axis] != x.shape[axis]:
                        raise ValueError(
                            f"scatter_add: index shape mismatch at dim {axis}: "
                            f"got {idx.shape[axis]}, expected {x.shape[axis]}"
                        )
        
        # Validate index bounds
        if idx.size > 0:
            dim_size = x.shape[dim]
            idx_min = int(np.min(idx))
            idx_max = int(np.max(idx))
            if idx_min < -dim_size or idx_max >= dim_size:
                raise IndexError(
                    f"scatter_add: index out of bounds for dim {dim} with size {dim_size} "
                    f"(min={idx_min}, max={idx_max})"
                )
        
        out_data = x.copy()

        moved_out = np.moveaxis(out_data, dim, -1)
        moved_idx = np.moveaxis(idx, dim, -1)
        moved_src = np.moveaxis(src_data, dim, -1)

        flat_out = moved_out.reshape(-1, moved_out.shape[-1])
        flat_idx = moved_idx.reshape(-1, moved_idx.shape[-1])
        flat_src = moved_src.reshape(-1, moved_src.shape[-1])

        row_idx = np.repeat(np.arange(flat_out.shape[0]), flat_idx.shape[1])
        np.add.at(flat_out, (row_idx, flat_idx.reshape(-1)), flat_src.reshape(-1))

        out_data = np.moveaxis(flat_out.reshape(moved_out.shape), -1, dim)
        
        out = Tensor(out_data, self.requires_grad or src_t.requires_grad, (self, src_t), "scatter_add", device=self.device)

        def _backward():
            if self.requires_grad:
                # Gradient flows through unchanged
                self.grad += out.grad
            if src_t.requires_grad:
                # Gradient is gathered from the scattered positions
                src_t.grad += np.take_along_axis(out.grad, idx, axis=dim)

        out._backward = _backward
        return out

    def index_select(self, dim, index):
        idx = index.to_numpy().astype(np.int64) if isinstance(index, Tensor) else np.asarray(index, dtype=np.int64)
        x = _to_numpy(self.data)
        dim = dim + x.ndim if dim < 0 else dim
        if dim < 0 or dim >= x.ndim:
            raise IndexError(f"index_select: dim {dim} out of range for ndim {x.ndim}")
        if idx.ndim != 1:
            raise ValueError("index_select: index must be a 1-D tensor/array")
        if idx.size > 0:
            dim_size = x.shape[dim]
            idx_min = int(np.min(idx))
            idx_max = int(np.max(idx))
            if idx_min < -dim_size or idx_max >= dim_size:
                raise IndexError(
                    f"index_select: index out of bounds for dim {dim} with size {dim_size} "
                    f"(min={idx_min}, max={idx_max})"
                )
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

    def tril(self, diagonal=0):
        x = _to_numpy(self.data)
        out_data = np.tril(x, k=diagonal)
        out = Tensor(out_data, self.requires_grad, (self,), "tril", device=self.device)

        def _backward():
            if self.requires_grad:
                mask = np.tril(np.ones_like(x, dtype=self.grad.dtype), k=diagonal)
                self.grad += out.grad * mask

        out._backward = _backward
        return out

    def triu(self, diagonal=0):
        x = _to_numpy(self.data)
        out_data = np.triu(x, k=diagonal)
        out = Tensor(out_data, self.requires_grad, (self,), "triu", device=self.device)

        def _backward():
            if self.requires_grad:
                mask = np.triu(np.ones_like(x, dtype=self.grad.dtype), k=diagonal)
                self.grad += out.grad * mask

        out._backward = _backward
        return out

    def masked_fill(self, mask, value):
        x = _to_numpy(self.data)
        mask_np = mask.to_numpy().astype(bool) if isinstance(mask, Tensor) else np.asarray(mask, dtype=bool)
        fill_value = value.item() if isinstance(value, Tensor) and value.shape == () else value
        out_data = np.where(mask_np, fill_value, x)
        out = Tensor(out_data, self.requires_grad, (self,), "masked_fill", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad * (~mask_np)

        out._backward = _backward
        return out

    def masked_select(self, mask):
        x = _to_numpy(self.data)
        mask_np = mask.to_numpy().astype(bool) if isinstance(mask, Tensor) else np.asarray(mask, dtype=bool)
        out_data = x[mask_np]
        out = Tensor(out_data, self.requires_grad, (self,), "masked_select", device=self.device)

        def _backward():
            if self.requires_grad:
                grad = np.zeros_like(x, dtype=self.grad.dtype)
                grad[mask_np] = out.grad
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

    def tile(self, dims):
        return self.repeat(dims)

    def flip(self, dims):
        x = _to_numpy(self.data)
        if isinstance(dims, int):
            dims = (dims,)
        elif isinstance(dims, list):
            dims = tuple(dims)
        if not isinstance(dims, tuple):
            raise TypeError("flip: dims must be int/tuple/list")

        norm_dims = []
        for dim in dims:
            dim = dim + x.ndim if dim < 0 else dim
            if dim < 0 or dim >= x.ndim:
                raise IndexError(f"flip: dim {dim} out of range for ndim {x.ndim}")
            norm_dims.append(dim)
        norm_dims = tuple(norm_dims)

        out = Tensor(np.flip(x, axis=norm_dims), self.requires_grad, (self,), "flip", device=self.device)

        def _backward():
            if self.requires_grad:
                self.grad += np.flip(out.grad, axis=norm_dims)

        out._backward = _backward
        return out

    def roll(self, shifts, dims=None):
        x = _to_numpy(self.data)

        if dims is None:
            out_data = np.roll(x, shifts)
            out = Tensor(out_data, self.requires_grad, (self,), "roll", device=self.device)

            def _backward():
                if self.requires_grad:
                    self.grad += np.roll(out.grad, -shifts)

            out._backward = _backward
            return out

        if isinstance(dims, int):
            dims = (dims,)
        elif isinstance(dims, list):
            dims = tuple(dims)
        if isinstance(shifts, int):
            shifts = (shifts,)
        elif isinstance(shifts, list):
            shifts = tuple(shifts)

        if not isinstance(dims, tuple) or not isinstance(shifts, tuple):
            raise TypeError("roll: shifts/dims must be int/tuple/list")
        if len(shifts) != len(dims):
            raise ValueError("roll: shifts and dims must have the same length")

        norm_dims = tuple(d + x.ndim if d < 0 else d for d in dims)
        out = Tensor(np.roll(x, shifts, axis=norm_dims), self.requires_grad, (self,), "roll", device=self.device)

        def _backward():
            if self.requires_grad:
                neg_shifts = tuple(-s for s in shifts)
                self.grad += np.roll(out.grad, neg_shifts, axis=norm_dims)

        out._backward = _backward
        return out

    def moveaxis(self, source, destination):
        x = _to_numpy(self.data)
        out_data = np.moveaxis(x, source, destination)
        out = Tensor(out_data, self.requires_grad, (self,), "moveaxis", device=self.device)

        src = source if isinstance(source, tuple) else (source,)
        dst = destination if isinstance(destination, tuple) else (destination,)
        ndim = x.ndim
        src = tuple(s + ndim if s < 0 else s for s in src)
        dst = tuple(d + ndim if d < 0 else d for d in dst)

        order = [i for i in range(ndim) if i not in src]
        for d, s in sorted(zip(dst, src)):
            order.insert(d, s)
        inv_order = np.argsort(order)

        def _backward():
            if self.requires_grad:
                self.grad += out.grad.transpose(inv_order)

        out._backward = _backward
        return out

    def movedim(self, source, destination):
        return self.moveaxis(source, destination)

    def argsort(self, axis=-1, descending=False, dim=None):
        if dim is not None:
            axis = dim
        x = _to_numpy(self.data)
        axis = axis + x.ndim if axis < 0 else axis
        idx = np.argsort(x, axis=axis)
        if descending:
            idx = np.flip(idx, axis=axis)
        return Tensor(idx.astype(np.int64, copy=False), requires_grad=False, device=self.device)

    def sort(self, axis=-1, descending=False, dim=None):
        if dim is not None:
            axis = dim
        x = _to_numpy(self.data)
        axis = axis + x.ndim if axis < 0 else axis
        idx = np.argsort(x, axis=axis)
        if descending:
            idx = np.flip(idx, axis=axis)
        out_data = np.take_along_axis(x, idx, axis=axis)
        out = Tensor(out_data, self.requires_grad, (self,), "sort", device=self.device)
        idx_t = Tensor(idx.astype(np.int64, copy=False), requires_grad=False, device=self.device)

        def _backward():
            if self.requires_grad:
                grad = np.zeros_like(x, dtype=self.grad.dtype)
                np.put_along_axis(grad, idx, out.grad, axis=axis)
                self.grad += grad

        out._backward = _backward
        return out, idx_t

    def topk(self, k, dim=-1, largest=True, sorted=True):
        x = _to_numpy(self.data)
        dim = dim + x.ndim if dim < 0 else dim
        if k < 0 or k > x.shape[dim]:
            raise ValueError("topk: k must satisfy 0 <= k <= size(dim)")

        if k == 0:
            out_shape = list(x.shape)
            out_shape[dim] = 0
            empty_vals = np.empty(out_shape, dtype=x.dtype)
            empty_idx = np.empty(out_shape, dtype=np.int64)
            return Tensor(empty_vals, self.requires_grad, (self,), "topk", device=self.device), Tensor(
                empty_idx, requires_grad=False, device=self.device
            )

        if largest:
            part_idx = np.argpartition(-x, k - 1, axis=dim)
        else:
            part_idx = np.argpartition(x, k - 1, axis=dim)

        slicer = [slice(None)] * x.ndim
        slicer[dim] = slice(0, k)
        topk_idx = part_idx[tuple(slicer)]
        topk_vals = np.take_along_axis(x, topk_idx, axis=dim)

        if sorted:
            order = np.argsort(-topk_vals if largest else topk_vals, axis=dim)
            topk_vals = np.take_along_axis(topk_vals, order, axis=dim)
            topk_idx = np.take_along_axis(topk_idx, order, axis=dim)

        out = Tensor(topk_vals, self.requires_grad, (self,), "topk", device=self.device)
        idx_t = Tensor(topk_idx.astype(np.int64, copy=False), requires_grad=False, device=self.device)

        def _backward():
            if self.requires_grad:
                grad = np.zeros_like(x, dtype=self.grad.dtype)
                np.add.at(
                    grad,
                    tuple(
                        topk_idx if ax == dim else np.indices(topk_idx.shape)[ax]
                        for ax in range(x.ndim)
                    ),
                    out.grad,
                )
                self.grad += grad

        out._backward = _backward
        return out, idx_t

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

    def sub_(self, other):
        """In-place subtraction: self -= other"""
        other_t = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        out = _to_numpy(self.data) - _to_numpy(other_t.data)
        self.data = _to_data_on_device(out, self.device)
        return self

    def div_(self, other):
        """In-place division: self /= other"""
        other_t = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        out = _to_numpy(self.data) / _to_numpy(other_t.data)
        self.data = _to_data_on_device(out, self.device)
        return self

    def pow_(self, other):
        """In-place power: self **= other"""
        other_t = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        out = _to_numpy(self.data) ** _to_numpy(other_t.data)
        self.data = _to_data_on_device(out, self.device)
        return self

    def copy_(self, other):
        """In-place copy: self = copy of other"""
        other_t = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        if other_t.shape != self.shape:
            raise ValueError(f"copy_: shape mismatch {other_t.shape} vs {self.shape}")
        self.data = _to_data_on_device(_to_numpy(other_t.data).copy(), self.device)
        return self

    def fill_(self, value):
        """In-place fill: fill all elements with value"""
        arr = _to_numpy(self.data)
        arr.fill(value)
        self.data = _to_data_on_device(arr, self.device)
        return self

    def zero_(self):
        """In-place zero: fill all elements with 0"""
        arr = _to_numpy(self.data)
        arr.fill(0.0)
        self.data = _to_data_on_device(arr, self.device)
        return self

    # ========== In-place Mathematical Operations ==========

    def exp_(self):
        """In-place exponential: e^x"""
        out_data = np.exp(_to_numpy(self.data))
        self.data = _to_data_on_device(out_data, self.device)
        return self

    def log_(self):
        """In-place natural logarithm"""
        x = _to_numpy(self.data)
        out_data = np.log(np.maximum(x, 1e-12))
        self.data = _to_data_on_device(out_data, self.device)
        return self

    def log10_(self):
        """In-place base-10 logarithm"""
        x = _to_numpy(self.data)
        out_data = np.log10(np.maximum(x, 1e-12))
        self.data = _to_data_on_device(out_data, self.device)
        return self

    def log2_(self):
        """In-place base-2 logarithm"""
        x = _to_numpy(self.data)
        out_data = np.log2(np.maximum(x, 1e-12))
        self.data = _to_data_on_device(out_data, self.device)
        return self

    def sqrt_(self):
        """In-place square root"""
        out_data = np.sqrt(np.maximum(_to_numpy(self.data), 0))
        self.data = _to_data_on_device(out_data, self.device)
        return self

    def sin_(self):
        """In-place sine function"""
        out_data = np.sin(_to_numpy(self.data))
        self.data = _to_data_on_device(out_data, self.device)
        return self

    def cos_(self):
        """In-place cosine function"""
        out_data = np.cos(_to_numpy(self.data))
        self.data = _to_data_on_device(out_data, self.device)
        return self

    def tan_(self):
        """In-place tangent function"""
        out_data = np.tan(_to_numpy(self.data))
        self.data = _to_data_on_device(out_data, self.device)
        return self

    def tanh_(self):
        """In-place hyperbolic tangent function"""
        out_data = np.tanh(_to_numpy(self.data))
        self.data = _to_data_on_device(out_data, self.device)
        return self

    def sigmoid_(self):
        """In-place sigmoid activation"""
        x = _to_numpy(self.data)
        sigmoid_data = np.where(
            x >= 0,
            1.0 / (1.0 + np.exp(-x)),
            np.exp(x) / (1.0 + np.exp(x))
        )
        self.data = _to_data_on_device(sigmoid_data, self.device)
        return self

    def abs_(self):
        """In-place absolute value"""
        out_data = np.abs(_to_numpy(self.data))
        self.data = _to_data_on_device(out_data, self.device)
        return self

    def clamp_(self, min=None, max=None):
        """In-place clamp: restrict values to [min, max]"""
        if min is None and max is None:
            raise ValueError("clamp_: at least one of min/max must be specified")
        x = _to_numpy(self.data)
        if min is not None:
            min_val = min.item() if isinstance(min, Tensor) else min
            x = np.maximum(x, min_val)
        if max is not None:
            max_val = max.item() if isinstance(max, Tensor) else max
            x = np.minimum(x, max_val)
        self.data = _to_data_on_device(x, self.device)
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

    # ========== Logical Operations ==========

    def all(self, dim=None, keepdim=False):
        """Check if all elements are non-zero (true)
        
        Args:
            dim: Dimension along which to reduce (None = all)
            keepdim: Keep the reduced dimension
        
        Returns:
            Boolean tensor
        """
        x = _to_numpy(self.data).astype(bool)
        result = np.all(x, axis=dim, keepdims=keepdim)
        return Tensor(result.astype(np.float32), requires_grad=False, device=self.device)

    def any(self, dim=None, keepdim=False):
        """Check if any element is non-zero (true)
        
        Args:
            dim: Dimension along which to reduce (None = all)
            keepdim: Keep the reduced dimension
        
        Returns:
            Boolean tensor
        """
        x = _to_numpy(self.data).astype(bool)
        result = np.any(x, axis=dim, keepdims=keepdim)
        return Tensor(result.astype(np.float32), requires_grad=False, device=self.device)

    # ===== Phase 2: Padding Operations =====
    
    def pad(self, pad_width, mode='constant', value=0):
        """Pad the tensor with specified values
        
        Args:
            pad_width: Padding width for each dimension (tuple of tuples or list)
                      Format: ((before_1, after_1), ..., (before_n, after_n))
            mode: Padding mode ('constant', 'reflect', 'replicate', 'circular')
            value: Fill value for constant padding (default: 0)
        
        Returns:
            Padded tensor with gradient support
        """
        x = _to_numpy(self.data)
        
        # Normalize pad_width to tuple of tuples
        if isinstance(pad_width, int):
            pad_width = ((pad_width, pad_width),) * x.ndim
        elif isinstance(pad_width, (list, tuple)) and not isinstance(pad_width[0], (list, tuple)):
            # Convert flat list [1,1,2,2] to ((1,1), (2,2))
            if len(pad_width) % 2 != 0:
                raise ValueError("pad_width must have even length")
            pad_width = tuple((pad_width[i], pad_width[i+1]) for i in range(0, len(pad_width), 2))
        
        # Apply padding
        if mode == 'constant':
            out_data = np.pad(x, pad_width, mode='constant', constant_values=value)
        elif mode == 'reflect':
            out_data = np.pad(x, pad_width, mode='reflect')
        elif mode == 'replicate' or mode == 'edge':
            out_data = np.pad(x, pad_width, mode='edge')
        elif mode == 'circular' or mode == 'wrap':
            out_data = np.pad(x, pad_width, mode='wrap')
        else:
            raise ValueError(f"Unsupported padding mode: {mode}")
        
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self,), _op="pad", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # Remove padding from gradient
                slices = tuple(slice(before, out.grad.shape[i] - after) 
                              for i, (before, after) in enumerate(pad_width))
                self.grad += out.grad[slices]
        
        out._backward = _backward
        return out

    # ===== Phase 2: Matrix Operations =====
    
    def trace(self):
        """Compute the trace (sum of diagonal elements) of a 2D tensor
        
        Returns:
            Scalar tensor containing the trace
        """
        x = _to_numpy(self.data)
        if x.ndim != 2:
            raise ValueError(f"trace() requires 2D tensor, got {x.ndim}D")
        
        out_data = np.trace(x)
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self,), _op="trace", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # Gradient flows only through diagonal
                grad = np.zeros_like(x)
                np.fill_diagonal(grad, out.grad)
                self.grad += grad
        
        out._backward = _backward
        return out
    
    def det(self):
        """Compute the determinant of a 2D square matrix
        
        Returns:
            Scalar tensor containing the determinant
        """
        x = _to_numpy(self.data)
        if x.ndim != 2 or x.shape[0] != x.shape[1]:
            raise ValueError(f"det() requires square 2D tensor, got shape {x.shape}")
        
        out_data = np.linalg.det(x)
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self,), _op="det", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # Gradient: det(A) * A^(-T)
                inv_transpose = np.linalg.inv(x).T
                self.grad += out.grad * out_data * inv_transpose
        
        out._backward = _backward
        return out
    
    def matrix_rank(self, tol=None):
        """Compute the rank of a 2D matrix
        
        Args:
            tol: Tolerance for singular values (default: automatic)
        
        Returns:
            Integer rank (as a Tensor for consistency, but no gradient)
        """
        x = _to_numpy(self.data)
        if x.ndim != 2:
            raise ValueError(f"matrix_rank() requires 2D tensor, got {x.ndim}D")
        
        rank = np.linalg.matrix_rank(x, tol=tol)
        return Tensor(np.array(rank, dtype=np.float32), requires_grad=False, device=self.device)

    # ===== Phase 2: Cumulative Operations =====
    
    def cumsum(self, dim=0):
        """Compute cumulative sum along a dimension
        
        Args:
            dim: Dimension along which to compute cumsum
        
        Returns:
            Tensor with cumulative sum
        """
        x = _to_numpy(self.data)
        dim = _normalize_axis(dim, x.ndim)
        
        out_data = np.cumsum(x, axis=dim)
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self,), _op="cumsum", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # Gradient: reverse cumsum
                grad = np.flip(np.cumsum(np.flip(out.grad, axis=dim), axis=dim), axis=dim)
                self.grad += grad
        
        out._backward = _backward
        return out
    
    def cumprod(self, dim=0):
        """Compute cumulative product along a dimension
        
        Args:
            dim: Dimension along which to compute cumprod
        
        Returns:
            Tensor with cumulative product
        """
        x = _to_numpy(self.data)
        dim = _normalize_axis(dim, x.ndim)
        
        out_data = np.cumprod(x, axis=dim)
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self,), _op="cumprod", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # Gradient computation for cumprod
                # d/dx[cumprod(x)] = cumprod(x) * cumsum(1/x) from right
                grad = out.grad.copy()
                y = out_data
                
                # Avoid division by zero
                x_safe = x.copy()
                x_safe[x_safe == 0] = 1e-20
                
                # Compute gradient: y_i * sum(grad_j / x_j) for j >= i
                grad_cumsum = np.flip(np.cumsum(np.flip(grad / x_safe, axis=dim), axis=dim), axis=dim)
                self.grad += y * grad_cumsum
        
        out._backward = _backward
        return out

    # ===== Phase 2: Inverse Trigonometric Functions =====
    
    def asin(self):
        """Compute arcsine (inverse sine) element-wise
        
        Returns:
            Tensor with arcsine applied
        """
        x = _to_numpy(self.data)
        out_data = np.arcsin(x)
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self,), _op="asin", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # Gradient: 1 / sqrt(1 - x^2)
                grad_mask = 1.0 / np.sqrt(1.0 - x**2 + 1e-8)
                self.grad += out.grad * grad_mask
        
        out._backward = _backward
        return out
    
    def acos(self):
        """Compute arccosine (inverse cosine) element-wise
        
        Returns:
            Tensor with arccosine applied
        """
        x = _to_numpy(self.data)
        out_data = np.arccos(x)
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self,), _op="acos", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # Gradient: -1 / sqrt(1 - x^2)
                grad_mask = -1.0 / np.sqrt(1.0 - x**2 + 1e-8)
                self.grad += out.grad * grad_mask
        
        out._backward = _backward
        return out
    
    def atan(self):
        """Compute arctangent (inverse tangent) element-wise
        
        Returns:
            Tensor with arctangent applied
        """
        x = _to_numpy(self.data)
        out_data = np.arctan(x)
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self,), _op="atan", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # Gradient: 1 / (1 + x^2)
                grad_mask = 1.0 / (1.0 + x**2)
                self.grad += out.grad * grad_mask
        
        out._backward = _backward
        return out

    # ===== Phase 2: Hyperbolic Functions =====
    
    def sinh(self):
        """Compute hyperbolic sine element-wise
        
        Returns:
            Tensor with sinh applied
        """
        x = _to_numpy(self.data)
        out_data = np.sinh(x)
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self,), _op="sinh", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # Gradient: cosh(x)
                grad_mask = np.cosh(x)
                self.grad += out.grad * grad_mask
        
        out._backward = _backward
        return out
    
    def cosh(self):
        """Compute hyperbolic cosine element-wise
        
        Returns:
            Tensor with cosh applied
        """
        x = _to_numpy(self.data)
        out_data = np.cosh(x)
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self,), _op="cosh", device=self.device)
        
        def _backward():
            if self.requires_grad:
                # Gradient: sinh(x)
                grad_mask = np.sinh(x)
                self.grad += out.grad * grad_mask
        
        out._backward = _backward
        return out

    # ============================================================
    # Phase 3: Advanced Tensor Operations
    # ============================================================
    
    # Phase 3.1: Basic Math Operations
    
    def floor(self):
        """Floor function (round down to nearest integer)
        
        Returns:
            Tensor with floor applied
        """
        x = _to_numpy(self.data)
        out_data = np.floor(x)
        out = Tensor(out_data, requires_grad=False, _children=(self,), _op="floor", device=self.device)
        
        # Floor is not differentiable, so no gradient
        def _backward():
            pass
        
        out._backward = _backward
        return out

    def ceil(self):
        """Ceiling function (round up to nearest integer)
        
        Returns:
            Tensor with ceil applied
        """
        x = _to_numpy(self.data)
        out_data = np.ceil(x)
        out = Tensor(out_data, requires_grad=False, _children=(self,), _op="ceil", device=self.device)
        
        # Ceil is not differentiable, so no gradient
        def _backward():
            pass
        
        out._backward = _backward
        return out

    def round(self):
        """Round to nearest integer
        
        Returns:
            Tensor with round applied
        """
        x = _to_numpy(self.data)
        out_data = np.round(x)
        out = Tensor(out_data, requires_grad=False, _children=(self,), _op="round", device=self.device)
        
        # Round is not differentiable, so no gradient
        def _backward():
            pass
        
        out._backward = _backward
        return out

    def lerp(self, other, weight):
        """Linear interpolation: self * (1 - weight) + other * weight
        
        Args:
            other: Another Tensor
            weight: Interpolation weight (0 <= weight <= 1)
        
        Returns:
            Interpolated Tensor
        """
        other = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        w = weight if isinstance(weight, (int, float)) else weight
        
        x = _to_numpy(self.data)
        other_data = _to_numpy(other.data)
        
        if isinstance(w, Tensor):
            w_val = _to_numpy(w.data)
        else:
            w_val = w
        
        out_data = x * (1 - w_val) + other_data * w_val
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self, other), 
                     _op="lerp", device=self.device)
        
        def _backward():
            if self.requires_grad:
                if isinstance(w, Tensor):
                    w_val = _to_numpy(w.data)
                else:
                    w_val = w
                self.grad += out.grad * (1 - w_val)
            if other.requires_grad:
                if isinstance(w, Tensor):
                    w_val = _to_numpy(w.data)
                else:
                    w_val = w
                other.grad += _unbroadcast(out.grad * w_val, other.shape)
        
        out._backward = _backward
        return out

    def where(self, condition, other):
        """Select elements from self or other based on condition
        
        Args:
            condition: Boolean tensor (same shape as self)
            other: Tensor to select from when condition is False
        
        Returns:
            Tensor with selected elements
        """
        condition = _to_numpy(condition.data) if isinstance(condition, Tensor) else condition
        other = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        
        x = _to_numpy(self.data)
        other_data = _to_numpy(other.data)
        
        out_data = np.where(condition, x, other_data)
        out = Tensor(out_data, requires_grad=self.requires_grad, _children=(self, other),
                     _op="where", device=self.device)
        
        def _backward():
            if self.requires_grad:
                self.grad += out.grad * condition
            if other.requires_grad:
                other.grad += _unbroadcast(out.grad * ~condition, other.shape)
        
        out._backward = _backward
        return out

    # Phase 3.3: Tensor Operations (Concatenation/Splitting)
    
    def split(self, split_size, dim=0):
        """Split tensor into chunks of given size or at given indices
        
        Args:
            split_size: Size of each split or list of indices to split at
            dim: Dimension to split along
        
        Returns:
            List of Tensors
        """
        x = _to_numpy(self.data)
        
        # Handle negative dim
        if dim < 0:
            dim = len(self.shape) + dim
        
        # Handle list of sizes
        if isinstance(split_size, (list, tuple)):
            # If it's a list of sizes, convert to indices
            indices = []
            cumsum = 0
            for size in split_size[:-1]:  # Don't include last one
                cumsum += size
                indices.append(cumsum)
            splits = np.split(x, indices, axis=dim)
        else:
            # Handle single size
            num_splits = (self.shape[dim] + split_size - 1) // split_size
            indices = [i * split_size for i in range(1, num_splits)]
            splits = np.split(x, indices, axis=dim)
        
        result = [Tensor(s, requires_grad=self.requires_grad, _children=(self,), 
                        _op="split", device=self.device) for s in splits]
        
        # Set backward for all splits
        def make_backward(split_list):
            def _backward():
                if self.requires_grad:
                    # Concatenate gradients back
                    grad_parts = [split_list[i].grad for i in range(len(split_list))]
                    self.grad += np.concatenate(grad_parts, axis=dim)
            return _backward
        
        for r in result:
            r._backward = make_backward(result)
        
        return result

    def chunk(self, chunks, dim=0):
        """Split tensor into given number of chunks
        
        Args:
            chunks: Number of chunks
            dim: Dimension to split along
        
        Returns:
            List of Tensors
        """
        x = _to_numpy(self.data)
        
        # Handle negative dim
        if dim < 0:
            dim = len(self.shape) + dim
        
        # Calculate split size
        size = (self.shape[dim] + chunks - 1) // chunks
        split_list = np.array_split(x, chunks, axis=dim)
        
        result = [Tensor(s, requires_grad=self.requires_grad, _children=(self,),
                        _op="chunk", device=self.device) for s in split_list]
        
        # Set backward for all chunks
        def make_backward(chunk_list):
            def _backward():
                if self.requires_grad:
                    grad_parts = [chunk_list[i].grad for i in range(len(chunk_list))]
                    self.grad += np.concatenate(grad_parts, axis=dim)
            return _backward
        
        for r in result:
            r._backward = make_backward(result)
        
        return result

    @staticmethod
    def cat(tensors, dim=0):
        """Concatenate tensors along a dimension
        
        Args:
            tensors: List of Tensors to concatenate
            dim: Dimension to concatenate along
        
        Returns:
            Concatenated Tensor
        """
        if len(tensors) == 0:
            raise ValueError("cat expects at least one tensor")
        
        # Handle negative dim
        if dim < 0:
            dim = len(tensors[0].shape) + dim
        
        # Convert to numpy
        arrays = [_to_numpy(t.data) for t in tensors]
        out_data = np.concatenate(arrays, axis=dim)
        
        # Check if any requires grad
        requires_grad = any(t.requires_grad for t in tensors)
        device = tensors[0].device
        
        out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(tensors),
                    _op="cat", device=device)
        
        def _backward():
            # Split gradients back to each tensor
            splits = np.split(out.grad, [sum(t.shape[dim] for t in tensors[:i+1]) 
                                         for i in range(len(tensors)-1)], axis=dim)
            for t, grad in zip(tensors, splits):
                if t.requires_grad:
                    t.grad += grad
        
        out._backward = _backward
        return out

    @staticmethod
    def stack(tensors, dim=0):
        """Stack tensors along a new dimension
        
        Args:
            tensors: List of Tensors with same shape
            dim: Dimension to insert
        
        Returns:
            Stacked Tensor
        """
        if len(tensors) == 0:
            raise ValueError("stack expects at least one tensor")
        
        # Handle negative dim
        if dim < 0:
            dim = len(tensors[0].shape) + 1 + dim
        
        # Convert to numpy
        arrays = [_to_numpy(t.data) for t in tensors]
        out_data = np.stack(arrays, axis=dim)
        
        # Check if any requires grad
        requires_grad = any(t.requires_grad for t in tensors)
        device = tensors[0].device
        
        out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(tensors),
                    _op="stack", device=device)
        
        def _backward():
            # Unstack gradients
            split_grads = np.split(out.grad, len(tensors), axis=dim)
            for t, grad in zip(tensors, split_grads):
                if t.requires_grad:
                    t.grad += np.squeeze(grad, axis=dim)
        
        out._backward = _backward
        return out

    # Phase 3.4: Comparison Operations
    
    def gt(self, other):
        """Greater than comparison
        
        Args:
            other: Tensor or scalar
        
        Returns:
            Boolean Tensor
        """
        other = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        x = _to_numpy(self.data)
        other_data = _to_numpy(other.data)
        
        out_data = x > other_data
        out = Tensor(out_data.astype(np.float32), requires_grad=False, 
                    _children=(self, other), _op="gt", device=self.device)
        
        def _backward():
            pass
        
        out._backward = _backward
        return out

    def lt(self, other):
        """Less than comparison
        
        Args:
            other: Tensor or scalar
        
        Returns:
            Boolean Tensor
        """
        other = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        x = _to_numpy(self.data)
        other_data = _to_numpy(other.data)
        
        out_data = x < other_data
        out = Tensor(out_data.astype(np.float32), requires_grad=False,
                    _children=(self, other), _op="lt", device=self.device)
        
        def _backward():
            pass
        
        out._backward = _backward
        return out

    def ge(self, other):
        """Greater than or equal comparison
        
        Args:
            other: Tensor or scalar
        
        Returns:
            Boolean Tensor
        """
        other = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        x = _to_numpy(self.data)
        other_data = _to_numpy(other.data)
        
        out_data = x >= other_data
        out = Tensor(out_data.astype(np.float32), requires_grad=False,
                    _children=(self, other), _op="ge", device=self.device)
        
        def _backward():
            pass
        
        out._backward = _backward
        return out

    def le(self, other):
        """Less than or equal comparison
        
        Args:
            other: Tensor or scalar
        
        Returns:
            Boolean Tensor
        """
        other = other if isinstance(other, Tensor) else Tensor(other, device=self.device)
        x = _to_numpy(self.data)
        other_data = _to_numpy(other.data)
        
        out_data = x <= other_data
        out = Tensor(out_data.astype(np.float32), requires_grad=False,
                    _children=(self, other), _op="le", device=self.device)
        
        def _backward():
            pass
        
        out._backward = _backward
        return out

    def isnan(self):
        """Check for NaN values
        
        Returns:
            Boolean Tensor
        """
        x = _to_numpy(self.data)
        out_data = np.isnan(x)
        out = Tensor(out_data.astype(np.float32), requires_grad=False, _children=(self,),
                    _op="isnan", device=self.device)
        
        def _backward():
            pass
        
        out._backward = _backward
        return out

    def isinf(self):
        """Check for infinity values
        
        Returns:
            Boolean Tensor
        """
        x = _to_numpy(self.data)
        out_data = np.isinf(x)
        out = Tensor(out_data.astype(np.float32), requires_grad=False, _children=(self,),
                    _op="isinf", device=self.device)
        
        def _backward():
            pass
        
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

    def __array__(self, dtype=None):
        arr = self.to_numpy()
        if dtype is not None:
            return arr.astype(dtype, copy=False)
        return arr

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
        """Convert to float32 (default float type)"""
        return self.to(dtype=np.float32)

    def double(self):
        """Convert to float64 (double precision)"""
        return self.to(dtype=np.float64)

    def half(self):
        """Convert to float16 (half precision) - limited gradient support"""
        return self.to(dtype=np.float16)

    def float16(self):
        """Alias for half() - convert to float16"""
        return self.half()

    def float32(self):
        """Alias for float() - convert to float32"""
        return self.float()

    def float64(self):
        """Alias for double() - convert to float64"""
        return self.double()

    def int32(self):
        """Convert to int32"""
        return self.to(dtype=np.int32)

    def int64(self):
        """Convert to int64"""
        return self.to(dtype=np.int64)

    def long(self):
        return self.to(dtype=np.int64)


def where(condition, x=None, y=None):
    cond = condition.to_numpy() if isinstance(condition, Tensor) else np.asarray(condition)

    if x is None and y is None:
        # PyTorch-compatible single-argument form:
        # torch.where(condition) -> tuple of index tensors
        indices = np.nonzero(cond)
        if isinstance(indices, tuple):
            return tuple(Tensor(idx.astype(np.int64, copy=False), requires_grad=False) for idx in indices)
        return (Tensor(np.asarray(indices).astype(np.int64, copy=False), requires_grad=False),)

    if (x is None) != (y is None):
        raise ValueError("where expected both x and y when using ternary form")

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


def softmax(input, dim=-1):
    t = input if isinstance(input, Tensor) else Tensor(input)
    return t.softmax(dim=dim)


def log_softmax(input, dim=-1):
    t = input if isinstance(input, Tensor) else Tensor(input)
    return t.log_softmax(dim=dim)


def take_along_dim(input, indices, dim=-1):
    t = input if isinstance(input, Tensor) else Tensor(input)
    return t.take_along_dim(indices, dim=dim)


def clamp(input, min=None, max=None):
    t = input if isinstance(input, Tensor) else Tensor(input)
    return t.clamp(min=min, max=max)


def clip(input, min=None, max=None):
    t = input if isinstance(input, Tensor) else Tensor(input)
    return t.clip(min=min, max=max)


def sign(input):
    t = input if isinstance(input, Tensor) else Tensor(input)
    return t.sign()


def flip(input, dims):
    t = input if isinstance(input, Tensor) else Tensor(input)
    return t.flip(dims)


def roll(input, shifts, dims=None):
    t = input if isinstance(input, Tensor) else Tensor(input)
    return t.roll(shifts, dims=dims)


def tile(input, dims):
    t = input if isinstance(input, Tensor) else Tensor(input)
    return t.tile(dims)


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


def split(neurx, split_size_or_sections, axis=0, dim=None):
    if dim is not None:
        axis = dim
    t = neurx if isinstance(neurx, Tensor) else Tensor(neurx)
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


def chunk(neurx, chunks, axis=0, dim=None):
    if dim is not None:
        axis = dim
    t = neurx if isinstance(neurx, Tensor) else Tensor(neurx)
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
    """Create a neurx filled with zeros.
    
    Args:
        *shape: Shape of the neurx (int or tuple)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.zeros(2, 3)
        >>> neurx.zeros((2, 3), device='cuda')
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    dtype = dtype or np.float32
    data = np.zeros(shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def ones(*shape, dtype=None, requires_grad=False, device=None):
    """Create a neurx filled with ones.
    
    Args:
        *shape: Shape of the neurx (int or tuple)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.ones(2, 3)
        >>> neurx.ones((2, 3), dtype=np.int32)
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    dtype = dtype or np.float32
    data = np.ones(shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def full(shape, fill_value, dtype=None, requires_grad=False, device=None):
    """Create a neurx filled with a specific value.
    
    Args:
        shape: Shape of the neurx
        fill_value: Value to fill the neurx with
        dtype: Data type (default: inferred from fill_value)
        requires_grad: Whether to track gradients
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.full((2, 3), 7.5)
    """
    if isinstance(shape, int):
        shape = (shape,)
    data = np.full(shape, fill_value, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def empty(*shape, dtype=None, requires_grad=False, device=None):
    """Create an uninitialized neurx.
    
    Args:
        *shape: Shape of the neurx (int or tuple)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.empty(2, 3)
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    dtype = dtype or np.float32
    data = np.empty(shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def rand(*shape, dtype=None, requires_grad=False, device=None):
    """Create a neurx with random values from uniform distribution [0, 1).
    
    Args:
        *shape: Shape of the neurx (int or tuple)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.rand(2, 3)
        >>> neurx.rand((2, 3), device='cuda')
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    dtype = dtype or np.float32
    data = np.random.rand(*shape).astype(dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def randn(*shape, dtype=None, requires_grad=False, device=None):
    """Create a neurx with random values from standard normal distribution.
    
    Args:
        *shape: Shape of the neurx (int or tuple)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.randn(2, 3)
        >>> neurx.randn((2, 3), device='cuda')
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    dtype = dtype or np.float32
    data = np.random.randn(*shape).astype(dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def randint(low, high, shape, dtype=None, requires_grad=False, device=None):
    """Create a neurx with random integers from [low, high).
    
    Args:
        low: Lowest integer (inclusive)
        high: Highest integer (exclusive)
        shape: Shape of the neurx
        dtype: Data type (default: int64)
        requires_grad: Whether to track gradients (typically False for integers)
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.randint(0, 10, (2, 3))
    """
    if isinstance(shape, int):
        shape = (shape,)
    dtype = dtype or np.int64
    data = np.random.randint(low, high, size=shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def arange(start, end=None, step=1, dtype=None, requires_grad=False, device=None):
    """Create a 1D neurx with evenly spaced values.
    
    Args:
        start: Start value (or end if end is None)
        end: End value (exclusive)
        step: Spacing between values
        dtype: Data type (default: inferred)
        requires_grad: Whether to track gradients
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.arange(10)        # [0, 1, 2, ..., 9]
        >>> neurx.arange(2, 10, 2)  # [2, 4, 6, 8]
    """
    if end is None:
        end = start
        start = 0
    data = np.arange(start, end, step, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def linspace(start, end, steps, dtype=None, requires_grad=False, device=None):
    """Create a 1D neurx with linearly spaced values.
    
    Args:
        start: Start value
        end: End value (inclusive)
        steps: Number of values
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.linspace(0, 1, 5)  # [0.0, 0.25, 0.5, 0.75, 1.0]
    """
    dtype = dtype or np.float32
    data = np.linspace(start, end, steps, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def logspace(start, end, steps, base=10.0, dtype=None, requires_grad=False, device=None):
    """Create a 1D neurx with logarithmically spaced values.
    
    Args:
        start: Start exponent
        end: End exponent
        steps: Number of values
        base: Base of the logarithm (default: 10)
        dtype: Data type (default: float32)
        requires_grad: Whether to track gradients
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.logspace(0, 3, 4)  # [1, 10, 100, 1000]
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
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.eye(3)
        >>> neurx.eye(3, 4)
    """
    dtype = dtype or np.float32
    data = np.eye(n, m, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def diag(v, k=0, dtype=None, requires_grad=False, device=None):
    """Create a diagonal matrix from a vector or extract diagonal from matrix.
    
    Args:
        v: 1D or 2D neurx/array
        k: Diagonal offset (0=main diagonal, positive=above, negative=below)
        dtype: Data type
        requires_grad: Whether to track gradients
        device: Device to place neurx on ('cpu' or 'cuda')
    
    Example:
        >>> neurx.diag([1, 2, 3])
        >>> neurx.diag(neurx.ones(3, 3), k=1)
    """
    v_data = v.to_numpy() if isinstance(v, Tensor) else np.asarray(v)
    data = np.diag(v_data, k=k)
    if dtype is not None:
        data = data.astype(dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def zeros_like(input, dtype=None, requires_grad=False, device=None):
    """Create a neurx of zeros with the same shape as input.
    
    Args:
        input: Input neurx to match shape
        dtype: Data type (default: same as input)
        requires_grad: Whether to track gradients
        device: Device to place neurx on (default: same as input)
    
    Example:
        >>> x = neurx.rand(2, 3)
        >>> neurx.zeros_like(x)
    """
    shape = input.shape if isinstance(input, Tensor) else np.asarray(input).shape
    device = device or (input.device if isinstance(input, Tensor) else None)
    dtype = dtype or (input.dtype if isinstance(input, Tensor) else np.asarray(input).dtype)
    return zeros(*shape, dtype=dtype, requires_grad=requires_grad, device=device)


def ones_like(input, dtype=None, requires_grad=False, device=None):
    """Create a neurx of ones with the same shape as input.
    
    Args:
        input: Input neurx to match shape
        dtype: Data type (default: same as input)
        requires_grad: Whether to track gradients
        device: Device to place neurx on (default: same as input)
    
    Example:
        >>> x = neurx.rand(2, 3)
        >>> neurx.ones_like(x)
    """
    shape = input.shape if isinstance(input, Tensor) else np.asarray(input).shape
    device = device or (input.device if isinstance(input, Tensor) else None)
    dtype = dtype or (input.dtype if isinstance(input, Tensor) else np.asarray(input).dtype)
    return ones(*shape, dtype=dtype, requires_grad=requires_grad, device=device)


def full_like(input, fill_value, dtype=None, requires_grad=False, device=None):
    """Create a neurx filled with a value, matching the shape of input.
    
    Args:
        input: Input neurx to match shape
        fill_value: Value to fill with
        dtype: Data type (default: same as input)
        requires_grad: Whether to track gradients
        device: Device to place neurx on (default: same as input)
    
    Example:
        >>> x = neurx.rand(2, 3)
        >>> neurx.full_like(x, 7.5)
    """
    shape = input.shape if isinstance(input, Tensor) else np.asarray(input).shape
    device = device or (input.device if isinstance(input, Tensor) else None)
    dtype = dtype or (input.dtype if isinstance(input, Tensor) else np.asarray(input).dtype)
    return full(shape, fill_value, dtype=dtype, requires_grad=requires_grad, device=device)


def meshgrid(*tensors, indexing='xy'):
    """
    Creates coordinate matrices from coordinate vectors.
    
    Args:
        *tensors: 1D tensors representing coordinates for each dimension
        indexing: Either 'xy' (Cartesian) or 'ij' (matrix) indexing
    
    Returns:
        Tuple of tensors representing coordinate grids
    
    Example:
        >>> x = neurx.arange(3)
        >>> y = neurx.arange(4)
        >>> X, Y = neurx.meshgrid(x, y)
        >>> X.shape  # (4, 3) with indexing='xy'
        >>> Y.shape  # (4, 3)
        
        >>> # Create a 2D grid for coordinates
        >>> x = neurx.linspace(-1, 1, 100)
        >>> y = neurx.linspace(-1, 1, 100)
        >>> X, Y = neurx.meshgrid(x, y)
        >>> # Now X and Y are 100x100 grids
    """
    if len(tensors) == 0:
        raise ValueError("meshgrid requires at least one neurx")
    
    # Convert all inputs to Tensor if needed
    tensors = [t if isinstance(t, Tensor) else Tensor(t) for t in tensors]
    
    # All tensors should be 1D
    for i, t in enumerate(tensors):
        if t.ndim != 1:
            raise ValueError(f"Expected 1D neurx for meshgrid, got {t.ndim}D neurx at position {i}")
    
    if indexing not in ('xy', 'ij'):
        raise ValueError(f"indexing must be 'xy' or 'ij', got {indexing}")
    
    # Get shapes
    shapes = [t.shape[0] for t in tensors]
    n = len(tensors)
    
    # Determine output shape based on indexing
    if indexing == 'xy' and n > 1:
        # Swap first two dimensions for Cartesian indexing
        output_shape = [shapes[1], shapes[0]] + shapes[2:]
    else:
        output_shape = shapes
    
    grids = []
    for i, t in enumerate(tensors):
        # Create shape for broadcasting
        view_shape = [1] * n
        
        if indexing == 'xy' and n > 1:
            # For Cartesian indexing
            if i == 0:
                view_shape[1] = -1
            elif i == 1:
                view_shape[0] = -1
            else:
                view_shape[i] = -1
        else:
            # For matrix indexing
            view_shape[i] = -1
        
        # Reshape and broadcast
        data = _to_numpy(t.data).reshape(view_shape)
        broadcasted = np.broadcast_to(data, output_shape)
        grids.append(Tensor(broadcasted.copy(), device=t.device))
    
    return tuple(grids)


def rand_like(input, dtype=None, requires_grad=False, device=None):
    """Create a neurx of random values [0, 1) with the same shape as input.
    
    Args:
        input: Input neurx to match shape
        dtype: Data type (default: same as input)
        requires_grad: Whether to track gradients
        device: Device to place neurx on (default: same as input)
    
    Example:
        >>> x = neurx.rand(2, 3)
        >>> neurx.rand_like(x)
    """
    shape = input.shape if isinstance(input, Tensor) else np.asarray(input).shape
    device = device or (input.device if isinstance(input, Tensor) else None)
    dtype = dtype or (input.dtype if isinstance(input, Tensor) else np.asarray(input).dtype)
    return rand(*shape, dtype=dtype, requires_grad=requires_grad, device=device)


def randn_like(input, dtype=None, requires_grad=False, device=None):
    """Create a neurx of random normal values with the same shape as input.
    
    Args:
        input: Input neurx to match shape
        dtype: Data type (default: same as input)
        requires_grad: Whether to track gradients
        device: Device to place neurx on (default: same as input)
    
    Example:
        >>> x = neurx.rand(2, 3)
        >>> neurx.randn_like(x)
    """
    shape = input.shape if isinstance(input, Tensor) else np.asarray(input).shape
    device = device or (input.device if isinstance(input, Tensor) else None)
    dtype = dtype or (input.dtype if isinstance(input, Tensor) else np.asarray(input).dtype)
    return randn(*shape, dtype=dtype, requires_grad=requires_grad, device=device)
