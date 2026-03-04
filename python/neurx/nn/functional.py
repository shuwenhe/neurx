import numpy as np

from neurx.neurx import Tensor, stack


def _as_tensor(x):
    return x if isinstance(x, Tensor) else Tensor(x)


def _pair(value):
    if isinstance(value, tuple):
        if len(value) != 2:
            raise ValueError(f"expected a 2-tuple, got {value}")
        return value
    if isinstance(value, list):
        if len(value) != 2:
            raise ValueError(f"expected a list with 2 values, got {value}")
        return tuple(value)
    return (value, value)


def _single(value):
    if isinstance(value, tuple):
        if len(value) != 1:
            raise ValueError(f"expected a 1-tuple, got {value}")
        return value[0]
    if isinstance(value, list):
        if len(value) != 1:
            raise ValueError(f"expected a list with 1 value, got {value}")
        return value[0]
    return value


def _triple(value):
    if isinstance(value, tuple):
        if len(value) != 3:
            raise ValueError(f"expected a 3-tuple, got {value}")
        return value
    if isinstance(value, list):
        if len(value) != 3:
            raise ValueError(f"expected a list with 3 values, got {value}")
        return tuple(value)
    return (value, value, value)


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
    out_data = 1.0 / (1.0 + np.exp(-np.clip(x_data, -500, 500)))
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="sigmoid", device=x.device)

    def _backward():
        if x.requires_grad:
            x.grad += out.grad * (out_data * (1.0 - out_data))

    out._backward = _backward
    return out


def tanh(x: Tensor):
    x = _as_tensor(x)
    x_data = x.to_numpy()
    out_data = np.tanh(x_data)
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="tanh", device=x.device)

    def _backward():
        if x.requires_grad:
            x.grad += out.grad * (1.0 - out_data ** 2)

    out._backward = _backward
    return out


def focal_loss(
    input: Tensor,
    target,
    alpha: float = 0.25,
    gamma: float = 2.0,
    weight=None,
    ignore_index: int = -100,
    reduction: str = "mean",
    dim=None,
):
    """
    Focal Loss - addresses class imbalance by focusing on hard negatives.
    
    Focal loss applies a modulating term to cross entropy loss to focus learning
    on hard negative examples. It is particularly useful for object detection
    where there is extreme class imbalance between foreground and background.
    
    Formula: FL(p_t) = -α * (1 - p_t)^γ * log(p_t)
    
    Args:
        input: Model predictions logits (batch, num_classes) or (batch,)
        target: Ground truth class indices (batch,)
        alpha: Weighting factor (default 0.25) - down-weights easy examples
        gamma: Focusing parameter (default 2.0) - emphasizes hard examples
        weight: Class weights for balancing
        ignore_index: Index to ignore (default -100)
        reduction: 'none', 'mean', or 'sum' (default 'mean')
        dim: Class dimension (auto-detected if None)
    
    Returns:
        Tensor: Focal loss value
    
    Example:
        >>> input = neurx.randn(8, 4)  # 8 samples, 4 classes
        >>> target = neurx.Tensor([0, 1, 2, 3, 0, 1, 2, 3])
        >>> loss = F.focal_loss(input, target, alpha=0.25, gamma=2.0)
    """
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target_arr = target.to_numpy()
    else:
        target_arr = np.asarray(target)
    
    target_arr = np.asarray(target_arr, dtype=np.int64)
    x = input.to_numpy()
    
    if reduction not in ("none", "mean", "sum"):
        raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")
    if not (0 <= alpha <= 1.0):
        raise ValueError(f"alpha must be in [0, 1], got {alpha}")
    if gamma < 0:
        raise ValueError(f"gamma must be non-negative, got {gamma}")
    
    class_dim = _infer_class_dim_for_loss(x.shape, target_arr.shape, dim=dim)
    
    # Convert logits to log probabilities
    log_probs = log_softmax(input, axis=class_dim)
    log_probs_np = log_probs.to_numpy()
    
    # Get probabilities from log probabilities
    probs = np.exp(log_probs_np)
    
    # Reshape for batch processing
    if x.ndim == 1:
        x_moved = x.reshape(1, x.shape[0])
        target_shape = target_arr.shape
        target_flat = target_arr.reshape(-1)
    else:
        x_moved = np.moveaxis(x, class_dim, -1)
        c = x_moved.shape[-1]
        target_shape = target_arr.shape
        target_flat = target_arr.reshape(-1)
    
    x_flat = x_moved.reshape(-1, c) if x.ndim > 1 else x_moved
    probs_flat = np.moveaxis(probs.reshape(-1, probs.shape[-1]) if x.ndim > 1 else probs, -1, -1)
    
    valid_mask = target_flat != int(ignore_index)
    valid_indices = np.nonzero(valid_mask)[0]
    targets_valid = target_flat[valid_mask]
    
    if len(valid_indices) == 0:
        return Tensor(0.0)
    
    # Get logits and probs for target classes
    logits_valid = x_flat[valid_indices, targets_valid]
    probs_valid = np.exp(log_probs_np.reshape(-1, c)[valid_indices, targets_valid])
    
    # Calculate focal loss: -alpha * (1-p)^gamma * log(p)
    focal_weight = alpha * np.power(1.0 - probs_valid, gamma)
    focal = focal_weight * (-logits_valid)  # Since logits are log(p)
    
    # Apply weights if provided
    if weight is not None:
        weight_arr = weight.to_numpy() if isinstance(weight, Tensor) else np.asarray(weight)
        weight_arr = np.asarray(weight_arr)
        if weight_arr.shape != (c,):
            raise ValueError(f"weight shape {weight_arr.shape} does not match num_classes {c}")
        focal = focal * weight_arr[targets_valid]
    
    # Apply reduction
    if reduction == "none":
        result_full = np.zeros(target_flat.shape)
        result_full[valid_indices] = focal
        out_data = result_full.reshape(target_shape)
    elif reduction == "mean":
        out_data = np.mean(focal)
    elif reduction == "sum":
        out_data = np.sum(focal)
    
    out = Tensor(out_data, input.requires_grad, (input,), "focal_loss")
    
    def _backward():
        if not input.requires_grad:
            return
        
        c = x_flat.shape[-1] if x_flat.ndim > 1 else x.shape[-1]
        grad_shape = x.shape
        
        # Compute gradient
        # d(focal)/d(logits) = -alpha * (1-p)^gamma / p * (log(p) + (1-p)^gamma * gamma / (1-p)) * dL
        probs_safe = np.clip(probs_flat.reshape(-1, c), 1e-7, 1.0)
        focal_grad_term = alpha * np.power(1.0 - probs_safe, gamma)
        
        grad_full = np.zeros_like(x_flat)
        for i in valid_indices:
            t = targets_valid[np.where(valid_indices == i)[0][0]]
            grad_full[i, :] = focal_grad_term[np.where(valid_indices == i)[0][0], :] / probs_safe[i, :]
            grad_full[i, t] -= focal_grad_term[np.where(valid_indices == i)[0][0], t]
        
        if reduction == "mean":
            grad_full = grad_full / len(valid_indices)
        
        # Restore original shape
        if x.ndim == 1:
            grad = grad_full[0]
        else:
            grad = np.moveaxis(grad_full.reshape(x_moved.shape), -1, class_dim)
        
        input.grad += grad * out.grad
    
    out._backward = _backward
    return out


def leaky_relu(x: Tensor, negative_slope: float = 0.01, inplace: bool = False):
    x = _as_tensor(x)
    if inplace:
        raise NotImplementedError("inplace leaky_relu is not supported")
    x_data = x.to_numpy()
    out_data = np.where(x_data > 0, x_data, negative_slope * x_data)
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="leaky_relu", device=x.device)

    def _backward():
        if x.requires_grad:
            grad = np.where(x_data > 0, 1.0, negative_slope)
            x.grad += out.grad * grad

    out._backward = _backward
    return out


def elu(x: Tensor, alpha: float = 1.0, inplace: bool = False):
    x = _as_tensor(x)
    if inplace:
        raise NotImplementedError("inplace elu is not supported")
    x_data = x.to_numpy()
    out_data = np.where(x_data > 0, x_data, alpha * (np.exp(x_data) - 1.0))
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="elu", device=x.device)

    def _backward():
        if x.requires_grad:
            grad = np.where(x_data > 0, 1.0, alpha * np.exp(x_data))
            x.grad += out.grad * grad

    out._backward = _backward
    return out


def selu(x: Tensor, inplace: bool = False):
    alpha = 1.6732632423543772
    scale = 1.0507009873554805
    x = _as_tensor(x)
    if inplace:
        raise NotImplementedError("inplace selu is not supported")
    x_data = x.to_numpy()
    inner = np.where(x_data > 0, x_data, alpha * (np.exp(x_data) - 1.0))
    out_data = scale * inner
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="selu", device=x.device)

    def _backward():
        if x.requires_grad:
            grad_inner = np.where(x_data > 0, 1.0, alpha * np.exp(x_data))
            x.grad += out.grad * (scale * grad_inner)

    out._backward = _backward
    return out


def prelu(x: Tensor, weight: Tensor, inplace: bool = False):
    x = _as_tensor(x)
    weight = _as_tensor(weight)
    if inplace:
        raise NotImplementedError("inplace prelu is not supported")

    x_data = x.to_numpy()
    w_data = weight.to_numpy()
    if w_data.ndim == 0 or w_data.size == 1:
        slope = float(w_data.reshape(-1)[0])
    else:
        raise ValueError("functional prelu currently supports scalar weight only")

    out_data = np.where(x_data > 0, x_data, slope * x_data)
    out = Tensor(out_data, requires_grad=(x.requires_grad or weight.requires_grad), _children=(x, weight), _op="prelu", device=x.device)

    def _backward():
        if x.requires_grad:
            dx = np.where(x_data > 0, 1.0, slope)
            x.grad += out.grad * dx
        if weight.requires_grad:
            dw = (out.grad * np.where(x_data > 0, 0.0, x_data)).sum()
            weight.grad += np.asarray(dw, dtype=weight.grad.dtype)

    out._backward = _backward
    return out


def rrelu(
    x: Tensor,
    lower: float = 1.0 / 8.0,
    upper: float = 1.0 / 3.0,
    training: bool = False,
    inplace: bool = False,
):
    x = _as_tensor(x)
    if inplace:
        raise NotImplementedError("inplace rrelu is not supported")
    if lower > upper:
        raise ValueError("lower must be <= upper")

    x_data = x.to_numpy()
    slope = (lower + upper) * 0.5
    if training:
        slope_arr = np.random.uniform(lower, upper, size=x_data.shape)
    else:
        slope_arr = slope
    out_data = np.where(x_data > 0, x_data, slope_arr * x_data)
    out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="rrelu", device=x.device)

    def _backward():
        if x.requires_grad:
            grad = np.where(x_data > 0, 1.0, slope_arr)
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


def _rnn_prepare_input(input: Tensor, batch_first: bool):
    input = _as_tensor(input)
    if input.ndim != 3:
        raise ValueError(
            f"expected input with shape (seq, batch, feature) or (batch, seq, feature), got {input.shape}"
        )
    x_seq = input.transpose(0, 1) if batch_first else input
    return input, x_seq


def _rnn_prepare_hidden(h, batch_size, hidden_size, name, device, dtype):
    if h is None:
        return Tensor(np.zeros((batch_size, hidden_size), dtype=dtype), device=device)

    h = _as_tensor(h)
    if h.ndim == 3:
        if h.shape[0] != 1:
            raise ValueError(f"{name} first dim must be 1 for functional single-layer API, got {h.shape[0]}")
        h = h[0]
    elif h.ndim != 2:
        raise ValueError(f"{name} must have shape (batch, hidden) or (1, batch, hidden), got {h.shape}")

    if h.shape != (batch_size, hidden_size):
        raise ValueError(f"{name} shape must be ({batch_size}, {hidden_size}), got {h.shape}")
    return h


def _rnn_stack_or_empty(outputs, batch_size, hidden_size, dtype, device):
    if len(outputs) == 0:
        return Tensor(np.zeros((0, batch_size, hidden_size), dtype=dtype), device=device)
    return stack(outputs, axis=0)


def rnn_cell(
    input: Tensor,
    hx: Tensor,
    weight_ih: Tensor,
    weight_hh: Tensor,
    bias_ih: Tensor | None = None,
    bias_hh: Tensor | None = None,
    nonlinearity: str = "tanh",
):
    input = _as_tensor(input)
    hx = _as_tensor(hx)
    weight_ih = _as_tensor(weight_ih)
    weight_hh = _as_tensor(weight_hh)
    if bias_ih is not None:
        bias_ih = _as_tensor(bias_ih)
    if bias_hh is not None:
        bias_hh = _as_tensor(bias_hh)

    if input.ndim != 2:
        raise ValueError(f"rnn_cell input must be 2D (batch, input_size), got {input.shape}")
    if hx.ndim != 2:
        raise ValueError(f"rnn_cell hx must be 2D (batch, hidden_size), got {hx.shape}")
    if weight_ih.ndim != 2 or weight_hh.ndim != 2:
        raise ValueError(f"rnn_cell weight_ih/weight_hh must be 2D, got {weight_ih.shape} and {weight_hh.shape}")

    batch_size, input_size = input.shape
    if hx.shape[0] != batch_size:
        raise ValueError(f"rnn_cell hx batch size must match input batch size ({batch_size}), got {hx.shape[0]}")

    hidden_size = hx.shape[1]
    if weight_ih.shape != (input_size, hidden_size):
        raise ValueError(f"rnn_cell weight_ih shape must be ({input_size}, {hidden_size}), got {weight_ih.shape}")
    if weight_hh.shape != (hidden_size, hidden_size):
        raise ValueError(f"rnn_cell weight_hh shape must be ({hidden_size}, {hidden_size}), got {weight_hh.shape}")
    if bias_ih is not None and bias_ih.shape != (hidden_size,):
        raise ValueError(f"rnn_cell bias_ih shape must be ({hidden_size},), got {bias_ih.shape}")
    if bias_hh is not None and bias_hh.shape != (hidden_size,):
        raise ValueError(f"rnn_cell bias_hh shape must be ({hidden_size},), got {bias_hh.shape}")

    gates = input @ weight_ih + hx @ weight_hh
    if bias_ih is not None:
        gates = gates + bias_ih
    if bias_hh is not None:
        gates = gates + bias_hh

    if nonlinearity == "tanh":
        return tanh(gates)
    if nonlinearity == "relu":
        return relu(gates)
    raise ValueError(f"nonlinearity must be 'tanh' or 'relu', got {nonlinearity}")


