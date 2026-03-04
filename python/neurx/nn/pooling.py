"""
Pooling layers for feature map downsampling.
Compatible with PyTorch API.
"""

import numpy as np
from ..core import Tensor


class MaxPool1d:
    """1D Max Pooling layer.
    
    Args:
        kernel_size: Size of pooling kernel
        stride: Stride of pooling. Default: None (same as kernel_size)
        padding: Padding to be added. Default: 0
        dilation: Spacing between kernel elements. Default: 1
    """
    
    def __init__(self, kernel_size, stride=None, padding=0, dilation=1):
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size,)
        self.stride = stride if stride is None else (stride if isinstance(stride, tuple) else (stride,))
        if self.stride is None:
            self.stride = self.kernel_size
        self.padding = padding if isinstance(padding, tuple) else (padding,)
        self.dilation = dilation if isinstance(dilation, tuple) else (dilation,)
    
    def forward(self, x):
        """Forward pass of MaxPool1d.
        
        Args:
            x: Input neurx of shape (batch, channels, length)
        
        Returns:
            Output neurx of shape (batch, channels, length_out)
        """
        batch_size, channels, length = x.shape
        kernel_size = self.kernel_size[0]
        stride = self.stride[0]
        padding = self.padding[0]
        dilation = self.dilation[0]
        
        # Apply padding
        if padding > 0:
            x_padded = np.pad(x.data, ((0, 0), (0, 0), (padding, padding)), mode='constant', 
                             constant_values=-np.inf)
        else:
            x_padded = x.data
        
        # Compute output length
        out_length = (length + 2 * padding - dilation * (kernel_size - 1) - 1) // stride + 1
        
        output = np.zeros((batch_size, channels, out_length))
        
        for ol in range(out_length):
            start = ol * stride
            indices = start + np.arange(kernel_size) * dilation
            indices = indices[indices < x_padded.shape[2]]
            output[:, :, ol] = np.max(x_padded[:, :, indices], axis=2)
        
        return Tensor(output, requires_grad=x.requires_grad)
    
    def __call__(self, x):
        return self.forward(x)


class MaxPool2d:
    """2D Max Pooling layer.
    
    Args:
        kernel_size: Size of pooling kernel (int or tuple)
        stride: Stride of pooling. Default: None (same as kernel_size)
        padding: Padding to be added. Default: 0
        dilation: Spacing between kernel elements. Default: 1
        return_indices: If True, returns indices along with output. Default: False
        ceil_mode: Use ceil instead of floor. Default: False
    """
    
    def __init__(self, kernel_size, stride=None, padding=0, dilation=1, return_indices=False, ceil_mode=False):
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size)
        self.stride = stride if stride is None else (stride if isinstance(stride, tuple) else (stride, stride))
        if self.stride is None:
            self.stride = self.kernel_size
        self.padding = padding if isinstance(padding, tuple) else (padding, padding)
        self.dilation = dilation if isinstance(dilation, tuple) else (dilation, dilation)
        self.return_indices = return_indices
        self.ceil_mode = ceil_mode
    
    def forward(self, x):
        """Forward pass of MaxPool2d.
        
        Args:
            x: Input neurx of shape (batch, channels, height, width)
        
        Returns:
            Output neurx of shape (batch, channels, height_out, width_out)
            If return_indices=True, returns (output, indices) where indices are flattened positions in input
        """
        batch_size, channels, height, width = x.shape
        kernel_h, kernel_w = self.kernel_size
        stride_h, stride_w = self.stride
        padding_h, padding_w = self.padding
        dilation_h, dilation_w = self.dilation
        
        # Apply padding
        if padding_h > 0 or padding_w > 0:
            x_padded = np.pad(x.data, ((0, 0), (0, 0), (padding_h, padding_h), (padding_w, padding_w)), 
                             mode='constant', constant_values=-np.inf)
        else:
            x_padded = x.data
        
        # Compute output dimensions
        if self.ceil_mode:
            out_height = int(np.ceil((height + 2 * padding_h - dilation_h * (kernel_h - 1) - 1) / stride_h)) + 1
            out_width = int(np.ceil((width + 2 * padding_w - dilation_w * (kernel_w - 1) - 1) / stride_w)) + 1
        else:
            out_height = (height + 2 * padding_h - dilation_h * (kernel_h - 1) - 1) // stride_h + 1
            out_width = (width + 2 * padding_w - dilation_w * (kernel_w - 1) - 1) // stride_w + 1
        
        output = np.zeros((batch_size, channels, out_height, out_width))
        max_h_idx = np.zeros((batch_size, channels, out_height, out_width), dtype=np.int64) if self.return_indices else None
        max_w_idx = np.zeros((batch_size, channels, out_height, out_width), dtype=np.int64) if self.return_indices else None
        
        for bi in range(batch_size):
            for ci in range(channels):
                for oh in range(out_height):
                    for ow in range(out_width):
                        h_start = oh * stride_h
                        w_start = ow * stride_w
                        best_val = -np.inf
                        best_h = -1
                        best_w = -1
                        
                        for kh in range(kernel_h):
                            ih = h_start + kh * dilation_h
                            if ih < 0 or ih >= x_padded.shape[2]:
                                continue
                            for kw in range(kernel_w):
                                iw = w_start + kw * dilation_w
                                if iw < 0 or iw >= x_padded.shape[3]:
                                    continue
                                val = x_padded[bi, ci, ih, iw]
                                if val > best_val:
                                    best_val = val
                                    best_h = ih
                                    best_w = iw
                        
                        output[bi, ci, oh, ow] = best_val
                        if self.return_indices:
                            max_h_idx[bi, ci, oh, ow] = best_h
                            max_w_idx[bi, ci, oh, ow] = best_w
        
        if self.return_indices:
            # Convert to flattened indices: (h - padding) * width + (w - padding)
            flat_indices = (max_h_idx - padding_h) * width + (max_w_idx - padding_w)
            # Mark out-of-bounds as -1
            flat_indices[(max_h_idx < padding_h) | (max_h_idx >= padding_h + height) | 
                        (max_w_idx < padding_w) | (max_w_idx >= padding_w + width)] = -1
            return Tensor(output, requires_grad=x.requires_grad), Tensor(flat_indices, requires_grad=False)
        else:
            return Tensor(output, requires_grad=x.requires_grad)
    
    def __call__(self, x):
        return self.forward(x)


