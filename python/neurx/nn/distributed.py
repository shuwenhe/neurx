"""
Week 7: Distributed Training and Multi-GPU Support

Utilities for distributed training including data parallelism, 
gradient synchronization, and device management.
"""

import numpy as np
from typing import Optional, List, Dict, Any


# ============================================================================
# Device Management
# ============================================================================

class DeviceManager:
    """
    Manages device placement and synchronization.
    
    Handles CPU/GPU device management for distributed training scenarios.
    
    Example:
        >>> device_mgr = DeviceManager()
        >>> device = device_mgr.get_device()
        >>> available = device_mgr.get_available_devices()
    """
    
    def __init__(self, device_type: str = 'cpu', device_id: int = 0):
        self.device_type = device_type  # 'cpu' or 'cuda'
        self.device_id = device_id
        self.available_devices = self._detect_devices()
    
    def _detect_devices(self) -> Dict[str, List]:
        """Detect available devices."""
        devices = {
            'cpu': [0],  # Always have CPU
            'cuda': [],  # GPU detection would happen here
        }
        return devices
    
    def get_device(self) -> str:
        """Get current device string."""
        if self.device_type == 'cuda' and self.device_id >= 0:
            return f"{self.device_type}:{self.device_id}"
        return self.device_type
    
    def get_available_devices(self) -> Dict[str, List]:
        """Get all available devices."""
        return self.available_devices
    
    def synchronize(self, device: Optional[str] = None) -> None:
        """
        Synchronize device (for GPU, waits for all operations to complete).
        
        Args:
            device: Device to synchronize (None for current)
        """
        # In numpy, this is mostly a no-op since operations are synchronous
        pass
    
    def set_device(self, device_type: str, device_id: int = 0) -> None:
        """Set current device."""
        self.device_type = device_type
        self.device_id = device_id


# ============================================================================
# Data Parallelism
# ============================================================================

class DataParallel:
    """
    Data parallel wrapper for single-machine multi-GPU training.
    
    Replicates model across multiple GPUs and distributes data batches.
    
    Args:
        model: Model to parallelize
        device_ids: List of GPU IDs to use (default: all available)
        output_device: Device for output (default: device_ids[0])
    
    Example:
        >>> model = MyModel()
        >>> parallel_model = DataParallel(model, device_ids=[0, 1, 2])
        >>> output = parallel_model(input_data)  # Distributed batch
    """
    
    def __init__(self, model: Any, device_ids: Optional[List[int]] = None,
                 output_device: Optional[int] = None):
        self.model = model
        self.device_ids = device_ids or [0]
        self.output_device = output_device or self.device_ids[0]
        
        self.num_replicas = len(self.device_ids)
    
    def forward(self, inputs: np.ndarray, *args, **kwargs) -> np.ndarray:
        """
        Forward pass with data parallelism.
        
        Args:
            inputs: Input data to process
            *args, **kwargs: Additional arguments for model
        
        Returns:
            Model output combined from all replicas
        """
        
        # Split input batch across devices
        batch_size = inputs.shape[0]
        batch_per_device = batch_size // self.num_replicas
        
        outputs = []
        
        for device_id in self.device_ids:
            # Get batch for this device
            start_idx = self.device_ids.index(device_id) * batch_per_device
            end_idx = start_idx + batch_per_device if device_id != self.device_ids[-1] else batch_size
            
            batch = inputs[start_idx:end_idx]
            
            # Forward on this device (simulated)
            output = self.model(batch, *args, **kwargs)
            outputs.append(output)
        
        # Concatenate outputs from all devices
        return np.concatenate(outputs, axis=0)
    
    def get_model(self):
        """Get underlying model."""
        return self.model


# ============================================================================
# Distributed Data Parallel
# ============================================================================

class DistributedDataParallel:
    """
    Distributed data parallel for multi-machine training.
    
    Synchronizes gradients across processes for distributed training.
    
    Args:
        model: Model to distribute
        process_group: Process group for communication (optional)
        rank: Rank of current process
        world_size: Total number of processes
    
    Example:
        >>> model = MyModel()
        >>> dist_model = DistributedDataParallel(model, rank=0, world_size=4)
        >>> loss = dist_model.compute_loss(outputs, targets)
    """
    
    def __init__(self, model: Any, process_group: Optional[Any] = None,
                 rank: int = 0, world_size: int = 1):
        self.model = model
        self.process_group = process_group
        self.rank = rank
        self.world_size = world_size
        
        self.requires_gradient_sync = world_size > 1
    
    def forward(self, inputs: np.ndarray) -> np.ndarray:
        """Forward pass."""
        return self.model(inputs)
    
    def synchronize_gradients(self, gradients: Dict[str, np.ndarray]) -> Dict[str, np.ndarray]:
        """
        Synchronize gradients across all processes using AllReduce.
        
        Args:
            gradients: Gradient dictionary
        
        Returns:
            Averaged gradients from all processes
        """
        
        if not self.requires_gradient_sync:
            return gradients
        
        # Average gradients across all processes
        synchronized = {}
        for key, grad in gradients.items():
            # Simulate AllReduce: average gradients
            synchronized[key] = grad / self.world_size
        
        return synchronized
    
    def get_model(self):
        """Get underlying model."""
        return self.model


