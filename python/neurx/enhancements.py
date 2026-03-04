"""
neurx Tensor API 增强模块

为 neurx.Tensor 添加缺失的 PyTorch 兼容功能：
1. 核心张量方法（clone, detach, to, item, numpy）
2. 就地操作（add_, mul_, div_, zero_, fill_）
3. 比较和逻辑操作（==, !=, <, >, <=, >=）
4. 类型转换（float, double, int, long, type）
5. 高级操作（pad, clamp, isnan, isinf, isfinite）
"""

import numpy as np


def add_tensor_enhancements(tensor_class):
    """
    为 Tensor 类动态添加增强功能
    
    Usage:
        from neurx.core.neurx import Tensor
        from neurx.enhancements import add_tensor_enhancements
        add_tensor_enhancements(Tensor)
    """
    
    # ========================================================================
    # 1. 核心张量方法
    # ========================================================================
    
    if not hasattr(tensor_class, 'clone'):
        def clone(self):
            """返回张量副本（独立的数据和梯度）"""
            return tensor_class(self.data.copy(), requires_grad=self.requires_grad, device=self.device)
        tensor_class.clone = clone
    
    if not hasattr(tensor_class, 'detach'):
        def detach(self):
            """返回新张量，断开梯度计算图"""
            return tensor_class(self.data.copy(), requires_grad=False, device=self.device)
        tensor_class.detach = detach
    
    if not hasattr(tensor_class, 'item'):
        def item(self):
            """获取标量值（仅限单元素张量）"""
            if self.numel() != 1:
                raise ValueError(f"item() requires exactly one element, got {self.numel()}")
            from neurx.core.neurx import _to_numpy
            return float(_to_numpy(self.data).flatten()[0])
        tensor_class.item = item
    
    if not hasattr(tensor_class, 'numpy'):
        def numpy(self):
            """转换为 NumPy 数组"""
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            return arr.astype(np.float64) if arr.dtype == np.float64 else arr.copy()
        tensor_class.numpy = numpy
    
    if not hasattr(tensor_class, 'to'):
        def to(self, device):
            """转移张量到指定设备"""
            from neurx.core.neurx import _to_numpy, _cuda_ops, _to_data_on_device
            
            if device == self.device:
                return self
            
            if device == "cuda":
                if _cuda_ops is None:
                    raise RuntimeError("CUDA backend not available")
                data = _to_numpy(self.data).astype(np.float32)
                cuda_data = _to_data_on_device(data, "cuda")
                return tensor_class(cuda_data, requires_grad=self.requires_grad, device="cuda")
            else:  # cpu
                data = _to_numpy(self.data)
                return tensor_class(data, requires_grad=self.requires_grad, device="cpu")
        tensor_class.to = to
    
    if not hasattr(tensor_class, 'requires_grad_'):
        def requires_grad_(self, requires_grad=True):
            """原地设置 requires_grad"""
            self.requires_grad = requires_grad
            if requires_grad and self.grad is None:
                if self.device == "cuda":
                    self.grad = np.zeros(self.shape, dtype=np.float32)
                else:
                    self.grad = np.zeros_like(self.data, dtype=np.float64)
            return self
        tensor_class.requires_grad_ = requires_grad_
    
    # ========================================================================
    # 2. 就地操作（In-place Operations）
    # ========================================================================
    
    if not hasattr(tensor_class, 'add_'):
        def add_(self, other, alpha=1):
            """原地加法: self += alpha * other"""
            from neurx.core.neurx import _to_numpy
            other_data = (other if isinstance(other, tensor_class) else tensor_class(other)).data
            self.data = self.data + alpha * _to_numpy(other_data)
            return self
        tensor_class.add_ = add_
    
    if not hasattr(tensor_class, 'sub_'):
        def sub_(self, other, alpha=1):
            """原地减法: self -= alpha * other"""
            from neurx.core.neurx import _to_numpy
            other_data = (other if isinstance(other, tensor_class) else tensor_class(other)).data
            self.data = self.data - alpha * _to_numpy(other_data)
            return self
        tensor_class.sub_ = sub_
    
    if not hasattr(tensor_class, 'mul_'):
        def mul_(self, other):
            """原地乘法: self *= other"""
            from neurx.core.neurx import _to_numpy
            other_data = (other if isinstance(other, tensor_class) else tensor_class(other)).data
            self.data = self.data * _to_numpy(other_data)
            return self
        tensor_class.mul_ = mul_
    
    if not hasattr(tensor_class, 'div_'):
        def div_(self, other):
            """原地除法: self /= other"""
            from neurx.core.neurx import _to_numpy
            other_data = (other if isinstance(other, tensor_class) else tensor_class(other)).data
            self.data = self.data / _to_numpy(other_data)
            return self
        tensor_class.div_ = div_
    
    if not hasattr(tensor_class, 'zero_'):
        def zero_(self):
            """原地填充为零"""
            self.data.fill(0)
            if self.requires_grad and self.grad is not None:
                self.grad.fill(0)
            return self
        tensor_class.zero_ = zero_
    
    if not hasattr(tensor_class, 'fill_'):
        def fill_(self, value):
            """原地填充为指定值"""
            self.data.fill(value)
            return self
        tensor_class.fill_ = fill_
    
    # ========================================================================
    # 3. 比较和逻辑操作
    # ========================================================================
    
    # 注意：__eq__ 用于对象相等性检查，不应覆盖
    # 使用单独的方法实现元素比较
    
    if not hasattr(tensor_class, 'eq'):
        def eq(self, other):
            """元素比较: =="""
            from neurx.core.neurx import _to_numpy
            other_data = (other if isinstance(other, tensor_class) else tensor_class(other)).data
            return tensor_class(_to_numpy(self.data) == _to_numpy(other_data), device=self.device)
        tensor_class.eq = eq
    
    if not hasattr(tensor_class, 'ne'):
        def ne(self, other):
            """元素比较: !="""
            from neurx.core.neurx import _to_numpy
            other_data = (other if isinstance(other, tensor_class) else tensor_class(other)).data
            return tensor_class(_to_numpy(self.data) != _to_numpy(other_data), device=self.device)
        tensor_class.ne = ne
    
    if not hasattr(tensor_class, 'lt'):
        def lt(self, other):
            """元素比较: <"""
            from neurx.core.neurx import _to_numpy
            other_data = (other if isinstance(other, tensor_class) else tensor_class(other)).data
            return tensor_class(_to_numpy(self.data) < _to_numpy(other_data), device=self.device)
        tensor_class.lt = lt
    
    if not hasattr(tensor_class, 'le'):
        def le(self, other):
            """元素比较: <="""
            from neurx.core.neurx import _to_numpy
            other_data = (other if isinstance(other, tensor_class) else tensor_class(other)).data
            return tensor_class(_to_numpy(self.data) <= _to_numpy(other_data), device=self.device)
        tensor_class.le = le
    
    if not hasattr(tensor_class, 'gt'):
        def gt(self, other):
            """元素比较: >"""
            from neurx.core.neurx import _to_numpy
            other_data = (other if isinstance(other, tensor_class) else tensor_class(other)).data
            return tensor_class(_to_numpy(self.data) > _to_numpy(other_data), device=self.device)
        tensor_class.gt = gt
    
    if not hasattr(tensor_class, 'ge'):
        def ge(self, other):
            """元素比较: >="""
            from neurx.core.neurx import _to_numpy
            other_data = (other if isinstance(other, tensor_class) else tensor_class(other)).data
            return tensor_class(_to_numpy(self.data) >= _to_numpy(other_data), device=self.device)
        tensor_class.ge = ge

    
    # ========================================================================
    # 4. 数据类型转换
    # ========================================================================
    
    if not hasattr(tensor_class, 'float'):
        def float(self):
            """转换为 float32"""
            data = _to_numpy(self.data).astype(np.float32)
            return tensor_class(data, requires_grad=self.requires_grad, device=self.device)
        tensor_class.float = float
    
    if not hasattr(tensor_class, 'double'):
        def double(self):
            """转换为 float64"""
            from neurx.core.neurx import _to_numpy
            data = _to_numpy(self.data).astype(np.float64)
            return tensor_class(data, requires_grad=self.requires_grad, device=self.device)
        tensor_class.double = double
    
    if not hasattr(tensor_class, 'int'):
        def int(self):
            """转换为 int32"""
            from neurx.core.neurx import _to_numpy
            data = _to_numpy(self.data).astype(np.int32)
            return tensor_class(data, requires_grad=False, device=self.device)
        tensor_class.int = int
    
    if not hasattr(tensor_class, 'long'):
        def long(self):
            """转换为 int64"""
            from neurx.core.neurx import _to_numpy
            data = _to_numpy(self.data).astype(np.int64)
            return tensor_class(data, requires_grad=False, device=self.device)
        tensor_class.long = long
    
    # ========================================================================
    # 5. 高级操作
    # ========================================================================
    
    if not hasattr(tensor_class, 'clamp'):
        def clamp(self, min=None, max=None):
            """限制张量值在 [min, max] 范围内"""
            from neurx.core.neurx import _to_numpy
            data = _to_numpy(self.data).copy()
            if min is not None:
                data = np.maximum(data, min)
            if max is not None:
                data = np.minimum(data, max)
            
            out = tensor_class(data, requires_grad=self.requires_grad, device=self.device)
            
            def _backward():
                if self.requires_grad:
                    grad = out.grad.copy()
                    if min is not None:
                        grad[_to_numpy(self.data) < min] = 0
                    if max is not None:
                        grad[_to_numpy(self.data) > max] = 0
                    self.grad += grad
            
            out._backward = _backward
            return out
        tensor_class.clamp = clamp
    
    if not hasattr(tensor_class, 'isnan'):
        def isnan(self):
            """检查 NaN 值"""
            from neurx.core.neurx import _to_numpy
            return tensor_class(np.isnan(_to_numpy(self.data)))
        tensor_class.isnan = isnan
    
    if not hasattr(tensor_class, 'isinf'):
        def isinf(self):
            """检查无穷值"""
            from neurx.core.neurx import _to_numpy
            return tensor_class(np.isinf(_to_numpy(self.data)))
        tensor_class.isinf = isinf
    
    if not hasattr(tensor_class, 'isfinite'):
        def isfinite(self):
            """检查有限值"""
            from neurx.core.neurx import _to_numpy
            return tensor_class(np.isfinite(_to_numpy(self.data)))
        tensor_class.isfinite = isfinite
    
    if not hasattr(tensor_class, 'retain_grad'):
        def retain_grad(self):
            """保留非叶子节点的梯度"""
            if not self.requires_grad:
                raise RuntimeError("called retain_grad on tensor with requires_grad=False")
            self._retain_grad = True
            return self
        tensor_class.retain_grad = retain_grad
    
    if not hasattr(tensor_class, 'contiguous'):
        def contiguous(self):
            """确保内存连续（NumPy 数组已连续）"""
            return self
        tensor_class.contiguous = contiguous
    
    return tensor_class


# 自动应用增强（在模块导入时）
def _apply_enhancements():
    """在 neurx 导入时自动应用增强"""
    try:
        from neurx.core.neurx import Tensor
        add_tensor_enhancements(Tensor)
    except ImportError:
        pass


# 调用自动应用
_apply_enhancements()
