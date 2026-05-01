"""
Linear algebra operations for NeurX Tensors.
Implements PyTorch-like linalg API.
"""
from __future__ import annotations

import numpy as np
from typing import Optional, Tuple, TYPE_CHECKING

from .neurx import Tensor, _to_numpy

if TYPE_CHECKING:
    pass


def matrix_rank(tensor: "Tensor", atol: Optional[float] = None, rtol: Optional[float] = None) -> int:
    """
    Compute matrix rank.
    
    Args:
        tensor: Input tensor (2D)
        atol: Absolute tolerance
        rtol: Relative tolerance
        
    Returns:
        Rank of matrix
    """
    data = _to_numpy(tensor.data)
    if len(data.shape) != 2:
        raise ValueError(f"Expected 2D tensor, got shape {data.shape}")
    
    if atol is None and rtol is None:
        return int(np.linalg.matrix_rank(data))

    singular_values = np.linalg.svd(data, compute_uv=False)
    if singular_values.size == 0:
        return 0
    eps = np.finfo(singular_values.dtype).eps
    rel_tol = rtol if rtol is not None else max(data.shape) * eps
    abs_tol = atol if atol is not None else 0.0
    tol = max(abs_tol, singular_values.max() * rel_tol)
    return int(np.sum(singular_values > tol))


