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


def tanh(x: Tensor):
    """双曲正切激活函数 tanh(x) = (e^x - e^-x) / (e^x + e^-x)"""
    x = _as_tensor(x)
    x_data = x.to_numpy()
    out_data = np.tanh(x_data)
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="tanh", device=x.device)

    def _backward():
        if x.requires_grad:
            # 梯度: 1 - tanh^2(x)
            x.grad += out.grad * (1.0 - out_data ** 2)

    out._backward = _backward
    return out


def elu(x: Tensor, alpha: float = 1.0):
    """指数线性单元 (Exponential Linear Unit)
    
    ELU(x) = x if x > 0, else alpha * (e^x - 1)
    """
    x = _as_tensor(x)
    x_data = x.to_numpy()
    out_data = np.where(x_data > 0, x_data, alpha * (np.exp(x_data) - 1))
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="elu", device=x.device)

    def _backward():
        if x.requires_grad:
            # 梯度: 1 if x > 0, else alpha * e^x
            grad = np.where(x_data > 0, 1.0, alpha * np.exp(x_data))
            x.grad += out.grad * grad

    out._backward = _backward
    return out


def selu(x: Tensor):
    """自缩放指数线性单元 (Scaled ELU)
    
    SELU(x) = lambda * ELU(x)
    其中 lambda ≈ 1.0507, alpha ≈ 1.6733
    """
    lambda_val = 1.0507009873554804
    alpha_val = 1.6732632423543772
    
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    elu_out = np.where(x_data > 0, x_data, alpha_val * (np.exp(x_data) - 1))
    out_data = lambda_val * elu_out
    
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="selu", device=x.device)

    def _backward():
        if x.requires_grad:
            grad = np.where(x_data > 0, 1.0, alpha_val * np.exp(x_data))
            x.grad += out.grad * lambda_val * grad

    out._backward = _backward
    return out


def prelu(x: Tensor, weight: Tensor):
    """参数化ReLU (Parametric ReLU)
    
    PReLU(x) = x if x > 0, else weight * x
    weight 是可学习的参数
    """
    x = _as_tensor(x)
    weight = _as_tensor(weight)
    
    x_data = x.to_numpy()
    w_data = weight.to_numpy()
    
    out_data = np.where(x_data > 0, x_data, w_data * x_data)
    
    out = Tensor(out_data, requires_grad=x.requires_grad, 
                 _children=(x, weight), _op="prelu", device=x.device)

    def _backward():
        if x.requires_grad:
            grad_x = np.where(x_data > 0, 1.0, w_data)
            x.grad += out.grad * grad_x
        
        if weight.requires_grad:
            grad_w = np.where(x_data > 0, 0.0, x_data)
            weight.grad += out.grad * grad_w

    out._backward = _backward
    return out


def rrelu(x: Tensor, lower: float = 1.0/8, upper: float = 1.0/3, training: bool = True):
    """随机ReLU (Randomized ReLU)
    
    在训练时，negative_slope在[lower, upper]之间随机
    在评估时，使用(lower + upper) / 2作为固定值
    """
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    if training:
        # 训练时随机
        negative_slope = np.random.uniform(lower, upper, x_data.shape)
    else:
        # 评估时使用固定值
        negative_slope = (lower + upper) / 2.0
    
    out_data = np.where(x_data > 0, x_data, negative_slope * x_data)
    
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="rrelu", device=x.device)

    def _backward():
        if x.requires_grad:
            grad = np.where(x_data > 0, 1.0, negative_slope)
            x.grad += out.grad * grad

    out._backward = _backward
    return out


def hardtanh(x: Tensor, min_val: float = -1.0, max_val: float = 1.0):
    """硬双曲正切 (Hard Tanh)
    
    HardTanh(x) = clip(x, min_val, max_val)
    在量化场景中很有用
    """
    x = _as_tensor(x)
    x_data = x.to_numpy()
    out_data = np.clip(x_data, min_val, max_val)
    
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="hardtanh", device=x.device)

    def _backward():
        if x.requires_grad:
            # 只有在 min_val < x < max_val 时才有梯度
            grad = ((x_data > min_val) & (x_data < max_val)).astype(np.float32)
            x.grad += out.grad * grad

    out._backward = _backward
    return out


