"""
测试 Phase 1 数学函数实现
包含 exp, log, sqrt 等基础数学函数的测试
"""
import numpy as np
import pytest
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

from neurx.core.neurx import Tensor

# ==================== exp() 测试 ====================

def test_exp_forward():
    """测试 exp() 前向传播"""
    x = np.array([0, 1, 2, -1])
    t = Tensor(x, requires_grad=False)
    y = t.exp()
    
    expected = np.exp(x)
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ exp() 前向传播测试通过")


def test_exp_backward():
    """测试 exp() 反向传播"""
    x = np.array([0.5, 1.0, 1.5])
    t = Tensor(x, requires_grad=True)
    y = t.exp()
    
    # 计算损失 (简单求和)
    loss = y.sum()
    loss.backward()
    
    # exp(x) 的导数是 exp(x)
    expected_grad = np.exp(x)
    np.testing.assert_allclose(t.grad, expected_grad, rtol=1e-6)
    print("✓ exp() 反向传播测试通过")


def test_exp_backward_with_chain_rule():
    """测试 exp() 在链式法则中的反向传播"""
    x = np.array([1.0, 2.0])
    t = Tensor(x, requires_grad=True)
    
    # y = exp(x)
    y = t.exp()
    
    # z = y^2
    z = y * y
    
    # loss = sum(z)
    loss = z.sum()
    loss.backward()
    
    # d(loss)/dx = d(sum(exp(x)^2))/dx = 2 * exp(x) * exp(x) = 2 * exp(2x)
    expected_grad = 2 * np.exp(x) * np.exp(x)
    np.testing.assert_allclose(t.grad, expected_grad, rtol=1e-5)
    print("✓ exp() 链式法则测试通过")


def test_exp_numerical_stability():
    """测试 exp() 的数值稳定性"""
    # 测试大数值
    x_large = np.array([10.0, 20.0])
    t_large = Tensor(x_large, requires_grad=False)
    y_large = t_large.exp()
    expected_large = np.exp(x_large)
    np.testing.assert_allclose(y_large.data, expected_large, rtol=1e-5)
    
    # 测试小数值
    x_small = np.array([-10.0, -5.0])
    t_small = Tensor(x_small, requires_grad=False)
    y_small = t_small.exp()
    expected_small = np.exp(x_small)
    np.testing.assert_allclose(y_small.data, expected_small, rtol=1e-6)
    
    print("✓ exp() 数值稳定性测试通过")


def test_exp_multidimensional():
    """测试 exp() 对多维张量的支持"""
    x = np.random.randn(2, 3, 4)
    t = Tensor(x, requires_grad=True)
    y = t.exp()
    
    expected = np.exp(x)
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    
    # 测试反向传播
    loss = y.sum()
    loss.backward()
    expected_grad = np.exp(x)
    np.testing.assert_allclose(t.grad, expected_grad, rtol=1e-6)
    
    print("✓ exp() 多维张量测试通过")


def test_exp_zero_grad():
    """测试 exp() 在 requires_grad=False 时不计算梯度"""
    x = np.array([1.0, 2.0])
    t = Tensor(x, requires_grad=False)
    y = t.exp()
    
    assert t.grad is None, "requires_grad=False 时不应该有梯度"
    print("✓ exp() 梯度禁用测试通过")


# ==================== PyTorch 兼容性测试 ====================

def test_exp_pytorch_compatibility():
    """测试与 PyTorch 的兼容性"""
    try:
        import torch
    except ImportError:
        print("⊘ PyTorch 未安装，跳过兼容性测试")
        return
    
    # 前向传播
    x_np = np.random.randn(3, 4)
    x_torch = torch.tensor(x_np, dtype=torch.float64)
    x_neurx = Tensor(x_np.copy())
    
    y_torch = torch.exp(x_torch)
    y_neurx = x_neurx.exp()
    
    np.testing.assert_allclose(y_neurx.data, y_torch.numpy(), rtol=1e-6)
    
    # 反向传播
    x_torch = torch.tensor(x_np, dtype=torch.float64, requires_grad=True)
    x_neurx = Tensor(x_np.copy(), requires_grad=True)
    
    y_torch = torch.exp(x_torch)
    y_neurx = x_neurx.exp()
    
    y_torch.sum().backward()
    y_neurx.sum().backward()
    
    np.testing.assert_allclose(x_neurx.grad, x_torch.grad.numpy(), rtol=1e-6)
    print("✓ exp() PyTorch 兼容性测试通过")


# ==================== log() 测试 ====================

def test_log_forward():
    """测试 log() 前向传播"""
    x = np.array([1.0, np.e, np.e**2, 10.0])
    t = Tensor(x, requires_grad=False)
    y = t.log()
    
    expected = np.log(x)
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ log() 前向传播测试通过")


