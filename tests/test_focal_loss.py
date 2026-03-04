"""
Test suite for Focal Loss implementation.

Tests cover:
- Basic functionality with different alpha and gamma values
- Multi-class classification
- Comparison with reference implementation
- Gradient computation
- Edge cases and parameter validation
"""

import numpy as np
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

from tensor import Tensor
import tensor.nn.functional as F
import tensor.nn as nn
import pytest


class TestFocalLossBasic:
    """Test basic focal loss functionality."""
    
    def test_focal_loss_basic(self):
        """Test basic focal loss computation."""
        # Create simple input and target
        input = Tensor([[2.0, 1.0, 0.1], [0.1, 2.0, 0.1], [0.1, 0.1, 2.0]])  # 3 samples, 3 classes
        target = np.array([0, 1, 2])
        
        loss = F.focal_loss(input, target, alpha=0.25, gamma=2.0)
        
        # Loss should be positive
        assert float(loss.to_numpy()) > 0
        # Loss should be scalar
        assert loss.shape == ()
    
    def test_focal_loss_perfect_predictions(self):
        """Test focal loss with perfect predictions."""
        # Very high logits for correct class
        input = Tensor([[10.0, -10.0, -10.0], [-10.0, 10.0, -10.0], [-10.0, -10.0, 10.0]])
        target = np.array([0, 1, 2])
        
        loss = F.focal_loss(input, target, alpha=0.25, gamma=2.0)
        loss_val = float(loss.to_numpy())
        
        # Loss should be very small for perfect predictions
        assert loss_val < 0.01
    
    def test_focal_loss_vs_cross_entropy_gamma0(self):
        """Test that focal loss with gamma=0 approximates cross entropy."""
        input = Tensor(np.random.randn(8, 4))
        target = np.array([0, 1, 2, 3, 0, 1, 2, 3])
        
        focal = F.focal_loss(input, target, alpha=1.0, gamma=0.0, reduction="mean")
        cross_entropy = F.cross_entropy(input, target, reduction="mean")
        
        # With alpha=1.0 and gamma=0.0, focal loss should be close to cross entropy
        focal_val = float(focal.to_numpy())
        ce_val = float(cross_entropy.to_numpy())
        
        # Allow some tolerance for numerical differences
        assert abs(focal_val - ce_val) < 0.1 * ce_val
    
    def test_focal_loss_reduction_none(self):
        """Test focal loss with reduction='none'."""
        input = Tensor([[2.0, 1.0], [1.0, 2.0], [2.0, 1.0]])  # 3 samples
        target = np.array([0, 1, 0])
        
        loss = F.focal_loss(input, target, alpha=0.25, gamma=2.0, reduction="none")
        
        # Should return per-sample losses
        assert loss.shape == (3,)
        # All losses should be positive
        assert np.all(loss.to_numpy() >= 0)
    
    def test_focal_loss_reduction_sum(self):
        """Test focal loss with reduction='sum'."""
        input = Tensor([[2.0, 1.0], [1.0, 2.0]])
        target = np.array([0, 1])
        
        loss_sum = F.focal_loss(input, target, alpha=0.25, gamma=2.0, reduction="sum")
        loss_none = F.focal_loss(input, target, alpha=0.25, gamma=2.0, reduction="none")
        
        # Sum should equal sum of none reduction
        assert np.allclose(
            float(loss_sum.to_numpy()),
            float(loss_none.sum().to_numpy()),
            rtol=1e-5
        )


class TestFocalLossParameters:
    """Test focal loss with different parameters."""
    
    def test_alpha_parameter(self):
        """Test that alpha parameter affects loss magnitude."""
        input = Tensor(np.random.randn(8, 4))
        target = np.array([0, 1, 2, 3, 0, 1, 2, 3])
        
        loss_alpha_0 = F.focal_loss(input, target, alpha=0.0, gamma=2.0)
        loss_alpha_1 = F.focal_loss(input, target, alpha=1.0, gamma=2.0)
        
        # alpha=0 should give 0 loss
        assert abs(float(loss_alpha_0.to_numpy())) < 1e-6
        
        # alpha=1 should give positive loss
        assert float(loss_alpha_1.to_numpy()) > 0
    
    def test_gamma_parameter(self):
        """Test that gamma parameter affects focusing strength."""
        input = Tensor(np.random.randn(8, 4))
        target = np.array([0, 1, 2, 3, 0, 1, 2, 3])
        
        loss_gamma_0 = F.focal_loss(input, target, alpha=0.25, gamma=0.0)
        loss_gamma_2 = F.focal_loss(input, target, alpha=0.25, gamma=2.0)
        loss_gamma_5 = F.focal_loss(input, target, alpha=0.25, gamma=5.0)
        
        # All should be positive
        assert float(loss_gamma_0.to_numpy()) > 0
        assert float(loss_gamma_2.to_numpy()) > 0
        assert float(loss_gamma_5.to_numpy()) > 0
        
        # Different gammas should give different losses
        assert not np.allclose(
            float(loss_gamma_0.to_numpy()),
            float(loss_gamma_2.to_numpy())
        )
    
    def test_invalid_alpha(self):
        """Test that invalid alpha raises error."""
        input = Tensor([[2.0, 1.0], [1.0, 2.0]])
        target = np.array([0, 1])
        
        with pytest.raises(ValueError, match="alpha must be in"):
            F.focal_loss(input, target, alpha=1.5, gamma=2.0)
        
        with pytest.raises(ValueError, match="alpha must be in"):
            F.focal_loss(input, target, alpha=-0.1, gamma=2.0)
    
    def test_invalid_gamma(self):
        """Test that invalid gamma raises error."""
        input = Tensor([[2.0, 1.0], [1.0, 2.0]])
        target = np.array([0, 1])
        
        with pytest.raises(ValueError, match="gamma must be non-negative"):
            F.focal_loss(input, target, alpha=0.25, gamma=-1.0)
    
    def test_invalid_reduction(self):
        """Test that invalid reduction raises error."""
        input = Tensor([[2.0, 1.0], [1.0, 2.0]])
        target = np.array([0, 1])
        
        with pytest.raises(ValueError, match="reduction must be one of"):
            F.focal_loss(input, target, alpha=0.25, gamma=2.0, reduction="invalid")


