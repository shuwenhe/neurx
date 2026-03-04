import os
import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from neurx import Tensor
from neurx.nn import functional as F


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


def test_leaky_relu_backward_matches_numeric_grad():
    x_np = np.random.randn(2, 3).astype(np.float64)
    slope = 0.2
    x = Tensor(x_np.copy(), requires_grad=True)
    y = F.leaky_relu(x, negative_slope=slope).sum()
    y.backward()

    def f(v):
        return F.leaky_relu(Tensor(v), negative_slope=slope).sum().item()

    num = _numeric_grad(f, x_np.copy())
    assert np.allclose(x.grad, num, atol=1e-5, rtol=1e-5)


def test_conv2d_forward_shape_and_values():
    x_np = np.arange(1 * 1 * 4 * 4, dtype=np.float64).reshape(1, 1, 4, 4)
    w_np = np.ones((1, 1, 3, 3), dtype=np.float64)
    b_np = np.array([0.5], dtype=np.float64)

    x = Tensor(x_np, requires_grad=False)
    w = Tensor(w_np, requires_grad=False)
    b = Tensor(b_np, requires_grad=False)
    y = F.conv2d(x, w, b, stride=1, padding=1)

    expected = np.zeros((1, 1, 4, 4), dtype=np.float64)
    x_pad = np.pad(x_np, ((0, 0), (0, 0), (1, 1), (1, 1)), mode="constant")
    for oh in range(4):
        for ow in range(4):
            expected[0, 0, oh, ow] = x_pad[0, 0, oh:oh + 3, ow:ow + 3].sum() + 0.5

    assert y.shape == (1, 1, 4, 4)
    assert np.allclose(y.to_numpy(), expected, atol=1e-8)


def test_conv2d_backward_matches_numeric_grad():
    x_np = np.random.randn(1, 1, 3, 3).astype(np.float64)
    w_np = np.random.randn(1, 1, 2, 2).astype(np.float64)
    b_np = np.random.randn(1).astype(np.float64)

    x = Tensor(x_np.copy(), requires_grad=True)
    w = Tensor(w_np.copy(), requires_grad=True)
    b = Tensor(b_np.copy(), requires_grad=True)
    loss = F.conv2d(x, w, b, stride=1, padding=0).sum()
    loss.backward()

    def f_x(v):
        return F.conv2d(Tensor(v), Tensor(w_np), Tensor(b_np)).sum().item()

    def f_w(v):
        return F.conv2d(Tensor(x_np), Tensor(v), Tensor(b_np)).sum().item()

    def f_b(v):
        return F.conv2d(Tensor(x_np), Tensor(w_np), Tensor(v)).sum().item()

    num_x = _numeric_grad(f_x, x_np.copy())
    num_w = _numeric_grad(f_w, w_np.copy())
    num_b = _numeric_grad(f_b, b_np.copy())

    assert np.allclose(x.grad, num_x, atol=1e-4, rtol=1e-4)
    assert np.allclose(w.grad, num_w, atol=1e-4, rtol=1e-4)
    assert np.allclose(b.grad, num_b, atol=1e-4, rtol=1e-4)


def test_max_pool2d_backward_argmax_routing():
    x = Tensor(np.array([[[[1.0, 2.0], [3.0, 4.0]]]], dtype=np.float64), requires_grad=True)
    y = F.max_pool2d(x, kernel_size=2, stride=2)
    y.sum().backward()
    expected_grad = np.array([[[[0.0, 0.0], [0.0, 1.0]]]], dtype=np.float64)
    assert np.allclose(x.grad, expected_grad)


def test_avg_pool2d_backward_uniform_distribution():
    x = Tensor(np.array([[[[1.0, 2.0], [3.0, 4.0]]]], dtype=np.float64), requires_grad=True)
    y = F.avg_pool2d(x, kernel_size=2, stride=2)
    y.sum().backward()
    expected_grad = np.full((1, 1, 2, 2), 0.25, dtype=np.float64)
    assert np.allclose(x.grad, expected_grad)


def test_adaptive_avg_pool2d_backward():
    x = Tensor(np.ones((1, 1, 4, 4), dtype=np.float64), requires_grad=True)
    y = F.adaptive_avg_pool2d(x, output_size=(2, 2))
    assert y.shape == (1, 1, 2, 2)
    y.sum().backward()
    expected_grad = np.full((1, 1, 4, 4), 0.25, dtype=np.float64)
    assert np.allclose(x.grad, expected_grad)
