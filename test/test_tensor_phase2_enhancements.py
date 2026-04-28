"""
neurx Tensor Phase 2 增强功能测试套件

测试内容:
  - 张量拼接和堆叠 (cat, stack)
  - 张量分割 (split, chunk)
  - 数学函数 (log, exp, softmax等)
  - 统计函数 (var, std)
  - 向量操作 (outer, cross)
"""

import numpy as np
import pytest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent.parent / "python"))

from neurx.core.neurx import Tensor
from neurx.enhancements import add_tensor_enhancements
from neurx.enhancements_phase2 import add_phase2_enhancements

# Apply enhancements
add_tensor_enhancements(Tensor)
add_phase2_enhancements(Tensor)


class TestPhase2Concatenation:
    """测试张量拼接操作"""
    
    def test_cat_along_dim0(self):
        """沿第0维拼接"""
        t1 = Tensor([[1, 2], [3, 4]])
        t2 = Tensor([[5, 6], [7, 8]])
        result = Tensor.cat([t1, t2], dim=0)
        
        assert result.shape == (4, 2)
        expected = np.array([[1, 2], [3, 4], [5, 6], [7, 8]])
        assert np.allclose(result.numpy(), expected)
    
    def test_cat_along_dim1(self):
        """沿第1维拼接"""
        t1 = Tensor([[1, 2], [3, 4]])
        t2 = Tensor([[5, 6], [7, 8]])
        result = Tensor.cat([t1, t2], dim=1)
        
        assert result.shape == (2, 4)
        expected = np.array([[1, 2, 5, 6], [3, 4, 7, 8]])
        assert np.allclose(result.numpy(), expected)
    
    def test_stack_new_dimension(self):
        """在新维度堆叠"""
        t1 = Tensor([1, 2, 3])
        t2 = Tensor([4, 5, 6])
        result = Tensor.stack([t1, t2], dim=0)
        
        assert result.shape == (2, 3)
        expected = np.array([[1, 2, 3], [4, 5, 6]])
        assert np.allclose(result.numpy(), expected)
    
    def test_stack_different_dim(self):
        """在不同维度堆叠"""
        t1 = Tensor([1, 2, 3])
        t2 = Tensor([4, 5, 6])
        result = Tensor.stack([t1, t2], dim=1)
        
        assert result.shape == (3, 2)
        expected = np.array([[1, 4], [2, 5], [3, 6]])
        assert np.allclose(result.numpy(), expected)


class TestPhase2Splitting:
    """测试张量分割操作"""
    
    def test_split_equal_chunks(self):
        """等大小分割"""
        t = Tensor([[1, 2, 3, 4], [5, 6, 7, 8]])
        chunks = t.split(2, dim=1)
        
        assert len(chunks) == 2
        assert chunks[0].shape == (2, 2)
        assert np.allclose(chunks[0].numpy(), [[1, 2], [5, 6]])
        assert np.allclose(chunks[1].numpy(), [[3, 4], [7, 8]])
    
    def test_split_unequal_chunks(self):
        """非等大小分割"""
        t = Tensor([1, 2, 3, 4, 5])
        chunks = t.split([2, 3], dim=0)
        
        assert len(chunks) == 2
        assert chunks[0].shape == (2,)
        assert chunks[1].shape == (3,)
    
    def test_chunk_into_n_pieces(self):
        """分割成N块"""
        t = Tensor([[1, 2, 3, 4], [5, 6, 7, 8]])
        chunks = t.chunk(2, dim=1)
        
        assert len(chunks) == 2
        assert chunks[0].shape == (2, 2)


class TestPhase2MathFunctions:
    """测试数学函数"""
    
    def test_log_function(self):
        """对数函数"""
        t = Tensor([1.0, 2.0, np.e])
        result = t.log()
        
        expected = np.log([1.0, 2.0, np.e])
        assert np.allclose(result.numpy(), expected, atol=1e-5)
    
    def test_exp_function(self):
        """指数函数"""
        t = Tensor([0.0, 1.0, 2.0])
        result = t.exp()
        
        expected = np.exp([0.0, 1.0, 2.0])
        assert np.allclose(result.numpy(), expected, atol=1e-5)
    
    def test_log2_function(self):
        """以2为底对数"""
        t = Tensor([1.0, 2.0, 4.0, 8.0])
        result = t.log2()
        
        expected = np.log2([1.0, 2.0, 4.0, 8.0])
        assert np.allclose(result.numpy(), expected, atol=1e-5)
    
    def test_log10_function(self):
        """以10为底对数"""
        t = Tensor([1.0, 10.0, 100.0])
        result = t.log10()
        
        expected = np.log10([1.0, 10.0, 100.0])
        assert np.allclose(result.numpy(), expected, atol=1e-5)
    
    def test_sin_function(self):
        """正弦函数"""
        t = Tensor([0.0, np.pi/2, np.pi])
        result = t.sin()
        
        expected = np.sin([0.0, np.pi/2, np.pi])
        assert np.allclose(result.numpy(), expected, atol=1e-5)
    
    def test_cos_function(self):
        """余弦函数"""
        t = Tensor([0.0, np.pi/2, np.pi])
        result = t.cos()
        
        expected = np.cos([0.0, np.pi/2, np.pi])
        assert np.allclose(result.numpy(), expected, atol=1e-5)
    
    def test_tan_function(self):
        """正切函数"""
        t = Tensor([0.0, np.pi/4])
        result = t.tan()
        
        expected = np.tan([0.0, np.pi/4])
        assert np.allclose(result.numpy(), expected, atol=1e-5)
    
    def test_sigmoid_function(self):
        """Sigmoid 激活函数"""
        t = Tensor([-1.0, 0.0, 1.0])
        result = t.sigmoid()
        
        expected = 1 / (1 + np.exp(-np.array([-1.0, 0.0, 1.0])))
        assert np.allclose(result.numpy(), expected, atol=1e-5)
    
    def test_tanh_function(self):
        """双曲正切函数"""
        t = Tensor([0.0, 1.0, -1.0])
        result = t.tanh()
        
        expected = np.tanh([0.0, 1.0, -1.0])
        assert np.allclose(result.numpy(), expected, atol=1e-5)


