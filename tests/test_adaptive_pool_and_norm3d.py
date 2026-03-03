import os
import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from tensor import Tensor
import tensor.nn as nn
from tensor.nn import functional as F


def test_adaptive_avg_pool1d_backward_uniform_distribution():
    x = Tensor(np.ones((1, 1, 4), dtype=np.float64), requires_grad=True)
    y = F.adaptive_avg_pool1d(x, 2)
    assert y.shape == (1, 1, 2)
    assert np.allclose(y.to_numpy(), np.ones((1, 1, 2), dtype=np.float64))

    y.sum().backward()
    expected_grad = np.full((1, 1, 4), 0.5, dtype=np.float64)
    assert np.allclose(x.grad, expected_grad)


def test_adaptive_max_pool2d_return_indices_and_backward():
    x_np = np.array(
        [[[[1.0, 3.0, 2.0, 0.0],
           [4.0, 6.0, 5.0, 1.0],
           [0.0, 2.0, 9.0, 8.0],
           [7.0, 3.0, 4.0, 5.0]]]],
        dtype=np.float64,
    )
    x = Tensor(x_np.copy(), requires_grad=True)

    y, idx = F.adaptive_max_pool2d(x, (2, 2), return_indices=True)
    expected_y = np.array([[[[6.0, 5.0], [7.0, 9.0]]]], dtype=np.float64)
    expected_idx = np.array([[[[5, 6], [12, 10]]]], dtype=np.int64)

    assert y.shape == (1, 1, 2, 2)
    assert np.allclose(y.to_numpy(), expected_y)
    assert np.array_equal(idx.to_numpy(), expected_idx)

    y.sum().backward()
    expected_grad = np.zeros_like(x_np)
    expected_grad[0, 0, 1, 1] = 1.0
    expected_grad[0, 0, 1, 2] = 1.0
    expected_grad[0, 0, 3, 0] = 1.0
    expected_grad[0, 0, 2, 2] = 1.0
    assert np.allclose(x.grad, expected_grad)


def test_adaptive_avg_pool3d_backward_uniform_distribution():
    x = Tensor(np.ones((1, 1, 4, 4, 4), dtype=np.float64), requires_grad=True)
    y = F.adaptive_avg_pool3d(x, (2, 2, 2))
    assert y.shape == (1, 1, 2, 2, 2)
    assert np.allclose(y.to_numpy(), np.ones((1, 1, 2, 2, 2), dtype=np.float64))

    y.sum().backward()
    expected_grad = np.full((1, 1, 4, 4, 4), 1.0 / 8.0, dtype=np.float64)
    assert np.allclose(x.grad, expected_grad)


def test_batchnorm3d_module_forward_backward_and_running_stats():
    bn = nn.BatchNorm3d(3)
    bn.train()

    x = Tensor(np.random.randn(2, 3, 4, 3, 2).astype(np.float64), requires_grad=True)
    y = bn(x)
    assert y.shape == x.shape

    y.sum().backward()

    assert x.grad.shape == x.shape
    assert bn.weight.grad.shape == (3,)
    assert bn.bias.grad.shape == (3,)
    assert np.linalg.norm(bn.running_mean) > 0
    assert np.linalg.norm(bn.running_var - np.ones(3)) > 0


def test_instancenorm3d_module_forward_backward_and_running_stats():
    norm = nn.InstanceNorm3d(2, affine=True, track_running_stats=True)
    norm.train()

    x = Tensor(np.random.randn(3, 2, 4, 3, 2).astype(np.float64), requires_grad=True)
    y = norm(x)
    assert y.shape == x.shape

    y.sum().backward()

    assert x.grad.shape == x.shape
    assert norm.weight.grad.shape == (2,)
    assert norm.bias.grad.shape == (2,)
    assert np.linalg.norm(norm.running_mean) > 0


def test_pool2d_modules_delegate_to_functional_interfaces():
    x = Tensor(np.random.randn(2, 3, 5, 5).astype(np.float64), requires_grad=True)

    max_pool = nn.MaxPool2d(kernel_size=2, stride=2, return_indices=True)
    y_mod, idx_mod = max_pool(x)
    y_fun, idx_fun = F.max_pool2d(x, kernel_size=2, stride=2, return_indices=True)
    assert np.allclose(y_mod.to_numpy(), y_fun.to_numpy())
    assert np.array_equal(idx_mod.to_numpy(), idx_fun.to_numpy())

    avg_pool = nn.AvgPool2d(kernel_size=2, stride=2, padding=1, ceil_mode=True, count_include_pad=False)
    y_mod_avg = avg_pool(x)
    y_fun_avg = F.avg_pool2d(x, kernel_size=2, stride=2, padding=1, ceil_mode=True, count_include_pad=False)
    assert np.allclose(y_mod_avg.to_numpy(), y_fun_avg.to_numpy())


def test_adaptive_pool_modules_shapes_and_indices():
    x1 = Tensor(np.random.randn(2, 3, 7).astype(np.float64), requires_grad=True)
    x2 = Tensor(np.random.randn(2, 3, 7, 5).astype(np.float64), requires_grad=True)
    x3 = Tensor(np.random.randn(1, 2, 6, 4, 5).astype(np.float64), requires_grad=True)

    y1 = nn.AdaptiveAvgPool1d(4)(x1)
    y2 = nn.AdaptiveAvgPool2d((3, 2))(x2)
    y3 = nn.AdaptiveAvgPool3d((2, 2, 3))(x3)

    z1, i1 = nn.AdaptiveMaxPool1d(4, return_indices=True)(x1)
    z2, i2 = nn.AdaptiveMaxPool2d((3, 2), return_indices=True)(x2)
    z3, i3 = nn.AdaptiveMaxPool3d((2, 2, 3), return_indices=True)(x3)

    assert y1.shape == (2, 3, 4)
    assert y2.shape == (2, 3, 3, 2)
    assert y3.shape == (1, 2, 2, 2, 3)

    assert z1.shape == y1.shape
    assert z2.shape == y2.shape
    assert z3.shape == y3.shape

    assert i1.shape == z1.shape
    assert i2.shape == z2.shape
    assert i3.shape == z3.shape

    (y1.sum() + y2.sum() + y3.sum() + z1.sum() + z2.sum() + z3.sum()).backward()
    assert x1.grad.shape == x1.shape
    assert x2.grad.shape == x2.shape
    assert x3.grad.shape == x3.shape