class MaxPool3d:
    """3D Max Pooling layer."""
    
    def __init__(self, kernel_size, stride=None, padding=0, dilation=1, ceil_mode=False):
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size, kernel_size)
        self.stride = stride if stride is None else (stride if isinstance(stride, tuple) else (stride, stride, stride))
        if self.stride is None:
            self.stride = self.kernel_size
        self.padding = padding if isinstance(padding, tuple) else (padding, padding, padding)
        self.dilation = dilation if isinstance(dilation, tuple) else (dilation, dilation, dilation)
        self.ceil_mode = ceil_mode
    
    def forward(self, x):
        batch_size, channels, depth, height, width = x.shape
        kernel_d, kernel_h, kernel_w = self.kernel_size
        stride_d, stride_h, stride_w = self.stride
        padding_d, padding_h, padding_w = self.padding
        dilation_d, dilation_h, dilation_w = self.dilation
        
        if padding_d > 0 or padding_h > 0 or padding_w > 0:
            x_padded = np.pad(x.data, ((0, 0), (0, 0), (padding_d, padding_d), 
                                      (padding_h, padding_h), (padding_w, padding_w)), 
                             mode='constant', constant_values=-np.inf)
        else:
            x_padded = x.data
        
        if self.ceil_mode:
            out_depth = int(np.ceil((depth + 2 * padding_d - dilation_d * (kernel_d - 1) - 1) / stride_d)) + 1
            out_height = int(np.ceil((height + 2 * padding_h - dilation_h * (kernel_h - 1) - 1) / stride_h)) + 1
            out_width = int(np.ceil((width + 2 * padding_w - dilation_w * (kernel_w - 1) - 1) / stride_w)) + 1
        else:
            out_depth = (depth + 2 * padding_d - dilation_d * (kernel_d - 1) - 1) // stride_d + 1
            out_height = (height + 2 * padding_h - dilation_h * (kernel_h - 1) - 1) // stride_h + 1
            out_width = (width + 2 * padding_w - dilation_w * (kernel_w - 1) - 1) // stride_w + 1
        
        output = np.zeros((batch_size, channels, out_depth, out_height, out_width))
        
        for od in range(out_depth):
            for oh in range(out_height):
                for ow in range(out_width):
                    d_start = od * stride_d
                    h_start = oh * stride_h
                    w_start = ow * stride_w
                    d_indices = d_start + np.arange(kernel_d) * dilation_d
                    h_indices = h_start + np.arange(kernel_h) * dilation_h
                    w_indices = w_start + np.arange(kernel_w) * dilation_w
                    
                    d_mesh, h_mesh, w_mesh = np.meshgrid(d_indices, h_indices, w_indices, indexing='ij')
                    output[:, :, od, oh, ow] = np.max(x_padded[:, :, d_mesh, h_mesh, w_mesh], 
                                                       axis=(2, 3, 4))
        
        return Tensor(output, requires_grad=x.requires_grad)
    
    def __call__(self, x):
        return self.forward(x)


