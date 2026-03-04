"""
Week 7: Model Serialization and Checkpoint Management

Utilities for saving and loading model weights, checkpoints, and full models.
Supports pickling, numpy npz format, and custom checkpoint formats.
"""

import numpy as np
import pickle
import os
from typing import Optional, Dict, Any, List
import json


# ============================================================================
# Weight Saving and Loading
# ============================================================================

def save_weights(model_weights: Dict[str, np.ndarray], filepath: str,
                format: str = 'pickle') -> None:
    """
    Save model weights to disk.
    
    Args:
        model_weights: Dictionary of weight arrays (e.g., {'layer1': array, ...})
        filepath: Path to save weights
        format: Save format - 'pickle', 'npz', or 'pkl'
    
    Example:
        >>> weights = {'w1': np.array([1, 2, 3]), 'b1': np.array([0.1])}
        >>> save_weights(weights, 'model_weights.pkl')
    """
    
    os.makedirs(os.path.dirname(filepath) or '.', exist_ok=True)
    
    try:
        if format in ['pickle', 'pkl']:
            with open(filepath, 'wb') as f:
                pickle.dump(model_weights, f)
        elif format == 'npz':
            # Convert dict to npz format
            np.savez(filepath, **model_weights)
        else:
            raise ValueError(f"Unsupported format: {format}")
    except Exception as e:
        raise RuntimeError(f"Failed to save weights: {e}")


def load_weights(filepath: str, format: str = 'pickle') -> Dict[str, np.ndarray]:
    """
    Load model weights from disk.
    
    Args:
        filepath: Path to weights file
        format: File format - 'pickle', 'npz', or 'pkl'
    
    Returns:
        Dictionary of weight arrays
    
    Example:
        >>> weights = load_weights('model_weights.pkl')
        >>> print(weights.keys())  # ['w1', 'b1', ...]
    """
    
    try:
        if format in ['pickle', 'pkl']:
            with open(filepath, 'rb') as f:
                weights = pickle.load(f)
        elif format == 'npz':
            data = np.load(filepath)
            weights = {key: data[key] for key in data.files}
        else:
            raise ValueError(f"Unsupported format: {format}")
    except Exception as e:
        raise RuntimeError(f"Failed to load weights: {e}")
    
    return weights


# ============================================================================
# Checkpoint Management
# ============================================================================

