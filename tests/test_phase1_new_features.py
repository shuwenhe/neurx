"""
测试 Phase 1 新增功能
包含 in-place数学运算、数学函数增强、clamp变体、逻辑运算
"""
import numpy as np
import pytest
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

from neurx.core.neurx import Tensor

# ==================== In-place Mathematical Operations Tests ====================

class TestInPlaceMathOps:
    """Test in-place mathematical operations"""
    
    def test_exp_(self):
        """Test in-place exponential"""
        x = Tensor([0.0, 1.0, 2.0])
        x_data_before = x.data.copy()
        x.exp_()
        expected = np.exp([0.0, 1.0, 2.0])
        np.testing.assert_allclose(x.data, expected, rtol=1e-6)
        assert x.data is not x_data_before or not np.shares_memory(x.data, x_data_before)
        print("✓ exp_() 测试通过")

    def test_log_(self):
        """Test in-place logarithm"""
        x = Tensor([1.0, np.e, 10.0])
        x.log_()
        expected = np.log([1.0, np.e, 10.0])
        np.testing.assert_allclose(x.data, expected, rtol=1e-6)
        print("✓ log_() 测试通过")

    def test_sqrt_(self):
        """Test in-place square root"""
        x = Tensor([1.0, 4.0, 9.0, 16.0])
        x.sqrt_()
        expected = np.array([1.0, 2.0, 3.0, 4.0])
        np.testing.assert_allclose(x.data, expected, rtol=1e-6)
        print("✓ sqrt_() 测试通过")

    def test_sin_(self):
        """Test in-place sine"""
        x = Tensor([0.0, np.pi/2, np.pi])
        x.sin_()
        expected = np.sin([0.0, np.pi/2, np.pi])
        np.testing.assert_allclose(x.data, expected, rtol=1e-6)
        print("✓ sin_() 测试通过")

    def test_cos_(self):
        """Test in-place cosine"""
        x = Tensor([0.0, np.pi/2, np.pi])
        x.cos_()
        expected = np.cos([0.0, np.pi/2, np.pi])
        np.testing.assert_allclose(x.data, expected, rtol=1e-5)
        print("✓ cos_() 测试通过")

    def test_abs_(self):
        """Test in-place absolute value"""
        x = Tensor([-3.0, -1.0, 0.0, 1.0, 3.0])
        x.abs_()
        expected = np.array([3.0, 1.0, 0.0, 1.0, 3.0])
        np.testing.assert_allclose(x.data, expected, rtol=1e-6)
        print("✓ abs_() 测试通过")

    def test_sigmoid_(self):
        """Test in-place sigmoid"""
        x = Tensor([0.0, 1.0, -1.0])
        x.sigmoid_()
        expected = 1.0 / (1.0 + np.exp(-np.array([0.0, 1.0, -1.0])))
        np.testing.assert_allclose(x.data, expected, rtol=1e-6)
        print("✓ sigmoid_() 测试通过")

    def test_tanh_(self):
        """Test in-place tanh"""
        x = Tensor([0.0, 0.5, -0.5])
        x.tanh_()
        expected = np.tanh([0.0, 0.5, -0.5])
        np.testing.assert_allclose(x.data, expected, rtol=1e-6)
        print("✓ tanh_() 测试通过")


# ==================== Mathematical Functions Enhancement Tests ====================

