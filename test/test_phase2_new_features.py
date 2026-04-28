"""
Phase 2 New Features Tests

Tests for Phase 2 tensor operations:
- Padding operations (pad)
- Matrix operations (trace, det, matrix_rank)
- Cumulative operations (cumsum, cumprod)
- Inverse trigonometric functions (asin, acos, atan)
- Hyperbolic functions (sinh, cosh)
"""

import pytest
import numpy as np
import neurx


class TestPaddingOperations:
    """Tests for padding operations"""
    
    def test_pad_constant_2d(self):
        """Test constant padding for 2D tensor"""
        x = neurx.Tensor([[1, 2], [3, 4]], requires_grad=True)
        
        # Pad with 1 on all sides
        y = x.pad(((1, 1), (1, 1)), mode='constant', value=0)
        
        assert y.shape == (4, 4)
        assert y.data[0, 0] == 0  # Padding
        assert y.data[1, 1] == 1  # Original
        assert y.data[2, 2] == 4  # Original
        
        # Test gradient
        y.sum().backward()
        assert x.grad.shape == x.shape
        assert np.allclose(x.grad, np.ones_like(x.data))
    
    def test_pad_constant_with_value(self):
        """Test constant padding with custom value"""
        x = neurx.Tensor([1, 2, 3], requires_grad=True)
        y = x.pad(((2, 2),), mode='constant', value=5)
        
        assert y.shape == (7,)
        assert y.data[0] == 5 and y.data[1] == 5
        assert y.data[-1] == 5 and y.data[-2] == 5
        np.testing.assert_array_equal(y.data[2:5], [1, 2, 3])
    
    def test_pad_reflect(self):
        """Test reflect padding"""
        x = neurx.Tensor([1, 2, 3, 4], requires_grad=True)
        y = x.pad(((2, 2),), mode='reflect')
        
        # Reflect: [3, 2] [1, 2, 3, 4] [3, 2]
        assert y.shape == (8,)
        np.testing.assert_array_equal(y.data, [3, 2, 1, 2, 3, 4, 3, 2])
    
    def test_pad_replicate(self):
        """Test replicate/edge padding"""
        x = neurx.Tensor([1, 2, 3], requires_grad=True)
        y = x.pad(((2, 2),), mode='replicate')
        
        # Edge: [1, 1] [1, 2, 3] [3, 3]
        assert y.shape == (7,)
        assert y.data[0] == 1 and y.data[1] == 1
        assert y.data[-1] == 3 and y.data[-2] == 3
    
    def test_pad_gradient_flow(self):
        """Test gradient flows correctly through padding"""
        x = neurx.Tensor([[1.0, 2.0]], requires_grad=True)
        y = x.pad(((1, 1), (1, 1)), mode='constant', value=0)
        loss = (y ** 2).sum()
        loss.backward()
        
        # Gradient should only flow through non-padded elements
        assert x.grad.shape == (1, 2)
        np.testing.assert_allclose(x.grad, [[2.0, 4.0]])


class TestMatrixOperations:
    """Tests for matrix operations"""
    
    def test_trace_basic(self):
        """Test trace computation"""
        x = neurx.Tensor([[1, 2], [3, 4]], requires_grad=True)
        y = x.trace()
        
        assert y.data == 5  # 1 + 4
        
        # Test gradient
        y.backward()
        expected_grad = np.array([[1, 0], [0, 1]])
        np.testing.assert_array_equal(x.grad, expected_grad)
    
    def test_trace_larger_matrix(self):
        """Test trace for larger matrix"""
        x = neurx.Tensor(np.eye(5), requires_grad=True)
        y = x.trace()
        
        assert y.data == 5.0
        
        y.backward()
        np.testing.assert_array_equal(x.grad, np.eye(5))
    
    def test_det_2x2(self):
        """Test determinant for 2x2 matrix"""
        x = neurx.Tensor([[2, 1], [1, 2]], requires_grad=True)
        y = x.det()
        
        assert np.isclose(y.data, 3.0)  # 2*2 - 1*1 = 3
        
        # Test gradient
        y.backward()
        assert x.grad.shape == (2, 2)
    
    def test_det_3x3(self):
        """Test determinant for 3x3 matrix"""
        x = neurx.Tensor([[1, 2, 3], [0, 1, 4], [5, 6, 0]], requires_grad=True)
        y = x.det()
        
        expected_det = np.linalg.det(x.data)
        assert np.isclose(y.data, expected_det)
        
        y.backward()
        assert x.grad.shape == (3, 3)
    
    def test_matrix_rank(self):
        """Test matrix rank computation"""
        # Full rank matrix
        x1 = neurx.Tensor([[1, 0], [0, 1]])
        assert x1.matrix_rank().data == 2
        
        # Rank deficient matrix
        x2 = neurx.Tensor([[1, 2], [2, 4]])
        assert x2.matrix_rank().data == 1
        
        # Zero matrix
        x3 = neurx.Tensor(np.zeros((3, 3)))
        assert x3.matrix_rank().data == 0


