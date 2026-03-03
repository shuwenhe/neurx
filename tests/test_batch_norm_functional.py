import os
import numpy as np

os.environ["TENSOR_DEVICE"] = "cpu"

from tensor import Tensor
from tensor.nn import BatchNorm1d, BatchNorm2d
from tensor.nn import functional as F


def test_functional_batch_norm_training_updates_running_stats_and_backward():
    x_np = np.random.randn(8, 3, 5).astype(np.float64)
    x = Tensor(x_np.copy(), requires_grad=True)

    running_mean = np.zeros(3, dtype=np.float64)
    running_var = np.ones(3, dtype=np.float64)
    weight = Tensor(np.array([1.2, 0.9, 1.1], dtype=np.float64), requires_grad=True)
    bias = Tensor(np.array([0.1, -0.2, 0.3], dtype=np.float64), requires_grad=True)
    momentum = 0.2

    out = F.batch_norm(
        x,
        running_mean=running_mean,
        running_var=running_var,
        weight=weight,
        bias=bias,
        training=True,
        momentum=momentum,
        eps=1e-5,
    )
    loss = out.sum()
    loss.backward()

    batch_mean = x_np.mean(axis=(0, 2))
    batch_var = x_np.var(axis=(0, 2))
    expected_running_mean = momentum * batch_mean
    expected_running_var = (1.0 - momentum) * np.ones(3) + momentum * batch_var

    assert np.allclose(running_mean, expected_running_mean, atol=1e-10)
    assert np.allclose(running_var, expected_running_var, atol=1e-10)
    assert x.grad.shape == x.shape
    assert weight.grad.shape == weight.shape
    assert bias.grad.shape == bias.shape


def test_functional_batch_norm_eval_uses_running_stats_and_has_constant_input_grad():
    x_np = np.random.randn(4, 3).astype(np.float64)
    x = Tensor(x_np.copy(), requires_grad=True)

    running_mean = np.array([0.5, -0.25, 1.0], dtype=np.float64)
    running_var = np.array([2.0, 1.5, 0.5], dtype=np.float64)
    weight_np = np.array([1.2, 0.9, 1.1], dtype=np.float64)
    bias_np = np.array([0.1, -0.2, 0.3], dtype=np.float64)
    weight = Tensor(weight_np.copy(), requires_grad=True)
    bias = Tensor(bias_np.copy(), requires_grad=True)
    eps = 1e-5

    out = F.batch_norm(
        x,
        running_mean=running_mean.copy(),
        running_var=running_var.copy(),
        weight=weight,
        bias=bias,
        training=False,
        eps=eps,
    )

    expected = ((x_np - running_mean.reshape(1, -1)) / np.sqrt(running_var.reshape(1, -1) + eps))
    expected = expected * weight_np.reshape(1, -1) + bias_np.reshape(1, -1)
    assert np.allclose(out.to_numpy(), expected, atol=1e-10)

    out.sum().backward()
    expected_x_grad = np.broadcast_to(weight_np.reshape(1, -1) / np.sqrt(running_var.reshape(1, -1) + eps), x_np.shape)
    assert np.allclose(x.grad, expected_x_grad, atol=1e-10)


def test_batchnorm1d_module_updates_buffers_and_state_dict_consistent():
    bn = BatchNorm1d(4)
    bn.train()
    x = Tensor(np.random.randn(16, 4).astype(np.float64), requires_grad=True)

    y = bn(x)
    y.sum().backward()

    assert np.linalg.norm(bn.running_mean) > 0
    assert np.linalg.norm(bn.running_var - np.ones(4)) > 0

    state = bn.state_dict()
    assert "running_mean" in state
    assert "running_var" in state
    assert np.allclose(state["running_mean"], bn.running_mean)
    assert np.allclose(state["running_var"], bn.running_var)


def test_batchnorm1d_track_running_stats_false_uses_batch_stats_in_eval():
    bn = BatchNorm1d(3, track_running_stats=False)
    bn.eval()

    x1 = Tensor((np.random.randn(32, 3) + 10.0).astype(np.float64))
    x2 = Tensor((np.random.randn(32, 3) - 10.0).astype(np.float64))
    y1 = bn(x1).to_numpy()
    y2 = bn(x2).to_numpy()

    assert bn.running_mean is None
    assert bn.running_var is None
    assert np.allclose(y1.mean(axis=0), np.zeros(3), atol=1e-5)
    assert np.allclose(y2.mean(axis=0), np.zeros(3), atol=1e-5)


def test_batchnorm2d_module_forward_backward():
    bn = BatchNorm2d(3)
    bn.train()
    x = Tensor(np.random.randn(2, 3, 4, 5).astype(np.float64), requires_grad=True)

    y = bn(x)
    assert y.shape == x.shape
    y.sum().backward()

    assert x.grad.shape == x.shape
    assert bn.weight.grad.shape == (3,)
    assert bn.bias.grad.shape == (3,)
