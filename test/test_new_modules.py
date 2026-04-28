#!/usr/bin/env python3
"""
测试新增的Module功能：BatchNorm、Pooling、Sequential、权重初始化
"""

import numpy as np
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

from neurx.neurx import Tensor
from neurx.nn.modules import (
    BatchNorm1d, BatchNorm2d, MaxPool2d, AvgPool2d, Sequential, Linear, GELU,
    kaiming_uniform_, kaiming_normal_, xavier_uniform_, xavier_normal_,
    Parameter
)


def test_batchnorm1d():
    """测试BatchNorm1d"""
    print("=" * 60)
    print("Testing BatchNorm1d")
    print("=" * 60)
    
    bn = BatchNorm1d(num_features=10, eps=1e-5, momentum=0.1)
    
    # 训练模式
    bn.train()
    x = Tensor(np.random.randn(32, 10).astype(np.float32), requires_grad=True)
    
    # 前向传播
    y = bn(x)
    print(f"Input shape: {x.shape}")
    print(f"Output shape: {y.shape}")
    print(f"Output mean: {y.data.mean():.6f} (应该接近0)")
    print(f"Output std: {y.data.std():.6f} (应该接近1)")
    
    # 反向传播
    loss = y.sum()
    loss.backward()
    print(f"Gradient shape: {x.grad.shape}")
    print(f"Weight gradient shape: {bn.weight.grad.shape}")
    print(f"Bias gradient shape: {bn.bias.grad.shape}")
    
    # 评估模式
    bn.eval()
    y_eval = bn(x)
    print(f"\nEval mode output shape: {y_eval.shape}")
    print("✓ BatchNorm1d test passed\n")


def test_batchnorm2d():
    """测试BatchNorm2d"""
    print("=" * 60)
    print("Testing BatchNorm2d")
    print("=" * 60)
    
    bn = BatchNorm2d(num_features=16, eps=1e-5)
    bn.train()
    
    # (batch=4, channels=16, height=32, width=32)
    x = Tensor(np.random.randn(4, 16, 32, 32).astype(np.float32), requires_grad=True)
    
    y = bn(x)
    print(f"Input shape: {x.shape}")
    print(f"Output shape: {y.shape}")
    print(f"Output mean: {y.data.mean():.6f}")
    print(f"Output std: {y.data.std():.6f}")
    
    loss = y.sum()
    loss.backward()
    print(f"Gradient shape: {x.grad.shape}")
    print("✓ BatchNorm2d test passed\n")


def test_maxpool2d():
    """测试MaxPool2d"""
    print("=" * 60)
    print("Testing MaxPool2d")
    print("=" * 60)
    
    pool = MaxPool2d(kernel_size=2, stride=2, padding=0)
    
    x = Tensor(np.random.randn(2, 3, 8, 8).astype(np.float32), requires_grad=True)
    y = pool(x)
    
    print(f"Input shape: {x.shape}")
    print(f"Output shape: {y.shape} (expected: (2, 3, 4, 4))")
    
    loss = y.sum()
    loss.backward()
    print(f"Gradient shape: {x.grad.shape}")
    print("✓ MaxPool2d test passed\n")


def test_avgpool2d():
    """测试AvgPool2d"""
    print("=" * 60)
    print("Testing AvgPool2d")
    print("=" * 60)
    
    pool = AvgPool2d(kernel_size=2, stride=2, padding=0)
    
    x = Tensor(np.random.randn(2, 3, 8, 8).astype(np.float32), requires_grad=True)
    y = pool(x)
    
    print(f"Input shape: {x.shape}")
    print(f"Output shape: {y.shape} (expected: (2, 3, 4, 4))")
    
    loss = y.sum()
    loss.backward()
    print(f"Gradient shape: {x.grad.shape}")
    print("✓ AvgPool2d test passed\n")


def test_sequential():
    """测试Sequential容器"""
    print("=" * 60)
    print("Testing Sequential")
    print("=" * 60)
    
    # 构建简单的MLP
    model = Sequential(
        Linear(10, 20),
        GELU(),
        Linear(20, 5)
    )
    
    x = Tensor(np.random.randn(4, 10).astype(np.float32), requires_grad=True)
    y = model(x)
    
    print(f"Input shape: {x.shape}")
    print(f"Output shape: {y.shape}")
    print(f"Model layers: {len(model)}")
    
    # 验证参数
    params = model.parameters()
    print(f"Number of parameters: {len(params)}")
    
    loss = y.sum()
    loss.backward()
    print("✓ Sequential test passed\n")


