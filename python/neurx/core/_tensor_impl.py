from __future__ import annotations

from contextlib import contextmanager
from functools import reduce
from operator import mul
from typing import Any, Iterable

import numpy as np


_grad_enabled = True
_accelerator_available = False
_cuda_ops = None


def _ensure_array(x: Any) -> np.ndarray:
    if isinstance(x, np.ndarray):
        return x
    return np.asarray(x)


def _to_numpy(x: Any) -> np.ndarray:
    if isinstance(x, Tensor):
        return np.asarray(x.data)
    return np.asarray(x)


def _is_cuda_device(device: Any) -> bool:
    return str(device).startswith("cuda")


def _resolve_default_device(device: Any | None = None) -> str:
    return "cpu" if device is None else str(device)


def _runtime_tensor_array(x: Any) -> np.ndarray:
    return _to_numpy(x)


def _shape_of(x: Any) -> tuple[int, ...]:
    return tuple(_to_numpy(x).shape)


def _should_fallback_cuda_to_cpu(device: Any) -> bool:
    return _is_cuda_device(device) and not _accelerator_available


def _to_data_on_device(data: Any, device: Any) -> np.ndarray:
    return _ensure_array(data)


def _sum_to_shape(grad: np.ndarray, shape: tuple[int, ...]) -> np.ndarray:
    grad = np.asarray(grad)
    if shape == grad.shape:
        return grad
    while grad.ndim > len(shape):
        grad = grad.sum(axis=0)
    for axis, dim in enumerate(shape):
        if dim == 1 and grad.shape[axis] != 1:
            grad = grad.sum(axis=axis, keepdims=True)
    return grad.reshape(shape)


def _coerce_tensor(value: Any, device: str | None = None) -> "Tensor":
    if isinstance(value, Tensor):
        return value
    return Tensor(value, requires_grad=False, device=device or "cpu")


