"""
Autograd 上下文管理器和梯度相关工具
"""

from contextlib import contextmanager
from typing import Generator, Any
import numpy as np


class _GradientAccumulation:
    """梯度累积管理器"""
    
    def __init__(self):
        self.accumulate = False  # 默认不累积，覆盖梯度
        
    def __enter__(self):
        self.accumulate = True
        return self
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.accumulate = False


# 全局梯度累积状态
_grad_accumulation = _GradientAccumulation()


def set_gradient_accumulation(accumulate: bool) -> None:
    """设置全局梯度累积模式"""
    _grad_accumulation.accumulate = accumulate


def get_gradient_accumulation() -> bool:
    """获取全局梯度累积模式状态"""
    return _grad_accumulation.accumulate


@contextmanager
def gradient_accumulation(enable: bool = True) -> Generator[None, Any, None]:
    """上下文管理器：梯度累积模式
    
    示例：
        with gradient_accumulation(True):
            # 在此上下文中，grad += 而不是 grad = 
            loss.backward()
    """
    old_state = _grad_accumulation.accumulate
    _grad_accumulation.accumulate = enable
    try:
        yield
    finally:
        _grad_accumulation.accumulate = old_state


@contextmanager  
def no_grad() -> Generator[None, Any, None]:
    """禁用梯度计算的上下文管理器（PyTorch兼容）
    
    示例：
        with no_grad():
            # 此上下文中创建的Tensor不追踪梯度
            output = model(input)
    """
    from neurx.neurx import _enable_grad_global
    
    old_grad_enabled = getattr(_enable_grad_global, 'enabled', True)
    try:
        _enable_grad_global.enabled = False
        yield
    finally:
        _enable_grad_global.enabled = old_grad_enabled


@contextmanager
def enable_grad() -> Generator[None, Any, None]:
    """启用梯度计算的上下文管理器（与no_grad相反）"""
    from neurx.neurx import _enable_grad_global
    
    old_grad_enabled = getattr(_enable_grad_global, 'enabled', True)
    try:
        _enable_grad_global.enabled = True
        yield
    finally:
        _enable_grad_global.enabled = old_grad_enabled


@contextmanager
def set_detect_anomaly(enabled: bool) -> Generator[None, Any, None]:
    """检测梯度异常的上下文管理器（PyTorch兼容）"""
    # 这是一个简化版本，仅用于API兼容
    try:
        yield
    finally:
        pass
