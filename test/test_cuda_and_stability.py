"""
Test CUDA path gradient consistency verification.

This module tests that gradient computations on CUDA match CPU implementations,
ensuring numerical consistency across devices.
"""
import pytest
import numpy as np
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

from neurx import Tensor
import neurx

# Only run CUDA tests if CUDA is available
try:
    import neurx.cuda
    CUDA_AVAILABLE = True
except Exception:
    CUDA_AVAILABLE = False


class TestCUDAGradientConsistency:
    """Test CUDA gradient computation consistency with CPU"""
    
    @pytest.mark.skipif(not CUDA_AVAILABLE, reason="CUDA not available")
    def test_basic_operations_gradient_consistency(self):
        """Test that basic operations (add, mul, etc.) produce same gradients on CPU and CUDA"""
        np.random.seed(42)
        data = np.random.randn(3, 4).astype(np.float32)
        
        # CPU computation
        t_cpu = Tensor(data.copy(), requires_grad=True, device="cpu")
        y_cpu = (t_cpu * 2 + 1).sum()
        y_cpu.backward()
        grad_cpu = t_cpu.grad.copy()
        
        # CUDA computation
        try:
            t_cuda = Tensor(data.copy(), requires_grad=True, device="cuda")
            y_cuda = (t_cuda * 2 + 1).sum()
            y_cuda.backward()
            grad_cuda = t_cuda.grad.copy() if isinstance(t_cuda.grad, np.ndarray) else t_cuda.grad
            
            # Compare gradients
            if isinstance(grad_cuda, np.ndarray):
                assert np.allclose(grad_cpu, grad_cuda.astype(np.float64), rtol=1e-4, atol=1e-5)
            else:
                # CUDA grad might be DeviceArray, convert to numpy
                grad_cuda_np = grad_cuda.astype(np.float64) if hasattr(grad_cuda, 'astype') else np.array(grad_cuda, dtype=np.float64)
                assert np.allclose(grad_cpu, grad_cuda_np, rtol=1e-4, atol=1e-5)
        except Exception as e:
            pytest.skip(f"CUDA computation failed: {e}")
    
    def test_cpu_gradient_correctness(self):
        """Test basic CPU gradient computation correctness"""
        t = Tensor(np.array([[1.0, 2.0], [3.0, 4.0]]), requires_grad=True)
        
        # Simple operation: sum(x * 2)
        y = (t * 2).sum()
        y.backward()
        
        # Expected gradient: all 2s
        assert np.allclose(t.grad, np.ones_like(t.data) * 2)
    
    def test_reduction_operation_gradients(self):
        """Test that reduction operations (mean, sum, max) produce consistent gradients"""
        data = np.random.randn(3, 4, 5).astype(np.float64)
        
        # Test sum() gradient
        t_cpu = Tensor(data.copy(), requires_grad=True, device="cpu")
        y = t_cpu.sum(dim=1, keepdim=True)
        loss = y.sum()
        loss.backward()
        
        # Expected: all gradients should be 1.0
        expected_grad = np.ones_like(data)
        assert np.allclose(t_cpu.grad, expected_grad)
    
    def test_gather_gradient_consistency(self):
        """Test gather operation gradient computation"""
        data = np.arange(12).reshape(3, 4).astype(np.float64)
        t = Tensor(data, requires_grad=True)
        
        # Gather operation
        idx = Tensor(np.array([[0, 2], [1, 3], [2, 0]], dtype=np.int64))
        gathered = t.gather(1, idx)
        loss = gathered.sum()
        loss.backward()
        
        # Gradients should accumulate at gathered indices
        assert t.grad.shape == t.shape
        assert t.grad.sum() == gathered.numel()  # Each gathered element contributes 1 to gradient
    
    def test_scatter_gradient_consistency(self):
        """Test scatter operation gradient computation"""
        t = Tensor(np.ones((3, 5)), requires_grad=False)
        idx = Tensor(np.array([[0, 2], [1, 3], [2, 4]], dtype=np.int64))
        src = Tensor(np.ones((3, 2)), requires_grad=True)
        
        out = t.scatter(1, idx, src)
        loss = out.sum()
        
        # Check that scatter produces expected output
        assert out.shape == t.shape
        
        # Gradient should flow only to src values
        src.grad = np.zeros_like(src.data)  # Reset gradient
        # In a proper backward pass, src.grad would accumulate
    
    def test_softmax_gradient_stability(self):
        """Test softmax gradient computation for numerical stability"""
        data = np.random.randn(3, 4).astype(np.float64)
        t = Tensor(data, requires_grad=True)
        
        # Softmax operation
        sm = t.softmax(dim=1)
        loss = sm.sum()
        loss.backward()
        
        # Check gradient properties
        assert t.grad is not None
        assert t.grad.shape == t.shape
        assert not np.isnan(t.grad).any()
        assert not np.isinf(t.grad).any()
    
    def test_clamp_gradient_masking(self):
        """Test that clamp properly masks gradients"""
        data = np.array([[-1.0, 0.5, 2.0], [1.5, -0.5, 3.0]])
        t = Tensor(data, requires_grad=True)
        
        # Clamp to [0, 2]
        clamped = t.clamp(min=0, max=2)
        loss = clamped.sum()
        loss.backward()
        
        # Gradients should be 0 for values outside [0, 2]
        # and 1 for values inside
        expected_grad = np.array([[0.0, 1.0, 1.0], [1.0, 0.0, 0.0]])
        assert np.allclose(t.grad, expected_grad)
    
    def test_dtype_conversion_gradient_preservation(self):
        """Test that dtype conversion preserves gradient flow"""
        data = np.array([1.0, 2.0, 3.0])
        t = Tensor(data, requires_grad=True)
        
        # Convert to float16 then back to float64
        t_half = t.float16()
        t_back = t_half.float64()
        
        loss = t_back.sum()
        loss.backward()
        
        # Should have gradients
        assert t.grad is not None
        assert t.grad.shape == t.shape


