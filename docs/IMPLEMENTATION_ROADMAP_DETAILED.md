# Tensor 框架功能补齐 - 详细实现路线图

**版本**: 1.0  
**更新日期**: 2026-03-04

---

## 📌 概述

本文档提供每个功能模块的具体实现指导，包括代码示例、测试策略和验证方法。

---

## 🎯 第一阶段：核心功能补齐（第 1-3 周）

### 1. In-place 操作实现

#### 1.1 设计规范

```python
# 文件位置: python/neurx/core/neurx.py

class Tensor:
    # 基本原则:
    # 1. in-place 操作返回 self
    # 2. 保持梯度追踪能力
    # 3. 对 CUDA 和 CPU 都支持
    # 4. 不改变其他引用对象的值
    
    def add_(self, other):
        """
        原地加法。in-place 版本的 add()
        
        Args:
            other: Tensor 或标量
            
        Returns:
            self
            
        Example:
            >>> x = Tensor([1, 2, 3])
            >>> x.add_(2)
            >>> x  # [3, 4, 5]
        """
        other = other if isinstance(other, Tensor) else Tensor(other)
        
        if self.device == "cuda" and other.device == "cuda":
            self.data = _cuda_ops.add(self.data, other.data)
        else:
            self.data = _to_numpy(self.data) + _to_numpy(other.data)
        
        # 更新梯度 (如果之前有 requires_grad)
        if self.requires_grad or other.requires_grad:
            self.requires_grad = True
        
        return self
    
    def mul_(self, other):
        """原地乘法"""
        other = other if isinstance(other, Tensor) else Tensor(other)
        
        if self.device == "cuda" and other.device == "cuda":
            self.data = _cuda_ops.mul(self.data, other.data)
        else:
            self.data = _to_numpy(self.data) * _to_numpy(other.data)
        
        if self.requires_grad or other.requires_grad:
            self.requires_grad = True
        
        return self
    
    def sub_(self, other):
        """原地减法"""
        return self.add_(-other if isinstance(other, Tensor) else -other)
    
    def div_(self, other):
        """原地除法"""
        other = other if isinstance(other, Tensor) else Tensor(other)
        
        self.data = _to_numpy(self.data) / _to_numpy(other.data)
        
        if self.requires_grad or other.requires_grad:
            self.requires_grad = True
        
        return self
    
    def pow_(self, exponent):
        """原地幂运算"""
        self.data = _to_numpy(self.data) ** exponent
        return self
    
    def copy_(self, other):
        """原地复制"""
        self.data = _to_numpy(other.data).copy()
        self.requires_grad = other.requires_grad
        return self
    
    def fill_(self, value):
        """原地填充"""
        self.data = np.full(self.shape, value, dtype=self.data.dtype)
        return self
    
    def zero_(self):
        """原地归零"""
        return self.fill_(0)
```

#### 1.2 测试代码

```python
# 文件位置: tests/test_inplace_ops.py

import numpy as np
import pytest
from neurx import Tensor

class TestInPlaceOps:
    def test_add_(self):
        """测试原地加法"""
        x = Tensor([1.0, 2.0, 3.0], requires_grad=True)
        x_id = id(x.data)
        
        x.add_(2.0)
        
        assert np.allclose(x.data, [3.0, 4.0, 5.0])
        assert x.requires_grad
        assert id(x.data) != x_id  # 数据被修改
    
    def test_mul_(self):
        """测试原地乘法"""
        x = Tensor([1.0, 2.0, 3.0])
        x.mul_(2.0)
        assert np.allclose(x.data, [2.0, 4.0, 6.0])
    
    def test_inplace_returns_self(self):
        """验证返回值是 self"""
        x = Tensor([1.0, 2.0])
        result = x.add_(1.0)
        assert result is x
    
    def test_zero_(self):
        """测试原地归零"""
        x = Tensor([1.0, 2.0, 3.0])
        x.zero_()
        assert np.allclose(x.data, [0.0, 0.0, 0.0])
    
    def test_fill_(self):
        """测试原地填充"""
        x = Tensor([1.0, 2.0, 3.0])
        x.fill_(5.0)
        assert np.allclose(x.data, [5.0, 5.0, 5.0])
    
    @pytest.mark.skipif(not _cuda_ops, reason="CUDA not available")
    def test_cuda_inplace(self):
        """测试 CUDA in-place 操作"""
        x = Tensor([1.0, 2.0], device="cuda")
        x.add_(1.0)
        assert np.allclose(_to_numpy(x.data), [2.0, 3.0])
```