def lstm_cell(
    input: Tensor,
    hx: tuple[Tensor, Tensor],
    weight_ih: Tensor,
    weight_hh: Tensor,
    bias_ih: Tensor | None = None,
    bias_hh: Tensor | None = None,
):
    input = _as_tensor(input)
    if not isinstance(hx, (tuple, list)) or len(hx) != 2:
        raise ValueError("lstm_cell hx must be a tuple (h, c)")
    h_t = _as_tensor(hx[0])
    c_t = _as_tensor(hx[1])
    weight_ih = _as_tensor(weight_ih)
    weight_hh = _as_tensor(weight_hh)
    if bias_ih is not None:
        bias_ih = _as_tensor(bias_ih)
    if bias_hh is not None:
        bias_hh = _as_tensor(bias_hh)

    if input.ndim != 2:
        raise ValueError(f"lstm_cell input must be 2D (batch, input_size), got {input.shape}")
    if h_t.ndim != 2 or c_t.ndim != 2:
        raise ValueError(f"lstm_cell h/c must be 2D (batch, hidden_size), got {h_t.shape} and {c_t.shape}")
    if h_t.shape != c_t.shape:
        raise ValueError(f"lstm_cell h and c must have same shape, got {h_t.shape} and {c_t.shape}")
    if weight_ih.ndim != 2 or weight_hh.ndim != 2:
        raise ValueError(f"lstm_cell weight_ih/weight_hh must be 2D, got {weight_ih.shape} and {weight_hh.shape}")

    batch_size, input_size = input.shape
    if h_t.shape[0] != batch_size:
        raise ValueError(f"lstm_cell h batch size must match input batch size ({batch_size}), got {h_t.shape[0]}")

    hidden_size = h_t.shape[1]
    if weight_ih.shape != (input_size, 4 * hidden_size):
        raise ValueError(
            f"lstm_cell weight_ih shape must be ({input_size}, {4 * hidden_size}), got {weight_ih.shape}"
        )
    if weight_hh.shape != (hidden_size, 4 * hidden_size):
        raise ValueError(
            f"lstm_cell weight_hh shape must be ({hidden_size}, {4 * hidden_size}), got {weight_hh.shape}"
        )
    if bias_ih is not None and bias_ih.shape != (4 * hidden_size,):
        raise ValueError(f"lstm_cell bias_ih shape must be ({4 * hidden_size},), got {bias_ih.shape}")
    if bias_hh is not None and bias_hh.shape != (4 * hidden_size,):
        raise ValueError(f"lstm_cell bias_hh shape must be ({4 * hidden_size},), got {bias_hh.shape}")

    gates = input @ weight_ih + h_t @ weight_hh
    if bias_ih is not None:
        gates = gates + bias_ih
    if bias_hh is not None:
        gates = gates + bias_hh

    i_t = sigmoid(gates[:, :hidden_size])
    f_t = sigmoid(gates[:, hidden_size:2 * hidden_size])
    g_t = tanh(gates[:, 2 * hidden_size:3 * hidden_size])
    o_t = sigmoid(gates[:, 3 * hidden_size:])

    c_next = f_t * c_t + i_t * g_t
    h_next = o_t * tanh(c_next)
    return h_next, c_next


def gru_cell(
    input: Tensor,
    hx: Tensor,
    weight_ih: Tensor,
    weight_hh: Tensor,
    bias_ih: Tensor | None = None,
    bias_hh: Tensor | None = None,
):
    input = _as_tensor(input)
    hx = _as_tensor(hx)
    weight_ih = _as_tensor(weight_ih)
    weight_hh = _as_tensor(weight_hh)
    if bias_ih is not None:
        bias_ih = _as_tensor(bias_ih)
    if bias_hh is not None:
        bias_hh = _as_tensor(bias_hh)

    if input.ndim != 2:
        raise ValueError(f"gru_cell input must be 2D (batch, input_size), got {input.shape}")
    if hx.ndim != 2:
        raise ValueError(f"gru_cell hx must be 2D (batch, hidden_size), got {hx.shape}")
    if weight_ih.ndim != 2 or weight_hh.ndim != 2:
        raise ValueError(f"gru_cell weight_ih/weight_hh must be 2D, got {weight_ih.shape} and {weight_hh.shape}")

    batch_size, input_size = input.shape
    if hx.shape[0] != batch_size:
        raise ValueError(f"gru_cell hx batch size must match input batch size ({batch_size}), got {hx.shape[0]}")

    hidden_size = hx.shape[1]
    if weight_ih.shape != (input_size, 3 * hidden_size):
        raise ValueError(
            f"gru_cell weight_ih shape must be ({input_size}, {3 * hidden_size}), got {weight_ih.shape}"
        )
    if weight_hh.shape != (hidden_size, 3 * hidden_size):
        raise ValueError(
            f"gru_cell weight_hh shape must be ({hidden_size}, {3 * hidden_size}), got {weight_hh.shape}"
        )
    if bias_ih is not None and bias_ih.shape != (3 * hidden_size,):
        raise ValueError(f"gru_cell bias_ih shape must be ({3 * hidden_size},), got {bias_ih.shape}")
    if bias_hh is not None and bias_hh.shape != (3 * hidden_size,):
        raise ValueError(f"gru_cell bias_hh shape must be ({3 * hidden_size},), got {bias_hh.shape}")

    gi = input @ weight_ih
    gh = hx @ weight_hh
    if bias_ih is not None:
        gi = gi + bias_ih
    if bias_hh is not None:
        gh = gh + bias_hh

    i_r = gi[:, :hidden_size]
    i_z = gi[:, hidden_size:2 * hidden_size]
    i_n = gi[:, 2 * hidden_size:]

    h_r = gh[:, :hidden_size]
    h_z = gh[:, hidden_size:2 * hidden_size]
    h_n = gh[:, 2 * hidden_size:]

    r_t = sigmoid(i_r + h_r)
    z_t = sigmoid(i_z + h_z)
    n_t = tanh(i_n + r_t * h_n)
    return (1.0 - z_t) * n_t + z_t * hx


def rnn(
    input: Tensor,
    weight_ih: Tensor,
    weight_hh: Tensor,
    bias_ih: Tensor | None = None,
    bias_hh: Tensor | None = None,
    hx: Tensor | None = None,
    nonlinearity: str = "tanh",
    batch_first: bool = False,
):
    input, x_seq = _rnn_prepare_input(input, batch_first=batch_first)
    weight_ih = _as_tensor(weight_ih)
    weight_hh = _as_tensor(weight_hh)
    if bias_ih is not None:
        bias_ih = _as_tensor(bias_ih)
    if bias_hh is not None:
        bias_hh = _as_tensor(bias_hh)

    seq_len, batch_size, input_size = x_seq.shape
    if weight_ih.ndim != 2 or weight_hh.ndim != 2:
        raise ValueError(
            f"weight_ih/weight_hh must be 2D, got {weight_ih.shape} and {weight_hh.shape}"
        )
    hidden_size = weight_hh.shape[1]
    if weight_ih.shape != (input_size, hidden_size):
        raise ValueError(f"weight_ih shape must be ({input_size}, {hidden_size}), got {weight_ih.shape}")
    if weight_hh.shape != (hidden_size, hidden_size):
        raise ValueError(f"weight_hh shape must be ({hidden_size}, {hidden_size}), got {weight_hh.shape}")
    if bias_ih is not None and bias_ih.shape != (hidden_size,):
        raise ValueError(f"bias_ih shape must be ({hidden_size},), got {bias_ih.shape}")
    if bias_hh is not None and bias_hh.shape != (hidden_size,):
        raise ValueError(f"bias_hh shape must be ({hidden_size},), got {bias_hh.shape}")

    if nonlinearity not in ("tanh", "relu"):
        raise ValueError(f"nonlinearity must be 'tanh' or 'relu', got {nonlinearity}")

    h_t = _rnn_prepare_hidden(
        hx,
        batch_size=batch_size,
        hidden_size=hidden_size,
        name="hx",
        device=input.device,
        dtype=input.to_numpy().dtype,
    )

    outputs = []
    for t in range(seq_len):
        h_t = rnn_cell(
            x_seq[t],
            h_t,
            weight_ih,
            weight_hh,
            bias_ih=bias_ih,
            bias_hh=bias_hh,
            nonlinearity=nonlinearity,
        )
        outputs.append(h_t)

    output = _rnn_stack_or_empty(outputs, batch_size, hidden_size, input.to_numpy().dtype, input.device)
    if batch_first:
        output = output.transpose(0, 1)
    return output, h_t.unsqueeze(0)


def lstm(
    input: Tensor,
    weight_ih: Tensor,
    weight_hh: Tensor,
    bias_ih: Tensor | None = None,
    bias_hh: Tensor | None = None,
    hx: tuple[Tensor, Tensor] | None = None,
    batch_first: bool = False,
):
    input, x_seq = _rnn_prepare_input(input, batch_first=batch_first)
    weight_ih = _as_tensor(weight_ih)
    weight_hh = _as_tensor(weight_hh)
    if bias_ih is not None:
        bias_ih = _as_tensor(bias_ih)
    if bias_hh is not None:
        bias_hh = _as_tensor(bias_hh)

    seq_len, batch_size, input_size = x_seq.shape
    if weight_ih.ndim != 2 or weight_hh.ndim != 2:
        raise ValueError(
            f"weight_ih/weight_hh must be 2D, got {weight_ih.shape} and {weight_hh.shape}"
        )
    if weight_ih.shape[0] != input_size:
        raise ValueError(f"weight_ih first dim must be input_size ({input_size}), got {weight_ih.shape[0]}")
    if weight_ih.shape[1] % 4 != 0:
        raise ValueError(f"weight_ih second dim must be multiple of 4, got {weight_ih.shape[1]}")

    hidden_size = weight_ih.shape[1] // 4
    if weight_hh.shape != (hidden_size, 4 * hidden_size):
        raise ValueError(
            f"weight_hh shape must be ({hidden_size}, {4 * hidden_size}), got {weight_hh.shape}"
        )
    if bias_ih is not None and bias_ih.shape != (4 * hidden_size,):
        raise ValueError(f"bias_ih shape must be ({4 * hidden_size},), got {bias_ih.shape}")
    if bias_hh is not None and bias_hh.shape != (4 * hidden_size,):
        raise ValueError(f"bias_hh shape must be ({4 * hidden_size},), got {bias_hh.shape}")

    if hx is None:
        h_t = _rnn_prepare_hidden(
            None,
            batch_size=batch_size,
            hidden_size=hidden_size,
            name="h0",
            device=input.device,
            dtype=input.to_numpy().dtype,
        )
        c_t = _rnn_prepare_hidden(
            None,
            batch_size=batch_size,
            hidden_size=hidden_size,
            name="c0",
            device=input.device,
            dtype=input.to_numpy().dtype,
        )
    else:
        if not isinstance(hx, (tuple, list)) or len(hx) != 2:
            raise ValueError("hx for lstm must be a tuple (h0, c0)")
        h_t = _rnn_prepare_hidden(
            hx[0],
            batch_size=batch_size,
            hidden_size=hidden_size,
            name="h0",
            device=input.device,
            dtype=input.to_numpy().dtype,
        )
        c_t = _rnn_prepare_hidden(
            hx[1],
            batch_size=batch_size,
            hidden_size=hidden_size,
            name="c0",
            device=input.device,
            dtype=input.to_numpy().dtype,
        )

    outputs = []
    for t in range(seq_len):
        h_t, c_t = lstm_cell(
            x_seq[t],
            (h_t, c_t),
            weight_ih,
            weight_hh,
            bias_ih=bias_ih,
            bias_hh=bias_hh,
        )
        outputs.append(h_t)

    output = _rnn_stack_or_empty(outputs, batch_size, hidden_size, input.to_numpy().dtype, input.device)
    if batch_first:
        output = output.transpose(0, 1)
    return output, (h_t.unsqueeze(0), c_t.unsqueeze(0))


def gru(
    input: Tensor,
    weight_ih: Tensor,
    weight_hh: Tensor,
    bias_ih: Tensor | None = None,
    bias_hh: Tensor | None = None,
    hx: Tensor | None = None,
    batch_first: bool = False,
):
    input, x_seq = _rnn_prepare_input(input, batch_first=batch_first)
    weight_ih = _as_tensor(weight_ih)
    weight_hh = _as_tensor(weight_hh)
    if bias_ih is not None:
        bias_ih = _as_tensor(bias_ih)
    if bias_hh is not None:
        bias_hh = _as_tensor(bias_hh)

    seq_len, batch_size, input_size = x_seq.shape
    if weight_ih.ndim != 2 or weight_hh.ndim != 2:
        raise ValueError(
            f"weight_ih/weight_hh must be 2D, got {weight_ih.shape} and {weight_hh.shape}"
        )
    if weight_ih.shape[0] != input_size:
        raise ValueError(f"weight_ih first dim must be input_size ({input_size}), got {weight_ih.shape[0]}")
    if weight_ih.shape[1] % 3 != 0:
        raise ValueError(f"weight_ih second dim must be multiple of 3, got {weight_ih.shape[1]}")

    hidden_size = weight_ih.shape[1] // 3
    if weight_hh.shape != (hidden_size, 3 * hidden_size):
        raise ValueError(
            f"weight_hh shape must be ({hidden_size}, {3 * hidden_size}), got {weight_hh.shape}"
        )
    if bias_ih is not None and bias_ih.shape != (3 * hidden_size,):
        raise ValueError(f"bias_ih shape must be ({3 * hidden_size},), got {bias_ih.shape}")
    if bias_hh is not None and bias_hh.shape != (3 * hidden_size,):
        raise ValueError(f"bias_hh shape must be ({3 * hidden_size},), got {bias_hh.shape}")

    h_t = _rnn_prepare_hidden(
        hx,
        batch_size=batch_size,
        hidden_size=hidden_size,
        name="hx",
        device=input.device,
        dtype=input.to_numpy().dtype,
    )

    outputs = []
    for t in range(seq_len):
        h_t = gru_cell(
            x_seq[t],
            h_t,
            weight_ih,
            weight_hh,
            bias_ih=bias_ih,
            bias_hh=bias_hh,
        )
        outputs.append(h_t)

    output = _rnn_stack_or_empty(outputs, batch_size, hidden_size, input.to_numpy().dtype, input.device)
    if batch_first:
        output = output.transpose(0, 1)
    return output, h_t.unsqueeze(0)


