"""
Layer Normalization Implementation

标准化特征维度，而不是批次维度。
与BatchNorm不同，LayerNorm在推理和训练中表现一致。

参考: https://arxiv.org/abs/1607.06450
"""

import numpy as np
from neurx.core.neurx import Tensor
from neurx.nn.modules import Module


class LayerNorm(Module):
    """
    Layer Normalization over a mini-batch of inputs.
    
    Normalizes the inputs along the feature dimensions (last dimensions).
    Unlike BatchNorm, it normalizes over features, not over batch.
    
    Args:
        normalized_shape: input shape from an expected input of size
            [*, normalized_shape[0], normalized_shape[1], ..., normalized_shape[-1]]
            If a single integer is used, it is treated as a (normalized_shape,) tuple.
        
        eps: a value added to the denominator for numerical stability.
            Default: 1e-5
        
        elementwise_affine: a boolean value that when set to ``True``, this module
            has learnable per-element affine parameters initialized to ones (for weights)
            and zeros (for biases). Default: ``True``
    
    Example:
        >>> # With normalized_shape being a single integer
        >>> m = LayerNorm(100)
        >>> input = Tensor(np.random.randn(20, 100))
        >>> output = m(input)
        >>> output.shape  # (20, 100)
    """
    
    def __init__(self, normalized_shape, eps=1e-5, elementwise_affine=True):
        super().__init__()
        
        if isinstance(normalized_shape, int):
            normalized_shape = (normalized_shape,)
        
        self.normalized_shape = tuple(normalized_shape)
        self.eps = eps
        self.elementwise_affine = elementwise_affine
        
        if self.elementwise_affine:
            # Initialize weight (gamma) to ones
            self.weight = Tensor(
                np.ones(self.normalized_shape, dtype=np.float32),
                requires_grad=True
            )
            # Initialize bias (beta) to zeros
            self.bias = Tensor(
                np.zeros(self.normalized_shape, dtype=np.float32),
                requires_grad=True
            )
        else:
            self.weight = None
            self.bias = None
    
    def forward(self, input):
        """
        Args:
            input: Tensor of shape [*, normalized_shape]
        
        Returns:
            Normalized neurx of same shape
        """
        # Compute mean and variance over the last len(normalized_shape) dimensions
        normalized_ndim = len(self.normalized_shape)
        
        # Axes to reduce over (all except the feature dimensions)
        begin_norm_axis = -(normalized_ndim)
        
        # Compute mean and variance
        # Reduce over last 'normalized_ndim' dimensions
        mean = self._compute_mean(input, normalized_ndim)
        variance = self._compute_variance(input, mean, normalized_ndim)
        
        # Normalize
        normalized = (input - mean) / np.sqrt(variance + self.eps)
        
        # Apply affine transformation if enabled
        if self.elementwise_affine:
            output = self.weight * normalized + self.bias
        else:
            output = normalized
        
        return output
    
    def _compute_mean(self, x, num_dims):
        """Compute mean over last num_dims dimensions."""
        # Get axes to reduce over
        axes = tuple(range(-num_dims, 0))
        
        # Compute mean
        x_data = x.data if isinstance(x, Tensor) else x
        mean_data = np.mean(x_data, axis=axes, keepdims=True)
        
        # Return as neurx if input is neurx
        if isinstance(x, Tensor):
            return Tensor(mean_data, requires_grad=x.requires_grad)
        return mean_data
    
    def _compute_variance(self, x, mean, num_dims):
        """Compute variance over last num_dims dimensions."""
        axes = tuple(range(-num_dims, 0))
        
        # Compute variance
        x_data = x.data if isinstance(x, Tensor) else x
        mean_data = mean.data if isinstance(mean, Tensor) else mean
        
        variance_data = np.mean((x_data - mean_data) ** 2, axis=axes, keepdims=True)
        
        # Return as neurx if input is neurx
        if isinstance(x, Tensor):
            return Tensor(variance_data, requires_grad=x.requires_grad)
        return variance_data
    
    def extra_repr(self):
        return f'normalized_shape={self.normalized_shape}, eps={self.eps}, elementwise_affine={self.elementwise_affine}'