# ============================================================================
# Gradient Synchronization
# ============================================================================

class GradientSynchronizer:
    """
    Handles gradient synchronization for distributed training.
    
    Supports different synchronization strategies (eager, bucketing, etc.).
    
    Args:
        world_size: Number of distributed processes
        backend: Communication backend ('nccl', 'gloo', 'mpi')
    
    Example:
        >>> sync = GradientSynchronizer(world_size=4, backend='nccl')
        >>> synced_grads = sync.synchronize(grads)
    """
    
    def __init__(self, world_size: int = 1, backend: str = 'nccl'):
        self.world_size = world_size
        self.backend = backend
        self.requires_sync = world_size > 1
    
    def synchronize(self, gradients: Dict[str, np.ndarray],
                   operation: str = 'mean') -> Dict[str, np.ndarray]:
        """
        Synchronize gradients across all processes.
        
        Args:
            gradients: Gradient dictionary
            operation: 'mean', 'sum', or 'max'
        
        Returns:
            Synchronized gradients
        """
        
        if not self.requires_sync:
            return gradients
        
        synchronized = {}
        for key, grad in gradients.items():
            if operation == 'mean':
                synchronized[key] = grad / self.world_size
            elif operation == 'sum':
                synchronized[key] = grad * self.world_size
            elif operation == 'max':
                synchronized[key] = grad
            else:
                raise ValueError(f"Unknown operation: {operation}")
        
        return synchronized
    
    def all_reduce(self, neurx: np.ndarray,
                  operation: str = 'sum') -> np.ndarray:
        """
        All-reduce operation on neurx.
        
        Args:
            neurx: Tensor to reduce
            operation: 'sum', 'mean', 'max', 'min'
        
        Returns:
            Reduced neurx
        """
        
        if not self.requires_sync:
            return neurx
        
        if operation == 'sum':
            return neurx * self.world_size
        elif operation == 'mean':
            return neurx / self.world_size
        elif operation == 'max':
            return neurx
        elif operation == 'min':
            return neurx
        else:
            raise ValueError(f"Unknown operation: {operation}")


# ============================================================================
# Distributed Sampler
# ============================================================================

class DistributedSampler:
    """
    Sampler for distributed training.
    
    Ensures each process gets a different subset of data (no duplication).
    
    Args:
        num_samples: Total number of samples
        rank: Rank of current process
        world_size: Total number of processes
        shuffle: Whether to shuffle data
        seed: Random seed for shuffling
    
    Example:
        >>> sampler = DistributedSampler(1000, rank=0, world_size=4)
        >>> indices = sampler.get_indices()
    """
    
    def __init__(self, num_samples: int, rank: int = 0, world_size: int = 1,
                 shuffle: bool = True, seed: int = 0):
        self.num_samples = num_samples
        self.rank = rank
        self.world_size = world_size
        self.shuffle = shuffle
        self.seed = seed
    
    def get_indices(self) -> np.ndarray:
        """
        Get indices for this process.
        
        Returns:
            Array of indices for this process's data
        """
        
        indices = np.arange(self.num_samples)
        
        if self.shuffle:
            np.random.seed(self.seed)
            np.random.shuffle(indices)
        
        # Partition data: each process gets contiguous chunk
        samples_per_process = self.num_samples // self.world_size
        start = self.rank * samples_per_process
        end = start + samples_per_process if self.rank < self.world_size - 1 else self.num_samples
        
        return indices[start:end]
    
    def __len__(self) -> int:
        """Number of samples for this process."""
        return len(self.get_indices())


# ============================================================================
# Utility Functions
# ============================================================================

def is_distributed() -> bool:
    """Check if running in distributed mode."""
    # Would check for environment variables like RANK, WORLD_SIZE
    import os
    return 'RANK' in os.environ and 'WORLD_SIZE' in os.environ


def get_rank() -> int:
    """Get current process rank."""
    import os
    return int(os.environ.get('RANK', '0'))


def get_world_size() -> int:
    """Get total number of processes."""
    import os
    return int(os.environ.get('WORLD_SIZE', '1'))


def barrier() -> None:
    """Synchronization barrier for all processes."""
    # In distributed training, this waits for all processes to reach this point
    pass


__all__ = [
    'DeviceManager',
    'DataParallel',
    'DistributedDataParallel',
    'GradientSynchronizer',
    'DistributedSampler',
    'is_distributed',
    'get_rank',
    'get_world_size',
    'barrier',
]