class TestMathFunctionsEnhancement:
    """Test enhanced mathematical functions"""
    
    def test_log1p(self):
        """Test log(1 + x) - numerically stable"""
        x = Tensor([0.0, 0.5, 1.0, -0.5], requires_grad=True)
        y = x.log1p()
        expected = np.log1p([0.0, 0.5, 1.0, -0.5])
        np.testing.assert_allclose(y.data, expected, rtol=1e-6)
        print("✓ log1p() 前向通过")
        
        # 测试反向传播
        loss = y.sum()
        loss.backward()
        expected_grad = 1.0 / (1.0 + np.array([0.0, 0.5, 1.0, -0.5]))
        np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
        print("✓ log1p() 梯度通过")

    def test_expm1(self):
        """Test exp(x) - 1 - numerically stable"""
        x = Tensor([0.0, 0.5, 1.0], requires_grad=True)
        y = x.expm1()
        expected = np.expm1([0.0, 0.5, 1.0])
        np.testing.assert_allclose(y.data, expected, rtol=1e-6)
        print("✓ expm1() 前向通过")
        
        # 测试反向传播
        loss = y.sum()
        loss.backward()
        expected_grad = np.exp([0.0, 0.5, 1.0])
        np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
        print("✓ expm1() 梯度通过")

    def test_reciprocal(self):
        """Test 1/x"""
        x = Tensor([1.0, 2.0, 4.0], requires_grad=True)
        y = x.reciprocal()
        expected = np.array([1.0, 0.5, 0.25])
        np.testing.assert_allclose(y.data, expected, rtol=1e-6)
        print("✓ reciprocal() 前向通过")
        
        # 测试反向传播
        loss = y.sum()
        loss.backward()
        # d(1/x)/dx = -1/x²
        expected_grad = -1.0 / (np.array([1.0, 2.0, 4.0]) ** 2)
        np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
        print("✓ reciprocal() 梯度通过")

    def test_rsqrt(self):
        """Test 1/sqrt(x)"""
        x = Tensor([1.0, 4.0, 9.0], requires_grad=True)
        y = x.rsqrt()
        expected = 1.0 / np.sqrt([1.0, 4.0, 9.0])
        np.testing.assert_allclose(y.data, expected, rtol=1e-6)
        print("✓ rsqrt() 前向通过")
        
        # 测试反向传播
        loss = y.sum()
        loss.backward()
        # d(1/sqrt(x))/dx = -1/(2*x^(3/2))
        x_vals = np.array([1.0, 4.0, 9.0])
        expected_grad = -0.5 / (x_vals ** 1.5)
        np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
        print("✓ rsqrt() 梯度通过")


# ==================== Clamp Variants Tests ====================

class TestClampVariants:
    """Test clamp variants"""
    
    def test_clamp_min(self):
        """Test clamp minimum"""
        x = Tensor([-2.0, -1.0, 0.0, 1.0, 2.0], requires_grad=True)
        y = x.clamp_min(0.0)
        expected = np.array([0.0, 0.0, 0.0, 1.0, 2.0])
        np.testing.assert_allclose(y.data, expected, rtol=1e-6)
        print("✓ clamp_min() 前向通过")
        
        # 测试梯度
        loss = y.sum()
        loss.backward()
        # 梯度在 x >= min_val 的位置为1，否则为0
        expected_grad = np.array([0.0, 0.0, 1.0, 1.0, 1.0])
        np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
        print("✓ clamp_min() 梯度通过")

    def test_clamp_max(self):
        """Test clamp maximum"""
        x = Tensor([-2.0, -1.0, 0.0, 1.0, 2.0], requires_grad=True)
        y = x.clamp_max(1.0)
        expected = np.array([-2.0, -1.0, 0.0, 1.0, 1.0])
        np.testing.assert_allclose(y.data, expected, rtol=1e-6)
        print("✓ clamp_max() 前向通过")
        
        # 测试梯度
        loss = y.sum()
        loss.backward()
        # 梯度在 x <= max_val 的位置为1，否则为0
        expected_grad = np.array([1.0, 1.0, 1.0, 1.0, 0.0])
        np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
        print("✓ clamp_max() 梯度通过")

    def test_clamp_(self):
        """Test in-place clamp"""
        x = Tensor([-2.0, -1.0, 0.0, 1.0, 2.0])
        x.clamp_(-1.0, 1.0)
        expected = np.array([-1.0, -1.0, 0.0, 1.0, 1.0])
        np.testing.assert_allclose(x.data, expected, rtol=1e-6)
        print("✓ clamp_() 测试通过")


# ==================== Logical Operations Tests ====================

