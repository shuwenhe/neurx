"""
Week 7: Integration Utilities

Bridge between neurx and PyTorch, unified device management,
and format conversion utilities.
"""

import numpy as np
from typing import Dict, Any, Optional, Tuple
import warnings


# ============================================================================
# PyTorch Conversion
# ============================================================================

def convert_from_pytorch(pytorch_state: Dict[str, Any]) -> Dict[str, np.ndarray]:
    """
    Convert PyTorch model state to neurx format.
    
    Converts torch.Tensor to numpy arrays while preserving structure.
    
    Args:
        pytorch_state: Dictionary from PyTorch model.state_dict()
    
    Returns:
        Dictionary of numpy arrays
    
    Example:
        >>> import torch
        >>> model = torch.nn.Linear(10, 5)
        >>> pytorch_state = model.state_dict()
        >>> neurx_weights = convert_from_pytorch(pytorch_state)
    """
    
    neurx_weights = {}
    
    for name, tensor in pytorch_state.items():
        # Convert torch tensor to numpy
        try:
            # Try to convert tensor to numpy
            if hasattr(tensor, 'cpu'):
                tensor = tensor.cpu()
            if hasattr(tensor, 'detach'):
                tensor = tensor.detach()
            if hasattr(tensor, 'numpy'):
                neurx_weights[name] = tensor.numpy()
            else:
                neurx_weights[name] = np.array(tensor)
        except Exception as e:
            warnings.warn(f"Failed to convert {name}: {e}")
            neurx_weights[name] = np.array(tensor)
    
    return neurx_weights


def convert_to_pytorch(neurx_weights: Dict[str, np.ndarray]) -> Dict[str, Any]:
    """
    Convert neurx weights to PyTorch format.
    
    Converts numpy arrays to torch.Tensor format.
    
    Args:
        neurx_weights: Dictionary of numpy arrays
    
    Returns:
        Dictionary of torch tensors (or dict representation)
    
    Example:
        >>> neurx_weights = {'w': np.random.randn(10, 5)}
        >>> pytorch_weights = convert_to_pytorch(neurx_weights)
    """
    
    pytorch_weights = {}
    
    for name, array in neurx_weights.items():
        # Convert numpy to torch tensor representation
        try:
            import torch
            pytorch_weights[name] = torch.from_numpy(array.copy()).float()
        except ImportError:
            # PyTorch not available - return dict representation
            pytorch_weights[name] = {
                'value': array.tolist(),
                'shape': array.shape,
                'dtype': str(array.dtype),
            }
    
    return pytorch_weights


def get_pytorch_model_info(pytorch_model: Any) -> Dict[str, Any]:
    """
    Extract information from PyTorch model.
    
    Args:
        pytorch_model: PyTorch nn.Module instance
    
    Returns:
        Model information dictionary
    
    Example:
        >>> import torch
        >>> model = torch.nn.Sequential(
        ...     torch.nn.Linear(10, 5),
        ...     torch.nn.ReLU(),
        ...     torch.nn.Linear(5, 2)
        ... )
        >>> info = get_pytorch_model_info(model)
    """
    
    info = {
        'num_parameters': 0,
        'num_trainable': 0,
        'num_non_trainable': 0,
        'modules': [],
    }
    
    try:
        for name, param in pytorch_model.named_parameters():
            param_count = param.numel()
            info['num_parameters'] += param_count
            
            if param.requires_grad:
                info['num_trainable'] += param_count
            else:
                info['num_non_trainable'] += param_count
        
        # Module information
        for name, module in pytorch_model.named_modules():
            info['modules'].append({
                'name': name,
                'type': module.__class__.__name__,
            })
    except Exception as e:
        warnings.warn(f"Could not extract full model info: {e}")
    
    return info


# ============================================================================
# Format Conversion
# ============================================================================

