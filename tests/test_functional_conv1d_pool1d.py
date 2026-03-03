import os
import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from tensor import Tensor
import tensor.nn as nn
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


def test_conv1d_forward_values():
    x_np = np.arange(1 * 1 * 6, dtype=np.float64).reshape(1, 1, 6)
    w_np = np.ones((1, 1, 3), dtype=np.float64)
    b_np = np.array([0.5], dtype=np.float64)

    x = Tensor(x_np)
    w = Tensor(w_np)
    b = Tensor(b_np)
    y = F.conv1d(x, w, b, stride=1, padding=1)

    expected = np.zeros((1, 1, 6), dtype=np.float64)
    x_pad = np.pad(x_np, ((0, 0), (0, 0), (1, 1)), mode="constant")
    for i in range(6):
        expected[0, 0, i] = x_pad[0, 0, i:i + 3].sum() + 0.5

    assert y.shape == (1, 1, 6)
    assert np.allclose(y.to_numpy(), expected, atol=1e-8)


def test_conv1d_backward_matches_numeric_grad():
    x_np = np.random.randn(1, 1, 5).astype(np.float64)
    w_np = np.random.randn(1, 1, 3).astype(np.float64)
    b_np = np.random.randn(1).astype(np.float64)

    x = Tensor(x_np.copy(), requires_grad=True)
    w = Tensor(w_np.copy(), requires_grad=True)
    b = Tensor(b_np.copy(), requires_grad=True)
    loss = F.conv1d(x, w, b).sum()
    loss.backward()

    def f_x(v):
        return F.conv1d(Tensor(v), Tensor(w_np), Tensor(b_np)).sum().item()

    def f_w(v):
        return F.conv1d(Tensor(x_np), Tensor(v), Tensor(b_np)).sum().item()

    def f_b(v):
        return F.conv1d(Tensor(x_np), Tensor(w_np), Tensor(v)).sum().item()

    num_x = _numeric_grad(f_x, x_np.copy())
    num_w = _numeric_grad(f_w, w_np.copy())
    num_b = _numeric_grad(f_b, b_np.copy())

    assert np.allclose(x.grad, num_x, atol=1e-4, rtol=1e-4)
    assert np.allclose(w.grad, num_w, atol=1e-4, rtol=1e-4)
    assert np.allclose(b.grad, num_b, atol=1e-4, rtol=1e-4)


def test_max_pool1d_backward_argmax_routing():
    x = Tensor(np.array([[[1.0, 3.0, 2.0, 4.0]]], dtype=np.float64), requires_grad=True)
    y = F.max_pool1d(x, kernel_size=2, stride=2)
    y.sum().backward()
    expected = np.array([[[0.0, 1.0, 0.0, 1.0]]], dtype=np.float64)
    assert np.allclose(x.grad, expected)


def test_avg_pool1d_backward_uniform_distribution():
    x = Tensor(np.array([[[1.0, 2.0, 3.0, 4.0]]], dtype=np.float64), requires_grad=True)
    y = F.avg_pool1d(x, kernel_size=2, stride=2)
    y.sum().backward()
    expected = np.array([[[0.5, 0.5, 0.5, 0.5]]], dtype=np.float64)
    assert np.allclose(x.grad, expected)


def test_conv1d_and_pool1d_modules_forward_backward():
    conv = nn.Conv1d(2, 3, kernel_size=3, stride=1, padding=1)
    pool = nn.MaxPool1d(kernel_size=2, stride=2)
    avg = nn.AvgPool1d(kernel_size=2, stride=2)

    x = Tensor(np.random.randn(4, 2, 8).astype(np.float64), requires_grad=True)
    y = conv(x)
    z1 = pool(y)
    z2 = avg(y)
    loss = (z1.sum() + z2.sum())
    loss.backward()

    assert y.shape == (4, 3, 8)
    assert z1.shape == (4, 3, 4)
    assert z2.shape == (4, 3, 4)
    assert conv.weight.grad is not None
    if conv.bias is not None:
        assert conv.bias.grad is not None
