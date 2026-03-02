import numpy as np

from tensor.tensor import Tensor
from tensor.losses import cross_entropy as _cross_entropy


def relu(x: Tensor):
    x_data = x.to_numpy()
    out_data = np.maximum(x_data, 0)
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="relu", device=x.device)

    def _backward():
        if x.requires_grad:
            x.grad += out.grad * (x_data > 0)

    out._backward = _backward
    return out


def sigmoid(x: Tensor):
    x_data = x.to_numpy()
    out_data = 1.0 / (1.0 + np.exp(-x_data))
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="sigmoid", device=x.device)

    def _backward():
        if x.requires_grad:
            x.grad += out.grad * out_data * (1.0 - out_data)

    out._backward = _backward
    return out


def silu(x: Tensor):
    return x * sigmoid(x)


def gelu(x: Tensor):
    x_data = x.to_numpy()
    out_data = x_data * (1.0 / (1.0 + np.exp(-1.702 * x_data)))
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="gelu", device=x.device)

    def _backward():
        if x.requires_grad:
            sig = 1.0 / (1.0 + np.exp(-1.702 * x_data))
            grad_sig = 1.702 * sig * (1 - sig)
            x.grad += out.grad * (sig + x_data * grad_sig)

    out._backward = _backward
    return out


def softmax(x: Tensor, axis=-1):
    x_data = x.to_numpy()
    x_max = x_data.max(axis=axis, keepdims=True)
    exp_x = np.exp(x_data - x_max)
    denom = exp_x.sum(axis=axis, keepdims=True)
    out_data = exp_x / np.maximum(denom, 1e-12)
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="softmax", device=x.device)

    def _backward():
        if x.requires_grad:
            out_host = out.to_numpy()
            sum_gs = (out.grad * out_host).sum(axis=axis, keepdims=True)
            x.grad += out_host * (out.grad - sum_gs)

    out._backward = _backward
    return out


def linear(x: Tensor, weight: Tensor, bias: Tensor | None = None):
    out = x @ weight
    if bias is not None:
        out = out + bias
    return out


def layer_norm(x: Tensor, normalized_shape, weight=None, bias=None, eps=1e-5):
    if isinstance(normalized_shape, int):
        normalized_shape = (normalized_shape,)
    x_data = x.to_numpy()
    norm_dims = len(normalized_shape)
    norm_axes = tuple(range(x_data.ndim - norm_dims, x_data.ndim))
    mean = x_data.mean(axis=norm_axes, keepdims=True)
    var = x_data.var(axis=norm_axes, keepdims=True)
    x_normalized = (x_data - mean) / np.sqrt(var + eps)

    w = weight.to_numpy() if weight is not None else 1.0
    b = bias.to_numpy() if bias is not None else 0.0
    out_data = x_normalized * w + b

    requires_grad = x.requires_grad or (weight is not None and weight.requires_grad) or (bias is not None and bias.requires_grad)
    children = [c for c in [x, weight, bias] if c is not None and getattr(c, "requires_grad", False)]
    out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="layer_norm", device=x.device)

    def _backward():
        if not out.grad.any():
            return
        reduce_axes = tuple(range(out.grad.ndim - len(normalized_shape)))
        if weight is not None and weight.requires_grad:
            weight.grad += (out.grad * x_normalized).sum(axis=reduce_axes)
        if bias is not None and bias.requires_grad:
            bias.grad += out.grad.sum(axis=reduce_axes)
        if x.requires_grad:
            w_data = w if np.isscalar(w) else w
            dxhat = out.grad * w_data
            inv_std = 1.0 / np.sqrt(var + eps)
            n = float(np.prod(normalized_shape))
            sum_dxhat = dxhat.sum(axis=norm_axes, keepdims=True)
            sum_dxhat_xhat = (dxhat * x_normalized).sum(axis=norm_axes, keepdims=True)
            x.grad += (inv_std / n) * (n * dxhat - sum_dxhat - x_normalized * sum_dxhat_xhat)

    out._backward = _backward
    return out


def rms_norm(x: Tensor, normalized_shape, weight=None, bias=None, eps=1e-6):
    if isinstance(normalized_shape, int):
        normalized_shape = (normalized_shape,)
    x_data = x.to_numpy()
    norm_dims = len(normalized_shape)
    norm_axes = tuple(range(x_data.ndim - norm_dims, x_data.ndim))
    mean_sq = (x_data ** 2).mean(axis=norm_axes, keepdims=True)
    inv_rms = 1.0 / np.sqrt(mean_sq + eps)
    x_normalized = x_data * inv_rms

    w = weight.to_numpy() if weight is not None else 1.0
    b = bias.to_numpy() if bias is not None else 0.0
    out_data = x_normalized * w + b

    requires_grad = x.requires_grad or (weight is not None and weight.requires_grad) or (bias is not None and bias.requires_grad)
    children = [c for c in [x, weight, bias] if c is not None and getattr(c, "requires_grad", False)]
    out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="rms_norm", device=x.device)

    def _backward():
        if not out.grad.any():
            return
        reduce_axes = tuple(range(out.grad.ndim - len(normalized_shape)))
        if weight is not None and weight.requires_grad:
            weight.grad += (out.grad * x_normalized).sum(axis=reduce_axes)
        if bias is not None and bias.requires_grad:
            bias.grad += out.grad.sum(axis=reduce_axes)
        if x.requires_grad:
            w_data = w if np.isscalar(w) else w
            dxhat = out.grad * w_data
            n = float(np.prod(normalized_shape))
            mean_dxhat_x = (dxhat * x_data).sum(axis=norm_axes, keepdims=True) / n
            x.grad += dxhat * inv_rms - x_data * (inv_rms ** 3) * mean_dxhat_x

    out._backward = _backward
    return out


def dropout(x: Tensor, p=0.5, training=True):
    if not training or p == 0:
        return x
    if p < 0 or p >= 1:
        raise ValueError(f"dropout p must satisfy 0 <= p < 1, got {p}")
    x_data = x.to_numpy()
    mask = np.random.binomial(1, 1 - p, size=x_data.shape) / (1 - p)
    out_data = x_data * mask
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="dropout", device=x.device)

    def _backward():
        if x.requires_grad:
            x.grad += out.grad * mask

    out._backward = _backward
    return out


def mse_loss(input: Tensor, target, reduction="mean"):
    target = target if isinstance(target, Tensor) else Tensor(target)
    diff = input - target
    out = diff * diff
    if reduction == "mean":
        return out.mean()
    if reduction == "sum":
        return Tensor(out.to_numpy().sum(), requires_grad=out.requires_grad, _children=(out,), _op="sum", device=out.device)
    return out


def cross_entropy(input: Tensor, target):
    return _cross_entropy(input, target)


__all__ = [
    "relu",
    "sigmoid",
    "silu",
    "gelu",
    "softmax",
    "linear",
    "layer_norm",
    "rms_norm",
    "dropout",
    "mse_loss",
    "cross_entropy",
]
