"""
Tensor creation functions for NeurX.
Implements PyTorch-like tensor creation API.
"""
from __future__ import annotations

import numpy as np
from typing import Optional, Union, Tuple, List, TYPE_CHECKING

from neurx.core.neurx import Tensor

if TYPE_CHECKING:
    pass


def zeros(
    *shape: Union[int, Tuple[int, ...]],
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create a tensor filled with zeros.
    
    Args:
        *shape: Shape dimensions. Can be (3, 4) or *(3, 4) or shape_tuple
        dtype: Data type (default: np.float64)
        device: Device type ('cpu' or 'cuda')
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Zero tensor
        
    Examples:
        >>> zeros(3, 4)
        >>> zeros((3, 4))
        >>> zeros((2, 3, 4), dtype=np.float32)
    """
    from neurx.neurx import Tensor
    
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    elif len(shape) == 1 and not isinstance(shape[0], int):
        shape = tuple(shape[0])
    
    if dtype is None:
        dtype = np.float64
    
    data = np.zeros(shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def ones(
    *shape: Union[int, Tuple[int, ...]],
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create a tensor filled with ones.
    
    Args:
        *shape: Shape dimensions
        dtype: Data type (default: np.float64)
        device: Device type ('cpu' or 'cuda')
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Ones tensor
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    elif len(shape) == 1 and not isinstance(shape[0], int):
        shape = tuple(shape[0])
    
    if dtype is None:
        dtype = np.float64
    
    data = np.ones(shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def full(
    shape: Union[Tuple[int, ...], List[int]],
    fill_value: Union[int, float],
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create a tensor filled with specified value.
    
    Args:
        shape: Tensor shape
        fill_value: Value to fill
        dtype: Data type (default: np.float64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Filled tensor
    """
    if dtype is None:
        dtype = np.float64
    
    if isinstance(shape, int):
        shape = (shape,)
    
    data = np.full(shape, fill_value, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def zeros_like(
    tensor: "Tensor",
    dtype: Optional[np.dtype] = None,
    device: Optional[str] = None,
    requires_grad: bool = False
) -> "Tensor":
    """
    Create a zero tensor with same shape as input.
    
    Args:
        tensor: Input tensor
        dtype: Data type (default: same as input)
        device: Device type (default: same as input)
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Zero tensor with same shape
    """
    if dtype is None:
        dtype = tensor.dtype
    if device is None:
        device = tensor.device
    
    data = np.zeros(tensor.shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def ones_like(
    tensor: "Tensor",
    dtype: Optional[np.dtype] = None,
    device: Optional[str] = None,
    requires_grad: bool = False
) -> "Tensor":
    """
    Create a ones tensor with same shape as input.
    
    Args:
        tensor: Input tensor
        dtype: Data type (default: same as input)
        device: Device type (default: same as input)
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Ones tensor with same shape
    """
    if dtype is None:
        dtype = tensor.dtype
    if device is None:
        device = tensor.device
    
    data = np.ones(tensor.shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def full_like(
    tensor: "Tensor",
    fill_value: Union[int, float],
    dtype: Optional[np.dtype] = None,
    device: Optional[str] = None,
    requires_grad: bool = False
) -> "Tensor":
    """
    Create a tensor filled with value and same shape as input.
    
    Args:
        tensor: Input tensor
        fill_value: Value to fill
        dtype: Data type (default: same as input)
        device: Device type (default: same as input)
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Filled tensor with same shape
    """
    if dtype is None:
        dtype = tensor.dtype
    if device is None:
        device = tensor.device
    
    data = np.full(tensor.shape, fill_value, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def eye(
    n: int,
    m: Optional[int] = None,
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create an identity matrix.
    
    Args:
        n: Number of rows
        m: Number of columns (default: same as n)
        dtype: Data type (default: np.float64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Identity matrix
        
    Examples:
        >>> eye(3)  # 3x3 identity
        >>> eye(3, 4)  # 3x4 with 1s on diagonal
    """
    if m is None:
        m = n
    if dtype is None:
        dtype = np.float64
    
    data = np.eye(n, m, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def arange(
    start: Union[int, float],
    end: Optional[Union[int, float]] = None,
    step: Union[int, float] = 1,
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create evenly spaced values within interval.
    
    Args:
        start: Start value (or end if end is None)
        end: End value (exclusive)
        step: Spacing between values
        dtype: Data type (default: np.float64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Tensor with evenly spaced values
        
    Examples:
        >>> arange(5)  # [0, 1, 2, 3, 4]
        >>> arange(2, 5)  # [2, 3, 4]
        >>> arange(0, 1, 0.2)  # [0, 0.2, 0.4, 0.6, 0.8]
    """
    if end is None:
        end = start
        start = 0
    if dtype is None:
        dtype = np.float64
    
    data = np.arange(start, end, step, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def linspace(
    start: Union[int, float],
    end: Union[int, float],
    steps: int = 100,
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create linearly spaced values.
    
    Args:
        start: Start value
        end: End value
        steps: Number of samples (default: 100)
        dtype: Data type (default: np.float64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Tensor with linearly spaced values
        
    Examples:
        >>> linspace(0, 1, 5)  # [0, 0.25, 0.5, 0.75, 1]
    """
    if dtype is None:
        dtype = np.float64
    
    data = np.linspace(start, end, steps, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def logspace(
    start: Union[int, float],
    end: Union[int, float],
    steps: int = 50,
    base: Union[int, float] = 10.0,
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create logarithmically spaced values.
    
    Args:
        start: log_base(start)
        end: log_base(end)
        steps: Number of samples
        base: Logarithm base (default: 10)
        dtype: Data type (default: np.float64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Tensor with logarithmically spaced values
        
    Examples:
        >>> logspace(0, 2, 5)  # [1, 3.16, 10, 31.6, 100]
    """
    if dtype is None:
        dtype = np.float64
    
    data = np.logspace(start, end, steps, base=base, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def rand(
    *shape: Union[int, Tuple[int, ...]],
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create random tensor with values in [0, 1).
    
    Args:
        *shape: Shape dimensions
        dtype: Data type (default: np.float64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Random tensor
        
    Examples:
        >>> rand(3, 4)
        >>> rand((2, 3, 4))
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    elif len(shape) == 1 and not isinstance(shape[0], int):
        shape = tuple(shape[0])
    
    if dtype is None:
        dtype = np.float64
    
    data = np.random.rand(*shape).astype(dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def randn(
    *shape: Union[int, Tuple[int, ...]],
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create random tensor from standard normal distribution.
    
    Args:
        *shape: Shape dimensions
        dtype: Data type (default: np.float64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Random tensor from N(0, 1)
        
    Examples:
        >>> randn(3, 4)
        >>> randn((2, 3, 4))
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    elif len(shape) == 1 and not isinstance(shape[0], int):
        shape = tuple(shape[0])
    
    if dtype is None:
        dtype = np.float64
    
    data = np.random.randn(*shape).astype(dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def randint(
    low: int,
    high: int,
    shape: Union[Tuple[int, ...], List[int]],
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create random integer tensor.
    
    Args:
        low: Low bound (inclusive)
        high: High bound (exclusive)
        shape: Tensor shape
        dtype: Data type (default: np.int64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Random integer tensor
        
    Examples:
        >>> randint(0, 10, (3, 4))  # Random ints in [0, 10)
    """
    if dtype is None:
        dtype = np.int64
    
    if isinstance(shape, int):
        shape = (shape,)
    
    data = np.random.randint(low, high, shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def randperm(
    n: int,
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create random permutation of 0 to n-1.
    
    Args:
        n: Size of permutation
        dtype: Data type (default: np.int64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Random permutation tensor
        
    Examples:
        >>> randperm(10)  # Random permutation of [0-9]
    """
    if dtype is None:
        dtype = np.int64
    
    data = np.random.permutation(n).astype(dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def normal(
    mean: Union[int, float] = 0.0,
    std: Union[int, float] = 1.0,
    shape: Union[Tuple[int, ...], List[int], int] = (1,),
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create random tensor from normal distribution.
    
    Args:
        mean: Mean of distribution
        std: Standard deviation
        shape: Tensor shape
        dtype: Data type (default: np.float64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Random tensor from N(mean, std^2)
        
    Examples:
        >>> normal(0, 1, (3, 4))  # Standard normal
        >>> normal(5, 2, (100,))  # N(5, 4)
    """
    if dtype is None:
        dtype = np.float64
    
    if isinstance(shape, int):
        shape = (shape,)
    
    data = np.random.normal(mean, std, shape).astype(dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def uniform(
    low: Union[int, float] = 0.0,
    high: Union[int, float] = 1.0,
    shape: Union[Tuple[int, ...], List[int], int] = (1,),
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create random tensor from uniform distribution.
    
    Args:
        low: Low bound
        high: High bound
        shape: Tensor shape
        dtype: Data type (default: np.float64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Random tensor from U(low, high)
        
    Examples:
        >>> uniform(0, 1, (3, 4))
        >>> uniform(-1, 1, (100,))
    """
    if dtype is None:
        dtype = np.float64
    
    if isinstance(shape, int):
        shape = (shape,)
    
    data = np.random.uniform(low, high, shape).astype(dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def empty(
    *shape: Union[int, Tuple[int, ...]],
    dtype: Optional[np.dtype] = None,
    device: str = "cpu",
    requires_grad: bool = False
) -> "Tensor":
    """
    Create uninitialized tensor.
    
    Args:
        *shape: Shape dimensions
        dtype: Data type (default: np.float64)
        device: Device type
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Uninitialized tensor
        
    Note:
        Values are uninitialized and may contain arbitrary data.
    """
    if len(shape) == 1 and isinstance(shape[0], (tuple, list)):
        shape = tuple(shape[0])
    elif len(shape) == 1 and not isinstance(shape[0], int):
        shape = tuple(shape[0])
    
    if dtype is None:
        dtype = np.float64
    
    data = np.empty(shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)


def empty_like(
    tensor: "Tensor",
    dtype: Optional[np.dtype] = None,
    device: Optional[str] = None,
    requires_grad: bool = False
) -> "Tensor":
    """
    Create uninitialized tensor with same shape as input.
    
    Args:
        tensor: Input tensor
        dtype: Data type (default: same as input)
        device: Device type (default: same as input)
        requires_grad: Whether tensor requires gradients
        
    Returns:
        Uninitialized tensor with same shape
    """
    if dtype is None:
        dtype = tensor.dtype
    if device is None:
        device = tensor.device
    
    data = np.empty(tensor.shape, dtype=dtype)
    return Tensor(data, requires_grad=requires_grad, device=device)
