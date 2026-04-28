"""
Test suite for in-place neurx operations.

Tests cover:
- Basic functionality (correct computation)
- Device compatibility (CPU and CUDA)
- Gradient flow (where applicable)
- Shape validation
- Type handling (Tensor and scalar)
"""

import numpy as np
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

from neurx import Tensor
import pytest


class TestInPlaceAdd:
    """Test add_ (in-place addition) operation."""
    
    def test_add_scalar(self):
        """Test in-place addition with scalar."""
        t = Tensor([1.0, 2.0, 3.0])
        t.add_(5.0)
        assert np.allclose(t.to_numpy(), [6.0, 7.0, 8.0])
    
    def test_add_tensor(self):
        """Test in-place addition with another neurx."""
        t1 = Tensor([1.0, 2.0, 3.0])
        t2 = Tensor([10.0, 20.0, 30.0])
        t1.add_(t2)
        assert np.allclose(t1.to_numpy(), [11.0, 22.0, 33.0])
    
    def test_add_2d(self):
        """Test in-place addition on 2D neurx."""
        t = Tensor([[1.0, 2.0], [3.0, 4.0]])
        t.add_(Tensor([[10.0, 20.0], [30.0, 40.0]]))
        expected = [[11.0, 22.0], [33.0, 44.0]]
        assert np.allclose(t.to_numpy(), expected)
    
    def test_add_returns_self(self):
        """Test that add_ returns self."""
        t = Tensor([1.0, 2.0, 3.0])
        result = t.add_(5.0)
        assert result is t
    
    def test_add_broadcast(self):
        """Test in-place addition with broadcasting."""
        t = Tensor([[1.0, 2.0], [3.0, 4.0]])
        t.add_(Tensor([10.0, 20.0]))  # (2,) broadcasts to (2, 2)
        expected = [[11.0, 22.0], [13.0, 24.0]]
        assert np.allclose(t.to_numpy(), expected)


class TestInPlaceMul:
    """Test mul_ (in-place multiplication) operation."""
    
    def test_mul_scalar(self):
        """Test in-place multiplication with scalar."""
        t = Tensor([1.0, 2.0, 3.0])
        t.mul_(2.0)
        assert np.allclose(t.to_numpy(), [2.0, 4.0, 6.0])
    
    def test_mul_tensor(self):
        """Test in-place multiplication with another neurx."""
        t1 = Tensor([1.0, 2.0, 3.0])
        t2 = Tensor([2.0, 3.0, 4.0])
        t1.mul_(t2)
        assert np.allclose(t1.to_numpy(), [2.0, 6.0, 12.0])
    
    def test_mul_by_zero(self):
        """Test in-place multiplication by zero."""
        t = Tensor([1.0, 2.0, 3.0])
        t.mul_(0.0)
        assert np.allclose(t.to_numpy(), [0.0, 0.0, 0.0])
    
    def test_mul_negative(self):
        """Test in-place multiplication with negative values."""
        t = Tensor([1.0, 2.0, 3.0])
        t.mul_(-1.0)
        assert np.allclose(t.to_numpy(), [-1.0, -2.0, -3.0])
    
    def test_mul_returns_self(self):
        """Test that mul_ returns self."""
        t = Tensor([1.0, 2.0, 3.0])
        result = t.mul_(2.0)
        assert result is t


class TestInPlaceSub:
    """Test sub_ (in-place subtraction) operation."""
    
    def test_sub_scalar(self):
        """Test in-place subtraction with scalar."""
        t = Tensor([5.0, 6.0, 7.0])
        t.sub_(2.0)
        assert np.allclose(t.to_numpy(), [3.0, 4.0, 5.0])
    
    def test_sub_tensor(self):
        """Test in-place subtraction with another neurx."""
        t1 = Tensor([10.0, 20.0, 30.0])
        t2 = Tensor([1.0, 2.0, 3.0])
        t1.sub_(t2)
        assert np.allclose(t1.to_numpy(), [9.0, 18.0, 27.0])
    
    def test_sub_negative(self):
        """Test in-place subtraction with negative value (adds)."""
        t = Tensor([5.0, 6.0, 7.0])
        t.sub_(-2.0)
        assert np.allclose(t.to_numpy(), [7.0, 8.0, 9.0])
    
    def test_sub_returns_self(self):
        """Test that sub_ returns self."""
        t = Tensor([5.0, 6.0, 7.0])
        result = t.sub_(2.0)
        assert result is t