class Checkpoint:
    """
    Encapsulates a training checkpoint with state information.
    
    Contains model weights, optimizer state, training metadata, and metrics.
    
    Attributes:
        epoch: Training epoch number
        weights: Model weight dictionary
        optimizer_state: Optimizer state (e.g., momentum, adaptive LR)
        metrics: Training metrics at checkpoint time
        config: Model configuration metadata
    
    Example:
        >>> checkpoint = Checkpoint(
        ...     epoch=10,
        ...     weights=weights,
        ...     optimizer_state=opt_state,
        ...     metrics={'loss': 0.05, 'accuracy': 0.95}
        ... )
    """
    
    def __init__(self, epoch: int, weights: Dict[str, np.ndarray],
                 optimizer_state: Optional[Dict] = None,
                 metrics: Optional[Dict] = None,
                 config: Optional[Dict] = None):
        self.epoch = epoch
        self.weights = weights
        self.optimizer_state = optimizer_state or {}
        self.metrics = metrics or {}
        self.config = config or {}
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert checkpoint to dictionary."""
        return {
            'epoch': self.epoch,
            'weights': self.weights,
            'optimizer_state': self.optimizer_state,
            'metrics': self.metrics,
            'config': self.config,
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Checkpoint':
        """Create checkpoint from dictionary."""
        return cls(
            epoch=data.get('epoch', 0),
            weights=data.get('weights', {}),
            optimizer_state=data.get('optimizer_state'),
            metrics=data.get('metrics'),
            config=data.get('config'),
        )


def save_checkpoint(checkpoint: Checkpoint, filepath: str) -> None:
    """
    Save training checkpoint to disk.
    
    Args:
        checkpoint: Checkpoint object to save
        filepath: Path to save checkpoint
    
    Example:
        >>> checkpoint = Checkpoint(epoch=5, weights=weights, metrics={'loss': 0.1})
        >>> save_checkpoint(checkpoint, 'checkpoint_epoch5.pkl')
    """
    
    os.makedirs(os.path.dirname(filepath) or '.', exist_ok=True)
    
    try:
        with open(filepath, 'wb') as f:
            pickle.dump(checkpoint.to_dict(), f)
    except Exception as e:
        raise RuntimeError(f"Failed to save checkpoint: {e}")


def load_checkpoint(filepath: str) -> Checkpoint:
    """
    Load training checkpoint from disk.
    
    Args:
        filepath: Path to checkpoint file
    
    Returns:
        Checkpoint object
    
    Example:
        >>> checkpoint = load_checkpoint('checkpoint_epoch5.pkl')
        >>> print(checkpoint.epoch)  # 5
    """
    
    try:
        with open(filepath, 'rb') as f:
            data = pickle.load(f)
        return Checkpoint.from_dict(data)
    except Exception as e:
        raise RuntimeError(f"Failed to load checkpoint: {e}")


# ============================================================================
# Checkpoint Manager
# ============================================================================

class CheckpointManager:
    """
    Manages multiple checkpoints with cleanup and best model tracking.
    
    Maintains a directory of checkpoints, keeping best models and cleaning up old ones.
    
    Args:
        checkpoint_dir: Directory for storing checkpoints
        keep_best_k: Number of best checkpoints to keep
        keep_latest_k: Number of latest checkpoints to keep
    
    Example:
        >>> manager = CheckpointManager('checkpoints/', keep_best_k=3)
        >>> manager.save_checkpoint(checkpoint, 'val_loss')
        >>> best_ckpt = manager.restore_best('val_loss')
    """
    
    def __init__(self, checkpoint_dir: str, keep_best_k: int = 3,
                 keep_latest_k: int = 5):
        self.checkpoint_dir = checkpoint_dir
        self.keep_best_k = keep_best_k
        self.keep_latest_k = keep_latest_k
        
        os.makedirs(checkpoint_dir, exist_ok=True)
        
        self.best_checkpoints = {}  # metric -> [list of (value, epoch, path)]
        self.latest_checkpoints = []  # [(epoch, path)]
    
    def save_checkpoint(self, checkpoint: Checkpoint, metric_name: str,
                       metric_value: float) -> str:
        """
        Save checkpoint and manage history.
        
        Args:
            checkpoint: Checkpoint object
            metric_name: Name of metric being tracked
            metric_value: Value of metric (for ranking)
        
        Returns:
            Path to saved checkpoint
        """
        
        epoch = checkpoint.epoch
        filename = f"checkpoint_epoch_{epoch:04d}_{metric_name}_{metric_value:.4f}.pkl"
        filepath = os.path.join(self.checkpoint_dir, filename)
        
        save_checkpoint(checkpoint, filepath)
        
        # Track best checkpoints
        if metric_name not in self.best_checkpoints:
            self.best_checkpoints[metric_name] = []
        
        self.best_checkpoints[metric_name].append((metric_value, epoch, filepath))
        
        # Keep only best_k
        self.best_checkpoints[metric_name].sort(key=lambda x: x[0])
        if len(self.best_checkpoints[metric_name]) > self.keep_best_k:
            _, _, old_path = self.best_checkpoints[metric_name].pop()
            try:
                os.remove(old_path)
            except:
                pass
        
        # Track latest checkpoints
        self.latest_checkpoints.append((epoch, filepath))
        self.latest_checkpoints.sort(key=lambda x: x[0], reverse=True)
        if len(self.latest_checkpoints) > self.keep_latest_k:
            _, old_path = self.latest_checkpoints.pop()
            try:
                os.remove(old_path)
            except:
                pass
        
        return filepath
    
    def restore_best(self, metric_name: str) -> Optional[Checkpoint]:
        """
        Restore best checkpoint for a metric.
        
        Args:
            metric_name: Name of metric
        
        Returns:
            Best checkpoint or None if no checkpoints saved
        """
        
        if metric_name not in self.best_checkpoints or not self.best_checkpoints[metric_name]:
            return None
        
        _, _, filepath = self.best_checkpoints[metric_name][0]
        return load_checkpoint(filepath)
    
    def restore_latest(self) -> Optional[Checkpoint]:
        """Restore most recent checkpoint."""
        
        if not self.latest_checkpoints:
            return None
        
        _, filepath = self.latest_checkpoints[0]
        return load_checkpoint(filepath)


# ============================================================================
# Model Export
# ============================================================================

def export_model(model_weights: Dict[str, np.ndarray],
                model_config: Dict[str, Any],
                filepath: str,
                format: str = 'npz') -> None:
    """
    Export model weights and configuration for inference.
    
    Args:
        model_weights: Model weight dictionary
        model_config: Model configuration (architecture, hyperparams, etc.)
        filepath: Path to export file
        format: Export format - 'npz' (numpy), 'json' (config only), 'pkl' (all)
    
    Example:
        >>> config = {'input_size': 784, 'hidden_size': 128, 'output_size': 10}
        >>> export_model(weights, config, 'model_export.npz', format='npz')
    """
    
    os.makedirs(os.path.dirname(filepath) or '.', exist_ok=True)
    
    try:
        if format == 'npz':
            # Save weights as npz
            np.savez(filepath, **model_weights)
            # Save config separately
            config_path = filepath.replace('.npz', '_config.json')
            with open(config_path, 'w') as f:
                json.dump(model_config, f, indent=2)
        
        elif format == 'json':
            # Save config only
            with open(filepath, 'w') as f:
                json.dump(model_config, f, indent=2)
        
        elif format == 'pkl':
            # Save everything as pickle
            data = {
                'weights': model_weights,
                'config': model_config,
            }
            with open(filepath, 'wb') as f:
                pickle.dump(data, f)
    
    except Exception as e:
        raise RuntimeError(f"Failed to export model: {e}")


def import_model(filepath: str, format: str = 'npz') -> Dict[str, Any]:
    """
    Import exported model.
    
    Args:
        filepath: Path to exported model
        format: Export format
    
    Returns:
        Dictionary with 'weights' and optionally 'config'
    
    Example:
        >>> model = import_model('model_export.npz')
        >>> weights = model['weights']
        >>> config = model['config']
    """
    
    try:
        if format == 'npz':
            data = np.load(filepath)
            weights = {key: data[key] for key in data.files}
            
            config_path = filepath.replace('.npz', '_config.json')
            config = {}
            if os.path.exists(config_path):
                with open(config_path, 'r') as f:
                    config = json.load(f)
            
            return {'weights': weights, 'config': config}
        
        elif format == 'pkl':
            with open(filepath, 'rb') as f:
                data = pickle.load(f)
            return data
    
    except Exception as e:
        raise RuntimeError(f"Failed to import model: {e}")


# ============================================================================
# Utility Functions
# ============================================================================

def get_checkpoint_info(checkpoint: Checkpoint) -> Dict[str, Any]:
    """
    Get summary information about a checkpoint.
    
    Args:
        checkpoint: Checkpoint object
    
    Returns:
        Summary dictionary with sizes, counts, and metadata
    """
    
    total_params = sum(w.size for w in checkpoint.weights.values())
    total_size_mb = sum(w.nbytes for w in checkpoint.weights.values()) / 1e6
    
    return {
        'epoch': checkpoint.epoch,
        'total_parameters': total_params,
        'total_size_mb': total_size_mb,
        'num_weight_tensors': len(checkpoint.weights),
        'metrics': checkpoint.metrics,
    }


def resume_from_checkpoint(checkpoint: Checkpoint) -> Dict[str, Any]:
    """
    Extract training state from checkpoint for resumption.
    
    Args:
        checkpoint: Checkpoint object
    
    Returns:
        Dictionary with resumption state
    """
    
    return {
        'start_epoch': checkpoint.epoch + 1,
        'weights': checkpoint.weights,
        'optimizer_state': checkpoint.optimizer_state,
        'last_metrics': checkpoint.metrics,
    }


__all__ = [
    'save_weights',
    'load_weights',
    'Checkpoint',
    'save_checkpoint',
    'load_checkpoint',
    'CheckpointManager',
    'export_model',
    'import_model',
    'get_checkpoint_info',
    'resume_from_checkpoint',
]
