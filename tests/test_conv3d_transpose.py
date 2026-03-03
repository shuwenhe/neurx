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


def test_conv3d_forward_values():
    x_np = np.arange(1 * 1 * 3 * 3 * 3, dtype=np.float64).reshape(1, 1, 3, 3, 3)
    w_np = np.ones((1, 1, 2, 2, 2), dtype=np.float64)
    b_np = np.array([0.5], dtype=np.float64)

    x = Tensor(x_np)
    w = Tensor(w_np)
    b = Tensor(b_np)
    y = F.conv3d(x, w, b, stride=1, padding=0)

    expected = np.zeros((1, 1, 2, 2, 2), dtype=np.float64)
    for od in range(2):
        for oh in range(2):
            for ow in range(2):
                patch = x_np[0, 0, od:od + 2, oh:oh + 2, ow:ow + 2]
                expected[0, 0, od, oh, ow] = patch.sum() + 0.5

    assert y.shape == (1, 1, 2, 2, 2)
    assert np.allclose(y.to_numpy(), expected, atol=1e-8)


def test_conv3d_backward_numeric():
    x_np = np.random.randn(1, 1, 3, 3, 3).astype(np.float64)
    w_np = np.random.randn(1, 1, 2, 2, 2).astype(np.float64)
    b_np = np.random.randn(1).astype(np.float64)

    x = Tensor(x_np.copy(), requires_grad=True)
    w = Tensor(w_np.copy(), requires_grad=True)
    b = Tensor(b_np.copy(), requires_grad=True)
    loss = F.conv3d(x, w, b).sum()
    loss.backward()

    def f_x(v):
        return F.conv3d(Tensor(v), Tensor(w_np), Tensor(b_np)).sum().item()

    def f_w(v):
        return F.conv3d(Tensor(x_np), Tensor(v), Tensor(b_np)).sum().item()

    def f_b(v):
        return F.conv3d(Tensor(x_np), Tensor(w_np), Tensor(v)).sum().item()

    num_x = _numeric_grad(f_x, x_np.copy())
    num_w = _numeric_grad(f_w, w_np.copy())
    num_b = _numeric_grad(f_b, b_np.copy())

    assert np.allclose(x.grad, num_x, atol=1e-4, rtol=1e-4)
    assert np.allclose(w.grad, num_w, atol=1e-4, rtol=1e-4)
    assert np.allclose(b.grad, num_b, atol=1e-4, rtol=1e-4)


def test_conv_transpose1d_forward_and_backward_numeric():
    x_np = np.random.randn(1, 1, 3).astype(np.float64)
    w_np = np.random.randn(1, 1, 3).astype(np.float64)
    b_np = np.random.randn(1).astype(np.float64)

    x = Tensor(x_np.copy(), requires_grad=True)
    w = Tensor(w_np.copy(), requires_grad=True)
    b = Tensor(b_np.copy(), requires_grad=True)
    y = F.conv_transpose1d(x, w, b, stride=2, padding=1, output_padding=0)
    assert y.shape == (1, 1, 5)
    loss = y.sum()
    loss.backward()

    def f_x(v):
        return F.conv_transpose1d(Tensor(v), Tensor(w_np), Tensor(b_np), stride=2, padding=1).sum().item()

    def f_w(v):
        return F.conv_transpose1d(Tensor(x_np), Tensor(v), Tensor(b_np), stride=2, padding=1).sum().item()

    def f_b(v):
        return F.conv_transpose1d(Tensor(x_np), Tensor(w_np), Tensor(v), stride=2, padding=1).sum().item()

    num_x = _numeric_grad(f_x, x_np.copy())
    num_w = _numeric_grad(f_w, w_np.copy())
    num_b = _numeric_grad(f_b, b_np.copy())

    assert np.allclose(x.grad, num_x, atol=1e-4, rtol=1e-4)
    assert np.allclose(w.grad, num_w, atol=1e-4, rtol=1e-4)
    assert np.allclose(b.grad, num_b, atol=1e-4, rtol=1e-4)