def hardswish(x: Tensor, inplace: bool = False):
    """硬Swish激活 (Hard Swish)
    
    用于移动设备的高效激活函数
    HardSwish(x) = x * clip(x + 3, 0, 6) / 6
    """
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    # clip(x + 3, 0, 6) / 6
    clipped = np.clip(x_data + 3.0, 0.0, 6.0) / 6.0
    out_data = x_data * clipped
    
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="hardswish", device=x.device)

    def _backward():
        if x.requires_grad:
            # 分段梯度
            grad = np.zeros_like(x_data)
            
            # 当 x < -3 时，梯度为 0
            # 当 -3 <= x < 3 时，梯度为 x/3 + clipped = 2x/6 + 1
            # 当 x >= 3 时，梯度为 1
            
            mask_mid = (x_data >= -3) & (x_data < 3)
            mask_high = x_data >= 3
            
            grad[mask_mid] = 2 * x_data[mask_mid] / 6 + 1
            grad[mask_high] = 1.0
            
            x.grad += out.grad * grad

    out._backward = _backward
    return out


def mish(x: Tensor):
    """Mish激活函数
    
    Mish(x) = x * tanh(softplus(x)) = x * tanh(ln(1 + e^x))
    """
    x = _as_tensor(x)
    x_data = x.to_numpy()
    
    # 数值稳定的softplus
    softplus = np.where(x_data > 20, x_data, np.log(1.0 + np.exp(x_data)))
    tanh_sp = np.tanh(softplus)
    out_data = x_data * tanh_sp
    
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="mish", device=x.device)

    def _backward():
        if x.requires_grad:
            # 梯度: tanh(softplus(x)) + x * sech^2(softplus(x)) * sigmoid(x)
            sigmoid_x = 1.0 / (1.0 + np.exp(-x_data))
            sech2_sp = 1.0 - tanh_sp ** 2
            grad = tanh_sp + x_data * sech2_sp * sigmoid_x
            x.grad += out.grad * grad

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


def bce_loss(input: Tensor, target, reduction="mean"):
    """Binary Cross Entropy Loss
    
    Computes: -[target * log(input) + (1 - target) * log(1 - input)]
    Numerically stable version handles edge cases.
    """
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target = target.to_numpy()
    target = np.asarray(target)
    
    x = input.to_numpy()
    # Clamp to prevent log(0)
    x = np.clip(x, 1e-7, 1 - 1e-7)
    
    loss_vals = -(target * np.log(x) + (1 - target) * np.log(1 - x))
    
    if reduction == "sum":
        out_data = loss_vals.sum()
    elif reduction == "none":
        out_data = loss_vals
    else:  # mean
        out_data = loss_vals.mean()
    
    out = Tensor(np.array(out_data) if np.isscalar(out_data) else out_data, 
                 requires_grad=input.requires_grad, _children=(input,), 
                 _op="bce_loss", device=input.device)
    
    def _backward():
        if input.requires_grad:
            x_clamped = np.clip(x, 1e-7, 1 - 1e-7)
            grad = -(target / x_clamped - (1 - target) / (1 - x_clamped))
            if reduction == "mean":
                grad = grad / target.size
            out.grad_data = np.array(out.grad) if isinstance(out.grad, Tensor) else out.grad
            input.grad += grad * out.grad_data
    
    out._backward = _backward
    return out


def bce_with_logits_loss(input: Tensor, target, reduction="mean"):
    """Binary Cross Entropy with Logits Loss
    
    Combines sigmoid and BCE into one numerically stable operation.
    More stable than sigmoid(input) -> bce_loss()
    """
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target = target.to_numpy()
    target = np.asarray(target)
    
    x = input.to_numpy()
    # Numerically stable: max(x, 0) - x * target + log(1 + exp(-abs(x)))
    max_x = np.maximum(x, 0)
    loss_vals = max_x - x * target + np.log(1 + np.exp(-np.abs(x)))
    
    if reduction == "sum":
        out_data = loss_vals.sum()
    elif reduction == "none":
        out_data = loss_vals
    else:  # mean
        out_data = loss_vals.mean()
    
    out = Tensor(np.array(out_data) if np.isscalar(out_data) else out_data, 
                 requires_grad=input.requires_grad, _children=(input,), 
                 _op="bce_with_logits_loss", device=input.device)
    
    def _backward():
        if input.requires_grad:
            # Gradient: sigmoid(x) - target
            sigmoid_x = 1.0 / (1.0 + np.exp(-np.clip(x, -500, 500)))
            grad = sigmoid_x - target
            if reduction == "mean":
                grad = grad / target.size
            out.grad_data = np.array(out.grad) if isinstance(out.grad, Tensor) else out.grad
            input.grad += grad * out.grad_data
    
    out._backward = _backward
    return out


