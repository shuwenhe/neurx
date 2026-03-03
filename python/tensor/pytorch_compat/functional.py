from tensor.tensor import Tensor
from tensor.nn import functional as F


def _as_tensor(x):
    return x if isinstance(x, Tensor) else Tensor(x)


def linear(input, weight, bias=None):
    input = _as_tensor(input)
    weight = _as_tensor(weight)
    # PyTorch: weight shape is (out_features, in_features)
    return F.linear(input, weight.transpose(0, 1), bias)


def relu(input):
    return F.relu(input)


def leaky_relu(input, negative_slope=0.01, inplace=False):
    return F.leaky_relu(input, negative_slope=negative_slope, inplace=inplace)


def gelu(input, approximate=False):
    return F.gelu(input, approximate=approximate)


def sigmoid(input):
    return F.sigmoid(input)


def softmax(input, dim=-1):
    return F.softmax(input, dim=dim)


def layer_norm(input, normalized_shape, weight=None, bias=None, eps=1e-5):
    return F.layer_norm(input, normalized_shape, weight=weight, bias=bias, eps=eps)


def dropout(input, p=0.5, training=True, inplace=False):
    return F.dropout(input, p=p, training=training, inplace=inplace)


def embedding(input, weight, padding_idx=None):
    return F.embedding(input, weight, padding_idx=padding_idx)


def cross_entropy(input, target, reduction="mean"):
    return F.cross_entropy(input, target, reduction=reduction)


def conv2d(input, weight, bias=None, stride=1, padding=0, dilation=1, groups=1):
    return F.conv2d(input, weight, bias=bias, stride=stride, padding=padding, dilation=dilation, groups=groups)


def max_pool2d(input, kernel_size, stride=None, padding=0, dilation=1, ceil_mode=False, return_indices=False):
    return F.max_pool2d(
        input,
        kernel_size=kernel_size,
        stride=stride,
        padding=padding,
        dilation=dilation,
        ceil_mode=ceil_mode,
        return_indices=return_indices,
    )


def avg_pool2d(
    input,
    kernel_size,
    stride=None,
    padding=0,
    ceil_mode=False,
    count_include_pad=True,
    divisor_override=None,
):
    return F.avg_pool2d(
        input,
        kernel_size=kernel_size,
        stride=stride,
        padding=padding,
        ceil_mode=ceil_mode,
        count_include_pad=count_include_pad,
        divisor_override=divisor_override,
    )


def adaptive_avg_pool2d(input, output_size):
    return F.adaptive_avg_pool2d(input, output_size=output_size)


__all__ = [
    "linear",
    "relu",
    "leaky_relu",
    "gelu",
    "sigmoid",
    "softmax",
    "layer_norm",
    "dropout",
    "embedding",
    "cross_entropy",
    "conv2d",
    "max_pool2d",
    "avg_pool2d",
    "adaptive_avg_pool2d",
]