class Tensor:
    def __init__(self, data: Any, requires_grad: bool = False, _children=(), _op: str = "", device: str = "cpu"):
        self.data = np.asarray(data)
        self.requires_grad = bool(requires_grad)
        self.grad = None
        self._prev = set(_children)
        self._op = _op
        self._backward = lambda: None
        self.device = device

    @property
    def shape(self) -> tuple[int, ...]:
        return tuple(self.data.shape)

    def __len__(self):
        if self.data.ndim == 0:
            raise TypeError("len() of a scalar tensor")
        return self.data.shape[0]

    @property
    def ndim(self) -> int:
        return self.data.ndim

    @property
    def dtype(self):
        return self.data.dtype

    def numel(self) -> int:
        return int(self.data.size)

    def clone(self) -> "Tensor":
        return Tensor(self.data.copy(), requires_grad=self.requires_grad, device=self.device)

    def detach(self) -> "Tensor":
        return Tensor(self.data.copy(), requires_grad=False, device=self.device)

    def numpy(self) -> np.ndarray:
        return np.array(self.data, copy=True)

    def to_numpy(self) -> np.ndarray:
        return self.numpy()

    def item(self):
        return self.data.item()

    def to(self, device: str):
        return Tensor(self.data.copy(), requires_grad=self.requires_grad, device=device)

    def cpu(self):
        return self.to("cpu")

    def cuda(self):
        return self.to("cuda")

    def mps(self):
        return self.to("mps")

    def requires_grad_(self, requires_grad: bool = True):
        self.requires_grad = bool(requires_grad)
        return self

    def zero_grad(self):
        self.grad = np.zeros_like(self.data, dtype=self.data.dtype)

    def backward(self, grad: Any | None = None):
        if not self.requires_grad:
            return
        if grad is None:
            grad = np.ones_like(self.data, dtype=self.data.dtype)
        self.grad = _ensure_array(grad)
        topo = []
        visited = set()

        def build(node: "Tensor"):
            if node not in visited:
                visited.add(node)
                for child in node._prev:
                    build(child)
                topo.append(node)

        build(self)
        for node in reversed(topo):
            node._backward()

    def _accum(self, grad: Any):
        grad = _ensure_array(grad)
        self.grad = grad if self.grad is None else self.grad + grad

    def __array__(self, dtype=None):
        return np.asarray(self.data, dtype=dtype)

    def __repr__(self):
        return f"Tensor({self.data!r}, requires_grad={self.requires_grad}, device={self.device!r})"

    def _binary(self, other: Any, op_name: str, forward, backward_self, backward_other):
        other = _coerce_tensor(other, self.device)
        out_data = forward(self.data, other.data)
        requires_grad = _grad_enabled and (self.requires_grad or other.requires_grad)
        out = Tensor(out_data, requires_grad=requires_grad, _children=(self, other), _op=op_name, device=self.device)

        def _backward():
            if out.grad is None:
                return
            if self.requires_grad:
                self._accum(_sum_to_shape(backward_self(out.grad, self.data, other.data), self.data.shape))
            if other.requires_grad:
                other._accum(_sum_to_shape(backward_other(out.grad, self.data, other.data), other.data.shape))

        out._backward = _backward
        return out

    def __add__(self, other):
        return self._binary(other, "add", np.add, lambda g, a, b: g, lambda g, a, b: g)

    def __radd__(self, other):
        return self.__add__(other)

    def __sub__(self, other):
        return self._binary(other, "sub", np.subtract, lambda g, a, b: g, lambda g, a, b: -g)

    def __rsub__(self, other):
        return _coerce_tensor(other, self.device).__sub__(self)

    def __mul__(self, other):
        return self._binary(other, "mul", np.multiply, lambda g, a, b: g * b, lambda g, a, b: g * a)

    def __rmul__(self, other):
        return self.__mul__(other)

    def __truediv__(self, other):
        return self._binary(other, "div", np.divide, lambda g, a, b: g / b, lambda g, a, b: -g * a / (b * b))

    def __rtruediv__(self, other):
        return _coerce_tensor(other, self.device).__truediv__(self)

    def __neg__(self):
        return self * -1

    def __matmul__(self, other):
        other = _coerce_tensor(other, self.device)
        out_data = self.data @ other.data
        requires_grad = _grad_enabled and (self.requires_grad or other.requires_grad)
        out = Tensor(out_data, requires_grad=requires_grad, _children=(self, other), _op="matmul", device=self.device)

        def _backward():
            if out.grad is None:
                return
            if self.requires_grad:
                self._accum(out.grad @ np.swapaxes(other.data, -1, -2))
            if other.requires_grad:
                other._accum(np.swapaxes(self.data, -1, -2) @ out.grad)

        out._backward = _backward
        return out

    def __getitem__(self, idx):
        out = Tensor(self.data[idx], requires_grad=self.requires_grad, _children=(self,), _op="getitem", device=self.device)

        def _backward():
            if out.grad is None or not self.requires_grad:
                return
            grad = np.zeros_like(self.data)
            grad[idx] = out.grad
            self._accum(grad)

        out._backward = _backward
        return out

    def reshape(self, *shape):
        if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
            shape = tuple(shape[0])
        out = Tensor(self.data.reshape(shape), requires_grad=self.requires_grad, _children=(self,), _op="reshape", device=self.device)

        def _backward():
            if out.grad is None or not self.requires_grad:
                return
            self._accum(out.grad.reshape(self.data.shape))

        out._backward = _backward
        return out

    view = reshape

    def flatten(self, start_dim: int = 0, end_dim: int = -1):
        return Tensor(self.data.reshape(-1), requires_grad=self.requires_grad, _children=(self,), _op="flatten", device=self.device)

    def squeeze(self, dim: int | None = None):
        out = Tensor(np.squeeze(self.data, axis=None if dim is None else dim), requires_grad=self.requires_grad, _children=(self,), _op="squeeze", device=self.device)
        out._backward = lambda: None
        return out

    def unsqueeze(self, dim: int):
        out = Tensor(np.expand_dims(self.data, axis=dim), requires_grad=self.requires_grad, _children=(self,), _op="unsqueeze", device=self.device)
        out._backward = lambda: None
        return out

    def transpose(self, dim0: int, dim1: int):
        out = Tensor(np.swapaxes(self.data, dim0, dim1), requires_grad=self.requires_grad, _children=(self,), _op="transpose", device=self.device)
        out._backward = lambda: None
        return out

    def permute(self, *dims):
        out = Tensor(np.transpose(self.data, axes=dims), requires_grad=self.requires_grad, _children=(self,), _op="permute", device=self.device)
        out._backward = lambda: None
        return out

    def sum(self, axis=None, keepdims=False):
        out = Tensor(self.data.sum(axis=axis, keepdims=keepdims), requires_grad=self.requires_grad, _children=(self,), _op="sum", device=self.device)

        def _backward():
            if out.grad is None or not self.requires_grad:
                return
            grad = out.grad
            if axis is None:
                grad = np.broadcast_to(grad, self.data.shape)
            else:
                grad = np.asarray(grad)
                if not keepdims:
                    grad = np.expand_dims(grad, axis=axis)
                grad = np.broadcast_to(grad, self.data.shape)
            self._accum(grad)

        out._backward = _backward
        return out

    def mean(self, axis=None, keepdims=False):
        out = Tensor(self.data.mean(axis=axis, keepdims=keepdims), requires_grad=self.requires_grad, _children=(self,), _op="mean", device=self.device)

        def _backward():
            if out.grad is None or not self.requires_grad:
                return
            count = self.data.size if axis is None else self.data.shape[axis]
            grad = out.grad / count
            if axis is None:
                grad = np.broadcast_to(grad, self.data.shape)
            else:
                if not keepdims:
                    grad = np.expand_dims(grad, axis=axis)
                grad = np.broadcast_to(grad, self.data.shape)
            self._accum(grad)

        out._backward = _backward
        return out

    def softmax(self, dim=-1):
        x = self.data - np.max(self.data, axis=dim, keepdims=True)
        e = np.exp(x)
        return Tensor(e / e.sum(axis=dim, keepdims=True), requires_grad=self.requires_grad, device=self.device)

    def log_softmax(self, dim=-1):
        x = self.data - np.max(self.data, axis=dim, keepdims=True)
        return Tensor(x - np.log(np.exp(x).sum(axis=dim, keepdims=True)), requires_grad=self.requires_grad, device=self.device)