class AvgPool1d:
    """1D Average Pooling layer."""
    
    def __init__(self, kernel_size, stride=None, padding=0):
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size,)
        self.stride = stride if stride is None else (stride if isinstance(stride, tuple) else (stride,))
        if self.stride is None:
            self.stride = self.kernel_size
        self.padding = padding if isinstance(padding, tuple) else (padding,)
    
    def forward(self, x):
        batch_size, channels, length = x.shape
        kernel_size = self.kernel_size[0]
        stride = self.stride[0]
        padding = self.padding[0]
        
        if padding > 0:
            x_padded = np.pad(x.data, ((0, 0), (0, 0), (padding, padding)), mode='constant')
        else:
            x_padded = x.data
        
        out_length = (length + 2 * padding - kernel_size) // stride + 1
        output = np.zeros((batch_size, channels, out_length))
        
        for ol in range(out_length):
            start = ol * stride
            end = start + kernel_size
            output[:, :, ol] = np.mean(x_padded[:, :, start:end], axis=2)
        
        return Tensor(output, requires_grad=x.requires_grad)
    
    def __call__(self, x):
        return self.forward(x)


class AvgPool2d:
    """2D Average Pooling layer.
    
    Args:
        kernel_size: Size of pooling kernel (int or tuple)
        stride: Stride of pooling. Default: None (same as kernel_size)
        padding: Padding to be added. Default: 0
        ceil_mode: Use ceil instead of floor. Default: False
        count_include_pad: Count padded elements in average. Default: True
    """
    
    def __init__(self, kernel_size, stride=None, padding=0, ceil_mode=False, count_include_pad=True):
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size)
        self.stride = stride if stride is None else (stride if isinstance(stride, tuple) else (stride, stride))
        if self.stride is None:
            self.stride = self.kernel_size
        self.padding = padding if isinstance(padding, tuple) else (padding, padding)
        self.ceil_mode = ceil_mode
        self.count_include_pad = count_include_pad
    
    def forward(self, x):
        from . import functional as F

        return F.avg_pool2d(
            x,
            kernel_size=self.kernel_size,
            stride=self.stride,
            padding=self.padding,
            ceil_mode=self.ceil_mode,
            count_include_pad=self.count_include_pad,
        )
    
    def __call__(self, x):
        return self.forward(x)