class TestLogicalOperations:
    """Test logical operations"""
    
    def test_all(self):
        """Test all() function"""
        # 测试全为真的情况
        x = Tensor([1.0, 2.0, 3.0])
        result = x.all()
        assert float(result.data) == 1.0
        print("✓ all() 全为真测试通过")
        
        # 测试包含0的情况
        x = Tensor([1.0, 0.0, 3.0])
        result = x.all()
        assert float(result.data) == 0.0
        print("✓ all() 包含0测试通过")
        
        # 测试按维度
        x = Tensor([[1.0, 2.0], [0.0, 1.0]])
        result = x.all(dim=0)
        expected = np.array([0.0, 1.0])
        np.testing.assert_allclose(result.data, expected, rtol=1e-6)
        print("✓ all(dim=0) 测试通过")

    def test_any(self):
        """Test any() function"""
        # 测试全为假的情况
        x = Tensor([0.0, 0.0, 0.0])
        result = x.any()
        assert float(result.data) == 0.0
        print("✓ any() 全为假测试通过")
        
        # 测试包含1的情况
        x = Tensor([0.0, 1.0, 0.0])
        result = x.any()
        assert float(result.data) == 1.0
        print("✓ any() 包含1测试通过")
        
        # 测试按维度
        x = Tensor([[0.0, 0.0], [0.0, 1.0]])
        result = x.any(dim=1)
        expected = np.array([0.0, 1.0])
        np.testing.assert_allclose(result.data, expected, rtol=1e-6)
        print("✓ any(dim=1) 测试通过")


# ==================== Integration Tests ====================

class TestIntegration:
    """Integration tests with backward pass"""
    
    def test_inplace_ops_with_backward(self):
        """Test that in-place ops don't break gradients"""
        x = Tensor([1.0, 2.0], requires_grad=True)
        y = x + 1.0  # 创建新tensor防止覆盖
        y.relu_()  # in-place操作
        loss = y.sum()
        loss.backward()
        # relu doesn't affect positive values
        expected_grad = np.array([1.0, 1.0])
        np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
        print("✓ in-place with backward 测试通过")

    def test_math_functions_chain(self):
        """Test chaining of mathematical functions"""
        x = Tensor([0.1, 0.5, 1.0], requires_grad=True)
        y = x.log1p().exp_().reciprocal()
        loss = y.sum()
        loss.backward()
        # 梯度应该反向传播
        assert x.grad is not None and x.grad.size > 0
        print("✓ 函数链式组合测试通过")


# ==================== Run Tests ====================

if __name__ == "__main__":
    print("=" * 60)
    print("开始测试 Phase 1 新增功能")
    print("=" * 60)
    
    # In-place operations
    print("\n--- In-place Mathematical Operations ---")
    test_inplace = TestInPlaceMathOps()
    test_inplace.test_exp_()
    test_inplace.test_log_()
    test_inplace.test_sqrt_()
    test_inplace.test_sin_()
    test_inplace.test_cos_()
    test_inplace.test_abs_()
    test_inplace.test_sigmoid_()
    test_inplace.test_tanh_()
    
    # Mathematical functions enhancement
    print("\n--- Mathematical Functions Enhancement ---")
    test_math = TestMathFunctionsEnhancement()
    test_math.test_log1p()
    test_math.test_expm1()
    test_math.test_reciprocal()
    test_math.test_rsqrt()
    
    # Clamp variants
    print("\n--- Clamp Variants ---")
    test_clamp = TestClampVariants()
    test_clamp.test_clamp_min()
    test_clamp.test_clamp_max()
    test_clamp.test_clamp_()
    
    # Logical operations
    print("\n--- Logical Operations ---")
    test_logical = TestLogicalOperations()
    test_logical.test_all()
    test_logical.test_any()
    
    # Integration
    print("\n--- Integration Tests ---")
    test_integration = TestIntegration()
    test_integration.test_inplace_ops_with_backward()
    test_integration.test_math_functions_chain()
    
    print("\n" + "=" * 60)
    print("✓ 所有 Phase 1 测试通过！")
    print("=" * 60)