@contextmanager
def no_grad():
    global _grad_enabled
    prev = _grad_enabled
    _grad_enabled = False
    try:
        yield
    finally:
        _grad_enabled = prev


def enable_grad():
    global _grad_enabled
    _grad_enabled = True


def set_grad_enabled(mode: bool):
    global _grad_enabled
    _grad_enabled = bool(mode)


def is_grad_enabled() -> bool:
    return _grad_enabled


def zeros(shape, device: str = "cpu"):
    return Tensor(np.zeros(shape, dtype=np.float32), device=device)


def ones(shape, device: str = "cpu"):
    return Tensor(np.ones(shape, dtype=np.float32), device=device)


def full(shape, value, device: str = "cpu"):
    return Tensor(np.full(shape, value, dtype=np.float32), device=device)


def zeros_like(like: Tensor):
    return Tensor(np.zeros_like(like.data), device=like.device)


def ones_like(like: Tensor):
    return Tensor(np.ones_like(like.data), device=like.device)


def full_like(like: Tensor, value):
    return Tensor(np.full_like(like.data, value), device=like.device)


def empty(shape, device: str = "cpu"):
    return Tensor(np.empty(shape, dtype=np.float32), device=device)


def empty_like(like: Tensor):
    return Tensor(np.empty_like(like.data), device=like.device)


def rand_like(like: Tensor):
    return Tensor(np.random.rand(*like.shape).astype(np.float32), device=like.device)


def randn_like(like: Tensor):
    return Tensor(np.random.randn(*like.shape).astype(np.float32), device=like.device)


def eye(n: int, m: int | None = None):
    return Tensor(np.eye(n, m if m is not None else n, dtype=np.float32))


def arange(start, end=None, step=1):
    if end is None:
        start, end = 0, start
    return Tensor(np.arange(start, end, step, dtype=np.float32))


def linspace(start, end, steps):
    return Tensor(np.linspace(start, end, steps, dtype=np.float32))


def logspace(start, end, steps, base=10.0):
    return Tensor(np.logspace(start, end, steps, base=base, dtype=np.float32))


def rand(shape):
    return Tensor(np.random.rand(*shape).astype(np.float32))


def randn(shape):
    return Tensor(np.random.randn(*shape).astype(np.float32))


def randint(low, high, shape):
    return Tensor(np.random.randint(low, high, size=shape).astype(np.float32))


def randperm(n):
    return Tensor(np.random.permutation(n).astype(np.float32))


def normal(mean, std, shape):
    return Tensor(np.random.normal(mean, std, size=shape).astype(np.float32))


