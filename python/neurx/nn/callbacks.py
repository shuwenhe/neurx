"""
Week 7: Training Callbacks and Monitoring

Comprehensive callback system for training loop management, monitoring, and control.
Includes early stopping, model checkpointing, metrics tracking, and learning rate monitoring.
"""

import numpy as np
import pickle
import os
from typing import Optional, Dict, Any, List, Callable


# ============================================================================
# Base Callback Classes
# ============================================================================

class Callback:
    """Base class for all callbacks."""
    
    def on_train_begin(self, logs: Optional[Dict] = None):
        """Called at the beginning of training."""
        pass
    
    def on_train_end(self, logs: Optional[Dict] = None):
        """Called at the end of training."""
        pass
    
    def on_epoch_begin(self, epoch: int, logs: Optional[Dict] = None):
        """Called at the beginning of each epoch."""
        pass
    
    def on_epoch_end(self, epoch: int, logs: Optional[Dict] = None):
        """Called at the end of each epoch."""
        pass
    
    def on_batch_begin(self, batch: int, logs: Optional[Dict] = None):
        """Called at the beginning of each batch."""
        pass
    
    def on_batch_end(self, batch: int, logs: Optional[Dict] = None):
        """Called at the end of each batch."""
        pass


# ============================================================================
# Early Stopping Callback
# ============================================================================

class EarlyStopping(Callback):
    """
    Early stopping callback to halt training when monitored metric stops improving.
    
    Monitors a metric (e.g., validation loss) and stops training if no improvement
    is observed for a specified number of epochs (patience).
    
    Args:
        monitor (str): Name of metric to monitor (e.g., 'val_loss')
        patience (int): Number of epochs with no improvement after which training stops
        min_delta (float): Minimum change to qualify as improvement (default: 0.0)
        mode (str): One of {'min', 'max'} for minimization or maximization
        restore_best_weights (bool): Whether to restore weights from best epoch
    
    Example:
        >>> early_stopping = EarlyStopping(monitor='val_loss', patience=5, mode='min')
        >>> callbacks = [early_stopping]
        >>> # Use in training loop
    """
    
    def __init__(self, monitor: str = 'val_loss', patience: int = 10, 
                 min_delta: float = 0.0, mode: str = 'min',
                 restore_best_weights: bool = True):
        super().__init__()
        self.monitor = monitor
        self.patience = patience
        self.min_delta = min_delta
        self.mode = mode
        self.restore_best_weights = restore_best_weights
        
        self.wait_count = 0
        self.best_epoch = 0
        self.best_value = np.inf if mode == 'min' else -np.inf
        self.best_weights = None
        self.stopped_epoch = 0
        
    def on_epoch_end(self, epoch: int, logs: Optional[Dict] = None):
        """Check if metric has improved."""
        if logs is None:
            return
        
        current = logs.get(self.monitor)
        if current is None:
            return
        
        # Check improvement
        if self.mode == 'min':
            improved = current < self.best_value - self.min_delta
        else:  # max mode
            improved = current > self.best_value + self.min_delta
        
        if improved:
            self.best_value = current
            self.best_epoch = epoch
            self.wait_count = 0
            # Store best weights if requested
            if self.restore_best_weights:
                self.best_weights = logs.get('weights')
        else:
            self.wait_count += 1
            if self.wait_count >= self.patience:
                self.stopped_epoch = epoch
                logs['stop_training'] = True
    
    def on_train_end(self, logs: Optional[Dict] = None):
        """Print stopping info."""
        if self.stopped_epoch > 0:
            if logs is not None:
                logs['best_epoch'] = self.best_epoch
                logs['best_value'] = self.best_value
                logs['best_weights'] = self.best_weights


# ============================================================================
# Model Checkpoint Callback
# ============================================================================

