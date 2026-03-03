"""
Week 7: Model Profiling and Performance Analysis

Tools for profiling model performance, analyzing memory usage, 
computing FLOPs, and identifying bottlenecks.
"""

import numpy as np
import time
from typing import Optional, Dict, Any, Tuple
import sys


# ============================================================================
# FLOP Counting
# ============================================================================

def count_flops_linear(input_size: int, output_size: int, batch_size: int = 1) -> int:
    """
    Count FLOPs for linear layer.
    
    Linear layer: y = Wx + b
    FLOPs = 2 * input_size * output_size (multiply-accumulate)
    
    Args:
        input_size: Input feature dimension
        output_size: Output feature dimension
        batch_size: Batch size
    
    Returns:
        Total FLOPs
    
    Example:
        >>> flops = count_flops_linear(784, 128, batch_size=32)
    """
    
    # Multiply-accumulate: (input_size - 1) adds + input_size multiplies
    mul_add_flops = input_size * output_size * batch_size * 2
    # Bias addition
    bias_flops = output_size * batch_size
    
    return mul_add_flops + bias_flops


def count_flops_conv2d(in_channels: int, out_channels: int, kernel_size: int,
                      input_height: int, input_width: int, batch_size: int = 1,
                      padding: int = 0, stride: int = 1) -> int:
    """
    Count FLOPs for 2D convolution.
    
    Args:
        in_channels: Number of input channels
        out_channels: Number of output channels
        kernel_size: Size of convolution kernel
        input_height: Input height
        input_width: Input width
        batch_size: Batch size
        padding: Padding size
        stride: Stride size
    
    Returns:
        Total FLOPs
    """
    
    # Output spatial dimensions
    out_h = (input_height + 2 * padding - kernel_size) // stride + 1
    out_w = (input_width + 2 * padding - kernel_size) // stride + 1
    
    # FLOPs per output pixel: kernel_size^2 * in_channels multiplies + accumulates
    kernel_flops = kernel_size * kernel_size * in_channels * 2
    
    # Total output pixels
    total_output_pixels = batch_size * out_channels * out_h * out_w
    
    # Total FLOPs
    flops = kernel_flops * total_output_pixels
    
    # Bias
    flops += out_channels * out_h * out_w * batch_size
    
    return flops


def count_flops_matmul(m: int, n: int, k: int) -> int:
    """
    Count FLOPs for matrix multiplication (m x k) @ (k x n).
    
    Args:
        m, n, k: Matrix dimensions
    
    Returns:
        Total FLOPs
    """
    
    # Each output element: k multiplies and k-1 additions
    return m * n * (2 * k - 1)


# ============================================================================
# Memory Profiler
# ============================================================================

class MemoryProfiler:
    """
    Profile memory usage of models and operations.
    
    Tracks peak memory, allocated memory, and memory per layer.
    
    Example:
        >>> profiler = MemoryProfiler()
        >>> profiler.start_measurement()
        >>> # ... model forward pass ...
        >>> stats = profiler.get_memory_stats()
    """
    
    def __init__(self):
        self.start_memory = 0
        self.peak_memory = 0
        self.allocated_memory = 0
        self.layer_memory = {}
    
    def get_current_memory(self) -> int:
        """Get current memory usage in bytes."""
        return sys.getsizeof(self) * 1024  # Simplified for demo
    
    def start_measurement(self) -> None:
        """Start measuring memory."""
        self.start_memory = self.get_current_memory()
        self.peak_memory = self.start_memory
        self.layer_memory = {}
    
    def record_layer_memory(self, layer_name: str, 
                          weights: Optional[np.ndarray] = None,
                          activations: Optional[np.ndarray] = None) -> None:
        """Record memory for a layer."""
        
        total_bytes = 0
        
        if weights is not None:
            total_bytes += weights.nbytes
        
        if activations is not None:
            total_bytes += activations.nbytes
        
        self.layer_memory[layer_name] = total_bytes
        self.allocated_memory += total_bytes
        self.peak_memory = max(self.peak_memory, self.allocated_memory)
    
    def get_memory_stats(self) -> Dict[str, Any]:
        """Get memory statistics."""
        
        return {
            'peak_memory_mb': self.peak_memory / 1e6,
            'allocated_memory_mb': self.allocated_memory / 1e6,
            'layer_memory_mb': {k: v / 1e6 for k, v in self.layer_memory.items()},
            'num_layers': len(self.layer_memory),
        }
    
    def reset(self) -> None:
        """Reset profiler."""
        self.__init__()


# ============================================================================
# Time Profiler
# ============================================================================

class TimeProfiler:
    """
    Profile execution time of models and operations.
    
    Tracks forward time, backward time, and per-layer timing.
    
    Example:
        >>> profiler = TimeProfiler()
        >>> with profiler.measure('forward'):
        ...     output = model(input_data)
        >>> stats = profiler.get_timing_stats()
    """
    
    def __init__(self):
        self.timings = {}
        self.current_operation = None
        self.start_time = None
    
    def measure(self, operation_name: str):
        """Context manager for measuring operation time."""
        return _TimeMeasurement(self, operation_name)
    
    def start_operation(self, operation_name: str) -> None:
        """Start timing an operation."""
        self.current_operation = operation_name
        self.start_time = time.time()
    
    def end_operation(self) -> float:
        """End timing and return elapsed time."""
        elapsed = time.time() - self.start_time
        
        if self.current_operation not in self.timings:
            self.timings[self.current_operation] = []
        
        self.timings[self.current_operation].append(elapsed)
        return elapsed
    
    def get_timing_stats(self) -> Dict[str, Any]:
        """Get timing statistics."""
        
        stats = {}
        for op_name, times in self.timings.items():
            stats[op_name] = {
                'count': len(times),
                'total_ms': sum(times) * 1000,
                'mean_ms': np.mean(times) * 1000,
                'min_ms': np.min(times) * 1000,
                'max_ms': np.max(times) * 1000,
                'std_ms': np.std(times) * 1000,
            }
        
        return stats
    
    def reset(self) -> None:
        """Reset profiler."""
        self.__init__()