class AvgPool3d:
    """3D Average Pooling layer."""
    
    def __init__(self, kernel_size, stride=None, padding=0, ceil_mode=False, count_include_pad=True):
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size, kernel_size)
        self.stride = stride if stride is None else (stride if isinstance(stride, tuple) else (stride, stride, stride))
        if self.stride is None:
            self.stride = self.kernel_size
        self.padding = padding if isinstance(padding, tuple) else (padding, padding, padding)
        self.ceil_mode = ceil_mode
        self.count_include_pad = count_include_pad
    
    def forward(self, x):
        batch_size, channels, depth, height, width = x.shape
        kernel_d, kernel_h, kernel_w = self.kernel_size
        stride_d, stride_h, stride_w = self.stride
        padding_d, padding_h, padding_w = self.padding
        
        if padding_d > 0 or padding_h > 0 or padding_w > 0:
            x_padded = np.pad(x.data, ((0, 0), (0, 0), (padding_d, padding_d),
                                      (padding_h, padding_h), (padding_w, padding_w)), mode='constant')
        else:
            x_padded = x.data
        
        if self.ceil_mode:
            out_depth = int(np.ceil((depth + 2 * padding_d - kernel_d) / stride_d)) + 1
            out_height = int(np.ceil((height + 2 * padding_h - kernel_h) / stride_h)) + 1
            out_width = int(np.ceil((width + 2 * padding_w - kernel_w) / stride_w)) + 1
        else:
            out_depth = (depth + 2 * padding_d - kernel_d) // stride_d + 1
            out_height = (height + 2 * padding_h - kernel_h) // stride_h + 1
            out_width = (width + 2 * padding_w - kernel_w) // stride_w + 1
        
        output = np.zeros((batch_size, channels, out_depth, out_height, out_width))
        
        for od in range(out_depth):
            for oh in range(out_height):
                for ow in range(out_width):
                    d_start = od * stride_d
                    h_start = oh * stride_h
                    w_start = ow * stride_w
                    
                    if self.count_include_pad:
                        output[:, :, od, oh, ow] = np.mean(x_padded[:, :,
                                                           d_start:d_start+kernel_d,
                                                           h_start:h_start+kernel_h,
                                                           w_start:w_start+kernel_w], axis=(2, 3, 4))
                    else:
                        patch = x_padded[:, :, d_start:d_start+kernel_d,
                                        h_start:h_start+kernel_h, w_start:w_start+kernel_w]
                        output[:, :, od, oh, ow] = np.mean(patch, axis=(2, 3, 4))
        
        return Tensor(output, requires_grad=x.requires_grad)
    
    def __call__(self, x):
        return self.forward(x)


class AdaptiveMaxPool2d:
    """Adaptive 2D Max Pooling layer.
    
    Args:
        output_size: Desired output spatial dimensions
        return_indices: If True, returns indices along with output. Default: False
    """
    
    def __init__(self, output_size, return_indices=False):
        self.output_size = output_size if isinstance(output_size, tuple) else (output_size, output_size)
        self.return_indices = return_indices
    
    def forward(self, x):
        batch_size, channels, height, width = x.shape
        out_height, out_width = self.output_size
        
        # Compute stride and kernel size
        stride_h = height // out_height
        stride_w = width // out_width
        kernel_h = height - (out_height - 1) * stride_h
        kernel_w = width - (out_width - 1) * stride_w
        
        output = np.zeros((batch_size, channels, out_height, out_width))
        indices = np.zeros((batch_size, channels, out_height, out_width), dtype=np.int64) if self.return_indices else None
        
        for oh in range(out_height):
            for ow in range(out_width):
                h_start = oh * stride_h
                w_start = ow * stride_w
                h_end = min(h_start + kernel_h, height)
                w_end = min(w_start + kernel_w, width)
                
                patch = x.data[:, :, h_start:h_end, w_start:w_end]
                output[:, :, oh, ow] = np.max(patch, axis=(2, 3))
                
                if self.return_indices:
                    max_indices = np.argmax(patch.reshape(batch_size, channels, -1), axis=2)
                    indices[:, :, oh, ow] = max_indices
        
        if self.return_indices:
            return Tensor(output, requires_grad=x.requires_grad), Tensor(indices, requires_grad=False)
        else:
            return Tensor(output, requires_grad=x.requires_grad)
    
    def __call__(self, x):
        return self.forward(x)


class AdaptiveAvgPool2d:
    """Adaptive 2D Average Pooling layer.
    
    Args:
        output_size: Desired output spatial dimensions
    """
    
    def __init__(self, output_size):
        self.output_size = output_size if isinstance(output_size, tuple) else (output_size, output_size)
    
    def forward(self, x):
        batch_size, channels, height, width = x.shape
        out_height, out_width = self.output_size
        
        # Compute stride and kernel size
        stride_h = height // out_height
        stride_w = width // out_width
        kernel_h = height - (out_height - 1) * stride_h
        kernel_w = width - (out_width - 1) * stride_w
        
        output = np.zeros((batch_size, channels, out_height, out_width))
        
        for oh in range(out_height):
            for ow in range(out_width):
                h_start = oh * stride_h
                w_start = ow * stride_w
                h_end = min(h_start + kernel_h, height)
                w_end = min(w_start + kernel_w, width)
                
                output[:, :, oh, ow] = np.mean(x.data[:, :, h_start:h_end, w_start:w_end], 
                                              axis=(2, 3))
        
        return Tensor(output, requires_grad=x.requires_grad)
    
    def __call__(self, x):
        return self.forward(x)