def convert_array_format(array: np.ndarray, target_format: str) -> np.ndarray:
    """
    Convert numpy array between formats (uint8, float32, etc.).
    
    Args:
        array: Input numpy array
        target_format: Target dtype ('uint8', 'int32', 'float32', 'float64')
    
    Returns:
        Converted array
    
    Example:
        >>> arr = np.random.randn(10, 5).astype(np.float32)
        >>> arr_uint8 = convert_array_format(arr, 'uint8')
    """
    
    if target_format == 'uint8':
        if array.dtype == np.float32 or array.dtype == np.float64:
            # Normalize to [0, 255]
            array = np.clip(array * 255, 0, 255)
        return array.astype(np.uint8)
    
    elif target_format == 'int32':
        return array.astype(np.int32)
    
    elif target_format == 'float32':
        if array.dtype == np.uint8:
            return (array.astype(np.float32) / 255.0)
        return array.astype(np.float32)
    
    elif target_format == 'float64':
        if array.dtype == np.uint8:
            return (array.astype(np.float64) / 255.0)
        return array.astype(np.float64)
    
    else:
        raise ValueError(f"Unknown format: {target_format}")


def normalize_weights(weights: Dict[str, np.ndarray], 
                     method: str = 'zero_mean') -> Dict[str, np.ndarray]:
    """
    Normalize weights using various methods.
    
    Args:
        weights: Dictionary of weight arrays
        method: Normalization method ('zero_mean', 'unit_norm', 'layer_norm')
    
    Returns:
        Normalized weights dictionary
    
    Example:
        >>> weights = {'w': np.random.randn(10, 5)}
        >>> norm_weights = normalize_weights(weights, method='unit_norm')
    """
    
    normalized = {}
    
    if method == 'zero_mean':
        # Center to zero mean
        for name, w in weights.items():
            normalized[name] = w - np.mean(w)
    
    elif method == 'unit_norm':
        # Normalize to unit norm
        for name, w in weights.items():
            norm = np.linalg.norm(w)
            normalized[name] = w / (norm + 1e-8)
    
    elif method == 'layer_norm':
        # Layer normalization (normalize each weight matrix)
        for name, w in weights.items():
            mean = np.mean(w)
            std = np.std(w)
            normalized[name] = (w - mean) / (std + 1e-8)
    
    elif method == 'min_max':
        # Min-max scaling to [0, 1]
        for name, w in weights.items():
            w_min = np.min(w)
            w_max = np.max(w)
            normalized[name] = (w - w_min) / (w_max - w_min + 1e-8)
    
    else:
        raise ValueError(f"Unknown normalization method: {method}")
    
    return normalized


# ============================================================================
# Device Utilities
# ============================================================================

class UnifiedDeviceManager:
    """
    Unified device management for neurx and PyTorch.
    
    Abstracts device handling for both frameworks.
    
    Example:
        >>> manager = UnifiedDeviceManager()
        >>> device = manager.get_device('gpu', device_id=0)
        >>> manager.set_device(device)
    """
    
    def __init__(self):
        self.current_device = 'cpu'
        self.pytorch_available = self._check_pytorch()
        self.cuda_available = self._check_cuda()
    
    def _check_pytorch(self) -> bool:
        """Check if PyTorch is available."""
        try:
            import torch
            return True
        except ImportError:
            return False
    
    def _check_cuda(self) -> bool:
        """Check if CUDA is available."""
        if not self.pytorch_available:
            return False
        
        try:
            import torch
            return torch.cuda.is_available()
        except Exception:
            return False
    
    def get_device(self, device_type: str = 'cpu', 
                  device_id: int = 0) -> str:
        """
        Get device string for framework.
        
        Args:
            device_type: 'cpu' or 'gpu'
            device_id: GPU device ID
        
        Returns:
            Device string ('cpu' or 'cuda:0')
        """
        
        if device_type == 'gpu':
            if self.cuda_available:
                self.current_device = f'cuda:{device_id}'
            else:
                warnings.warn("CUDA not available, falling back to CPU")
                self.current_device = 'cpu'
        else:
            self.current_device = 'cpu'
        
        return self.current_device
    
    def to_device(self, data: Any, device: str) -> Any:
        """
        Move data to device (PyTorch compatible).
        
        Args:
            data: Data to move (numpy array or torch tensor)
            device: Target device
        
        Returns:
            Data on target device
        """
        
        if not self.pytorch_available:
            # Return numpy array as-is
            return np.asarray(data)
        
        try:
            import torch
            if isinstance(data, np.ndarray):
                tensor = torch.from_numpy(data)
            else:
                tensor = data
            return tensor.to(device)
        except Exception as e:
            warnings.warn(f"Could not move to device: {e}")
            return data
    
    def get_available_devices(self) -> Dict[str, int]:
        """Get available devices."""
        
        devices = {'cpu': 1}
        
        if self.cuda_available:
            try:
                import torch
                devices['cuda'] = torch.cuda.device_count()
            except Exception:
                pass
        
        return devices
    
    def synchronize(self, device: Optional[str] = None) -> None:
        """Synchronize device (GPU)."""
        
        if device is None:
            device = self.current_device
        
        if 'cuda' in device and self.pytorch_available:
            try:
                import torch
                torch.cuda.synchronize()
            except Exception:
                pass