def test_log_backward():
    """测试 log() 反向传播"""
    x = np.array([1.0, 2.0, 3.0])
    t = Tensor(x, requires_grad=True)
    y = t.log()
    
    # 计算损失 (简单求和)
    loss = y.sum()
    loss.backward()
    
    # log(x) 的导数是 1/x
    expected_grad = 1.0 / x
    np.testing.assert_allclose(t.grad, expected_grad, rtol=1e-6)
    print("✓ log() 反向传播测试通过")


def test_log_backward_with_chain_rule():
    """测试 log() 在链式法则中的反向传播"""
    x = np.array([2.0, 4.0])
    t = Tensor(x, requires_grad=True)
    
    # y = log(x)
    y = t.log()
    
    # z = y^2
    z = y * y
    
    # loss = sum(z)
    loss = z.sum()
    loss.backward()
    
    # d(loss)/dx = d(sum(log(x)^2))/dx = 2 * log(x) / x
    expected_grad = 2 * np.log(x) / x
    np.testing.assert_allclose(t.grad, expected_grad, rtol=1e-5)
    print("✓ log() 链式法则测试通过")


def test_log_numerical_stability():
    """测试 log() 的数值稳定性"""
    # 测试大数值
    x_large = np.array([100.0, 1000.0, 10000.0])
    t_large = Tensor(x_large, requires_grad=True)
    y_large = t_large.log()
    expected_large = np.log(x_large)
    np.testing.assert_allclose(y_large.data, expected_large, rtol=1e-6)
    
    # 反向传播
    y_large.sum().backward()
    expected_grad = 1.0 / x_large
    np.testing.assert_allclose(t_large.grad, expected_grad, rtol=1e-6)
    
    # 测试小数值
    x_small = np.array([0.001, 0.01, 0.1])
    t_small = Tensor(x_small, requires_grad=True)
    y_small = t_small.log()
    expected_small = np.log(x_small)
    np.testing.assert_allclose(y_small.data, expected_small, rtol=1e-6)
    
    y_small.sum().backward()
    expected_grad_small = 1.0 / x_small
    np.testing.assert_allclose(t_small.grad, expected_grad_small, rtol=1e-6)
    
    print("✓ log() 数值稳定性测试通过")


def test_log_multidimensional():
    """测试 log() 对多维张量的支持"""
    x = np.random.rand(2, 3, 4) + 0.1  # 确保 > 0
    t = Tensor(x, requires_grad=True)
    y = t.log()
    
    expected = np.log(x)
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    
    # 测试反向传播
    loss = y.sum()
    loss.backward()
    expected_grad = 1.0 / x
    np.testing.assert_allclose(t.grad, expected_grad, rtol=1e-6)
    
    print("✓ log() 多维张量测试通过")


def test_log_exp_inverse():
    """测试 log() 和 exp() 是反函数"""
    x = np.array([0.5, 1.0, 2.0, 3.0])
    t = Tensor(x, requires_grad=False)
    
    # exp(log(x)) = x
    y = t.log().exp()
    np.testing.assert_allclose(y.data, x, rtol=1e-6)
    
    # log(exp(x)) = x
    t2 = Tensor(x, requires_grad=False)
    y2 = t2.exp().log()
    np.testing.assert_allclose(y2.data, x, rtol=1e-6)
    
    print("✓ log() 和 exp() 互为反函数测试通过")


def test_log10_forward():
    """测试 log10() 前向传播"""
    x = np.array([1.0, 10.0, 100.0, 1000.0])
    t = Tensor(x, requires_grad=False)
    y = t.log10()
    
    expected = np.log10(x)
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ log10() 前向传播测试通过")


def test_log10_backward():
    """测试 log10() 反向传播"""
    x = np.array([1.0, 10.0, 100.0])
    t = Tensor(x, requires_grad=True)
    y = t.log10()
    
    loss = y.sum()
    loss.backward()
    
    # log10(x) 的导数是 1/(x * ln(10))
    expected_grad = 1.0 / (x * np.log(10))
    np.testing.assert_allclose(t.grad, expected_grad, rtol=1e-6)
    print("✓ log10() 反向传播测试通过")


def test_log2_forward():
    """测试 log2() 前向传播"""
    x = np.array([1.0, 2.0, 4.0, 8.0, 16.0])
    t = Tensor(x, requires_grad=False)
    y = t.log2()
    
    expected = np.log2(x)
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ log2() 前向传播测试通过")