class TestCumulativeOperations:
    """Tests for cumulative operations"""
    
    def test_cumsum_1d(self):
        """Test cumulative sum for 1D tensor"""
        x = neurx.Tensor([1, 2, 3, 4], requires_grad=True)
        y = x.cumsum(dim=0)
        
        np.testing.assert_array_equal(y.data, [1, 3, 6, 10])
        
        # Test gradient
        y.sum().backward()
        np.testing.assert_array_equal(x.grad, [4, 3, 2, 1])
    
    def test_cumsum_2d(self):
        """Test cumulative sum for 2D tensor"""
        x = neurx.Tensor([[1, 2], [3, 4]], requires_grad=True)
        
        # Cumsum along rows
        y1 = x.cumsum(dim=0)
        np.testing.assert_array_equal(y1.data, [[1, 2], [4, 6]])
        
        # Cumsum along columns
        y2 = x.cumsum(dim=1)
        np.testing.assert_array_equal(y2.data, [[1, 3], [3, 7]])
    
    def test_cumsum_gradient(self):
        """Test cumsum gradient computation"""
        x = neurx.Tensor([1.0, 2.0, 3.0], requires_grad=True)
        y = x.cumsum(dim=0)
        loss = (y ** 2).sum()
        loss.backward()
        
        # Gradient should accumulate in reverse
        assert x.grad.shape == (3,)
        assert x.grad is not None
    
    def test_cumprod_1d(self):
        """Test cumulative product for 1D tensor"""
        x = neurx.Tensor([1, 2, 3, 4], requires_grad=True)
        y = x.cumprod(dim=0)
        
        np.testing.assert_array_equal(y.data, [1, 2, 6, 24])
        
        # Test gradient
        y.sum().backward()
        assert x.grad.shape == (4,)
    
    def test_cumprod_2d(self):
        """Test cumulative product for 2D tensor"""
        x = neurx.Tensor([[1, 2], [3, 4]], requires_grad=True)
        
        # Cumprod along rows
        y1 = x.cumprod(dim=0)
        np.testing.assert_array_equal(y1.data, [[1, 2], [3, 8]])
        
        # Cumprod along columns
        y2 = x.cumprod(dim=1)
        np.testing.assert_array_equal(y2.data, [[1, 2], [3, 12]])
    
    def test_cumprod_gradient(self):
        """Test cumprod gradient computation"""
        x = neurx.Tensor([2.0, 3.0, 4.0], requires_grad=True)
        y = x.cumprod(dim=0)
        loss = y.sum()
        loss.backward()
        
        # Gradient should be computed correctly
        assert x.grad.shape == (3,)
        assert x.grad is not None


