"""
Neural Network Activation Functions

Provides both functional and module-based implementations of common activation functions.
"""

import numpy as np
from neurx.neurx import Tensor


# ============================================================================
# Functional Activation Functions
# ============================================================================

def relu(x):
    """
    ReLU (Rectified Linear Unit) activation
    
    Formula: f(x) = max(0, x)
    
    Args:
        x: Input array or neurx
        
    Returns:
        array: Output with ReLU applied
    """
    x = np.asarray(x)
    return np.maximum(0, x)


def leaky_relu(x, negative_slope=0.01):
    """
    Leaky ReLU activation
    
    Formula: f(x) = max(negative_slope * x, x)
    
    Args:
        x: Input array or neurx
        negative_slope: Slope for negative values (default 0.01)
        
    Returns:
        array: Output with LeakyReLU applied
    """
    x = np.asarray(x)
    return np.where(x > 0, x, negative_slope * x)


def elu(x, alpha=1.0):
    """
    ELU (Exponential Linear Unit) activation
    
    Formula: f(x) = x if x > 0 else alpha * (exp(x) - 1)
    
    Args:
        x: Input array or neurx
        alpha: Scale parameter (default 1.0)
        
    Returns:
        array: Output with ELU applied
    """
    x = np.asarray(x)
    return np.where(x > 0, x, alpha * (np.exp(x) - 1))


def selu(x):
    """
    SELU (Scaled ELU) activation - Self-Normalizing Neural Networks
    
    Formula: f(x) = λ * (x if x > 0 else α * (exp(x) - 1))
    where λ ≈ 1.0507 and α ≈ 1.6733
    
    Args:
        x: Input array or neurx
        
    Returns:
        array: Output with SELU applied
    """
    alpha = 1.6732632423543772848170429916717
    scale = 1.0507009873554804934193349852946
    x = np.asarray(x)
    return scale * np.where(x > 0, x, alpha * (np.exp(x) - 1))


def sigmoid(x):
    """
    Sigmoid activation function
    
    Formula: f(x) = 1 / (1 + exp(-x))
    
    Args:
        x: Input array or neurx
        
    Returns:
        array: Output with sigmoid applied (values in [0, 1])
    """
    x = np.asarray(x)
    out = np.empty_like(x, dtype=np.result_type(x, np.float64))
    pos = x >= 0
    neg = ~pos

    out[pos] = 1.0 / (1.0 + np.exp(-x[pos]))
    exp_x = np.exp(x[neg])
    out[neg] = exp_x / (1.0 + exp_x)
    return out


def tanh(x):
    """
    Tanh activation function
    
    Formula: f(x) = (exp(x) - exp(-x)) / (exp(x) + exp(-x))
    
    Args:
        x: Input array or neurx
        
    Returns:
        array: Output with tanh applied (values in [-1, 1])
    """
    x = np.asarray(x)
    return np.tanh(x)


def softmax(x, axis=-1):
    """
    Softmax activation function
    
    Formula: f(x_i) = exp(x_i) / sum(exp(x_j))
    
    Args:
        x: Input array or neurx
        axis: Axis along which to apply softmax
        
    Returns:
        array: Output with softmax applied (sums to 1 along axis)
    """
    x = np.asarray(x)
    # Numerical stability: subtract max
    x_shifted = x - np.max(x, axis=axis, keepdims=True)
    exp_x = np.exp(x_shifted)
    return exp_x / np.sum(exp_x, axis=axis, keepdims=True)


def log_softmax(x, axis=-1):
    """
    Log-Softmax activation function
    
    Formula: f(x_i) = log(exp(x_i) / sum(exp(x_j)))
                    = x_i - log(sum(exp(x_j)))
    
    Args:
        x: Input array or neurx
        axis: Axis along which to apply log-softmax
        
    Returns:
        array: Output with log-softmax applied
    """
    x = np.asarray(x)
    # Numerical stability: subtract max
    x_shifted = x - np.max(x, axis=axis, keepdims=True)
    return x_shifted - np.log(np.sum(np.exp(x_shifted), axis=axis, keepdims=True))


def softplus(x, beta=1.0):
    """
    Softplus activation function
    
    Formula: f(x) = (1 / beta) * log(1 + exp(beta * x))
    
    Args:
        x: Input array or neurx
        beta: Smoothness parameter (default 1.0)
        
    Returns:
        array: Output with softplus applied
    """
    x = np.asarray(x)
    # Numerical stability
    return np.where(
        x > 20,  # For large positive values, log(exp(bx)) ≈ bx
        x,
        (1 / beta) * np.log(1 + np.exp(beta * x))
    )