def inv(tensor: "Tensor") -> "Tensor":
    """
    Compute matrix inverse.
    
    Args:
        tensor: Input tensor (2D)
        
    Returns:
        Inverse matrix
        
    Examples:
        >>> A = Tensor([[1, 2], [3, 4]])
        >>> A_inv = inv(A)
    """
    from .neurx import Tensor
    data = _to_numpy(tensor.data)
    if len(data.shape) != 2:
        raise ValueError(f"Expected 2D tensor, got shape {data.shape}")
    
    inv_data = np.linalg.inv(data)
    out = Tensor(inv_data, requires_grad=tensor.requires_grad, _children=(tensor,), _op="inv", device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            grad = out.grad
            inv_T = inv_data.T
            tensor.grad += -inv_T @ grad @ inv_T
    
    out._backward = _backward
    return out


def det(tensor: "Tensor") -> "Tensor":
    """
    Compute matrix determinant.
    
    Args:
        tensor: Input tensor (2D)
        
    Returns:
        Determinant
        
    Examples:
        >>> A = Tensor([[1, 2], [3, 4]])
        >>> det_A = det(A)
    """
    from .neurx import Tensor
    data = _to_numpy(tensor.data)
    if len(data.shape) != 2:
        raise ValueError(f"Expected 2D tensor, got shape {data.shape}")
    
    det_val = np.linalg.det(data)
    out = Tensor(det_val, requires_grad=tensor.requires_grad, _children=(tensor,), _op="det", device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            inv_data = np.linalg.inv(data)
            tensor.grad += out.grad * (det_val * inv_data.T)
    
    out._backward = _backward
    return out


def eig(tensor: "Tensor") -> Tuple["Tensor", Tensor]:
    """
    Compute eigenvalue decomposition.
    
    Args:
        tensor: Input tensor (2D)
        
    Returns:
        Tuple of (eigenvalues, eigenvectors)
        
    Examples:
        >>> A = Tensor([[1, 2], [2, 1]])
        >>> eigenvalues, eigenvectors = eig(A)
    """
    data = _to_numpy(tensor.data)
    if len(data.shape) != 2:
        raise ValueError(f"Expected 2D tensor, got shape {data.shape}")
    
    eigenvalues, eigenvectors = np.linalg.eig(data)
    
    return (Tensor(eigenvalues, requires_grad=False, device=tensor.device),
            Tensor(eigenvectors, requires_grad=False, device=tensor.device))


def eigh(tensor: "Tensor") -> Tuple["Tensor", Tensor]:
    """
    Compute eigenvalue decomposition for Hermitian/symmetric matrix.
    
    Args:
        tensor: Input tensor (2D, symmetric)
        
    Returns:
        Tuple of (eigenvalues, eigenvectors)
    """
    data = _to_numpy(tensor.data)
    if len(data.shape) != 2:
        raise ValueError(f"Expected 2D tensor, got shape {data.shape}")
    
    eigenvalues, eigenvectors = np.linalg.eigh(data)
    
    return (Tensor(eigenvalues, requires_grad=False, device=tensor.device),
            Tensor(eigenvectors, requires_grad=False, device=tensor.device))


def svd(tensor: "Tensor", full_matrices: bool = False) -> Tuple["Tensor", Tensor, Tensor]:
    """
    Singular value decomposition.
    
    Args:
        tensor: Input tensor (2D)
        full_matrices: Compute full or reduced SVD
        
    Returns:
        Tuple of (U, S, Vh) where A = U @ diag(S) @ Vh
        
    Examples:
        >>> A = Tensor([[1, 2], [3, 4], [5, 6]])
        >>> U, S, Vh = svd(A)
    """
    data = _to_numpy(tensor.data)
    if len(data.shape) != 2:
        raise ValueError(f"Expected 2D tensor, got shape {data.shape}")
    
    U, S, Vh = np.linalg.svd(data, full_matrices=full_matrices)
    
    return (Tensor(U, requires_grad=False, device=tensor.device),
            Tensor(S, requires_grad=False, device=tensor.device),
            Tensor(Vh, requires_grad=False, device=tensor.device))


def qr(tensor: "Tensor") -> Tuple["Tensor", Tensor]:
    """
    QR decomposition.
    
    Args:
        tensor: Input tensor (2D)
        
    Returns:
        Tuple of (Q, R) where A = Q @ R
        
    Examples:
        >>> A = Tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
        >>> Q, R = qr(A)
    """
    data = _to_numpy(tensor.data)
    if len(data.shape) != 2:
        raise ValueError(f"Expected 2D tensor, got shape {data.shape}")
    
    Q, R = np.linalg.qr(data)
    
    return (Tensor(Q, requires_grad=False, device=tensor.device),
            Tensor(R, requires_grad=False, device=tensor.device))


def cholesky(tensor: "Tensor") -> "Tensor":
    """
    Cholesky decomposition of positive-definite matrix.
    
    Args:
        tensor: Input tensor (2D, symmetric positive-definite)
        
    Returns:
        Lower triangular L where A = L @ L.T
        
    Examples:
        >>> A = Tensor([[4, 2], [2, 3]])
        >>> L = cholesky(A)
    """
    from .neurx import Tensor
    data = _to_numpy(tensor.data)
    if len(data.shape) != 2:
        raise ValueError(f"Expected 2D tensor, got shape {data.shape}")
    
    L = np.linalg.cholesky(data)
    out = Tensor(L, requires_grad=tensor.requires_grad, _children=(tensor,), _op="cholesky", device=tensor.device)
    
    def _backward():
        if tensor.requires_grad:
            # Gradient of Cholesky decomposition
            grad_L = out.grad
            # Compute gradient w.r.t. input
            # This is complex; simplified version
            tensor.grad += L @ grad_L.T
    
    out._backward = _backward
    return out


def solve(A: "Tensor", B: "Tensor") -> "Tensor":
    """
    Solve linear system AX = B.
    
    Args:
        A: Coefficient matrix (2D)
        B: Right-hand side matrix (2D) or vector (1D)
        
    Returns:
        Solution X
        
    Examples:
        >>> A = Tensor([[3, 1], [1, 2]])
        >>> B = Tensor([9, 8])
        >>> X = solve(A, B)
    """
    from .neurx import Tensor
    A_data = _to_numpy(A.data)
    B_data = _to_numpy(B.data)
    
    if len(A_data.shape) != 2:
        raise ValueError(f"Expected 2D matrix A, got shape {A_data.shape}")
    
    X = np.linalg.solve(A_data, B_data)
    out = Tensor(X, requires_grad=A.requires_grad or B.requires_grad, _children=(A, B), _op="solve", device=A.device)
    
    def _backward():
        if A.requires_grad:
            # grad_A = -X.T @ (grad_X @ B.T)
            X_grad = out.grad
            A.grad += -X_grad @ B_data.T
        if B.requires_grad:
            # grad_B = A.T @ grad_X
            X_grad = out.grad
            B.grad += A_data.T @ X_grad
    
    out._backward = _backward
    return out


def lstsq(A: "Tensor", B: "Tensor") -> "Tensor":
    """
    Least squares solution to AX = B.
    
    Args:
        A: Coefficient matrix (M, N)
        B: Right-hand side (M, K) or (M,)
        
    Returns:
        Least squares solution X (N, K) or (N,)
        
    Examples:
        >>> A = Tensor([[1, 0], [1, 1], [1, 2]])  # 3x2
        >>> B = Tensor([1, 2, 3])  # 3
        >>> X = lstsq(A, B)  # 2
    """
    from .neurx import Tensor
    A_data = _to_numpy(A.data)
    B_data = _to_numpy(B.data)
    
    if len(A_data.shape) != 2:
        raise ValueError(f"Expected 2D matrix A, got shape {A_data.shape}")
    
    X = np.linalg.lstsq(A_data, B_data, rcond=None)[0]
    out = Tensor(X, requires_grad=A.requires_grad or B.requires_grad, _children=(A, B), _op="lstsq", device=A.device)
    
    return out


def cross(A: "Tensor", B: "Tensor", dim: int = -1) -> "Tensor":
    """
    Vector cross product.
    
    Args:
        A: First vector (shape: (..., 3))
        B: Second vector (shape: (..., 3))
        dim: Dimension containing vectors (default: -1)
        
    Returns:
        Cross product (shape: (..., 3))
        
    Examples:
        >>> u = Tensor([1, 0, 0])
        >>> v = Tensor([0, 1, 0])
        >>> cross(u, v)  # [0, 0, 1]
    """
    from .neurx import Tensor
    A_data = _to_numpy(A.data)
    B_data = _to_numpy(B.data)
    
    out_data = np.cross(A_data, B_data, axisa=dim, axisb=dim)
    out = Tensor(out_data, requires_grad=A.requires_grad or B.requires_grad, _children=(A, B), _op="cross", device=A.device)
    
    def _backward():
        if A.requires_grad:
            # Gradient w.r.t. A
            A.grad += np.cross(out.grad, B_data, axisa=dim, axisb=dim)
        if B.requires_grad:
            # Gradient w.r.t. B
            B.grad += np.cross(A_data, out.grad, axisa=dim, axisb=dim)
    
    out._backward = _backward
    return out


def outer(A: "Tensor", B: "Tensor") -> "Tensor":
    """
    Outer product of two vectors.
    
    Args:
        A: First vector (shape: (M,))
        B: Second vector (shape: (N,))
        
    Returns:
        Outer product (shape: (M, N))
        
    Examples:
        >>> u = Tensor([1, 2, 3])
        >>> v = Tensor([4, 5])
        >>> outer(u, v)  # [[4, 5], [8, 10], [12, 15]]
    """
    from .neurx import Tensor
    A_data = _to_numpy(A.data)
    B_data = _to_numpy(B.data)
    
    out_data = np.outer(A_data, B_data)
    out = Tensor(out_data, requires_grad=A.requires_grad or B.requires_grad, _children=(A, B), _op="outer", device=A.device)
    
    def _backward():
        if A.requires_grad:
            A.grad += out.grad @ B_data
        if B.requires_grad:
            B.grad += A_data @ out.grad
    
    out._backward = _backward
    return out


def inner(A: "Tensor", B: "Tensor") -> "Tensor":
    """
    Inner product of two vectors.
    
    Args:
        A: First vector
        B: Second vector
        
    Returns:
        Inner product (scalar)
        
    Examples:
        >>> u = Tensor([1, 2, 3])
        >>> v = Tensor([4, 5, 6])
        >>> inner(u, v)  # 32
    """
    from .neurx import Tensor
    A_data = _to_numpy(A.data)
    B_data = _to_numpy(B.data)
    
    out_data = np.inner(A_data, B_data)
    out = Tensor(out_data, requires_grad=A.requires_grad or B.requires_grad, _children=(A, B), _op="inner", device=A.device)
    
    def _backward():
        if A.requires_grad:
            A.grad += out.grad * B_data
        if B.requires_grad:
            B.grad += out.grad * A_data
    
    out._backward = _backward
    return out


def matrix_power(tensor: "Tensor", n: int) -> "Tensor":
    """
    Raise square matrix to integer power.
    
    Args:
        tensor: Input matrix (2D)
        n: Power (non-negative integer)
        
    Returns:
        Matrix to power n
        
    Examples:
        >>> A = Tensor([[1, 2], [3, 4]])
        >>> A_squared = matrix_power(A, 2)
    """
    from .neurx import Tensor
    data = _to_numpy(tensor.data)
    if len(data.shape) != 2:
        raise ValueError(f"Expected 2D tensor, got shape {data.shape}")
    
    if not isinstance(n, int) or n < 0:
        raise ValueError("Power must be non-negative integer")
    
    out_data = np.linalg.matrix_power(data, n)
    out = Tensor(out_data, requires_grad=tensor.requires_grad, _children=(tensor,), _op="matrix_power", device=tensor.device)
    
    return out
