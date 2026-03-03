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


def _log_softmax_np(x, axis):
    x_max = x.max(axis=axis, keepdims=True)
    exp_x = np.exp(x - x_max)
    return (x - x_max) - np.log(exp_x.sum(axis=axis, keepdims=True))


def test_cross_entropy_supports_pytorch_layout_grad():
    x = np.random.randn(2, 4, 3).astype(np.float64)
    target = np.random.randint(0, 4, size=(2, 3), dtype=np.int64)

    t = Tensor(x.copy(), requires_grad=True)
    loss = F.cross_entropy(t, target, reduction="mean")
    loss.backward()

    def f(xv):
        return F.cross_entropy(Tensor(xv), target, reduction="mean").item()

    num = _numeric_grad(f, x.copy())
    assert np.allclose(t.grad, num, atol=2e-3, rtol=2e-3)


def test_cross_entropy_weight_and_ignore_index_mean_matches_manual_and_grad():
    logits = np.array(
        [
            [2.0, -1.0, 0.5, 1.0],
            [0.2, 0.4, -0.3, 1.2],
            [-1.2, 1.0, 2.0, -0.7],
        ],
        dtype=np.float64,
    )
    target = np.array([1, -100, 2], dtype=np.int64)
    weight = np.array([1.0, 2.0, 3.0, 4.0], dtype=np.float64)

    t = Tensor(logits.copy(), requires_grad=True)
    loss = F.cross_entropy(
        t,
        target,
        weight=weight,
        ignore_index=-100,
        reduction="mean",
    )

    log_probs = _log_softmax_np(logits, axis=1)
    expected = (-(log_probs[0, 1] * weight[1]) - (log_probs[2, 2] * weight[2])) / (weight[1] + weight[2])
    assert np.allclose(loss.item(), expected, atol=1e-10)

    loss.backward()
    assert np.allclose(t.grad[1], np.zeros_like(t.grad[1]), atol=1e-12)

    def f(xv):
        return F.cross_entropy(
            Tensor(xv),
            target,
            weight=weight,
            ignore_index=-100,
            reduction="mean",
        ).item()

    num = _numeric_grad(f, logits.copy())
    assert np.allclose(t.grad, num, atol=2e-3, rtol=2e-3)


def test_cross_entropy_label_smoothing_matches_manual_and_grad():
    logits = np.random.randn(2, 3).astype(np.float64)
    target = np.array([0, 2], dtype=np.int64)
    label_smoothing = 0.2

    t = Tensor(logits.copy(), requires_grad=True)
    loss = F.cross_entropy(t, target, label_smoothing=label_smoothing, reduction="mean")

    log_probs = _log_softmax_np(logits, axis=1)
    nll = -log_probs[np.arange(2), target]
    smooth = -log_probs.mean(axis=1)
    expected = ((1.0 - label_smoothing) * nll + label_smoothing * smooth).mean()
    assert np.allclose(loss.item(), expected, atol=1e-10)

    loss.backward()

    def f(xv):
        return F.cross_entropy(
            Tensor(xv),
            target,
            label_smoothing=label_smoothing,
            reduction="mean",
        ).item()

    num = _numeric_grad(f, logits.copy())
    assert np.allclose(t.grad, num, atol=2e-3, rtol=2e-3)


def test_nll_loss_none_and_dim_override():
    logits = np.random.randn(2, 3, 4).astype(np.float64)
    target = np.random.randint(0, 3, size=(2, 4), dtype=np.int64)

    log_probs = _log_softmax_np(logits, axis=1)
    out = F.nll_loss(Tensor(log_probs), target, reduction="none")
    expected = -np.take_along_axis(log_probs, target[:, None, :], axis=1)[:, 0, :]
    assert out.shape == target.shape
    assert np.allclose(out.to_numpy(), expected, atol=1e-10)

    logits_last = np.transpose(logits, (0, 2, 1))
    log_probs_last = _log_softmax_np(logits_last, axis=-1)
    out_last = F.nll_loss(Tensor(log_probs_last), target, dim=-1, reduction="none")
    expected_last = -np.take_along_axis(log_probs_last, target[..., None], axis=-1)[..., 0]
    assert out_last.shape == target.shape
    assert np.allclose(out_last.to_numpy(), expected_last, atol=1e-10)


def test_cross_entropy_loss_module_matches_functional():
    x = Tensor(np.random.randn(3, 5).astype(np.float64), requires_grad=True)
    target = np.array([1, -100, 4], dtype=np.int64)
    weight = np.array([1.0, 2.0, 1.5, 0.5, 3.0], dtype=np.float64)

    loss_fn = nn.CrossEntropyLoss(
        weight=weight,
        ignore_index=-100,
        reduction="mean",
        label_smoothing=0.1,
    )
    out_mod = loss_fn(x, target)
    out_fun = F.cross_entropy(
        x,
        target,
        weight=weight,
        ignore_index=-100,
        reduction="mean",
        label_smoothing=0.1,
    )

    assert np.allclose(out_mod.item(), out_fun.item(), atol=1e-12)
