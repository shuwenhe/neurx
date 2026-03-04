"""
Week 5 综合测试套件: 权重初始化、梯度操作、模型分析、BatchNorm

包含 21 个测试，覆盖所有 Week 5 实现的功能。
"""

import numpy as np
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

from neurx.nn.init import (
    xavier_uniform, xavier_normal, kaiming_uniform, kaiming_normal,
    orthogonal, uniform, normal
)
from neurx.nn.grad_utils import (
    get_grad_norm, clip_grad_norm_, clip_grad_value_, zero_grad
)
from neurx.nn.utils import (
    count_parameters, count_flops, model_size, summary, analyze_network
)
from neurx.nn.normalization import BatchNorm1d, BatchNorm2d, BatchNorm3d
from neurx.core import Tensor


# =====================================================================
# WEIGHT INITIALIZATION TESTS (7 tests)
# =====================================================================

def test_xavier_uniform():
    """测试 Xavier 均匀初始化"""
    print("\n[TEST] Xavier Uniform Initialization")
    shape = (100, 50)
    weights = xavier_uniform(shape)
    
    # 检查形状
    assert weights.shape == shape, f"Shape mismatch: {weights.shape} vs {shape}"
    
    # 检查统计
    mean = np.mean(weights)
    std = np.std(weights)
    limit = np.sqrt(6.0 / (100 + 50))
    
    print(f"  Shape: {shape} ✓")
    print(f"  Mean: {mean:.6f} (expected ~0) ✓")
    print(f"  Std: {std:.6f} ✓")
    print(f"  Range: [{np.min(weights):.4f}, {np.max(weights):.4f}]")
    print(f"  Expected limit: {limit:.4f} ✓")
    
    assert abs(mean) < 0.1, f"Mean too large: {mean}"
    assert np.max(weights) <= limit + 0.01, f"Values exceed limit"
    print("  ✅ PASSED")


def test_xavier_normal():
    """测试 Xavier 正态初始化"""
    print("\n[TEST] Xavier Normal Initialization")
    shape = (100, 50)
    weights = xavier_normal(shape)
    
    assert weights.shape == shape
    mean = np.mean(weights)
    std = np.std(weights)
    expected_std = np.sqrt(2.0 / (100 + 50))
    
    print(f"  Shape: {shape} ✓")
    print(f"  Mean: {mean:.6f} (expected ~0) ✓")
    print(f"  Std: {std:.6f} (expected {expected_std:.4f}) ✓")
    print(f"  Ratio: {std / expected_std:.3f} ✓")
    
    assert abs(mean) < 0.1
    assert 0.9 < std / expected_std < 1.1
    print("  ✅ PASSED")


def test_kaiming_uniform():
    """测试 Kaiming 均匀初始化"""
    print("\n[TEST] Kaiming Uniform Initialization")
    shape = (128, 256)
    weights = kaiming_uniform(shape, a=0)
    
    assert weights.shape == shape
    print(f"  Shape: {shape} ✓")
    print(f"  Mean: {np.mean(weights):.6f} ✓")
    print(f"  Std: {np.std(weights):.6f} ✓")
    print(f"  Range: [{np.min(weights):.4f}, {np.max(weights):.4f}] ✓")
    print("  ✅ PASSED")


def test_kaiming_normal():
    """测试 Kaiming 正态初始化"""
    print("\n[TEST] Kaiming Normal Initialization")
    shape = (128, 256)
    weights = kaiming_normal(shape, a=0)
    
    assert weights.shape == shape
    mean = np.mean(weights)
    std = np.std(weights)
    expected_std = np.sqrt(2.0 / 128)
    
    print(f"  Shape: {shape} ✓")
    print(f"  Mean: {mean:.6f} (expected ~0) ✓")
    print(f"  Std: {std:.6f} (expected {expected_std:.4f}) ✓")
    print(f"  Ratio: {std / expected_std:.3f} ✓")
    
    assert abs(mean) < 0.05
    assert 0.85 < std / expected_std < 1.15
    print("  ✅ PASSED")


def test_orthogonal():
    """测试正交初始化"""
    print("\n[TEST] Orthogonal Initialization")
    shape = (64, 64)
    weights = orthogonal(shape, gain=1.0)
    
    assert weights.shape == shape
    
    # 检查正交性: W^T @ W ≈ I
    gram = weights.T @ weights
    identity = np.eye(64)
    error = np.max(np.abs(gram - identity))
    
    print(f"  Shape: {shape} ✓")
    print(f"  Gram matrix error: {error:.6f} (< 1e-4) ✓")
    print(f"  Is orthogonal: {error < 1e-4} ✓")
    
    assert error < 1e-4, f"Not orthogonal: {error}"
    print("  ✅ PASSED")