def l1_loss(input: Tensor, target, reduction="mean"):
    """L1 Loss (Mean Absolute Error)
    
    Computes: |input - target|
    """
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target = target.to_numpy()
    target = np.asarray(target)
    
    x = input.to_numpy()
    diff = x - target
    loss_vals = np.abs(diff)
    
    if reduction == "sum":
        out_data = loss_vals.sum()
    elif reduction == "none":
        out_data = loss_vals
    else:  # mean
        out_data = loss_vals.mean()
    
    out = Tensor(np.array(out_data) if np.isscalar(out_data) else out_data, 
                 requires_grad=input.requires_grad, _children=(input,), 
                 _op="l1_loss", device=input.device)
    
    def _backward():
        if input.requires_grad:
            grad = np.sign(diff)
            if reduction == "mean":
                grad = grad / diff.size
            out.grad_data = np.array(out.grad) if isinstance(out.grad, Tensor) else out.grad
            input.grad += grad * out.grad_data
    
    out._backward = _backward
    return out


def smooth_l1_loss(input: Tensor, target, reduction="mean", beta=1.0):
    """Smooth L1 Loss (Huber Loss)
    
    Combines L1 and L2 loss for robustness:
    - L2 loss when |x - target| < beta
    - L1 loss - beta/2 otherwise
    """
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target = target.to_numpy()
    target = np.asarray(target)
    
    x = input.to_numpy()
    diff = x - target
    abs_diff = np.abs(diff)
    
    # Smooth L1: 0.5 * x^2 / beta if |x| < beta, |x| - 0.5 * beta otherwise
    loss_vals = np.where(abs_diff < beta, 
                         0.5 * diff * diff / beta,
                         abs_diff - 0.5 * beta)
    
    if reduction == "sum":
        out_data = loss_vals.sum()
    elif reduction == "none":
        out_data = loss_vals
    else:  # mean
        out_data = loss_vals.mean()
    
    out = Tensor(np.array(out_data) if np.isscalar(out_data) else out_data, 
                 requires_grad=input.requires_grad, _children=(input,), 
                 _op="smooth_l1_loss", device=input.device)
    
    def _backward():
        if input.requires_grad:
            grad = np.where(abs_diff < beta,
                           diff / beta,
                           np.sign(diff))
            if reduction == "mean":
                grad = grad / diff.size
            out.grad_data = np.array(out.grad) if isinstance(out.grad, Tensor) else out.grad
            input.grad += grad * out.grad_data
    
    out._backward = _backward
    return out


def kl_div_loss(input: Tensor, target, reduction="mean"):
    """Kullback-Leibler Divergence Loss
    
    Computes KL(target || input) where both are log-probabilities
    KL = sum(target * (log(target) - input))
    """
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target = target.to_numpy()
    target = np.asarray(target)
    
    x = input.to_numpy()  # log-probabilities
    target = np.asarray(target)
    
    # Avoid log(0)
    target_clipped = np.clip(target, 1e-10, 1.0)
    log_target = np.log(target_clipped)
    
    loss_vals = target * (log_target - x)
    
    if reduction == "sum":
        out_data = loss_vals.sum()
    elif reduction == "none":
        out_data = loss_vals
    else:  # mean
        out_data = loss_vals.mean()
    
    out = Tensor(np.array(out_data) if np.isscalar(out_data) else out_data, 
                 requires_grad=input.requires_grad, _children=(input,), 
                 _op="kl_div_loss", device=input.device)
    
    def _backward():
        if input.requires_grad:
            grad = -target
            if reduction == "mean":
                grad = grad / target.size
            out.grad_data = np.array(out.grad) if isinstance(out.grad, Tensor) else out.grad
            input.grad += grad * out.grad_data
    
    out._backward = _backward
    return out


__all__ = [
    "relu",
    "sigmoid",
    "tanh",
    "elu",
    "selu",
    "prelu",
    "rrelu",
    "hardtanh",
    "hardswish",
    "mish",
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
    "bce_loss",
    "bce_with_logits_loss",
    "l1_loss",
    "smooth_l1_loss",
    "kl_div_loss",
]