def test_log2_backward():
    """测试 log2() 反向传播"""
    x = np.array([1.0, 2.0, 4.0, 8.0])
    t = Tensor(x, requires_grad=True)
    y = t.log2()
    
    loss = y.sum()
    loss.backward()
    
    # log2(x) 的导数是 1/(x * ln(2))
    expected_grad = 1.0 / (x * np.log(2))
    np.testing.assert_allclose(t.grad, expected_grad, rtol=1e-6)
    print("✓ log2() 反向传播测试通过")


# ==================== Sigmoid 测试 ====================

def test_sigmoid_forward():
    """Sigmoid 前向传播测试"""
    x = Tensor([0.0, 1.0, -1.0, 2.0], requires_grad=False)
    y = x.sigmoid()
    
    # sigmoid(0) = 0.5
    # sigmoid(1) ≈ 0.731
    # sigmoid(-1) ≈ 0.269
    expected = 1.0 / (1.0 + np.exp(-x.data))
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ sigmoid() 前向传播测试通过")


def test_sigmoid_backward():
    """Sigmoid 反向传播测试"""
    x = Tensor([0.0, 1.0, 2.0], requires_grad=True)
    y = x.sigmoid()
    y.sum().backward()
    
    # 梯度: d(sigmoid(x))/dx = sigmoid(x) * (1 - sigmoid(x))
    sigmoid_data = 1.0 / (1.0 + np.exp(-x.data))
    expected_grad = sigmoid_data * (1 - sigmoid_data)
    
    np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
    print("✓ sigmoid() 反向传播测试通过")


def test_sigmoid_backward_with_chain_rule():
    """Sigmoid 链式法则测试: d(sigmoid²(x))/dx = 2*sigmoid(x)*(1-sigmoid(x))*sigmoid(x)"""
    x = Tensor([0.5, 1.5], requires_grad=True)
    y = x.sigmoid()
    z = y ** 2
    z.sum().backward()
    
    sigmoid_data = 1.0 / (1.0 + np.exp(-x.data))
    # d(sigmoid²)/dx = 2*sigmoid(x) * d(sigmoid(x))/dx
    expected_grad = 2 * sigmoid_data * sigmoid_data * (1 - sigmoid_data)
    
    np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
    print("✓ sigmoid() 链式法则测试通过")


def test_sigmoid_range():
    """Sigmoid 值域测试: 输出应该在 (0, 1) 之间"""
    x = Tensor(np.linspace(-10, 10, 100), requires_grad=False)
    y = x.sigmoid()
    
    assert np.all(y.data > 0) and np.all(y.data < 1), "sigmoid 输出应该在 (0, 1) 之间"
    print("✓ sigmoid() 值域测试通过")


# ==================== Tanh 测试 ====================

def test_tanh_forward():
    """Tanh 前向传播测试"""
    x = Tensor([0.0, 1.0, -1.0, 2.0], requires_grad=False)
    y = x.tanh()
    
    expected = np.tanh(x.data)
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ tanh() 前向传播测试通过")


def test_tanh_backward():
    """Tanh 反向传播测试"""
    x = Tensor([0.0, 1.0, 2.0], requires_grad=True)
    y = x.tanh()
    y.sum().backward()
    
    # 梯度: d(tanh(x))/dx = 1 - tanh²(x)
    tanh_data = np.tanh(x.data)
    expected_grad = 1 - tanh_data ** 2
    
    np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
    print("✓ tanh() 反向传播测试通过")


def test_tanh_backward_with_chain_rule():
    """Tanh 链式法则测试: d(tanh²(x))/dx"""
    x = Tensor([0.5, 1.5], requires_grad=True)
    y = x.tanh()
    z = y ** 2
    z.sum().backward()
    
    tanh_data = np.tanh(x.data)
    # d(tanh²)/dx = 2*tanh(x) * (1 - tanh²(x))
    expected_grad = 2 * tanh_data * (1 - tanh_data ** 2)
    
    np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
    print("✓ tanh() 链式法则测试通过")


def test_tanh_range():
    """Tanh 值域测试: 输出应该在 (-1, 1) 之间"""
    x = Tensor(np.linspace(-10, 10, 100), requires_grad=False)
    y = x.tanh()
    
    assert np.all(y.data > -1) and np.all(y.data < 1), "tanh 输出应该在 (-1, 1) 之间"
    print("✓ tanh() 值域测试通过")


def test_sigmoid_vs_tanh():
    """Sigmoid 和 Tanh 关系测试: tanh(x) = 2*sigmoid(2x) - 1"""
    x = Tensor(np.random.randn(10), requires_grad=False)
    
    tanh_result = x.tanh().data
    sigmoid_result = (2 * x).sigmoid().data * 2 - 1
    
    np.testing.assert_allclose(tanh_result, sigmoid_result, rtol=1e-6)
    print("✓ sigmoid/tanh 关系测试通过")