def batch_norm(
    input: Tensor,
    running_mean=None,
    running_var=None,
    weight: Tensor | None = None,
    bias: Tensor | None = None,
    training: bool = False,
    momentum: float = 0.1,
    eps: float = 1e-5,
):
    input = _as_tensor(input)
    if weight is not None:
        weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)

    x_data = input.to_numpy()
    if x_data.ndim < 2:
        raise ValueError(f"batch_norm expects input with at least 2 dims, got shape {x_data.shape}")

    c = x_data.shape[1]
    reduce_axes = tuple(i for i in range(x_data.ndim) if i != 1)
    param_shape = [1] * x_data.ndim
    param_shape[1] = c
    param_shape = tuple(param_shape)

    def _as_channel_vector(buf, name):
        if buf is None:
            return None
        if isinstance(buf, Tensor):
            arr = buf.to_numpy()
        else:
            arr = np.asarray(buf)
        if arr.shape != (c,):
            raise ValueError(f"{name} must have shape ({c},), got {arr.shape}")
        return arr

    if weight is not None and weight.shape != (c,):
        raise ValueError(f"weight must have shape ({c},), got {weight.shape}")
    if bias is not None and bias.shape != (c,):
        raise ValueError(f"bias must have shape ({c},), got {bias.shape}")

    running_mean_arr = _as_channel_vector(running_mean, "running_mean")
    running_var_arr = _as_channel_vector(running_var, "running_var")

    use_batch_stats = training or running_mean_arr is None or running_var_arr is None
    if use_batch_stats:
        mean = x_data.mean(axis=reduce_axes, keepdims=True)
        var = x_data.var(axis=reduce_axes, keepdims=True)

        if training and running_mean_arr is not None and running_var_arr is not None:
            batch_mean = mean.reshape(c)
            batch_var = var.reshape(c)
            updated_mean = (1.0 - momentum) * running_mean_arr + momentum * batch_mean
            updated_var = (1.0 - momentum) * running_var_arr + momentum * batch_var
            if isinstance(running_mean, Tensor):
                running_mean.data[...] = updated_mean.astype(running_mean.data.dtype, copy=False)
            else:
                running_mean[...] = updated_mean.astype(np.asarray(running_mean).dtype, copy=False)
            if isinstance(running_var, Tensor):
                running_var.data[...] = updated_var.astype(running_var.data.dtype, copy=False)
            else:
                running_var[...] = updated_var.astype(np.asarray(running_var).dtype, copy=False)
    else:
        mean = running_mean_arr.reshape(param_shape)
        var = running_var_arr.reshape(param_shape)

    inv_std = 1.0 / np.sqrt(var + eps)
    x_hat = (x_data - mean) * inv_std

    if weight is not None:
        w = weight.to_numpy().reshape(param_shape)
    else:
        w = 1.0
    if bias is not None:
        b = bias.to_numpy().reshape(param_shape)
    else:
        b = 0.0
    out_data = x_hat * w + b

    requires_grad = input.requires_grad or (weight is not None and weight.requires_grad) or (bias is not None and bias.requires_grad)
    children = [t for t in (input, weight, bias) if t is not None and t.requires_grad]
    out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="batch_norm", device=input.device)

    def _backward():
        grad = out.grad

        if weight is not None and weight.requires_grad:
            weight.grad += (grad * x_hat).sum(axis=reduce_axes).astype(weight.grad.dtype, copy=False)
        if bias is not None and bias.requires_grad:
            bias.grad += grad.sum(axis=reduce_axes).astype(bias.grad.dtype, copy=False)

        if input.requires_grad:
            dxhat = grad * w
            if use_batch_stats:
                n = float(np.prod([x_data.shape[ax] for ax in reduce_axes]))
                sum_dxhat = dxhat.sum(axis=reduce_axes, keepdims=True)
                sum_dxhat_xhat = (dxhat * x_hat).sum(axis=reduce_axes, keepdims=True)
                dx = (inv_std / n) * (n * dxhat - sum_dxhat - x_hat * sum_dxhat_xhat)
            else:
                dx = dxhat * inv_std
            input.grad += dx.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def group_norm(input: Tensor, num_groups: int, weight: Tensor | None = None, bias: Tensor | None = None, eps: float = 1e-5):
    input = _as_tensor(input)
    if weight is not None:
        weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)

    x_data = input.to_numpy()
    if x_data.ndim < 2:
        raise ValueError(f"group_norm expects input with at least 2 dims, got shape {x_data.shape}")
    if num_groups <= 0:
        raise ValueError(f"num_groups must be positive, got {num_groups}")

    n, c = x_data.shape[0], x_data.shape[1]
    if c % num_groups != 0:
        raise ValueError(f"num_channels ({c}) must be divisible by num_groups ({num_groups})")
    if weight is not None and weight.shape != (c,):
        raise ValueError(f"weight must have shape ({c},), got {weight.shape}")
    if bias is not None and bias.shape != (c,):
        raise ValueError(f"bias must have shape ({c},), got {bias.shape}")

    group_shape = (n, num_groups, c // num_groups) + x_data.shape[2:]
    x_grouped = x_data.reshape(group_shape)
    reduce_axes = tuple(range(2, x_grouped.ndim))

    mean = x_grouped.mean(axis=reduce_axes, keepdims=True)
    var = x_grouped.var(axis=reduce_axes, keepdims=True)
    inv_std = 1.0 / np.sqrt(var + eps)
    x_hat_grouped = (x_grouped - mean) * inv_std
    x_hat = x_hat_grouped.reshape(x_data.shape)

    param_shape = (1, c) + (1,) * (x_data.ndim - 2)
    w = weight.to_numpy().reshape(param_shape) if weight is not None else 1.0
    b = bias.to_numpy().reshape(param_shape) if bias is not None else 0.0
    out_data = x_hat * w + b

    requires_grad = input.requires_grad or (weight is not None and weight.requires_grad) or (bias is not None and bias.requires_grad)
    children = [t for t in (input, weight, bias) if t is not None and t.requires_grad]
    out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="group_norm", device=input.device)

    def _backward():
        grad = out.grad
        reduce_param_axes = tuple(i for i in range(grad.ndim) if i != 1)

        if weight is not None and weight.requires_grad:
            weight.grad += (grad * x_hat).sum(axis=reduce_param_axes).astype(weight.grad.dtype, copy=False)
        if bias is not None and bias.requires_grad:
            bias.grad += grad.sum(axis=reduce_param_axes).astype(bias.grad.dtype, copy=False)

        if input.requires_grad:
            dxhat = grad * w
            dxhat_grouped = dxhat.reshape(group_shape)
            n_group = float(np.prod(group_shape[2:]))
            sum_dxhat = dxhat_grouped.sum(axis=reduce_axes, keepdims=True)
            sum_dxhat_xhat = (dxhat_grouped * x_hat_grouped).sum(axis=reduce_axes, keepdims=True)
            dx_grouped = (inv_std / n_group) * (n_group * dxhat_grouped - sum_dxhat - x_hat_grouped * sum_dxhat_xhat)
            input.grad += dx_grouped.reshape(x_data.shape).astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def instance_norm(
    input: Tensor,
    running_mean=None,
    running_var=None,
    weight: Tensor | None = None,
    bias: Tensor | None = None,
    use_input_stats: bool = True,
    momentum: float = 0.1,
    eps: float = 1e-5,
):
    input = _as_tensor(input)
    if weight is not None:
        weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)

    x_data = input.to_numpy()
    if x_data.ndim < 3:
        raise ValueError(f"instance_norm expects input with at least 3 dims, got shape {x_data.shape}")

    n, c = x_data.shape[0], x_data.shape[1]
    if weight is not None and weight.shape != (c,):
        raise ValueError(f"weight must have shape ({c},), got {weight.shape}")
    if bias is not None and bias.shape != (c,):
        raise ValueError(f"bias must have shape ({c},), got {bias.shape}")

    def _as_channel_vector(buf, name):
        if buf is None:
            return None
        if isinstance(buf, Tensor):
            arr = buf.to_numpy()
        else:
            arr = np.asarray(buf)
        if arr.shape != (c,):
            raise ValueError(f"{name} must have shape ({c},), got {arr.shape}")
        return arr

    running_mean_arr = _as_channel_vector(running_mean, "running_mean")
    running_var_arr = _as_channel_vector(running_var, "running_var")

    spatial_axes = tuple(range(2, x_data.ndim))
    if use_input_stats:
        mean = x_data.mean(axis=spatial_axes, keepdims=True)
        var = x_data.var(axis=spatial_axes, keepdims=True)

        if running_mean_arr is not None and running_var_arr is not None:
            batch_mean = mean.mean(axis=0, keepdims=True).reshape(c)
            batch_var = var.mean(axis=0, keepdims=True).reshape(c)
            updated_mean = (1.0 - momentum) * running_mean_arr + momentum * batch_mean
            updated_var = (1.0 - momentum) * running_var_arr + momentum * batch_var

            if isinstance(running_mean, Tensor):
                running_mean.data[...] = updated_mean.astype(running_mean.data.dtype, copy=False)
            else:
                running_mean[...] = updated_mean.astype(np.asarray(running_mean).dtype, copy=False)
            if isinstance(running_var, Tensor):
                running_var.data[...] = updated_var.astype(running_var.data.dtype, copy=False)
            else:
                running_var[...] = updated_var.astype(np.asarray(running_var).dtype, copy=False)
    else:
        if running_mean_arr is None or running_var_arr is None:
            raise ValueError("running_mean and running_var must be provided when use_input_stats=False")
        shape = (1, c) + (1,) * (x_data.ndim - 2)
        mean = running_mean_arr.reshape(shape)
        var = running_var_arr.reshape(shape)

    inv_std = 1.0 / np.sqrt(var + eps)
    x_hat = (x_data - mean) * inv_std

    param_shape = (1, c) + (1,) * (x_data.ndim - 2)
    w = weight.to_numpy().reshape(param_shape) if weight is not None else 1.0
    b = bias.to_numpy().reshape(param_shape) if bias is not None else 0.0
    out_data = x_hat * w + b

    requires_grad = input.requires_grad or (weight is not None and weight.requires_grad) or (bias is not None and bias.requires_grad)
    children = [t for t in (input, weight, bias) if t is not None and t.requires_grad]
    out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="instance_norm", device=input.device)

    def _backward():
        grad = out.grad
        reduce_param_axes = tuple(i for i in range(grad.ndim) if i != 1)

        if weight is not None and weight.requires_grad:
            weight.grad += (grad * x_hat).sum(axis=reduce_param_axes).astype(weight.grad.dtype, copy=False)
        if bias is not None and bias.requires_grad:
            bias.grad += grad.sum(axis=reduce_param_axes).astype(bias.grad.dtype, copy=False)

        if input.requires_grad:
            dxhat = grad * w
            if use_input_stats:
                n_spatial = float(np.prod([x_data.shape[ax] for ax in spatial_axes]))
                sum_dxhat = dxhat.sum(axis=spatial_axes, keepdims=True)
                sum_dxhat_xhat = (dxhat * x_hat).sum(axis=spatial_axes, keepdims=True)
                dx = (inv_std / n_spatial) * (n_spatial * dxhat - sum_dxhat - x_hat * sum_dxhat_xhat)
            else:
                dx = dxhat * inv_std
            input.grad += dx.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def conv1d(input: Tensor, weight: Tensor, bias: Tensor | None = None, stride=1, padding=0, dilation=1, groups=1):
    input = _as_tensor(input)
    weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)

    x_data = input.to_numpy()
    w_data = weight.to_numpy()
    b_data = bias.to_numpy() if bias is not None else None

    if x_data.ndim != 3:
        raise ValueError(f"conv1d expects 3D input (N, C, L), got shape {x_data.shape}")
    if w_data.ndim != 3:
        raise ValueError(f"conv1d expects 3D weight (out_channels, in_channels/groups, kL), got shape {w_data.shape}")

    stride_l = int(_single(stride))
    pad_l = int(_single(padding))
    dil_l = int(_single(dilation))

    n, in_channels, in_len = x_data.shape
    out_channels, in_channels_per_group, kernel_len = w_data.shape

    if groups <= 0:
        raise ValueError(f"groups must be positive, got {groups}")
    if in_channels % groups != 0:
        raise ValueError(f"in_channels ({in_channels}) must be divisible by groups ({groups})")
    if out_channels % groups != 0:
        raise ValueError(f"out_channels ({out_channels}) must be divisible by groups ({groups})")
    if in_channels_per_group != in_channels // groups:
        raise ValueError(
            f"weight second dim ({in_channels_per_group}) must equal in_channels/groups ({in_channels // groups})"
        )
    if bias is not None and b_data.shape != (out_channels,):
        raise ValueError(f"bias shape must be ({out_channels},), got {b_data.shape}")

    eff_kernel = dil_l * (kernel_len - 1) + 1
    out_len = (in_len + 2 * pad_l - eff_kernel) // stride_l + 1
    if out_len <= 0:
        raise ValueError(
            f"invalid output shape for conv1d: input={x_data.shape}, weight={w_data.shape}, "
            f"stride={stride_l}, padding={pad_l}, dilation={dil_l}"
        )

    if pad_l > 0:
        x_padded = np.pad(x_data, ((0, 0), (0, 0), (pad_l, pad_l)), mode="constant")
    else:
        x_padded = x_data

    out_data = np.zeros((n, out_channels, out_len), dtype=x_data.dtype)
    in_ch_per_group = in_channels // groups
    out_ch_per_group = out_channels // groups

    for bi in range(n):
        for g in range(groups):
            in_start = g * in_ch_per_group
            out_start = g * out_ch_per_group
            for oc_local in range(out_ch_per_group):
                oc = out_start + oc_local
                for ol in range(out_len):
                    il_start = ol * stride_l
                    acc = 0.0
                    for ic_local in range(in_ch_per_group):
                        ic = in_start + ic_local
                        for kl in range(kernel_len):
                            il = il_start + kl * dil_l
                            acc += x_padded[bi, ic, il] * w_data[oc, ic_local, kl]
                    out_data[bi, oc, ol] = acc

    if b_data is not None:
        out_data += b_data.reshape(1, -1, 1)

    requires_grad = input.requires_grad or weight.requires_grad or (bias is not None and bias.requires_grad)
    children = [t for t in (input, weight, bias) if t is not None and t.requires_grad]
    out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="conv1d", device=input.device)

    def _backward():
        grad_out = out.grad

        if weight.requires_grad:
            w_grad = np.zeros_like(w_data)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for oc_local in range(out_ch_per_group):
                        oc = out_start + oc_local
                        for ol in range(out_len):
                            il_start = ol * stride_l
                            go = grad_out[bi, oc, ol]
                            for ic_local in range(in_ch_per_group):
                                ic = in_start + ic_local
                                for kl in range(kernel_len):
                                    il = il_start + kl * dil_l
                                    w_grad[oc, ic_local, kl] += x_padded[bi, ic, il] * go
            weight.grad += w_grad.astype(weight.grad.dtype, copy=False)

        if bias is not None and bias.requires_grad:
            bias.grad += grad_out.sum(axis=(0, 2)).astype(bias.grad.dtype, copy=False)

        if input.requires_grad:
            x_grad_padded = np.zeros_like(x_padded)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for oc_local in range(out_ch_per_group):
                        oc = out_start + oc_local
                        for ol in range(out_len):
                            il_start = ol * stride_l
                            go = grad_out[bi, oc, ol]
                            for ic_local in range(in_ch_per_group):
                                ic = in_start + ic_local
                                for kl in range(kernel_len):
                                    il = il_start + kl * dil_l
                                    x_grad_padded[bi, ic, il] += w_data[oc, ic_local, kl] * go
            if pad_l > 0:
                x_grad = x_grad_padded[:, :, pad_l:pad_l + in_len]
            else:
                x_grad = x_grad_padded
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def conv_transpose1d(
    input: Tensor,
    weight: Tensor,
    bias: Tensor | None = None,
    stride=1,
    padding=0,
    output_padding=0,
    groups=1,
    dilation=1,
):
    input = _as_tensor(input)
    weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)

    x_data = input.to_numpy()
    w_data = weight.to_numpy()
    b_data = bias.to_numpy() if bias is not None else None

    if x_data.ndim != 3:
        raise ValueError(f"conv_transpose1d expects 3D input (N, C, L), got shape {x_data.shape}")
    if w_data.ndim != 3:
        raise ValueError(
            f"conv_transpose1d expects 3D weight (in_channels, out_channels/groups, kL), got shape {w_data.shape}"
        )

    stride_l = int(_single(stride))
    pad_l = int(_single(padding))
    out_pad_l = int(_single(output_padding))
    dil_l = int(_single(dilation))

    n, in_channels, in_len = x_data.shape
    if w_data.shape[0] != in_channels:
        raise ValueError(f"weight first dim ({w_data.shape[0]}) must equal in_channels ({in_channels})")
    if groups <= 0:
        raise ValueError(f"groups must be positive, got {groups}")
    if in_channels % groups != 0:
        raise ValueError(f"in_channels ({in_channels}) must be divisible by groups ({groups})")

    out_ch_per_group = w_data.shape[1]
    out_channels = out_ch_per_group * groups
    kernel_l = w_data.shape[2]

    if bias is not None and b_data.shape != (out_channels,):
        raise ValueError(f"bias shape must be ({out_channels},), got {b_data.shape}")
    if out_pad_l < 0:
        raise ValueError(f"output_padding must be non-negative, got {out_pad_l}")

    out_len = (in_len - 1) * stride_l - 2 * pad_l + dil_l * (kernel_l - 1) + out_pad_l + 1
    if out_len <= 0:
        raise ValueError(
            f"invalid output shape for conv_transpose1d: input={x_data.shape}, weight={w_data.shape}, "
            f"stride={stride_l}, padding={pad_l}, output_padding={out_pad_l}, dilation={dil_l}"
        )

    out_data = np.zeros((n, out_channels, out_len), dtype=x_data.dtype)
    in_ch_per_group = in_channels // groups

    for bi in range(n):
        for g in range(groups):
            in_start = g * in_ch_per_group
            out_start = g * out_ch_per_group
            for ic_local in range(in_ch_per_group):
                ic = in_start + ic_local
                for il in range(in_len):
                    base_l = il * stride_l - pad_l
                    x_val = x_data[bi, ic, il]
                    for kl in range(kernel_l):
                        ol = base_l + kl * dil_l
                        if ol < 0 or ol >= out_len:
                            continue
                        for oc_local in range(out_ch_per_group):
                            oc = out_start + oc_local
                            out_data[bi, oc, ol] += x_val * w_data[ic, oc_local, kl]

    if b_data is not None:
        out_data += b_data.reshape(1, -1, 1)

    requires_grad = input.requires_grad or weight.requires_grad or (bias is not None and bias.requires_grad)
    children = [t for t in (input, weight, bias) if t is not None and t.requires_grad]
    out = Tensor(
        out_data,
        requires_grad=requires_grad,
        _children=tuple(children),
        _op="conv_transpose1d",
        device=input.device,
    )

    def _backward():
        grad_out = out.grad

        if weight.requires_grad:
            w_grad = np.zeros_like(w_data)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for ic_local in range(in_ch_per_group):
                        ic = in_start + ic_local
                        for il in range(in_len):
                            base_l = il * stride_l - pad_l
                            x_val = x_data[bi, ic, il]
                            for kl in range(kernel_l):
                                ol = base_l + kl * dil_l
                                if ol < 0 or ol >= out_len:
                                    continue
                                for oc_local in range(out_ch_per_group):
                                    oc = out_start + oc_local
                                    w_grad[ic, oc_local, kl] += x_val * grad_out[bi, oc, ol]
            weight.grad += w_grad.astype(weight.grad.dtype, copy=False)

        if bias is not None and bias.requires_grad:
            bias.grad += grad_out.sum(axis=(0, 2)).astype(bias.grad.dtype, copy=False)

        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for ic_local in range(in_ch_per_group):
                        ic = in_start + ic_local
                        for il in range(in_len):
                            base_l = il * stride_l - pad_l
                            acc = 0.0
                            for kl in range(kernel_l):
                                ol = base_l + kl * dil_l
                                if ol < 0 or ol >= out_len:
                                    continue
                                for oc_local in range(out_ch_per_group):
                                    oc = out_start + oc_local
                                    acc += grad_out[bi, oc, ol] * w_data[ic, oc_local, kl]
                            x_grad[bi, ic, il] += acc
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def max_pool1d(input: Tensor, kernel_size, stride=None, padding=0, dilation=1, ceil_mode=False, return_indices=False):
    input = _as_tensor(input)
    x_data = input.to_numpy()
    if x_data.ndim != 3:
        raise ValueError(f"max_pool1d expects 3D input (N, C, L), got shape {x_data.shape}")

    kernel_l = int(_single(kernel_size))
    stride_l = int(_single(stride if stride is not None else kernel_size))
    pad_l = int(_single(padding))
    dil_l = int(_single(dilation))

    n, c, in_len = x_data.shape
    eff_kernel = dil_l * (kernel_l - 1) + 1
    if ceil_mode:
        out_len = int(np.ceil((in_len + 2 * pad_l - eff_kernel) / stride_l + 1))
    else:
        out_len = (in_len + 2 * pad_l - eff_kernel) // stride_l + 1
    if ceil_mode and out_len > 0 and (out_len - 1) * stride_l >= in_len + pad_l:
        out_len -= 1
    out_len = max(out_len, 0)

    x_padded = np.pad(x_data, ((0, 0), (0, 0), (pad_l, pad_l)), mode="constant", constant_values=-np.inf)
    out_data = np.empty((n, c, out_len), dtype=x_data.dtype)
    max_idx = np.full((n, c, out_len), -1, dtype=np.int64)

    for bi in range(n):
        for ci in range(c):
            for ol in range(out_len):
                il_start = ol * stride_l
                best_val = -np.inf
                best_idx = -1
                for kl in range(kernel_l):
                    il = il_start + kl * dil_l
                    if il < 0 or il >= x_padded.shape[2]:
                        continue
                    v = x_padded[bi, ci, il]
                    if v > best_val:
                        best_val = v
                        best_idx = il
                out_data[bi, ci, ol] = best_val
                max_idx[bi, ci, ol] = best_idx

    out = Tensor(out_data, requires_grad=input.requires_grad, _children=(input,), _op="max_pool1d", device=input.device)

    def _backward():
        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for bi in range(n):
                for ci in range(c):
                    for ol in range(out_len):
                        il = max_idx[bi, ci, ol] - pad_l
                        if 0 <= il < in_len:
                            x_grad[bi, ci, il] += out.grad[bi, ci, ol]
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    if not return_indices:
        return out

    indices = max_idx - pad_l
    indices[(indices < 0) | (indices >= in_len)] = -1
    return out, Tensor(indices.astype(np.int64), requires_grad=False, device=input.device)


