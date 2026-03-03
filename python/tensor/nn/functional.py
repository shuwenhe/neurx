import numpy as np

from tensor.tensor import Tensor


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
            x_data,
            ((0, 0), (0, 0), (pad_h, pad_h), (pad_w, pad_w)),
            mode="constant",
        )
    else:
        x_padded = x_data

    out_data = np.zeros((n, out_channels, out_h, out_w), dtype=x_data.dtype)
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
                                    acc += x_padded[bi, ic, ih, iw] * w_data[oc, ic_local, kh, kw]
                        out_data[bi, oc, oh, ow] = acc

    if b_data is not None:
        out_data += b_data.reshape(1, -1, 1, 1)

    requires_grad = input.requires_grad or weight.requires_grad or (bias is not None and bias.requires_grad)
    children = [t for t in (input, weight, bias) if t is not None and t.requires_grad]
    out = Tensor(out_data, requires_grad=requires_grad, _children=tuple(children), _op="conv2d", device=input.device)

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
                                            x_grad_padded[bi, ic, ih, iw] += w_data[oc, ic_local, kh, kw] * go
            if pad_h > 0 or pad_w > 0:
                x_grad = x_grad_padded[:, :, pad_h:pad_h + in_h, pad_w:pad_w + in_w]
            else:
                x_grad = x_grad_padded
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


def adaptive_avg_pool2d(input: Tensor, output_size):
    input = _as_tensor(input)
    x_data = input.to_numpy()
    if x_data.ndim != 4:
        raise ValueError(f"adaptive_avg_pool2d expects 4D input (N, C, H, W), got shape {x_data.shape}")

    if isinstance(output_size, int):
        out_h, out_w = output_size, output_size
    else:
        out_h, out_w = output_size
    if out_h <= 0 or out_w <= 0:
        raise ValueError(f"output_size must be positive, got {output_size}")

    n, c, in_h, in_w = x_data.shape
    out_data = np.zeros((n, c, out_h, out_w), dtype=x_data.dtype)
    regions = []

    for oh in range(out_h):
        h_start = int(np.floor(oh * in_h / out_h))
        h_end = int(np.ceil((oh + 1) * in_h / out_h))
        for ow in range(out_w):
            w_start = int(np.floor(ow * in_w / out_w))
            w_end = int(np.ceil((ow + 1) * in_w / out_w))
            region = x_data[:, :, h_start:h_end, w_start:w_end]
            out_data[:, :, oh, ow] = region.mean(axis=(2, 3))
            regions.append((h_start, h_end, w_start, w_end))

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
            ridx = 0
            for oh in range(out_h):
                for ow in range(out_w):
                    h_start, h_end, w_start, w_end = regions[ridx]
                    ridx += 1
                    area = float((h_end - h_start) * (w_end - w_start))
                    grad_slice = out.grad[:, :, oh:oh + 1, ow:ow + 1] / area
                    x_grad[:, :, h_start:h_end, w_start:w_end] += grad_slice
            input.grad += x_grad.astype(input.grad.dtype, copy=False)

    out._backward = _backward
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
    "conv1d",
    "max_pool1d",
    "avg_pool1d",
    "conv2d",
    "max_pool2d",
    "avg_pool2d",
    "adaptive_avg_pool2d",
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
