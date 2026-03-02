import os
import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from tensor import Tensor
from tensor.nn import functional as F


def _numeric_grad(f, x, eps=1e-4):
    grad = np.zeros_like(x)
    it = np.nditer(x, flags=["multi_index"], op_flags=["readwrite"])
    while not it.finished:
        idx = it.multi_index
        old = x[idx]
        x[idx] = old + eps
        f1 = f(x)
        x[idx] = old - eps
        f2 = f(x)
        x[idx] = old
        grad[idx] = (f1 - f2) / (2 * eps)
        it.iternext()
    return grad


def test_log_softmax_grad():
    x = np.random.randn(2, 3).astype(np.float64)
    t = Tensor(x.copy(), requires_grad=True)
    y = F.log_softmax(t, axis=-1)
    loss = y.sum()
    loss.backward()

    def f(xv):
        return F.log_softmax(Tensor(xv), axis=-1).sum().item()

    num = _numeric_grad(f, x)
    assert np.allclose(t.grad, num, atol=1e-3, rtol=1e-3)


def test_nll_loss_grad():
    x = np.random.randn(2, 4).astype(np.float64)
    target = np.array([1, 3], dtype=np.int64)
    t = Tensor(x.copy(), requires_grad=True)
    y = F.log_softmax(t, axis=-1)
    loss = F.nll_loss(y, target, reduction="mean")
    loss.backward()

    def f(xv):
        yv = F.log_softmax(Tensor(xv), axis=-1)
        return F.nll_loss(yv, target, reduction="mean").item()

    num = _numeric_grad(f, x)
    assert np.allclose(t.grad, num, atol=1e-3, rtol=1e-3)


def test_cross_entropy_grad():
    x = np.random.randn(2, 3, 5).astype(np.float64)
    target = np.random.randint(0, 5, size=(2, 3))
    t = Tensor(x.copy(), requires_grad=True)
    loss = F.cross_entropy(t, target)
    loss.backward()

    def f(xv):
        return F.cross_entropy(Tensor(xv), target).item()

    num = _numeric_grad(f, x)
    assert np.allclose(t.grad, num, atol=1e-3, rtol=1e-3)