#### 1.3 预期工作量
- 实现: 2 天
- 测试: 1 天
- 文档: 0.5 天

---

### 2. 线性代数操作

#### 2.1 基础实现框架

```python
# 文件位置: python/neurx/linalg.py

"""线性代数模块 - 矩阵分解和求解器"""

import numpy as np
from neurx.neurx import Tensor

class _LinAlgMixin:
    """为 Tensor 添加线性代数方法的 mixin"""
    
    @property
    def linalg(self):
        """返回线性代数操作对象"""
        return _LinAlgOps(self)


class _LinAlgOps:
    """线性代数操作集合"""
    
    def __init__(self, neurx):
        self.neurx = neurx
    
    def svd(self, full_matrices=True):
        """
        奇异值分解 (SVD)
        
        A = U @ diag(S) @ V^T
        
        Returns:
            U: (m, k) 矩阵
            S: (k,) 奇异值
            Vh: (k, n) 矩阵
        """
        data = _to_numpy(self.neurx.data)
        
        if data.ndim != 2:
            raise ValueError("SVD requires 2D neurx")
        
        U, S, Vh = np.linalg.svd(data, full_matrices=full_matrices)
        
        U_tensor = Tensor(U, requires_grad=self.neurx.requires_grad)
        S_tensor = Tensor(S, requires_grad=self.neurx.requires_grad)
        Vh_tensor = Tensor(Vh, requires_grad=self.neurx.requires_grad)
        
        # 定义梯度函数（简化版本）
        def _backward():
            # SVD 的梯度计算较复杂，这里仅提供框架
            if self.neurx.requires_grad:
                # 计算梯度（参考 PyTorch 实现）
                pass
        
        return U_tensor, S_tensor, Vh_tensor
    
    def qr(self):
        """
        QR 分解
        
        A = Q @ R
        
        Returns:
            Q: 正交矩阵
            R: 上三角矩阵
        """
        data = _to_numpy(self.neurx.data)
        
        if data.ndim != 2:
            raise ValueError("QR requires 2D neurx")
        
        Q, R = np.linalg.qr(data)
        
        Q_tensor = Tensor(Q, requires_grad=self.neurx.requires_grad)
        R_tensor = Tensor(R, requires_grad=self.neurx.requires_grad)
        
        return Q_tensor, R_tensor
    
    def cholesky(self, upper=False):
        """
        Cholesky 分解
        
        A = L @ L^T (lower=True)
        A = U^T @ U (upper=True)
        
        要求 A 是对称正定矩阵
        """
        data = _to_numpy(self.neurx.data)
        
        if data.ndim != 2:
            raise ValueError("Cholesky requires 2D neurx")
        
        L = np.linalg.cholesky(data)
        
        if upper:
            L = L.T
        
        out = Tensor(L, requires_grad=self.neurx.requires_grad)
        return out
    
    def inv(self):
        """矩阵求逆"""
        data = _to_numpy(self.neurx.data)
        
        if data.ndim != 2:
            raise ValueError("inv requires 2D neurx")
        
        inv_data = np.linalg.inv(data)
        
        out = Tensor(inv_data, requires_grad=self.neurx.requires_grad, 
                     parents=(self.neurx,), op="inv")
        
        def _backward():
            if self.neurx.requires_grad:
                # d(inv(A))/dA = -inv(A)^T @ dL/dA @ inv(A)^T
                grad = out.grad
                inv_A = inv_data
                self.neurx.grad += -inv_A.T @ grad @ inv_A.T
        
        out._backward = _backward
        return out
    
    def solve(self, B):
        """
        求解线性方程 A @ X = B
        
        Args:
            B: 右侧向量或矩阵
            
        Returns:
            X: 解矩阵
        """
        A = _to_numpy(self.neurx.data)
        B_data = _to_numpy(B.data) if isinstance(B, Tensor) else B
        
        X = np.linalg.solve(A, B_data)
        
        out = Tensor(X, requires_grad=self.neurx.requires_grad or B.requires_grad)
        
        return out
    
    def eig(self):
        """
        特征值分解
        
        返回: (特征值, 特征向量)
        """
        data = _to_numpy(self.neurx.data)
        
        if data.ndim != 2:
            raise ValueError("eig requires 2D neurx")
        
        eigenvalues, eigenvectors = np.linalg.eig(data)
        
        evals = Tensor(eigenvalues, requires_grad=self.neurx.requires_grad)
        evecs = Tensor(eigenvectors, requires_grad=self.neurx.requires_grad)
        
        return evals, evecs
    
    def norm(self, ord=None, dim=None, keepdim=False):
        """
        计算范数
        
        ord 可以是 'fro', 2, 1, -1, -2, inf 等
        """
        data = _to_numpy(self.neurx.data)
        
        if dim is None:
            # 全局范数
            norm_val = np.linalg.norm(data, ord=ord)
        else:
            # 按维度范数
            norm_val = np.linalg.norm(data, ord=ord, axis=dim, keepdims=keepdim)
        
        out = Tensor(norm_val, requires_grad=self.neurx.requires_grad)
        return out
```