def avg_pool1d(
    input: Tensor,
    kernel_size,
    stride=None,
    padding=0,
    ceil_mode=False,
    count_include_pad=True,
    divisor_override=None,
):
    input = _as_tensor(input)
    x_data = input.to_numpy()
    if x_data.ndim != 3:
        raise ValueError(f"avg_pool1d expects 3D input (N, C, L), got shape {x_data.shape}")

    kernel_l = int(_single(kernel_size))
    stride_l = int(_single(stride if stride is not None else kernel_size))
    pad_l = int(_single(padding))

    n, c, in_len = x_data.shape
    if ceil_mode:
        out_len = int(np.ceil((in_len + 2 * pad_l - kernel_l) / stride_l + 1))
    else:
        out_len = (in_len + 2 * pad_l - kernel_l) // stride_l + 1
    if ceil_mode and out_len > 0 and (out_len - 1) * stride_l >= in_len + pad_l:
        out_len -= 1
    out_len = max(out_len, 0)

    x_padded = np.pad(x_data, ((0, 0), (0, 0), (pad_l, pad_l)), mode="constant", constant_values=0.0)
    out_data = np.zeros((n, c, out_len), dtype=x_data.dtype)
    divisors = np.zeros((n, c, out_len), dtype=np.float64)

    for bi in range(n):
        for ci in range(c):
            for ol in range(out_len):
                il_start = ol * stride_l
                acc = 0.0
                valid = 0
                for kl in range(kernel_l):
                    il = il_start + kl
                    if 0 <= il < x_padded.shape[2]:
                        acc += x_padded[bi, ci, il]
                    if pad_l <= il < pad_l + in_len:
                        valid += 1
                if divisor_override is not None:
                    div = float(divisor_override)
                elif count_include_pad:
                    div = float(kernel_l)
                else:
                    div = float(max(valid, 1))
                divisors[bi, ci, ol] = div
                out_data[bi, ci, ol] = acc / div

    out = Tensor(out_data, requires_grad=input.requires_grad, _children=(input,), _op="avg_pool1d", device=input.device)

    def _backward():
        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for bi in range(n):
                for ci in range(c):
                    for ol in range(out_len):
                        go = out.grad[bi, ci, ol] / divisors[bi, ci, ol]
                        il_start = ol * stride_l
                        for kl in range(kernel_l):
                            il = il_start + kl - pad_l
                            if 0 <= il < in_len:
                                x_grad[bi, ci, il] += go
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def conv2d(input: Tensor, weight: Tensor, bias: Tensor | None = None, stride=1, padding=0, dilation=1, groups=1):
    input = _as_tensor(input)
    weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)

    x_data = input.to_numpy()
    w_data = weight.to_numpy()
    b_data = bias.to_numpy() if bias is not None else None
    compute_dtype = np.result_type(x_data.dtype, w_data.dtype, np.float64)
    x_compute = x_data.astype(compute_dtype, copy=False)
    w_compute = w_data.astype(compute_dtype, copy=False)
    b_compute = b_data.astype(compute_dtype, copy=False) if b_data is not None else None

    if x_data.ndim != 4:
        raise ValueError(f"conv2d expects 4D input (N, C, H, W), got shape {x_data.shape}")
    if w_data.ndim != 4:
        raise ValueError(f"conv2d expects 4D weight (out_channels, in_channels/groups, kH, kW), got shape {w_data.shape}")

    stride_h, stride_w = _pair(stride)
    pad_h, pad_w = _pair(padding)
    dil_h, dil_w = _pair(dilation)

    n, in_channels, in_h, in_w = x_data.shape
    out_channels, in_channels_per_group, kernel_h, kernel_w = w_data.shape

    if groups <= 0:
        raise ValueError(f"groups must be positive, got {groups}")
    if in_channels % groups != 0:
        raise ValueError(f"in_channels ({in_channels}) must be divisible by groups ({groups})")
    if out_channels % groups != 0:
        raise ValueError(f"out_channels ({out_channels}) must be divisible by groups ({groups})")
    if in_channels_per_group != in_channels // groups:
        raise ValueError(
            f"weight second dim ({in_channels_per_group}) must equal in_channels/groups ({in_channels // groups})"
        )
    if bias is not None and b_data.shape != (out_channels,):
        raise ValueError(f"bias shape must be ({out_channels},), got {b_data.shape}")

    eff_kernel_h = dil_h * (kernel_h - 1) + 1
    eff_kernel_w = dil_w * (kernel_w - 1) + 1
    out_h = (in_h + 2 * pad_h - eff_kernel_h) // stride_h + 1
    out_w = (in_w + 2 * pad_w - eff_kernel_w) // stride_w + 1
    if out_h <= 0 or out_w <= 0:
        raise ValueError(
            f"invalid output shape for conv2d: input={x_data.shape}, weight={w_data.shape}, "
            f"stride={(stride_h, stride_w)}, padding={(pad_h, pad_w)}, dilation={(dil_h, dil_w)}"
        )

    if pad_h > 0 or pad_w > 0:
        x_padded = np.pad(
            x_compute,
            ((0, 0), (0, 0), (pad_h, pad_h), (pad_w, pad_w)),
            mode="constant",
        )
    else:
        x_padded = x_compute

    out_data = np.zeros((n, out_channels, out_h, out_w), dtype=compute_dtype)
    in_ch_per_group = in_channels // groups
    out_ch_per_group = out_channels // groups

    for bi in range(n):
        for g in range(groups):
            in_start = g * in_ch_per_group
            out_start = g * out_ch_per_group
            for oc_local in range(out_ch_per_group):
                oc = out_start + oc_local
                for oh in range(out_h):
                    ih_start = oh * stride_h
                    for ow in range(out_w):
                        iw_start = ow * stride_w
                        acc = 0.0
                        for ic_local in range(in_ch_per_group):
                            ic = in_start + ic_local
                            for kh in range(kernel_h):
                                ih = ih_start + kh * dil_h
                                for kw in range(kernel_w):
                                    iw = iw_start + kw * dil_w
                                    acc += x_padded[bi, ic, ih, iw] * w_compute[oc, ic_local, kh, kw]
                        out_data[bi, oc, oh, ow] = acc

    if b_compute is not None:
        out_data += b_compute.reshape(1, -1, 1, 1)

    out_tensor_data = out_data.astype(x_data.dtype, copy=False) if out_data.dtype != x_data.dtype else out_data

    requires_grad = input.requires_grad or weight.requires_grad or (bias is not None and bias.requires_grad)
    children = [t for t in (input, weight, bias) if t is not None and t.requires_grad]
    out = Tensor(out_tensor_data, requires_grad=requires_grad, _children=tuple(children), _op="conv2d", device=input.device)

    def _backward():
        grad_out = out.grad

        if weight.requires_grad:
            w_grad = np.zeros_like(w_compute)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for oc_local in range(out_ch_per_group):
                        oc = out_start + oc_local
                        for oh in range(out_h):
                            ih_start = oh * stride_h
                            for ow in range(out_w):
                                iw_start = ow * stride_w
                                go = grad_out[bi, oc, oh, ow]
                                for ic_local in range(in_ch_per_group):
                                    ic = in_start + ic_local
                                    for kh in range(kernel_h):
                                        ih = ih_start + kh * dil_h
                                        for kw in range(kernel_w):
                                            iw = iw_start + kw * dil_w
                                            w_grad[oc, ic_local, kh, kw] += x_padded[bi, ic, ih, iw] * go
            weight.grad += w_grad.astype(weight.grad.dtype, copy=False)

        if bias is not None and bias.requires_grad:
            bias.grad += grad_out.sum(axis=(0, 2, 3)).astype(bias.grad.dtype, copy=False)

        if input.requires_grad:
            x_grad_padded = np.zeros_like(x_padded)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for oc_local in range(out_ch_per_group):
                        oc = out_start + oc_local
                        for oh in range(out_h):
                            ih_start = oh * stride_h
                            for ow in range(out_w):
                                iw_start = ow * stride_w
                                go = grad_out[bi, oc, oh, ow]
                                for ic_local in range(in_ch_per_group):
                                    ic = in_start + ic_local
                                    for kh in range(kernel_h):
                                        ih = ih_start + kh * dil_h
                                        for kw in range(kernel_w):
                                            iw = iw_start + kw * dil_w
                                            x_grad_padded[bi, ic, ih, iw] += w_compute[oc, ic_local, kh, kw] * go
            if pad_h > 0 or pad_w > 0:
                x_grad = x_grad_padded[:, :, pad_h:pad_h + in_h, pad_w:pad_w + in_w]
            else:
                x_grad = x_grad_padded
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def conv_transpose2d(
    input: Tensor,
    weight: Tensor,
    bias: Tensor | None = None,
    stride=1,
    padding=0,
    output_padding=0,
    groups=1,
    dilation=1,
):
    input = _as_tensor(input)
    weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)

    x_data = input.to_numpy()
    w_data = weight.to_numpy()
    b_data = bias.to_numpy() if bias is not None else None

    if x_data.ndim != 4:
        raise ValueError(f"conv_transpose2d expects 4D input (N, C, H, W), got shape {x_data.shape}")
    if w_data.ndim != 4:
        raise ValueError(
            "conv_transpose2d expects 4D weight (in_channels, out_channels/groups, kH, kW), "
            f"got shape {w_data.shape}"
        )

    stride_h, stride_w = _pair(stride)
    pad_h, pad_w = _pair(padding)
    out_pad_h, out_pad_w = _pair(output_padding)
    dil_h, dil_w = _pair(dilation)

    n, in_channels, in_h, in_w = x_data.shape
    if w_data.shape[0] != in_channels:
        raise ValueError(f"weight first dim ({w_data.shape[0]}) must equal in_channels ({in_channels})")
    if groups <= 0:
        raise ValueError(f"groups must be positive, got {groups}")
    if in_channels % groups != 0:
        raise ValueError(f"in_channels ({in_channels}) must be divisible by groups ({groups})")

    out_ch_per_group = w_data.shape[1]
    out_channels = out_ch_per_group * groups
    kernel_h, kernel_w = w_data.shape[2], w_data.shape[3]

    if bias is not None and b_data.shape != (out_channels,):
        raise ValueError(f"bias shape must be ({out_channels},), got {b_data.shape}")
    if out_pad_h < 0 or out_pad_w < 0:
        raise ValueError(f"output_padding must be non-negative, got {(out_pad_h, out_pad_w)}")

    out_h = (in_h - 1) * stride_h - 2 * pad_h + dil_h * (kernel_h - 1) + out_pad_h + 1
    out_w = (in_w - 1) * stride_w - 2 * pad_w + dil_w * (kernel_w - 1) + out_pad_w + 1
    if out_h <= 0 or out_w <= 0:
        raise ValueError(
            f"invalid output shape for conv_transpose2d: input={x_data.shape}, weight={w_data.shape}, "
            f"stride={(stride_h, stride_w)}, padding={(pad_h, pad_w)}, output_padding={(out_pad_h, out_pad_w)}, "
            f"dilation={(dil_h, dil_w)}"
        )

    out_data = np.zeros((n, out_channels, out_h, out_w), dtype=x_data.dtype)
    in_ch_per_group = in_channels // groups

    for bi in range(n):
        for g in range(groups):
            in_start = g * in_ch_per_group
            out_start = g * out_ch_per_group
            for ic_local in range(in_ch_per_group):
                ic = in_start + ic_local
                for ih in range(in_h):
                    base_h = ih * stride_h - pad_h
                    for iw in range(in_w):
                        base_w = iw * stride_w - pad_w
                        x_val = x_data[bi, ic, ih, iw]
                        for kh in range(kernel_h):
                            oh = base_h + kh * dil_h
                            if oh < 0 or oh >= out_h:
                                continue
                            for kw in range(kernel_w):
                                ow = base_w + kw * dil_w
                                if ow < 0 or ow >= out_w:
                                    continue
                                for oc_local in range(out_ch_per_group):
                                    oc = out_start + oc_local
                                    out_data[bi, oc, oh, ow] += x_val * w_data[ic, oc_local, kh, kw]

    if b_data is not None:
        out_data += b_data.reshape(1, -1, 1, 1)

    requires_grad = input.requires_grad or weight.requires_grad or (bias is not None and bias.requires_grad)
    children = [t for t in (input, weight, bias) if t is not None and t.requires_grad]
    out = Tensor(
        out_data,
        requires_grad=requires_grad,
        _children=tuple(children),
        _op="conv_transpose2d",
        device=input.device,
    )

    def _backward():
        grad_out = out.grad

        if weight.requires_grad:
            w_grad = np.zeros_like(w_data)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for ic_local in range(in_ch_per_group):
                        ic = in_start + ic_local
                        for ih in range(in_h):
                            base_h = ih * stride_h - pad_h
                            for iw in range(in_w):
                                base_w = iw * stride_w - pad_w
                                x_val = x_data[bi, ic, ih, iw]
                                for kh in range(kernel_h):
                                    oh = base_h + kh * dil_h
                                    if oh < 0 or oh >= out_h:
                                        continue
                                    for kw in range(kernel_w):
                                        ow = base_w + kw * dil_w
                                        if ow < 0 or ow >= out_w:
                                            continue
                                        for oc_local in range(out_ch_per_group):
                                            oc = out_start + oc_local
                                            w_grad[ic, oc_local, kh, kw] += x_val * grad_out[bi, oc, oh, ow]
            weight.grad += w_grad.astype(weight.grad.dtype, copy=False)

        if bias is not None and bias.requires_grad:
            bias.grad += grad_out.sum(axis=(0, 2, 3)).astype(bias.grad.dtype, copy=False)

        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for ic_local in range(in_ch_per_group):
                        ic = in_start + ic_local
                        for ih in range(in_h):
                            base_h = ih * stride_h - pad_h
                            for iw in range(in_w):
                                base_w = iw * stride_w - pad_w
                                acc = 0.0
                                for kh in range(kernel_h):
                                    oh = base_h + kh * dil_h
                                    if oh < 0 or oh >= out_h:
                                        continue
                                    for kw in range(kernel_w):
                                        ow = base_w + kw * dil_w
                                        if ow < 0 or ow >= out_w:
                                            continue
                                        for oc_local in range(out_ch_per_group):
                                            oc = out_start + oc_local
                                            acc += grad_out[bi, oc, oh, ow] * w_data[ic, oc_local, kh, kw]
                                x_grad[bi, ic, ih, iw] += acc
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def conv3d(input: Tensor, weight: Tensor, bias: Tensor | None = None, stride=1, padding=0, dilation=1, groups=1):
    input = _as_tensor(input)
    weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)

    x_data = input.to_numpy()
    w_data = weight.to_numpy()
    b_data = bias.to_numpy() if bias is not None else None

    if x_data.ndim != 5:
        raise ValueError(f"conv3d expects 5D input (N, C, D, H, W), got shape {x_data.shape}")
    if w_data.ndim != 5:
        raise ValueError(
            f"conv3d expects 5D weight (out_channels, in_channels/groups, kD, kH, kW), got shape {w_data.shape}"
        )

    stride_d, stride_h, stride_w = _triple(stride)
    pad_d, pad_h, pad_w = _triple(padding)
    dil_d, dil_h, dil_w = _triple(dilation)

    n, in_channels, in_d, in_h, in_w = x_data.shape
    out_channels, in_channels_per_group, kernel_d, kernel_h, kernel_w = w_data.shape

    if groups <= 0:
        raise ValueError(f"groups must be positive, got {groups}")
    if in_channels % groups != 0:
        raise ValueError(f"in_channels ({in_channels}) must be divisible by groups ({groups})")
    if out_channels % groups != 0:
        raise ValueError(f"out_channels ({out_channels}) must be divisible by groups ({groups})")
    if in_channels_per_group != in_channels // groups:
        raise ValueError(
            f"weight second dim ({in_channels_per_group}) must equal in_channels/groups ({in_channels // groups})"
        )
    if bias is not None and b_data.shape != (out_channels,):
        raise ValueError(f"bias shape must be ({out_channels},), got {b_data.shape}")

    eff_kd = dil_d * (kernel_d - 1) + 1
    eff_kh = dil_h * (kernel_h - 1) + 1
    eff_kw = dil_w * (kernel_w - 1) + 1
    out_d = (in_d + 2 * pad_d - eff_kd) // stride_d + 1
    out_h = (in_h + 2 * pad_h - eff_kh) // stride_h + 1
    out_w = (in_w + 2 * pad_w - eff_kw) // stride_w + 1
    if out_d <= 0 or out_h <= 0 or out_w <= 0:
        raise ValueError(
            f"invalid output shape for conv3d: input={x_data.shape}, weight={w_data.shape}, "
            f"stride={(stride_d, stride_h, stride_w)}, padding={(pad_d, pad_h, pad_w)}, "
            f"dilation={(dil_d, dil_h, dil_w)}"
        )

    if pad_d > 0 or pad_h > 0 or pad_w > 0:
        x_padded = np.pad(
            x_data,
            ((0, 0), (0, 0), (pad_d, pad_d), (pad_h, pad_h), (pad_w, pad_w)),
            mode="constant",
        )
    else:
        x_padded = x_data

    out_data = np.zeros((n, out_channels, out_d, out_h, out_w), dtype=x_data.dtype)
    in_ch_per_group = in_channels // groups
    out_ch_per_group = out_channels // groups

    for bi in range(n):
        for g in range(groups):
            in_start = g * in_ch_per_group
            out_start = g * out_ch_per_group
            for oc_local in range(out_ch_per_group):
                oc = out_start + oc_local
                for od in range(out_d):
                    id_start = od * stride_d
                    for oh in range(out_h):
                        ih_start = oh * stride_h
                        for ow in range(out_w):
                            iw_start = ow * stride_w
                            acc = 0.0
                            for ic_local in range(in_ch_per_group):
                                ic = in_start + ic_local
                                for kd in range(kernel_d):
                                    id_ = id_start + kd * dil_d
                                    for kh in range(kernel_h):
                                        ih = ih_start + kh * dil_h
                                        for kw in range(kernel_w):
                                            iw = iw_start + kw * dil_w
                                            acc += x_padded[bi, ic, id_, ih, iw] * w_data[oc, ic_local, kd, kh, kw]
                            out_data[bi, oc, od, oh, ow] = acc

    if b_data is not None:
        out_data += b_data.reshape(1, -1, 1, 1, 1)

    requires_grad = input.requires_grad or weight.requires_grad or (bias is not None and bias.requires_grad)
    children = [t for t in (input, weight, bias) if t is not None and t.requires_grad]
    out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="conv3d", device=input.device)

    def _backward():
        grad_out = out.grad

        if weight.requires_grad:
            w_grad = np.zeros_like(w_data)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for oc_local in range(out_ch_per_group):
                        oc = out_start + oc_local
                        for od in range(out_d):
                            id_start = od * stride_d
                            for oh in range(out_h):
                                ih_start = oh * stride_h
                                for ow in range(out_w):
                                    iw_start = ow * stride_w
                                    go = grad_out[bi, oc, od, oh, ow]
                                    for ic_local in range(in_ch_per_group):
                                        ic = in_start + ic_local
                                        for kd in range(kernel_d):
                                            id_ = id_start + kd * dil_d
                                            for kh in range(kernel_h):
                                                ih = ih_start + kh * dil_h
                                                for kw in range(kernel_w):
                                                    iw = iw_start + kw * dil_w
                                                    w_grad[oc, ic_local, kd, kh, kw] += x_padded[bi, ic, id_, ih, iw] * go
            weight.grad += w_grad.astype(weight.grad.dtype, copy=False)

        if bias is not None and bias.requires_grad:
            bias.grad += grad_out.sum(axis=(0, 2, 3, 4)).astype(bias.grad.dtype, copy=False)

        if input.requires_grad:
            x_grad_padded = np.zeros_like(x_padded)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for oc_local in range(out_ch_per_group):
                        oc = out_start + oc_local
                        for od in range(out_d):
                            id_start = od * stride_d
                            for oh in range(out_h):
                                ih_start = oh * stride_h
                                for ow in range(out_w):
                                    iw_start = ow * stride_w
                                    go = grad_out[bi, oc, od, oh, ow]
                                    for ic_local in range(in_ch_per_group):
                                        ic = in_start + ic_local
                                        for kd in range(kernel_d):
                                            id_ = id_start + kd * dil_d
                                            for kh in range(kernel_h):
                                                ih = ih_start + kh * dil_h
                                                for kw in range(kernel_w):
                                                    iw = iw_start + kw * dil_w
                                                    x_grad_padded[bi, ic, id_, ih, iw] += w_data[oc, ic_local, kd, kh, kw] * go
            if pad_d > 0 or pad_h > 0 or pad_w > 0:
                x_grad = x_grad_padded[:, :, pad_d:pad_d + in_d, pad_h:pad_h + in_h, pad_w:pad_w + in_w]
            else:
                x_grad = x_grad_padded
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def conv_transpose3d(
    input: Tensor,
    weight: Tensor,
    bias: Tensor | None = None,
    stride=1,
    padding=0,
    output_padding=0,
    groups=1,
    dilation=1,
):
    input = _as_tensor(input)
    weight = _as_tensor(weight)
    if bias is not None:
        bias = _as_tensor(bias)

    x_data = input.to_numpy()
    w_data = weight.to_numpy()
    b_data = bias.to_numpy() if bias is not None else None

    if x_data.ndim != 5:
        raise ValueError(f"conv_transpose3d expects 5D input (N, C, D, H, W), got shape {x_data.shape}")
    if w_data.ndim != 5:
        raise ValueError(
            "conv_transpose3d expects 5D weight (in_channels, out_channels/groups, kD, kH, kW), "
            f"got shape {w_data.shape}"
        )

    stride_d, stride_h, stride_w = _triple(stride)
    pad_d, pad_h, pad_w = _triple(padding)
    out_pad_d, out_pad_h, out_pad_w = _triple(output_padding)
    dil_d, dil_h, dil_w = _triple(dilation)

    n, in_channels, in_d, in_h, in_w = x_data.shape
    if w_data.shape[0] != in_channels:
        raise ValueError(f"weight first dim ({w_data.shape[0]}) must equal in_channels ({in_channels})")
    if groups <= 0:
        raise ValueError(f"groups must be positive, got {groups}")
    if in_channels % groups != 0:
        raise ValueError(f"in_channels ({in_channels}) must be divisible by groups ({groups})")

    out_ch_per_group = w_data.shape[1]
    out_channels = out_ch_per_group * groups
    kernel_d, kernel_h, kernel_w = w_data.shape[2], w_data.shape[3], w_data.shape[4]

    if bias is not None and b_data.shape != (out_channels,):
        raise ValueError(f"bias shape must be ({out_channels},), got {b_data.shape}")
    if out_pad_d < 0 or out_pad_h < 0 or out_pad_w < 0:
        raise ValueError(f"output_padding must be non-negative, got {(out_pad_d, out_pad_h, out_pad_w)}")

    out_d = (in_d - 1) * stride_d - 2 * pad_d + dil_d * (kernel_d - 1) + out_pad_d + 1
    out_h = (in_h - 1) * stride_h - 2 * pad_h + dil_h * (kernel_h - 1) + out_pad_h + 1
    out_w = (in_w - 1) * stride_w - 2 * pad_w + dil_w * (kernel_w - 1) + out_pad_w + 1
    if out_d <= 0 or out_h <= 0 or out_w <= 0:
        raise ValueError(
            f"invalid output shape for conv_transpose3d: input={x_data.shape}, weight={w_data.shape}, "
            f"stride={(stride_d, stride_h, stride_w)}, padding={(pad_d, pad_h, pad_w)}, "
            f"output_padding={(out_pad_d, out_pad_h, out_pad_w)}, dilation={(dil_d, dil_h, dil_w)}"
        )

    out_data = np.zeros((n, out_channels, out_d, out_h, out_w), dtype=x_data.dtype)
    in_ch_per_group = in_channels // groups

    for bi in range(n):
        for g in range(groups):
            in_start = g * in_ch_per_group
            out_start = g * out_ch_per_group
            for ic_local in range(in_ch_per_group):
                ic = in_start + ic_local
                for id_ in range(in_d):
                    base_d = id_ * stride_d - pad_d
                    for ih in range(in_h):
                        base_h = ih * stride_h - pad_h
                        for iw in range(in_w):
                            base_w = iw * stride_w - pad_w
                            x_val = x_data[bi, ic, id_, ih, iw]
                            for kd in range(kernel_d):
                                od = base_d + kd * dil_d
                                if od < 0 or od >= out_d:
                                    continue
                                for kh in range(kernel_h):
                                    oh = base_h + kh * dil_h
                                    if oh < 0 or oh >= out_h:
                                        continue
                                    for kw in range(kernel_w):
                                        ow = base_w + kw * dil_w
                                        if ow < 0 or ow >= out_w:
                                            continue
                                        for oc_local in range(out_ch_per_group):
                                            oc = out_start + oc_local
                                            out_data[bi, oc, od, oh, ow] += x_val * w_data[ic, oc_local, kd, kh, kw]

    if b_data is not None:
        out_data += b_data.reshape(1, -1, 1, 1, 1)

    requires_grad = input.requires_grad or weight.requires_grad or (bias is not None and bias.requires_grad)
    children = [t for t in (input, weight, bias) if t is not None and t.requires_grad]
    out = Tensor(
        out_data,
        requires_grad=requires_grad,
        _children=tuple(children),
        _op="conv_transpose3d",
        device=input.device,
    )

    def _backward():
        grad_out = out.grad

        if weight.requires_grad:
            w_grad = np.zeros_like(w_data)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for ic_local in range(in_ch_per_group):
                        ic = in_start + ic_local
                        for id_ in range(in_d):
                            base_d = id_ * stride_d - pad_d
                            for ih in range(in_h):
                                base_h = ih * stride_h - pad_h
                                for iw in range(in_w):
                                    base_w = iw * stride_w - pad_w
                                    x_val = x_data[bi, ic, id_, ih, iw]
                                    for kd in range(kernel_d):
                                        od = base_d + kd * dil_d
                                        if od < 0 or od >= out_d:
                                            continue
                                        for kh in range(kernel_h):
                                            oh = base_h + kh * dil_h
                                            if oh < 0 or oh >= out_h:
                                                continue
                                            for kw in range(kernel_w):
                                                ow = base_w + kw * dil_w
                                                if ow < 0 or ow >= out_w:
                                                    continue
                                                for oc_local in range(out_ch_per_group):
                                                    oc = out_start + oc_local
                                                    w_grad[ic, oc_local, kd, kh, kw] += x_val * grad_out[bi, oc, od, oh, ow]
            weight.grad += w_grad.astype(weight.grad.dtype, copy=False)

        if bias is not None and bias.requires_grad:
            bias.grad += grad_out.sum(axis=(0, 2, 3, 4)).astype(bias.grad.dtype, copy=False)

        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for bi in range(n):
                for g in range(groups):
                    in_start = g * in_ch_per_group
                    out_start = g * out_ch_per_group
                    for ic_local in range(in_ch_per_group):
                        ic = in_start + ic_local
                        for id_ in range(in_d):
                            base_d = id_ * stride_d - pad_d
                            for ih in range(in_h):
                                base_h = ih * stride_h - pad_h
                                for iw in range(in_w):
                                    base_w = iw * stride_w - pad_w
                                    acc = 0.0
                                    for kd in range(kernel_d):
                                        od = base_d + kd * dil_d
                                        if od < 0 or od >= out_d:
                                            continue
                                        for kh in range(kernel_h):
                                            oh = base_h + kh * dil_h
                                            if oh < 0 or oh >= out_h:
                                                continue
                                            for kw in range(kernel_w):
                                                ow = base_w + kw * dil_w
                                                if ow < 0 or ow >= out_w:
                                                    continue
                                                for oc_local in range(out_ch_per_group):
                                                    oc = out_start + oc_local
                                                    acc += grad_out[bi, oc, od, oh, ow] * w_data[ic, oc_local, kd, kh, kw]
                                    x_grad[bi, ic, id_, ih, iw] += acc
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def max_pool2d(input: Tensor, kernel_size, stride=None, padding=0, dilation=1, ceil_mode=False, return_indices=False):
    input = _as_tensor(input)
    x_data = input.to_numpy()
    if x_data.ndim != 4:
        raise ValueError(f"max_pool2d expects 4D input (N, C, H, W), got shape {x_data.shape}")

    kernel_h, kernel_w = _pair(kernel_size)
    stride_h, stride_w = _pair(stride if stride is not None else kernel_size)
    pad_h, pad_w = _pair(padding)
    dil_h, dil_w = _pair(dilation)

    n, c, in_h, in_w = x_data.shape
    eff_kernel_h = dil_h * (kernel_h - 1) + 1
    eff_kernel_w = dil_w * (kernel_w - 1) + 1

    if ceil_mode:
        out_h = int(np.ceil((in_h + 2 * pad_h - eff_kernel_h) / stride_h + 1))
        out_w = int(np.ceil((in_w + 2 * pad_w - eff_kernel_w) / stride_w + 1))
    else:
        out_h = (in_h + 2 * pad_h - eff_kernel_h) // stride_h + 1
        out_w = (in_w + 2 * pad_w - eff_kernel_w) // stride_w + 1
    if ceil_mode and out_h > 0 and (out_h - 1) * stride_h >= in_h + pad_h:
        out_h -= 1
    if ceil_mode and out_w > 0 and (out_w - 1) * stride_w >= in_w + pad_w:
        out_w -= 1
    out_h = max(out_h, 0)
    out_w = max(out_w, 0)

    x_padded = np.pad(
        x_data,
        ((0, 0), (0, 0), (pad_h, pad_h), (pad_w, pad_w)),
        mode="constant",
        constant_values=-np.inf,
    )

    out_data = np.empty((n, c, out_h, out_w), dtype=x_data.dtype)
    max_h = np.full((n, c, out_h, out_w), -1, dtype=np.int64)
    max_w = np.full((n, c, out_h, out_w), -1, dtype=np.int64)

    for bi in range(n):
        for ci in range(c):
            for oh in range(out_h):
                ih_start = oh * stride_h
                for ow in range(out_w):
                    iw_start = ow * stride_w
                    best_val = -np.inf
                    best_h = -1
                    best_w = -1
                    for kh in range(kernel_h):
                        ih = ih_start + kh * dil_h
                        if ih < 0 or ih >= x_padded.shape[2]:
                            continue
                        for kw in range(kernel_w):
                            iw = iw_start + kw * dil_w
                            if iw < 0 or iw >= x_padded.shape[3]:
                                continue
                            v = x_padded[bi, ci, ih, iw]
                            if v > best_val:
                                best_val = v
                                best_h = ih
                                best_w = iw
                    out_data[bi, ci, oh, ow] = best_val
                    max_h[bi, ci, oh, ow] = best_h
                    max_w[bi, ci, oh, ow] = best_w

    out = Tensor(out_data, requires_grad=input.requires_grad, _children=(input,), _op="max_pool2d", device=input.device)

    def _backward():
        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for bi in range(n):
                for ci in range(c):
                    for oh in range(out_h):
                        for ow in range(out_w):
                            ih = max_h[bi, ci, oh, ow] - pad_h
                            iw = max_w[bi, ci, oh, ow] - pad_w
                            if 0 <= ih < in_h and 0 <= iw < in_w:
                                x_grad[bi, ci, ih, iw] += out.grad[bi, ci, oh, ow]
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward

    if not return_indices:
        return out

    indices = (max_h - pad_h) * in_w + (max_w - pad_w)
    indices[(max_h < pad_h) | (max_h >= pad_h + in_h) | (max_w < pad_w) | (max_w >= pad_w + in_w)] = -1
    return out, Tensor(indices.astype(np.int64), requires_grad=False, device=input.device)