# ==================== GELU 测试 ====================

def test_gelu_exact_forward():
    """GELU (精确版) 前向传播测试"""
    x = Tensor([0.0, 1.0, -1.0, 2.0], requires_grad=False)
    y = x.gelu(approximate=False)
    
    # 精确版本: gelu(x) = x * Φ(x) where Φ 是标准高斯 CDF
    from scipy import special
    expected = x.data * 0.5 * (1 + special.erf(x.data / np.sqrt(2)))
    
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ gelu() (精确) 前向传播测试通过")


def test_gelu_approximate_forward():
    """GELU (近似版) 前向传播测试"""
    x = Tensor([0.0, 1.0, -1.0, 2.0], requires_grad=False)
    y = x.gelu(approximate=True)
    
    # 近似版本应该接近精确版本
    from scipy import special
    exact = x.data * 0.5 * (1 + special.erf(x.data / np.sqrt(2)))
    
    # 近似误差应该小于 1%（对于 [-3, 3] 范围内）
    np.testing.assert_allclose(y.data, exact, rtol=0.01, atol=0.01)
    print("✓ gelu() (近似) 前向传播测试通过")


def test_gelu_backward():
    """GELU 反向传播测试"""
    x = Tensor([0.0, 1.0, 2.0], requires_grad=True)
    y = x.gelu(approximate=False)
    y.sum().backward()
    
    # 梯度应该是有限的，不为 NaN
    assert not np.any(np.isnan(x.grad)), "GELU 梯度不应该包含 NaN"
    assert not np.any(np.isinf(x.grad)), "GELU 梯度不应该包含无穷"
    print("✓ gelu() 反向传播测试通过")


def test_gelu_backward_with_chain_rule():
    """GELU 链式法则测试"""
    x = Tensor([0.5, 1.5], requires_grad=True)
    y = x.gelu(approximate=False)
    z = y ** 2
    z.sum().backward()
    
    # 梯度应该是有限的
    assert not np.any(np.isnan(x.grad)), "GELU 链式法则梯度不应该包含 NaN"
    assert not np.any(np.isinf(x.grad)), "GELU 链式法则梯度不应该包含无穷"
    print("✓ gelu() 链式法则测试通过")


def test_gelu_vs_relu():
    """GELU vs ReLU 对比: GELU(x) 应该像平滑的 ReLU"""
    x = Tensor([-2.0, -1.0, 0.0, 1.0, 2.0], requires_grad=False)
    y_gelu = x.gelu().data
    
    # GELU 应该在正值附近接近 x，在负值附近接近 0
    assert np.all(y_gelu[x.data > 0] > 0), "GELU(x>0) 应该为正"
    assert np.all(y_gelu[x.data < 0] < 0), "GELU(x<0) 应该为负"
    # 但不像 ReLU 那样硬截断 - 在 x=1 处，GELU(1) 应该较大
    assert y_gelu[3] > 0.8, "GELU(1) 应该接近 0.84"
    print("✓ gelu() vs relu 对比测试通过")


def test_gelu_multidimensional():
    """GELU 多维张量测试"""
    x = Tensor(np.random.randn(2, 3, 4), requires_grad=True)
    y = x.gelu()
    
    assert y.shape == x.shape, "GELU 输出形状应该与输入相同"
    
    # 反向传播
    y.sum().backward()
    assert x.grad.shape == x.shape, "梯度形状应该与输入相同"
    print("✓ gelu() 多维张量测试通过")


# ==================== 索引与矩阵操作测试 ====================

def test_gather_forward():
    """gather 前向传播测试"""
    x = Tensor([[1, 2, 3], [4, 5, 6]], requires_grad=False)
    index = Tensor([[2, 1], [0, 2]])
    y = x.gather(1, index)
    expected = np.array([[3, 2], [4, 6]])
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ gather() 前向传播测试通过")


def test_gather_backward():
    """gather 反向传播测试"""
    x = Tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], requires_grad=True)
    index = Tensor([[2, 1], [0, 2]])
    y = x.gather(1, index)
    y.sum().backward()
    expected_grad = np.array([[0.0, 1.0, 1.0], [1.0, 0.0, 1.0]])
    np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
    print("✓ gather() 反向传播测试通过")


def test_scatter_forward():
    """scatter 前向传播测试"""
    x = Tensor(np.zeros((2, 4)), requires_grad=False)
    index = Tensor([[0, 2], [1, 3]])
    src = Tensor([[10.0, 20.0], [30.0, 40.0]], requires_grad=False)
    y = x.scatter(1, index, src)
    expected = np.array([[10.0, 0.0, 20.0, 0.0], [0.0, 30.0, 0.0, 40.0]])
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ scatter() 前向传播测试通过")