class TestFocalLossModule:
    """Test FocalLoss module wrapper."""
    
    def test_focal_loss_module_basic(self):
        """Test FocalLoss module creation and usage."""
        criterion = nn.FocalLoss(alpha=0.25, gamma=2.0)
        
        input = Tensor([[2.0, 1.0], [1.0, 2.0]])
        target = np.array([0, 1])
        
        loss = criterion(input, target)
        
        # Loss should be scalar and positive
        assert loss.shape == ()
        assert float(loss.to_numpy()) > 0
    
    def test_focal_loss_module_with_weights(self):
        """Test FocalLoss module with class weights."""
        weights = np.array([0.1, 0.2, 0.7])  # Class weights
        criterion = nn.FocalLoss(alpha=0.25, gamma=2.0, weight=weights)
        
        input = Tensor(np.random.randn(4, 3))
        target = np.array([0, 1, 2, 0])
        
        loss = criterion(input, target)
        
        # Loss should be scalar
        assert loss.shape == ()
    
    def test_focal_loss_module_ignore_index(self):
        """Test FocalLoss with ignore_index."""
        criterion = nn.FocalLoss(alpha=0.25, gamma=2.0, ignore_index=2)
        
        input = Tensor(np.random.randn(4, 3))
        target = np.array([0, 1, 2, 0])  # Index 2 should be ignored
        
        loss = criterion(input, target)
        
        # Loss should be computed only from non-ignored samples
        assert loss.shape == ()
        assert float(loss.to_numpy()) > 0
    
    def test_focal_loss_module_invalid_alpha(self):
        """Test that invalid alpha in module raises error."""
        with pytest.raises(ValueError, match="alpha must be in"):
            nn.FocalLoss(alpha=1.5, gamma=2.0)
    
    def test_focal_loss_module_invalid_gamma(self):
        """Test that invalid gamma in module raises error."""
        with pytest.raises(ValueError, match="gamma must be non-negative"):
            nn.FocalLoss(alpha=0.25, gamma=-1.0)


class TestFocalLossGradients:
    """Test gradient computation for focal loss."""
    
    def test_focal_loss_requires_grad(self):
        """Test that focal loss propagates gradients."""
        input = Tensor(np.random.randn(4, 3), requires_grad=True)
        target = np.array([0, 1, 2, 0])
        
        loss = F.focal_loss(input, target, alpha=0.25, gamma=2.0)
        loss.backward()
        
        # Gradients should be computed
        assert input.grad is not None
        assert input.grad.shape == input.shape
        assert not np.all(input.grad == 0)
    
    def test_focal_loss_numerical_gradient(self):
        """Test numerical gradient verification for focal loss."""
        np.random.seed(42)
        input_data = np.random.randn(2, 3).astype(np.float32)
        target = np.array([0, 2])
        
        eps = 1e-4
        
        # Forward pass
        input = Tensor(input_data.copy(), requires_grad=True)
        loss = F.focal_loss(input, target, alpha=0.25, gamma=2.0)
        loss.backward()
        analytical_grad = input.grad.copy()
        
        # Numerical gradients
        numerical_grad = np.zeros_like(input_data)
        for i in range(input_data.shape[0]):
            for j in range(input_data.shape[1]):
                # Forward difference
                input_data_plus = input_data.copy()
                input_data_plus[i, j] += eps
                input_plus = Tensor(input_data_plus)
                loss_plus = F.focal_loss(input_plus, target, alpha=0.25, gamma=2.0)
                
                input_data_minus = input_data.copy()
                input_data_minus[i, j] -= eps
                input_minus = Tensor(input_data_minus)
                loss_minus = F.focal_loss(input_minus, target, alpha=0.25, gamma=2.0)
                
                numerical_grad[i, j] = (float(loss_plus.to_numpy()) - float(loss_minus.to_numpy())) / (2 * eps)
        
        # Compare (with tolerance for numerical errors)
        assert np.allclose(analytical_grad, numerical_grad, rtol=1e-3, atol=1e-4)