def avg_pool2d(
    input: Tensor,
    kernel_size,
    stride=None,
    padding=0,
    ceil_mode=False,
    count_include_pad=True,
    divisor_override=None,
):
    input = _as_tensor(input)
    x_data = input.to_numpy()
    if x_data.ndim != 4:
        raise ValueError(f"avg_pool2d expects 4D input (N, C, H, W), got shape {x_data.shape}")

    kernel_h, kernel_w = _pair(kernel_size)
    stride_h, stride_w = _pair(stride if stride is not None else kernel_size)
    pad_h, pad_w = _pair(padding)

    n, c, in_h, in_w = x_data.shape
    eff_kernel_h = kernel_h
    eff_kernel_w = kernel_w
    if ceil_mode:
        out_h = int(np.ceil((in_h + 2 * pad_h - eff_kernel_h) / stride_h + 1))
        out_w = int(np.ceil((in_w + 2 * pad_w - eff_kernel_w) / stride_w + 1))
    else:
        out_h = (in_h + 2 * pad_h - eff_kernel_h) // stride_h + 1
        out_w = (in_w + 2 * pad_w - eff_kernel_w) // stride_w + 1
    if ceil_mode and out_h > 0 and (out_h - 1) * stride_h >= in_h + pad_h:
        out_h -= 1
    if ceil_mode and out_w > 0 and (out_w - 1) * stride_w >= in_w + pad_w:
        out_w -= 1
    out_h = max(out_h, 0)
    out_w = max(out_w, 0)

    x_padded = np.pad(
        x_data,
        ((0, 0), (0, 0), (pad_h, pad_h), (pad_w, pad_w)),
        mode="constant",
        constant_values=0.0,
    )

    out_data = np.zeros((n, c, out_h, out_w), dtype=x_data.dtype)
    divisors = np.zeros((n, c, out_h, out_w), dtype=np.float64)

    for bi in range(n):
        for ci in range(c):
            for oh in range(out_h):
                ih_start = oh * stride_h
                for ow in range(out_w):
                    iw_start = ow * stride_w
                    acc = 0.0
                    valid = 0
                    for kh in range(kernel_h):
                        ih = ih_start + kh
                        for kw in range(kernel_w):
                            iw = iw_start + kw
                            if 0 <= ih < x_padded.shape[2] and 0 <= iw < x_padded.shape[3]:
                                acc += x_padded[bi, ci, ih, iw]
                            if pad_h <= ih < pad_h + in_h and pad_w <= iw < pad_w + in_w:
                                valid += 1
                    if divisor_override is not None:
                        div = float(divisor_override)
                    elif count_include_pad:
                        div = float(kernel_h * kernel_w)
                    else:
                        div = float(max(valid, 1))
                    divisors[bi, ci, oh, ow] = div
                    out_data[bi, ci, oh, ow] = acc / div

    out = Tensor(out_data, requires_grad=input.requires_grad, _children=(input,), _op="avg_pool2d", device=input.device)

    def _backward():
        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for bi in range(n):
                for ci in range(c):
                    for oh in range(out_h):
                        ih_start = oh * stride_h
                        for ow in range(out_w):
                            iw_start = ow * stride_w
                            go = out.grad[bi, ci, oh, ow] / divisors[bi, ci, oh, ow]
                            for kh in range(kernel_h):
                                ih = ih_start + kh - pad_h
                                if ih < 0 or ih >= in_h:
                                    continue
                                for kw in range(kernel_w):
                                    iw = iw_start + kw - pad_w
                                    if iw < 0 or iw >= in_w:
                                        continue
                                    x_grad[bi, ci, ih, iw] += go
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def _resolve_adaptive_output_size(output_size, input_spatial_shape):
    dims = len(input_spatial_shape)
    if isinstance(output_size, int):
        resolved = (int(output_size),) * dims
    elif isinstance(output_size, (tuple, list)):
        if len(output_size) != dims:
            raise ValueError(f"output_size for {dims}D adaptive pooling must have {dims} values, got {output_size}")
        resolved_vals = []
        for i, size in enumerate(output_size):
            if size is None:
                resolved_vals.append(int(input_spatial_shape[i]))
            else:
                resolved_vals.append(int(size))
        resolved = tuple(resolved_vals)
    else:
        raise ValueError(f"invalid output_size {output_size}")

    if any(size <= 0 for size in resolved):
        raise ValueError(f"output_size must be positive, got {output_size}")
    return resolved