def test_scatter_backward():
    """scatter 反向传播测试"""
    x = Tensor(np.ones((2, 4)), requires_grad=True)
    index = Tensor([[0, 2], [1, 3]])
    src = Tensor([[10.0, 20.0], [30.0, 40.0]], requires_grad=True)
    y = x.scatter(1, index, src)
    y.sum().backward()

    expected_x_grad = np.array([[0.0, 1.0, 0.0, 1.0], [1.0, 0.0, 1.0, 0.0]])
    expected_src_grad = np.ones((2, 2))
    np.testing.assert_allclose(x.grad, expected_x_grad, rtol=1e-6)
    np.testing.assert_allclose(src.grad, expected_src_grad, rtol=1e-6)
    print("✓ scatter() 反向传播测试通过")


def test_scatter_add_forward_with_repeated_indices():
    """scatter_add 前向测试（重复索引累加）"""
    x = Tensor(np.zeros((2, 5)), requires_grad=False)
    index = Tensor([[1, 1, 3], [0, 0, 4]])
    src = Tensor([[2.0, 3.0, 5.0], [7.0, 11.0, 13.0]], requires_grad=False)

    y = x.scatter_add(1, index, src)

    expected = np.zeros((2, 5))
    expected[0, 1] = 5.0
    expected[0, 3] = 5.0
    expected[1, 0] = 18.0
    expected[1, 4] = 13.0
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ scatter_add() 重复索引累加测试通过")


def test_scatter_add_backward():
    """scatter_add 反向传播测试"""
    x = Tensor(np.ones((2, 4)), requires_grad=True)
    index = Tensor([[0, 2], [1, 3]])
    src = Tensor([[10.0, 20.0], [30.0, 40.0]], requires_grad=True)

    y = x.scatter_add(1, index, src)
    y.sum().backward()

    expected_x_grad = np.ones((2, 4))
    expected_src_grad = np.ones((2, 2))
    np.testing.assert_allclose(x.grad, expected_x_grad, rtol=1e-6)
    np.testing.assert_allclose(src.grad, expected_src_grad, rtol=1e-6)
    print("✓ scatter_add() 反向传播测试通过")


def test_scatter_add_pytorch_alignment_repeated_indices():
    """scatter_add 与 PyTorch 对齐测试（重复索引）"""
    try:
        import torch
    except ImportError:
        pytest.skip("PyTorch 未安装，跳过 scatter_add 对齐测试")

    x_np = np.zeros((2, 5), dtype=np.float64)
    idx_np = np.array([[1, 1, 3], [0, 0, 4]], dtype=np.int64)
    src_np = np.array([[2.0, 3.0, 5.0], [7.0, 11.0, 13.0]], dtype=np.float64)

    x_neurx = Tensor(x_np.copy(), requires_grad=True)
    idx_neurx = Tensor(idx_np)
    src_neurx = Tensor(src_np.copy(), requires_grad=True)
    y_neurx = x_neurx.scatter_add(1, idx_neurx, src_neurx)
    y_neurx.sum().backward()

    x_torch = torch.tensor(x_np, dtype=torch.float64, requires_grad=True)
    idx_torch = torch.tensor(idx_np, dtype=torch.int64)
    src_torch = torch.tensor(src_np, dtype=torch.float64, requires_grad=True)
    y_torch = x_torch.scatter_add(1, idx_torch, src_torch)
    y_torch.sum().backward()

    np.testing.assert_allclose(y_neurx.data, y_torch.detach().numpy(), rtol=1e-6)
    np.testing.assert_allclose(x_neurx.grad, x_torch.grad.numpy(), rtol=1e-6)
    np.testing.assert_allclose(src_neurx.grad, src_torch.grad.numpy(), rtol=1e-6)
    print("✓ scatter_add() 与 PyTorch 对齐测试（重复索引）通过")


