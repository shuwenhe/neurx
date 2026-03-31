"""Distributed training utilities for neurx.

This module provides process-group lifecycle and collective communication
primitives backed by ``torch.distributed``. On Ascend environments it uses
HCCL; on CPU it can fall back to Gloo.
"""

from __future__ import annotations

import datetime
import os
from typing import Optional, List, Dict, Any

import numpy as np

try:
    import torch
    import torch.distributed as _torch_dist
except Exception:
    torch = None
    _torch_dist = None


_REDUCE_OPS = {
    "sum": "SUM",
    "mean": "SUM",
    "max": "MAX",
    "min": "MIN",
    "prod": "PRODUCT",
}


def _distributed_available() -> bool:
    return _torch_dist is not None and hasattr(_torch_dist, "is_available") and _torch_dist.is_available()


def _env_int(name: str, default: int) -> int:
    value = os.environ.get(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"{name} must be an integer, got {value!r}") from exc


def _resolve_backend(backend: Optional[str]) -> str:
    requested = (backend or os.environ.get("TENSOR_DIST_BACKEND") or "").strip().lower()
    if not requested:
        requested = "hccl" if _npu_available() else "gloo"
    if requested == "nccl" and _npu_available():
        # Keep existing config compatibility while using Ascend backend.
        requested = "hccl"
    if requested not in {"hccl", "gloo", "nccl"}:
        raise ValueError(f"Unsupported backend: {requested}")
    return requested


def _npu_available() -> bool:
    if torch is None:
        return False
    return bool(hasattr(torch, "npu") and torch.npu.is_available())


def _current_world_size_from_runtime() -> int:
    if _distributed_available() and _torch_dist.is_initialized():
        return int(_torch_dist.get_world_size())
    return _env_int("WORLD_SIZE", 1)


def _to_collective_tensor(arr: np.ndarray, backend: str):
    if torch is None:
        raise RuntimeError("torch is required for distributed collectives")
    np_arr = np.ascontiguousarray(arr)
    dtype = np_arr.dtype
    if backend == "hccl":
        # Ascend HCCL typically expects float16/float32/int32/int64.
        if dtype == np.float64:
            np_arr = np_arr.astype(np.float32, copy=False)
        tensor = torch.from_numpy(np_arr).to("npu")
    else:
        tensor = torch.from_numpy(np_arr)
    return tensor, dtype


def _from_collective_tensor(tensor, original_dtype: np.dtype) -> np.ndarray:
    host = tensor.detach().cpu().numpy()
    if host.dtype != original_dtype:
        host = host.astype(original_dtype, copy=False)
    return host


def init_process_group(
    backend: Optional[str] = None,
    rank: Optional[int] = None,
    world_size: Optional[int] = None,
    init_method: Optional[str] = None,
    timeout_seconds: int = 1800,
) -> None:
    """Initialize distributed process group.

    Uses environment defaults when optional args are omitted:
    ``RANK``, ``WORLD_SIZE``, ``MASTER_ADDR``, ``MASTER_PORT``.
    """
    if not _distributed_available():
        raise RuntimeError("torch.distributed is unavailable in current runtime")
    if _torch_dist.is_initialized():
        return

    resolved_backend = _resolve_backend(backend)
    resolved_rank = _env_int("RANK", 0) if rank is None else int(rank)
    resolved_world_size = _env_int("WORLD_SIZE", 1) if world_size is None else int(world_size)

    if resolved_world_size < 1:
        raise ValueError("world_size must be >= 1")
    if resolved_rank < 0 or resolved_rank >= resolved_world_size:
        raise ValueError("rank must satisfy 0 <= rank < world_size")

    if init_method is None:
        master_addr = os.environ.get("MASTER_ADDR", "127.0.0.1")
        master_port = os.environ.get("MASTER_PORT", "29500")
        init_method = f"tcp://{master_addr}:{master_port}"

    if resolved_backend == "hccl":
        if not _npu_available():
            raise RuntimeError("HCCL backend requested but torch.npu is unavailable")
        local_rank = _env_int("LOCAL_RANK", resolved_rank)
        torch.npu.set_device(f"npu:{local_rank}")

    _torch_dist.init_process_group(
        backend=resolved_backend,
        init_method=init_method,
        rank=resolved_rank,
        world_size=resolved_world_size,
        timeout=datetime.timedelta(seconds=int(timeout_seconds)),
    )


