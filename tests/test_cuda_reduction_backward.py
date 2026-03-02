import os
import numpy as np
import pytest

from tensor import Tensor
from tensor.cuda.ops import available


def _cuda_runtime_ok() -> bool:
    if not available():
        return False
    try:
        x = Tensor(np.zeros((2, 2), dtype=np.float32), device="cuda")
        _ = x + x
        return True
    except Exception:
        return False


def _numeric_grad(fn, x, eps=1e-3):
    grad = np.zeros_like(x, dtype=np.float32)
    it = np.nditer(x, flags=["multi_index"], op_flags=["readwrite"])
    while not it.finished:
        idx = it.multi_index
        old = x[idx]
        x[idx] = old + eps
        p = fn(x)
        x[idx] = old - eps
        n = fn(x)
        x[idx] = old
        grad[idx] = (p - n) / (2 * eps)
        it.iternext()
    return grad


def _reduce_value(x, op, axis):
    if op == "sum":
        return x.sum(axis=axis)
    if op == "mean":
        return x.mean(axis=axis)
    if op == "max":
        return x.max(axis=axis)
    if op == "min":
        return x.min(axis=axis)
    raise ValueError(op)


def _scalar_objective(x_arr, op, axis):
    val = _reduce_value(x_arr, op, axis)
    return float(np.asarray(val).sum())


def _check_case(op, axis):
    # Add tiny deterministic perturbation to avoid max/min ties.
    base = np.random.randn(2, 3, 4).astype(np.float32)
    base = base + np.linspace(0.0, 1e-3, base.size, dtype=np.float32).reshape(base.shape)

    x = Tensor(base.copy(), requires_grad=True, device="cuda")
    out = _reduce_value(x, op, axis)
    if isinstance(out, tuple):
        out = out[0]
    loss = out.sum()
    loss.backward()
    grad_cuda = x.grad.copy()

    num = _numeric_grad(lambda z: _scalar_objective(z, op, axis), base.copy())

    atol = 1e-4 if op in ("sum", "mean") else 2e-2
    rtol = 1e-4 if op in ("sum", "mean") else 2e-2
    assert np.allclose(grad_cuda, num, atol=atol, rtol=rtol)


def test_cuda_reduction_backward_vs_numeric():
    os.environ["TENSOR_DEVICE"] = "cuda"
    if not _cuda_runtime_ok():
        pytest.skip("CUDA runtime not available")

    for op in ("sum", "mean", "max", "min"):
        for axis in (0, 1, 2):
            _check_case(op, axis)