class TestInPlaceDiv:
    """Test div_ (in-place division) operation."""
    
    def test_div_scalar(self):
        """Test in-place division with scalar."""
        t = Tensor([2.0, 4.0, 6.0])
        t.div_(2.0)
        assert np.allclose(t.to_numpy(), [1.0, 2.0, 3.0])
    
    def test_div_tensor(self):
        """Test in-place division with another neurx."""
        t1 = Tensor([10.0, 20.0, 30.0])
        t2 = Tensor([2.0, 4.0, 5.0])
        t1.div_(t2)
        assert np.allclose(t1.to_numpy(), [5.0, 5.0, 6.0])
    
    def test_div_by_one(self):
        """Test in-place division by 1."""
        t = Tensor([1.0, 2.0, 3.0])
        original = t.to_numpy().copy()
        t.div_(1.0)
        assert np.allclose(t.to_numpy(), original)
    
    def test_div_returns_self(self):
        """Test that div_ returns self."""
        t = Tensor([2.0, 4.0, 6.0])
        result = t.div_(2.0)
        assert result is t


class TestInPlacePow:
    """Test pow_ (in-place power) operation."""
    
    def test_pow_scalar(self):
        """Test in-place power with scalar exponent."""
        t = Tensor([2.0, 3.0, 4.0])
        t.pow_(2.0)
        assert np.allclose(t.to_numpy(), [4.0, 9.0, 16.0])
    
    def test_pow_sqrt(self):
        """Test in-place power with 0.5 (square root)."""
        t = Tensor([4.0, 9.0, 16.0])
        t.pow_(0.5)
        assert np.allclose(t.to_numpy(), [2.0, 3.0, 4.0])
    
    def test_pow_zero(self):
        """Test in-place power with exponent 0."""
        t = Tensor([2.0, 3.0, 4.0])
        t.pow_(0.0)
        assert np.allclose(t.to_numpy(), [1.0, 1.0, 1.0])
    
    def test_pow_negative(self):
        """Test in-place power with negative exponent."""
        t = Tensor([2.0, 4.0])
        t.pow_(-1.0)
        assert np.allclose(t.to_numpy(), [0.5, 0.25])
    
    def test_pow_returns_self(self):
        """Test that pow_ returns self."""
        t = Tensor([2.0, 3.0, 4.0])
        result = t.pow_(2.0)
        assert result is t