def adaptive_avg_pool1d(input: Tensor, output_size):
    input = _as_tensor(input)
    x_data = input.to_numpy()
    if x_data.ndim != 3:
        raise ValueError(f"adaptive_avg_pool1d expects 3D input (N, C, L), got shape {x_data.shape}")

    n, c, in_len = x_data.shape
    (out_len,) = _resolve_adaptive_output_size(output_size, (in_len,))
    out_data = np.zeros((n, c, out_len), dtype=x_data.dtype)
    starts = np.zeros(out_len, dtype=np.int64)
    ends = np.zeros(out_len, dtype=np.int64)

    for ol in range(out_len):
        start = int(np.floor(ol * in_len / out_len))
        end = int(np.ceil((ol + 1) * in_len / out_len))
        starts[ol] = start
        ends[ol] = end
        out_data[:, :, ol] = x_data[:, :, start:end].mean(axis=2)

    out = Tensor(
        out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="adaptive_avg_pool1d",
        device=input.device,
    )

    def _backward():
        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for ol in range(out_len):
                start = starts[ol]
                end = ends[ol]
                width = float(max(end - start, 1))
                x_grad[:, :, start:end] += out.grad[:, :, ol:ol + 1] / width
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def adaptive_max_pool1d(input: Tensor, output_size, return_indices: bool = False):
    input = _as_tensor(input)
    x_data = input.to_numpy()
    if x_data.ndim != 3:
        raise ValueError(f"adaptive_max_pool1d expects 3D input (N, C, L), got shape {x_data.shape}")

    n, c, in_len = x_data.shape
    (out_len,) = _resolve_adaptive_output_size(output_size, (in_len,))
    out_data = np.zeros((n, c, out_len), dtype=x_data.dtype)
    max_indices = np.zeros((n, c, out_len), dtype=np.int64)

    for ol in range(out_len):
        start = int(np.floor(ol * in_len / out_len))
        end = int(np.ceil((ol + 1) * in_len / out_len))
        region = x_data[:, :, start:end]
        local_idx = region.argmax(axis=2)
        out_data[:, :, ol] = np.take_along_axis(region, local_idx[..., None], axis=2)[:, :, 0]
        max_indices[:, :, ol] = local_idx + start

    out = Tensor(
        out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="adaptive_max_pool1d",
        device=input.device,
    )

    def _backward():
        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for bi in range(n):
                for ci in range(c):
                    for ol in range(out_len):
                        idx = max_indices[bi, ci, ol]
                        x_grad[bi, ci, idx] += out.grad[bi, ci, ol]
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    if not return_indices:
        return out
    return out, Tensor(max_indices.astype(np.int64), requires_grad=False, device=input.device)


