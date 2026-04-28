"""
Comprehensive tests for Phase 3: Advanced Tensor Operations
Tests for basic math, tensor concatenation/splitting, and comparison operations
"""

import pytest
import numpy as np
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

from neurx.core.neurx import Tensor


class TestPhase3BasicMath:
    """Test Phase 3.1: Basic Math Operations"""
    
    def test_floor_basic(self):
        """Test floor operation"""
        x = Tensor(np.array([[1.5, 2.7], [3.2, 4.9]]))
        result = x.floor()
        expected = np.array([[1., 2.], [3., 4.]])
        np.testing.assert_array_almost_equal(result.to_numpy(), expected)
    
    def test_floor_negative(self):
        """Test floor with negative numbers"""
        x = Tensor(np.array([-1.5, -2.7, 3.2]))
        result = x.floor()
        expected = np.array([-2., -3., 3.])
        np.testing.assert_array_almost_equal(result.to_numpy(), expected)
    
    def test_ceil_basic(self):
        """Test ceil operation"""
        x = Tensor(np.array([[1.5, 2.7], [3.2, 4.9]]))
        result = x.ceil()
        expected = np.array([[2., 3.], [4., 5.]])
        np.testing.assert_array_almost_equal(result.to_numpy(), expected)
    
    def test_ceil_negative(self):
        """Test ceil with negative numbers"""
        x = Tensor(np.array([-1.5, -2.7, 3.2]))
        result = x.ceil()
        expected = np.array([-1., -2., 4.])
        np.testing.assert_array_almost_equal(result.to_numpy(), expected)
    
    def test_round_basic(self):
        """Test round operation"""
        x = Tensor(np.array([1.5, 2.4, 3.5, 4.6]))
        result = x.round()
        expected = np.array([2., 2., 4., 5.])
        np.testing.assert_array_almost_equal(result.to_numpy(), expected)
    
    def test_round_negative(self):
        """Test round with negative numbers"""
        x = Tensor(np.array([-1.5, -2.4, -3.5, -4.6]))
        result = x.round()
        expected = np.array([-2., -2., -4., -5.])
        np.testing.assert_array_almost_equal(result.to_numpy(), expected)
    
    def test_lerp_basic(self):
        """Test linear interpolation"""
        a = Tensor(np.array([1., 2., 3.]))
        b = Tensor(np.array([5., 6., 7.]))
        weight = 0.5
        result = a.lerp(b, weight)
        expected = np.array([3., 4., 5.])  # midpoint
        np.testing.assert_array_almost_equal(result.to_numpy(), expected)
    
    def test_lerp_weight_zero(self):
        """Test lerp with weight = 0"""
        a = Tensor(np.array([1., 2., 3.]))
        b = Tensor(np.array([5., 6., 7.]))
        result = a.lerp(b, 0.0)
        np.testing.assert_array_almost_equal(result.to_numpy(), a.to_numpy())
    
    def test_lerp_weight_one(self):
        """Test lerp with weight = 1"""
        a = Tensor(np.array([1., 2., 3.]))
        b = Tensor(np.array([5., 6., 7.]))
        result = a.lerp(b, 1.0)
        np.testing.assert_array_almost_equal(result.to_numpy(), b.to_numpy())
    
    def test_lerp_gradient(self):
        """Test lerp backward pass"""
        a = Tensor(np.array([1., 2., 3.]), requires_grad=True)
        b = Tensor(np.array([5., 6., 7.]), requires_grad=True)
        z = a.lerp(b, 0.3)
        loss = z.sum()
        loss.backward()
        
        # Expected: da = (1 - 0.3) = 0.7, db = 0.3
        np.testing.assert_array_almost_equal(a.grad, [0.7, 0.7, 0.7])
        np.testing.assert_array_almost_equal(b.grad, [0.3, 0.3, 0.3])
    
    def test_where_basic(self):
        """Test where (conditional select)"""
        condition = np.array([True, False, True])
        x = Tensor(np.array([1., 2., 3.]))
        y = Tensor(np.array([10., 20., 30.]))
        result = x.where(condition, y)
        expected = np.array([1., 20., 3.])
        np.testing.assert_array_almost_equal(result.to_numpy(), expected)
    
    def test_where_matrix(self):
        """Test where with 2D arrays"""
        condition = np.array([[True, False], [False, True]])
        x = Tensor(np.array([[1., 2.], [3., 4.]]))
        y = Tensor(np.array([[10., 20.], [30., 40.]]))
        result = x.where(condition, y)
        expected = np.array([[1., 20.], [30., 4.]])
        np.testing.assert_array_almost_equal(result.to_numpy(), expected)
    
    def test_where_gradient(self):
        """Test where backward pass"""
        condition = np.array([True, False, True])
        x = Tensor(np.array([1., 2., 3.]), requires_grad=True)
        y = Tensor(np.array([10., 20., 30.]), requires_grad=True)
        z = x.where(condition, y)
        loss = z.sum()
        loss.backward()
        
        # Gradient flows only through selected elements
        np.testing.assert_array_almost_equal(x.grad, [1., 0., 1.])
        np.testing.assert_array_almost_equal(y.grad, [0., 1., 0.])