class TestInverseTrigFunctions:
    """Tests for inverse trigonometric functions"""
    
    def test_asin_basic(self):
        """Test arcsine computation"""
        x = neurx.Tensor([0.0, 0.5, 1.0], requires_grad=True)
        y = x.asin()
        
        expected = np.arcsin(x.data)
        np.testing.assert_allclose(y.data, expected)
        
        # Test gradient
        y.sum().backward()
        assert x.grad.shape == (3,)
    
    def test_asin_gradient(self):
        """Test arcsine gradient"""
        x = neurx.Tensor([0.5], requires_grad=True)
        y = x.asin()
        y.backward()
        
        # Gradient: 1 / sqrt(1 - x^2)
        expected_grad = 1.0 / np.sqrt(1.0 - 0.5**2)
        np.testing.assert_allclose(x.grad, [expected_grad], rtol=1e-5)
    
    def test_acos_basic(self):
        """Test arccosine computation"""
        x = neurx.Tensor([0.0, 0.5, 1.0], requires_grad=True)
        y = x.acos()
        
        expected = np.arccos(x.data)
        np.testing.assert_allclose(y.data, expected)
        
        # Test gradient
        y.sum().backward()
        assert x.grad.shape == (3,)
    
    def test_acos_gradient(self):
        """Test arccosine gradient"""
        x = neurx.Tensor([0.5], requires_grad=True)
        y = x.acos()
        y.backward()
        
        # Gradient: -1 / sqrt(1 - x^2)
        expected_grad = -1.0 / np.sqrt(1.0 - 0.5**2)
        np.testing.assert_allclose(x.grad, [expected_grad], rtol=1e-5)
    
    def test_atan_basic(self):
        """Test arctangent computation"""
        x = neurx.Tensor([0.0, 1.0, -1.0], requires_grad=True)
        y = x.atan()
        
        expected = np.arctan(x.data)
        np.testing.assert_allclose(y.data, expected)
        
        # Test gradient
        y.sum().backward()
        assert x.grad.shape == (3,)
    
    def test_atan_gradient(self):
        """Test arctangent gradient"""
        x = neurx.Tensor([1.0], requires_grad=True)
        y = x.atan()
        y.backward()
        
        # Gradient: 1 / (1 + x^2)
        expected_grad = 1.0 / (1.0 + 1.0**2)
        np.testing.assert_allclose(x.grad, [expected_grad])
    
    def test_inverse_trig_2d(self):
        """Test inverse trig functions on 2D tensors"""
        x = neurx.Tensor([[0.0, 0.5], [-0.5, 0.0]], requires_grad=True)
        
        y1 = x.asin()
        y2 = x.acos()
        y3 = x.atan()
        
        assert y1.shape == (2, 2)
        assert y2.shape == (2, 2)
        assert y3.shape == (2, 2)


class TestHyperbolicFunctions:
    """Tests for hyperbolic functions"""
    
    def test_sinh_basic(self):
        """Test hyperbolic sine computation"""
        x = neurx.Tensor([0.0, 1.0, -1.0], requires_grad=True)
        y = x.sinh()
        
        expected = np.sinh(x.data)
        np.testing.assert_allclose(y.data, expected)
        
        # Test gradient
        y.sum().backward()
        assert x.grad.shape == (3,)
    
    def test_sinh_gradient(self):
        """Test sinh gradient"""
        x = neurx.Tensor([1.0], requires_grad=True)
        y = x.sinh()
        y.backward()
        
        # Gradient: cosh(x)
        expected_grad = np.cosh(1.0)
        np.testing.assert_allclose(x.grad, [expected_grad])
    
    def test_cosh_basic(self):
        """Test hyperbolic cosine computation"""
        x = neurx.Tensor([0.0, 1.0, -1.0], requires_grad=True)
        y = x.cosh()
        
        expected = np.cosh(x.data)
        np.testing.assert_allclose(y.data, expected)
        
        # Test gradient
        y.sum().backward()
        assert x.grad.shape == (3,)
    
    def test_cosh_gradient(self):
        """Test cosh gradient"""
        x = neurx.Tensor([1.0], requires_grad=True)
        y = x.cosh()
        y.backward()
        
        # Gradient: sinh(x)
        expected_grad = np.sinh(1.0)
        np.testing.assert_allclose(x.grad, [expected_grad])
    
    def test_hyperbolic_identity(self):
        """Test hyperbolic identity: cosh^2 - sinh^2 = 1"""
        x = neurx.Tensor([0.5, 1.0, 1.5])
        
        cosh_x = x.cosh()
        sinh_x = x.sinh()
        
        result = cosh_x**2 - sinh_x**2
        np.testing.assert_allclose(result.data, np.ones(3), rtol=1e-6)
    
    def test_hyperbolic_2d(self):
        """Test hyperbolic functions on 2D tensors"""
        x = neurx.Tensor([[0.0, 1.0], [2.0, -1.0]], requires_grad=True)
        
        y1 = x.sinh()
        y2 = x.cosh()
        
        assert y1.shape == (2, 2)
        assert y2.shape == (2, 2)
        
        # Test gradient flow
        (y1 + y2).sum().backward()
        assert x.grad.shape == (2, 2)