class ModelCheckpoint(Callback):
    """
    Save model weights when monitored metric improves.
    
    Args:
        filepath (str): Path to save model weights
        monitor (str): Metric name to monitor
        mode (str): One of {'min', 'max'} for improvement direction
        save_best_only (bool): Save only best model weights
        save_freq (int): Save every N epochs (if save_best_only=False)
        verbose (int): Verbosity level (0, 1, or 2)
    
    Example:
        >>> checkpoint = ModelCheckpoint('best_model.pkl', monitor='val_loss', mode='min')
    """
    
    def __init__(self, filepath: str, monitor: str = 'val_loss', mode: str = 'min',
                 save_best_only: bool = True, save_freq: int = 1, verbose: int = 0):
        super().__init__()
        self.filepath = filepath
        self.monitor = monitor
        self.mode = mode
        self.save_best_only = save_best_only
        self.save_freq = save_freq
        self.verbose = verbose
        
        self.best_value = np.inf if mode == 'min' else -np.inf
        self.best_epoch = 0
        
    def on_epoch_end(self, epoch: int, logs: Optional[Dict] = None):
        """Save model if conditions are met."""
        if logs is None:
            return
        
        current = logs.get(self.monitor)
        if current is None:
            return
        
        # Check if should save
        should_save = False
        
        if self.save_best_only:
            if self.mode == 'min':
                should_save = current < self.best_value
            else:  # max mode
                should_save = current > self.best_value
            
            if should_save:
                self.best_value = current
                self.best_epoch = epoch
        else:
            should_save = (epoch % self.save_freq == 0)
        
        if should_save and 'weights' in logs:
            weights = logs.get('weights')
            try:
                with open(self.filepath, 'wb') as f:
                    pickle.dump(weights, f)
                if self.verbose > 0:
                    print(f"Epoch {epoch}: Checkpoint saved to {self.filepath}")
            except Exception as e:
                if self.verbose > 0:
                    print(f"Error saving checkpoint: {e}")


# ============================================================================
# Metric Tracking Callback
# ============================================================================

class MetricsTracker(Callback):
    """
    Track and aggregate metrics across training.
    
    Maintains running history of all logged metrics.
    
    Example:
        >>> tracker = MetricsTracker()
        >>> # Access history: tracker.history['loss'], tracker.history['accuracy']
    """
    
    def __init__(self):
        super().__init__()
        self.history = {}
        
    def on_train_begin(self, logs: Optional[Dict] = None):
        """Initialize history."""
        self.history = {}
    
    def on_epoch_end(self, epoch: int, logs: Optional[Dict] = None):
        """Record metrics."""
        if logs is None:
            return
        
        for key, value in logs.items():
            if key not in ['weights', 'stop_training', 'best_epoch', 'best_value', 'best_weights']:
                if key not in self.history:
                    self.history[key] = []
                self.history[key].append(value)
    
    def get_history(self) -> Dict[str, List]:
        """Get complete history."""
        return self.history


# ============================================================================
# Learning Rate Monitor Callback
# ============================================================================

class LRMonitor(Callback):
    """
    Monitor learning rate during training.
    
    Tracks learning rate changes and can trigger actions based on LR values.
    
    Example:
        >>> lr_monitor = LRMonitor()
        >>> # Access LR history: lr_monitor.lrs
    """
    
    def __init__(self):
        super().__init__()
        self.lrs = []
        
    def on_epoch_begin(self, epoch: int, logs: Optional[Dict] = None):
        """Record current learning rate."""
        if logs is None:
            return
        
        lr = logs.get('learning_rate')
        if lr is not None:
            self.lrs.append(lr)
    
    def get_lrs(self) -> List[float]:
        """Get list of learning rates."""
        return self.lrs


# ============================================================================
# Patience-based Learning Rate Reduction
# ============================================================================

class ReduceLROnPlateau(Callback):
    """
    Reduce learning rate when monitored metric plateaus.
    
    Multiplies learning rate by a factor when no improvement is seen for 
    a specified number of epochs.
    
    Args:
        monitor (str): Metric to monitor
        factor (float): Multiplicative factor to apply to LR (default: 0.1)
        patience (int): Number of epochs with no improvement before reducing LR
        min_lr (float): Minimum learning rate value
        mode (str): One of {'min', 'max'}
        verbose (int): Verbosity level
    
    Example:
        >>> reduce_lr = ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=3)
    """
    
    def __init__(self, monitor: str = 'val_loss', factor: float = 0.1,
                 patience: int = 10, min_lr: float = 0.0, mode: str = 'min',
                 verbose: int = 0):
        super().__init__()
        self.monitor = monitor
        self.factor = factor
        self.patience = patience
        self.min_lr = min_lr
        self.mode = mode
        self.verbose = verbose
        
        self.best_value = np.inf if mode == 'min' else -np.inf
        self.wait_count = 0
        self.best_epoch = 0
    
    def on_epoch_end(self, epoch: int, logs: Optional[Dict] = None):
        """Check if LR should be reduced."""
        if logs is None:
            return
        
        current = logs.get(self.monitor)
        if current is None:
            return
        
        # Check improvement
        if self.mode == 'min':
            improved = current < self.best_value
        else:  # max mode
            improved = current > self.best_value
        
        if improved:
            self.best_value = current
            self.wait_count = 0
            self.best_epoch = epoch
        else:
            self.wait_count += 1
            if self.wait_count >= self.patience:
                # Reduce LR
                current_lr = logs.get('learning_rate', 0.001)
                new_lr = max(current_lr * self.factor, self.min_lr)
                logs['learning_rate'] = new_lr
                
                if self.verbose > 0:
                    print(f"Epoch {epoch}: Reducing LR to {new_lr}")
                
                self.wait_count = 0


