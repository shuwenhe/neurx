"""Enhanced model serialization with versioning, compression, and utilities."""

import gzip
import json
import os
import pickle
import shutil
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, Optional, Dict

import numpy as np

try:
    from tensor.serialization.checkpoint import save_checkpoint, load_checkpoint
except ImportError:
    save_checkpoint = None
    load_checkpoint = None


class ModelCheckpoint:
    """Enhanced checkpoint manager with versioning and metadata."""
    
    def __init__(self, path: str, max_keep: int = 5, compress: bool = False):
        """
        Initialize checkpoint manager.
        
        Args:
            path: Directory to store checkpoints
            max_keep: Maximum number of checkpoints to keep
            compress: Whether to compress checkpoints with gzip
        """
        self.path = Path(path)
        self.path.mkdir(parents=True, exist_ok=True)
        self.max_keep = max_keep
        self.compress = compress
        self._history_file = self.path / "_checkpoint_history.json"
        self._load_history()
    
    def _load_history(self):
        """Load checkpoint history."""
        self.history = []
        if self._history_file.exists():
            try:
                with open(self._history_file, 'r') as f:
                    self.history = json.load(f)
            except Exception:
                self.history = []
    
    def _save_history(self):
        """Save checkpoint history."""
        with open(self._history_file, 'w') as f:
            json.dump(self.history, f, indent=2)
    
    def _cleanup_old(self):
        """Remove old checkpoints exceeding max_keep."""
        if len(self.history) > self.max_keep:
            # Remove oldest checkpoints
            to_remove = self.history[:-self.max_keep]
            for entry in to_remove:
                checkpoint_path = Path(entry['path'])
                if checkpoint_path.exists():
                    checkpoint_path.unlink()
            # Keep only newest checkpoints
            self.history = self.history[-self.max_keep:]
            self._save_history()
    
    def save(self, model=None, optimizer=None, scaler=None, step: int = 0, 
             epoch: int = 0, metrics: Dict[str, Any] = None, name: str = None) -> str:
        """
        Save checkpoint with metadata.
        
        Args:
            model: Model to save (must have state_dict())
            optimizer: Optimizer to save
            scaler: Scaler for AMP
            step: Training step
            epoch: Training epoch
            metrics: Metrics dict
            name: Custom checkpoint name
        
        Returns:
            Path to saved checkpoint
        """
        if name is None:
            name = f"checkpoint_ep{epoch}_step{step}"
        
        checkpoint_file = self.path / f"{name}.pt"
        if self.compress:
            checkpoint_file = self.path / f"{name}.pt.gz"
        
        # Create checkpoint data
        checkpoint_data = {
            'format': 'neurx.checkpoint',
            'version': 1,
            'timestamp': datetime.now().isoformat(),
            'training': {
                'step': int(step),
                'epoch': int(epoch),
            },
            'metrics': metrics or {},
            'model_state': model.state_dict() if model is not None else None,
            'optimizer_state': optimizer.state_dict() if optimizer is not None else None,
            'scaler_state': scaler.state_dict() if scaler is not None else None,
        }
        
        # Save checkpoint
        if self.compress:
            with gzip.open(checkpoint_file, 'wb') as f:
                pickle.dump(checkpoint_data, f, protocol=pickle.HIGHEST_PROTOCOL)
        else:
            with open(checkpoint_file, 'wb') as f:
                pickle.dump(checkpoint_data, f, protocol=pickle.HIGHEST_PROTOCOL)
        
        # Update history
        history_entry = {
            'path': str(checkpoint_file),
            'timestamp': checkpoint_data['timestamp'],
            'epoch': epoch,
            'step': step,
            'metrics': metrics or {},
        }
        self.history.append(history_entry)
        self._save_history()
        self._cleanup_old()
        
        return str(checkpoint_file)
    
    def load(self, checkpoint_path: str = None, model=None, optimizer=None, 
             scaler=None, strict: bool = True) -> Dict[str, Any]:
        """
        Load checkpoint.
        
        Args:
            checkpoint_path: Path to checkpoint (None = latest)
            model: Model to load into
            optimizer: Optimizer to load into
            scaler: Scaler to load into
            strict: Strict mode for state dict
        
        Returns:
            Loaded checkpoint data
        """
        if checkpoint_path is None:
            # Load latest checkpoint
            if not self.history:
                raise ValueError("No checkpoints available")
            checkpoint_path = self.history[-1]['path']
        
        checkpoint_path = Path(checkpoint_path)
        
        # Load checkpoint
        if checkpoint_path.suffix == '.gz':
            with gzip.open(checkpoint_path, 'rb') as f:
                checkpoint_data = pickle.load(f)
        else:
            with open(checkpoint_path, 'rb') as f:
                checkpoint_data = pickle.load(f)
        
        # Load states
        if model is not None and checkpoint_data.get('model_state') is not None:
            if hasattr(model, 'load_state_dict'):
                try:
                    model.load_state_dict(checkpoint_data['model_state'], strict=strict)
                except TypeError:
                    model.load_state_dict(checkpoint_data['model_state'])
        
        if optimizer is not None and checkpoint_data.get('optimizer_state') is not None:
            if hasattr(optimizer, 'load_state_dict'):
                optimizer.load_state_dict(checkpoint_data['optimizer_state'])
        
        if scaler is not None and checkpoint_data.get('scaler_state') is not None:
            if hasattr(scaler, 'load_state_dict'):
                scaler.load_state_dict(checkpoint_data['scaler_state'])
        
        return checkpoint_data
    
    def get_best_checkpoint(self, metric_key: str = 'loss', maximize: bool = False) -> Optional[str]:
        """
        Get path to best checkpoint based on metric.
        
        Args:
            metric_key: Key in metrics dict to use for comparison
            maximize: If True, find max; if False, find min
        
        Returns:
            Path to best checkpoint or None
        """
        best_idx = None
        best_value = None
        
        for i, entry in enumerate(self.history):
            metrics = entry.get('metrics', {})
            if metric_key not in metrics:
                continue
            
            value = metrics[metric_key]
            
            if best_value is None:
                best_value = value
                best_idx = i
            elif maximize and value > best_value:
                best_value = value
                best_idx = i
            elif not maximize and value < best_value:
                best_value = value
                best_idx = i
        
        if best_idx is not None:
            return self.history[best_idx]['path']
        return None
    
    def list_checkpoints(self):
        """List all saved checkpoints."""
        return [
            {
                'epoch': entry['epoch'],
                'step': entry['step'],
                'path': entry['path'],
                'timestamp': entry['timestamp'],
                'metrics': entry.get('metrics', {}),
            }
            for entry in self.history
        ]


