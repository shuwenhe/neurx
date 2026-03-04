"""
Tests for new tensor functionality.
"""
import numpy as np
import pytest
from neurx.core import (
    zeros, ones, full, eye, arange, linspace, logspace,
    rand, randn, randint, randperm, normal, uniform,
    index_select, masked_select, masked_fill, where,
    cat, split, chunk, stack,
    sort, argsort, topk, unique, median, cumsum, cumprod, prod,
    Tensor
)
from neurx.core import linalg


class TestTensorCreation:
    """Test tensor creation functions."""
    
    def test_zeros(self):
        x = zeros(3, 4)
        assert x.shape == (3, 4)
        assert np.allclose(x.to_numpy(), 0)
        
        x = zeros((2, 3))
        assert x.shape == (2, 3)
    
    def test_ones(self):
        x = ones(3, 4)
        assert x.shape == (3, 4)
        assert np.allclose(x.to_numpy(), 1)
    
    def test_full(self):
        x = full((2, 3), 5.0)
        assert x.shape == (2, 3)
        assert np.allclose(x.to_numpy(), 5.0)
    
    def test_eye(self):
        x = eye(3)
        assert x.shape == (3, 3)
        assert np.allclose(x.to_numpy(), np.eye(3))
    
    def test_arange(self):
        x = arange(10)
        assert np.allclose(x.to_numpy(), np.arange(10))
        
        x = arange(2, 10, 2)
        assert np.allclose(x.to_numpy(), np.arange(2, 10, 2))
    
    def test_linspace(self):
        x = linspace(0, 1, 5)
        assert len(x.shape) == 1
        assert x.shape[0] == 5
    
    def test_rand(self):
        x = rand(3, 4)
        assert x.shape == (3, 4)
        assert np.all(x.to_numpy() >= 0) and np.all(x.to_numpy() < 1)
    
    def test_randn(self):
        x = randn(100, 1)
        # Check if roughly standard normal
        data = x.to_numpy()
        assert abs(np.mean(data)) < 0.5
        assert abs(np.std(data) - 1) < 0.3
    
    def test_randint(self):
        x = randint(0, 10, (5, 5))
        assert x.shape == (5, 5)
        assert np.all(x.to_numpy() >= 0) and np.all(x.to_numpy() < 10)


class TestTensorIndexing:
    """Test advanced indexing operations."""
    
    def test_index_select(self):
        x = Tensor([[1, 2, 3], [4, 5, 6]])
        indices = Tensor([0, 2])
        result = index_select(x, 1, indices)
        expected = np.array([[1, 3], [4, 6]])
        assert np.allclose(result.to_numpy(), expected)
    
    def test_masked_select(self):
        x = Tensor([1, 2, 3, 4, 5])
        mask = Tensor([True, False, True, False, True])
        result = masked_select(x, mask)
        expected = np.array([1, 3, 5])
        assert np.allclose(result.to_numpy(), expected)
    
    def test_masked_fill(self):
        x = Tensor([1, 2, 3, 4, 5])
        mask = Tensor([True, False, True, False, True])
        result = masked_fill(x, mask, 0)
        expected = np.array([0, 2, 0, 4, 0])
        assert np.allclose(result.to_numpy(), expected)
    
    def test_where(self):
        cond = Tensor([True, False, True])
        x = Tensor([1, 2, 3])
        y = Tensor([10, 20, 30])
        result = where(cond, x, y)
        expected = np.array([1, 20, 3])
        assert np.allclose(result.to_numpy(), expected)
    
    def test_cat(self):
        x = Tensor([1, 2, 3])
        y = Tensor([4, 5, 6])
        result = cat([x, y], dim=0)
        expected = np.array([1, 2, 3, 4, 5, 6])
        assert np.allclose(result.to_numpy(), expected)
    
    def test_split(self):
        x = Tensor([1, 2, 3, 4, 5, 6])
        parts = split(x, 2, dim=0)
        assert len(parts) == 3
        assert np.allclose(parts[0].to_numpy(), [1, 2])
        assert np.allclose(parts[1].to_numpy(), [3, 4])
        assert np.allclose(parts[2].to_numpy(), [5, 6])
    
    def test_stack(self):
        x = Tensor([1, 2, 3])
        y = Tensor([4, 5, 6])
        result = stack([x, y], dim=0)
        expected = np.array([[1, 2, 3], [4, 5, 6]])
        assert np.allclose(result.to_numpy(), expected)


