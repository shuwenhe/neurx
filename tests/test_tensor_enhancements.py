"""
neurx Tensor 增强功能测试套件

测试新增的 PyTorch 兼容 API
"""

import numpy as np
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

import neurx
from neurx.enhancements import add_tensor_enhancements


def test_clone_and_detach():
    """测试 clone() 和 detach() 方法"""
    print("Testing clone() and detach()...")
    
    # 测试 clone
    x = neurx.randn(2, 3, requires_grad=True)
    x_clone = x.clone()
    assert x_clone.shape == x.shape
    assert np.allclose(x_clone.data, x.data)
    assert x_clone.requires_grad == x.requires_grad
    
    # 修改 clone 不应该影响原始张量
    x_clone.data[0, 0] = 999
    assert x.data[0, 0] != 999
    
    # 测试 detach
    x_detach = x.detach()
    assert x_detach.requires_grad == False
    assert np.allclose(x_detach.data, x.data)
    
    print("  ✓ clone() and detach() work correctly")


def test_to_device():
    """测试 to() 方法"""
    print("Testing to() device movement...")
    
    x = neurx.randn(2, 3)
    assert x.device == "cpu"
    
    # CPU 转 CPU 应该返回相同对象
    x_cpu = x.to("cpu")
    assert x_cpu.device == "cpu"
    
    print("  ✓ to() works correctly")


def test_item_and_numpy():
    """测试 item() 和 numpy() 方法"""
    print("Testing item() and numpy()...")
    
    # item() - 单元素张量
    x = neurx.Tensor([[5.0]])
    val = x.item()
    assert isinstance(val, float)
    assert val == 5.0
    
    # numpy() - 转换为数组
    x = neurx.randn(2, 3)
    x_np = x.numpy()
    assert isinstance(x_np, np.ndarray)
    assert x_np.shape == (2, 3)
    
    print("  ✓ item() and numpy() work correctly")


def test_inplace_operations():
    """测试就地操作"""
    print("Testing in-place operations...")
    
    x = neurx.Tensor([[1.0, 2.0], [3.0, 4.0]])
    y = neurx.Tensor([[5.0, 6.0], [7.0, 8.0]])
    
    # add_
    x_orig = x.data.copy()
    x.add_(y)
    assert np.allclose(x.data, x_orig + y.data)
    
    # mul_
    x = neurx.Tensor([[1.0, 2.0], [3.0, 4.0]])
    x.mul_(2)
    assert np.allclose(x.data, [[2.0, 4.0], [6.0, 8.0]])
    
    # zero_
    x = neurx.Tensor([[1.0, 2.0], [3.0, 4.0]])
    x.zero_()
    assert np.allclose(x.data, 0)
    
    # fill_
    x = neurx.Tensor([[1.0, 2.0], [3.0, 4.0]])
    x.fill_(7)
    assert np.allclose(x.data, 7)
    
    print("  ✓ In-place operations work correctly")


def test_comparison_operators():
    """测试比较操作"""
    print("Testing comparison operators...")
    
    x = neurx.Tensor([[1.0, 2.0], [3.0, 4.0]])
    y = neurx.Tensor([[1.5, 1.5], [3.5, 3.5]])
    
    # eq() - 相等
    eq = x.eq(y)
    assert isinstance(eq, neurx.Tensor)
    
    # lt() - 小于
    lt = x.lt(y)
    assert lt.data[0, 0] == True  # 1 < 1.5 ✓
    assert lt.data[0, 1] == False  # 2 < 1.5? No ✓
    
    # gt() - 大于
    gt = x.gt(y)
    assert gt.data[0, 0] == False  # 1 > 1.5? No ✓
    assert gt.data[0, 1] == True  # 2 > 1.5 ✓
    
    # le(), ge() - 小于等于、大于等于
    le = x.le(y)
    ge = x.ge(y)
    
    print("  ✓ Comparison operators work correctly")


def test_dtype_conversion():
    """测试数据类型转换"""
    print("Testing dtype conversions...")
    
    x = neurx.randn(2, 3)
    
    # float()
    x_float = x.float()
    assert x_float.dtype == np.float32
    
    # double()
    x_double = x.double()
    assert x_double.dtype == np.float64
    
    # int()
    x_int = x.int()
    assert x_int.dtype == np.int32
    
    # long()
    x_long = x.long()
    assert x_long.dtype == np.int64
    
    print("  ✓ Dtype conversions work correctly")


def test_advanced_operations():
    """测试高级操作"""
    print("Testing advanced operations...")
    
    # clamp
    x = neurx.Tensor([[-1.0, 0.5], [1.5, 2.0]])
    x_clamped = x.clamp(min=0, max=1)
    expected = np.array([[0.0, 0.5], [1.0, 1.0]])
    assert np.allclose(x_clamped.data, expected)
    
    # isnan, isinf, isfinite
    x = neurx.Tensor([[1.0, np.nan], [np.inf, 2.0]])
    nan_mask = x.isnan()
    assert nan_mask.data[0, 1] == True
    
    inf_mask = x.isinf()
    assert inf_mask.data[1, 0] == True
    
    finite_mask = x.isfinite()
    assert finite_mask.data[0, 0] == True
    
    print("  ✓ Advanced operations work correctly")


def test_requires_grad_():
    """测试 requires_grad_() 方法"""
    print("Testing requires_grad_()...")
    
    x = neurx.Tensor([[1.0, 2.0]], requires_grad=False)
    assert x.requires_grad == False
    
    x.requires_grad_(True)
    assert x.requires_grad == True
    assert x.grad is not None
    
    print("  ✓ requires_grad_() works correctly")


def test_backward_with_enhancements():
    """测试增强后的反向传播"""
    print("Testing backward with enhancements...")
    
    x = neurx.Tensor([[1.0, 2.0], [3.0, 4.0]], requires_grad=True)
    y = x * 2
    z = y.sum()
    z.backward()
    
    # 梯度应该是 2（因为 dy/dx = 2）
    assert np.allclose(x.grad, 2)
    
    print("  ✓ Backward with enhancements works correctly")


def run_all_tests():
    """运行所有测试"""
    print("=" * 60)
    print("Running neurx Tensor Enhancement Tests")
    print("=" * 60)
    
    try:
        test_clone_and_detach()
        test_to_device()
        test_item_and_numpy()
        test_inplace_operations()
        test_comparison_operators()
        test_dtype_conversion()
        test_advanced_operations()
        test_requires_grad_()
        test_backward_with_enhancements()
        
        print("\n" + "=" * 60)
        print("✅ All enhancement tests passed!")
        print("=" * 60)
        return True
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