def softsign(x):
    """
    Softsign activation function
    
    Formula: f(x) = x / (1 + |x|)
    
    Args:
        x: Input array or neurx
        
    Returns:
        array: Output with softsign applied
    """
    x = np.asarray(x)
    return x / (1 + np.abs(x))


def swish(x, beta=1.0):
    """
    Swish activation function (SiLU variant)
    
    Formula: f(x) = x * sigmoid(beta * x)
    
    Args:
        x: Input array or neurx
        beta: Scale parameter (default 1.0)
        
    Returns:
        array: Output with swish applied
    """
    x = np.asarray(x)
    return x * sigmoid(beta * x)


def mish(x):
    """
    Mish activation function
    
    Formula: f(x) = x * tanh(softplus(x))
    
    Args:
        x: Input array or neurx
        
    Returns:
        array: Output with mish applied
    """
    x = np.asarray(x)
    return x * tanh(softplus(x))


def gelu(x, approximate=False):
    """
    GELU (Gaussian Error Linear Unit) activation
    
    Args:
        x: Input array or neurx
        approximate: If True, use approximation for faster computation
        
    Returns:
        array: Output with GELU applied
    """
    x = np.asarray(x)
    
    if approximate:
        # Approximation: 0.5 * x * (1 + tanh(sqrt(2/π) * (x + 0.044715 * x^3)))
        sqrt_2_over_pi = np.sqrt(2.0 / np.pi)
        return 0.5 * x * (1 + tanh(sqrt_2_over_pi * (x + 0.044715 * np.power(x, 3))))
    else:
        # Exact: 0.5 * x * (1 + erf(x / sqrt(2)))
        from scipy.special import erf
        return 0.5 * x * (1 + erf(x / np.sqrt(2)))


def hardshrink(x, lambd=0.5):
    """
    Hard Shrink activation
    
    Formula: f(x) = x if |x| > λ else 0
    
    Args:
        x: Input array or neurx
        lambd: Threshold parameter (default 0.5)
        
    Returns:
        array: Output with hard shrink applied
    """
    x = np.asarray(x)
    return np.where(np.abs(x) > lambd, x, 0)


def softshrink(x, lambd=0.5):
    """
    Soft Shrink activation
    
    Formula: f(x) = x - λ if x > λ, x + λ if x < -λ, 0 else
    
    Args:
        x: Input array or neurx
        lambd: Threshold parameter (default 0.5)
        
    Returns:
        array: Output with soft shrink applied
    """
    x = np.asarray(x)
    return np.where(
        x > lambd,
        x - lambd,
        np.where(x < -lambd, x + lambd, 0)
    )


def hardtanh(x, min_val=-1.0, max_val=1.0):
    """
    Hard Tanh activation
    
    Formula: f(x) = min_val if x < min_val, max_val if x > max_val, x else
    
    Args:
        x: Input array or neurx
        min_val: Minimum value (default -1.0)
        max_val: Maximum value (default 1.0)
        
    Returns:
        array: Output with hard tanh applied
    """
    x = np.asarray(x)
    return np.clip(x, min_val, max_val)


def threshold(x, threshold, value):
    """
    Threshold activation
    
    Formula: f(x) = x if x > threshold else value
    
    Args:
        x: Input array or neurx
        threshold: Threshold value
        value: Value to use when x <= threshold
        
    Returns:
        array: Output with threshold applied
    """
    x = np.asarray(x)
    return np.where(x > threshold, x, value)


def glu(x, axis=-1):
    """
    Gated Linear Unit activation
    
    Args:
        x: Input array or neurx (size of last dimension must be even)
        axis: Axis to split for gating
        
    Returns:
        array: Output with GLU applied
    """
    x = np.asarray(x)
    # Split input in half along the specified axis
    x_a, x_b = np.split(x, 2, axis=axis)
    return x_a * sigmoid(x_b)


def prelu(x, weight):
    """
    Parametric ReLU activation
    
    Formula: f(x) = max(weight * x, x)
    
    Args:
        x: Input array or neurx
        weight: Learnable weight parameter for negative values
        
    Returns:
        array: Output with PReLU applied
    """
    x = np.asarray(x)
    weight = np.asarray(weight)
    return np.where(x > 0, x, weight * x)