def test_scatter_add_pytorch_alignment_negative_indices():
    """scatter_add 与 PyTorch 对齐测试（负索引）"""
    try:
        import torch
    except ImportError:
        pytest.skip("PyTorch 未安装，跳过 scatter_add 对齐测试")

    x_np = np.zeros((2, 4), dtype=np.float64)
    idx_np = np.array([[-1, -2], [-4, -1]], dtype=np.int64)
    src_np = np.array([[1.5, 2.5], [3.5, 4.5]], dtype=np.float64)

    x_neurx = Tensor(x_np.copy(), requires_grad=True)
    idx_neurx = Tensor(idx_np)
    src_neurx = Tensor(src_np.copy(), requires_grad=True)
    y_neurx = x_neurx.scatter_add(1, idx_neurx, src_neurx)
    y_neurx.sum().backward()

    x_torch = torch.tensor(x_np, dtype=torch.float64, requires_grad=True)
    idx_torch = torch.tensor(idx_np, dtype=torch.int64)
    src_torch = torch.tensor(src_np, dtype=torch.float64, requires_grad=True)
    y_torch = x_torch.scatter_add(1, idx_torch, src_torch)
    y_torch.sum().backward()

    np.testing.assert_allclose(y_neurx.data, y_torch.detach().numpy(), rtol=1e-6)
    np.testing.assert_allclose(x_neurx.grad, x_torch.grad.numpy(), rtol=1e-6)
    np.testing.assert_allclose(src_neurx.grad, src_torch.grad.numpy(), rtol=1e-6)
    print("✓ scatter_add() 与 PyTorch 对齐测试（负索引）通过")


def test_scatter_add_error_cases():
    """scatter_add 边界错误测试"""
    x = Tensor(np.zeros((2, 3)), requires_grad=False)
    src = Tensor(np.ones((2, 2)), requires_grad=False)

    with pytest.raises(IndexError):
        x.scatter_add(1, Tensor([[0, 3], [1, 2]]), src)

    with pytest.raises(IndexError):
        x.scatter_add(1, Tensor([[-4, 1], [0, 2]]), src)

    print("✓ scatter_add() 边界错误测试通过")


def test_scatter_add_multidim_dim_minus1_forward():
    """scatter_add 多维 + dim=-1 前向测试"""
    x = Tensor(np.zeros((2, 3, 4)), requires_grad=False)
    index = Tensor(
        np.array(
            [
                [[0, 1], [1, 1], [3, 0]],
                [[2, 2], [0, 3], [1, 1]],
            ]
        )
    )
    src = Tensor(
        np.array(
            [
                [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]],
                [[7.0, 8.0], [9.0, 10.0], [11.0, 12.0]],
            ]
        ),
        requires_grad=False,
    )

    y = x.scatter_add(-1, index, src)

    expected = np.zeros((2, 3, 4))
    expected[0, 0, 0] += 1.0
    expected[0, 0, 1] += 2.0
    expected[0, 1, 1] += 3.0 + 4.0
    expected[0, 2, 3] += 5.0
    expected[0, 2, 0] += 6.0
    expected[1, 0, 2] += 7.0 + 8.0
    expected[1, 1, 0] += 9.0
    expected[1, 1, 3] += 10.0
    expected[1, 2, 1] += 11.0 + 12.0

    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ scatter_add() 多维 dim=-1 前向测试通过")


def test_scatter_add_multidim_dim_minus1_backward():
    """scatter_add 多维 + dim=-1 反向传播测试"""
    x = Tensor(np.ones((2, 3, 4)), requires_grad=True)
    index = Tensor(
        np.array(
            [
                [[0, 1], [1, 1], [3, 0]],
                [[2, 2], [0, 3], [1, 1]],
            ]
        )
    )
    src = Tensor(
        np.array(
            [
                [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]],
                [[7.0, 8.0], [9.0, 10.0], [11.0, 12.0]],
            ]
        ),
        requires_grad=True,
    )

    y = x.scatter_add(-1, index, src)
    y.sum().backward()

    np.testing.assert_allclose(x.grad, np.ones((2, 3, 4)), rtol=1e-6)
    np.testing.assert_allclose(src.grad, np.ones((2, 3, 2)), rtol=1e-6)
    print("✓ scatter_add() 多维 dim=-1 反向传播测试通过")


def test_scatter_add_multidim_dim_minus1_pytorch_alignment():
    """scatter_add 多维 + dim=-1 与 PyTorch 对齐测试"""
    try:
        import torch
    except ImportError:
        pytest.skip("PyTorch 未安装，跳过 scatter_add 多维 dim=-1 对齐测试")

    x_np = np.zeros((2, 3, 4), dtype=np.float64)
    idx_np = np.array(
        [
            [[0, 1], [1, 1], [3, 0]],
            [[2, 2], [0, 3], [1, 1]],
        ],
        dtype=np.int64,
    )
    src_np = np.array(
        [
            [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]],
            [[7.0, 8.0], [9.0, 10.0], [11.0, 12.0]],
        ],
        dtype=np.float64,
    )

    x_neurx = Tensor(x_np.copy(), requires_grad=True)
    idx_neurx = Tensor(idx_np)
    src_neurx = Tensor(src_np.copy(), requires_grad=True)
    y_neurx = x_neurx.scatter_add(-1, idx_neurx, src_neurx)
    y_neurx.sum().backward()

    x_torch = torch.tensor(x_np, dtype=torch.float64, requires_grad=True)
    idx_torch = torch.tensor(idx_np, dtype=torch.int64)
    src_torch = torch.tensor(src_np, dtype=torch.float64, requires_grad=True)
    y_torch = x_torch.scatter_add(-1, idx_torch, src_torch)
    y_torch.sum().backward()

    np.testing.assert_allclose(y_neurx.data, y_torch.detach().numpy(), rtol=1e-6)
    np.testing.assert_allclose(x_neurx.grad, x_torch.grad.numpy(), rtol=1e-6)
    np.testing.assert_allclose(src_neurx.grad, src_torch.grad.numpy(), rtol=1e-6)
    print("✓ scatter_add() 多维 dim=-1 与 PyTorch 对齐测试通过")