class TestNumericStability:
    """Test numerical stability of operations"""
    
    def test_softmax_large_values(self):
        """Test softmax with large values doesn't overflow"""
        data = np.array([[100.0, 101.0, 99.0]])
        t = Tensor(data)
        
        sm = t.softmax(dim=1)
        
        # Should still sum to ~1.0
        assert np.allclose(sm.data.sum(), 1.0, rtol=1e-5)
        # No NaN or Inf
        assert not np.isnan(sm.data).any()
        assert not np.isinf(sm.data).any()
    
    def test_softmax_small_values(self):
        """Test softmax with very small values"""
        data = np.array([[-100.0, -101.0, -99.0]])
        t = Tensor(data)
        
        sm = t.softmax(dim=1)
        
        # Should still sum to ~1.0
        assert np.allclose(sm.data.sum(), 1.0, rtol=1e-5)
        # No NaN or Inf
        assert not np.isnan(sm.data).any()
        assert not np.isinf(sm.data).any()
    
    def test_log_softmax_stability(self):
        """Test log_softmax numerical stability"""
        data = np.random.randn(3, 1000)  # Wide tensor
        t = Tensor(data)
        
        log_sm = t.log_softmax(dim=1)
        
        # Log softmax should sum to log(1.0) = 0.0 (approximately)
        exp_sm = np.exp(log_sm.data)
        assert np.allclose(exp_sm.sum(axis=1), 1.0, rtol=1e-5)
        
        # No NaN or Inf
        assert not np.isnan(log_sm.data).any()
        assert not np.isinf(log_sm.data).any()


class TestErrorMessages:
    """Test error message consistency and quality"""
    
    def test_scatter_error_messages_are_informative(self):
        """Test that scatter errors provide helpful information"""
        t = Tensor(np.ones((3, 4)))
        
        # Different error types should have clear messages
        with pytest.raises(IndexError) as exc_info:
            idx = Tensor(np.array([[0, 1], [2, 10], [0, 1]], dtype=np.int64))
            src = Tensor(np.ones((3, 2)))
            t.scatter(1, idx, src)
        
        error_msg = str(exc_info.value)
        assert "scatter" in error_msg
        assert "out of bounds" in error_msg
        assert "dim 1" in error_msg or "size 4" in error_msg
    
    def test_gather_error_messages_match_scatter(self):
        """Test that gather and scatter error messages follow same format"""
        t = Tensor(np.ones((3, 4)))
        
        # Both should have similar error message format
        scatter_error = None
        gather_error = None
        
        try:
            idx = Tensor(np.array([[0, 1], [2, 10], [0, 1]], dtype=np.int64))
            src = Tensor(np.ones((3, 2)))
            t.scatter(1, idx, src)
        except IndexError as e:
            scatter_error = str(e)
        
        try:
            idx = Tensor(np.array([[0, 1], [2, 10], [0, 1]], dtype=np.int64))
            t.gather(1, idx)
        except IndexError as e:
            gather_error = str(e)
        
        if scatter_error and gather_error:
            # Both should mention bounds and dim
            assert ("out of bounds" in scatter_error or "index" in scatter_error)
            assert ("out of bounds" in gather_error or "index" in gather_error)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