#### 2.2 集成到 Tensor 类

```python
# 在 neurx.py 的 Tensor 类中添加

from neurx.linalg import _LinAlgMixin

class Tensor(_LinAlgMixin):
    # ... 现有代码 ...
    
    def svd(self, full_matrices=True):
        return self.linalg.svd(full_matrices)
    
    def qr(self):
        return self.linalg.qr()
    
    def cholesky(self, upper=False):
        return self.linalg.cholesky(upper)
    
    def inv(self):
        return self.linalg.inv()
    
    def solve(self, B):
        return self.linalg.solve(B)
    
    def eig(self):
        return self.linalg.eig()
    
    def norm(self, ord=None, dim=None, keepdim=False):
        return self.linalg.norm(ord, dim, keepdim)
```

#### 2.3 测试用例

```python
# 文件位置: tests/test_linalg.py

class TestLinAlg:
    def test_svd(self):
        """测试 SVD 分解"""
        A = Tensor(np.random.randn(5, 3))
        U, S, Vh = A.svd()
        
        # 验证重构
        A_reconstructed = U @ np.diag(S) @ Vh
        assert np.allclose(A.data, A_reconstructed.data, atol=1e-6)
    
    def test_qr(self):
        """测试 QR 分解"""
        A = Tensor(np.random.randn(4, 3))
        Q, R = A.qr()
        
        # Q 应该是正交矩阵
        assert np.allclose(Q.data.T @ Q.data, np.eye(3), atol=1e-6)
        
        # 验证重构
        assert np.allclose(Q.data @ R.data, A.data, atol=1e-6)
    
    def test_inv(self):
        """测试矩阵求逆"""
        A = Tensor(np.array([[1.0, 2.0], [3.0, 4.0]]))
        A_inv = A.inv()
        
        # A @ A^-1 = I
        result = A @ A_inv
        assert np.allclose(result.data, np.eye(2), atol=1e-6)
    
    def test_cholesky(self):
        """测试 Cholesky 分解"""
        # 创建对称正定矩阵
        A = Tensor(np.array([[4.0, 2.0], [2.0, 3.0]]))
        L = A.cholesky()
        
        # L @ L^T = A
        result = L @ L.transpose(0, 1)
        assert np.allclose(result.data, A.data, atol=1e-6)
    
    def test_norm(self):
        """测试范数计算"""
        x = Tensor([3.0, 4.0])
        norm2 = x.norm(ord=2)
        assert np.isclose(norm2.data, 5.0)
```