class TestPhase3TensorOps:
    """Test Phase 3.3: Tensor Operations (Concatenation/Splitting)"""
    
    def test_split_basic(self):
        """Test split operation"""
        x = Tensor(np.arange(12).reshape(3, 4))
        splits = x.split(2, dim=1)
        assert len(splits) == 2
        np.testing.assert_array_equal(splits[0].to_numpy(), np.array([[0, 1], [4, 5], [8, 9]]))
        np.testing.assert_array_equal(splits[1].to_numpy(), np.array([[2, 3], [6, 7], [10, 11]]))
    
    def test_split_dim0(self):
        """Test split along dimension 0"""
        x = Tensor(np.arange(12).reshape(4, 3))
        splits = x.split(2, dim=0)
        assert len(splits) == 2
        np.testing.assert_array_equal(splits[0].to_numpy(), np.array([[0, 1, 2], [3, 4, 5]]))
        np.testing.assert_array_equal(splits[1].to_numpy(), np.array([[6, 7, 8], [9, 10, 11]]))
    
    def test_split_uneven(self):
        """Test split with uneven division"""
        x = Tensor(np.arange(10).reshape(2, 5))
        splits = x.split(2, dim=1)
        assert len(splits) == 3
        assert splits[0].shape == (2, 2)
        assert splits[1].shape == (2, 2)
        assert splits[2].shape == (2, 1)
    
    def test_chunk_basic(self):
        """Test chunk operation"""
        x = Tensor(np.arange(12).reshape(3, 4))
        chunks = x.chunk(2, dim=1)
        assert len(chunks) == 2
        np.testing.assert_array_equal(chunks[0].to_numpy(), np.array([[0, 1], [4, 5], [8, 9]]))
        np.testing.assert_array_equal(chunks[1].to_numpy(), np.array([[2, 3], [6, 7], [10, 11]]))
    
    def test_chunk_dim0(self):
        """Test chunk along dimension 0"""
        x = Tensor(np.arange(12).reshape(4, 3))
        chunks = x.chunk(2, dim=0)
        assert len(chunks) == 2
        assert chunks[0].shape == (2, 3)
        assert chunks[1].shape == (2, 3)
    
    def test_chunk_three_parts(self):
        """Test chunk into 3 parts"""
        x = Tensor(np.arange(12).reshape(3, 4))
        chunks = x.chunk(3, dim=0)
        assert len(chunks) == 3
        for chunk in chunks:
            assert chunk.shape == (1, 4)
    
    def test_cat_basic(self):
        """Test concatenation along dimension"""
        a = Tensor(np.array([[1, 2], [3, 4]]))
        b = Tensor(np.array([[5, 6], [7, 8]]))
        result = Tensor.cat([a, b], dim=1)
        expected = np.array([[1, 2, 5, 6], [3, 4, 7, 8]])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_cat_dim0(self):
        """Test concatenation along dimension 0"""
        a = Tensor(np.array([[1, 2], [3, 4]]))
        b = Tensor(np.array([[5, 6], [7, 8]]))
        result = Tensor.cat([a, b], dim=0)
        expected = np.array([[1, 2], [3, 4], [5, 6], [7, 8]])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_cat_multiple(self):
        """Test concatenation of multiple tensors"""
        a = Tensor(np.array([[1], [2]]))
        b = Tensor(np.array([[3], [4]]))
        c = Tensor(np.array([[5], [6]]))
        result = Tensor.cat([a, b, c], dim=1)
        expected = np.array([[1, 3, 5], [2, 4, 6]])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_cat_gradient(self):
        """Test cat backward pass"""
        a = Tensor(np.array([[1., 2.]]), requires_grad=True)
        b = Tensor(np.array([[3., 4.]]), requires_grad=True)
        result = Tensor.cat([a, b], dim=1)
        loss = result.sum()
        loss.backward()
        
        np.testing.assert_array_almost_equal(a.grad, [[1., 1.]])
        np.testing.assert_array_almost_equal(b.grad, [[1., 1.]])
    
    def test_stack_basic(self):
        """Test stack operation"""
        a = Tensor(np.array([1, 2, 3]))
        b = Tensor(np.array([4, 5, 6]))
        result = Tensor.stack([a, b], dim=0)
        expected = np.array([[1, 2, 3], [4, 5, 6]])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_stack_dim1(self):
        """Test stack along dimension 1"""
        a = Tensor(np.array([1, 2, 3]))
        b = Tensor(np.array([4, 5, 6]))
        result = Tensor.stack([a, b], dim=1)
        expected = np.array([[1, 4], [2, 5], [3, 6]])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_stack_2d(self):
        """Test stack with 2D tensors"""
        a = Tensor(np.array([[1, 2], [3, 4]]))
        b = Tensor(np.array([[5, 6], [7, 8]]))
        result = Tensor.stack([a, b], dim=0)
        assert result.shape == (2, 2, 2)
        np.testing.assert_array_equal(result.to_numpy()[0], a.to_numpy())
        np.testing.assert_array_equal(result.to_numpy()[1], b.to_numpy())
    
    def test_stack_gradient(self):
        """Test stack backward pass"""
        a = Tensor(np.array([1., 2.]), requires_grad=True)
        b = Tensor(np.array([3., 4.]), requires_grad=True)
        result = Tensor.stack([a, b], dim=0)
        loss = result.sum()
        loss.backward()
        
        np.testing.assert_array_almost_equal(a.grad, [1., 1.])
        np.testing.assert_array_almost_equal(b.grad, [1., 1.])


