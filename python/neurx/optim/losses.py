"""
Loss functions for training neural networks.

Includes:
- CrossEntropyLoss: Multi-class classification
- BCELoss, BCEWithLogitsLoss: Binary classification
- L1Loss, SmoothL1Loss: Regression
- KLDivLoss: Divergence
- NLLLoss: Negative log likelihood
- MSELoss: Mean squared error
"""

import numpy as np
from typing import Optional

from neurx.core.neurx import Tensor


class Loss:
    """Base class for loss functions."""
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """Compute loss value."""
        raise NotImplementedError


class CrossEntropyLoss(Loss):
    """
    Cross Entropy Loss for multi-class classification.
    
    Combines LogSoftmax and NLLLoss in a single class.
    
    Args:
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
        ignore_index (int): Target value to ignore. Default: -100
        label_smoothing (float): Label smoothing factor. Default: 0.0
    """
    
    def __init__(
        self,
        reduction: str = 'mean',
        ignore_index: int = -100,
        label_smoothing: float = 0.0
    ):
        self.reduction = reduction
        self.ignore_index = ignore_index
        self.label_smoothing = label_smoothing
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input (Tensor): (batch_size, num_classes) or (batch_size, num_classes, ...)
            target (Tensor): (batch_size,) or (batch_size, ...) with class indices
        
        Returns:
            Tensor: Scalar loss value
        """
        # Reshape inputs
        batch_size = input.shape[0]
        num_classes = input.shape[1]
        
        # Flatten if needed
        if len(input.shape) > 2:
            input_flat = input.data.reshape(-1, num_classes)
            target_flat = target.data.flatten()
        else:
            input_flat = input.data
            target_flat = target.data.astype(int)
        
        # Compute softmax
        input_max = np.max(input_flat, axis=1, keepdims=True)
        exp_input = np.exp(input_flat - input_max)
        softmax = exp_input / np.sum(exp_input, axis=1, keepdims=True)
        
        # Label smoothing
        if self.label_smoothing > 0:
            smoothed = (1 - self.label_smoothing) * np.eye(num_classes)[target_flat.astype(int)]
            smoothed += self.label_smoothing / num_classes
            target_one_hot = smoothed
        else:
            target_one_hot = np.eye(num_classes)[target_flat.astype(int)]
        
        # Compute cross entropy
        log_softmax = np.log(softmax + 1e-10)
        loss = -np.sum(target_one_hot * log_softmax, axis=1)
        
        # Apply ignore index
        if self.ignore_index >= 0:
            mask = target_flat != self.ignore_index
            loss = loss[mask]
        
        # Reduction
        if self.reduction == 'mean':
            loss = np.mean(loss) if len(loss) > 0 else np.array(0.0)
        elif self.reduction == 'sum':
            loss = np.sum(loss)
        else:
            loss = loss.reshape(target.shape)
        
        return Tensor(loss, requires_grad=True)


class BCELoss(Loss):
    """
    Binary Cross Entropy Loss.
    
    Args:
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
    """
    
    def __init__(self, reduction: str = 'mean'):
        self.reduction = reduction
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input (Tensor): Predicted probabilities in range [0, 1]
            target (Tensor): Binary targets (0 or 1)
        
        Returns:
            Tensor: Loss value
        """
        # Clamp input to avoid log(0)
        input_clipped = np.clip(input.data, 1e-7, 1 - 1e-7)
        
        # Binary cross entropy
        loss = -(target.data * np.log(input_clipped) + 
                 (1 - target.data) * np.log(1 - input_clipped))
        
        # Reduction
        if self.reduction == 'mean':
            loss = np.mean(loss)
        elif self.reduction == 'sum':
            loss = np.sum(loss)
        else:
            pass  # return as is
        
        return Tensor(loss, requires_grad=True)


class BCEWithLogitsLoss(Loss):
    """
    Binary Cross Entropy with Logits Loss.
    
    Combines sigmoid and BCELoss for numerical stability.
    
    Args:
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
        pos_weight (Optional[Tensor]): Weight for positive class. Default: None
    """
    
    def __init__(self, reduction: str = 'mean', pos_weight: Optional[Tensor] = None):
        self.reduction = reduction
        self.pos_weight = pos_weight
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input (Tensor): Raw model output (logits)
            target (Tensor): Binary targets (0 or 1)
        
        Returns:
            Tensor: Loss value
        """
        # Numerically stable BCE with logits
        # loss = max(x, 0) - x * z + log(1 + exp(-|x|))
        abs_input = np.abs(input.data)
        neg_abs_input = -abs_input
        
        loss = np.maximum(input.data, 0) - input.data * target.data + np.log(1 + np.exp(neg_abs_input))
        
        # Apply positive weight if provided
        if self.pos_weight is not None:
            loss = loss * (self.pos_weight.data * target.data + (1 - target.data))
        
        # Reduction
        if self.reduction == 'mean':
            loss = np.mean(loss)
        elif self.reduction == 'sum':
            loss = np.sum(loss)
        
        return Tensor(loss, requires_grad=True)


class L1Loss(Loss):
    """
    L1 Loss (Mean Absolute Error).
    
    Args:
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
    """
    
    def __init__(self, reduction: str = 'mean'):
        self.reduction = reduction
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input (Tensor): Predicted values
            target (Tensor): Target values
        
        Returns:
            Tensor: Loss value
        """
        loss = np.abs(input.data - target.data)
        
        if self.reduction == 'mean':
            loss = np.mean(loss)
        elif self.reduction == 'sum':
            loss = np.sum(loss)
        
        return Tensor(loss, requires_grad=True)