class TestPhase2Softmax:
    """测试 Softmax 函数"""
    
    def test_softmax_basic(self):
        """基本 Softmax"""
        t = Tensor([[1.0, 2.0, 3.0]])
        result = t.softmax(dim=1)
        
        # Softmax 应该输出概率分布
        assert np.allclose(np.sum(result.numpy(), axis=1), [1.0], atol=1e-5)
        assert np.all(result.numpy() >= 0) and np.all(result.numpy() <= 1)
    
    def test_softmax_numerically_stable(self):
        """数值稳定性测试"""
        # 大数值不应该导致数值溢出
        t = Tensor([[1000.0, 1001.0, 1002.0]])
        result = t.softmax(dim=1)
        
        assert not np.any(np.isnan(result.numpy()))
        assert not np.any(np.isinf(result.numpy()))
        assert np.allclose(np.sum(result.numpy(), axis=1), [1.0], atol=1e-5)
    
    def test_log_softmax_basic(self):
        """基本 Log-Softmax"""
        t = Tensor([[1.0, 2.0, 3.0]])
        result = t.log_softmax(dim=1)
        
        # Log-Softmax 的输出应该是负数或零
        assert np.all(result.numpy() <= 0)
        assert not np.any(np.isnan(result.numpy()))
    
    def test_log_softmax_equivalence(self):
        """Log-Softmax 和 log(Softmax) 等价性"""
        t = Tensor([[1.0, 2.0, 3.0]])
        
        log_softmax_result = t.log_softmax(dim=1)
        softmax_result = t.softmax(dim=1)
        manual_log = np.log(softmax_result.numpy() + 1e-10)
        
        assert np.allclose(log_softmax_result.numpy(), manual_log, atol=1e-5)


class TestPhase2Statistics:
    """测试统计函数"""
    
    def test_variance(self):
        """方差计算"""
        t = Tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
        result = t.var()
        
        expected = np.var(np.array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]), ddof=1)
        assert np.allclose(result.numpy(), expected, atol=1e-5)
    
    def test_std_deviation(self):
        """标准差计算"""
        t = Tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
        result = t.std()
        
        # neurx.py中的std默认使用correction=0 (即ddof=0)
        expected = np.std(np.array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]), ddof=0)
        assert np.allclose(result.numpy(), expected, atol=1e-5)
    
    def test_variance_per_dimension(self):
        """按维度计算方差"""
        t = Tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
        result = t.var(dim=0, keepdims=True)
        
        expected = np.var(np.array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]), axis=0, keepdims=True, ddof=1)
        assert np.allclose(result.numpy(), expected, atol=1e-5)


class TestPhase2VectorOperations:
    """测试向量操作"""
    
    def test_outer_product(self):
        """外积运算"""
        a = Tensor([1.0, 2.0, 3.0])
        b = Tensor([4.0, 5.0, 6.0])
        result = a.outer(b)
        
        expected = np.outer([1.0, 2.0, 3.0], [4.0, 5.0, 6.0])
        assert result.shape == (3, 3)
        assert np.allclose(result.numpy(), expected)
    
    def test_cross_product(self):
        """叉积运算"""
        a = Tensor([1.0, 0.0, 0.0])
        b = Tensor([0.0, 1.0, 0.0])
        result = a.cross(b)
        
        expected = np.cross([1.0, 0.0, 0.0], [0.0, 1.0, 0.0])
        assert np.allclose(result.numpy(), expected)


class TestPhase2Integration:
    """集成测试"""
    
    def test_chained_operations(self):
        """链式操作"""
        t = Tensor([1.0, 2.0, 3.0])
        result = t.log().exp().log()
        
        # log(exp(log(t))) = log(t)
        expected = np.log([1.0, 2.0, 3.0])
        assert np.allclose(result.numpy(), expected, atol=1e-5)
    
    def test_cat_and_softmax(self):
        """拼接后应用 Softmax"""
        t1 = Tensor([[1.0, 2.0]])
        t2 = Tensor([[3.0, 4.0]])
        concatenated = Tensor.cat([t1, t2], dim=0)
        result = concatenated.softmax(dim=0)
        
        # 应该是有效的概率分布
        assert np.allclose(np.sum(result.numpy(), axis=0), [1.0, 1.0], atol=1e-5)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
