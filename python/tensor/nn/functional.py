import numpy as np

from tensor.tensor import Tensor


def _as_tensor(x):
    return x if isinstance(x, Tensor) else Tensor(x)


def relu(x: Tensor):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    out_data = np.maximum(x_data, 0)
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="relu", device=x.device)

    def _backward():
        if x.requires_grad:
            x.grad += out.grad * (x_data > 0)

    out._backward = _backward
    return out


def sigmoid(x: Tensor):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    out_data = 1.0 / (1.0 + np.exp(-x_data))
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="sigmoid", device=x.device)

    def _backward():
        if x.requires_grad:
            x.grad += out.grad * out_data * (1.0 - out_data)

    out._backward = _backward
    return out


def silu(x: Tensor):
    x = _as_tensor(x)
    return x * sigmoid(x)


def gelu(x: Tensor, approximate: bool = False):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    if approximate:
        out_data = x_data * (1.0 / (1.0 + np.exp(-1.702 * x_data)))

        def _backward():
            if x.requires_grad:
                sig = 1.0 / (1.0 + np.exp(-1.702 * x_data))
                grad_sig = 1.702 * sig * (1 - sig)
                x.grad += out.grad * (sig + x_data * grad_sig)
    else:
        cdf = 0.5 * (1.0 + np.tanh(np.sqrt(2.0 / np.pi) * (x_data + 0.044715 * x_data ** 3)))
        out_data = x_data * cdf

        def _backward():
            if x.requires_grad:
                pdf = np.exp(-0.5 * x_data ** 2) / np.sqrt(2.0 * np.pi)
                dcdf_dx = pdf * (1.0 + (0.134145 * x_data ** 2)) / (1.0 + (0.1978 * x_data ** 2))
                x.grad += out.grad * (cdf + x_data * dcdf_dx)

    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="gelu", device=x.device)
    out._backward = _backward
    return out


def softmax(x: Tensor, axis=-1, dim=None):
    x = _as_tensor(x)
    if dim is not None:
        axis = dim
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


def log_softmax(x: Tensor, axis=-1, dim=None):
    x = _as_tensor(x)
    if dim is not None:
        axis = dim
    x_data = x.to_numpy()
    x_max = x_data.max(axis=axis, keepdims=True)
    exp_x = np.exp(x_data - x_max)
    denom = exp_x.sum(axis=axis, keepdims=True)
    log_probs = (x_data - x_max) - np.log(np.maximum(denom, 1e-12))
    out = Tensor(log_probs, requires_grad=x.requires_grad, _children=(x,), _op="log_softmax", device=x.device)

    def _backward():
        if x.requires_grad:
            probs = np.exp(log_probs)
            sum_g = out.grad.sum(axis=axis, keepdims=True)
            x.grad += out.grad - probs * sum_g

    out._backward = _backward
    return out


def linear(x: Tensor, weight: Tensor, bias: Tensor | None = None):
    x = _as_tensor(x)
    weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)
    out = x @ weight
    if bias is not None:
        out = out + bias
    return out


def layer_norm(x: Tensor, normalized_shape, weight=None, bias=None, eps=1e-5):
    x = _as_tensor(x)
    if weight is not None:
        weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)
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
    x = _as_tensor(x)
    if weight is not None:
        weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)
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


def dropout(x: Tensor, p=0.5, training=True, inplace=False):
    x = _as_tensor(x)
    if inplace:
        raise NotImplementedError("inplace dropout is not supported")
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
        return out.sum()
    return out


def embedding(input, weight: Tensor, padding_idx=None):
    weight = _as_tensor(weight)
    input_ids = np.asarray(input, dtype=np.int64)

    if padding_idx is not None:
        padding_idx = int(padding_idx)

    out_data = weight.data[input_ids]
    out = Tensor(out_data, requires_grad=weight.requires_grad, _children=(weight,), _op="embedding", device=weight.device)

    def _backward():
        if weight.requires_grad:
            grad = np.zeros_like(weight.data)
            if padding_idx is None:
                np.add.at(grad, input_ids, out.grad)
            else:
                valid = input_ids != padding_idx
                if np.any(valid):
                    np.add.at(grad, input_ids[valid], out.grad[valid])
            weight.grad += grad

    out._backward = _backward
    return out


def cross_entropy(input: Tensor, target, reduction="mean"):
    log_probs = log_softmax(input, axis=-1)
    return nll_loss(log_probs, target, reduction=reduction)


def nll_loss(input: Tensor, target, reduction="mean"):
    # input: log-probabilities
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target = target.to_numpy()
    target = np.asarray(target, dtype=np.int64)
    x = input.to_numpy()

    if x.ndim == 1:
        x = x.reshape(1, -1)
        target = target.reshape(1,)

    c = x.shape[-1]
    x_flat = x.reshape(-1, c)
    target_flat = target.reshape(-1)
    n = target_flat.shape[0]

    loss_vals = -x_flat[np.arange(n), target_flat]
    if reduction == "sum":
        out_data = loss_vals.sum()
    elif reduction == "none":
        out_data = loss_vals.reshape(target.shape)
    else:
        out_data = loss_vals.mean()

    out = Tensor(np.array(out_data) if np.isscalar(out_data) else out_data, requires_grad=input.requires_grad, _children=(input,), _op="nll_loss", device=input.device)

    def _backward():
        if input.requires_grad:
            grad = np.zeros_like(x_flat)
            grad[np.arange(n), target_flat] = -1.0
            if reduction == "mean":
                grad /= n
                grad = grad.reshape(x.shape)
                input.grad += grad * out.grad
            elif reduction == "sum":
                grad = grad.reshape(x.shape)
                input.grad += grad * out.grad
            else:
                grad = grad.reshape(x.shape)
                input.grad += grad * out.grad.reshape(target.shape + (1,))

    out._backward = _backward
    return out


__all__ = [
    "relu",
    "sigmoid",
    "silu",
    "gelu",
    "softmax",
    "log_softmax",
    "linear",
    "layer_norm",
    "rms_norm",
    "dropout",
    "embedding",
    "mse_loss",
    "cross_entropy",
    "nll_loss",
]