# ============================================================================
# Callback List Manager
# ============================================================================

class CallbackList:
    """
    Manager for multiple callbacks.
    
    Handles callback execution lifecycle and logging.
    
    Example:
        >>> callbacks = CallbackList([
        ...     EarlyStopping(monitor='val_loss'),
        ...     ModelCheckpoint('best.pkl'),
        ...     MetricsTracker()
        ... ])
        >>> # Use in training loop
    """
    
    def __init__(self, callbacks: Optional[List[Callback]] = None):
        self.callbacks = callbacks or []
    
    def add_callback(self, callback: Callback):
        """Add a callback."""
        self.callbacks.append(callback)
    
    def train_begin(self, logs: Optional[Dict] = None):
        """Call on_train_begin for all callbacks."""
        for callback in self.callbacks:
            callback.on_train_begin(logs)
    
    def train_end(self, logs: Optional[Dict] = None):
        """Call on_train_end for all callbacks."""
        for callback in self.callbacks:
            callback.on_train_end(logs)
    
    def epoch_begin(self, epoch: int, logs: Optional[Dict] = None):
        """Call on_epoch_begin for all callbacks."""
        for callback in self.callbacks:
            callback.on_epoch_begin(epoch, logs)
    
    def epoch_end(self, epoch: int, logs: Optional[Dict] = None):
        """Call on_epoch_end for all callbacks."""
        for callback in self.callbacks:
            callback.on_epoch_end(epoch, logs)
    
    def batch_begin(self, batch: int, logs: Optional[Dict] = None):
        """Call on_batch_begin for all callbacks."""
        for callback in self.callbacks:
            callback.on_batch_begin(batch, logs)
    
    def batch_end(self, batch: int, logs: Optional[Dict] = None):
        """Call on_batch_end for all callbacks."""
        for callback in self.callbacks:
            callback.on_batch_end(batch, logs)


# ============================================================================
# Custom Callback Example
# ============================================================================

class CustomCallback(Callback):
    """
    Template for creating custom callbacks.
    
    Users can inherit from this to create custom monitoring/control logic.
    
    Example:
        >>> class MyCallback(CustomCallback):
        ...     def on_epoch_end(self, epoch, logs=None):
        ...         if logs['loss'] < 0.1:
        ...             logs['stop_training'] = True
    """
    
    def __init__(self):
        super().__init__()
    
    def on_train_begin(self, logs: Optional[Dict] = None):
        """Override in subclass."""
        super().on_train_begin(logs)
    
    def on_train_end(self, logs: Optional[Dict] = None):
        """Override in subclass."""
        super().on_train_end(logs)
    
    def on_epoch_begin(self, epoch: int, logs: Optional[Dict] = None):
        """Override in subclass."""
        super().on_epoch_begin(epoch, logs)
    
    def on_epoch_end(self, epoch: int, logs: Optional[Dict] = None):
        """Override in subclass."""
        super().on_epoch_end(epoch, logs)


# ============================================================================
# Training Progress Callback
# ============================================================================

class ProgressTracker(Callback):
    """
    Track training progress with visual feedback.
    
    Displays epoch progress, time tracking, and ETA estimation.
    
    Example:
        >>> progress = ProgressTracker(total_epochs=100)
    """
    
    def __init__(self, total_epochs: int = 100):
        super().__init__()
        self.total_epochs = total_epochs
        self.epoch_start_time = None
        self.train_start_time = None
    
    def on_train_begin(self, logs: Optional[Dict] = None):
        """Start timing."""
        import time
        self.train_start_time = time.time()
    
    def on_epoch_begin(self, epoch: int, logs: Optional[Dict] = None):
        """Start epoch timing."""
        import time
        self.epoch_start_time = time.time()
    
    def on_epoch_end(self, epoch: int, logs: Optional[Dict] = None):
        """Print progress."""
        import time
        if self.epoch_start_time is None:
            return
        
        epoch_time = time.time() - self.epoch_start_time
        total_time = time.time() - self.train_start_time
        
        if logs is not None:
            logs['epoch_time'] = epoch_time
            logs['total_time'] = total_time
            
            # Estimate ETA
            if epoch > 0:
                avg_time = total_time / (epoch + 1)
                eta = avg_time * (self.total_epochs - epoch - 1)
                logs['eta_seconds'] = eta


__all__ = [
    'Callback',
    'EarlyStopping',
    'ModelCheckpoint',
    'MetricsTracker',
    'LRMonitor',
    'ReduceLROnPlateau',
    'CallbackList',
    'CustomCallback',
    'ProgressTracker',
]