class MSELoss(Loss):
    """
    Mean Squared Error Loss.
    
    Args:
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
    """
    
    def __init__(self, reduction: str = 'mean'):
        self.reduction = reduction
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input (Tensor): Predicted values
            target (Tensor): Target values
        
        Returns:
            Tensor: Loss value
        """
        loss = (input.data - target.data) ** 2
        
        if self.reduction == 'mean':
            loss = np.mean(loss)
        elif self.reduction == 'sum':
            loss = np.sum(loss)
        
        return Tensor(loss, requires_grad=True)


class SmoothL1Loss(Loss):
    """
    Smooth L1 Loss (Huber Loss).
    
    Combines L1 and L2 loss for robustness.
    
    Args:
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
        beta (float): Threshold for switching between L1 and L2. Default: 1.0
    """
    
    def __init__(self, reduction: str = 'mean', beta: float = 1.0):
        self.reduction = reduction
        self.beta = beta
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input (Tensor): Predicted values
            target (Tensor): Target values
        
        Returns:
            Tensor: Loss value
        """
        diff = np.abs(input.data - target.data)
        
        # Smooth L1
        loss = np.where(
            diff < self.beta,
            0.5 * (diff ** 2) / self.beta,
            diff - 0.5 * self.beta
        )
        
        if self.reduction == 'mean':
            loss = np.mean(loss)
        elif self.reduction == 'sum':
            loss = np.sum(loss)
        
        return Tensor(loss, requires_grad=True)


class KLDivLoss(Loss):
    """
    Kullback-Leibler Divergence Loss.
    
    Args:
        reduction (str): 'mean', 'sum', 'batchmean', or 'none'. Default: 'mean'
    """
    
    def __init__(self, reduction: str = 'mean'):
        self.reduction = reduction
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input (Tensor): Log probabilities from model (after log_softmax)
            target (Tensor): Target probabilities
        
        Returns:
            Tensor: KL divergence
        """
        # KL divergence: sum(target * (log(target) - input))
        target_clipped = np.clip(target.data, 1e-10, 1.0)
        
        kl_div = target.data * (np.log(target_clipped) - input.data)
        
        if self.reduction == 'mean':
            loss = np.mean(kl_div)
        elif self.reduction == 'sum':
            loss = np.sum(kl_div)
        elif self.reduction == 'batchmean':
            loss = np.sum(kl_div) / kl_div.shape[0]
        else:
            loss = kl_div
        
        return Tensor(loss, requires_grad=True)


class NLLLoss(Loss):
    """
    Negative Log Likelihood Loss.
    
    Args:
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
        ignore_index (int): Target value to ignore. Default: -100
    """
    
    def __init__(self, reduction: str = 'mean', ignore_index: int = -100):
        self.reduction = reduction
        self.ignore_index = ignore_index
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input (Tensor): Log probabilities (after log_softmax)
            target (Tensor): Target class indices
        
        Returns:
            Tensor: Loss value
        """
        batch_size = input.shape[0]
        num_classes = input.shape[1] if len(input.shape) > 1 else 1
        
        # Flatten
        input_flat = input.data.reshape(-1, num_classes) if len(input.shape) > 2 else input.data
        target_flat = target.data.flatten().astype(int)
        
        # Select log probabilities at target indices
        batch_idx = np.arange(len(target_flat))
        loss = -input_flat[batch_idx, target_flat]
        
        # Apply ignore index
        if self.ignore_index >= 0:
            mask = target_flat != self.ignore_index
            loss = loss[mask]
        
        # Reduction
        if self.reduction == 'mean':
            loss = np.mean(loss) if len(loss) > 0 else np.array(0.0)
        elif self.reduction == 'sum':
            loss = np.sum(loss)
        else:
            loss = loss.reshape(target.shape)
        
        return Tensor(loss, requires_grad=True)