# ============================================================================
# Compatibility Utilities
# ============================================================================

def ensure_numpy(data: Any) -> np.ndarray:
    """
    Convert various formats to numpy array.
    
    Args:
        data: Input data (list, tuple, array, tensor, etc.)
    
    Returns:
        Numpy array
    
    Example:
        >>> arr = ensure_numpy([1, 2, 3])
        >>> assert isinstance(arr, np.ndarray)
    """
    
    if isinstance(data, np.ndarray):
        return data
    
    try:
        # Try PyTorch tensor
        if hasattr(data, 'numpy'):
            return data.numpy()
        if hasattr(data, 'detach'):
            return data.detach().numpy()
    except Exception:
        pass
    
    # Fallback to numpy conversion
    return np.array(data)


def ensure_list(data: Any) -> list:
    """
    Convert to list format.
    
    Args:
        data: Input data
    
    Returns:
        List representation
    """
    
    if isinstance(data, list):
        return data
    if isinstance(data, np.ndarray):
        return data.tolist()
    if isinstance(data, tuple):
        return list(data)
    
    return [data]


def shape_to_string(shape: Tuple) -> str:
    """Convert shape tuple to string representation."""
    return 'x'.join(str(d) for d in shape)


def parse_shape_string(shape_str: str) -> Tuple:
    """Parse shape string to tuple."""
    return tuple(int(d) for d in shape_str.split('x'))


# ============================================================================
# Model Architecture Utilities
# ============================================================================

def get_layer_config(layer_name: str, layer_type: str, 
                    input_shape: Tuple, output_shape: Tuple) -> Dict[str, Any]:
    """
    Get configuration for a layer.
    
    Args:
        layer_name: Layer name
        layer_type: Layer type (linear, conv2d, etc.)
        input_shape: Input shape
        output_shape: Output shape
    
    Returns:
        Layer configuration dictionary
    """
    
    config = {
        'name': layer_name,
        'type': layer_type,
        'input_shape': input_shape,
        'output_shape': output_shape,
    }
    
    if layer_type == 'linear':
        config['input_features'] = input_shape[-1]
        config['output_features'] = output_shape[-1]
    
    elif layer_type == 'conv2d':
        config['in_channels'] = input_shape[1]
        config['out_channels'] = output_shape[1]
        config['height'] = input_shape[2]
        config['width'] = input_shape[3]
    
    return config


__all__ = [
    'convert_from_pytorch',
    'convert_to_pytorch',
    'get_pytorch_model_info',
    'convert_array_format',
    'normalize_weights',
    'UnifiedDeviceManager',
    'ensure_numpy',
    'ensure_list',
    'shape_to_string',
    'parse_shape_string',
    'get_layer_config',
]