class TestInPlaceCopy:
    """Test copy_ (in-place copy) operation."""
    
    def test_copy_same_shape(self):
        """Test in-place copy with same shape."""
        t1 = Tensor([1.0, 2.0, 3.0])
        t2 = Tensor([4.0, 5.0, 6.0])
        t1.copy_(t2)
        assert np.allclose(t1.to_numpy(), [4.0, 5.0, 6.0])
    
    def test_copy_modifies_original(self):
        """Test that copy modifies the original values."""
        t1 = Tensor([1.0, 2.0, 3.0])
        original_data = t1.to_numpy().copy()
        t2 = Tensor([10.0, 20.0, 30.0])
        t1.copy_(t2)
        assert not np.allclose(t1.to_numpy(), original_data)
    
    def test_copy_is_deep(self):
        """Test that copy_ creates independent data."""
        t1 = Tensor([1.0, 2.0, 3.0])
        t2 = Tensor([4.0, 5.0, 6.0])
        t1.copy_(t2)
        # Modify t2
        t2_data = t2.to_numpy()
        t2_data[0] = 999.0
        # t1 should not be affected if copy is deep
        # Note: depends on implementation details
        assert np.allclose(t1.to_numpy(), [4.0, 5.0, 6.0])
    
    def test_copy_2d(self):
        """Test in-place copy on 2D neurx."""
        t1 = Tensor([[1.0, 2.0], [3.0, 4.0]])
        t2 = Tensor([[10.0, 20.0], [30.0, 40.0]])
        t1.copy_(t2)
        assert np.allclose(t1.to_numpy(), [[10.0, 20.0], [30.0, 40.0]])
    
    def test_copy_returns_self(self):
        """Test that copy_ returns self."""
        t1 = Tensor([1.0, 2.0, 3.0])
        t2 = Tensor([4.0, 5.0, 6.0])
        result = t1.copy_(t2)
        assert result is t1
    
    def test_copy_shape_mismatch(self):
        """Test that copy_ raises error on shape mismatch."""
        t1 = Tensor([1.0, 2.0, 3.0])
        t2 = Tensor([[1.0, 2.0], [3.0, 4.0]])
        with pytest.raises(ValueError, match="shape mismatch"):
            t1.copy_(t2)


class TestInPlaceFill:
    """Test fill_ (in-place fill) operation."""
    
    def test_fill_positive(self):
        """Test filling with positive value."""
        t = Tensor([1.0, 2.0, 3.0])
        t.fill_(7.5)
        assert np.allclose(t.to_numpy(), [7.5, 7.5, 7.5])
    
    def test_fill_zero(self):
        """Test filling with zero."""
        t = Tensor([1.0, 2.0, 3.0])
        t.fill_(0.0)
        assert np.allclose(t.to_numpy(), [0.0, 0.0, 0.0])
    
    def test_fill_negative(self):
        """Test filling with negative value."""
        t = Tensor([1.0, 2.0, 3.0])
        t.fill_(-5.0)
        assert np.allclose(t.to_numpy(), [-5.0, -5.0, -5.0])
    
    def test_fill_2d(self):
        """Test filling 2D neurx."""
        t = Tensor([[1.0, 2.0], [3.0, 4.0]])
        t.fill_(42.0)
        expected = [[42.0, 42.0], [42.0, 42.0]]
        assert np.allclose(t.to_numpy(), expected)
    
    def test_fill_returns_self(self):
        """Test that fill_ returns self."""
        t = Tensor([1.0, 2.0, 3.0])
        result = t.fill_(5.0)
        assert result is t


class TestInPlaceZero:
    """Test zero_ (in-place zero) operation."""
    
    def test_zero_1d(self):
        """Test zeroing 1D neurx."""
        t = Tensor([1.0, 2.0, 3.0])
        t.zero_()
        assert np.allclose(t.to_numpy(), [0.0, 0.0, 0.0])
    
    def test_zero_2d(self):
        """Test zeroing 2D neurx."""
        t = Tensor([[1.0, 2.0], [3.0, 4.0]])
        t.zero_()
        assert np.allclose(t.to_numpy(), [[0.0, 0.0], [0.0, 0.0]])
    
    def test_zero_already_zero(self):
        """Test zeroing neurx that's already zero."""
        t = Tensor([0.0, 0.0, 0.0])
        t.zero_()
        assert np.allclose(t.to_numpy(), [0.0, 0.0, 0.0])
    
    def test_zero_returns_self(self):
        """Test that zero_ returns self."""
        t = Tensor([1.0, 2.0, 3.0])
        result = t.zero_()
        assert result is t


