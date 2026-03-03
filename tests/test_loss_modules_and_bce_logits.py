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


def test_bce_with_logits_weight_pos_weight_forward_matches_manual():
    logits = np.array([[0.5, -1.2, 2.0], [1.3, 0.0, -0.7]], dtype=np.float64)
    target = np.array([[1.0, 0.0, 1.0], [0.0, 1.0, 0.0]], dtype=np.float64)
    weight = np.array([1.0, 0.5, 2.0], dtype=np.float64)
    pos_weight = np.array([3.0, 1.5, 2.0], dtype=np.float64)

    out = F.bce_with_logits_loss(
        Tensor(logits),
        target,
        weight=weight,
        pos_weight=pos_weight,
        reduction="mean",
    )

    log_sigmoid = -np.logaddexp(0.0, -logits)
    log_one_minus_sigmoid = -np.logaddexp(0.0, logits)
    expected_per_elem = -(pos_weight * target * log_sigmoid + (1.0 - target) * log_one_minus_sigmoid)
    expected_per_elem = expected_per_elem * weight.reshape(1, -1)
    expected = expected_per_elem.mean()

    assert np.allclose(out.item(), expected, atol=1e-10)


def test_bce_with_logits_weight_pos_weight_grad_matches_numeric():
    logits = np.random.randn(2, 3).astype(np.float64)
    target = np.array([[1.0, 0.0, 1.0], [0.0, 1.0, 0.0]], dtype=np.float64)
    weight = np.array([1.0, 0.5, 2.0], dtype=np.float64)
    pos_weight = np.array([2.0, 1.3, 1.7], dtype=np.float64)

    t = Tensor(logits.copy(), requires_grad=True)
    loss = F.bce_with_logits_loss(
        t,
        target,
        weight=weight,
        pos_weight=pos_weight,
        reduction="mean",
    )
    loss.backward()

    def f(xv):
        return F.bce_with_logits_loss(
            Tensor(xv),
            target,
            weight=weight,
            pos_weight=pos_weight,
            reduction="mean",
        ).item()

    num = _numeric_grad(f, logits.copy())
    assert np.allclose(t.grad, num, atol=2e-3, rtol=2e-3)


def test_bce_loss_weight_module_matches_functional():
    x = Tensor(np.clip(np.random.rand(2, 3), 1e-4, 1 - 1e-4).astype(np.float64), requires_grad=True)
    target = np.random.rand(2, 3).astype(np.float64)
    weight = np.array([[1.0, 0.5, 2.0], [1.0, 1.5, 0.7]], dtype=np.float64)

    mod = nn.BCELoss(weight=weight, reduction="mean")
    out_mod = mod(x, target)
    out_fun = F.bce_loss(x, target, weight=weight, reduction="mean")
    assert np.allclose(out_mod.item(), out_fun.item(), atol=1e-12)


def test_kl_div_loss_log_target_batchmean_matches_manual():
    inp = np.log(np.array([[0.2, 0.8], [0.6, 0.4]], dtype=np.float64))
    target_prob = np.array([[0.3, 0.7], [0.5, 0.5]], dtype=np.float64)
    target_log = np.log(target_prob)

    out = F.kl_div_loss(Tensor(inp), target_log, reduction="batchmean", log_target=True)
    expected = (target_prob * (target_log - inp)).sum() / inp.shape[0]
    assert np.allclose(out.item(), expected, atol=1e-12)


def test_basic_loss_modules_match_functional_outputs():
    pred = Tensor(np.random.randn(3, 4).astype(np.float64), requires_grad=True)
    target_reg = np.random.randn(3, 4).astype(np.float64)

    mse_m = nn.MSELoss(reduction="mean")
    l1_m = nn.L1Loss(reduction="sum")
    s1_m = nn.SmoothL1Loss(beta=1.0, reduction="mean")

    assert np.allclose(mse_m(pred, target_reg).item(), F.mse_loss(pred, target_reg, reduction="mean").item(), atol=1e-12)
    assert np.allclose(l1_m(pred, target_reg).item(), F.l1_loss(pred, target_reg, reduction="sum").item(), atol=1e-12)
    assert np.allclose(
        s1_m(pred, target_reg).item(),
        F.smooth_l1_loss(pred, target_reg, beta=1.0, reduction="mean").item(),
        atol=1e-12,
    )

    log_probs = F.log_softmax(Tensor(np.random.randn(2, 5).astype(np.float64)), axis=1)
    labels = np.array([2, 4], dtype=np.int64)
    nll_m = nn.NLLLoss(reduction="mean")
    assert np.allclose(nll_m(log_probs, labels).item(), F.nll_loss(log_probs, labels, reduction="mean").item(), atol=1e-12)

    kld_m = nn.KLDivLoss(reduction="sum", log_target=False)
    target_prob = np.array([[0.2, 0.8, 0.0, 0.0, 0.0], [0.1, 0.2, 0.3, 0.2, 0.2]], dtype=np.float64)
    assert np.allclose(kld_m(log_probs, target_prob).item(), F.kl_div_loss(log_probs, target_prob, reduction="sum").item(), atol=1e-12)


def test_bce_with_logits_module_matches_functional_and_backward():
    x_np = np.random.randn(2, 3).astype(np.float64)
    target = np.random.randint(0, 2, size=(2, 3)).astype(np.float64)
    weight = np.array([1.0, 0.8, 1.2], dtype=np.float64)
    pos_weight = np.array([2.0, 1.0, 1.5], dtype=np.float64)

    mod = nn.BCEWithLogitsLoss(weight=weight, pos_weight=pos_weight, reduction="mean")

    x = Tensor(x_np.copy(), requires_grad=True)
    out_mod = mod(x, target)
    out_fun = F.bce_with_logits_loss(x, target, weight=weight, pos_weight=pos_weight, reduction="mean")
    assert np.allclose(out_mod.item(), out_fun.item(), atol=1e-12)

    out_mod.backward()
    assert x.grad.shape == x.shape