def test_index_select_forward_and_backward():
    """index_select 前后向测试"""
    x = Tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], requires_grad=True)
    idx = Tensor([2, 0])
    y = x.index_select(1, idx)
    expected = np.array([[3.0, 1.0], [6.0, 4.0]])
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)

    y.sum().backward()
    expected_grad = np.array([[1.0, 0.0, 1.0], [1.0, 0.0, 1.0]])
    np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
    print("✓ index_select() 前后向测试通过")


def test_index_select_negative_dim():
    """index_select 负维度测试"""
    x = Tensor([[1, 2, 3], [4, 5, 6]], requires_grad=False)
    idx = Tensor([1, 2])
    y = x.index_select(-1, idx)
    expected = np.array([[2, 3], [5, 6]])
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)
    print("✓ index_select() 负维度测试通过")


def test_tril_triu_forward_backward():
    """tril/triu 前后向测试"""
    x_np = np.arange(1, 10, dtype=np.float64).reshape(3, 3)

    x1 = Tensor(x_np.copy(), requires_grad=True)
    y1 = x1.tril()
    np.testing.assert_allclose(y1.data, np.tril(x_np), rtol=1e-6)
    y1.sum().backward()
    np.testing.assert_allclose(x1.grad, np.tril(np.ones_like(x_np)), rtol=1e-6)

    x2 = Tensor(x_np.copy(), requires_grad=True)
    y2 = x2.triu(1)
    np.testing.assert_allclose(y2.data, np.triu(x_np, 1), rtol=1e-6)
    y2.sum().backward()
    np.testing.assert_allclose(x2.grad, np.triu(np.ones_like(x_np), 1), rtol=1e-6)
    print("✓ tril()/triu() 前后向测试通过")


def test_norm_forward_and_backward():
    """norm 前后向测试"""
    x_np = np.array([[3.0, 4.0], [0.0, 5.0]])
    x = Tensor(x_np.copy(), requires_grad=True)

    y = x.norm(p=2, axis=1)
    expected = np.array([5.0, 5.0])
    np.testing.assert_allclose(y.data, expected, rtol=1e-6)

    y.sum().backward()
    expected_grad = np.array([[3.0 / 5.0, 4.0 / 5.0], [0.0, 1.0]])
    np.testing.assert_allclose(x.grad, expected_grad, rtol=1e-6)
    print("✓ norm() 前后向测试通过")


def test_norm_p1_and_inf():
    """norm p=1 和 p=inf 测试"""
    x_np = np.array([[1.0, -2.0, 3.0], [4.0, -5.0, 6.0]])
    x = Tensor(x_np, requires_grad=False)

    y1 = x.norm(p=1, axis=1)
    np.testing.assert_allclose(y1.data, np.array([6.0, 15.0]), rtol=1e-6)

    yinf = x.norm(p=np.inf, axis=1)
    np.testing.assert_allclose(yinf.data, np.array([3.0, 6.0]), rtol=1e-6)
    print("✓ norm() p=1/p=inf 测试通过")


def test_index_ops_error_cases():
    """索引操作异常分支测试"""
    x = Tensor(np.zeros((2, 3)), requires_grad=False)

    with pytest.raises(IndexError):
        x.index_select(3, Tensor([0]))

    with pytest.raises(ValueError):
        x.index_select(1, Tensor([[0, 1]]))

    with pytest.raises(IndexError):
        x.gather(1, Tensor([[3, 0, 1], [0, 1, 2]]))

    print("✓ 索引操作异常分支测试通过")


# ==================== 数值梯度验证 ====================

def numerical_gradient(func, x, eps=1e-5):
    """
    计算数值梯度用于验证自动微分
    
    Args:
        func: 接受 numpy 数组并返回标量的函数
        x: 输入数组
        eps: 微分步长
    
    Returns:
        数值梯度
    """
    grad = np.zeros_like(x)
    it = np.nditer(x, flags=['multi_index'], op_flags=['readwrite'])
    
    while not it.finished:
        idx = it.multi_index
        old_value = x[idx]
        
        x[idx] = old_value + eps
        fxh_plus = func(x)
        
        x[idx] = old_value - eps
        fxh_minus = func(x)
        
        grad[idx] = (fxh_plus - fxh_minus) / (2 * eps)
        x[idx] = old_value
        it.iternext()
    
    return grad


