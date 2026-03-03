"""
权重初始化函数 (Weight Initialization)

提供各种权重初始化策略，用于神经网络参数的初始化。
支持 Xavier、Kaiming、正交等初始化方法。

使用示例:
    from tensor.nn.init import xavier_uniform, kaiming_normal
    
    weight = Tensor(np.zeros((100, 50)))
    xavier_uniform_(weight)  # 原地初始化
    
    # 或使用无下划线版本获得初始化后的数组
    weights = kaiming_normal((100, 50))
"""

import numpy as np
from tensor.core import Tensor


def _calculate_fan(shape):
    """
    计算 fan-in 和 fan-out
    
    Args:
        shape: 张量形状元组
        
    Returns:
        (fan_in, fan_out): 元组
    """
    if len(shape) < 2:
        raise ValueError(f"需要至少 2D 张量来计算 fan 值, 得到形状: {shape}")
    
    num_input = shape[0]
    num_output = shape[1]
    
    # 对于卷积层，考虑感受野
    receptive_field = 1
    for dim in shape[2:]:
        receptive_field *= dim
    
    fan_in = num_input * receptive_field
    fan_out = num_output * receptive_field
    
    return fan_in, fan_out


def xavier_uniform(shape):
    """
    Xavier 均匀初始化（Glorot Uniform）
    
    从均匀分布 U(-limit, limit) 中采样，其中
    limit = sqrt(6 / (fan_in + fan_out))
    
    论文: Glorot & Bengio (2010)
    
    Args:
        shape: 张量形状元组
        
    Returns:
        numpy数组: 初始化后的权重
    """
    fan_in, fan_out = _calculate_fan(shape)
    limit = np.sqrt(6.0 / (fan_in + fan_out))
    return np.random.uniform(-limit, limit, shape)


def xavier_normal(shape):
    """
    Xavier 正态初始化（Glorot Normal）
    
    从正态分布 N(0, std) 中采样，其中
    std = sqrt(2 / (fan_in + fan_out))
    
    论文: Glorot & Bengio (2010)
    
    Args:
        shape: 张量形状元组
        
    Returns:
        numpy数组: 初始化后的权重
    """
    fan_in, fan_out = _calculate_fan(shape)
    std = np.sqrt(2.0 / (fan_in + fan_out))
    return np.random.normal(0, std, shape)


def kaiming_uniform(shape, a=0, mode='fan_in'):
    """
    Kaiming 均匀初始化（He Uniform）
    
    用于 ReLU 等激活函数。从均匀分布中采样，其中
    limit = sqrt(6 / ((1 + a^2) * fan_in))
    
    论文: He et al. (2015)
    
    Args:
        shape: 张量形状元组
        a: 负斜率系数（LeakyReLU 的负斜率，ReLU 时为 0）
        mode: 'fan_in' 或 'fan_out'
        
    Returns:
        numpy数组: 初始化后的权重
    """
    fan_in, fan_out = _calculate_fan(shape)
    fan = fan_in if mode == 'fan_in' else fan_out
    
    gain = np.sqrt(2.0 / (1.0 + a ** 2))
    limit = gain * np.sqrt(3.0 / fan)
    return np.random.uniform(-limit, limit, shape)


def kaiming_normal(shape, a=0, mode='fan_in'):
    """
    Kaiming 正态初始化（He Normal）
    
    用于 ReLU 等激活函数。从正态分布中采样，其中
    std = sqrt(2 / ((1 + a^2) * fan_in))
    
    论文: He et al. (2015)
    
    Args:
        shape: 张量形状元组
        a: 负斜率系数（LeakyReLU 的负斜率，ReLU 时为 0）
        mode: 'fan_in' 或 'fan_out'
        
    Returns:
        numpy数组: 初始化后的权重
    """
    fan_in, fan_out = _calculate_fan(shape)
    fan = fan_in if mode == 'fan_in' else fan_out
    
    gain = np.sqrt(2.0 / (1.0 + a ** 2))
    std = gain / np.sqrt(fan)
    return np.random.normal(0, std, shape)


