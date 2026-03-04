"""
梯度操作工具 (Gradient Operations)

提供梯度裁剪、梯度范数计算等实用工具。
在深度学习中，梯度裁剪用于防止梯度爆炸问题。

使用示例:
    from neurx.nn.grad_utils import clip_grad_norm_
    
    # 对模型的所有参数进行梯度范数裁剪
    clip_grad_norm_(model.parameters(), max_norm=1.0)
"""

import numpy as np


def get_grad_norm(gradients):
    """
    计算梯度的二范数
    
    ||grad|| = sqrt(sum(grad_i^2))
    
    Args:
        gradients: 梯度列表或单个梯度数组
        
    Returns:
        float: 梯度的二范数
    """
    if isinstance(gradients, (list, tuple)):
        total_norm = 0.0
        for grad in gradients:
            if grad is not None:
                param_norm = np.sqrt(np.sum(grad ** 2))
                total_norm += param_norm ** 2
        return np.sqrt(total_norm)
    else:
        return np.sqrt(np.sum(gradients ** 2))


def clip_grad_norm_(gradients, max_norm, norm_type=2.0):
    """
    按范数裁剪梯度
    
    如果梯度范数超过 max_norm，则按比例缩小梯度。
    
    Args:
        gradients: 梯度列表（原地修改）
        max_norm: 最大允许的梯度范数
        norm_type: 范数类型（2.0 表示 L2 范数）
        
    Returns:
        float: 梯度的原始范数
    """
    if isinstance(gradients, (list, tuple)):
        # 计算总梯度范数
        total_norm = 0.0
        for grad in gradients:
            if grad is not None:
                param_norm = np.power(np.sum(np.abs(grad) ** norm_type), 1.0 / norm_type)
                total_norm += param_norm ** norm_type
        total_norm = np.power(total_norm, 1.0 / norm_type)
        
        # 如果超过阈值则裁剪
        if total_norm > max_norm:
            clip_coef = max_norm / (total_norm + 1e-6)
            for i in range(len(gradients)):
                if gradients[i] is not None:
                    gradients[i] *= clip_coef
        
        return total_norm
    else:
        # 单个梯度
        total_norm = np.power(np.sum(np.abs(gradients) ** norm_type), 1.0 / norm_type)
        if total_norm > max_norm:
            clip_coef = max_norm / (total_norm + 1e-6)
            gradients *= clip_coef
        return total_norm


def clip_grad_value_(gradients, clip_value):
    """
    按值裁剪梯度
    
    将梯度限制在 [-clip_value, clip_value] 范围内。
    
    Args:
        gradients: 梯度列表或单个梯度数组（原地修改）
        clip_value: 裁剪范围 (±clip_value)
        
    Returns:
        None
    """
    if isinstance(gradients, (list, tuple)):
        for i in range(len(gradients)):
            if gradients[i] is not None:
                gradients[i] = np.clip(gradients[i], -clip_value, clip_value)
    else:
        np.clip(gradients, -clip_value, clip_value, out=gradients)


def zero_grad(parameters):
    """
    将参数的梯度清零
    
    Args:
        parameters: 参数列表或单个参数
        
    Returns:
        None
    """
    if isinstance(parameters, (list, tuple)):
        for param in parameters:
            if hasattr(param, 'grad') and param.grad is not None:
                param.grad[:] = 0.0
    else:
        if hasattr(parameters, 'grad') and parameters.grad is not None:
            parameters.grad[:] = 0.0


class GradientClipper:
    """
    梯度裁剪管理器
    
    便利的上下文管理器用于应用梯度裁剪。
    
    使用示例:
        with GradientClipper(model.parameters(), max_norm=1.0):
            # 梯度计算代码
            loss.backward()
    """
    
    def __init__(self, parameters, max_norm=None, clip_value=None):
        """
        初始化梯度裁剪器
        
        Args:
            parameters: 需要裁剪梯度的参数列表
            max_norm: 梯度范数阈值（None 表示不使用范数裁剪）
            clip_value: 梯度值范围（None 表示不使用值裁剪）
        """
        self.parameters = parameters if isinstance(parameters, (list, tuple)) else [parameters]
        self.max_norm = max_norm
        self.clip_value = clip_value
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """在退出时应用梯度裁剪"""
        self.apply()
    
    def apply(self):
        """应用梯度裁剪"""
        # 收集梯度
        gradients = [param.grad for param in self.parameters if hasattr(param, 'grad')]
        
        # 应用范数裁剪
        if self.max_norm is not None:
            clip_grad_norm_(gradients, self.max_norm)
        
        # 应用值裁剪
        if self.clip_value is not None:
            clip_grad_value_(gradients, self.clip_value)


__all__ = [
    'get_grad_norm',
    'clip_grad_norm_',
    'clip_grad_value_',
    'zero_grad',
    'GradientClipper',
]