def rrelu(x, lower=0.125, upper=0.333, training=True):
    """
    Randomized ReLU (Randomized Leaky ReLU)
    
    Args:
        x: Input array or neurx
        lower: Lower bound for random slope (default 0.125)
        upper: Upper bound for random slope (default 0.333)
        training: If True, use random slopes; if False, use mean slope
        
    Returns:
        array: Output with RReLU applied
    """
    x = np.asarray(x)
    
    if training:
        # Random slope during training
        slope = np.random.uniform(lower, upper)
    else:
        # Fixed slope during inference (mean of range)
        slope = (lower + upper) / 2
    
    return np.where(x > 0, x, slope * x)


# ============================================================================
# Activation Module Classes
# ============================================================================

class ReLU:
    """ReLU activation module"""
    
    def __init__(self, inplace=False):
        self.inplace = inplace
    
    def forward(self, x):
        # Handle Tensor inputs properly
        if isinstance(x, Tensor):
            # Apply ReLU operation on Tensor
            out_data = np.maximum(0, x.data)
            out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="relu")
            
            def _backward():
                if x.requires_grad:
                    # Gradient of ReLU: 1 where x > 0, 0 otherwise
                    grad_mask = (x.data > 0).astype(x.data.dtype)
                    x.grad += out.grad * grad_mask
            
            out._backward = _backward
            return out
        else:
            return relu(x)
    
    def __call__(self, x):
        return self.forward(x)


class LeakyReLU:
    """Leaky ReLU activation module"""
    
    def __init__(self, negative_slope=0.01, inplace=False):
        self.negative_slope = negative_slope
        self.inplace = inplace
    
    def forward(self, x):
        if isinstance(x, Tensor):
            out_data = np.where(x.data > 0, x.data, self.negative_slope * x.data)
            out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="leaky_relu")
            
            def _backward():
                if x.requires_grad:
                    grad_mask = np.where(x.data > 0, 1.0, self.negative_slope).astype(x.data.dtype)
                    x.grad += out.grad * grad_mask
            
            out._backward = _backward
            return out
        else:
            return leaky_relu(x, self.negative_slope)
    
    def __call__(self, x):
        return self.forward(x)


class ELU:
    """ELU activation module"""
    
    def __init__(self, alpha=1.0, inplace=False):
        self.alpha = alpha
        self.inplace = inplace
    
    def forward(self, x):
        if isinstance(x, Tensor):
            out_data = np.where(x.data > 0, x.data, self.alpha * (np.exp(x.data) - 1))
            out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="elu")
            
            def _backward():
                if x.requires_grad:
                    grad_mask = np.where(x.data > 0, 1.0, self.alpha * np.exp(x.data)).astype(x.data.dtype)
                    x.grad += out.grad * grad_mask
            
            out._backward = _backward
            return out
        else:
            return elu(x, self.alpha)
    
    def __call__(self, x):
        return self.forward(x)


class SELU:
    """SELU activation module"""
    
    def __init__(self, inplace=False):
        self.inplace = inplace
        self.alpha = 1.6732632423543772848170429916717
        self.scale = 1.0507009873554804934193349852946
    
    def forward(self, x):
        if isinstance(x, Tensor):
            raw_out = np.where(x.data > 0, x.data, self.alpha * (np.exp(x.data) - 1))
            out_data = self.scale * raw_out
            out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="selu")
            
            def _backward():
                if x.requires_grad:
                    grad_mask = np.where(x.data > 0, 1.0, self.alpha * np.exp(x.data)).astype(x.data.dtype)
                    x.grad += out.grad * self.scale * grad_mask
            
            out._backward = _backward
            return out
        else:
            return selu(x)
    
    def __call__(self, x):
        return self.forward(x)


class Sigmoid:
    """Sigmoid activation module"""
    
    def forward(self, x):
        if isinstance(x, Tensor):
            # Numerically stable sigmoid
            out_data = np.empty_like(x.data, dtype=np.result_type(x.data, np.float64))
            pos = x.data >= 0
            neg = ~pos
            out_data[pos] = 1.0 / (1.0 + np.exp(-x.data[pos]))
            out_data[neg] = np.exp(x.data[neg]) / (1.0 + np.exp(x.data[neg]))
            out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="sigmoid")
            
            def _backward():
                if x.requires_grad:
                    grad_mask = out_data * (1.0 - out_data)
                    x.grad += out.grad * grad_mask
            
            out._backward = _backward
            return out
        else:
            return sigmoid(x)
    
    def __call__(self, x):
        return self.forward(x)


class Tanh:
    """Tanh activation module"""
    
    def forward(self, x):
        if isinstance(x, Tensor):
            out_data = np.tanh(x.data)
            out = Tensor(out_data, requires_grad=x.requires_grad, _children=(x,), _op="tanh")
            
            def _backward():
                if x.requires_grad:
                    grad_mask = 1.0 - out_data ** 2
                    x.grad += out.grad * grad_mask
            
            out._backward = _backward
            return out
        else:
            return tanh(x)
    
    def __call__(self, x):
        return self.forward(x)


