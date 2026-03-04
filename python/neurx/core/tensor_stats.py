"""
Statistical and sorting operations for NeurX Tensors.
Implements PyTorch-like statistics API.
"""
from __future__ import annotations

import numpy as np
from typing import Optional, Tuple, Union, TYPE_CHECKING

from neurx.core.neurx import Tensor, _to_numpy

if TYPE_CHECKING:
    pass


def sort(
    tensor: "Tensor",
    dim: int = -1,
    descending: bool = False
) -> Tuple["Tensor", "Tensor"]:
    """
    Sort tensor along dimension.
    
    Args:
        tensor: Input tensor
        dim: Dimension along which to sort
        descending: Sort in descending order
        
    Returns:
        Tuple of (sorted_values, sorted_indices)
        
    Examples:
        >>> x = Tensor([[3, 1, 2], [6, 4, 5]])
        >>> values, indices = sort(x, dim=1)
    """
    data = _to_numpy(tensor.data)
    
    # Normalize dimension
    dim = dim + len(data.shape) if dim < 0 else dim
    
    if descending:
        indices = np.argsort(-data, axis=dim)
    else:
        indices = np.argsort(data, axis=dim)
    
    sorted_data = np.take_along_axis(data, indices, axis=dim)
    
    sorted_tensor = Tensor(sorted_data, requires_grad=tensor.requires_grad, _children=(tensor,), _op="sort", device=tensor.device)
    indices_tensor = Tensor(indices.astype(np.int64, copy=False), requires_grad=False, device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            # Reverse the sorting for gradient
            grad = np.zeros_like(data, dtype=tensor.grad.dtype)
            np.put_along_axis(grad, indices, sorted_tensor.grad, axis=dim)
            tensor.grad += grad
    
    sorted_tensor._backward = _backward
    return sorted_tensor, indices_tensor


def argsort(
    tensor: "Tensor",
    dim: int = -1,
    descending: bool = False
) -> "Tensor":
    """
    Return indices that sort tensor.
    
    Args:
        tensor: Input tensor
        dim: Dimension along which to sort
        descending: Sort in descending order
        
    Returns:
        Indices tensor
        
    Examples:
        >>> x = Tensor([3, 1, 4, 1, 5])
        >>> argsort(x)  # [1, 3, 0, 2, 4]
    """
    data = _to_numpy(tensor.data)
    
    # Normalize dimension
    dim = dim + len(data.shape) if dim < 0 else dim
    
    if descending:
        indices = np.argsort(-data, axis=dim)
    else:
        indices = np.argsort(data, axis=dim)
    
    return Tensor(indices.astype(np.int64, copy=False), requires_grad=False, device=tensor.device)


def topk(
    tensor: "Tensor",
    k: int,
    dim: int = -1,
    largest: bool = True,
    sorted: bool = True
) -> Tuple["Tensor", "Tensor"]:
    """
    Return top k values and indices.
    
    Args:
        tensor: Input tensor
        k: Number of top elements
        dim: Dimension along which to get top k
        largest: Get largest or smallest k elements
        sorted: Return sorted or not
        
    Returns:
        Tuple of (top_values, top_indices)
        
    Examples:
        >>> x = Tensor([1, 3, 5, 2, 4])
        >>> values, indices = topk(x, 3)
    """
    data = _to_numpy(tensor.data)
    
    # Normalize dimension
    dim = dim + len(data.shape) if dim < 0 else dim
    
    if largest:
        if sorted:
            indices = np.argsort(-data, axis=dim)
        else:
            indices = np.argpartition(-data, k - 1, axis=dim)
    else:
        if sorted:
            indices = np.argsort(data, axis=dim)
        else:
            indices = np.argpartition(data, k - 1, axis=dim)

    # Keep only first k entries along requested dimension
    slices = [slice(None)] * len(data.shape)
    slices[dim] = slice(0, k)
    indices = indices[tuple(slices)]

    values = np.take_along_axis(data, indices, axis=dim)

    # Ensure sorted output within top-k subset when requested
    if sorted:
        order = np.argsort(-values if largest else values, axis=dim)
        values = np.take_along_axis(values, order, axis=dim)
        indices = np.take_along_axis(indices, order, axis=dim)
    
    values_tensor = Tensor(values, requires_grad=tensor.requires_grad, _children=(tensor,), _op="topk", device=tensor.device)
    indices_tensor = Tensor(indices.astype(np.int64, copy=False), requires_grad=False, device=tensor.device)
    
    return values_tensor, indices_tensor


def unique(
    tensor: "Tensor",
    sorted: bool = False,
    return_inverse: bool = False,
    return_counts: bool = False
):
    """
    Return unique elements.
    
    Args:
        tensor: Input tensor
        sorted: Sort the unique elements
        return_inverse: Return inverse indices
        return_counts: Return counts for each unique element
        
    Returns:
        Unique elements, and optionally inverse indices and counts
        
    Examples:
        >>> x = Tensor([1, 2, 1, 3, 2, 3])
        >>> unique(x)  # [1, 2, 3]
        >>> unique(x, return_counts=True)  # ([1, 2, 3], [2, 2, 2])
    """
    data = _to_numpy(tensor.data).flatten()
    
    result = np.unique(data, return_inverse=return_inverse, return_counts=return_counts)
    
    if return_inverse or return_counts:
        unique_vals = result[0]
        rest = result[1:]
        unique_tensor = Tensor(unique_vals, requires_grad=False, device=tensor.device)
        
        ret = [unique_tensor]
        for r in rest:
            ret.append(Tensor(np.asarray(r).astype(np.int64, copy=False), requires_grad=False, device=tensor.device))
        
        return tuple(ret) if len(ret) > 1 else ret[0]
    else:
        return Tensor(result, requires_grad=False, device=tensor.device)


def median(
    tensor: "Tensor",
    dim: Optional[int] = None,
    keepdim: bool = False
) -> Union["Tensor", Tuple["Tensor", "Tensor"]]:
    """
    Return median value(s).
    
    Args:
        tensor: Input tensor
        dim: Dimension along which to compute median
        keepdim: Keep the dimension
        
    Returns:
        Median value(s), and optionally indices
        
    Examples:
        >>> x = Tensor([1, 2, 3, 4, 5])
        >>> median(x)  # 3
        >>> x = Tensor([[1, 2, 3], [4, 5, 6]])
        >>> median(x, dim=1)
    """
    data = _to_numpy(tensor.data)
    
    if dim is None:
        median_val = np.median(data)
        return Tensor(median_val, requires_grad=tensor.requires_grad, device=tensor.device)
    else:
        # Normalize dimension
        dim = dim + len(data.shape) if dim < 0 else dim
        
        # Get median values and indices
        median_vals = np.median(data, axis=dim, keepdims=keepdim)
        
        # Find indices of median values
        if keepdim:
            median_indices = np.argmin(np.abs(data - np.expand_dims(median_vals, axis=dim)), axis=dim, keepdims=True)
        else:
            median_indices = np.argmin(np.abs(data - np.expand_dims(median_vals, axis=dim)), axis=dim)
        
        median_tensor = Tensor(median_vals, requires_grad=tensor.requires_grad, _children=(tensor,), _op="median", device=tensor.device)
        indices_tensor = Tensor(median_indices.astype(np.int64, copy=False), requires_grad=False, device=tensor.device)
        
        return median_tensor, indices_tensor


def mode(
    tensor: "Tensor",
    dim: Optional[int] = None,
    keepdim: bool = False
) -> Tuple["Tensor", "Tensor"]:
    """
    Return mode (most frequent value).
    
    Args:
        tensor: Input tensor
        dim: Dimension along which to compute mode
        keepdim: Keep the dimension
        
    Returns:
        Tuple of (mode_values, mode_indices)
        
    Examples:
        >>> x = Tensor([1, 2, 2, 3, 3, 3])
        >>> values, indices = mode(x)
    """
    data = _to_numpy(tensor.data)
    
    if dim is None:
        data_flat = data.flatten()
        values, counts = np.unique(data_flat, return_counts=True)
        mode_idx = np.argmax(counts)
        mode_val = values[mode_idx]
        
        return Tensor(mode_val, requires_grad=False, device=tensor.device)
    else:
        # Normalize dimension
        dim = dim + len(data.shape) if dim < 0 else dim
        
        # Get shape for result
        result_shape = list(data.shape)
        result_shape.pop(dim)
        
        mode_vals = np.zeros(result_shape)
        mode_indices = np.zeros(result_shape, dtype=np.int64)
        
        # Iterate over non-dim axes to compute mode along dim
        import itertools
        for idx in itertools.product(*[range(s) for i, s in enumerate(data.shape) if i != dim]):
            full_idx = list(idx)
            full_idx.insert(dim, slice(None))
            values = data[tuple(full_idx)]
            unique_vals, counts = np.unique(values, return_counts=True)
            max_idx = np.argmax(counts)
            
            result_idx = list(idx)
            mode_vals[tuple(result_idx)] = unique_vals[max_idx]
            mode_indices[tuple(result_idx)] = np.where(values == unique_vals[max_idx])[0][0]
        
        if keepdim:
            mode_vals = np.expand_dims(mode_vals, axis=dim)
            mode_indices = np.expand_dims(mode_indices, axis=dim)
        
        return (Tensor(mode_vals, requires_grad=False, device=tensor.device),
            Tensor(mode_indices.astype(np.int64, copy=False), requires_grad=False, device=tensor.device))


def quantile(
    tensor: "Tensor",
    q: Union[float, np.ndarray],
    dim: Optional[int] = None,
    keepdim: bool = False,
    interpolation: str = "linear"
) -> "Tensor":
    """
    Compute quantiles.
    
    Args:
        tensor: Input tensor
        q: Quantile value(s) in [0, 1]
        dim: Dimension along which to compute quantiles
        keepdim: Keep the dimension
        interpolation: Interpolation method ('linear', 'lower', 'higher', 'midpoint', 'nearest')
        
    Returns:
        Quantile tensor
        
    Examples:
        >>> x = Tensor([1, 2, 3, 4, 5])
        >>> quantile(x, 0.5)  # Median
        >>> quantile(x, [0.25, 0.75])  # Quartiles
    """
    data = _to_numpy(tensor.data)
    
    if dim is None:
        quantiles = np.quantile(data, q, interpolation=interpolation)
    else:
        dim = dim + len(data.shape) if dim < 0 else dim
        quantiles = np.quantile(data, q, axis=dim, keepdims=keepdim, interpolation=interpolation)
    
    return Tensor(quantiles, requires_grad=False, device=tensor.device)


def cumsum(
    tensor: "Tensor",
    dim: int = 0
) -> "Tensor":
    """
    Cumulative sum along dimension.
    
    Args:
        tensor: Input tensor
        dim: Dimension along which to compute cumulative sum
        
    Returns:
        Cumulative sum tensor
        
    Examples:
        >>> x = Tensor([1, 2, 3, 4, 5])
        >>> cumsum(x)  # [1, 3, 6, 10, 15]
    """
    data = _to_numpy(tensor.data)
    
    dim = dim + len(data.shape) if dim < 0 else dim
    
    out_data = np.cumsum(data, axis=dim)
    out = Tensor(out_data, requires_grad=tensor.requires_grad, _children=(tensor,), _op="cumsum", device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            # Reverse cumsum for gradient
            grad = np.cumsum(out.grad[..., ::-1], axis=dim)[..., ::-1]
            # Handle axis properly
            if dim == 0:
                grad = grad[..., ::-1].T.cumsum().T[..., ::-1]
            tensor.grad += grad
    
    out._backward = _backward
    return out


def cumprod(
    tensor: "Tensor",
    dim: int = 0
) -> "Tensor":
    """
    Cumulative product along dimension.
    
    Args:
        tensor: Input tensor
        dim: Dimension along which to compute cumulative product
        
    Returns:
        Cumulative product tensor
        
    Examples:
        >>> x = Tensor([1, 2, 3, 4])
        >>> cumprod(x)  # [1, 2, 6, 24]
    """
    data = _to_numpy(tensor.data)
    
    dim = dim + len(data.shape) if dim < 0 else dim
    
    out_data = np.cumprod(data, axis=dim)
    out = Tensor(out_data, requires_grad=tensor.requires_grad, _children=(tensor,), _op="cumprod", device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            # For cumprod gradient: grad[i] = (prod[i] / data[i]) * d_grad[i]
            with np.errstate(divide='ignore', invalid='ignore'):
                grad = out_data / np.maximum(data, 1e-12)
            grad = np.where(data == 0, 0, grad)
            grad = grad * out.grad
            tensor.grad += grad
    
    out._backward = _backward
    return out


def prod(
    tensor: "Tensor",
    dim: Optional[int] = None,
    keepdim: bool = False
) -> "Tensor":
    """
    Product of elements.
    
    Args:
        tensor: Input tensor
        dim: Dimension along which to compute product
        keepdim: Keep the dimension
        
    Returns:
        Product tensor
        
    Examples:
        >>> x = Tensor([1, 2, 3, 4])
        >>> prod(x)  # 24
    """
    data = _to_numpy(tensor.data)
    
    if dim is None:
        out_data = np.prod(data)
    else:
        dim = dim + len(data.shape) if dim < 0 else dim
        out_data = np.prod(data, axis=dim, keepdims=keepdim)
    
    out = Tensor(out_data, requires_grad=tensor.requires_grad, _children=(tensor,), _op="prod", device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            if dim is None:
                grad = np.prod(data) / np.maximum(data, 1e-12)
                grad = np.where(data == 0, 0, grad)
                tensor.grad += grad * out.grad
            else:
                grad = out_data / np.maximum(data, 1e-12)
                grad = np.where(data == 0, 0, grad)
                if not keepdim:
                    grad = np.expand_dims(grad, axis=dim)
                    out_grad = np.expand_dims(out.grad, axis=dim)
                else:
                    out_grad = out.grad
                tensor.grad += grad * out_grad
    
    out._backward = _backward
    return out