def uniform(low, high, shape):
    return Tensor(np.random.uniform(low, high, size=shape).astype(np.float32))


def index_select(a, dim, indices):
    return Tensor(np.take(_to_numpy(a), indices, axis=dim), requires_grad=a.requires_grad, device=a.device)


def masked_select(a, mask):
    return Tensor(_to_numpy(a)[_to_numpy(mask).astype(bool)], requires_grad=a.requires_grad, device=a.device)


def masked_fill(a, mask, value):
    out = np.array(_to_numpy(a), copy=True)
    out[_to_numpy(mask).astype(bool)] = value
    return Tensor(out, requires_grad=a.requires_grad, device=a.device)


def masked_scatter(a, mask, source):
    out = np.array(_to_numpy(a), copy=True)
    out[_to_numpy(mask).astype(bool)] = _to_numpy(source).reshape(-1)[: np.count_nonzero(_to_numpy(mask))]
    return Tensor(out, requires_grad=a.requires_grad or getattr(source, "requires_grad", False), device=a.device)


def nonzero(a):
    return Tensor(np.argwhere(_to_numpy(a) != 0).astype(np.float32), device=a.device)


def repeat_interleave(a, repeats):
    return Tensor(np.repeat(_to_numpy(a), repeats, axis=0), requires_grad=a.requires_grad, device=a.device)


def cat(tensors: Iterable[Tensor], dim: int = 0):
    tensors = [t if isinstance(t, Tensor) else Tensor(t) for t in tensors]
    return Tensor(np.concatenate([_to_numpy(t) for t in tensors], axis=dim), requires_grad=any(t.requires_grad for t in tensors), device=tensors[0].device if tensors else "cpu")


def stack(tensors: Iterable[Tensor], dim: int = 0):
    tensors = [t if isinstance(t, Tensor) else Tensor(t) for t in tensors]
    return Tensor(np.stack([_to_numpy(t) for t in tensors], axis=dim), requires_grad=any(t.requires_grad for t in tensors), device=tensors[0].device if tensors else "cpu")


def split(a, sections):
    return tuple(Tensor(x, requires_grad=a.requires_grad, device=a.device) for x in np.array_split(_to_numpy(a), sections))


def chunk(a, chunks):
    return split(a, chunks)


def where(condition, x, y):
    return Tensor(np.where(_to_numpy(condition).astype(bool), _to_numpy(x), _to_numpy(y)), requires_grad=getattr(x, "requires_grad", False) or getattr(y, "requires_grad", False), device=getattr(x, "device", "cpu"))


def clamp(a, min=None, max=None):
    return Tensor(np.clip(_to_numpy(a), min, max), requires_grad=getattr(a, "requires_grad", False), device=getattr(a, "device", "cpu"))


clip = clamp


def sign(a):
    return Tensor(np.sign(_to_numpy(a)), requires_grad=getattr(a, "requires_grad", False), device=getattr(a, "device", "cpu"))


def flip(a, dims):
    return Tensor(np.flip(_to_numpy(a), axis=dims), requires_grad=getattr(a, "requires_grad", False), device=getattr(a, "device", "cpu"))


def roll(a, shifts, dims=None):
    return Tensor(np.roll(_to_numpy(a), shift=shifts, axis=dims), requires_grad=getattr(a, "requires_grad", False), device=getattr(a, "device", "cpu"))


def tile(a, reps):
    return Tensor(np.tile(_to_numpy(a), reps), requires_grad=getattr(a, "requires_grad", False), device=getattr(a, "device", "cpu"))


def diag(a):
    arr = _to_numpy(a)
    return Tensor(np.diag(arr), requires_grad=getattr(a, "requires_grad", False), device=getattr(a, "device", "cpu"))


def softmax(a, axis=-1):
    x = _to_numpy(a)
    x = x - np.max(x, axis=axis, keepdims=True)
    e = np.exp(x)
    return Tensor(e / e.sum(axis=axis, keepdims=True), requires_grad=getattr(a, "requires_grad", False), device=getattr(a, "device", "cpu"))


def log_softmax(a, axis=-1):
    x = _to_numpy(a)
    x = x - np.max(x, axis=axis, keepdims=True)
    logsum = np.log(np.exp(x).sum(axis=axis, keepdims=True))
    return Tensor(x - logsum, requires_grad=getattr(a, "requires_grad", False), device=getattr(a, "device", "cpu"))