class Softmax:
    """Softmax activation module"""
    
    def __init__(self, axis=-1):
        self.axis = axis
    
    def forward(self, x):
        return softmax(x, self.axis)
    
    def __call__(self, x):
        return self.forward(x)


class LogSoftmax:
    """Log-Softmax activation module"""
    
    def __init__(self, axis=-1):
        self.axis = axis
    
    def forward(self, x):
        return log_softmax(x, self.axis)
    
    def __call__(self, x):
        return self.forward(x)


class Softplus:
    """Softplus activation module"""
    
    def __init__(self, beta=1.0):
        self.beta = beta
    
    def forward(self, x):
        return softplus(x, self.beta)
    
    def __call__(self, x):
        return self.forward(x)


class Softsign:
    """Softsign activation module"""
    
    def forward(self, x):
        return softsign(x)
    
    def __call__(self, x):
        return self.forward(x)


class Swish:
    """Swish activation module"""
    
    def __init__(self, beta=1.0):
        self.beta = beta
    
    def forward(self, x):
        return swish(x, self.beta)
    
    def __call__(self, x):
        return self.forward(x)


class Mish:
    """Mish activation module"""
    
    def forward(self, x):
        return mish(x)
    
    def __call__(self, x):
        return self.forward(x)


class GELU:
    """GELU activation module"""
    
    def __init__(self, approximate=False):
        self.approximate = approximate
    
    def forward(self, x):
        return gelu(x, self.approximate)
    
    def __call__(self, x):
        return self.forward(x)


class HardShrink:
    """Hard Shrink activation module"""
    
    def __init__(self, lambd=0.5):
        self.lambd = lambd
    
    def forward(self, x):
        return hardshrink(x, self.lambd)
    
    def __call__(self, x):
        return self.forward(x)


class SoftShrink:
    """Soft Shrink activation module"""
    
    def __init__(self, lambd=0.5):
        self.lambd = lambd
    
    def forward(self, x):
        return softshrink(x, self.lambd)
    
    def __call__(self, x):
        return self.forward(x)


class HardTanh:
    """Hard Tanh activation module"""
    
    def __init__(self, min_val=-1.0, max_val=1.0, inplace=False):
        self.min_val = min_val
        self.max_val = max_val
        self.inplace = inplace
    
    def forward(self, x):
        return hardtanh(x, self.min_val, self.max_val)
    
    def __call__(self, x):
        return self.forward(x)


class Threshold:
    """Threshold activation module"""
    
    def __init__(self, threshold, value):
        self.threshold = threshold
        self.value = value
    
    def forward(self, x):
        return threshold(x, self.threshold, self.value)
    
    def __call__(self, x):
        return self.forward(x)


class GLU:
    """Gated Linear Unit activation module"""
    
    def __init__(self, axis=-1):
        self.axis = axis
    
    def forward(self, x):
        return glu(x, self.axis)
    
    def __call__(self, x):
        return self.forward(x)


class PReLU:
    """Parametric ReLU activation module"""
    
    def __init__(self, weight=None):
        self.weight = weight if weight is not None else 0.01
    
    def forward(self, x):
        return prelu(x, self.weight)
    
    def __call__(self, x):
        return self.forward(x)


class RReLU:
    """Randomized ReLU activation module"""
    
    def __init__(self, lower=0.125, upper=0.333):
        self.lower = lower
        self.upper = upper
        self.training = True
    
    def train(self):
        self.training = True
        return self
    
    def eval(self):
        self.training = False
        return self
    
    def forward(self, x):
        return rrelu(x, self.lower, self.upper, self.training)
    
    def __call__(self, x):
        return self.forward(x)


__all__ = [
    # Functional activations
    'relu', 'leaky_relu', 'elu', 'selu', 'sigmoid', 'tanh',
    'softmax', 'log_softmax', 'softplus', 'softsign', 'swish', 'mish',
    'gelu', 'hardshrink', 'softshrink', 'hardtanh', 'threshold', 'glu',
    'prelu', 'rrelu',
    # Module classes
    'ReLU', 'LeakyReLU', 'ELU', 'SELU', 'Sigmoid', 'Tanh',
    'Softmax', 'LogSoftmax', 'Softplus', 'Softsign', 'Swish', 'Mish',
    'GELU', 'HardShrink', 'SoftShrink', 'HardTanh', 'Threshold', 'GLU',
    'PReLU', 'RReLU',
]