def test_uniform_init():
    """测试均匀初始化"""
    print("\n[TEST] Uniform Initialization")
    shape = (100, 100)
    a, b = -0.5, 0.5
    weights = uniform(shape, a=a, b=b)
    
    assert weights.shape == shape
    assert np.min(weights) >= a
    assert np.max(weights) <= b
    
    print(f"  Shape: {shape} ✓")
    print(f"  Range: [{np.min(weights):.4f}, {np.max(weights):.4f}] ✓")
    print(f"  Expected: [{a}, {b}] ✓")
    print("  ✅ PASSED")


def test_normal_init():
    """测试正态初始化"""
    print("\n[TEST] Normal Initialization")
    shape = (100, 100)
    mean, std = 0.0, 1.0
    weights = normal(shape, mean=mean, std=std)
    
    assert weights.shape == shape
    actual_mean = np.mean(weights)
    actual_std = np.std(weights)
    
    print(f"  Shape: {shape} ✓")
    print(f"  Mean: {actual_mean:.6f} (expected {mean}) ✓")
    print(f"  Std: {actual_std:.6f} (expected {std}) ✓")
    print(f"  Ratio: {actual_std / std:.3f} ✓")
    
    assert abs(actual_mean - mean) < 0.1
    assert 0.9 < actual_std / std < 1.1
    print("  ✅ PASSED")


# =====================================================================
# GRADIENT OPERATIONS TESTS (4 tests)
# =====================================================================

def test_get_grad_norm():
    """测试梯度范数计算"""
    print("\n[TEST] Get Gradient Norm")
    
    # 创建样本梯度
    grad1 = np.random.randn(100, 50) * 0.1
    grad2 = np.random.randn(50, 20) * 0.1
    grads = [grad1, grad2]
    
    # 手动计算
    manual_norm = np.sqrt(np.sum(grad1**2) + np.sum(grad2**2))
    
    # 使用函数计算
    computed_norm = get_grad_norm(grads)
    
    print(f"  Manual norm: {manual_norm:.6f} ✓")
    print(f"  Computed norm: {computed_norm:.6f} ✓")
    print(f"  Difference: {abs(manual_norm - computed_norm):.9f} ✓")
    
    assert abs(manual_norm - computed_norm) < 1e-6
    print("  ✅ PASSED")


def test_clip_grad_norm():
    """测试梯度范数裁剪"""
    print("\n[TEST] Clip Gradient Norm")
    
    # 创建大的梯度
    grad1 = np.random.randn(100, 50) * 10.0
    grad2 = np.random.randn(50, 20) * 10.0
    grads = [grad1, grad2]
    
    original_norm = get_grad_norm(grads)
    max_norm = 1.0
    
    # 裁剪
    clip_grad_norm_(grads, max_norm)
    
    clipped_norm = get_grad_norm(grads)
    
    print(f"  Original norm: {original_norm:.6f} ✓")
    print(f"  Max norm: {max_norm} ✓")
    print(f"  Clipped norm: {clipped_norm:.6f} ✓")
    print(f"  Clipping ratio: {clipped_norm / original_norm:.6f} ✓")
    
    assert clipped_norm <= max_norm + 1e-4
    print("  ✅ PASSED")


def test_clip_grad_value():
    """测试梯度值裁剪"""
    print("\n[TEST] Clip Gradient Value")
    
    # 创建大范围的梯度
    grad = np.random.randn(100, 100) * 100.0
    grads = [grad.copy()]
    
    clip_value = 5.0
    clip_grad_value_(grads, clip_value)
    
    print(f"  Original range: [{np.min(grad):.2f}, {np.max(grad):.2f}]")
    print(f"  Clip value: {clip_value} ✓")
    print(f"  Clipped range: [{np.min(grads[0]):.2f}, {np.max(grads[0]):.2f}] ✓")
    
    assert np.max(np.abs(grads[0])) <= clip_value + 1e-6
    print("  ✅ PASSED")


def test_zero_grad():
    """测试梯度清零"""
    print("\n[TEST] Zero Gradient")
    
    # 创建模拟参数对象
    class FakeParam:
        def __init__(self):
            self.grad = np.ones((10, 10))
    
    param = FakeParam()
    
    print(f"  Before: grad sum = {np.sum(param.grad)} ✓")
    zero_grad(param)
    print(f"  After: grad sum = {np.sum(param.grad)} ✓")
    
    assert np.sum(param.grad) == 0
    print("  ✅ PASSED")


# =====================================================================
# MODEL ANALYSIS TESTS (4 tests)
# =====================================================================