class TestFocalLossEdgeCases:
    """Test edge cases for focal loss."""
    
    def test_single_sample(self):
        """Test focal loss with single sample."""
        input = Tensor([[10.0, 0.1, 0.1]])  # 1 sample, 3 classes
        target = np.array([0])
        
        loss = F.focal_loss(input, target, alpha=0.25, gamma=2.0)
        
        assert loss.shape == ()
        assert float(loss.to_numpy()) < 0.01  # Should be small for correct prediction
    
    def test_large_batch(self):
        """Test focal loss with large batch."""
        batch_size = 1000
        num_classes = 10
        input = Tensor(np.random.randn(batch_size, num_classes))
        target = np.random.randint(0, num_classes, batch_size)
        
        loss = F.focal_loss(input, target, alpha=0.25, gamma=2.0)
        
        assert loss.shape == ()
        assert float(loss.to_numpy()) > 0
    
    def test_imbalanced_classes(self):
        """Test focal loss with highly imbalanced classes."""
        # 95 easy negatives (class 0), 5 hard positives (class 1)
        input = np.zeros((100, 2))
        input[:95, 0] = 10.0  # High confidence for class 0
        input[95:, 1] = -10.0  # Misclassified as class 1
        
        input = Tensor(input)
        target = np.concatenate([np.zeros(95, dtype=int), np.ones(5, dtype=int)])
        
        loss = F.focal_loss(input, target, alpha=0.25, gamma=2.0)
        
        # Loss should focus on the 5 hard examples
        assert float(loss.to_numpy()) > 0
    
    def test_all_wrong_predictions(self):
        """Test focal loss when all predictions are wrong."""
        input = Tensor([[-10.0, 10.0], [10.0, -10.0]])  # Wrong class
        target = np.array([0, 0])  # Both should be class 0
        
        loss = F.focal_loss(input, target, alpha=0.25, gamma=2.0)
        
        # Loss should be large for wrong predictions
        assert float(loss.to_numpy()) > 1.0
    
    def test_ignore_index_all(self):
        """Test focal loss when all samples are ignored."""
        input = Tensor([[2.0, 1.0], [1.0, 2.0]])
        target = np.array([2, 2])  # All ignored
        
        loss = F.focal_loss(input, target, alpha=0.25, gamma=2.0, ignore_index=2)
        
        # Loss should be 0 (or very small) when nothing is computed
        assert float(loss.to_numpy()) <= 1e-6


class TestFocalLossComparison:
    """Test focal loss compared with other losses."""
    
    def test_focal_emphasizes_hard_samples(self):
        """Test that focal loss emphasizes hard samples more than cross entropy."""
        # Create two predictions: one easy, one hard
        easy_logits = Tensor([[10.0, -10.0]])  # Easy: high confidence correct
        hard_logits = Tensor([[0.1, -0.1]])    # Hard: low confidence
        target_easy = np.array([0])
        target_hard = np.array([0])
        
        focal_easy = F.focal_loss(easy_logits, target_easy, alpha=0.25, gamma=2.0)
        focal_hard = F.focal_loss(hard_logits, target_hard, alpha=0.25, gamma=2.0)
        
        ce_easy = F.cross_entropy(easy_logits, target_easy)
        ce_hard = F.cross_entropy(hard_logits, target_hard)
        
        # Focal loss should reduce the easy example loss more than cross entropy
        focal_ratio = float(focal_hard.to_numpy()) / (float(focal_easy.to_numpy()) + 1e-8)
        ce_ratio = float(ce_hard.to_numpy()) / (float(ce_easy.to_numpy()) + 1e-8)
        
        # Focal loss should have higher ratio (focus on hard examples)
        assert focal_ratio > ce_ratio
    
    def test_focal_loss_properties(self):
        """Test mathematical properties of focal loss."""
        input = Tensor(np.random.randn(10, 5))
        target = np.random.randint(0, 5, 10)
        
        # Test monotonicity: better predictions -> lower loss
        loss1 = F.focal_loss(input, target, alpha=0.25, gamma=2.0)
        
        # Increase logits for correct classes
        input_improved = input.clone()
        for i in range(len(target)):
            input_improved_data = input_improved.to_numpy()
            input_improved_data[i, target[i]] += 5.0
            input_improved.data = input_improved_data.copy()
        
        loss2 = F.focal_loss(input_improved, target, alpha=0.25, gamma=2.0)
        
        # Improved predictions should have lower loss
        assert float(loss2.to_numpy()) < float(loss1.to_numpy())


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
