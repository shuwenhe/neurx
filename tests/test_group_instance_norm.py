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


def test_group_norm_forward_group_stats():
    x_np = np.random.randn(2, 4, 3, 2).astype(np.float64)
    x = Tensor(x_np, requires_grad=True)
    y = F.group_norm(x, num_groups=2)
    y_np = y.to_numpy().reshape(2, 2, 2, -1)

    means = y_np.mean(axis=(2, 3))
    vars_ = y_np.var(axis=(2, 3))
    assert np.allclose(means, np.zeros_like(means), atol=1e-6)
    assert np.allclose(vars_, np.ones_like(vars_), atol=5e-5)


def test_group_norm_backward_numeric():
    x_np = np.random.randn(1, 4, 2, 2).astype(np.float64)
    w_np = np.random.randn(4).astype(np.float64)
    b_np = np.random.randn(4).astype(np.float64)
    g_np = np.random.randn(1, 4, 2, 2).astype(np.float64)

    x = Tensor(x_np.copy(), requires_grad=True)
    w = Tensor(w_np.copy(), requires_grad=True)
    b = Tensor(b_np.copy(), requires_grad=True)
    g = Tensor(g_np.copy())

    loss = (F.group_norm(x, num_groups=2, weight=w, bias=b) * g).sum()
    loss.backward()

    def f_x(v):
        out = F.group_norm(Tensor(v), num_groups=2, weight=Tensor(w_np), bias=Tensor(b_np)).to_numpy()
        return float((out * g_np).sum())

    def f_w(v):
        out = F.group_norm(Tensor(x_np), num_groups=2, weight=Tensor(v), bias=Tensor(b_np)).to_numpy()
        return float((out * g_np).sum())

    def f_b(v):
        out = F.group_norm(Tensor(x_np), num_groups=2, weight=Tensor(w_np), bias=Tensor(v)).to_numpy()
        return float((out * g_np).sum())

    num_x = _numeric_grad(f_x, x_np.copy())
    num_w = _numeric_grad(f_w, w_np.copy())
    num_b = _numeric_grad(f_b, b_np.copy())

    assert np.allclose(x.grad, num_x, atol=1e-4, rtol=1e-4)
    assert np.allclose(w.grad, num_w, atol=1e-4, rtol=1e-4)
    assert np.allclose(b.grad, num_b, atol=1e-4, rtol=1e-4)


def test_instance_norm_functional_training_updates_running_stats():
    x_np = np.random.randn(3, 2, 5).astype(np.float64)
    x = Tensor(x_np.copy(), requires_grad=True)
    running_mean = np.zeros(2, dtype=np.float64)
    running_var = np.ones(2, dtype=np.float64)

    y = F.instance_norm(
        x,
        running_mean=running_mean,
        running_var=running_var,
        use_input_stats=True,
        momentum=0.2,
        eps=1e-5,
    )
    y.sum().backward()

    assert np.linalg.norm(running_mean) > 0
    assert np.linalg.norm(running_var - np.ones_like(running_var)) > 0
    assert x.grad.shape == x.shape


def test_instance_norm_functional_eval_uses_running_stats():
    x_np = np.random.randn(2, 3, 4).astype(np.float64)
    x = Tensor(x_np.copy(), requires_grad=True)
    running_mean = np.array([0.1, -0.2, 0.3], dtype=np.float64)
    running_var = np.array([1.5, 0.8, 2.0], dtype=np.float64)
    weight_np = np.array([1.2, 0.7, 1.1], dtype=np.float64)
    bias_np = np.array([0.05, -0.1, 0.2], dtype=np.float64)
    weight = Tensor(weight_np.copy(), requires_grad=True)
    bias = Tensor(bias_np.copy(), requires_grad=True)
    eps = 1e-5

    y = F.instance_norm(
        x,
        running_mean=running_mean.copy(),
        running_var=running_var.copy(),
        weight=weight,
        bias=bias,
        use_input_stats=False,
        eps=eps,
    )

    expected = (x_np - running_mean.reshape(1, 3, 1)) / np.sqrt(running_var.reshape(1, 3, 1) + eps)
    expected = expected * weight_np.reshape(1, 3, 1) + bias_np.reshape(1, 3, 1)
    assert np.allclose(y.to_numpy(), expected, atol=1e-10)

    y.sum().backward()
    expected_x_grad = np.broadcast_to(weight_np.reshape(1, 3, 1) / np.sqrt(running_var.reshape(1, 3, 1) + eps), x_np.shape)
    assert np.allclose(x.grad, expected_x_grad, atol=1e-10)


def test_instance_norm_modules_and_group_norm_module():
    gn = nn.GroupNorm(num_groups=2, num_channels=4)
    in1 = nn.InstanceNorm1d(4, affine=True, track_running_stats=True)
    in2 = nn.InstanceNorm2d(4, affine=True, track_running_stats=True)

    x1 = Tensor(np.random.randn(2, 4, 8).astype(np.float64), requires_grad=True)
    x2 = Tensor(np.random.randn(2, 4, 6, 6).astype(np.float64), requires_grad=True)

    y1 = gn(x2)
    z1 = in1(x1)
    z2 = in2(x2)
    loss = y1.sum() + z1.sum() + z2.sum()
    loss.backward()

    assert y1.shape == x2.shape
    assert z1.shape == x1.shape
    assert z2.shape == x2.shape
    assert gn.weight.grad.shape == (4,)
    assert in1.weight.grad.shape == (4,)
    assert in2.weight.grad.shape == (4,)
    assert np.linalg.norm(in1.running_mean) > 0
    assert np.linalg.norm(in2.running_mean) > 0