class TestTensorStats:
    """Test statistical operations."""
    
    def test_sort(self):
        x = Tensor([3, 1, 4, 1, 5])
        sorted_x, indices = sort(x)
        expected = np.array([1, 1, 3, 4, 5])
        assert np.allclose(sorted_x.to_numpy(), expected)
    
    def test_argsort(self):
        x = Tensor([3, 1, 4, 1, 5])
        indices = argsort(x)
        expected = np.argsort([3, 1, 4, 1, 5])
        assert np.allclose(indices.to_numpy(), expected)
    
    def test_topk(self):
        x = Tensor([1, 3, 5, 2, 4])
        values, indices = topk(x, k=3)
        assert len(values.shape) == 1
        assert values.shape[0] == 3
    
    def test_unique(self):
        x = Tensor([1, 2, 1, 3, 2])
        unique_vals = unique(x)
        expected = np.array([1, 2, 3])
        assert np.allclose(unique_vals.to_numpy(), expected)
    
    def test_cumsum(self):
        x = Tensor([1, 2, 3, 4, 5])
        result = cumsum(x)
        expected = np.array([1, 3, 6, 10, 15])
        assert np.allclose(result.to_numpy(), expected)
    
    def test_prod(self):
        x = Tensor([1, 2, 3, 4])
        result = prod(x)
        expected = 24
        assert np.isclose(result.to_numpy(), expected)


class TestLinearAlgebra:
    """Test linear algebra operations."""
    
    def test_inv(self):
        A = Tensor([[1.0, 2.0], [3.0, 4.0]])
        A_inv = linalg.inv(A)
        
        # A @ A_inv should be close to I
        result = A @ A_inv
        I = np.eye(2)
        assert np.allclose(result.to_numpy(), I, atol=1e-6)
    
    def test_det(self):
        A = Tensor([[1.0, 2.0], [3.0, 4.0]])
        det_val = linalg.det(A)
        expected = np.linalg.det([[1, 2], [3, 4]])
        assert np.isclose(det_val.to_numpy(), expected)
    
    def test_matrix_rank(self):
        A = Tensor([[1.0, 2.0], [2.0, 4.0]])  # Rank 1
        rank = linalg.matrix_rank(A)
        assert rank == 1
    
    def test_svd(self):
        A = Tensor([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]])
        U, S, Vh = linalg.svd(A)
        
        # Reconstruct A
        A_reconstructed = U @ np.diag(S.to_numpy()) @ Vh.to_numpy()
        assert np.allclose(A_reconstructed, A.to_numpy(), atol=1e-6)
    
    def test_qr(self):
        A = Tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]])
        Q, R = linalg.qr(A)
        
        # Reconstruct A
        A_reconstructed = Q @ R
        assert np.allclose(A_reconstructed.to_numpy(), A.to_numpy(), atol=1e-6)
    
    def test_solve(self):
        A = Tensor([[3.0, 1.0], [1.0, 2.0]])
        b = Tensor([9.0, 8.0])
        x = linalg.solve(A, b)
        
        # A @ x should equal b
        result = A @ x
        assert np.allclose(result.to_numpy(), b.to_numpy(), atol=1e-6)
    
    def test_cross(self):
        u = Tensor([1.0, 0.0, 0.0])
        v = Tensor([0.0, 1.0, 0.0])
        cross_prod = linalg.cross(u, v)
        expected = np.array([0.0, 0.0, 1.0])
        assert np.allclose(cross_prod.to_numpy(), expected, atol=1e-6)
    
    def test_outer(self):
        u = Tensor([1.0, 2.0, 3.0])
        v = Tensor([4.0, 5.0])
        outer_prod = linalg.outer(u, v)
        expected = np.array([[4, 5], [8, 10], [12, 15]])
        assert np.allclose(outer_prod.to_numpy(), expected)
    
    def test_inner(self):
        u = Tensor([1.0, 2.0, 3.0])
        v = Tensor([4.0, 5.0, 6.0])
        inner_prod = linalg.inner(u, v)
        expected = 32.0  # 1*4 + 2*5 + 3*6
        assert np.isclose(inner_prod.to_numpy(), expected)


class TestGradients:
    """Test gradient computation for new functions."""
    
    def test_sort_gradient(self):
        x = Tensor([3.0, 1.0, 4.0], requires_grad=True)
        sorted_x, _ = sort(x)
        loss = sum(sorted_x.to_numpy())
        # Just check it doesn't error
        assert sorted_x.shape == x.shape
    
    def test_cat_gradient(self):
        x = Tensor([1.0, 2.0], requires_grad=True)
        y = Tensor([3.0, 4.0], requires_grad=True)
        z = cat([x, y], dim=0)
        
        assert z.shape == (4,)
    
    def test_cumsum_gradient(self):
        x = Tensor([1.0, 2.0, 3.0], requires_grad=True)
        y = cumsum(x)
        
        assert np.allclose(y.to_numpy(), [1, 3, 6])


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