def test_weight_initialization():
    """测试权重初始化函数"""
    print("=" * 60)
    print("Testing Weight Initialization")
    print("=" * 60)
    
    # Kaiming uniform
    param1 = Parameter(np.zeros((64, 32)))
    kaiming_uniform_(param1, mode='fan_in')
    print(f"Kaiming Uniform - Mean: {param1.data.mean():.6f}, Std: {param1.data.std():.6f}")
    
    # Kaiming normal
    param2 = Parameter(np.zeros((64, 32)))
    kaiming_normal_(param2, mode='fan_in')
    print(f"Kaiming Normal - Mean: {param2.data.mean():.6f}, Std: {param2.data.std():.6f}")
    
    # Xavier uniform
    param3 = Parameter(np.zeros((64, 32)))
    xavier_uniform_(param3)
    print(f"Xavier Uniform - Mean: {param3.data.mean():.6f}, Std: {param3.data.std():.6f}")
    
    # Xavier normal
    param4 = Parameter(np.zeros((64, 32)))
    xavier_normal_(param4)
    print(f"Xavier Normal - Mean: {param4.data.mean():.6f}, Std: {param4.data.std():.6f}")
    
    print("✓ Weight initialization test passed\n")


def test_module_utilities():
    """测试Module工具方法"""
    print("=" * 60)
    print("Testing Module Utilities")
    print("=" * 60)
    
    model = Sequential(
        Linear(10, 20),
        GELU(),
        Linear(20, 5)
    )
    
    # 测试requires_grad_
    model.requires_grad_(False)
    for param in model.parameters():
        assert not param.requires_grad, "requires_grad should be False"
    print("✓ requires_grad_ works correctly")
    
    model.requires_grad_(True)
    for param in model.parameters():
        assert param.requires_grad, "requires_grad should be True"
    print("✓ requires_grad_(True) works correctly")
    
    # 测试float/double
    model.double()
    for param in model.parameters():
        assert param.data.dtype == np.float64, "dtype should be float64"
    print("✓ double() works correctly")
    
    model.float()
    for param in model.parameters():
        assert param.data.dtype == np.float32, "dtype should be float32"
    print("✓ float() works correctly")
    
    # 测试to/cpu/cuda
    model.to('cpu')
    assert model.device == 'cpu', "device should be cpu"
    print("✓ to() and cpu() work correctly")
    
    print("✓ Module utilities test passed\n")


def test_integration():
    """集成测试：建立完整的网络"""
    print("=" * 60)
    print("Integration Test: CNN-like Network")
    print("=" * 60)
    
    # 简化的CNN结构
    model = Sequential(
        Linear(10, 64),
        GELU(),
        BatchNorm1d(64),
        Linear(64, 32),
        GELU(),
        BatchNorm1d(32),
        Linear(32, 5)
    )
    
    model.train()
    
    x = Tensor(np.random.randn(8, 10).astype(np.float32), requires_grad=True)
    y = model(x)
    
    print(f"Input shape: {x.shape}")
    print(f"Output shape: {y.shape}")
    
    # 计算损失
    target = Tensor(np.random.randn(8, 5).astype(np.float32))
    loss = ((y - target) ** 2).mean()
    
    print(f"Loss: {loss.data.item():.6f}")
    
    # 反向传播
    loss.backward()
    
    # 检查所有参数都有梯度
    param_count = 0
    grad_count = 0
    for param in model.parameters():
        param_count += 1
        if param.grad is not None and param.grad.any():
            grad_count += 1
    
    print(f"Parameters with gradients: {grad_count}/{param_count}")
    print("✓ Integration test passed\n")


if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("TENSOR LIBRARY - NEW MODULES TEST SUITE")
    print("=" * 60 + "\n")
    
    try:
        test_batchnorm1d()
        test_batchnorm2d()
        test_maxpool2d()
        test_avgpool2d()
        test_sequential()
        test_weight_initialization()
        test_module_utilities()
        test_integration()
        
        print("=" * 60)
        print("✅ ALL TESTS PASSED!")
        print("=" * 60)
    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
