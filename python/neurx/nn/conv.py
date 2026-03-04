"""
Convolutional layers for multi-dimensional convolution operations.
Compatible with PyTorch API.
"""

import numpy as np
from ..core import Tensor


class Conv1d:
    """1D Convolution layer.
    
    Args:
        in_channels: Number of input channels
        out_channels: Number of output channels
        kernel_size: Size of convolution kernel
        stride: Stride of convolution. Default: 1
        padding: Padding to be added. Default: 0
        dilation: Spacing between kernel elements. Default: 1
        groups: Number of groups. Default: 1
        bias: If True, add bias. Default: True
    """
    
    def __init__(self, in_channels, out_channels, kernel_size, 
                 stride=1, padding=0, dilation=1, groups=1, bias=True):
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size,)
        self.stride = stride if isinstance(stride, tuple) else (stride,)
        self.padding = padding if isinstance(padding, tuple) else (padding,)
        self.dilation = dilation if isinstance(dilation, tuple) else (dilation,)
        self.groups = groups
        
        # Weight: (out_channels, in_channels // groups, kernel_size)
        self.weight = Tensor(np.random.randn(out_channels, in_channels // groups, *self.kernel_size) * 
                            np.sqrt(2.0 / (in_channels * np.prod(self.kernel_size))), requires_grad=True)
        
        if bias:
            self.bias = Tensor(np.zeros(out_channels), requires_grad=True)
        else:
            self.bias = None
    
    def forward(self, x):
        """Forward pass of Conv1d.
        
        Args:
            x: Input neurx of shape (batch, in_channels, length)
        
        Returns:
            Output neurx of shape (batch, out_channels, length_out)
        """
        batch_size, in_channels, length = x.shape
        kernel_size = self.kernel_size[0]
        stride = self.stride[0]
        padding = self.padding[0]
        dilation = self.dilation[0]
        
        # Apply padding
        if padding > 0:
            x_padded = np.pad(x.data, ((0, 0), (0, 0), (padding, padding)), mode='constant')
        else:
            x_padded = x.data
        
        # Compute output length
        out_length = (length + 2 * padding - dilation * (kernel_size - 1) - 1) // stride + 1
        
        # Extract patches using stride tricks
        patches = self._extract_patches_1d(x_padded, kernel_size, stride, dilation)
        
        # Reshape for grouped convolution
        patches = patches.reshape(batch_size, self.groups, in_channels // self.groups, 
                                 kernel_size, out_length)
        
        # Perform convolution
        weight_reshaped = self.weight.data.reshape(self.out_channels // self.groups, 
                                                    self.groups, in_channels // self.groups, kernel_size)
        
        output = np.zeros((batch_size, self.out_channels, out_length))
        
        for g in range(self.groups):
            for oc in range(self.out_channels // self.groups):
                for ol in range(out_length):
                    patch = patches[:, g, :, :, ol]  # (batch, in_ch // groups, kernel_size)
                    w = weight_reshaped[oc, g, :, :]  # (in_ch // groups, kernel_size)
                    output[:, g * (self.out_channels // self.groups) + oc, ol] = \
                        np.sum(patch * w[None, :, :], axis=(1, 2))
        
        # Add bias
        if self.bias is not None:
            output = output + self.bias.data[None, :, None]
        
        return Tensor(output, requires_grad=True)
    
    def _extract_patches_1d(self, x, kernel_size, stride, dilation):
        """Extract patches from input neurx."""
        batch_size, in_channels, length = x.shape
        out_length = (length - dilation * (kernel_size - 1) - 1) // stride + 1
        
        patches = np.zeros((batch_size, in_channels, kernel_size, out_length))
        for i in range(out_length):
            start = i * stride
            indices = start + np.arange(kernel_size) * dilation
            patches[:, :, :, i] = x[:, :, indices]
        
        return patches
    
    def __call__(self, x):
        return self.forward(x)


class Conv2d:
    """2D Convolution layer.
    
    Args:
        in_channels: Number of input channels
        out_channels: Number of output channels
        kernel_size: Size of convolution kernel (int or tuple)
        stride: Stride of convolution. Default: 1
        padding: Padding to be added. Default: 0
        dilation: Spacing between kernel elements. Default: 1
        groups: Number of groups. Default: 1
        bias: If True, add bias. Default: True
    """
    
    def __init__(self, in_channels, out_channels, kernel_size,
                 stride=1, padding=0, dilation=1, groups=1, bias=True):
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size)
        self.stride = stride if isinstance(stride, tuple) else (stride, stride)
        self.padding = padding if isinstance(padding, tuple) else (padding, padding)
        self.dilation = dilation if isinstance(dilation, tuple) else (dilation, dilation)
        self.groups = groups
        
        # Weight: (out_channels, in_channels // groups, kernel_h, kernel_w)
        fan_in = in_channels // groups * np.prod(self.kernel_size)
        self.weight = Tensor(np.random.randn(out_channels, in_channels // groups, *self.kernel_size) * 
                            np.sqrt(2.0 / fan_in), requires_grad=True)
        
        if bias:
            self.bias = Tensor(np.zeros(out_channels), requires_grad=True)
        else:
            self.bias = None
    
    def forward(self, x):
        """Forward pass of Conv2d.
        
        Args:
            x: Input neurx of shape (batch, in_channels, height, width)
        
        Returns:
            Output neurx of shape (batch, out_channels, height_out, width_out)
        """
        batch_size, in_channels, height, width = x.shape
        kernel_h, kernel_w = self.kernel_size
        stride_h, stride_w = self.stride
        padding_h, padding_w = self.padding
        dilation_h, dilation_w = self.dilation
        
        # Apply padding
        if padding_h > 0 or padding_w > 0:
            x_padded = np.pad(x.data, ((0, 0), (0, 0), (padding_h, padding_h), (padding_w, padding_w)), 
                             mode='constant')
        else:
            x_padded = x.data
        
        # Compute output dimensions
        out_height = (height + 2 * padding_h - dilation_h * (kernel_h - 1) - 1) // stride_h + 1
        out_width = (width + 2 * padding_w - dilation_w * (kernel_w - 1) - 1) // stride_w + 1
        
        output = np.zeros((batch_size, self.out_channels, out_height, out_width))
        
        # Perform grouped convolution
        in_ch_per_group = in_channels // self.groups
        out_ch_per_group = self.out_channels // self.groups
        
        for g in range(self.groups):
            in_ch_start = g * in_ch_per_group
            in_ch_end = in_ch_start + in_ch_per_group
            out_ch_start = g * out_ch_per_group
            out_ch_end = out_ch_start + out_ch_per_group
            
            x_group = x_padded[:, in_ch_start:in_ch_end, :, :]
            w_group = self.weight.data[out_ch_start:out_ch_end, :, :, :]
            
            # Convolution
            for oh in range(out_height):
                for ow in range(out_width):
                    h_start = oh * stride_h
                    w_start = ow * stride_w
                    h_indices = h_start + np.arange(kernel_h) * dilation_h
                    w_indices = w_start + np.arange(kernel_w) * dilation_w
                    
                    # Extract patch
                    patch = x_group[:, :, h_indices[:, None], w_indices[None, :]]  # (batch, in_ch, kh, kw)
                    
                    # Perform convolution
                    for oc in range(out_ch_per_group):
                        w = w_group[oc, :, :, :]  # (in_ch, kh, kw)
                        output[:, out_ch_start + oc, oh, ow] = np.sum(patch * w[None, :, :, :], 
                                                                       axis=(1, 2, 3))
        
        # Add bias
        if self.bias is not None:
            output = output + self.bias.data[None, :, None, None]
        
        return Tensor(output, requires_grad=True)
    
    def __call__(self, x):
        return self.forward(x)


class Conv3d:
    """3D Convolution layer.
    
    Args:
        in_channels: Number of input channels
        out_channels: Number of output channels
        kernel_size: Size of convolution kernel (int or tuple)
        stride: Stride of convolution. Default: 1
        padding: Padding to be added. Default: 0
        dilation: Spacing between kernel elements. Default: 1
        groups: Number of groups. Default: 1
        bias: If True, add bias. Default: True
    """
    
    def __init__(self, in_channels, out_channels, kernel_size,
                 stride=1, padding=0, dilation=1, groups=1, bias=True):
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size, kernel_size)
        self.stride = stride if isinstance(stride, tuple) else (stride, stride, stride)
        self.padding = padding if isinstance(padding, tuple) else (padding, padding, padding)
        self.dilation = dilation if isinstance(dilation, tuple) else (dilation, dilation, dilation)
        self.groups = groups
        
        # Weight: (out_channels, in_channels // groups, kernel_d, kernel_h, kernel_w)
        fan_in = in_channels // groups * np.prod(self.kernel_size)
        self.weight = Tensor(np.random.randn(out_channels, in_channels // groups, *self.kernel_size) * 
                            np.sqrt(2.0 / fan_in), requires_grad=True)
        
        if bias:
            self.bias = Tensor(np.zeros(out_channels), requires_grad=True)
        else:
            self.bias = None
    
    def forward(self, x):
        """Forward pass of Conv3d.
        
        Args:
            x: Input neurx of shape (batch, in_channels, depth, height, width)
        
        Returns:
            Output neurx of shape (batch, out_channels, depth_out, height_out, width_out)
        """
        batch_size, in_channels, depth, height, width = x.shape
        kernel_d, kernel_h, kernel_w = self.kernel_size
        stride_d, stride_h, stride_w = self.stride
        padding_d, padding_h, padding_w = self.padding
        dilation_d, dilation_h, dilation_w = self.dilation
        
        # Apply padding
        if padding_d > 0 or padding_h > 0 or padding_w > 0:
            x_padded = np.pad(x.data, ((0, 0), (0, 0), (padding_d, padding_d), 
                                      (padding_h, padding_h), (padding_w, padding_w)), mode='constant')
        else:
            x_padded = x.data
        
        # Compute output dimensions
        out_depth = (depth + 2 * padding_d - dilation_d * (kernel_d - 1) - 1) // stride_d + 1
        out_height = (height + 2 * padding_h - dilation_h * (kernel_h - 1) - 1) // stride_h + 1
        out_width = (width + 2 * padding_w - dilation_w * (kernel_w - 1) - 1) // stride_w + 1
        
        output = np.zeros((batch_size, self.out_channels, out_depth, out_height, out_width))
        
        # Perform grouped convolution
        in_ch_per_group = in_channels // self.groups
        out_ch_per_group = self.out_channels // self.groups
        
        for g in range(self.groups):
            in_ch_start = g * in_ch_per_group
            in_ch_end = in_ch_start + in_ch_per_group
            out_ch_start = g * out_ch_per_group
            out_ch_end = out_ch_start + out_ch_per_group
            
            x_group = x_padded[:, in_ch_start:in_ch_end, :, :, :]
            w_group = self.weight.data[out_ch_start:out_ch_end, :, :, :, :]
            
            # Convolution
            for od in range(out_depth):
                for oh in range(out_height):
                    for ow in range(out_width):
                        d_start = od * stride_d
                        h_start = oh * stride_h
                        w_start = ow * stride_w
                        d_indices = d_start + np.arange(kernel_d) * dilation_d
                        h_indices = h_start + np.arange(kernel_h) * dilation_h
                        w_indices = w_start + np.arange(kernel_w) * dilation_w
                        
                        # Extract patch using meshgrid
                        d_mesh, h_mesh, w_mesh = np.meshgrid(d_indices, h_indices, w_indices, indexing='ij')
                        patch = x_group[:, :, d_mesh, h_mesh, w_mesh]  # (batch, in_ch, kd, kh, kw)
                        
                        # Perform convolution
                        for oc in range(out_ch_per_group):
                            w = w_group[oc, :, :, :, :]  # (in_ch, kd, kh, kw)
                            output[:, out_ch_start + oc, od, oh, ow] = \
                                np.sum(patch * w[None, :, :, :, :], axis=(1, 2, 3, 4))
        
        # Add bias
        if self.bias is not None:
            output = output + self.bias.data[None, :, None, None, None]
        
        return Tensor(output, requires_grad=True)
    
    def __call__(self, x):
        return self.forward(x)


class ConvTranspose2d:
    """2D Transposed Convolution (Deconvolution) layer.
    
    Args:
        in_channels: Number of input channels
        out_channels: Number of output channels
        kernel_size: Size of convolution kernel
        stride: Stride of convolution. Default: 1
        padding: Padding to be added. Default: 0
        output_padding: Additional size to the output. Default: 0
        groups: Number of groups. Default: 1
        bias: If True, add bias. Default: True
    """
    
    def __init__(self, in_channels, out_channels, kernel_size,
                 stride=1, padding=0, output_padding=0, groups=1, bias=True):
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size)
        self.stride = stride if isinstance(stride, tuple) else (stride, stride)
        self.padding = padding if isinstance(padding, tuple) else (padding, padding)
        self.output_padding = output_padding if isinstance(output_padding, tuple) else (output_padding, output_padding)
        self.groups = groups
        
        # Weight: (in_channels, out_channels // groups, kernel_h, kernel_w)
        fan_in = in_channels // groups * np.prod(self.kernel_size)
        self.weight = Tensor(np.random.randn(in_channels, out_channels // groups, *self.kernel_size) * 
                            np.sqrt(2.0 / fan_in), requires_grad=True)
        
        if bias:
            self.bias = Tensor(np.zeros(out_channels), requires_grad=True)
        else:
            self.bias = None
    
    def forward(self, x):
        """Forward pass of ConvTranspose2d.
        
        Args:
            x: Input neurx of shape (batch, in_channels, height, width)
        
        Returns:
            Output neurx of shape (batch, out_channels, height_out, width_out)
        """
        batch_size, in_channels, height, width = x.shape
        kernel_h, kernel_w = self.kernel_size
        stride_h, stride_w = self.stride
        padding_h, padding_w = self.padding
        out_padding_h, out_padding_w = self.output_padding
        
        # Compute output dimensions
        out_height = (height - 1) * stride_h - 2 * padding_h + kernel_h + out_padding_h
        out_width = (width - 1) * stride_w - 2 * padding_w + kernel_w + out_padding_w
        
        output = np.zeros((batch_size, self.out_channels, out_height, out_width))
        
        # Perform grouped transpose convolution
        in_ch_per_group = in_channels // self.groups
        out_ch_per_group = self.out_channels // self.groups
        
        for g in range(self.groups):
            in_ch_start = g * in_ch_per_group
            in_ch_end = in_ch_start + in_ch_per_group
            out_ch_start = g * out_ch_per_group
            out_ch_end = out_ch_start + out_ch_per_group
            
            x_group = x.data[:, in_ch_start:in_ch_end, :, :]
            w_group = self.weight.data[in_ch_start:in_ch_end, :, :, :]
            
            # Transpose convolution
            for h in range(height):
                for w in range(width):
                    h_out_start = h * stride_h - padding_h
                    w_out_start = w * stride_w - padding_w
                    
                    # Get the weight filter and input value
                    for ic in range(in_ch_per_group):
                        for oc in range(out_ch_per_group):
                            w_filter = w_group[ic, oc, :, :]  # (kernel_h, kernel_w)
                            x_val = x_group[:, ic, h, w]  # (batch,)
                            
                            for kh in range(kernel_h):
                                for kw in range(kernel_w):
                                    h_out = h_out_start + kh
                                    w_out = w_out_start + kw
                                    
                                    if 0 <= h_out < out_height and 0 <= w_out < out_width:
                                        output[:, out_ch_start + oc, h_out, w_out] += \
                                            x_val * w_filter[kh, kw]
        
        # Add bias
        if self.bias is not None:
            output = output + self.bias.data[None, :, None, None]
        
        return Tensor(output, requires_grad=True)
    
    def __call__(self, x):
        return self.forward(x)


class ConvTranspose1d:
    """1D Transposed Convolution layer."""
    
    def __init__(self, in_channels, out_channels, kernel_size,
                 stride=1, padding=0, output_padding=0, groups=1, bias=True):
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size,)
        self.stride = stride if isinstance(stride, tuple) else (stride,)
        self.padding = padding if isinstance(padding, tuple) else (padding,)
        self.output_padding = output_padding if isinstance(output_padding, tuple) else (output_padding,)
        self.groups = groups
        
        fan_in = in_channels // groups * np.prod(self.kernel_size)
        self.weight = Tensor(np.random.randn(in_channels, out_channels // groups, *self.kernel_size) * 
                            np.sqrt(2.0 / fan_in), requires_grad=True)
        
        if bias:
            self.bias = Tensor(np.zeros(out_channels), requires_grad=True)
        else:
            self.bias = None
    
    def forward(self, x):
        batch_size, in_channels, length = x.shape
        kernel_size = self.kernel_size[0]
        stride = self.stride[0]
        padding = self.padding[0]
        out_padding = self.output_padding[0]
        
        out_length = (length - 1) * stride - 2 * padding + kernel_size + out_padding
        
        output = np.zeros((batch_size, self.out_channels, out_length))
        
        in_ch_per_group = in_channels // self.groups
        out_ch_per_group = self.out_channels // self.groups
        
        for g in range(self.groups):
            in_ch_start = g * in_ch_per_group
            x_group = x.data[:, in_ch_start:in_ch_start + in_ch_per_group, :]
            w_group = self.weight.data[in_ch_start:in_ch_start + in_ch_per_group, :, :]
            
            for l in range(length):
                l_out_start = l * stride - padding
                for ic in range(in_ch_per_group):
                    for oc in range(out_ch_per_group):
                        w_filter = w_group[ic, oc, :]  # (kernel_size,)
                        x_val = x_group[:, ic, l]
                        
                        for k in range(kernel_size):
                            l_out = l_out_start + k
                            if 0 <= l_out < out_length:
                                output[:, g * out_ch_per_group + oc, l_out] += x_val * w_filter[k]
        
        if self.bias is not None:
            output = output + self.bias.data[None, :, None]
        
        return Tensor(output, requires_grad=True)
    
    def __call__(self, x):
        return self.forward(x)


class ConvTranspose3d:
    """3D Transposed Convolution layer."""
    
    def __init__(self, in_channels, out_channels, kernel_size,
                 stride=1, padding=0, output_padding=0, groups=1, bias=True):
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size, kernel_size)
        self.stride = stride if isinstance(stride, tuple) else (stride, stride, stride)
        self.padding = padding if isinstance(padding, tuple) else (padding, padding, padding)
        self.output_padding = output_padding if isinstance(output_padding, tuple) else (output_padding, output_padding, output_padding)
        self.groups = groups
        
        fan_in = in_channels // groups * np.prod(self.kernel_size)
        self.weight = Tensor(np.random.randn(in_channels, out_channels // groups, *self.kernel_size) * 
                            np.sqrt(2.0 / fan_in), requires_grad=True)
        
        if bias:
            self.bias = Tensor(np.zeros(out_channels), requires_grad=True)
        else:
            self.bias = None
    
    def forward(self, x):
        batch_size, in_channels, depth, height, width = x.shape
        kernel_d, kernel_h, kernel_w = self.kernel_size
        stride_d, stride_h, stride_w = self.stride
        padding_d, padding_h, padding_w = self.padding
        out_padding_d, out_padding_h, out_padding_w = self.output_padding
        
        out_depth = (depth - 1) * stride_d - 2 * padding_d + kernel_d + out_padding_d
        out_height = (height - 1) * stride_h - 2 * padding_h + kernel_h + out_padding_h
        out_width = (width - 1) * stride_w - 2 * padding_w + kernel_w + out_padding_w
        
        output = np.zeros((batch_size, self.out_channels, out_depth, out_height, out_width))
        
        in_ch_per_group = in_channels // self.groups
        out_ch_per_group = self.out_channels // self.groups
        
        for g in range(self.groups):
            in_ch_start = g * in_ch_per_group
            x_group = x.data[:, in_ch_start:in_ch_start + in_ch_per_group, :, :, :]
            w_group = self.weight.data[in_ch_start:in_ch_start + in_ch_per_group, :, :, :, :]
            
            for d in range(depth):
                for h in range(height):
                    for w in range(width):
                        d_out_start = d * stride_d - padding_d
                        h_out_start = h * stride_h - padding_h
                        w_out_start = w * stride_w - padding_w
                        
                        for ic in range(in_ch_per_group):
                            for oc in range(out_ch_per_group):
                                w_filter = w_group[ic, oc, :, :, :]
                                x_val = x_group[:, ic, d, h, w]
                                
                                for kd in range(kernel_d):
                                    for kh in range(kernel_h):
                                        for kw in range(kernel_w):
                                            d_out = d_out_start + kd
                                            h_out = h_out_start + kh
                                            w_out = w_out_start + kw
                                            
                                            if 0 <= d_out < out_depth and 0 <= h_out < out_height and 0 <= w_out < out_width:
                                                output[:, g * out_ch_per_group + oc, d_out, h_out, w_out] += \
                                                    x_val * w_filter[kd, kh, kw]
        
        if self.bias is not None:
            output = output + self.bias.data[None, :, None, None, None]
        
        return Tensor(output, requires_grad=True)
    
    def __call__(self, x):
        return self.forward(x)