class GroupNorm(Module):
    """
    Group Normalization.
    
    Divides channels into groups and computes normalization within each group.
    Unlike BatchNorm, it doesn't depend on batch size.
    Unlike LayerNorm, it allows different behaviors for different groups.
    
    Args:
        num_groups: Number of groups to divide channels into
        num_channels: Number of channels in the input
        eps: Small value for numerical stability. Default: 1e-5
        affine: Whether to have learnable affine parameters. Default: True
    
    Example:
        >>> gn = GroupNorm(32, 256)  # 256 channels, 32 groups
        >>> input = Tensor(np.random.randn(20, 256, 56, 56))  # (N, C, H, W)
        >>> output = gn(input)
    """
    
    def __init__(self, num_groups, num_channels, eps=1e-5, affine=True):
        super().__init__()
        
        if num_channels % num_groups != 0:
            raise ValueError(
                f'num_channels ({num_channels}) must be divisible by '
                f'num_groups ({num_groups})'
            )
        
        self.num_groups = num_groups
        self.num_channels = num_channels
        self.eps = eps
        self.affine = affine
        
        if self.affine:
            self.weight = Tensor(
                np.ones((num_channels,), dtype=np.float32),
                requires_grad=True
            )
            self.bias = Tensor(
                np.zeros((num_channels,), dtype=np.float32),
                requires_grad=True
            )
        else:
            self.weight = None
            self.bias = None
    
    def forward(self, input):
        """
        Args:
            input: Tensor of shape (N, C, *) where C is num_channels
        
        Returns:
            Normalized neurx of same shape
        """
        N, C = input.shape[0], input.shape[1]
        
        if C != self.num_channels:
            raise ValueError(
                f'expected {self.num_channels} channels, got {C}'
            )
        
        # Reshape to separate groups: (N, num_groups, C // num_groups, *)
        input_shape = input.shape
        input_reshaped = input.reshape(N, self.num_groups, C // self.num_groups, -1)
        
        # Compute mean and variance for each group
        # Reduce over (2, 3) dimensions - group channels and spatial dimensions
        input_data = input_reshaped.data
        
        # Compute mean over dimensions (2, 3)
        mean = np.mean(input_data, axis=(2, 3), keepdims=True)
        # Compute variance
        variance = np.mean((input_data - mean) ** 2, axis=(2, 3), keepdims=True)
        
        # Normalize
        normalized = (input_data - mean) / np.sqrt(variance + self.eps)
        
        # Reshape back
        normalized = normalized.reshape(input_shape)
        
        # Apply affine transformation
        if self.affine:
            # Reshape weight and bias for broadcasting
            affine_shape = [1, self.num_channels] + [1] * (len(input_shape) - 2)
            weight = self.weight.reshape(*affine_shape)
            bias = self.bias.reshape(*affine_shape)
            output = weight * normalized + bias
        else:
            output = Tensor(normalized) if isinstance(input, Tensor) else normalized
        
        return output
    
    def extra_repr(self):
        return f'num_groups={self.num_groups}, num_channels={self.num_channels}, eps={self.eps}, affine={self.affine}'


class InstanceNorm(Module):
    """
    Instance Normalization.
    
    Normalizes each instance in a batch independently.
    Typically used in style transfer applications.
    
    Args:
        num_features: Number of channels/features
        eps: Small value for numerical stability. Default: 1e-5
        momentum: Unused, for API compatibility. Default: 0.1
        affine: Whether to have learnable affine parameters. Default: True
    """
    
    def __init__(self, num_features, eps=1e-5, momentum=0.1, affine=True, track_running_stats=False):
        super().__init__()
        
        self.num_features = num_features
        self.eps = eps
        self.affine = affine
        self.track_running_stats = track_running_stats
        
        if self.affine:
            self.weight = Tensor(
                np.ones((num_features,), dtype=np.float32),
                requires_grad=True
            )
            self.bias = Tensor(
                np.zeros((num_features,), dtype=np.float32),
                requires_grad=True
            )
        else:
            self.weight = None
            self.bias = None
    
    def forward(self, input):
        """
        Args:
            input: Tensor of shape (N, C, H, W) or (N, C, D, H, W) etc.
        
        Returns:
            Normalized neurx of same shape
        """
        # For instance norm, compute mean/var for each (N, C) pair
        # Reduce over spatial dimensions
        
        input_shape = input.shape
        N, C = input_shape[0], input_shape[1]
        
        # Reshape to (N, C, -1)
        input_reshaped = input.reshape(N, C, -1)
        input_data = input_reshaped.data
        
        # Compute mean and variance for each (N, C)
        mean = np.mean(input_data, axis=2, keepdims=True)
        variance = np.mean((input_data - mean) ** 2, axis=2, keepdims=True)
        
        # Normalize
        normalized = (input_data - mean) / np.sqrt(variance + self.eps)
        
        # Reshape back to original shape
        normalized = normalized.reshape(input_shape)
        
        # Apply affine transformation
        if self.affine:
            # Reshape weight and bias for broadcasting
            affine_shape = [1, self.num_features] + [1] * (len(input_shape) - 2)
            weight = self.weight.reshape(*affine_shape)
            bias = self.bias.reshape(*affine_shape)
            output = weight * normalized + bias
        else:
            output = Tensor(normalized) if isinstance(input, Tensor) else normalized
        
        return output
    
    def extra_repr(self):
        return f'num_features={self.num_features}, eps={self.eps}, affine={self.affine}'


class BatchNorm1d(Module):
    """
    Batch Normalization over 2D/3D input (N, C) or (N, C, L)
    
    批归一化对 mini-batch 进行标准化，加速训练收敛。
    在训练期间使用批统计，在评估期间使用运行统计。
    
    Args:
        num_features: 特征数（通道数）
        eps: 数值稳定性常数，默认 1e-5
        momentum: 运行均值和方差的动量，默认 0.1
        affine: 是否有可学习的仿射参数（gamma, beta），默认 True
        track_running_stats: 是否跟踪运行统计，默认 True
    
    Shape:
        - Input: (N, C) 或 (N, C, L)
        - Output: 同输入
    
    参考: https://arxiv.org/abs/1502.03167
    """
    
    def __init__(self, num_features, eps=1e-5, momentum=0.1, affine=True, 
                 track_running_stats=True):
        super().__init__()
        self.num_features = num_features
        self.eps = eps
        self.momentum = momentum
        self.affine = affine
        self.track_running_stats = track_running_stats
        self.training = True
        
        if self.affine:
            from .modules import Parameter
            self.weight = Parameter(np.ones(num_features))
            self.bias = Parameter(np.zeros(num_features))
        else:
            self.weight = None
            self.bias = None
        
        if self.track_running_stats:
            self.running_mean = Tensor(np.zeros(num_features))
            self.running_var = Tensor(np.ones(num_features))
            self.num_batches_tracked = 0
        else:
            self.running_mean = None
            self.running_var = None
    
    def forward(self, x):
        """前向传播"""
        if isinstance(x, Tensor):
            x_data = x.data
        else:
            x_data = x
        
        # 获取形状
        shape = x_data.shape
        if len(shape) == 2:  # (N, C)
            # 形状: (N, C) -> 需要标准化维度 0
            axes = (0,)
            reshape_shape = (1, -1)
        elif len(shape) == 3:  # (N, C, L)
            # 形状: (N, C, L) -> 需要标准化维度 0 和 2
            axes = (0, 2)
            reshape_shape = (1, -1, 1)
        else:
            raise ValueError(f"Expected 2D or 3D input, got {len(shape)}D input")
        
        if self.training:
            # 训练模式：使用批统计
            batch_mean = np.mean(x_data, axis=axes, keepdims=True)
            batch_var = np.var(x_data, axis=axes, keepdims=True)
            
            # 标准化
            x_normalized = (x_data - batch_mean) / np.sqrt(batch_var + self.eps)
            
            # 更新运行统计
            if self.track_running_stats:
                batch_mean_squeeze = np.squeeze(batch_mean)
                batch_var_squeeze = np.squeeze(batch_var)
                
                self.running_mean.data = (
                    (1 - self.momentum) * self.running_mean.data + 
                    self.momentum * batch_mean_squeeze
                )
                self.running_var.data = (
                    (1 - self.momentum) * self.running_var.data + 
                    self.momentum * batch_var_squeeze
                )
                self.num_batches_tracked += 1
        else:
            # 评估模式：使用运行统计
            if self.track_running_stats:
                running_mean = self.running_mean.data.reshape(reshape_shape)
                running_var = self.running_var.data.reshape(reshape_shape)
                x_normalized = (x_data - running_mean) / np.sqrt(running_var + self.eps)
            else:
                # 如果不跟踪运行统计，使用批统计即使在eval模式
                batch_mean = np.mean(x_data, axis=axes, keepdims=True)
                batch_var = np.var(x_data, axis=axes, keepdims=True)
                x_normalized = (x_data - batch_mean) / np.sqrt(batch_var + self.eps)
        
        # 应用仿射变换
        if self.affine:
            weight = self.weight.data.reshape(reshape_shape)
            bias = self.bias.data.reshape(reshape_shape)
            output = weight * x_normalized + bias
        else:
            output = x_normalized
        
        return Tensor(output) if isinstance(x, Tensor) else output
    
    def train(self, mode=True):
        """设置训练模式"""
        self.training = mode
        return self
    
    def eval(self):
        """设置评估模式"""
        self.training = False
        return self
    
    def state_dict(self):
        """Return state dictionary"""
        state = {}
        if self.affine:
            state['weight'] = self.weight.data
            state['bias'] = self.bias.data
        if self.track_running_stats:
            state['running_mean'] = self.running_mean.data
            state['running_var'] = self.running_var.data
            state['num_batches_tracked'] = self.num_batches_tracked
        return state


class BatchNorm2d(Module):
    """
    Batch Normalization over 4D input (N, C, H, W)
    
    批归一化对 mini-batch 进行标准化，加速训练收敛。
    在训练期间使用批统计，在评估期间使用运行统计。
    
    Args:
        num_features: 特征数（通道数）
        eps: 数值稳定性常数，默认 1e-5
        momentum: 运行均值和方差的动量，默认 0.1
        affine: 是否有可学习的仿射参数（gamma, beta），默认 True
        track_running_stats: 是否跟踪运行统计，默认 True
    
    Shape:
        - Input: (N, C, H, W)
        - Output: 同输入
    
    参考: https://arxiv.org/abs/1502.03167
    """
    
    def __init__(self, num_features, eps=1e-5, momentum=0.1, affine=True, 
                 track_running_stats=True):
        super().__init__()
        self.num_features = num_features
        self.eps = eps
        self.momentum = momentum
        self.affine = affine
        self.track_running_stats = track_running_stats
        self.training = True
        
        if self.affine:
            from .modules import Parameter
            self.weight = Parameter(np.ones(num_features))
            self.bias = Parameter(np.zeros(num_features))
        else:
            self.weight = None
            self.bias = None
        
        if self.track_running_stats:
            self.running_mean = Tensor(np.zeros(num_features))
            self.running_var = Tensor(np.ones(num_features))
            self.num_batches_tracked = 0
        else:
            self.running_mean = None
            self.running_var = None
    
    def forward(self, x):
        """前向传播"""
        if isinstance(x, Tensor):
            x_data = x.data
        else:
            x_data = x
        
        # 验证输入形状
        if len(x_data.shape) != 4:
            raise ValueError(f"Expected 4D input (N, C, H, W), got {len(x_data.shape)}D input")
        
        # 计算沿 N, H, W 轴的统计
        axes = (0, 2, 3)
        reshape_shape = (1, -1, 1, 1)
        
        if self.training:
            # 训练模式：使用批统计
            batch_mean = np.mean(x_data, axis=axes, keepdims=True)
            batch_var = np.var(x_data, axis=axes, keepdims=True)
            
            # 标准化
            x_normalized = (x_data - batch_mean) / np.sqrt(batch_var + self.eps)
            
            # 更新运行统计
            if self.track_running_stats:
                batch_mean_squeeze = np.squeeze(batch_mean)
                batch_var_squeeze = np.squeeze(batch_var)
                
                self.running_mean.data = (
                    (1 - self.momentum) * self.running_mean.data + 
                    self.momentum * batch_mean_squeeze
                )
                self.running_var.data = (
                    (1 - self.momentum) * self.running_var.data + 
                    self.momentum * batch_var_squeeze
                )
                self.num_batches_tracked += 1
        else:
            # 评估模式：使用运行统计
            if self.track_running_stats:
                running_mean = self.running_mean.data.reshape(reshape_shape)
                running_var = self.running_var.data.reshape(reshape_shape)
                x_normalized = (x_data - running_mean) / np.sqrt(running_var + self.eps)
            else:
                # 如果不跟踪运行统计，使用身份变换
                x_normalized = x_data
        
        # 应用仿射变换
        if self.affine:
            weight = self.weight.data.reshape(reshape_shape)
            bias = self.bias.data.reshape(reshape_shape)
            output = weight * x_normalized + bias
        else:
            output = x_normalized
        
        return Tensor(output) if isinstance(x, Tensor) else output
    
    def train(self, mode=True):
        """设置训练模式"""
        self.training = mode
        return self
    
    def eval(self):
        """设置评估模式"""
        self.training = False
        return self


class BatchNorm3d(Module):
    """
    Batch Normalization over 5D input (N, C, D, H, W)
    
    批归一化对 mini-batch 进行标准化，加速训练收敛。
    在训练期间使用批统计，在评估期间使用运行统计。
    
    Args:
        num_features: 特征数（通道数）
        eps: 数值稳定性常数，默认 1e-5
        momentum: 运行均值和方差的动量，默认 0.1
        affine: 是否有可学习的仿射参数（gamma, beta），默认 True
        track_running_stats: 是否跟踪运行统计，默认 True
    
    Shape:
        - Input: (N, C, D, H, W)
        - Output: 同输入
    
    参考: https://arxiv.org/abs/1502.03167
    """
    
    def __init__(self, num_features, eps=1e-5, momentum=0.1, affine=True, 
                 track_running_stats=True):
        super().__init__()
        self.num_features = num_features
        self.eps = eps
        self.momentum = momentum
        self.affine = affine
        self.track_running_stats = track_running_stats
        self.training = True
        
        if self.affine:
            from .modules import Parameter
            self.weight = Parameter(np.ones(num_features))
            self.bias = Parameter(np.zeros(num_features))
        else:
            self.weight = None
            self.bias = None
        
        if self.track_running_stats:
            self.running_mean = Tensor(np.zeros(num_features))
            self.running_var = Tensor(np.ones(num_features))
            self.num_batches_tracked = 0
        else:
            self.running_mean = None
            self.running_var = None
    
    def forward(self, x):
        """前向传播"""
        if isinstance(x, Tensor):
            x_data = x.data
        else:
            x_data = x
        
        # 验证输入形状
        if len(x_data.shape) != 5:
            raise ValueError(f"Expected 5D input (N, C, D, H, W), got {len(x_data.shape)}D input")
        
        # 计算沿 N, D, H, W 轴的统计
        axes = (0, 2, 3, 4)
        reshape_shape = (1, -1, 1, 1, 1)
        
        if self.training:
            # 训练模式：使用批统计
            batch_mean = np.mean(x_data, axis=axes, keepdims=True)
            batch_var = np.var(x_data, axis=axes, keepdims=True)
            
            # 标准化
            x_normalized = (x_data - batch_mean) / np.sqrt(batch_var + self.eps)
            
            # 更新运行统计
            if self.track_running_stats:
                batch_mean_squeeze = np.squeeze(batch_mean)
                batch_var_squeeze = np.squeeze(batch_var)
                
                self.running_mean.data = (
                    (1 - self.momentum) * self.running_mean.data + 
                    self.momentum * batch_mean_squeeze
                )
                self.running_var.data = (
                    (1 - self.momentum) * self.running_var.data + 
                    self.momentum * batch_var_squeeze
                )
                self.num_batches_tracked += 1
        else:
            # 评估模式：使用运行统计
            if self.track_running_stats:
                running_mean = self.running_mean.data.reshape(reshape_shape)
                running_var = self.running_var.data.reshape(reshape_shape)
                x_normalized = (x_data - running_mean) / np.sqrt(running_var + self.eps)
            else:
                # 如果不跟踪运行统计，使用身份变换
                x_normalized = x_data
        
        # 应用仿射变换
        if self.affine:
            weight = self.weight.data.reshape(reshape_shape)
            bias = self.bias.data.reshape(reshape_shape)
            output = weight * x_normalized + bias
        else:
            output = x_normalized
        
        return Tensor(output) if isinstance(x, Tensor) else output
    
    def train(self, mode=True):
        """设置训练模式"""
        self.training = mode
        return self
    
    def eval(self):
        """设置评估模式"""
        self.training = False
        return self
