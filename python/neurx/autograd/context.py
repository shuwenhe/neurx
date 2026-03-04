"""
Autograd 上下文管理 - no_grad, enable_grad, gradient_accumulation 等
"""

from contextlib import contextmanager
from typing import Generator, Any


class _GradState:
    """全局梯度状态管理"""
    def __init__(self):
        self.grad_enabled = True
        self.grad_accumulation = False


_grad_state = _GradState()


@contextmanager
def no_grad() -> Generator[None, Any, None]:
    """禁用梯度计算的上下文管理器（PyTorch兼容）
    
    示例：
        with no_grad():
            output = model(input)  # 此上下文中不计算梯度
    """
    old_grad_enabled = _grad_state.grad_enabled
    try:
        _grad_state.grad_enabled = False
        yield
    finally:
        _grad_state.grad_enabled = old_grad_enabled


@contextmanager
def enable_grad() -> Generator[None, Any, None]:
    """启用梯度计算的上下文管理器（与no_grad相反）"""
    old_grad_enabled = _grad_state.grad_enabled
    try:
        _grad_state.grad_enabled = True
        yield
    finally:
        _grad_state.grad_enabled = old_grad_enabled


@contextmanager
def gradient_accumulation(enable: bool = True) -> Generator[None, Any, None]:
    """梯度累积模式上下文管理器
    
    示例：
        with gradient_accumulation(True):
            loss.backward()  # 梯度会累积（grad += delta）
    """
    old_accumulation = _grad_state.grad_accumulation
    try:
        _grad_state.grad_accumulation = enable
        yield
    finally:
        _grad_state.grad_accumulation = old_accumulation


@contextmanager
def set_detect_anomaly(enabled: bool) -> Generator[None, Any, None]:
    """检测梯度异常的上下文管理器（PyTorch兼容）
    
    在NeurX中这是一个简化版本，仅用于API兼容性
    """
    try:
        yield
    finally:
        pass


def is_grad_enabled() -> bool:
    """检查梯度是否启用"""
    return _grad_state.grad_enabled


def is_grad_accumulation_enabled() -> bool:
    """检查梯度累积是否启用"""
    return _grad_state.grad_accumulation


__all__ = [
    'no_grad',
    'enable_grad',
    'gradient_accumulation',
    'set_detect_anomaly',
    'is_grad_enabled',
    'is_grad_accumulation_enabled',
]
