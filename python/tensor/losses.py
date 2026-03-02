import numpy as np

from tensor.core.tensor import Tensor


def cross_entropy(logits: Tensor, targets):
    targets = np.asarray(targets, dtype=np.int64)
    b, t, v = logits.data.shape
    flat_logits = logits.data.reshape(b * t, v)
    flat_targets = targets.reshape(b * t)

    shifted = flat_logits - flat_logits.max(axis=1, keepdims=True)
    exp_scores = np.exp(shifted)
    probs = exp_scores / exp_scores.sum(axis=1, keepdims=True)

    n = flat_targets.shape[0]
    eps = 1e-12
    loss_value = -np.log(probs[np.arange(n), flat_targets] + eps).mean()

    out = Tensor(np.array(loss_value), requires_grad=logits.requires_grad, _children=(logits,), _op="cross_entropy")

    def _backward():
        if logits.requires_grad:
            grad_logits = probs
            grad_logits[np.arange(n), flat_targets] -= 1.0
            grad_logits /= n
            grad_logits = grad_logits.reshape(b, t, v)
            logits.grad += grad_logits * out.grad

    out._backward = _backward
    return out


def cross_entropy_loss(logits: Tensor, targets):
    # Backwards-compat alias used by __init__.py
    return cross_entropy(logits, targets)