def test_conv_transpose3d_forward_and_backward_numeric():
    x_np = np.random.randn(1, 1, 2, 2, 2).astype(np.float64)
    w_np = np.random.randn(1, 1, 2, 2, 2).astype(np.float64)
    b_np = np.random.randn(1).astype(np.float64)

    x = Tensor(x_np.copy(), requires_grad=True)
    w = Tensor(w_np.copy(), requires_grad=True)
    b = Tensor(b_np.copy(), requires_grad=True)
    y = F.conv_transpose3d(x, w, b, stride=2, padding=1, output_padding=1)
    assert y.shape == (1, 1, 3, 3, 3)
    y.sum().backward()

    def f_x(v):
        return F.conv_transpose3d(Tensor(v), Tensor(w_np), Tensor(b_np), stride=2, padding=1, output_padding=1).sum().item()

    def f_w(v):
        return F.conv_transpose3d(Tensor(x_np), Tensor(v), Tensor(b_np), stride=2, padding=1, output_padding=1).sum().item()

    def f_b(v):
        return F.conv_transpose3d(Tensor(x_np), Tensor(w_np), Tensor(v), stride=2, padding=1, output_padding=1).sum().item()

    num_x = _numeric_grad(f_x, x_np.copy())
    num_w = _numeric_grad(f_w, w_np.copy())
    num_b = _numeric_grad(f_b, b_np.copy())

    assert np.allclose(x.grad, num_x, atol=1e-4, rtol=1e-4)
    assert np.allclose(w.grad, num_w, atol=1e-4, rtol=1e-4)
    assert np.allclose(b.grad, num_b, atol=1e-4, rtol=1e-4)


def test_conv_transpose2d_and_modules_backward():
    x = Tensor(np.random.randn(2, 2, 4, 4).astype(np.float64), requires_grad=True)
    w = Tensor(np.random.randn(2, 3, 3, 3).astype(np.float64), requires_grad=True)
    b = Tensor(np.random.randn(3).astype(np.float64), requires_grad=True)

    y = F.conv_transpose2d(x, w, b, stride=2, padding=1, output_padding=1)
    assert y.shape == (2, 3, 8, 8)
    y.sum().backward()
    assert x.grad.shape == x.shape
    assert w.grad.shape == w.shape
    assert b.grad.shape == b.shape

    conv3d = nn.Conv3d(2, 3, kernel_size=3, padding=1)
    deconv1d = nn.ConvTranspose1d(2, 3, kernel_size=3, stride=2, padding=1, output_padding=1)
    deconv2d = nn.ConvTranspose2d(2, 3, kernel_size=3, stride=2, padding=1, output_padding=1)
    deconv3d = nn.ConvTranspose3d(2, 3, kernel_size=3, stride=2, padding=1, output_padding=1)

    x1 = Tensor(np.random.randn(2, 2, 5).astype(np.float64), requires_grad=True)
    x2 = Tensor(np.random.randn(2, 2, 4, 4).astype(np.float64), requires_grad=True)
    x3 = Tensor(np.random.randn(1, 2, 4, 4, 4).astype(np.float64), requires_grad=True)
    x4 = Tensor(np.random.randn(1, 2, 3, 3, 3).astype(np.float64), requires_grad=True)

    z1 = deconv1d(x1)
    z2 = deconv2d(x2)
    z3 = conv3d(x3)
    z4 = deconv3d(x4)
    loss = z1.sum() + z2.sum() + z3.sum() + z4.sum()
    loss.backward()

    assert z1.shape == (2, 3, 10)
    assert z2.shape == (2, 3, 8, 8)
    assert z3.shape == (1, 3, 4, 4, 4)
    assert z4.shape == (1, 3, 6, 6, 6)
    assert deconv1d.weight.grad is not None
    assert deconv2d.weight.grad is not None
    assert deconv3d.weight.grad is not None
    assert conv3d.weight.grad is not None