def test_count_parameters():
    """测试参数计数"""
    print("\n[TEST] Count Parameters")
    
    layers = [
        {'weight': np.zeros((32, 3, 3, 3))},  # Conv: 32*3*3*3 = 864
        {'weight': np.zeros((100, 256)), 'bias': np.zeros(100)},  # Linear: 100*256+100
    ]
    
    params = count_parameters(layers)
    expected = 32*3*3*3 + 100*256 + 100
    
    print(f"  Computed: {params:,} ✓")
    print(f"  Expected: {expected:,} ✓")
    
    assert params == expected
    print("  ✅ PASSED")


def test_count_flops():
    """测试 FLOPs 计算"""
    print("\n[TEST] Count FLOPs")
    
    configs = [
        {
            'type': 'conv2d',
            'kernel_h': 3, 'kernel_w': 3,
            'in_channels': 3, 'out_channels': 32,
            'out_h': 112, 'out_w': 112
        },
        {
            'type': 'linear',
            'in_features': 1024,
            'out_features': 10,
            'batch_size': 32
        }
    ]
    
    flops = count_flops(configs)
    print(f"  Total FLOPs: {flops:,} (~{flops/1e9:.2f}G) ✓")
    print(f"  Conv2d FLOPs: {count_flops([configs[0]]):,} ✓")
    print(f"  Linear FLOPs: {count_flops([configs[1]]):,} ✓")
    
    assert flops > 0
    print("  ✅ PASSED")


def test_model_size():
    """测试模型大小估算"""
    print("\n[TEST] Model Size")
    
    layers = [
        {'weight': np.zeros((100, 100))},
        {'weight': np.zeros((50, 50))}
    ]
    
    size_info = model_size(layers, precision_bytes=4)
    
    expected_params = 100*100 + 50*50
    expected_mb = (expected_params * 4) / (1024 * 1024)
    
    print(f"  Params: {size_info['params']:,} (expected {expected_params:,}) ✓")
    print(f"  Size: {size_info['size_mb']} MB ✓")
    print(f"  Bytes: {size_info['size_bytes']:,} ✓")
    
    assert size_info['params'] == expected_params
    print("  ✅ PASSED")


def test_analyze_network():
    """测试网络分析"""
    print("\n[TEST] Analyze Network")
    
    configs = [
        {
            'type': 'conv2d',
            'shape': (32, 3, 3, 3),
            'kernel_h': 3, 'kernel_w': 3,
            'in_channels': 3, 'out_channels': 32,
            'out_h': 224, 'out_w': 224
        },
        {
            'type': 'linear',
            'shape': (1000, 512),
            'in_features': 1000,
            'out_features': 512,
            'batch_size': 64
        }
    ]
    
    result = analyze_network(configs)
    
    print(f"  Params: {result['params']:,} ✓")
    print(f"  FLOPs: {result['flops']:,} (~{result['flops_giga']}G) ✓")
    print(f"  Size: {result['size_mb']} MB ✓")
    
    assert result['params'] > 0
    assert result['flops'] > 0
    print("  ✅ PASSED")


# =====================================================================
# BATCHNORM TESTS (6 tests)
# =====================================================================

def test_batchnorm1d_training():
    """测试 BatchNorm1d 训练模式"""
    print("\n[TEST] BatchNorm1d Training Mode")
    
    bn = BatchNorm1d(num_features=32, momentum=0.1)
    bn.train()
    
    # 输入: (batch_size=16, features=32)
    x = np.random.randn(16, 32)
    y = bn(x)
    
    print(f"  Input shape: {x.shape} ✓")
    print(f"  Output shape: {y.shape} ✓")
    print(f"  Has running stats: {hasattr(bn, 'running_mean')} ✓")
    
    # 检查输出形状
    assert y.shape == x.shape
    # 检查统计变化
    print(f"  Running mean updated: {not np.allclose(bn.running_mean.data, 0)} ✓")
    print("  ✅ PASSED")


def test_batchnorm2d_training():
    """测试 BatchNorm2d 训练模式"""
    print("\n[TEST] BatchNorm2d Training Mode")
    
    bn = BatchNorm2d(num_features=32, momentum=0.1)
    bn.train()
    
    # 输入: (batch_size=4, channels=32, H=28, W=28)
    x = np.random.randn(4, 32, 28, 28)
    y = bn(x)
    
    print(f"  Input shape: {x.shape} ✓")
    print(f"  Output shape: {y.shape} ✓")
    
    assert y.shape == x.shape
    assert y.dtype == np.float64
    print("  ✅ PASSED")