def orthogonal(shape, gain=1.0):
    """
    正交初始化
    
    产生正交矩阵。对 RNN 和其他递归网络特别有用。
    
    论文: Mezzadri (2007)
    
    Args:
        shape: 张量形状元组（至少 2D）
        gain: 增益因子（用于缩放正交矩阵）
        
    Returns:
        numpy数组: 初始化后的权重
    """
    if len(shape) < 2:
        raise ValueError(f"正交初始化需要至少 2D 张量, 得到形状: {shape}")
    
    # 创建随机正态矩阵
    flat_shape = (shape[0], np.prod(shape[1:]))
    a = np.random.normal(0, 1, flat_shape)
    
    # 进行 QR 分解以获得正交矩阵
    u, _ = np.linalg.qr(a)
    
    # 对于不是正方形的情况，取左 rows 和右 cols
    if u.shape[0] < u.shape[1]:
        u = u.T
    
    return gain * u[:shape[0], :np.prod(shape[1:])].reshape(shape)


def uniform(shape, a=0.0, b=1.0):
    """
    均匀初始化
    
    从均匀分布 U(a, b) 中采样。
    
    Args:
        shape: 张量形状元组
        a: 下界
        b: 上界
        
    Returns:
        numpy数组: 初始化后的权重
    """
    return np.random.uniform(a, b, shape)


def normal(shape, mean=0.0, std=1.0):
    """
    正态初始化
    
    从正态分布 N(mean, std) 中采样。
    
    Args:
        shape: 张量形状元组
        mean: 均值
        std: 标准差
        
    Returns:
        numpy数组: 初始化后的权重
    """
    return np.random.normal(mean, std, shape)


# 原地初始化版本（修改传入的张量）
def xavier_uniform_(tensor):
    """原地 Xavier 均匀初始化"""
    if isinstance(tensor, Tensor):
        tensor.data = xavier_uniform(tensor.shape)
    else:
        # 如果是 numpy 数组，复制初始化值
        result = xavier_uniform(tensor.shape)
        tensor[:] = result
    return tensor


def xavier_normal_(tensor):
    """原地 Xavier 正态初始化"""
    if isinstance(tensor, Tensor):
        tensor.data = xavier_normal(tensor.shape)
    else:
        result = xavier_normal(tensor.shape)
        tensor[:] = result
    return tensor


def kaiming_uniform_(tensor, a=0):
    """原地 Kaiming 均匀初始化"""
    if isinstance(tensor, Tensor):
        tensor.data = kaiming_uniform(tensor.shape, a=a)
    else:
        result = kaiming_uniform(tensor.shape, a=a)
        tensor[:] = result
    return tensor


def kaiming_normal_(tensor, a=0):
    """原地 Kaiming 正态初始化"""
    if isinstance(tensor, Tensor):
        tensor.data = kaiming_normal(tensor.shape, a=a)
    else:
        result = kaiming_normal(tensor.shape, a=a)
        tensor[:] = result
    return tensor


def orthogonal_(tensor, gain=1.0):
    """原地正交初始化"""
    if isinstance(tensor, Tensor):
        tensor.data = orthogonal(tensor.shape, gain=gain)
    else:
        result = orthogonal(tensor.shape, gain=gain)
        tensor[:] = result
    return tensor


def uniform_(tensor, a=0.0, b=1.0):
    """原地均匀初始化"""
    if isinstance(tensor, Tensor):
        tensor.data = uniform(tensor.shape, a=a, b=b)
    else:
        result = uniform(tensor.shape, a=a, b=b)
        tensor[:] = result
    return tensor


def normal_(tensor, mean=0.0, std=1.0):
    """原地正态初始化"""
    if isinstance(tensor, Tensor):
        tensor.data = normal(tensor.shape, mean=mean, std=std)
    else:
        result = normal(tensor.shape, mean=mean, std=std)
        tensor[:] = result
    return tensor


__all__ = [
    'xavier_uniform', 'xavier_normal',
    'kaiming_uniform', 'kaiming_normal',
    'orthogonal', 'uniform', 'normal',
    'xavier_uniform_', 'xavier_normal_',
    'kaiming_uniform_', 'kaiming_normal_',
    'orthogonal_', 'uniform_', 'normal_',
]
