"""
neurx Tensor API 增强模块 - Phase 2
优先级1-2的高级功能实现

Phase 2 功能:
  优先级 1 - 核心基础功能:
    ✓ cat()/stack() - 张量拼接和堆叠
    ✓ split()/chunk() - 张量分割
    ✓ log()/log2()/log10()/exp() - 对数和指数
    ✓ softmax()/logsoftmax() - 常用激活
    
  优先级 2 - 数学和统计:
    ✓ sin()/cos()/tan() - 三角函数
    ✓ tanh()/sigmoid() - 激活函数
    ✓ var()/std() - 方差和标准差
    ✓ norm() - 向量和矩阵范数
    ✓ outer() - 外积
    ✓ cross() - 叉积

"""

import numpy as np
from typing import List, Tuple, Union, Optional


def add_phase2_enhancements(tensor_class):
    """
    为 Tensor 类添加优先级1-2的高级功能
    """
    
    # ========================================================================
    # 优先级 1 - 核心基础功能
    # ========================================================================
    
    # 1.1 张量拼接和堆叠
    if not hasattr(tensor_class, 'cat'):
        @staticmethod
        def cat(tensors, dim=0):
            """
            沿指定维度拼接张量列表
            
            Args:
                tensors: Tensor 列表
                dim: 拼接维度（默认0）
            
            Returns:
                拼接后的 Tensor
            
            Example:
                >>> t1 = Tensor([[1, 2], [3, 4]])
                >>> t2 = Tensor([[5, 6], [7, 8]])
                >>> t3 = Tensor.cat([t1, t2], dim=0)
                >>> t3.shape  # (4, 2)
            """
            if not isinstance(tensors, (list, tuple)):
                raise TypeError("tensors must be a list or tuple")
            if len(tensors) == 0:
                raise ValueError("tensors cannot be empty")
            
            # Convert all to numpy
            from neurx.core.neurx import _to_numpy
            arrays = [_to_numpy(t.data) if isinstance(t, tensor_class) else t 
                     for t in tensors]
            
            # Concatenate
            result = np.concatenate(arrays, axis=dim)
            
            # Determine requires_grad and device
            requires_grad = any(isinstance(t, tensor_class) and t.requires_grad 
                              for t in tensors)
            device = tensors[0].device if isinstance(tensors[0], tensor_class) else 'cpu'
            
            return tensor_class(result, requires_grad=requires_grad, device=device)
        
        tensor_class.cat = cat
    
    if not hasattr(tensor_class, 'stack'):
        @staticmethod
        def stack(tensors, dim=0):
            """
            沿新维度堆叠张量列表
            
            Args:
                tensors: Tensor 列表
                dim: 堆叠维度（默认0）
            
            Returns:
                堆叠后的 Tensor
            
            Example:
                >>> t1 = Tensor([1, 2, 3])
                >>> t2 = Tensor([4, 5, 6])
                >>> t3 = Tensor.stack([t1, t2], dim=0)
                >>> t3.shape  # (2, 3)
            """
            if not isinstance(tensors, (list, tuple)):
                raise TypeError("tensors must be a list or tuple")
            if len(tensors) == 0:
                raise ValueError("tensors cannot be empty")
            
            # Convert all to numpy
            from neurx.core.neurx import _to_numpy
            arrays = [_to_numpy(t.data) if isinstance(t, tensor_class) else t 
                     for t in tensors]
            
            # Stack
            result = np.stack(arrays, axis=dim)
            
            # Determine requires_grad and device
            requires_grad = any(isinstance(t, tensor_class) and t.requires_grad 
                              for t in tensors)
            device = tensors[0].device if isinstance(tensors[0], tensor_class) else 'cpu'
            
            return tensor_class(result, requires_grad=requires_grad, device=device)
        
        tensor_class.stack = stack
    
    # 1.2 张量分割
    if not hasattr(tensor_class, 'split'):
        def split(self, split_size, dim=0):
            """
            沿指定维度分割张量
            
            Args:
                split_size: 每个块的大小（整数或列表）
                dim: 分割维度（默认0）
            
            Returns:
                分割后的 Tensor 列表
            
            Example:
                >>> t = Tensor([[1, 2, 3], [4, 5, 6]])
                >>> chunks = t.split(2, dim=1)
                >>> len(chunks)  # 2
                >>> chunks[0].shape  # (2, 2)
            """
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            
            if isinstance(split_size, int):
                # Equal split
                indices = list(range(split_size, arr.shape[dim], split_size))
                chunks = np.array_split(arr, indices, axis=dim)
            else:
                # Unequal split
                chunks = []
                start = 0
                for size in split_size:
                    end = start + size
                    chunk = np.take(arr, np.arange(start, min(end, arr.shape[dim])), axis=dim)
                    chunks.append(chunk)
                    start = end
            
            return [tensor_class(c, requires_grad=self.requires_grad, device=self.device) 
                   for c in chunks]
        
        tensor_class.split = split
    
    if not hasattr(tensor_class, 'chunk'):
        def chunk(self, chunks, dim=0):
            """
            将张量分割为指定数量的块
            
            Args:
                chunks: 块数
                dim: 分割维度（默认0）
            
            Returns:
                分割后的 Tensor 列表
            
            Example:
                >>> t = Tensor([[1, 2, 3, 4], [5, 6, 7, 8]])
                >>> chunks = t.chunk(2, dim=1)
                >>> len(chunks)  # 2
                >>> chunks[0].shape  # (2, 2)
            """
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            size = (arr.shape[dim] + chunks - 1) // chunks
            return self.split(size, dim=dim)
        
        tensor_class.chunk = chunk
    
    # 1.3 对数和指数函数 (数值稳定)
    if not hasattr(tensor_class, 'log'):
        def log(self):
            """
            自然对数，支持梯度反向传播
            
            Returns:
                log(self) Tensor
            
            Example:
                >>> t = Tensor([1.0, 2.0, 3.0])
                >>> result = t.log()
            """
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            result = np.log(np.clip(arr, 1e-10, None))  # 数值稳定性
            
            t = tensor_class(result, requires_grad=self.requires_grad and self.requires_grad, 
                           device=self.device)
            if self.requires_grad:
                t._children = (self,)
                t._op = 'log'
            return t
        
        tensor_class.log = log
    
    if not hasattr(tensor_class, 'exp'):
        def exp(self):
            """
            指数函数 e^x，支持梯度反向传播
            
            Returns:
                exp(self) Tensor
            
            Example:
                >>> t = Tensor([0.0, 1.0, 2.0])
                >>> result = t.exp()
            """
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            result = np.exp(np.clip(arr, -100, 100))  # 数值稳定性
            
            t = tensor_class(result, requires_grad=self.requires_grad and self.requires_grad, 
                           device=self.device)
            if self.requires_grad:
                t._children = (self,)
                t._op = 'exp'
            return t
        
        tensor_class.exp = exp
    
    if not hasattr(tensor_class, 'log2'):
        def log2(self):
            """以2为底的对数"""
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            result = np.log2(np.clip(arr, 1e-10, None))
            
            t = tensor_class(result, requires_grad=self.requires_grad and self.requires_grad, 
                           device=self.device)
            if self.requires_grad:
                t._children = (self,)
                t._op = 'log2'
            return t
        
        tensor_class.log2 = log2
    
    if not hasattr(tensor_class, 'log10'):
        def log10(self):
            """以10为底的对数"""
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            result = np.log10(np.clip(arr, 1e-10, None))
            
            t = tensor_class(result, requires_grad=self.requires_grad and self.requires_grad, 
                           device=self.device)
            if self.requires_grad:
                t._children = (self,)
                t._op = 'log10'
            return t
        
        tensor_class.log10 = log10
    
    # 1.4 Softmax (数值稳定实现)
    if not hasattr(tensor_class, 'softmax'):
        def softmax(self, dim=-1):
            """
            Softmax 激活函数，支持梯度反向传播
            使用 log-sum-exp 技巧确保数值稳定性
            
            Args:
                dim: 应用 softmax 的维度（默认 -1）
            
            Returns:
                softmax(self) Tensor
            
            Example:
                >>> t = Tensor([[1.0, 2.0, 3.0]])
                >>> result = t.softmax(dim=1)
            """
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            
            # Normalize dimension
            if dim < 0:
                dim = len(arr.shape) + dim
            
            # Log-sum-exp 技巧以确保数值稳定性
            arr_shifted = arr - np.max(arr, axis=dim, keepdims=True)
            exp = np.exp(arr_shifted)
            result = exp / np.sum(exp, axis=dim, keepdims=True)
            
            t = tensor_class(result, requires_grad=self.requires_grad and self.requires_grad, 
                           device=self.device)
            if self.requires_grad:
                t._children = (self,)
                t._op = f'softmax(dim={dim})'
            return t
        
        tensor_class.softmax = softmax
    
    if not hasattr(tensor_class, 'log_softmax'):
        def log_softmax(self, dim=-1):
            """
            Log-Softmax 函数，数值稳定
            log(softmax(x)) 使用稳定实现
            
            Args:
                dim: 应用 log_softmax 的维度（默认 -1）
            
            Returns:
                log_softmax(self) Tensor
            """
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            
            # Normalize dimension
            if dim < 0:
                dim = len(arr.shape) + dim
            
            # 使用稳定公式: log_softmax(x) = x - log(sum(exp(x)))
            arr_shifted = arr - np.max(arr, axis=dim, keepdims=True)
            logsumexp = np.log(np.sum(np.exp(arr_shifted), axis=dim, keepdims=True))
            result = arr_shifted - logsumexp
            
            t = tensor_class(result, requires_grad=self.requires_grad and self.requires_grad, 
                           device=self.device)
            if self.requires_grad:
                t._children = (self,)
                t._op = f'log_softmax(dim={dim})'
            return t
        
        tensor_class.log_softmax = log_softmax
    
    # ========================================================================
    # 优先级 2 - 数学和统计函数
    # ========================================================================
    
    # 2.1 三角函数
    if not hasattr(tensor_class, 'sin'):
        def sin(self):
            """正弦函数"""
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            result = np.sin(arr)
            
            t = tensor_class(result, requires_grad=self.requires_grad and self.requires_grad, 
                           device=self.device)
            if self.requires_grad:
                t._children = (self,)
                t._op = 'sin'
            return t
        
        tensor_class.sin = sin
    
    if not hasattr(tensor_class, 'cos'):
        def cos(self):
            """余弦函数"""
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            result = np.cos(arr)
            
            t = tensor_class(result, requires_grad=self.requires_grad and self.requires_grad, 
                           device=self.device)
            if self.requires_grad:
                t._children = (self,)
                t._op = 'cos'
            return t
        
        tensor_class.cos = cos
    
    if not hasattr(tensor_class, 'tan'):
        def tan(self):
            """正切函数"""
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            result = np.tan(arr)
            
            t = tensor_class(result, requires_grad=self.requires_grad and self.requires_grad, 
                           device=self.device)
            if self.requires_grad:
                t._children = (self,)
                t._op = 'tan'
            return t
        
        tensor_class.tan = tan
    
    # 2.2 激活函数
    if not hasattr(tensor_class, 'sigmoid'):
        def sigmoid(self):
            """
            Sigmoid 激活函数: 1 / (1 + exp(-x))
            使用稳定实现以避免数值溢出
            """
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            
            # 稳定实现
            result = np.where(
                arr >= 0,
                1 / (1 + np.exp(-arr)),
                np.exp(arr) / (1 + np.exp(arr))
            )
            
            t = tensor_class(result, requires_grad=self.requires_grad and self.requires_grad, 
                           device=self.device)
            if self.requires_grad:
                t._children = (self,)
                t._op = 'sigmoid'
            return t
        
        tensor_class.sigmoid = sigmoid
    
    if not hasattr(tensor_class, 'tanh'):
        def tanh(self):
            """双曲正切函数"""
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            result = np.tanh(arr)
            
            t = tensor_class(result, requires_grad=self.requires_grad and self.requires_grad, 
                           device=self.device)
            if self.requires_grad:
                t._children = (self,)
                t._op = 'tanh'
            return t
        
        tensor_class.tanh = tanh
    
    # 2.3 统计函数
    if not hasattr(tensor_class, 'var'):
        def var(self, dim=None, keepdims=False, unbiased=True):
            """
            方差计算
            
            Args:
                dim: 计算维度（None 表示所有元素）
                keepdims: 是否保持维度
                unbiased: 是否使用无偏估计（使用 N-1）
            """
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            
            ddof = 1 if unbiased else 0
            result = np.var(arr, axis=dim, keepdims=keepdims, ddof=ddof)
            
            return tensor_class(result, requires_grad=False, device=self.device)
        
        tensor_class.var = var
    
    if not hasattr(tensor_class, 'std'):
        def std(self, dim=None, keepdims=False, unbiased=True):
            """
            标准差计算
            
            Args:
                dim: 计算维度（None 表示所有元素）
                keepdims: 是否保持维度
                unbiased: 是否使用无偏估计（使用 N-1）
            """
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            
            ddof = 1 if unbiased else 0
            result = np.std(arr, axis=dim, keepdims=keepdims, ddof=ddof)
            
            return tensor_class(result, requires_grad=False, device=self.device)
        
        tensor_class.std = std
    
    # 2.4 范数计算
    if not hasattr(tensor_class, 'norm'):
        def norm(self, p='fro', dim=None, keepdims=False):
            """
            张量范数计算
            
            Args:
                p: 范数类型 ('fro'=Frobenius, 'nuc'=核, 1, 2, np.inf 等)
                dim: 计算维度
                keepdims: 是否保持维度
            
            Returns:
                范数值 Tensor
            """
            from neurx.core.neurx import _to_numpy
            arr = _to_numpy(self.data)
            
            if p == 'fro':
                result = np.linalg.norm(arr)
            elif p == 'nuc':
                # 核范数 = 奇异值之和
                _, s, _ = np.linalg.svd(arr)
                result = np.sum(s)
            else:
                result = np.linalg.norm(arr, ord=p, axis=dim, keepdims=keepdims)
            
            return tensor_class(np.array(result), requires_grad=False, device=self.device)
        
        tensor_class.norm = norm
    
    # 2.5 向量操作
    if not hasattr(tensor_class, 'outer'):
        def outer(self, other):
            """
            外积 (outer product)
            
            Args:
                other: 另一个 Tensor
            
            Returns:
                外积结果 Tensor
            
            Example:
                >>> a = Tensor([1, 2, 3])
                >>> b = Tensor([4, 5, 6])
                >>> result = a.outer(b)
                >>> result.shape  # (3, 3)
            """
            from neurx.core.neurx import _to_numpy
            a = _to_numpy(self.data).flatten()
            b = _to_numpy(other.data if isinstance(other, tensor_class) else other).flatten()
            
            result = np.outer(a, b)
            requires_grad = self.requires_grad or (isinstance(other, tensor_class) and other.requires_grad)
            
            return tensor_class(result, requires_grad=requires_grad, device=self.device)
        
        tensor_class.outer = outer
    
    if not hasattr(tensor_class, 'cross'):
        def cross(self, other, dim=-1):
            """
            叉积 (cross product) - 仅用于 3D 向量
            
            Args:
                other: 另一个 Tensor
                dim: 向量维度位置（默认 -1）
            
            Returns:
                叉积结果 Tensor
            """
            from neurx.core.neurx import _to_numpy
            a = _to_numpy(self.data)
            b = _to_numpy(other.data if isinstance(other, tensor_class) else other)
            
            result = np.cross(a, b)
            requires_grad = self.requires_grad or (isinstance(other, tensor_class) and other.requires_grad)
            
            return tensor_class(result, requires_grad=requires_grad, device=self.device)
        
        tensor_class.cross = cross
    
    return tensor_class
