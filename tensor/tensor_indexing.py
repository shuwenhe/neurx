"""
Advanced indexing and selection operations for NeurX Tensors.
Implements PyTorch-like indexing API.
"""
from __future__ import annotations

import numpy as np
from typing import Optional, Union, Tuple, List, Dict, TYPE_CHECKING

from .neurx import Tensor, _to_numpy

if TYPE_CHECKING:
    pass


def index_select(
    tensor: "Tensor",
    dim: int,
    indices: Union["Tensor", np.ndarray]
) -> "Tensor":
    """
    Select values along dimension by indices.
    
    Args:
        tensor: Input tensor
        dim: Dimension along which to select
        indices: Indices to select
        
    Returns:
        Selected tensor
        
    Examples:
        >>> x = Tensor([[1, 2, 3], [4, 5, 6]])
        >>> idx = Tensor([0, 2])
        >>> index_select(x, 1, idx)  # Select columns 0 and 2
    """
    indices_np = (indices.to_numpy() if isinstance(indices, Tensor) else np.asarray(indices)).astype(np.int64, copy=False)
    data = _to_numpy(tensor.data)
    
    # Normalize dimension
    dim = dim + len(data.shape) if dim < 0 else dim
    
    out_data = np.take(data, indices_np, axis=dim)
    out = Tensor(out_data, requires_grad=tensor.requires_grad, _children=(tensor,), _op="index_select", device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            grad = np.zeros_like(data, dtype=tensor.grad.dtype)
            np.add.at(grad, tuple(np.arange(len(indices_np)) if d == dim else slice(None) for d in range(len(data.shape))), out.grad)
            tensor.grad += grad
    
    out._backward = _backward
    return out


def masked_select(
    tensor: "Tensor",
    mask: Union["Tensor", np.ndarray]
) -> "Tensor":
    """
    Select elements where mask is True.
    
    Args:
        tensor: Input tensor
        mask: Boolean mask
        
    Returns:
        1D tensor of selected elements
        
    Examples:
        >>> x = Tensor([1, 2, 3, 4, 5])
        >>> mask = Tensor([True, False, True, False, True])
        >>> masked_select(x, mask)  # [1, 3, 5]
    """
    mask_np = (mask.to_numpy() if isinstance(mask, Tensor) else np.asarray(mask)).astype(bool, copy=False)
    data = _to_numpy(tensor.data)
    
    out_data = data[mask_np]
    out = Tensor(out_data, requires_grad=tensor.requires_grad, _children=(tensor,), _op="masked_select", device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            grad = np.zeros_like(data, dtype=tensor.grad.dtype)
            grad[mask_np] = out.grad
            tensor.grad += grad
    
    out._backward = _backward
    return out


def masked_fill(
    tensor: "Tensor",
    mask: Union["Tensor", np.ndarray],
    value: Union[int, float]
) -> "Tensor":
    """
    Fill masked positions with value.
    
    Args:
        tensor: Input tensor
        mask: Boolean mask
        value: Value to fill
        
    Returns:
        Filled tensor
        
    Examples:
        >>> x = Tensor([1, 2, 3, 4, 5])
        >>> mask = Tensor([True, False, True, False, True])
        >>> masked_fill(x, mask, 0)  # [0, 2, 0, 4, 0]
    """
    mask_np = (mask.to_numpy() if isinstance(mask, Tensor) else np.asarray(mask)).astype(bool, copy=False)
    data = _to_numpy(tensor.data).copy()
    
    out_data = data.copy()
    out_data[mask_np] = value
    out = Tensor(out_data, requires_grad=tensor.requires_grad, _children=(tensor,), _op="masked_fill", device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            grad = out.grad.copy()
            grad[mask_np] = 0  # Zero gradient for filled positions
            tensor.grad += grad
    
    out._backward = _backward
    return out


def masked_scatter(
    tensor: "Tensor",
    mask: Union["Tensor", np.ndarray],
    source: Tensor
) -> "Tensor":
    """
    Scatter elements from source where mask is True.
    
    Args:
        tensor: Input tensor
        mask: Boolean mask
        source: Source tensor to scatter
        
    Returns:
        Scattered tensor
        
    Examples:
        >>> x = Tensor([1, 2, 3, 4, 5])
        >>> mask = Tensor([True, False, True, False, True])
        >>> source = Tensor([10, 20, 30])
        >>> masked_scatter(x, mask, source)  # [10, 2, 20, 4, 30]
    """
    mask_np = (mask.to_numpy() if isinstance(mask, Tensor) else np.asarray(mask)).astype(bool, copy=False)
    data = _to_numpy(tensor.data).copy()
    source_np = source.to_numpy() if isinstance(source, Tensor) else np.asarray(source)
    
    out_data = data.copy()
    out_data[mask_np] = source_np.flatten()[:mask_np.sum()]
    out = Tensor(out_data, requires_grad=tensor.requires_grad or source.requires_grad, 
                 _children=(tensor, source), _op="masked_scatter", device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            grad = out.grad.copy()
            grad[mask_np] = 0
            tensor.grad += grad
        if source.requires_grad:
            source.grad += out.grad[mask_np].flatten()
    
    out._backward = _backward
    return out


def where(
    condition: Union["Tensor", np.ndarray],
    x: Union["Tensor", np.ndarray],
    y: Union["Tensor", np.ndarray]
) -> "Tensor":
    """
    Element-wise selection based on condition.
    
    Args:
        condition: Boolean condition
        x: Values where condition is True
        y: Values where condition is False
        
    Returns:
        Selected values
        
    Examples:
        >>> cond = Tensor([True, False, True])
        >>> x = Tensor([1, 2, 3])
        >>> y = Tensor([10, 20, 30])
        >>> where(cond, x, y)  # [1, 20, 3]
    """
    cond_np = (condition.to_numpy() if isinstance(condition, Tensor) else np.asarray(condition)).astype(bool, copy=False)
    x_np = x.to_numpy() if isinstance(x, Tensor) else np.asarray(x)
    y_np = y.to_numpy() if isinstance(y, Tensor) else np.asarray(y)
    
    out_data = np.where(cond_np, x_np, y_np)
    
    requires_grad = (isinstance(x, Tensor) and x.requires_grad) or (isinstance(y, Tensor) and y.requires_grad)
    children = tuple(t for t in [x, y] if isinstance(t, Tensor))
    
    out = Tensor(out_data, requires_grad=requires_grad, _children=children, _op="where", device=x.device if isinstance(x, Tensor) else y.device)
    
    def _backward():
        if isinstance(x, Tensor) and x.requires_grad:
            x.grad += np.where(cond_np, out.grad, 0)
        if isinstance(y, Tensor) and y.requires_grad:
            y.grad += np.where(cond_np, 0, out.grad)
    
    out._backward = _backward
    return out


def nonzero(tensor: "Tensor", as_tuple: bool = False) -> Union[Tensor, Tuple["Tensor", ...]]:
    """
    Return indices of non-zero elements.
    
    Args:
        tensor: Input tensor
        as_tuple: Return as tuple of tensors per dimension
        
    Returns:
        Indices of non-zero elements
        
    Examples:
        >>> x = Tensor([0, 1, 2, 0, 3])
        >>> nonzero(x)  # [[1], [2], [4]]
    """
    data = _to_numpy(tensor.data)
    indices = np.argwhere(data != 0)
    
    if as_tuple:
        return tuple(Tensor(indices[:, i], requires_grad=False, device=tensor.device) for i in range(indices.shape[1]))
    else:
        return Tensor(indices.astype(np.int64, copy=False), requires_grad=False, device=tensor.device)


def cat(
    tensors: List["Tensor"],
    dim: int = 0
) -> "Tensor":
    """
    Concatenate tensors along dimension.
    
    Args:
        tensors: List of tensors to concatenate
        dim: Dimension along which to concatenate
        
    Returns:
        Concatenated tensor
        
    Examples:
        >>> x = Tensor([[1, 2], [3, 4]])
        >>> y = Tensor([[5, 6]])
        >>> cat([x, y], dim=0)  # Shape: (3, 2)
    """
    data_list = [t.to_numpy() if isinstance(t, Tensor) else np.asarray(t) for t in tensors]
    out_data = np.concatenate(data_list, axis=dim)
    
    requires_grad = any(isinstance(t, Tensor) and t.requires_grad for t in tensors)
    tensor_children = tuple(t for t in tensors if isinstance(t, Tensor))
    
    out = Tensor(out_data, requires_grad=requires_grad, _children=tensor_children, _op="cat", 
                 device=next((t.device for t in tensors if isinstance(t, Tensor)), "cpu"))
    
    def _backward():
        offset = 0
        for t in tensors:
            if isinstance(t, Tensor) and t.requires_grad:
                size = t.shape[dim]
                if dim == 0:
                    grad_slice = out.grad[offset:offset+size]
                else:
                    # Handle other dimensions
                    slices = [slice(None)] * len(out.grad.shape)
                    slices[dim] = slice(offset, offset+size)
                    grad_slice = out.grad[tuple(slices)]
                t.grad += grad_slice
            if isinstance(t, Tensor):
                offset += t.shape[dim]
    
    out._backward = _backward
    return out


def split(
    tensor: "Tensor",
    split_size_or_sections: Union[int, List[int]],
    dim: int = 0
) -> List["Tensor"]:
    """
    Split tensor along dimension.
    
    Args:
        tensor: Input tensor
        split_size_or_sections: Size of each chunk or list of chunk sizes
        dim: Dimension along which to split
        
    Returns:
        List of split tensors
        
    Examples:
        >>> x = Tensor([[1, 2, 3, 4], [5, 6, 7, 8]])
        >>> split(x, 2, dim=1)  # Split into 2-sized chunks along dim 1
    """
    data = _to_numpy(tensor.data)
    
    if isinstance(split_size_or_sections, int):
        # Split by size
        chunks = []
        offset = 0
        while offset < data.shape[dim]:
            size = min(split_size_or_sections, data.shape[dim] - offset)
            if dim == 0:
                chunks.append(data[offset:offset+size])
            else:
                slices = [slice(None)] * len(data.shape)
                slices[dim] = slice(offset, offset+size)
                chunks.append(data[tuple(slices)])
            offset += size
    else:
        # Split by sections
        chunks = np.split(data, np.cumsum(split_size_or_sections)[:-1], axis=dim)
    
    return [Tensor(chunk, requires_grad=tensor.requires_grad, _children=(tensor,), _op="split", device=tensor.device) 
            for chunk in chunks]


def chunk(
    tensor: "Tensor",
    chunks: int,
    dim: int = 0
) -> List["Tensor"]:
    """
    Chunk tensor into chunks.
    
    Args:
        tensor: Input tensor
        chunks: Number of chunks
        dim: Dimension along which to chunk
        
    Returns:
        List of chunk tensors
        
    Examples:
        >>> x = Tensor([[1, 2, 3, 4], [5, 6, 7, 8]])
        >>> chunk(x, 2, dim=1)  # Split into 2 chunks along dim 1
    """
    data = _to_numpy(tensor.data)
    chunk_list = np.array_split(data, chunks, axis=dim)
    
    return [Tensor(c, requires_grad=tensor.requires_grad, _children=(tensor,), _op="chunk", device=tensor.device) 
            for c in chunk_list]


def stack(
    tensors: List["Tensor"],
    dim: int = 0
) -> "Tensor":
    """
    Stack tensors along new dimension.
    
    Args:
        tensors: List of tensors to stack
        dim: Dimension along which to stack
        
    Returns:
        Stacked tensor
        
    Examples:
        >>> x = Tensor([1, 2, 3])
        >>> y = Tensor([4, 5, 6])
        >>> stack([x, y], dim=0)  # Shape: (2, 3)
    """
    data_list = [t.to_numpy() if isinstance(t, Tensor) else np.asarray(t) for t in tensors]
    out_data = np.stack(data_list, axis=dim)
    
    requires_grad = any(isinstance(t, Tensor) and t.requires_grad for t in tensors)
    tensor_children = tuple(t for t in tensors if isinstance(t, Tensor))
    
    out = Tensor(out_data, requires_grad=requires_grad, _children=tensor_children, _op="stack",
                 device=next((t.device for t in tensors if isinstance(t, Tensor)), "cpu"))
    
    def _backward():
        indices = [None] * len(out.grad.shape)
        for i, t in enumerate(tensors):
            if isinstance(t, Tensor) and t.requires_grad:
                indices[dim] = i
                t.grad += out.grad[tuple(indices)]
    
    out._backward = _backward
    return out


def repeat_interleave(
    tensor: "Tensor",
    repeats: int,
    dim: Optional[int] = None
) -> "Tensor":
    """
    Repeat elements of tensor.
    
    Args:
        tensor: Input tensor
        repeats: Number of times to repeat
        dim: Dimension along which to repeat (None means flatten)
        
    Returns:
        Repeated tensor
        
    Examples:
        >>> x = Tensor([1, 2, 3])
        >>> repeat_interleave(x, 2)  # [1, 1, 2, 2, 3, 3]
    """
    data = _to_numpy(tensor.data)
    
    if dim is None:
        out_data = np.repeat(data.flatten(), repeats)
    else:
        out_data = np.repeat(data, repeats, axis=dim)
    
    out = Tensor(out_data, requires_grad=tensor.requires_grad, _children=(tensor,), _op="repeat_interleave", device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            if dim is None:
                grad = out.grad.reshape(-1, repeats).sum(axis=1)
                tensor.grad += grad.reshape(tensor.shape)
            else:
                # Sum along repeated elements
                slices = [slice(None)] * len(out.grad.shape)
                grad = out.grad
                for i in range(repeats-1):
                    slices[dim] = slice(i, None, repeats)
                    prev_slices = [slice(None)] * len(out.grad.shape)
                    prev_slices[dim] = slice(0, None, repeats)
                    grad[tuple(prev_slices)] += out.grad[tuple(slices)]
                slices[dim] = slice(0, None, repeats)
                tensor.grad += grad[tuple(slices)]
    
    out._backward = _backward
    return out