def adaptive_avg_pool2d(input: Tensor, output_size):
    input = _as_tensor(input)
    x_data = input.to_numpy()
    if x_data.ndim != 4:
        raise ValueError(f"adaptive_avg_pool2d expects 4D input (N, C, H, W), got shape {x_data.shape}")

    n, c, in_h, in_w = x_data.shape
    out_h, out_w = _resolve_adaptive_output_size(output_size, (in_h, in_w))
    out_data = np.zeros((n, c, out_h, out_w), dtype=x_data.dtype)

    h_starts = np.array([int(np.floor(oh * in_h / out_h)) for oh in range(out_h)], dtype=np.int64)
    h_ends = np.array([int(np.ceil((oh + 1) * in_h / out_h)) for oh in range(out_h)], dtype=np.int64)
    w_starts = np.array([int(np.floor(ow * in_w / out_w)) for ow in range(out_w)], dtype=np.int64)
    w_ends = np.array([int(np.ceil((ow + 1) * in_w / out_w)) for ow in range(out_w)], dtype=np.int64)

    for oh in range(out_h):
        hs = h_starts[oh]
        he = h_ends[oh]
        for ow in range(out_w):
            ws = w_starts[ow]
            we = w_ends[ow]
            out_data[:, :, oh, ow] = x_data[:, :, hs:he, ws:we].mean(axis=(2, 3))

    out = Tensor(
        out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="adaptive_avg_pool2d",
        device=input.device,
    )

    def _backward():
        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for oh in range(out_h):
                hs = h_starts[oh]
                he = h_ends[oh]
                for ow in range(out_w):
                    ws = w_starts[ow]
                    we = w_ends[ow]
                    area = float(max((he - hs) * (we - ws), 1))
                    grad_slice = out.grad[:, :, oh:oh + 1, ow:ow + 1] / area
                    x_grad[:, :, hs:he, ws:we] += grad_slice
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def adaptive_max_pool2d(input: Tensor, output_size, return_indices: bool = False):
    input = _as_tensor(input)
    x_data = input.to_numpy()
    if x_data.ndim != 4:
        raise ValueError(f"adaptive_max_pool2d expects 4D input (N, C, H, W), got shape {x_data.shape}")

    n, c, in_h, in_w = x_data.shape
    out_h, out_w = _resolve_adaptive_output_size(output_size, (in_h, in_w))
    out_data = np.zeros((n, c, out_h, out_w), dtype=x_data.dtype)
    max_h = np.zeros((n, c, out_h, out_w), dtype=np.int64)
    max_w = np.zeros((n, c, out_h, out_w), dtype=np.int64)

    h_starts = np.array([int(np.floor(oh * in_h / out_h)) for oh in range(out_h)], dtype=np.int64)
    h_ends = np.array([int(np.ceil((oh + 1) * in_h / out_h)) for oh in range(out_h)], dtype=np.int64)
    w_starts = np.array([int(np.floor(ow * in_w / out_w)) for ow in range(out_w)], dtype=np.int64)
    w_ends = np.array([int(np.ceil((ow + 1) * in_w / out_w)) for ow in range(out_w)], dtype=np.int64)

    for oh in range(out_h):
        hs = h_starts[oh]
        he = h_ends[oh]
        h_size = he - hs
        for ow in range(out_w):
            ws = w_starts[ow]
            we = w_ends[ow]
            w_size = we - ws

            region = x_data[:, :, hs:he, ws:we]
            flat = region.reshape(n, c, -1)
            local_idx = flat.argmax(axis=2)
            out_data[:, :, oh, ow] = np.take_along_axis(flat, local_idx[..., None], axis=2)[:, :, 0]
            max_h[:, :, oh, ow] = hs + (local_idx // w_size)
            max_w[:, :, oh, ow] = ws + (local_idx % w_size)

    out = Tensor(
        out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="adaptive_max_pool2d",
        device=input.device,
    )

    def _backward():
        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for bi in range(n):
                for ci in range(c):
                    for oh in range(out_h):
                        for ow in range(out_w):
                            ih = max_h[bi, ci, oh, ow]
                            iw = max_w[bi, ci, oh, ow]
                            x_grad[bi, ci, ih, iw] += out.grad[bi, ci, oh, ow]
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    if not return_indices:
        return out

    flat_indices = max_h * in_w + max_w
    return out, Tensor(flat_indices.astype(np.int64), requires_grad=False, device=input.device)


def adaptive_avg_pool3d(input: Tensor, output_size):
    input = _as_tensor(input)
    x_data = input.to_numpy()
    if x_data.ndim != 5:
        raise ValueError(f"adaptive_avg_pool3d expects 5D input (N, C, D, H, W), got shape {x_data.shape}")

    n, c, in_d, in_h, in_w = x_data.shape
    out_d, out_h, out_w = _resolve_adaptive_output_size(output_size, (in_d, in_h, in_w))
    out_data = np.zeros((n, c, out_d, out_h, out_w), dtype=x_data.dtype)

    d_starts = np.array([int(np.floor(od * in_d / out_d)) for od in range(out_d)], dtype=np.int64)
    d_ends = np.array([int(np.ceil((od + 1) * in_d / out_d)) for od in range(out_d)], dtype=np.int64)
    h_starts = np.array([int(np.floor(oh * in_h / out_h)) for oh in range(out_h)], dtype=np.int64)
    h_ends = np.array([int(np.ceil((oh + 1) * in_h / out_h)) for oh in range(out_h)], dtype=np.int64)
    w_starts = np.array([int(np.floor(ow * in_w / out_w)) for ow in range(out_w)], dtype=np.int64)
    w_ends = np.array([int(np.ceil((ow + 1) * in_w / out_w)) for ow in range(out_w)], dtype=np.int64)

    for od in range(out_d):
        ds = d_starts[od]
        de = d_ends[od]
        for oh in range(out_h):
            hs = h_starts[oh]
            he = h_ends[oh]
            for ow in range(out_w):
                ws = w_starts[ow]
                we = w_ends[ow]
                out_data[:, :, od, oh, ow] = x_data[:, :, ds:de, hs:he, ws:we].mean(axis=(2, 3, 4))

    out = Tensor(
        out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="adaptive_avg_pool3d",
        device=input.device,
    )

    def _backward():
        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for od in range(out_d):
                ds = d_starts[od]
                de = d_ends[od]
                for oh in range(out_h):
                    hs = h_starts[oh]
                    he = h_ends[oh]
                    for ow in range(out_w):
                        ws = w_starts[ow]
                        we = w_ends[ow]
                        volume = float(max((de - ds) * (he - hs) * (we - ws), 1))
                        grad_slice = out.grad[:, :, od:od + 1, oh:oh + 1, ow:ow + 1] / volume
                        x_grad[:, :, ds:de, hs:he, ws:we] += grad_slice
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def adaptive_max_pool3d(input: Tensor, output_size, return_indices: bool = False):
    input = _as_tensor(input)
    x_data = input.to_numpy()
    if x_data.ndim != 5:
        raise ValueError(f"adaptive_max_pool3d expects 5D input (N, C, D, H, W), got shape {x_data.shape}")

    n, c, in_d, in_h, in_w = x_data.shape
    out_d, out_h, out_w = _resolve_adaptive_output_size(output_size, (in_d, in_h, in_w))
    out_data = np.zeros((n, c, out_d, out_h, out_w), dtype=x_data.dtype)
    max_d = np.zeros((n, c, out_d, out_h, out_w), dtype=np.int64)
    max_h = np.zeros((n, c, out_d, out_h, out_w), dtype=np.int64)
    max_w = np.zeros((n, c, out_d, out_h, out_w), dtype=np.int64)

    d_starts = np.array([int(np.floor(od * in_d / out_d)) for od in range(out_d)], dtype=np.int64)
    d_ends = np.array([int(np.ceil((od + 1) * in_d / out_d)) for od in range(out_d)], dtype=np.int64)
    h_starts = np.array([int(np.floor(oh * in_h / out_h)) for oh in range(out_h)], dtype=np.int64)
    h_ends = np.array([int(np.ceil((oh + 1) * in_h / out_h)) for oh in range(out_h)], dtype=np.int64)
    w_starts = np.array([int(np.floor(ow * in_w / out_w)) for ow in range(out_w)], dtype=np.int64)
    w_ends = np.array([int(np.ceil((ow + 1) * in_w / out_w)) for ow in range(out_w)], dtype=np.int64)

    for od in range(out_d):
        ds = d_starts[od]
        de = d_ends[od]
        d_size = de - ds
        for oh in range(out_h):
            hs = h_starts[oh]
            he = h_ends[oh]
            h_size = he - hs
            for ow in range(out_w):
                ws = w_starts[ow]
                we = w_ends[ow]
                w_size = we - ws

                region = x_data[:, :, ds:de, hs:he, ws:we]
                flat = region.reshape(n, c, -1)
                local_idx = flat.argmax(axis=2)
                out_data[:, :, od, oh, ow] = np.take_along_axis(flat, local_idx[..., None], axis=2)[:, :, 0]

                dhw = h_size * w_size
                max_d[:, :, od, oh, ow] = ds + (local_idx // dhw)
                rem = local_idx % dhw
                max_h[:, :, od, oh, ow] = hs + (rem // w_size)
                max_w[:, :, od, oh, ow] = ws + (rem % w_size)

    out = Tensor(
        out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="adaptive_max_pool3d",
        device=input.device,
    )

    def _backward():
        if input.requires_grad:
            x_grad = np.zeros_like(x_data)
            for bi in range(n):
                for ci in range(c):
                    for od in range(out_d):
                        for oh in range(out_h):
                            for ow in range(out_w):
                                id_ = max_d[bi, ci, od, oh, ow]
                                ih = max_h[bi, ci, od, oh, ow]
                                iw = max_w[bi, ci, od, oh, ow]
                                x_grad[bi, ci, id_, ih, iw] += out.grad[bi, ci, od, oh, ow]
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    if not return_indices:
        return out

    flat_indices = max_d * (in_h * in_w) + max_h * in_w + max_w
    return out, Tensor(flat_indices.astype(np.int64), requires_grad=False, device=input.device)


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


def _infer_class_dim_for_loss(x_shape, target_shape, dim=None):
    ndim = len(x_shape)
    if ndim == 0:
        raise ValueError("classification loss expects input with at least 1 dimension")

    if dim is not None:
        class_dim = dim + ndim if dim < 0 else dim
        if class_dim < 0 or class_dim >= ndim:
            raise ValueError(f"dim out of range for input shape {x_shape}: got {dim}")
        if ndim == 1:
            if target_shape not in ((), (1,)):
                raise ValueError(f"for 1D input of shape {x_shape}, target must be scalar or shape (1,), got {target_shape}")
            return class_dim

        expected = x_shape[:class_dim] + x_shape[class_dim + 1:]
        if target_shape != expected:
            raise ValueError(
                f"target shape must be {expected} when class dim is {class_dim} for input shape {x_shape}, "
                f"got {target_shape}"
            )
        return class_dim

    if ndim == 1:
        if target_shape not in ((), (1,)):
            raise ValueError(f"for 1D input of shape {x_shape}, target must be scalar or shape (1,), got {target_shape}")
        return 0

    # Prefer PyTorch layout (N, C, ...) while keeping legacy last-dim-class compatibility.
    pytorch_shape = (x_shape[0],) + x_shape[2:]
    legacy_shape = x_shape[:-1]
    if target_shape == pytorch_shape:
        return 1
    if target_shape == legacy_shape:
        return ndim - 1

    raise ValueError(
        f"target shape {target_shape} does not match supported layouts for input shape {x_shape}: "
        f"(N,C,...) -> {pytorch_shape} or legacy last-dim class -> {legacy_shape}"
    )


def cross_entropy(
    input: Tensor,
    target,
    weight=None,
    ignore_index: int = -100,
    reduction: str = "mean",
    label_smoothing: float = 0.0,
    dim=None,
):
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target_arr = target.to_numpy()
    else:
        target_arr = np.asarray(target)
    class_dim = _infer_class_dim_for_loss(input.shape, target_arr.shape, dim=dim)
    log_probs = log_softmax(input, axis=class_dim)
    return nll_loss(
        log_probs,
        target_arr,
        weight=weight,
        ignore_index=ignore_index,
        reduction=reduction,
        label_smoothing=label_smoothing,
        dim=class_dim,
    )


def nll_loss(
    input: Tensor,
    target,
    weight=None,
    ignore_index: int = -100,
    reduction: str = "mean",
    label_smoothing: float = 0.0,
    dim=None,
):
    # input: log-probabilities
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target_arr = target.to_numpy()
    else:
        target_arr = np.asarray(target)
    target_arr = np.asarray(target_arr, dtype=np.int64)
    x = input.to_numpy()

    if reduction not in ("none", "mean", "sum"):
        raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")
    if label_smoothing < 0.0 or label_smoothing >= 1.0:
        raise ValueError(f"label_smoothing must satisfy 0 <= label_smoothing < 1, got {label_smoothing}")

    class_dim = _infer_class_dim_for_loss(x.shape, target_arr.shape, dim=dim)

    if x.ndim == 1:
        c = x.shape[0]
        x_moved = x.reshape(1, c)
        target_shape = target_arr.shape
        target_flat = target_arr.reshape(-1)
    else:
        x_moved = np.moveaxis(x, class_dim, -1)
        c = x_moved.shape[-1]
        target_shape = target_arr.shape
        target_flat = target_arr.reshape(-1)

    x_flat = x_moved.reshape(-1, c)
    valid_mask = target_flat != int(ignore_index)
    valid_indices = np.nonzero(valid_mask)[0]
    targets_valid = target_flat[valid_mask]

    weight_arr = None
    if weight is not None:
        weight_arr = weight.to_numpy() if isinstance(weight, Tensor) else np.asarray(weight)
        weight_arr = np.asarray(weight_arr)
        if weight_arr.shape != (c,):
            raise ValueError(f"weight must have shape ({c},), got {weight_arr.shape}")
        weight_arr = weight_arr.astype(x_flat.dtype, copy=False)

    if targets_valid.size > 0:
        if np.any(targets_valid < 0) or np.any(targets_valid >= c):
            bad = targets_valid[(targets_valid < 0) | (targets_valid >= c)][0]
            raise ValueError(f"target contains invalid class index {int(bad)} for input with {c} classes")

    if weight_arr is None:
        sample_weights = np.ones(targets_valid.shape[0], dtype=x_flat.dtype)
    else:
        sample_weights = weight_arr[targets_valid]

    loss_flat = np.zeros(x_flat.shape[0], dtype=x_flat.dtype)
    if targets_valid.size > 0:
        logp_valid = x_flat[valid_mask]
        nll_component = -logp_valid[np.arange(targets_valid.size), targets_valid]
        if label_smoothing > 0.0:
            if weight_arr is None:
                smooth_component = -logp_valid.mean(axis=1)
            else:
                smooth_component = -(logp_valid * (weight_arr.reshape(1, -1) / float(c))).sum(axis=1)
            loss_valid = (1.0 - label_smoothing) * sample_weights * nll_component + label_smoothing * smooth_component
        else:
            loss_valid = sample_weights * nll_component
        loss_flat[valid_mask] = loss_valid
    else:
        loss_valid = np.zeros((0,), dtype=x_flat.dtype)

    if reduction == "none":
        out_data = loss_flat.reshape(target_shape)
    elif reduction == "sum":
        out_data = loss_valid.sum()
    else:
        if loss_valid.size == 0:
            out_data = np.array(0.0, dtype=x_flat.dtype)
        else:
            denom = sample_weights.sum() if weight_arr is not None else float(loss_valid.size)
            out_data = loss_valid.sum() / float(max(denom, 1e-12))

    out = Tensor(
        np.array(out_data) if np.isscalar(out_data) else out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="nll_loss",
        device=input.device,
    )

    def _backward():
        if not input.requires_grad:
            return

        grad_flat = np.zeros_like(x_flat, dtype=x_flat.dtype)
        if targets_valid.size > 0:
            if label_smoothing > 0.0:
                if weight_arr is None:
                    grad_rows = np.full((targets_valid.size, c), -label_smoothing / float(c), dtype=x_flat.dtype)
                else:
                    grad_rows = np.broadcast_to(
                        -label_smoothing * weight_arr.reshape(1, -1) / float(c),
                        (targets_valid.size, c),
                    ).copy()
                grad_rows[np.arange(targets_valid.size), targets_valid] += -(1.0 - label_smoothing) * sample_weights
            else:
                grad_rows = np.zeros((targets_valid.size, c), dtype=x_flat.dtype)
                grad_rows[np.arange(targets_valid.size), targets_valid] = -sample_weights

            if reduction == "mean":
                denom = sample_weights.sum() if weight_arr is not None else float(targets_valid.size)
                if denom > 0:
                    grad_rows /= float(denom)
                else:
                    grad_rows.fill(0.0)

            if reduction == "none":
                out_grad_flat = np.asarray(out.grad).reshape(-1).astype(x_flat.dtype, copy=False)
                grad_rows *= out_grad_flat[valid_indices].reshape(-1, 1)
            else:
                grad_rows *= np.asarray(out.grad).astype(x_flat.dtype, copy=False)

            grad_flat[valid_mask] = grad_rows

        grad_moved = grad_flat.reshape(x_moved.shape)
        if x.ndim == 1:
            grad_input = grad_moved.reshape(x.shape)
        else:
            grad_input = np.moveaxis(grad_moved, -1, class_dim)
        input.grad += grad_input.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def bce_loss(input: Tensor, target, weight=None, reduction="mean"):
    """Binary Cross Entropy Loss
    
    Computes: -[target * log(input) + (1 - target) * log(1 - input)]
    Numerically stable version handles edge cases.
    """
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target_arr = target.to_numpy()
    else:
        target_arr = np.asarray(target)

    x = input.to_numpy()
    target_arr = np.asarray(target_arr, dtype=x.dtype)
    if target_arr.shape != x.shape:
        raise ValueError(f"target shape must match input shape {x.shape}, got {target_arr.shape}")
    if reduction not in ("none", "mean", "sum"):
        raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")

    if weight is None:
        weight_arr = None
    else:
        raw_weight = weight.to_numpy() if isinstance(weight, Tensor) else np.asarray(weight)
        try:
            weight_arr = np.broadcast_to(np.asarray(raw_weight, dtype=x.dtype), x.shape)
        except ValueError as exc:
            raise ValueError(f"weight with shape {np.asarray(raw_weight).shape} is not broadcastable to {x.shape}") from exc

    # Clamp to prevent log(0)
    x_clamped = np.clip(x, 1e-7, 1 - 1e-7)
    loss_vals = -(target_arr * np.log(x_clamped) + (1.0 - target_arr) * np.log(1.0 - x_clamped))
    if weight_arr is not None:
        loss_vals = loss_vals * weight_arr

    if reduction == "sum":
        out_data = loss_vals.sum()
    elif reduction == "none":
        out_data = loss_vals
    else:  # mean
        out_data = loss_vals.mean()

    out = Tensor(
        np.array(out_data) if np.isscalar(out_data) else out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="bce_loss",
        device=input.device,
    )

    def _backward():
        if not input.requires_grad:
            return

        grad = -(target_arr / x_clamped - (1.0 - target_arr) / (1.0 - x_clamped))
        if weight_arr is not None:
            grad = grad * weight_arr

        out_grad_arr = np.asarray(out.grad, dtype=grad.dtype)
        if reduction == "none":
            grad = grad * out_grad_arr
        elif reduction == "mean":
            grad = (grad / grad.size) * out_grad_arr
        else:
            grad = grad * out_grad_arr
        input.grad += grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def bce_with_logits_loss(input: Tensor, target, weight=None, reduction="mean", pos_weight=None):
    """Binary Cross Entropy with Logits Loss
    
    Combines sigmoid and BCE into one numerically stable operation.
    More stable than sigmoid(input) -> bce_loss()
    """
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target_arr = target.to_numpy()
    else:
        target_arr = np.asarray(target)

    x = input.to_numpy()
    target_arr = np.asarray(target_arr, dtype=x.dtype)
    if target_arr.shape != x.shape:
        raise ValueError(f"target shape must match input shape {x.shape}, got {target_arr.shape}")
    if reduction not in ("none", "mean", "sum"):
        raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")

    if weight is None:
        weight_arr = None
    else:
        raw_weight = weight.to_numpy() if isinstance(weight, Tensor) else np.asarray(weight)
        try:
            weight_arr = np.broadcast_to(np.asarray(raw_weight, dtype=x.dtype), x.shape)
        except ValueError as exc:
            raise ValueError(f"weight with shape {np.asarray(raw_weight).shape} is not broadcastable to {x.shape}") from exc

    if pos_weight is None:
        pos_weight_arr = None
    else:
        raw_pos_weight = pos_weight.to_numpy() if isinstance(pos_weight, Tensor) else np.asarray(pos_weight)
        try:
            pos_weight_arr = np.broadcast_to(np.asarray(raw_pos_weight, dtype=x.dtype), x.shape)
        except ValueError as exc:
            raise ValueError(
                f"pos_weight with shape {np.asarray(raw_pos_weight).shape} is not broadcastable to {x.shape}"
            ) from exc

    # Stable logsigmoid variants
    log_sigmoid = -np.logaddexp(0.0, -x)
    log_one_minus_sigmoid = -np.logaddexp(0.0, x)
    if pos_weight_arr is None:
        loss_vals = -(target_arr * log_sigmoid + (1.0 - target_arr) * log_one_minus_sigmoid)
    else:
        loss_vals = -(pos_weight_arr * target_arr * log_sigmoid + (1.0 - target_arr) * log_one_minus_sigmoid)

    if weight_arr is not None:
        loss_vals = loss_vals * weight_arr

    if reduction == "sum":
        out_data = loss_vals.sum()
    elif reduction == "none":
        out_data = loss_vals
    else:  # mean
        out_data = loss_vals.mean()

    out = Tensor(
        np.array(out_data) if np.isscalar(out_data) else out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="bce_with_logits_loss",
        device=input.device,
    )

    def _backward():
        if not input.requires_grad:
            return

        sigmoid_x = 1.0 / (1.0 + np.exp(-np.clip(x, -500, 500)))
        if pos_weight_arr is None:
            grad = sigmoid_x - target_arr
        else:
            grad = (1.0 - target_arr) * sigmoid_x - pos_weight_arr * target_arr * (1.0 - sigmoid_x)

        if weight_arr is not None:
            grad = grad * weight_arr

        out_grad_arr = np.asarray(out.grad, dtype=grad.dtype)
        if reduction == "none":
            grad = grad * out_grad_arr
        elif reduction == "mean":
            grad = (grad / grad.size) * out_grad_arr
        else:
            grad = grad * out_grad_arr
        input.grad += grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def l1_loss(input: Tensor, target, reduction="mean"):
    """L1 Loss (Mean Absolute Error)
    
    Computes: |input - target|
    """
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target_arr = target.to_numpy()
    else:
        target_arr = np.asarray(target)

    x = input.to_numpy()
    target_arr = np.asarray(target_arr, dtype=x.dtype)
    if target_arr.shape != x.shape:
        raise ValueError(f"target shape must match input shape {x.shape}, got {target_arr.shape}")
    if reduction not in ("none", "mean", "sum"):
        raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")

    diff = x - target_arr
    loss_vals = np.abs(diff)
    
    if reduction == "sum":
        out_data = loss_vals.sum()
    elif reduction == "none":
        out_data = loss_vals
    else:  # mean
        out_data = loss_vals.mean()
    
    out = Tensor(
        np.array(out_data) if np.isscalar(out_data) else out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="l1_loss",
        device=input.device,
    )

    def _backward():
        if not input.requires_grad:
            return
        grad = np.sign(diff)
        out_grad_arr = np.asarray(out.grad, dtype=grad.dtype)
        if reduction == "none":
            grad = grad * out_grad_arr
        elif reduction == "mean":
            grad = (grad / diff.size) * out_grad_arr
        else:
            grad = grad * out_grad_arr
        input.grad += grad.astype(input.grad.dtype, copy=False)

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
        target_arr = target.to_numpy()
    else:
        target_arr = np.asarray(target)

    x = input.to_numpy()
    target_arr = np.asarray(target_arr, dtype=x.dtype)
    if target_arr.shape != x.shape:
        raise ValueError(f"target shape must match input shape {x.shape}, got {target_arr.shape}")
    if reduction not in ("none", "mean", "sum"):
        raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', got {reduction}")
    if beta < 0:
        raise ValueError(f"beta must be non-negative, got {beta}")

    diff = x - target_arr
    abs_diff = np.abs(diff)

    if beta == 0:
        loss_vals = abs_diff
    else:
        # Smooth L1: 0.5 * x^2 / beta if |x| < beta, |x| - 0.5 * beta otherwise
        loss_vals = np.where(abs_diff < beta, 0.5 * diff * diff / beta, abs_diff - 0.5 * beta)
    
    if reduction == "sum":
        out_data = loss_vals.sum()
    elif reduction == "none":
        out_data = loss_vals
    else:  # mean
        out_data = loss_vals.mean()
    
    out = Tensor(
        np.array(out_data) if np.isscalar(out_data) else out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="smooth_l1_loss",
        device=input.device,
    )

    def _backward():
        if not input.requires_grad:
            return
        if beta == 0:
            grad = np.sign(diff)
        else:
            grad = np.where(abs_diff < beta, diff / beta, np.sign(diff))
        out_grad_arr = np.asarray(out.grad, dtype=grad.dtype)
        if reduction == "none":
            grad = grad * out_grad_arr
        elif reduction == "mean":
            grad = (grad / diff.size) * out_grad_arr
        else:
            grad = grad * out_grad_arr
        input.grad += grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


def kl_div_loss(input: Tensor, target, reduction="mean", log_target: bool = False):
    """Kullback-Leibler Divergence Loss
    
    Computes KL(target || input) where both are log-probabilities
    KL = sum(target * (log(target) - input))
    """
    input = _as_tensor(input)
    if isinstance(target, Tensor):
        target_arr = target.to_numpy()
    else:
        target_arr = np.asarray(target)

    x = input.to_numpy()  # log-probabilities
    target_arr = np.asarray(target_arr, dtype=x.dtype)
    if target_arr.shape != x.shape:
        raise ValueError(f"target shape must match input shape {x.shape}, got {target_arr.shape}")
    if reduction not in ("none", "mean", "sum", "batchmean"):
        raise ValueError(f"reduction must be one of 'none', 'mean', 'sum', 'batchmean', got {reduction}")

    if log_target:
        target_prob = np.exp(target_arr)
        loss_vals = target_prob * (target_arr - x)
    else:
        target_prob = target_arr
        loss_vals = np.where(target_arr > 0, target_arr * (np.log(np.clip(target_arr, 1e-10, None)) - x), 0.0)

    if reduction == "none":
        out_data = loss_vals
    elif reduction == "sum":
        out_data = loss_vals.sum()
    elif reduction == "batchmean":
        batch = x.shape[0] if x.ndim > 0 else 1
        out_data = loss_vals.sum() / float(max(batch, 1))
    else:
        out_data = loss_vals.mean()

    out = Tensor(
        np.array(out_data) if np.isscalar(out_data) else out_data,
        requires_grad=input.requires_grad,
        _children=(input,),
        _op="kl_div_loss",
        device=input.device,
    )

    def _backward():
        if not input.requires_grad:
            return
        grad = -target_prob
        out_grad_arr = np.asarray(out.grad, dtype=grad.dtype)
        if reduction == "none":
            grad = grad * out_grad_arr
        elif reduction == "mean":
            grad = (grad / grad.size) * out_grad_arr
        elif reduction == "batchmean":
            batch = x.shape[0] if x.ndim > 0 else 1
            grad = (grad / float(max(batch, 1))) * out_grad_arr
        else:
            grad = grad * out_grad_arr
        input.grad += grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
    return out


__all__ = [
    "relu",
    "leaky_relu",
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
    "batch_norm",
    "group_norm",
    "instance_norm",
    "conv1d",
    "conv_transpose1d",
    "rnn_cell",
    "lstm_cell",
    "gru_cell",
    "rnn",
    "lstm",
    "gru",
    "max_pool1d",
    "avg_pool1d",
    "adaptive_avg_pool1d",
    "adaptive_max_pool1d",
    "conv2d",
    "conv_transpose2d",
    "conv3d",
    "conv_transpose3d",
    "max_pool2d",
    "avg_pool2d",
    "adaptive_avg_pool2d",
    "adaptive_max_pool2d",
    "adaptive_avg_pool3d",
    "adaptive_max_pool3d",
    "layer_norm",
    "rms_norm",
    "focal_loss",
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