class _TimeMeasurement:
    """Context manager for time measurement."""
    
    def __init__(self, profiler: TimeProfiler, operation_name: str):
        self.profiler = profiler
        self.operation_name = operation_name
    
    def __enter__(self):
        self.profiler.start_operation(self.operation_name)
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.profiler.end_operation()


# ============================================================================
# Model Analyzer
# ============================================================================

class ModelAnalyzer:
    """
    Comprehensive model analysis tool.
    
    Analyzes model architecture, parameter count, memory usage, and FLOPs.
    
    Example:
        >>> analyzer = ModelAnalyzer()
        >>> analyzer.analyze_weights(weights)
        >>> report = analyzer.get_analysis_report()
    """
    
    def __init__(self):
        self.parameters = {}
        self.flops_estimate = 0
        self.memory_estimate = 0
        self.layer_info = {}
    
    def analyze_weights(self, weights: Dict[str, np.ndarray]) -> Dict[str, Any]:
        """
        Analyze weight dictionary.
        
        Args:
            weights: Dictionary of weight arrays
        
        Returns:
            Analysis dictionary
        """
        
        self.parameters = {}
        self.memory_estimate = 0
        
        for name, weight in weights.items():
            param_count = weight.size
            memory_bytes = weight.nbytes
            
            self.parameters[name] = {
                'shape': weight.shape,
                'dtype': weight.dtype,
                'count': param_count,
                'memory_mb': memory_bytes / 1e6,
            }
            
            self.memory_estimate += memory_bytes
        
        return {
            'total_parameters': sum(p['count'] for p in self.parameters.values()),
            'total_memory_mb': self.memory_estimate / 1e6,
            'layer_count': len(self.parameters),
        }
    
    def estimate_flops(self, input_shape: Tuple, config: Dict[str, Any]) -> int:
        """
        Estimate FLOPs from config.
        
        Args:
            input_shape: Input tensor shape
            config: Model configuration with layer specs
        
        Returns:
            Estimated FLOPs
        """
        
        total_flops = 0
        
        # Example: estimate from config
        if 'layers' in config:
            for layer in config['layers']:
                if layer.get('type') == 'linear':
                    flops = count_flops_linear(
                        layer['input_size'],
                        layer['output_size'],
                        batch_size=input_shape[0]
                    )
                    total_flops += flops
        
        self.flops_estimate = total_flops
        return total_flops
    
    def get_analysis_report(self) -> Dict[str, Any]:
        """Get comprehensive analysis report."""
        
        return {
            'total_parameters': sum(p['count'] for p in self.parameters.values()),
            'total_memory_mb': self.memory_estimate / 1e6,
            'estimated_flops': self.flops_estimate,
            'layer_details': self.parameters,
        }


# ============================================================================
# Profiling Utilities
# ============================================================================

def profile_forward_pass(model: Any, input_data: np.ndarray,
                        num_iterations: int = 10) -> Dict[str, Any]:
    """
    Profile forward pass performance.
    
    Args:
        model: Model to profile
        input_data: Input data
        num_iterations: Number of iterations for averaging
    
    Returns:
        Profiling results
    """
    
    times = []
    
    for _ in range(num_iterations):
        start = time.time()
        _ = model(input_data)
        times.append(time.time() - start)
    
    return {
        'mean_time_ms': np.mean(times) * 1000,
        'std_time_ms': np.std(times) * 1000,
        'min_time_ms': np.min(times) * 1000,
        'max_time_ms': np.max(times) * 1000,
        'throughput_samples_per_sec': input_data.shape[0] / np.mean(times),
    }


def estimate_training_time(total_samples: int, batch_size: int,
                          avg_batch_time_ms: float, num_epochs: int) -> Dict[str, Any]:
    """
    Estimate training time.
    
    Args:
        total_samples: Total number of training samples
        batch_size: Batch size
        avg_batch_time_ms: Average time per batch in milliseconds
        num_epochs: Number of epochs
    
    Returns:
        Training time estimates
    """
    
    batches_per_epoch = total_samples / batch_size
    total_batches = batches_per_epoch * num_epochs
    total_time_sec = total_batches * (avg_batch_time_ms / 1000)
    
    return {
        'batches_per_epoch': int(batches_per_epoch),
        'total_batches': int(total_batches),
        'total_time_seconds': total_time_sec,
        'total_time_minutes': total_time_sec / 60,
        'total_time_hours': total_time_sec / 3600,
    }


__all__ = [
    'count_flops_linear',
    'count_flops_conv2d',
    'count_flops_matmul',
    'MemoryProfiler',
    'TimeProfiler',
    'ModelAnalyzer',
    'profile_forward_pass',
    'estimate_training_time',
]