class TestPhase3Comparison:
    """Test Phase 3.4: Comparison Operations"""
    
    def test_gt_basic(self):
        """Test greater than"""
        a = Tensor(np.array([1., 2., 3.]))
        b = Tensor(np.array([2., 1., 3.]))
        result = a.gt(b)
        expected = np.array([0., 1., 0.])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_gt_scalar(self):
        """Test greater than with scalar"""
        a = Tensor(np.array([1., 2., 3.]))
        result = a.gt(2.0)
        expected = np.array([0., 0., 1.])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_lt_basic(self):
        """Test less than"""
        a = Tensor(np.array([1., 2., 3.]))
        b = Tensor(np.array([2., 1., 3.]))
        result = a.lt(b)
        expected = np.array([1., 0., 0.])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_ge_basic(self):
        """Test greater than or equal"""
        a = Tensor(np.array([1., 2., 3.]))
        b = Tensor(np.array([1., 2., 4.]))
        result = a.ge(b)
        expected = np.array([1., 1., 0.])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_le_basic(self):
        """Test less than or equal"""
        a = Tensor(np.array([1., 2., 3.]))
        b = Tensor(np.array([1., 2., 2.]))
        result = a.le(b)
        expected = np.array([1., 1., 0.])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_isnan_basic(self):
        """Test isnan operation"""
        a = Tensor(np.array([1., np.nan, 3., np.nan]))
        result = a.isnan()
        expected = np.array([0., 1., 0., 1.])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_isinf_basic(self):
        """Test isinf operation"""
        a = Tensor(np.array([1., np.inf, 3., -np.inf]))
        result = a.isinf()
        expected = np.array([0., 1., 0., 1.])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_isnan_matrix(self):
        """Test isnan with 2D array"""
        a = Tensor(np.array([[1., np.nan], [3., np.nan]]))
        result = a.isnan()
        expected = np.array([[0., 1.], [0., 1.]])
        np.testing.assert_array_equal(result.to_numpy(), expected)
    
    def test_isinf_matrix(self):
        """Test isinf with 2D array"""
        a = Tensor(np.array([[np.inf, 2.], [3., -np.inf]]))
        result = a.isinf()
        expected = np.array([[1., 0.], [0., 1.]])
        np.testing.assert_array_equal(result.to_numpy(), expected)


class TestPhase3Integration:
    """Integration tests combining multiple Phase 3 features"""
    
    def test_cat_after_where(self):
        """Test concatenating results of where operations"""
        condition = np.array([True, False])
        a = Tensor(np.array([[1., 2.], [3., 4.]]))
        b = Tensor(np.array([[10., 20.], [30., 40.]]))
        selected = a.where(condition, b)
        
        # Split selected back
        splits = selected.split(1, dim=1)
        assert len(splits) == 2
    
    def test_chunk_and_process(self):
        """Test chunking and processing chunks"""
        x = Tensor(np.arange(8).reshape(2, 4).astype(np.float32))
        chunks = x.chunk(2, dim=1)
        
        # Process each chunk
        processed = [c * 2 for c in chunks]
        
        # Concatenate back
        result = Tensor.cat(processed, dim=1)
        expected = np.arange(8).reshape(2, 4).astype(np.float32) * 2
        np.testing.assert_array_almost_equal(result.to_numpy(), expected)
    
    def test_stack_and_split(self):
        """Test stacking then splitting"""
        a = Tensor(np.array([1., 2., 3.]))
        b = Tensor(np.array([4., 5., 6.]))
        stacked = Tensor.stack([a, b], dim=0)
        
        # Split along first dimension
        splits = stacked.split(1, dim=0)
        assert len(splits) == 2
        np.testing.assert_array_almost_equal(splits[0].to_numpy().squeeze(), a.to_numpy())
        np.testing.assert_array_almost_equal(splits[1].to_numpy().squeeze(), b.to_numpy())
    
    def test_comparison_with_where(self):
        """Test using comparison results with where"""
        a = Tensor(np.array([1., 2., 3., 4.]))
        condition = a.gt(2.0).to_numpy()
        zero = Tensor(np.zeros(4))
        result = a.where(condition, zero)
        expected = np.array([0., 0., 3., 4.])
        np.testing.assert_array_almost_equal(result.to_numpy(), expected)
    
    def test_lerp_chain(self):
        """Test chaining lerp operations"""
        a = Tensor(np.array([0., 0.]))
        b = Tensor(np.array([2., 2.]))
        c = Tensor(np.array([4., 4.]))
        
        # Interpolate from a to b at 0.5
        mid_ab = a.lerp(b, 0.5)
        # Then interpolate from b to c at 0.5
        mid_bc = b.lerp(c, 0.5)
        
        np.testing.assert_array_almost_equal(mid_ab.to_numpy(), [1., 1.])
        np.testing.assert_array_almost_equal(mid_bc.to_numpy(), [3., 3.])


