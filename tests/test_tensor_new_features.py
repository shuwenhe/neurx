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
    softmax, log_softmax, take_along_dim,
    clamp, clip, sign, flip, roll, tile, Tensor
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


class TestTensorParityOps:
    """Test high-value PyTorch parity ops."""

    def test_clamp_and_clip(self):
        x = Tensor([-2.0, -0.5, 0.3, 2.0], requires_grad=True)
        y = clamp(x, min=-1.0, max=1.0)
        z = clip(x, min=0.0, max=1.0)

        assert np.allclose(y.to_numpy(), np.array([-1.0, -0.5, 0.3, 1.0]))
        assert np.allclose(z.to_numpy(), np.array([0.0, 0.0, 0.3, 1.0]))

        y.sum().backward()
        assert np.allclose(x.grad, np.array([0.0, 1.0, 1.0, 0.0]))

    def test_sign(self):
        x = Tensor([-2.0, 0.0, 3.0])
        y = sign(x)
        assert np.allclose(y.to_numpy(), np.array([-1.0, 0.0, 1.0]))

    def test_flip(self):
        x = Tensor([[1, 2, 3], [4, 5, 6]])
        y = flip(x, dims=(1,))
        assert np.allclose(y.to_numpy(), np.array([[3, 2, 1], [6, 5, 4]]))

    def test_roll(self):
        x = Tensor([1, 2, 3, 4, 5])
        y = roll(x, shifts=2)
        assert np.allclose(y.to_numpy(), np.array([4, 5, 1, 2, 3]))

    def test_tile(self):
        x = Tensor([[1, 2], [3, 4]])
        y = tile(x, (2, 1))
        assert np.allclose(y.to_numpy(), np.array([[1, 2], [3, 4], [1, 2], [3, 4]]))

    def test_boolean_indexing_tensor_mask(self):
        x = Tensor([1.0, -2.0, 3.0, -4.0], requires_grad=True)
        y = x[x > 0]
        assert np.allclose(y.to_numpy(), np.array([1.0, 3.0]))

        y.sum().backward()
        assert np.allclose(x.grad, np.array([1.0, 0.0, 1.0, 0.0]))

    def test_take_along_dim(self):
        x = Tensor([[10, 20, 30], [40, 50, 60]])
        idx = Tensor([[2, 1], [0, 2]])
        y = take_along_dim(x, idx, dim=1)
        assert np.allclose(y.to_numpy(), np.array([[30, 20], [40, 60]]))

    def test_tensor_softmax_log_softmax(self):
        x = Tensor([[1.0, 2.0, 3.0]])
        sm = x.softmax(dim=1)
        lsm = x.log_softmax(dim=1)

        assert np.allclose(np.sum(sm.to_numpy(), axis=1), np.array([1.0]), atol=1e-6)
        assert np.allclose(np.exp(lsm.to_numpy()), sm.to_numpy(), atol=1e-6)

    def test_functional_softmax_log_softmax(self):
        x = Tensor([[1.0, 2.0, 3.0]])
        sm = softmax(x, dim=1)
        lsm = log_softmax(x, dim=1)

        assert np.allclose(np.sum(sm.to_numpy(), axis=1), np.array([1.0]), atol=1e-6)
        assert np.allclose(np.exp(lsm.to_numpy()), sm.to_numpy(), atol=1e-6)

    def test_boolean_row_mask_2d(self):
        x = Tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]], requires_grad=True)
        row_mask = Tensor([True, False, True])
        y = x[row_mask]

        assert y.shape == (2, 3)
        assert np.allclose(y.to_numpy(), np.array([[1, 2, 3], [7, 8, 9]]))

        y.sum().backward()
        assert np.allclose(x.grad, np.array([[1, 1, 1], [0, 0, 0], [1, 1, 1]]))

    def test_boolean_full_mask_2d(self):
        x = Tensor([[1, -2, 3], [-4, 5, -6]], requires_grad=True)
        mask = x > 0
        y = x[mask]

        assert y.shape == (3,)
        assert np.allclose(y.to_numpy(), np.array([1, 3, 5]))

        y.sum().backward()
        assert np.allclose(x.grad, np.array([[1, 0, 1], [0, 1, 0]]))

    def test_mixed_boolean_and_int_indexing(self):
        x = Tensor([[10, 11, 12], [20, 21, 22], [30, 31, 32]], requires_grad=True)
        row_mask = Tensor([True, False, True])
        col_idx = Tensor([2, 0])
        y = x[row_mask, col_idx]

        assert y.shape == (2,)
        assert np.allclose(y.to_numpy(), np.array([12, 30]))

        y.sum().backward()
        expected_grad = np.zeros((3, 3), dtype=np.float64)
        expected_grad[0, 2] = 1.0
        expected_grad[2, 0] = 1.0
        assert np.allclose(x.grad, expected_grad)

    def test_mixed_boolean_slice_ellipsis(self):
        x = Tensor(np.arange(24, dtype=np.float64).reshape(2, 3, 4), requires_grad=True)
        mask = Tensor([True, False, True])

        y1 = x[:, mask, 1:3]
        assert y1.shape == (2, 2, 2)
        assert np.allclose(y1.to_numpy(), np.arange(24).reshape(2, 3, 4)[:, [0, 2], 1:3])

        y2 = x[..., 2]
        assert y2.shape == (2, 3)
        assert np.allclose(y2.to_numpy(), np.arange(24).reshape(2, 3, 4)[..., 2])

    def test_setitem_boolean_mask(self):
        x = Tensor([[1.0, -2.0, 3.0], [-4.0, 5.0, -6.0]])
        mask = x > 0
        x[mask] = 0.0
        assert np.allclose(x.to_numpy(), np.array([[0.0, -2.0, 0.0], [-4.0, 0.0, -6.0]]))

    def test_setitem_mixed_boolean_int(self):
        x = Tensor([[10.0, 11.0, 12.0], [20.0, 21.0, 22.0], [30.0, 31.0, 32.0]])
        row_mask = Tensor([True, False, True])
        col_idx = Tensor([2, 0])
        x[row_mask, col_idx] = Tensor([100.0, 200.0])

        expected = np.array([[10.0, 11.0, 100.0], [20.0, 21.0, 22.0], [200.0, 31.0, 32.0]])
        assert np.allclose(x.to_numpy(), expected)

    def test_setitem_ellipsis_and_slice(self):
        x = Tensor(np.arange(24, dtype=np.float64).reshape(2, 3, 4))
        x[..., 1] = -1.0
        out = x.to_numpy()
        assert np.allclose(out[..., 1], -1.0)

    def test_setitem_broadcast_scalar_and_vector(self):
        x = Tensor(np.zeros((2, 3), dtype=np.float64))
        x[:, 1] = 5.0
        assert np.allclose(x.to_numpy(), np.array([[0.0, 5.0, 0.0], [0.0, 5.0, 0.0]]))

        x[0, :] = Tensor([1.0, 2.0, 3.0])
        assert np.allclose(x.to_numpy()[0], np.array([1.0, 2.0, 3.0]))

    def test_setitem_shape_mismatch_error(self):
        x = Tensor(np.zeros((2, 3), dtype=np.float64))
        with pytest.raises((ValueError, IndexError)) as exc_info:
            x[:, 1] = Tensor([1.0, 2.0, 3.0])

        msg = str(exc_info.value).lower()
        assert "shape" in msg or "broadcast" in msg or "could not" in msg

    def test_gather_negative_dim(self):
        x = Tensor([[10, 20, 30], [40, 50, 60]])
        idx = Tensor([[2, 1], [0, 2]])
        y = x.gather(-1, idx)
        assert np.allclose(y.to_numpy(), np.array([[30, 20], [40, 60]]))

    def test_take_along_dim_negative_dim(self):
        x = Tensor([[10, 20, 30], [40, 50, 60]])
        idx = Tensor([[2, 1], [0, 2]])
        y = take_along_dim(x, idx, dim=-1)
        assert np.allclose(y.to_numpy(), np.array([[30, 20], [40, 60]]))

    def test_gather_dim_out_of_range_error(self):
        x = Tensor([[1, 2, 3]])
        idx = Tensor([[0, 1, 2]])
        with pytest.raises(IndexError) as exc_info:
            _ = x.gather(3, idx)
        assert "out of range" in str(exc_info.value).lower()

    def test_gather_index_out_of_bounds_error(self):
        x = Tensor([[1, 2, 3]])
        idx = Tensor([[0, 3, 1]])
        with pytest.raises(IndexError) as exc_info:
            _ = x.gather(1, idx)
        msg = str(exc_info.value).lower()
        assert "out of bounds" in msg or "out of range" in msg

    def test_gather_shape_mismatch_error(self):
        x = Tensor(np.arange(24, dtype=np.float64).reshape(2, 3, 4))
        idx = Tensor(np.zeros((2, 2, 4), dtype=np.int64))
        with pytest.raises(ValueError) as exc_info:
            _ = x.gather(2, idx)
        assert "shape" in str(exc_info.value).lower()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