#### 2.4 预期工作量
- 核心实现: 3 天
- 梯度函数: 2 天（复杂）
- 测试: 1.5 天
- 文档: 0.5 天

---

### 3. Embedding 模块完整实现

#### 3.1 设计与实现

```python
# 文件位置: python/neurx/nn/embedding.py

class Embedding(Module):
    """
    嵌入层 - 从索引到向量的映射
    
    通常用于处理分类变量或词汇表。
    """
    
    def __init__(self, num_embeddings, embedding_dim, 
                 padding_idx=None, max_norm=None, norm_type=2.0,
                 scale_grad_by_freq=False, sparse=False):
        """
        Args:
            num_embeddings: 词汇表大小
            embedding_dim: 嵌入向量维度
            padding_idx: 如果指定，该索引的向量始终为零
            max_norm: 如果指定，梯度会被缩放以不超过此范数
            norm_type: 范数类型（1, 2）
            scale_grad_by_freq: 是否按词频缩放梯度
            sparse: 是否返回稀疏梯度（当前不支持）
        """
        super().__init__()
        
        self.num_embeddings = num_embeddings
        self.embedding_dim = embedding_dim
        self.padding_idx = padding_idx
        self.max_norm = max_norm
        self.norm_type = norm_type
        self.scale_grad_by_freq = scale_grad_by_freq
        self.sparse = sparse
        
        # 初始化权重
        weight_data = np.random.randn(num_embeddings, embedding_dim) * 0.02
        
        # 如果有 padding_idx，将其设为零
        if padding_idx is not None:
            weight_data[padding_idx] = 0
        
        self.weight = Parameter(Tensor(weight_data, requires_grad=True))
    
    def forward(self, input):
        """
        Args:
            input: 长整型张量，包含要查询的索引
            
        Returns:
            嵌入向量张量，形状为 (*input.shape, embedding_dim)
        """
        indices = _to_numpy(input.data).astype(int)
        embeddings = self.weight.data[indices]
        
        out = Tensor(embeddings, requires_grad=self.weight.requires_grad,
                    parents=(input, self.weight), op="embedding")
        
        def _backward():
            if self.weight.requires_grad:
                grad = out.grad
                # 使用 add.at 进行原地聚集
                np.add.at(self.weight.grad, indices, grad)
        
        out._backward = _backward
        return out


class EmbeddingBag(Module):
    """
    嵌入包 - 对嵌入进行聚合
    
    常用于包嵌入，对输入索引进行嵌入并聚集结果。
    """
    
    def __init__(self, num_embeddings, embedding_dim,
                 max_norm=None, norm_type=2.0,
                 scale_grad_by_freq=False, mode='mean',
                 sparse=False, include_last_offset=False):
        """
        Args:
            num_embeddings: 词汇表大小
            embedding_dim: 嵌入维度
            mode: 聚集模式 ('mean', 'sum', 'max')
            include_last_offset: 是否在 offsets 中包含最后一个偏移
        """
        super().__init__()
        
        self.embedding = Embedding(
            num_embeddings, embedding_dim,
            max_norm=max_norm, norm_type=norm_type,
            scale_grad_by_freq=scale_grad_by_freq, sparse=sparse
        )
        
        self.mode = mode
        self.include_last_offset = include_last_offset
    
    def forward(self, input, offsets=None, per_sample_weights=None):
        """
        Args:
            input: 1D 张量，包含所有的嵌入索引
            offsets: 1D 张量，指示每个包的起始位置
            per_sample_weights: 权重张量
            
        Returns:
            聚集后的嵌入张量
        """
        embeddings = self.embedding(input)
        
        if offsets is None:
            # 如果没有 offsets，假设输入是 2D
            return self._aggregate(embeddings, None, per_sample_weights)
        
        # 对每个包进行聚集
        offsets_np = _to_numpy(offsets.data).astype(int)
        embeddings_np = _to_numpy(embeddings.data)
        
        batch_size = len(offsets_np)
        output = []
        
        for i in range(batch_size):
            start = offsets_np[i]
            if i + 1 < batch_size:
                end = offsets_np[i + 1]
            else:
                end = len(embeddings_np)
            
            bag = embeddings_np[start:end]
            
            if per_sample_weights is not None:
                weights = _to_numpy(per_sample_weights.data)[start:end]
                bag = bag * weights[:, np.newaxis]
            
            if self.mode == 'mean':
                output.append(bag.mean(axis=0))
            elif self.mode == 'sum':
                output.append(bag.sum(axis=0))
            elif self.mode == 'max':
                output.append(bag.max(axis=0))
        
        out_data = np.stack(output)
        out = Tensor(out_data, requires_grad=embeddings.requires_grad)
        
        return out
```

