"""
Learning Rate Schedulers for optimizers.
"""
import math
from typing import List


class _LRScheduler:
    """Base class for learning rate schedulers.
    
    Args:
        optimizer: Wrapped optimizer
        last_epoch: The index of last epoch (default: -1)
    """
    
    def __init__(self, optimizer, last_epoch=-1):
        self.optimizer = optimizer
        self.last_epoch = last_epoch
        
        # Store base learning rate
        if not isinstance(optimizer.lr, (list, tuple)):
            self.base_lrs = [optimizer.lr]
        else:
            self.base_lrs = list(optimizer.lr)
        
        self.step()
    
    def state_dict(self):
        """Return the state of the scheduler as a dict."""
        return {
            'last_epoch': self.last_epoch,
            'base_lrs': self.base_lrs,
        }
    
    def load_state_dict(self, state_dict):
        """Load the scheduler's state."""
        self.last_epoch = state_dict['last_epoch']
        self.base_lrs = state_dict['base_lrs']
    
    def get_lr(self):
        """Compute learning rate. Should be overridden by subclasses."""
        raise NotImplementedError
    
    def step(self, epoch=None):
        """Update learning rate after each epoch.
        
        Args:
            epoch: Current epoch. If None, increment last_epoch.
        """
        if epoch is None:
            self.last_epoch += 1
        else:
            self.last_epoch = epoch
        
        lr = self.get_lr()
        self.optimizer.lr = lr


class StepLR(_LRScheduler):
    """Decays learning rate by gamma every step_size epochs.
    
    Args:
        optimizer: Wrapped optimizer
        step_size: Period of learning rate decay
        gamma: Multiplicative factor of learning rate decay (default: 0.1)
        last_epoch: The index of last epoch (default: -1)
    
    Example:
        >>> # Decay LR by 0.1 every 30 epochs
        >>> scheduler = StepLR(optimizer, step_size=30, gamma=0.1)
        >>> for epoch in range(100):
        >>>     train(...)
        >>>     validate(...)
        >>>     scheduler.step()
    """
    
    def __init__(self, optimizer, step_size, gamma=0.1, last_epoch=-1):
        self.step_size = step_size
        self.gamma = gamma
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self):
        """Calculate learning rate."""
        if self.last_epoch == 0:
            return self.base_lrs[0]
        
        if self.last_epoch % self.step_size == 0:
            return self.optimizer.lr * self.gamma
        
        return self.optimizer.lr


class ExponentialLR(_LRScheduler):
    """Decays learning rate by gamma every epoch.
    
    Args:
        optimizer: Wrapped optimizer
        gamma: Multiplicative factor of learning rate decay
        last_epoch: The index of last epoch (default: -1)
    
    Example:
        >>> # Decay LR by 0.95 every epoch
        >>> scheduler = ExponentialLR(optimizer, gamma=0.95)
        >>> for epoch in range(100):
        >>>     train(...)
        >>>     validate(...)
        >>>     scheduler.step()
    """
    
    def __init__(self, optimizer, gamma, last_epoch=-1):
        self.gamma = gamma
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self):
        """Calculate learning rate."""
        if self.last_epoch == 0:
            return self.base_lrs[0]
        
        return self.optimizer.lr * self.gamma


class CosineAnnealingLR(_LRScheduler):
    """Set learning rate using cosine annealing schedule.
    
    The learning rate is annealed from initial lr to eta_min using cosine curve.
    
    Args:
        optimizer: Wrapped optimizer
        T_max: Maximum number of iterations
        eta_min: Minimum learning rate (default: 0)
        last_epoch: The index of last epoch (default: -1)
    
    Example:
        >>> # Anneal LR from initial to 0 over 100 epochs
        >>> scheduler = CosineAnnealingLR(optimizer, T_max=100)
        >>> for epoch in range(100):
        >>>     train(...)
        >>>     validate(...)
        >>>     scheduler.step()
    """
    
    def __init__(self, optimizer, T_max, eta_min=0, last_epoch=-1):
        self.T_max = T_max
        self.eta_min = eta_min
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self):
        """Calculate learning rate using cosine annealing."""
        if self.last_epoch == 0:
            return self.base_lrs[0]
        
        # Cosine annealing formula
        return self.eta_min + (self.base_lrs[0] - self.eta_min) * \
               (1 + math.cos(math.pi * self.last_epoch / self.T_max)) / 2