def save_tensor_dict(state_dict: Dict[str, np.ndarray], path: str, 
                     compress: bool = True, metadata: Dict[str, Any] = None):
    """
    Save state dict with optional compression.
    
    Args:
        state_dict: Dictionary of tensor states
        path: Save path
        compress: Whether to compress
        metadata: Additional metadata to save
    """
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    
    data = {
        'version': 1,
        'timestamp': datetime.now().isoformat(),
        'metadata': metadata or {},
        'state': state_dict,
    }
    
    if compress:
        with gzip.open(str(path) + '.gz', 'wb') as f:
            pickle.dump(data, f, protocol=pickle.HIGHEST_PROTOCOL)
    else:
        with open(path, 'wb') as f:
            pickle.dump(data, f, protocol=pickle.HIGHEST_PROTOCOL)


def load_tensor_dict(path: str) -> Dict[str, np.ndarray]:
    """Load state dict from file."""
    path = Path(path)
    
    # Try both .gz and non-compressed versions
    if not path.exists() and (path.parent / f"{path.name}.gz").exists():
        path = path.parent / f"{path.name}.gz"
    
    if path.suffix == '.gz':
        with gzip.open(path, 'rb') as f:
            data = pickle.load(f)
    else:
        with open(path, 'rb') as f:
            data = pickle.load(f)
    
    return data.get('state', data)


def merge_state_dicts(*state_dicts):
    """Merge multiple state dicts into one."""
    merged = {}
    for state_dict in state_dicts:
        for key, value in state_dict.items():
            if key in merged:
                raise ValueError(f"Duplicate key in state dicts: {key}")
            merged[key] = value
    return merged


def extract_state_dict_subset(state_dict, prefix: str = None, remove_prefix: bool = False):
    """
    Extract subset of state dict by prefix.
    
    Args:
        state_dict: Full state dict
        prefix: Prefix to filter by
        remove_prefix: Whether to remove prefix from keys
    
    Returns:
        Filtered state dict
    """
    if prefix is None:
        return state_dict.copy()
    
    filtered = {}
    for key, value in state_dict.items():
        if key.startswith(prefix):
            new_key = key[len(prefix)+1:] if remove_prefix and prefix else key
            filtered[new_key] = value
    
    return filtered
