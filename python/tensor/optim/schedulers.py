"""
Learning Rate Schedulers for optimization.

Schedulers adjust learning rate during training:
- StepLR: Step-based decay
- ExponentialLR: Exponential decay
- CosineAnnealingLR: Cosine annealing
- ReduceLROnPlateau: Adaptive reduction
- WarmupLR: Linear warmup
- LinearLR: Linear decay
- MultiplicativeLR: Multiplicative decay
"""

import numpy as np
import math
from typing import Optional, Callable, List


class LRScheduler:
    """Base class for learning rate schedulers."""
    
    def __init__(self, optimizer, last_epoch: int = -1):
        self.optimizer = optimizer
        self.last_epoch = last_epoch
        self.base_lrs = [group['lr'] for group in optimizer.param_groups]
        
        # Initialize
        self.step()
    
    def get_lr(self) -> List[float]:
        """Compute learning rates."""
        raise NotImplementedError
    
    def step(self, epoch: Optional[int] = None):
        """Update learning rate."""
        if epoch is None:
            epoch = self.last_epoch + 1
        self.last_epoch = epoch
        
        lrs = self.get_lr()
        for param_group, lr in zip(self.optimizer.param_groups, lrs):
            param_group['lr'] = lr


class StepLR(LRScheduler):
    """
    Step Decay: multiply LR by gamma every step_size epochs.
    
    Args:
        optimizer: Optimizer instance
        step_size (int): Period of learning rate decay
        gamma (float): Multiplicative factor. Default: 0.1
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(self, optimizer, step_size: int, gamma: float = 0.1, last_epoch: int = -1):
        self.step_size = step_size
        self.gamma = gamma
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute learning rates."""
        return [base_lr * self.gamma ** (self.last_epoch // self.step_size)
                for base_lr in self.base_lrs]


class ExponentialLR(LRScheduler):
    """
    Exponential Decay: lr = base_lr * gamma^epoch.
    
    Args:
        optimizer: Optimizer instance
        gamma (float): Decay factor
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(self, optimizer, gamma: float, last_epoch: int = -1):
        self.gamma = gamma
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute learning rates."""
        return [base_lr * self.gamma ** self.last_epoch
                for base_lr in self.base_lrs]


class CosineAnnealingLR(LRScheduler):
    """
    Cosine Annealing: decrease LR following cosine curve.
    
    Args:
        optimizer: Optimizer instance
        T_max (int): Maximum number of iterations
        eta_min (float): Minimum learning rate. Default: 0
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(self, optimizer, T_max: int, eta_min: float = 0, last_epoch: int = -1):
        self.T_max = T_max
        self.eta_min = eta_min
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute learning rates using cosine curve."""
        return [self.eta_min + (base_lr - self.eta_min) * 
                (1 + math.cos(math.pi * self.last_epoch / self.T_max)) / 2
                for base_lr in self.base_lrs]


class CosineAnnealingWarmRestarts(LRScheduler):
    """
    Cosine Annealing with Warm Restarts.
    
    Args:
        optimizer: Optimizer instance
        T_0 (int): Initial period for cosine
        T_mult (float): Period multiplier after restart. Default: 1
        eta_min (float): Minimum learning rate. Default: 0
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(
        self,
        optimizer,
        T_0: int,
        T_mult: float = 1,
        eta_min: float = 0,
        last_epoch: int = -1
    ):
        self.T_0 = T_0
        self.T_mult = T_mult
        self.eta_min = eta_min
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute learning rates with warm restarts."""
        # Find current period and position
        T_cur = self.last_epoch
        T_i = self.T_0
        T_total = 0
        
        while T_cur >= T_i:
            T_cur -= T_i
            T_total += T_i
            T_i = int(T_i * self.T_mult)
        
        return [self.eta_min + (base_lr - self.eta_min) * 
                (1 + math.cos(math.pi * T_cur / T_i)) / 2
                for base_lr in self.base_lrs]


class LinearLR(LRScheduler):
    """
    Linear Decay: linearly decrease LR from initial to final value.
    
    Args:
        optimizer: Optimizer instance
        start_factor (float): Initial learning rate multiplier. Default: 1.0
        total_iters (int): Total iterations for decay
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(self, optimizer, start_factor: float = 1.0, total_iters: int = 5, last_epoch: int = -1):
        self.start_factor = start_factor
        self.total_iters = total_iters
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute linearly decayed learning rates."""
        if self.last_epoch == 0:
            return [base_lr * self.start_factor for base_lr in self.base_lrs]
        
        progress = self.last_epoch / self.total_iters
        return [base_lr * (self.start_factor + (1 - self.start_factor) * progress)
                for base_lr in self.base_lrs]


class PolynomialLR(LRScheduler):
    """
    Polynomial Decay: decrease LR following polynomial curve.
    
    Args:
        optimizer: Optimizer instance
        total_iters (int): Total iterations
        power (float): Power of polynomial. Default: 1.0 (linear)
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(self, optimizer, total_iters: int, power: float = 1.0, last_epoch: int = -1):
        self.total_iters = total_iters
        self.power = power
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute polynomially decayed learning rates."""
        progress = self.last_epoch / self.total_iters
        return [base_lr * (1 - progress) ** self.power
                for base_lr in self.base_lrs]


class MultiplicativeLR(LRScheduler):
    """
    Multiplicative LR: multiply LR by a factor computed by a function.
    
    Args:
        optimizer: Optimizer instance
        lmbda (Callable): Function that computes multiplicative factor
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(self, optimizer, lmbda: Callable, last_epoch: int = -1):
        self.lmbda = lmbda
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute learning rates using lambda function."""
        return [base_lr * self.lmbda(self.last_epoch)
                for base_lr in self.base_lrs]


class LambdaLR(LRScheduler):
    """
    Lambda LR: multiply LR by function of epoch.
    
    Args:
        optimizer: Optimizer instance
        lr_lambda (Callable): Function that returns LR multiplier
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(self, optimizer, lr_lambda: Callable, last_epoch: int = -1):
        self.lr_lambda = lr_lambda
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute learning rates using lambda."""
        return [base_lr * self.lr_lambda(self.last_epoch)
                for base_lr in self.base_lrs]


class ReduceLROnPlateau:
    """
    Reduce LR when a metric stops improving.
    
    Args:
        optimizer: Optimizer instance
        mode (str): 'min' or 'max'. Default: 'min'
        factor (float): Multiplicative factor. Default: 0.1
        patience (int): Number of epochs with no improvement. Default: 10
        threshold (float): Threshold for improvement. Default: 1e-4
        cooldown (int): Cooldown epochs. Default: 0
        min_lr (float): Minimum learning rate. Default: 0
        eps (float): Threshold for numerical equivalence. Default: 1e-8
    """
    
    def __init__(
        self,
        optimizer,
        mode: str = 'min',
        factor: float = 0.1,
        patience: int = 10,
        threshold: float = 1e-4,
        cooldown: int = 0,
        min_lr: float = 0,
        eps: float = 1e-8
    ):
        self.optimizer = optimizer
        self.mode = mode
        self.factor = factor
        self.patience = patience
        self.threshold = threshold
        self.cooldown = cooldown
        self.min_lr = min_lr
        self.eps = eps
        
        self.best = None
        self.wait_count = 0
        self.cooldown_count = 0
        
        if mode == 'min':
            self.best = float('inf')
        else:
            self.best = float('-inf')
    
    def step(self, metric: float):
        """
        Update learning rate based on metric.
        
        Args:
            metric (float): Metric value to monitor
        """
        if self.cooldown_count > 0:
            self.cooldown_count -= 1
            self.wait_count = 0
            return
        
        # Check for improvement
        if self.mode == 'min':
            improved = metric < self.best - self.threshold
        else:
            improved = metric > self.best + self.threshold
        
        if improved:
            self.best = metric
            self.wait_count = 0
        else:
            self.wait_count += 1
        
        # Reduce LR if no improvement
        if self.wait_count >= self.patience:
            self._reduce_lr()
            self.cooldown_count = self.cooldown
            self.wait_count = 0
    
    def _reduce_lr(self):
        """Reduce learning rate."""
        for param_group in self.optimizer.param_groups:
            old_lr = param_group['lr']
            new_lr = max(old_lr * self.factor, self.min_lr)
            param_group['lr'] = new_lr


class WarmupLR(LRScheduler):
    """
    Linear Warmup Scheduler.
    
    Linearly increase LR from 0 to base_lr over warmup_epochs.
    
    Args:
        optimizer: Optimizer instance
        warmup_epochs (int): Number of warmup epochs
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(self, optimizer, warmup_epochs: int, last_epoch: int = -1):
        self.warmup_epochs = warmup_epochs
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute warmup learning rates."""
        if self.last_epoch < self.warmup_epochs:
            return [base_lr * (self.last_epoch + 1) / self.warmup_epochs
                    for base_lr in self.base_lrs]
        else:
            return self.base_lrs


class WarmupDecayLR(LRScheduler):
    """
    Warmup followed by decay.
    
    Args:
        optimizer: Optimizer instance
        warmup_epochs (int): Number of warmup epochs
        total_epochs (int): Total training epochs
        decay_type (str): 'linear', 'cosine', or 'exponential'. Default: 'linear'
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(
        self,
        optimizer,
        warmup_epochs: int,
        total_epochs: int,
        decay_type: str = 'linear',
        last_epoch: int = -1
    ):
        self.warmup_epochs = warmup_epochs
        self.total_epochs = total_epochs
        self.decay_type = decay_type
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute warmup + decay learning rates."""
        if self.last_epoch < self.warmup_epochs:
            # Warmup phase
            return [base_lr * (self.last_epoch + 1) / self.warmup_epochs
                    for base_lr in self.base_lrs]
        else:
            # Decay phase
            progress = (self.last_epoch - self.warmup_epochs) / (self.total_epochs - self.warmup_epochs)
            
            if self.decay_type == 'linear':
                return [base_lr * (1 - progress) for base_lr in self.base_lrs]
            elif self.decay_type == 'cosine':
                return [base_lr * (1 + math.cos(math.pi * progress)) / 2
                        for base_lr in self.base_lrs]
            elif self.decay_type == 'exponential':
                return [base_lr * math.exp(-progress) for base_lr in self.base_lrs]


class StepDecayWithWarmup(LRScheduler):
    """
    Step decay with warmup phase.
    
    Args:
        optimizer: Optimizer instance
        warmup_epochs (int): Number of warmup epochs
        step_size (int): Step size for decay
        gamma (float): Decay factor. Default: 0.1
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(
        self,
        optimizer,
        warmup_epochs: int,
        step_size: int,
        gamma: float = 0.1,
        last_epoch: int = -1
    ):
        self.warmup_epochs = warmup_epochs
        self.step_size = step_size
        self.gamma = gamma
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute learning rates."""
        if self.last_epoch < self.warmup_epochs:
            # Warmup
            return [base_lr * (self.last_epoch + 1) / self.warmup_epochs
                    for base_lr in self.base_lrs]
        else:
            # Step decay
            decay_epoch = self.last_epoch - self.warmup_epochs
            return [base_lr * self.gamma ** (decay_epoch // self.step_size)
                    for base_lr in self.base_lrs]


class CyclicLR(LRScheduler):
    """
    Cyclic Learning Rate Schedule.
    
    Cycles learning rate between base_lr and max_lr.
    
    Args:
        optimizer: Optimizer instance
        base_lr (float): Initial learning rate
        max_lr (float): Maximum learning rate
        step_size (int): Step size for half a cycle
        mode (str): 'triangular', 'triangular2', or 'exp_range'. Default: 'triangular'
        gamma (float): Gamma parameter for exp_range. Default: 1.0
        last_epoch (int): Last epoch number. Default: -1
    """
    
    def __init__(
        self,
        optimizer,
        base_lr: float,
        max_lr: float,
        step_size: int,
        mode: str = 'triangular',
        gamma: float = 1.0,
        last_epoch: int = -1
    ):
        self.base_lr = base_lr
        self.max_lr = max_lr
        self.step_size = step_size
        self.mode = mode
        self.gamma = gamma
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute cyclic learning rates."""
        cycle = self.last_epoch // (2 * self.step_size)
        x = abs(self.last_epoch % (2 * self.step_size) - self.step_size) / self.step_size
        
        if self.mode == 'triangular':
            lr_mult = 1 - x
        elif self.mode == 'triangular2':
            lr_mult = (1 - x) / (2.0 ** (cycle - 1))
        elif self.mode == 'exp_range':
            lr_mult = (1 - x) * (self.gamma ** self.last_epoch)
        
        return [self.base_lr + (self.max_lr - self.base_lr) * lr_mult
                for _ in self.base_lrs]


class OneCycleLR(LRScheduler):
    """
    One Cycle Learning Rate Schedule.
    
    Args:
        optimizer: Optimizer instance
        max_lr (float): Maximum learning rate
        total_steps (int): Total number of steps
        pct_start (float): Percentage of steps increasing. Default: 0.3
        anneal_strategy (str): 'cos' or 'linear'. Default: 'cos'
        div_factor (float): Initial LR = max_lr / div_factor. Default: 25.0
        final_div_factor (float): Final LR = max_lr / final_div_factor. Default: 10000.0
    """
    
    def __init__(
        self,
        optimizer,
        max_lr: float,
        total_steps: int,
        pct_start: float = 0.3,
        anneal_strategy: str = 'cos',
        div_factor: float = 25.0,
        final_div_factor: float = 10000.0,
        last_epoch: int = -1
    ):
        self.max_lr = max_lr
        self.total_steps = total_steps
        self.pct_start = pct_start
        self.anneal_strategy = anneal_strategy
        self.div_factor = div_factor
        self.final_div_factor = final_div_factor
        
        # Initialize base_lrs before calling parent __init__
        self.optimizer = optimizer
        self.base_lrs = [group['lr'] for group in optimizer.param_groups]
        self.last_epoch = last_epoch
        
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self) -> List[float]:
        """Compute one cycle learning rates."""
        initial_lr = self.max_lr / self.div_factor
        final_lr = self.max_lr / self.final_div_factor
        
        step_up = int(self.total_steps * self.pct_start)
        step_down = self.total_steps - step_up
        
        if self.last_epoch <= step_up:
            # Increasing phase
            progress = self.last_epoch / step_up
            if self.anneal_strategy == 'cos':
                return [initial_lr + (self.max_lr - initial_lr) * 
                        (1 - math.cos(math.pi * progress)) / 2
                        for _ in self.base_lrs]
            else:
                return [initial_lr + (self.max_lr - initial_lr) * progress
                        for _ in self.base_lrs]
        else:
            # Decreasing phase
            progress = (self.last_epoch - step_up) / step_down
            if self.anneal_strategy == 'cos':
                return [self.max_lr + (final_lr - self.max_lr) * 
                        (1 - math.cos(math.pi * progress)) / 2
                        for _ in self.base_lrs]
            else:
                return [self.max_lr + (final_lr - self.max_lr) * progress
                        for _ in self.base_lrs]