#### 3.2 测试

```python
# 文件位置: tests/test_embedding.py

class TestEmbedding:
    def test_embedding_lookup(self):
        """测试基础嵌入查询"""
        emb = Embedding(num_embeddings=10, embedding_dim=4)
        indices = Tensor(np.array([0, 2, 5]))
        
        output = emb(indices)
        
        assert output.shape == (3, 4)
        # 检查权重是否被正确查询
        assert np.allclose(output.data[0], emb.weight.data[0])
        assert np.allclose(output.data[1], emb.weight.data[2])
    
    def test_padding_idx(self):
        """测试 padding_idx"""
        emb = Embedding(10, 4, padding_idx=0)
        
        # padding 索引对应的向量应为零
        assert np.allclose(emb.weight.data[0], 0)
    
    def test_embedding_bag_mean(self):
        """测试 EmbeddingBag 的平均池化"""
        emb_bag = EmbeddingBag(10, 4, mode='mean')
        
        indices = Tensor(np.array([0, 1, 2, 3, 4]))
        offsets = Tensor(np.array([0, 2]))
        
        output = emb_bag(indices, offsets)
        
        assert output.shape == (2, 4)
```

#### 3.3 预期工作量
- 实现: 2 天
- 测试: 1 天
- 文档: 0.5 天

---

## 📊 实现进度跟踪

| 功能 | 状态 | 优先级 | 周期 | 所有者 |
|-----|------|-------|------|--------|
| In-place 操作 | 规划中 | P0 | W1 | - |
| 线性代数 | 规划中 | P0 | W1-W2 | - |
| Embedding 模块 | 规划中 | P0 | W1 | - |
| LabelSmoothingLoss | 规划中 | P0 | W2 | - |
| FocalLoss | 规划中 | P0 | W2 | - |
| OneCycleLR | 规划中 | P0 | W2 | - |

---

## 🧪 测试策略

### 单元测试
- 每个函数都有对应的测试用例
- 覆盖正常情况、边界情况、错误情况

### 集成测试
- 与其他模块的交互测试
- 梯度流验证

### 性能基准测试
- 与 NumPy/PyTorch 的性能对比
- 内存使用情况

### 兼容性测试
- CPU 和 CUDA 后端的一致性
- 不同数据类型的支持

---

## 📝 文档需求

每个实现都应包括：
1. 详细的 docstring（参数、返回值、示例）
2. 使用教程（常见用法）
3. API 参考
4. 性能特性说明
5. 已知限制

---

## ✅ 完成标准

实现被认为完成当：
- [ ] 所有测试通过
- [ ] 代码覆盖率 > 80%
- [ ] 梯度检验通过
- [ ] 文档完整
- [ ] 性能可接受（不比 NumPy 慢超过 2 倍）
- [ ] 代码审查通过