def take_along_dim(a, indices, dim):
    return Tensor(np.take_along_axis(_to_numpy(a), _to_numpy(indices).astype(int), axis=dim), requires_grad=getattr(a, "requires_grad", False), device=getattr(a, "device", "cpu"))


def matmul(a, b):
    return _coerce_tensor(a).__matmul__(b)


def mm(a, b):
    return matmul(a, b)


def bmm(a, b):
    return Tensor(np.matmul(_to_numpy(a), _to_numpy(b)), requires_grad=getattr(a, "requires_grad", False) or getattr(b, "requires_grad", False), device=getattr(a, "device", "cpu"))


def meshgrid(*arrays):
    return [Tensor(x) for x in np.meshgrid(*[_to_numpy(a) for a in arrays])]


def inverse(a):
    return Tensor(np.linalg.inv(_to_numpy(a)), requires_grad=getattr(a, "requires_grad", False), device=getattr(a, "device", "cpu"))


def eig(a):
    vals, vecs = np.linalg.eig(_to_numpy(a))
    return Tensor(vals), Tensor(vecs)


def svd(a):
    u, s, vh = np.linalg.svd(_to_numpy(a), full_matrices=False)
    return Tensor(u), Tensor(s), Tensor(vh)


def matrix_rank(a):
    return int(np.linalg.matrix_rank(_to_numpy(a)))


def det(a):
    return Tensor(np.asarray(np.linalg.det(_to_numpy(a))))


def eigh(a):
    vals, vecs = np.linalg.eigh(_to_numpy(a))
    return Tensor(vals), Tensor(vecs)


def qr(a):
    q, r = np.linalg.qr(_to_numpy(a))
    return Tensor(q), Tensor(r)


def cholesky(a):
    return Tensor(np.linalg.cholesky(_to_numpy(a)))


def solve(a, b):
    return Tensor(np.linalg.solve(_to_numpy(a), _to_numpy(b)))


def lstsq(a, b):
    x, *_ = np.linalg.lstsq(_to_numpy(a), _to_numpy(b), rcond=None)
    return Tensor(x)


def cross(a, b):
    return Tensor(np.cross(_to_numpy(a), _to_numpy(b)))


def outer(a, b):
    return Tensor(np.outer(_to_numpy(a), _to_numpy(b)))


def inner(a, b):
    return Tensor(np.inner(_to_numpy(a), _to_numpy(b)))


def matrix_power(a, n):
    return Tensor(np.linalg.matrix_power(_to_numpy(a), n))


def sort(a, dim=0):
    return Tensor(np.sort(_to_numpy(a), axis=dim), requires_grad=getattr(a, "requires_grad", False), device=getattr(a, "device", "cpu"))


def argsort(a, dim=0):
    return Tensor(np.argsort(_to_numpy(a), axis=dim).astype(np.float32), device=getattr(a, "device", "cpu"))


def topk(a, k):
    arr = np.sort(_to_numpy(a).reshape(-1))[::-1][:k]
    return Tensor(arr, device=getattr(a, "device", "cpu"))


def unique(a):
    return Tensor(np.unique(_to_numpy(a)), device=getattr(a, "device", "cpu"))


def median(a):
    return Tensor(np.asarray([np.median(_to_numpy(a))], dtype=np.float32), device=getattr(a, "device", "cpu"))


def mode(a):
    values, counts = np.unique(_to_numpy(a), return_counts=True)
    return Tensor(np.asarray([values[np.argmax(counts)]], dtype=np.float32), device=getattr(a, "device", "cpu"))


def quantile(a, q):
    return Tensor(np.asarray([np.quantile(_to_numpy(a), q)], dtype=np.float32), device=getattr(a, "device", "cpu"))


def cumsum(a, dim=0):
    return Tensor(np.cumsum(_to_numpy(a), axis=dim), device=getattr(a, "device", "cpu"))


def cumprod(a, dim=0):
    return Tensor(np.cumprod(_to_numpy(a), axis=dim), device=getattr(a, "device", "cpu"))


def prod(a, dim=0):
    return Tensor(np.prod(_to_numpy(a), axis=dim), device=getattr(a, "device", "cpu"))


def einsum(equation, *operands):
    return Tensor(np.einsum(equation, *[_to_numpy(op) for op in operands]))