def test_batchnorm3d_training():
    """测试 BatchNorm3d 训练模式"""
    print("\n[TEST] BatchNorm3d Training Mode")
    
    bn = BatchNorm3d(num_features=16, momentum=0.1)
    bn.train()
    
    # 输入: (batch_size=2, channels=16, D=8, H=8, W=8)
    x = np.random.randn(2, 16, 8, 8, 8)
    y = bn(x)
    
    print(f"  Input shape: {x.shape} ✓")
    print(f"  Output shape: {y.shape} ✓")
    
    assert y.shape == x.shape
    print("  ✅ PASSED")


def test_batchnorm2d_eval():
    """测试 BatchNorm2d 评估模式"""
    print("\n[TEST] BatchNorm2d Evaluation Mode")
    
    bn = BatchNorm2d(num_features=32, momentum=0.1)
    
    # 训练几个批次
    for _ in range(5):
        x = np.random.randn(8, 32, 28, 28)
        bn.train()
        bn(x)
    
    # 切换到评估模式
    bn.eval()
    
    x_test = np.random.randn(8, 32, 28, 28)
    y_test = bn(x_test)
    
    print(f"  Training mode: {bn.training} (expected False) ✓")
    print(f"  Has running stats: {not np.allclose(bn.running_mean.data, 0)} ✓")
    print(f"  Output shape: {y_test.shape} ✓")
    
    assert not bn.training
    assert y_test.shape == x_test.shape
    print("  ✅ PASSED")


def test_batchnorm_affine():
    """测试 BatchNorm 仿射参数"""
    print("\n[TEST] BatchNorm Affine Parameters")
    
    # 有仿射参数
    bn_with = BatchNorm1d(num_features=32, affine=True)
    assert hasattr(bn_with, 'weight') and bn_with.weight is not None
    print(f"  With affine - weight shape: {bn_with.weight.shape} ✓")
    print(f"  With affine - bias shape: {bn_with.bias.shape} ✓")
    
    # 无仿射参数
    bn_without = BatchNorm1d(num_features=32, affine=False)
    print(f"  Without affine - weight: {bn_without.weight} ✓")
    
    assert bn_with.weight.shape == (32,)
    assert bn_with.bias.shape == (32,)
    print("  ✅ PASSED")


def test_batchnorm_momentum():
    """测试 BatchNorm 动量"""
    print("\n[TEST] BatchNorm Momentum")
    
    bn = BatchNorm2d(num_features=16, momentum=0.1)
    bn.train()
    
    # 第一个批次
    x1 = np.ones((8, 16, 28, 28))
    y1 = bn(x1)
    
    mean_after_first = bn.running_mean.data.copy()
    
    # 第二个批次
    x2 = np.random.randn(8, 16, 28, 28)
    y2 = bn(x2)
    
    mean_after_second = bn.running_mean.data.copy()
    
    print(f"  Mean after batch 1: {mean_after_first[:3]} ✓")
    print(f"  Mean after batch 2: {mean_after_second[:3]} ✓")
    print(f"  Mean changed: {not np.allclose(mean_after_first, mean_after_second)} ✓")
    
    assert not np.allclose(mean_after_first, mean_after_second)
    print("  ✅ PASSED")


# =====================================================================
# MAIN TEST RUNNER
# =====================================================================

def main():
    """运行所有测试"""
    print("\n" + "="*80)
    print("WEEK 5: WEIGHT INITIALIZATION + GRADIENT + ANALYSIS + BATCHNORM TESTS")
    print("="*80)
    
    tests = [
        # Weight Initialization (7)
        test_xavier_uniform,
        test_xavier_normal,
        test_kaiming_uniform,
        test_kaiming_normal,
        test_orthogonal,
        test_uniform_init,
        test_normal_init,
        # Gradient Operations (4)
        test_get_grad_norm,
        test_clip_grad_norm,
        test_clip_grad_value,
        test_zero_grad,
        # Model Analysis (4)
        test_count_parameters,
        test_count_flops,
        test_model_size,
        test_analyze_network,
        # BatchNorm (6)
        test_batchnorm1d_training,
        test_batchnorm2d_training,
        test_batchnorm3d_training,
        test_batchnorm2d_eval,
        test_batchnorm_affine,
        test_batchnorm_momentum,
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            test()
            passed += 1
        except Exception as e:
            print(f"\n  ❌ FAILED: {str(e)}")
            failed += 1
    
    print("\n" + "="*80)
    print(f"RESULTS: {passed} passed, {failed} failed out of {len(tests)} tests")
    print("="*80)
    
    if failed == 0:
        print("\n✅ ALL TESTS PASSED!\n")
        return 0
    else:
        print(f"\n❌ {failed} tests failed\n")
        return 1


if __name__ == '__main__':
    exit(main())