class CosineAnnealingWarmRestarts(_LRScheduler):
    """Set learning rate using cosine annealing with warm restarts.
    
    Args:
        optimizer: Wrapped optimizer
        T_0: Number of iterations for the first restart
        T_mult: Factor to increase T_i after a restart (default: 1)
        eta_min: Minimum learning rate (default: 0)
        last_epoch: The index of last epoch (default: -1)
    
    Example:
        >>> # Restart every 10 epochs, then 20, then 40, etc.
        >>> scheduler = CosineAnnealingWarmRestarts(optimizer, T_0=10, T_mult=2)
        >>> for epoch in range(100):
        >>>     train(...)
        >>>     validate(...)
        >>>     scheduler.step()
    """
    
    def __init__(self, optimizer, T_0, T_mult=1, eta_min=0, last_epoch=-1):
        self.T_0 = T_0
        self.T_mult = T_mult
        self.eta_min = eta_min
        self.T_cur = 0
        self.T_i = T_0
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self):
        """Calculate learning rate with warm restarts."""
        if self.last_epoch == 0:
            self.T_cur = 0
            self.T_i = self.T_0
            return self.base_lrs[0]
        
        self.T_cur += 1
        
        # Check if we need to restart
        if self.T_cur >= self.T_i:
            self.T_cur = 0
            self.T_i = self.T_i * self.T_mult
        
        # Cosine annealing within current period
        return self.eta_min + (self.base_lrs[0] - self.eta_min) * \
               (1 + math.cos(math.pi * self.T_cur / self.T_i)) / 2


class ReduceLROnPlateau:
    """Reduce learning rate when a metric has stopped improving.
    
    Args:
        optimizer: Wrapped optimizer
        mode: 'min' or 'max'. In 'min' mode, lr will be reduced when metric stops decreasing
        factor: Factor by which learning rate will be reduced (default: 0.1)
        patience: Number of epochs with no improvement after which lr will be reduced (default: 10)
        threshold: Threshold for measuring new optimum (default: 1e-4)
        threshold_mode: 'rel' or 'abs' (default: 'rel')
        cooldown: Number of epochs to wait before resuming normal operation (default: 0)
        min_lr: Lower bound on learning rate (default: 0)
        eps: Minimal decay applied to lr (default: 1e-8)
    
    Example:
        >>> scheduler = ReduceLROnPlateau(optimizer, mode='min', patience=5)
        >>> for epoch in range(100):
        >>>     train(...)
        >>>     val_loss = validate(...)
        >>>     scheduler.step(val_loss)
    """
    
    def __init__(self, optimizer, mode='min', factor=0.1, patience=10,
                 threshold=1e-4, threshold_mode='rel', cooldown=0,
                 min_lr=0, eps=1e-8):
        if factor >= 1.0:
            raise ValueError('Factor should be < 1.0')
        
        self.optimizer = optimizer
        self.mode = mode
        self.factor = factor
        self.patience = patience
        self.threshold = threshold
        self.threshold_mode = threshold_mode
        self.cooldown = cooldown
        self.min_lr = min_lr
        self.eps = eps
        
        self.cooldown_counter = 0
        self.best = None
        self.num_bad_epochs = 0
        self.mode_worse = float('inf') if mode == 'min' else -float('inf')
        self.last_epoch = 0
    
    def state_dict(self):
        """Return the state of the scheduler as a dict."""
        return {
            'best': self.best,
            'cooldown_counter': self.cooldown_counter,
            'num_bad_epochs': self.num_bad_epochs,
            'last_epoch': self.last_epoch,
        }
    
    def load_state_dict(self, state_dict):
        """Load the scheduler's state."""
        self.best = state_dict['best']
        self.cooldown_counter = state_dict['cooldown_counter']
        self.num_bad_epochs = state_dict['num_bad_epochs']
        self.last_epoch = state_dict['last_epoch']
    
    def _is_better(self, current, best):
        """Check if current metric is better than best."""
        if self.mode == 'min' and self.threshold_mode == 'rel':
            return current < best - best * self.threshold
        elif self.mode == 'min' and self.threshold_mode == 'abs':
            return current < best - self.threshold
        elif self.mode == 'max' and self.threshold_mode == 'rel':
            return current > best + best * self.threshold
        else:  # mode == 'max' and threshold_mode == 'abs'
            return current > best + self.threshold
    
    def step(self, metrics):
        """Update learning rate based on metric.
        
        Args:
            metrics: Current metric value
        """
        current = float(metrics)
        self.last_epoch += 1
        
        if self.best is None:
            self.best = current
        elif self._is_better(current, self.best):
            self.best = current
            self.num_bad_epochs = 0
        else:
            self.num_bad_epochs += 1
        
        if self.cooldown_counter > 0:
            self.cooldown_counter -= 1
            self.num_bad_epochs = 0
        
        if self.num_bad_epochs > self.patience:
            self._reduce_lr()
            self.cooldown_counter = self.cooldown
            self.num_bad_epochs = 0
    
    def _reduce_lr(self):
        """Reduce learning rate."""
        old_lr = self.optimizer.lr
        new_lr = max(old_lr * self.factor, self.min_lr)
        
        if old_lr - new_lr > self.eps:
            self.optimizer.lr = new_lr