class TestPhase3EdgeCases:
    """Test edge cases and error handling"""
    
    def test_negative_dim_split(self):
        """Test split with negative dimension"""
        x = Tensor(np.arange(12).reshape(3, 4))
        splits = x.split(2, dim=-1)
        assert len(splits) == 2
        assert splits[0].shape == (3, 2)
    
    def test_negative_dim_chunk(self):
        """Test chunk with negative dimension"""
        x = Tensor(np.arange(12).reshape(3, 4))
        chunks = x.chunk(2, dim=-1)
        assert len(chunks) == 2
        assert chunks[0].shape == (3, 2)
    
    def test_negative_dim_stack(self):
        """Test stack with negative dimension"""
        a = Tensor(np.array([1, 2, 3]))
        b = Tensor(np.array([4, 5, 6]))
        result = Tensor.stack([a, b], dim=-1)
        assert result.shape == (3, 2)
    
    def test_empty_cat_raises(self):
        """Test that empty cat raises error"""
        with pytest.raises(ValueError):
            Tensor.cat([])
    
    def test_empty_stack_raises(self):
        """Test that empty stack raises error"""
        with pytest.raises(ValueError):
            Tensor.stack([])
    
    def test_large_tensor_operations(self):
        """Test operations on larger tensors"""
        x = Tensor(np.random.randn(100, 200))
        
        # Test various operations
        floored = x.floor()
        ceiled = x.ceil()
        rounded = x.round()
        
        assert floored.shape == x.shape
        assert ceiled.shape == x.shape
        assert rounded.shape == x.shape
    
    def test_tensor_cat_3d(self):
        """Test cat with 3D tensors"""
        a = Tensor(np.arange(24).reshape(2, 3, 4))
        b = Tensor(np.arange(24).reshape(2, 3, 4))
        result = Tensor.cat([a, b], dim=2)
        assert result.shape == (2, 3, 8)


class TestPhase3Summary:
    """Summary test ensuring all Phase 3 methods work together"""
    
    def test_all_phase3_methods_present(self):
        """Verify all Phase 3 methods are implemented"""
        x = Tensor(np.array([1., 2., 3.]))
        
        # Phase 3.1: Basic Math
        assert hasattr(x, 'floor')
        assert hasattr(x, 'ceil')
        assert hasattr(x, 'round')
        assert hasattr(x, 'lerp')
        assert hasattr(x, 'where')
        
        # Phase 3.3: Tensor Ops
        assert hasattr(x, 'split')
        assert hasattr(x, 'chunk')
        assert hasattr(Tensor, 'cat')
        assert hasattr(Tensor, 'stack')
        
        # Phase 3.4: Comparison
        assert hasattr(x, 'gt')
        assert hasattr(x, 'lt')
        assert hasattr(x, 'ge')
        assert hasattr(x, 'le')
        assert hasattr(x, 'isnan')
        assert hasattr(x, 'isinf')
    
    def test_phase3_comprehensive_workflow(self):
        """Test a comprehensive workflow using Phase 3 features"""
        # Create sample data
        batch = Tensor.stack([
            Tensor(np.random.randn(3, 4)),
            Tensor(np.random.randn(3, 4)),
            Tensor(np.random.randn(3, 4))
        ], dim=0)
        
        assert batch.shape == (3, 3, 4)
        
        # Split into individual samples
        samples = batch.chunk(3, dim=0)
        assert len(samples) == 3
        
        # Apply operations
        results = []
        for sample in samples:
            floored = sample.squeeze().floor()
            results.append(floored)
        
        # Verify all operations completed
        assert len(results) == 3


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