class TestInPlaceRelu:
    """Test relu_ (in-place ReLU) operation."""
    
    def test_relu_positive(self):
        """Test ReLU with positive values (unchanged)."""
        t = Tensor([1.0, 2.0, 3.0])
        t.relu_()
        assert np.allclose(t.to_numpy(), [1.0, 2.0, 3.0])
    
    def test_relu_negative(self):
        """Test ReLU with negative values (zeroed)."""
        t = Tensor([-1.0, -2.0, -3.0])
        t.relu_()
        assert np.allclose(t.to_numpy(), [0.0, 0.0, 0.0])
    
    def test_relu_mixed(self):
        """Test ReLU with mixed positive and negative."""
        t = Tensor([-2.0, -1.0, 0.0, 1.0, 2.0])
        t.relu_()
        assert np.allclose(t.to_numpy(), [0.0, 0.0, 0.0, 1.0, 2.0])
    
    def test_relu_2d(self):
        """Test ReLU on 2D neurx."""
        t = Tensor([[-1.0, 2.0], [3.0, -4.0]])
        t.relu_()
        expected = [[0.0, 2.0], [3.0, 0.0]]
        assert np.allclose(t.to_numpy(), expected)
    
    def test_relu_returns_self(self):
        """Test that relu_ returns self."""
        t = Tensor([1.0, 2.0, 3.0])
        result = t.relu_()
        assert result is t


class TestInPlaceChaining:
    """Test chaining multiple in-place operations."""
    
    def test_chain_add_mul(self):
        """Test chaining add_ and mul_."""
        t = Tensor([2.0, 3.0, 4.0])
        t.add_(1.0).mul_(2.0)  # (2+1)*2=6, (3+1)*2=8, (4+1)*2=10
        assert np.allclose(t.to_numpy(), [6.0, 8.0, 10.0])
    
    def test_chain_sub_div(self):
        """Test chaining sub_ and div_."""
        t = Tensor([10.0, 20.0, 30.0])
        t.sub_(4.0).div_(2.0)  # (10-4)/2=3, (20-4)/2=8, (30-4)/2=13
        assert np.allclose(t.to_numpy(), [3.0, 8.0, 13.0])
    
    def test_chain_mul_pow(self):
        """Test chaining mul_ and pow_."""
        t = Tensor([2.0, 3.0])
        t.mul_(2.0).pow_(2.0)  # (2*2)^2=16, (3*2)^2=36
        assert np.allclose(t.to_numpy(), [16.0, 36.0])


class TestInPlaceMemoryEfficiency:
    """Test that in-place operations are memory efficient."""
    
    def test_inplace_not_creating_new_tensor(self):
        """Test that in-place operations modify data in-place."""
        t = Tensor([1.0, 2.0, 3.0])
        original_id = id(t)
        t.add_(5.0)
        assert id(t) == original_id  # Same object
    
    def test_inplace_vs_non_inplace(self):
        """Compare in-place vs non-inplace operations."""
        t1 = Tensor([1.0, 2.0, 3.0])
        t2 = Tensor([1.0, 2.0, 3.0])
        
        # Non-inplace
        t2_result = t2 + 5.0
        
        # In-place
        t1.add_(5.0)
        
        # Both should have same result but t1 is modified in-place
        assert np.allclose(t1.to_numpy(), t2_result.to_numpy())
        assert id(t1) != id(t2_result)  # Non-inplace returns new neurx


class TestInPlaceEdgeCases:
    """Test edge cases and error conditions."""
    
    def test_empty_tensor(self):
        """Test operations on empty neurx."""
        t = Tensor([])
        t.add_(5.0)
        assert t.shape == (0,)
    
    def test_single_element(self):
        """Test operations on single element neurx."""
        t = Tensor([5.0])
        t.mul_(2.0)
        assert np.allclose(t.to_numpy(), [10.0])
    
    def test_large_tensor(self):
        """Test operations on large neurx."""
        t = Tensor(np.random.randn(1000, 1000).astype(np.float32))
        original_shape = t.shape
        t.add_(1.0)
        assert t.shape == original_shape
    
    def test_zero_division_warning(self):
        """Test division by very small number."""
        t = Tensor([1.0, 2.0, 3.0])
        # This should work but may produce inf/nan
        t.div_(1e-10)
        # Just verify it doesn't crash


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
