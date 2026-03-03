"""
Optimizer Utilities and Learning Rate Scheduling Helpers

Provides utilities for optimizer management and learning rate scheduling strategies.
"""

import numpy as np


# ============================================================================
# Learning Rate Schedule Functions
# ============================================================================

def constant_lr(initial_lr):
    """
    Constant learning rate schedule
    
    Args:
        initial_lr: Initial learning rate
        
    Returns:
        function: Function that takes step number and returns learning rate
    """
    def schedule(step):
        return initial_lr
    return schedule


def step_lr(initial_lr, step_size, gamma=0.1):
    """
    Step learning rate schedule - reduces LR by gamma every step_size steps
    
    Args:
        initial_lr: Initial learning rate
        step_size: Number of steps before reducing LR
        gamma: Multiplicative factor (default 0.1)
        
    Returns:
        function: Learning rate schedule function
    """
    def schedule(step):
        return initial_lr * (gamma ** (step // step_size))
    return schedule


def exponential_lr(initial_lr, gamma=0.99):
    """
    Exponential learning rate decay
    
    Formula: lr = initial_lr * gamma^step
    
    Args:
        initial_lr: Initial learning rate
        gamma: Decay factor per step (default 0.99)
        
    Returns:
        function: Learning rate schedule function
    """
    def schedule(step):
        return initial_lr * (gamma ** step)
    return schedule


def polynomial_lr(initial_lr, total_steps, end_lr=0.0, power=1.0):
    """
    Polynomial learning rate decay
    
    Formula: lr = (initial_lr - end_lr) * ((1 - step/total_steps)^power) + end_lr
    
    Args:
        initial_lr: Initial learning rate
        total_steps: Total number of steps
        end_lr: Final learning rate (default 0.0)
        power: Polynomial power (default 1.0 for linear)
        
    Returns:
        function: Learning rate schedule function
    """
    def schedule(step):
        progress = min(step / total_steps, 1.0)
        return (initial_lr - end_lr) * ((1 - progress) ** power) + end_lr
    return schedule


def cosine_lr(initial_lr, total_steps, min_lr=0.0):
    """
    Cosine annealing learning rate schedule
    
    Formula: lr = min_lr + (initial_lr - min_lr) * (1 + cos(π * step / total_steps)) / 2
    
    Args:
        initial_lr: Initial learning rate
        total_steps: Total number of steps
        min_lr: Minimum learning rate (default 0.0)
        
    Returns:
        function: Learning rate schedule function
    """
    def schedule(step):
        step = min(step, total_steps)
        return min_lr + (initial_lr - min_lr) * (1 + np.cos(np.pi * step / total_steps)) / 2
    return schedule


def cosine_restart_lr(initial_lr, period, min_lr=0.0, t_mult=1.0):
    """
    Cosine annealing with warm restarts (SGDR)
    
    Args:
        initial_lr: Initial learning rate
        period: Period of cosine annealing
        min_lr: Minimum learning rate
        t_mult: Multiplicative factor to period after each restart (default 1.0)
        
    Returns:
        function: Learning rate schedule function
    """
    def schedule(step):
        # Find which restart cycle we're in
        cycle = 0
        remaining_steps = step
        current_period = period
        
        while remaining_steps >= current_period:
            remaining_steps -= current_period
            cycle += 1
            current_period = int(period * (t_mult ** cycle))
        
        # Cosine annealing within current cycle
        progress = remaining_steps / current_period
        return min_lr + (initial_lr - min_lr) * (1 + np.cos(np.pi * progress)) / 2
    
    return schedule


def linear_warmup_lr(initial_lr, warmup_steps):
    """
    Linear warmup learning rate schedule
    
    Formula: 
    - For step <= warmup_steps: lr = initial_lr * step / warmup_steps
    - For step > warmup_steps: lr = initial_lr
    
    Args:
        initial_lr: Initial learning rate (after warmup)
        warmup_steps: Number of warmup steps
        
    Returns:
        function: Learning rate schedule function
    """
    def schedule(step):
        if step <= warmup_steps:
            return initial_lr * (step / warmup_steps)
        return initial_lr
    return schedule


def linear_warmup_cosine_lr(initial_lr, warmup_steps, total_steps, min_lr=0.0):
    """
    Linear warmup followed by cosine annealing
    
    Args:
        initial_lr: Initial learning rate
        warmup_steps: Number of warmup steps
        total_steps: Total training steps
        min_lr: Minimum learning rate
        
    Returns:
        function: Learning rate schedule function
    """
    def schedule(step):
        if step < warmup_steps:
            # Linear warmup
            return initial_lr * (step / warmup_steps)
        else:
            # Cosine annealing after warmup
            remaining_steps = total_steps - warmup_steps
            current_step = step - warmup_steps
            progress = min(current_step / remaining_steps, 1.0)
            return min_lr + (initial_lr - min_lr) * (1 + np.cos(np.pi * progress)) / 2
    
    return schedule


def cyclic_lr(initial_lr, max_lr, period):
    """
    Cyclical learning rate schedule (triangular)
    
    Args:
        initial_lr: Initial (minimum) learning rate
        max_lr: Maximum learning rate
        period: Period of oscillation (in steps)
        
    Returns:
        function: Learning rate schedule function
    """
    def schedule(step):
        cycle_pos = (step % period) / period  # Position in cycle [0, 1)
        if cycle_pos < 0.5:
            # First half: increase
            return initial_lr + (max_lr - initial_lr) * (cycle_pos * 2)
        else:
            # Second half: decrease
            return max_lr - (max_lr - initial_lr) * ((cycle_pos - 0.5) * 2)
    
    return schedule


def one_cycle_lr(initial_lr, max_lr, total_steps, pct_start=0.3, anneal_strategy='cos'):
    """
    One-cycle learning rate schedule
    
    Args:
        initial_lr: Initial learning rate
        max_lr: Maximum learning rate
        total_steps: Total number of steps
        pct_start: Percentage of steps to spend increasing LR (default 0.3)
        anneal_strategy: Strategy for final decrease ('cos' or 'linear', default 'cos')
        
    Returns:
        function: Learning rate schedule function
    """
    step_up = int(total_steps * pct_start)
    step_down = total_steps - step_up
    
    def schedule(step):
        if step < step_up:
            # Increase phase
            progress = step / step_up
            return initial_lr + (max_lr - initial_lr) * progress
        else:
            # Decrease phase
            progress = (step - step_up) / step_down
            if anneal_strategy == 'cos':
                return initial_lr + (max_lr - initial_lr) * (1 + np.cos(np.pi * progress)) / 2
            else:  # linear
                return max_lr - (max_lr - initial_lr) * progress
    
    return schedule


# ============================================================================
# Optimizer Utility Functions
# ============================================================================

def apply_weight_decay(params, weight_decay, lr):
    """
    Apply L2 weight decay (AdamW style)
    
    Args:
        params: Parameter array
        weight_decay: Weight decay coefficient
        lr: Learning rate
        
    Returns:
        array: Updated parameters
    """
    if weight_decay == 0:
        return params
    
    return params * (1 - weight_decay * lr)


def clip_grad_norm(grads, max_norm):
    """
    Clip gradient norm (utility for optimizers)
    
    Args:
        grads: List of gradient arrays
        max_norm: Maximum allowed norm
        
    Returns:
        tuple: (clipped_grads, norm_before_clipping)
    """
    total_norm = 0.0
    for grad in grads:
        if grad is not None:
            total_norm += np.sum(grad ** 2)
    
    total_norm = np.sqrt(total_norm)
    
    if total_norm > max_norm:
        scale = max_norm / (total_norm + 1e-6)
        clipped_grads = [g * scale if g is not None else None for g in grads]
    else:
        clipped_grads = grads
    
    return clipped_grads, total_norm


def compute_grad_norm(grads):
    """
    Compute L2 norm of gradients
    
    Args:
        grads: List of gradient arrays
        
    Returns:
        float: L2 norm
    """
    total_norm = 0.0
    for grad in grads:
        if grad is not None:
            total_norm += np.sum(grad ** 2)
    
    return np.sqrt(total_norm)


def adam_momentum_update(param, grad, m, v, beta1=0.9, beta2=0.999, lr=0.001, eps=1e-8, weight_decay=0):
    """
    Single step of Adam optimizer update
    
    Args:
        param: Parameter array
        grad: Gradient array
        m: First moment estimate
        v: Second moment estimate
        beta1: Exponential decay for first moment (default 0.9)
        beta2: Exponential decay for second moment (default 0.999)
        lr: Learning rate
        eps: Numerical stability constant
        weight_decay: L2 weight decay coefficient
        
    Returns:
        tuple: (updated_param, updated_m, updated_v)
    """
    # Update biased first moment estimate
    m = beta1 * m + (1 - beta1) * grad
    
    # Update biased second moment estimate
    v = beta2 * v + (1 - beta2) * (grad ** 2)
    
    # Bias correction (implicit when steps are tracked externally)
    # Apply weight decay
    if weight_decay > 0:
        param = param * (1 - weight_decay * lr)
    
    # Parameter update
    param = param - lr * m / (np.sqrt(v) + eps)
    
    return param, m, v


def sgd_momentum_update(param, grad, momentum_buf, momentum=0.9, lr=0.01, weight_decay=0):
    """
    Single step of SGD with momentum
    
    Args:
        param: Parameter array
        grad: Gradient array
        momentum_buf: Momentum buffer
        momentum: Momentum coefficient (default 0.9)
        lr: Learning rate
        weight_decay: L2 weight decay coefficient
        
    Returns:
        tuple: (updated_param, updated_momentum_buf)
    """
    # Apply weight decay
    if weight_decay > 0:
        grad = grad + weight_decay * param
    
    # Update momentum buffer
    if momentum_buf is None:
        momentum_buf = grad
    else:
        momentum_buf = momentum * momentum_buf + grad
    
    # Parameter update
    param = param - lr * momentum_buf
    
    return param, momentum_buf


# ============================================================================
# Optimizer Utility Classes
# ============================================================================

class LRScheduler:
    """Base class for learning rate schedulers"""
    
    def __init__(self, schedule_fn):
        """
        Initialize scheduler
        
        Args:
            schedule_fn: Function that takes step and returns learning rate
        """
        self.schedule_fn = schedule_fn
        self.step_count = 0
    
    def get_lr(self):
        """Get current learning rate"""
        return self.schedule_fn(self.step_count)
    
    def step(self):
        """Advance to next step"""
        self.step_count += 1
        return self.get_lr()
    
    def reset(self):
        """Reset step counter"""
        self.step_count = 0


class WarmupScheduler:
    """Learning rate scheduler with warmup phase"""
    
    def __init__(self, base_scheduler, warmup_steps, warmup_strategy='linear'):
        """
        Initialize warmup scheduler
        
        Args:
            base_scheduler: Base LR scheduler
            warmup_steps: Number of warmup steps
            warmup_strategy: 'linear' or 'constant'
        """
        self.base_scheduler = base_scheduler
        self.warmup_steps = warmup_steps
        self.warmup_strategy = warmup_strategy
        self.step_count = 0
    
    def get_lr(self):
        """Get current learning rate with warmup"""
        if self.step_count < self.warmup_steps:
            base_lr = self.base_scheduler.schedule_fn(0)  # Initial LR
            if self.warmup_strategy == 'linear':
                return base_lr * (self.step_count / self.warmup_steps)
            else:  # constant
                return base_lr
        else:
            # Adjust step count for base scheduler
            adjusted_step = self.step_count - self.warmup_steps
            return self.base_scheduler.schedule_fn(adjusted_step)
    
    def step(self):
        """Advance to next step"""
        self.step_count += 1
        return self.get_lr()
    
    def reset(self):
        """Reset step counter"""
        self.step_count = 0
        self.base_scheduler.reset()


class GradientAccumulator:
    """Utility for gradient accumulation"""
    
    def __init__(self, num_accumulation_steps=1):
        """
        Initialize accumulator
        
        Args:
            num_accumulation_steps: Number of steps to accumulate (default 1)
        """
        self.num_accumulation_steps = num_accumulation_steps
        self.step_count = 0
        self.accumulated_grads = None
    
    def add_grads(self, grads):
        """
        Add gradients to accumulator
        
        Args:
            grads: List of gradient arrays
        """
        if self.accumulated_grads is None:
            self.accumulated_grads = [g.copy() if g is not None else None for g in grads]
        else:
            for i, grad in enumerate(grads):
                if grad is not None and self.accumulated_grads[i] is not None:
                    self.accumulated_grads[i] += grad
        
        self.step_count += 1
    
    def should_update(self):
        """Check if optimizer should perform update"""
        return self.step_count >= self.num_accumulation_steps
    
    def get_accumulated_grads(self):
        """Get accumulated gradients, averaged over accumulation steps"""
        if self.accumulated_grads is None:
            return None
        
        return [
            g / self.num_accumulation_steps if g is not None else None
            for g in self.accumulated_grads
        ]
    
    def reset(self):
        """Reset accumulator"""
        self.accumulated_grads = None
        self.step_count = 0


__all__ = [
    # LR schedules
    'constant_lr', 'step_lr', 'exponential_lr', 'polynomial_lr',
    'cosine_lr', 'cosine_restart_lr', 'linear_warmup_lr',
    'linear_warmup_cosine_lr', 'cyclic_lr', 'one_cycle_lr',
    # Optimizer utilities
    'apply_weight_decay', 'clip_grad_norm', 'compute_grad_norm',
    'adam_momentum_update', 'sgd_momentum_update',
    # Classes
    'LRScheduler', 'WarmupScheduler', 'GradientAccumulator',
]