def test_exp_numerical_gradient():
    """使用数值梯度验证 exp() 的自动微分"""
    x_np = np.random.randn(3, 4)
    
    # 定义函数: f(x) = sum(exp(x))
    def func(x):
        return np.exp(x).sum()
    
    # 数值梯度
    numerical_grad = numerical_gradient(func, x_np.copy())
    
    # 自动微分梯度
    x_neurx = Tensor(x_np.copy(), requires_grad=True)
    y = x_neurx.exp()
    y.sum().backward()
    
    # 比较
    np.testing.assert_allclose(x_neurx.grad, numerical_grad, rtol=1e-4, atol=1e-6)
    print("✓ exp() 数值梯度验证通过")


# ==================== 性能基准测试 ====================

def test_exp_performance():
    """测试 exp() 的性能"""
    import time
    
    x_np = np.random.randn(1000, 1000)
    
    # 前向传播
    x_neurx = Tensor(x_np.copy(), requires_grad=False)
    start = time.time()
    for _ in range(10):
        y = x_neurx.exp()
    forward_time = time.time() - start
    
    # 后向传播
    x_neurx = Tensor(x_np.copy(), requires_grad=True)
    start = time.time()
    for _ in range(10):
        y = x_neurx.exp()
        y.sum().backward()
        # 重新创建张量而不是清除梯度
        x_neurx = Tensor(x_np.copy(), requires_grad=True)
    backward_time = time.time() - start
    
    print(f"✓ exp() 性能测试:")
    print(f"  前向传播 (10次): {forward_time:.4f}s")
    print(f"  前向+反向 (10次): {backward_time:.4f}s")
    
    # 确保性能合理 (不应该太慢)
    assert forward_time < 1.0, "前向传播太慢"
    assert backward_time < 2.0, "反向传播太慢"


if __name__ == "__main__":
    print("=" * 60)
    print("测试 Phase 1 数学函数: exp(), log(), log10(), log2(), sigmoid(), tanh(), gelu()")
    print("=" * 60)
    
    print("\n--- exp() 测试 ---")
    test_exp_forward()
    test_exp_backward()
    test_exp_backward_with_chain_rule()
    test_exp_numerical_stability()
    test_exp_multidimensional()
    test_exp_zero_grad()
    test_exp_pytorch_compatibility()
    test_exp_numerical_gradient()
    test_exp_performance()
    
    print("\n--- log() 测试 ---")
    test_log_forward()
    test_log_backward()
    test_log_backward_with_chain_rule()
    test_log_numerical_stability()
    test_log_multidimensional()
    test_log_exp_inverse()
    test_log10_forward()
    test_log10_backward()
    test_log2_forward()
    test_log2_backward()
    
    print("\n--- sigmoid() 测试 ---")
    test_sigmoid_forward()
    test_sigmoid_backward()
    test_sigmoid_backward_with_chain_rule()
    test_sigmoid_range()
    
    print("\n--- tanh() 测试 ---")
    test_tanh_forward()
    test_tanh_backward()
    test_tanh_backward_with_chain_rule()
    test_tanh_range()
    test_sigmoid_vs_tanh()
    
    print("\n--- gelu() 测试 ---")
    test_gelu_exact_forward()
    test_gelu_approximate_forward()
    test_gelu_backward()
    test_gelu_backward_with_chain_rule()
    test_gelu_vs_relu()
    test_gelu_multidimensional()

    print("\n--- 索引与矩阵操作测试 ---")
    test_gather_forward()
    test_gather_backward()
    test_scatter_forward()
    test_scatter_backward()
    test_scatter_add_forward_with_repeated_indices()
    test_scatter_add_backward()
    test_scatter_add_pytorch_alignment_repeated_indices()
    test_scatter_add_pytorch_alignment_negative_indices()
    test_scatter_add_error_cases()
    test_scatter_add_multidim_dim_minus1_forward()
    test_scatter_add_multidim_dim_minus1_backward()
    test_scatter_add_multidim_dim_minus1_pytorch_alignment()
    test_index_select_forward_and_backward()
    test_index_select_negative_dim()
    test_tril_triu_forward_backward()
    test_norm_forward_and_backward()
    test_norm_p1_and_inf()
    test_index_ops_error_cases()
    
    print("\n" + "=" * 60)
    print("✅ 所有测试通过!")
    print("=" * 60)