class LinearLR(_LRScheduler):
    """Linearly changes learning rate from start_factor to end_factor.
    
    Args:
        optimizer: Wrapped optimizer
        start_factor: The number we multiply learning rate in first epoch (default: 1./3)
        end_factor: The number we multiply learning rate at the end (default: 1.0)
        total_iters: The number of iterations to reach end_factor (default: 5)
        last_epoch: The index of last epoch (default: -1)
    
    Example:
        >>> # Linearly warmup LR from 0.1 to 1.0 over first 5 epochs
        >>> scheduler = LinearLR(optimizer, start_factor=0.1, total_iters=5)
        >>> for epoch in range(100):
        >>>     train(...)
        >>>     scheduler.step()
    """
    
    def __init__(self, optimizer, start_factor=1.0/3, end_factor=1.0, total_iters=5, last_epoch=-1):
        self.start_factor = start_factor
        self.end_factor = end_factor
        self.total_iters = total_iters
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self):
        """Calculate learning rate."""
        if self.last_epoch == 0:
            return self.base_lrs[0] * self.start_factor
        
        if self.last_epoch > self.total_iters:
            return self.base_lrs[0] * self.end_factor
        
        # Linear interpolation
        return self.base_lrs[0] * (self.start_factor + 
                                    (self.end_factor - self.start_factor) * 
                                    self.last_epoch / self.total_iters)


class LambdaLR(_LRScheduler):
    """Sets learning rate using a user-defined lambda function.
    
    Args:
        optimizer: Wrapped optimizer
        lr_lambda: A function which computes a multiplicative factor given an integer epoch
        last_epoch: The index of last epoch (default: -1)
    
    Example:
        >>> # Multiply LR by 0.95 every epoch
        >>> lambda_fn = lambda epoch: 0.95 ** epoch
        >>> scheduler = LambdaLR(optimizer, lr_lambda=lambda_fn)
        >>> for epoch in range(100):
        >>>     train(...)
        >>>     scheduler.step()
    """
    
    def __init__(self, optimizer, lr_lambda, last_epoch=-1):
        self.lr_lambda = lr_lambda
        super().__init__(optimizer, last_epoch)
    
    def get_lr(self):
        """Calculate learning rate using lambda function."""
        return self.base_lrs[0] * self.lr_lambda(self.last_epoch)