def destroy_process_group() -> None:
    """Destroy current process group if initialized."""
    if _distributed_available() and _torch_dist.is_initialized():
        _torch_dist.destroy_process_group()


def is_initialized() -> bool:
    """Return True when torch distributed process group is initialized."""
    return bool(_distributed_available() and _torch_dist.is_initialized())


def all_reduce(array: np.ndarray, operation: str = "sum") -> np.ndarray:
    """All-reduce a NumPy array across processes.

    Returns reduced values on all ranks.
    """
    if not is_initialized() or get_world_size() <= 1:
        return array

    op_name = operation.strip().lower()
    if op_name not in _REDUCE_OPS:
        raise ValueError(f"Unknown operation: {operation}")
    backend = _torch_dist.get_backend()
    tensor, original_dtype = _to_collective_tensor(array, backend)
    reduce_op = getattr(_torch_dist.ReduceOp, _REDUCE_OPS[op_name])
    _torch_dist.all_reduce(tensor, op=reduce_op)
    out = _from_collective_tensor(tensor, original_dtype)
    if op_name == "mean":
        out = out / float(get_world_size())
    return out


def broadcast(array: np.ndarray, src: int = 0) -> np.ndarray:
    """Broadcast a NumPy array from ``src`` rank to all ranks."""
    if not is_initialized() or get_world_size() <= 1:
        return array
    backend = _torch_dist.get_backend()
    tensor, original_dtype = _to_collective_tensor(array, backend)
    _torch_dist.broadcast(tensor, src=int(src))
    return _from_collective_tensor(tensor, original_dtype)


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
    
    def get_device(self, device_type: Optional[str] = None, device_id: int = 0) -> str:
        """Get current device string; optionally update current selection."""
        if device_type is not None:
            if device_type in ('cpu', 'cuda'):
                self.device_type = device_type
                self.device_id = int(device_id)
            elif device_type in ('gpu',):
                self.device_type = 'cuda'
                self.device_id = int(device_id)
            else:
                raise ValueError(f"Unsupported device type: {device_type}")

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

    def __call__(self, inputs: np.ndarray, *args, **kwargs) -> np.ndarray:
        return self.forward(inputs, *args, **kwargs)
    
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
        self.rank = int(rank)
        self.world_size = int(world_size)
        if is_initialized():
            self.rank = get_rank()
            self.world_size = get_world_size()
        
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
        
        # Average gradients across all processes.
        synchronized = {}
        for key, grad in gradients.items():
            synchronized[key] = all_reduce(grad, operation='mean')
        
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
        self.world_size = int(world_size)
        self.backend = backend
        self.requires_sync = self.world_size > 1
        if self.requires_sync and not is_initialized():
            init_process_group(backend=backend, world_size=self.world_size)
    
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
        
        synchronized: Dict[str, np.ndarray] = {}
        for key, grad in gradients.items():
            synchronized[key] = self.all_reduce(grad, operation=operation)
        
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
        
        if not self.requires_sync or self.world_size <= 1:
            return neurx
        return all_reduce(neurx, operation=operation)


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
    if is_initialized():
        return int(_torch_dist.get_rank())
    return _env_int('RANK', 0)


def get_world_size() -> int:
    """Get total number of processes."""
    if is_initialized():
        return int(_torch_dist.get_world_size())
    return _env_int('WORLD_SIZE', 1)


def barrier() -> None:
    """Synchronization barrier for all processes."""
    if is_initialized() and get_world_size() > 1:
        _torch_dist.barrier()


__all__ = [
    'DeviceManager',
    'DataParallel',
    'DistributedDataParallel',
    'GradientSynchronizer',
    'DistributedSampler',
    'init_process_group',
    'destroy_process_group',
    'is_initialized',
    'all_reduce',
    'broadcast',
    'is_distributed',
    'get_rank',
    'get_world_size',
    'barrier',
]