class HuberLoss(Loss):
    """
    Huber Loss (alias for SmoothL1Loss).
    
    Args:
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
        delta (float): Threshold for switching between L1 and L2. Default: 1.0
    """
    
    def __init__(self, reduction: str = 'mean', delta: float = 1.0):
        self.reduction = reduction
        self.delta = delta
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input (Tensor): Predicted values
            target (Tensor): Target values
        
        Returns:
            Tensor: Loss value
        """
        diff = np.abs(input.data - target.data)
        
        loss = np.where(
            diff <= self.delta,
            0.5 * (diff ** 2),
            self.delta * (diff - 0.5 * self.delta)
        )
        
        if self.reduction == 'mean':
            loss = np.mean(loss)
        elif self.reduction == 'sum':
            loss = np.sum(loss)
        
        return Tensor(loss, requires_grad=True)


class PoissonNLLLoss(Loss):
    """
    Poisson Negative Log Likelihood Loss.
    
    Args:
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
        full (bool): Whether to include Stirling approximation. Default: False
    """
    
    def __init__(self, reduction: str = 'mean', full: bool = False):
        self.reduction = reduction
        self.full = full
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input (Tensor): Predicted rates (must be non-negative)
            target (Tensor): Target counts
        
        Returns:
            Tensor: Loss value
        """
        input_clipped = np.clip(input.data, 1e-10, None)
        
        # Poisson NLL: exp(input) - target * input
        loss = np.exp(input.data) - target.data * input.data
        
        if self.full:
            # Add Stirling approximation term
            loss = loss + target.data * np.log(target.data) - target.data
        
        if self.reduction == 'mean':
            loss = np.mean(loss)
        elif self.reduction == 'sum':
            loss = np.sum(loss)
        
        return Tensor(loss, requires_grad=True)


class CTCLoss(Loss):
    """
    Connectionist Temporal Classification Loss.
    
    Simplified implementation for sequence-to-sequence tasks.
    
    Args:
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
    """
    
    def __init__(self, reduction: str = 'mean'):
        self.reduction = reduction
    
    def __call__(self, input: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input (Tensor): Log probabilities of shape (T, N, C)
            target (Tensor): Target sequences
        
        Returns:
            Tensor: CTC loss (simplified)
        """
        # Simplified CTC: just use negative log likelihood at each timestep
        # Full CTC would require dynamic programming
        T, N, C = input.shape
        
        loss = 0.0
        for t in range(T):
            # Get log probabilities at time t
            log_probs = input.data[t]  # (N, C)
            # For simplified version, use mean NLL
            loss += -np.mean(log_probs)
        
        loss = loss / T
        
        if self.reduction == 'sum':
            loss = loss * N
        
        return Tensor(loss, requires_grad=True)


class MarginRankingLoss(Loss):
    """
    Margin Ranking Loss.
    
    For triplet-style losses and ranking problems.
    
    Args:
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
        margin (float): Margin parameter. Default: 1.0
    """
    
    def __init__(self, reduction: str = 'mean', margin: float = 1.0):
        self.reduction = reduction
        self.margin = margin
    
    def __call__(self, input1: Tensor, input2: Tensor, target: Tensor) -> Tensor:
        """
        Args:
            input1 (Tensor): First input
            input2 (Tensor): Second input
            target (Tensor): Target {-1, 1}
        
        Returns:
            Tensor: Loss value
        """
        # loss = max(0, -target * (input1 - input2) + margin)
        loss = np.maximum(0, -target.data * (input1.data - input2.data) + self.margin)
        
        if self.reduction == 'mean':
            loss = np.mean(loss)
        elif self.reduction == 'sum':
            loss = np.sum(loss)
        
        return Tensor(loss, requires_grad=True)


class TripletMarginLoss(Loss):
    """
    Triplet Margin Loss for metric learning.
    
    Args:
        margin (float): Margin parameter. Default: 1.0
        reduction (str): 'mean', 'sum', or 'none'. Default: 'mean'
    """
    
    def __init__(self, margin: float = 1.0, reduction: str = 'mean'):
        self.margin = margin
        self.reduction = reduction
    
    def __call__(self, anchor: Tensor, positive: Tensor, negative: Tensor) -> Tensor:
        """
        Args:
            anchor (Tensor): Anchor embeddings
            positive (Tensor): Positive embeddings
            negative (Tensor): Negative embeddings
        
        Returns:
            Tensor: Triplet loss
        """
        # Compute distances
        pos_dist = np.sum((anchor.data - positive.data) ** 2, axis=1)
        neg_dist = np.sum((anchor.data - negative.data) ** 2, axis=1)
        
        # Triplet loss: max(0, pos_dist - neg_dist + margin)
        loss = np.maximum(0, pos_dist - neg_dist + self.margin)
        
        if self.reduction == 'mean':
            loss = np.mean(loss)
        elif self.reduction == 'sum':
            loss = np.sum(loss)
        
        return Tensor(loss, requires_grad=True)