class TestIntegrationPhase2:
    """Integration tests combining Phase 2 features"""
    
    def test_combined_operations(self):
        """Test combining multiple Phase 2 operations"""
        x = neurx.Tensor([0.0, 0.5, 1.0], requires_grad=True)
        
        # Chain multiple operations
        y = x.asin()
        z = y.sinh()
        w = z.cumsum(0)
        
        loss = w.sum()
        loss.backward()
        
        assert x.grad.shape == (3,)
        assert x.grad is not None
    
    def test_pad_then_trace(self):
        """Test padding followed by matrix operations"""
        x = neurx.Tensor([[1, 2], [3, 4]], requires_grad=True)
        
        # Pad to 4x4
        y = x.pad(((1, 1), (1, 1)), mode='constant', value=0)
        
        # Compute trace
        z = y.trace()
        z.backward()
        
        # Gradient should flow back correctly
        assert x.grad.shape == (2, 2)
    
    def test_cumulative_with_trig(self):
        """Test cumulative operations with trigonometric functions"""
        x = neurx.Tensor([0.1, 0.2, 0.3], requires_grad=True)
        
        y = x.atan()
        z = y.cumsum(0)
        loss = z.sum()
        loss.backward()
        
        assert x.grad.shape == (3,)
    
    def test_matrix_ops_chain(self):
        """Test chaining matrix operations"""
        x = neurx.Tensor([[1, 2], [3, 4]], requires_grad=True)
        
        # Multiple matrix operations
        trace_val = x.trace()
        det_val = x.det()
        
        loss = trace_val + det_val
        loss.backward()
        
        assert x.grad.shape == (2, 2)
    
    def test_phase2_with_phase1(self):
        """Test Phase 2 features work with Phase 1 features"""
        x = neurx.Tensor([1.0, 2.0, 3.0], requires_grad=True)
        
        # Phase 1: log1p, exp
        y = x.log1p()
        
        # Phase 2: cumsum, sinh
        z = y.cumsum(0)
        w = z.sinh()
        
        loss = w.sum()
        loss.backward()
        
        assert x.grad.shape == (3,)
        assert np.all(np.isfinite(x.grad))


def test_phase2_summary():
    """Summary test to verify all Phase 2 features are working"""
    print("\n" + "="*60)
    print("Phase 2 Feature Summary")
    print("="*60)
    
    features = [
        ("pad", lambda: neurx.Tensor([[1, 2]]).pad(((1, 1), (1, 1)))),
        ("trace", lambda: neurx.Tensor([[1, 2], [3, 4]]).trace()),
        ("det", lambda: neurx.Tensor([[1, 2], [3, 4]]).det()),
        ("matrix_rank", lambda: neurx.Tensor([[1, 2], [3, 4]]).matrix_rank()),
        ("cumsum", lambda: neurx.Tensor([1, 2, 3]).cumsum(0)),
        ("cumprod", lambda: neurx.Tensor([1, 2, 3]).cumprod(0)),
        ("asin", lambda: neurx.Tensor([0.5]).asin()),
        ("acos", lambda: neurx.Tensor([0.5]).acos()),
        ("atan", lambda: neurx.Tensor([1.0]).atan()),
        ("sinh", lambda: neurx.Tensor([1.0]).sinh()),
        ("cosh", lambda: neurx.Tensor([1.0]).cosh()),
    ]
    
    passed = 0
    for name, func in features:
        try:
            result = func()
            print(f"✓ {name:15s} - OK (shape: {result.shape})")
            passed += 1
        except Exception as e:
            print(f"✗ {name:15s} - FAILED: {e}")
    
    print("="*60)
    print(f"Phase 2 Complete: {passed}/{len(features)} features working")
    print("="*60)
    
    assert passed == len(features), f"Only {passed}/{len(features)} features working"
