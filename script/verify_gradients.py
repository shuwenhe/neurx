#!/usr/bin/env python3
"""
梯度验证脚本
用于验证新实现的函数的自动微分是否正确
"""
import numpy as np
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

from neurx.core.neurx import Tensor


def numerical_gradient(func, x, eps=1e-5):
    """
    计算数值梯度
    
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
        fxh_plus = func(x.copy())
        
        x[idx] = old_value - eps
        fxh_minus = func(x.copy())
        
        grad[idx] = (fxh_plus - fxh_minus) / (2 * eps)
        x[idx] = old_value
        it.iternext()
    
    return grad


def verify_gradient(function_name, test_func, x_shape=(3, 4), eps=1e-5, rtol=1e-4):
    """
    验证自动微分梯度与数值梯度的一致性
    
    Args:
        function_name: 函数名称
        test_func: 接受 Tensor 并返回 Tensor 的函数
        x_shape: 输入形状
        eps: 数值梯度的微分步长
        rtol: 相对容差
    """
    print(f"\n{'='*60}")
    print(f"验证 {function_name} 的梯度")
    print(f"{'='*60}")
    
    # 生成随机输入
    x_np = np.random.randn(*x_shape)
    
    # 定义损失函数
    def numpy_func(x):
        t = Tensor(x, requires_grad=False)
        y = test_func(t)
        return y.data.sum()
    
    # 计算数值梯度
    print("计算数值梯度...")
    numerical_grad = numerical_gradient(numpy_func, x_np.copy(), eps=eps)
    
    # 计算自动微分梯度
    print("计算自动微分梯度...")
    x_tensor = Tensor(x_np.copy(), requires_grad=True)
    y = test_func(x_tensor)
    y.sum().backward()
    auto_grad = x_tensor.grad
    
    # 比较
    print("\n结果:")
    print(f"  数值梯度 (样本):   {numerical_grad.flat[:3]}")
    print(f"  自动微分梯度 (样本): {auto_grad.flat[:3]}")
    
    # 计算差异
    abs_diff = np.abs(auto_grad - numerical_grad)
    rel_diff = abs_diff / (np.abs(numerical_grad) + 1e-8)
    
    max_abs_diff = np.max(abs_diff)
    max_rel_diff = np.max(rel_diff)
    mean_rel_diff = np.mean(rel_diff)
    
    print(f"\n差异统计:")
    print(f"  最大绝对差异: {max_abs_diff:.2e}")
    print(f"  最大相对差异: {max_rel_diff:.2e}")
    print(f"  平均相对差异: {mean_rel_diff:.2e}")
    
    # 判断
    try:
        np.testing.assert_allclose(auto_grad, numerical_grad, rtol=rtol, atol=1e-6)
        print(f"\n✅ {function_name} 梯度验证通过!")
        return True
    except AssertionError as e:
        print(f"\n❌ {function_name} 梯度验证失败!")
        print(f"  错误信息: {e}")
        return False


def main():
    """主函数"""
    print("="*60)
    print("NeurX 梯度验证工具")
    print("="*60)
    
    # 测试 exp()
    verify_gradient("exp()", lambda t: t.exp(), x_shape=(3, 4))
    
    # 测试 exp() 的组合
    verify_gradient("exp() 组合", lambda t: (t.exp() * 2 + 1), x_shape=(2, 3))
    
    # 测试 exp() 在链式法则中
    verify_gradient("exp() 链式", lambda t: t.exp().exp(), x_shape=(2, 2))
    
    # 测试 log() - 确保输入为正
    verify_gradient("log()", lambda t: (t * t + 1).log(), x_shape=(3, 4))
    
    # 测试 log() 组合
    verify_gradient("log() 组合", lambda t: ((t * t + 2).log() * 3), x_shape=(2, 3))
    
    # 测试 log() 在链式法则中 - 使用 abs 确保正值
    verify_gradient("log() 链式", lambda t: ((t * t + 1).log() + 1).log(), x_shape=(2, 2))
    
    # 测试 exp 和 log 组合
    verify_gradient("exp(log(x))", lambda t: (t * t + 1).log().exp(), x_shape=(3, 3))
    
    # 测试 log10()
    verify_gradient("log10()", lambda t: (t * t + 2).log10(), x_shape=(2, 3))
    
    # 测试 log2()
    verify_gradient("log2()", lambda t: (t * t + 2).log2(), x_shape=(2, 3))
    
    # 测试 sigmoid()
    verify_gradient("sigmoid()", lambda t: t.sigmoid(), x_shape=(3, 4))
    
    # 测试 sigmoid() 组合
    verify_gradient("sigmoid() 组合", lambda t: (t.sigmoid() * 2 - 1), x_shape=(2, 3))
    
    # 测试 sigmoid() 在链式法则中
    verify_gradient("sigmoid() 链式", lambda t: t.sigmoid().sigmoid(), x_shape=(2, 2))
    
    # 测试 tanh()
    verify_gradient("tanh()", lambda t: t.tanh(), x_shape=(3, 4))
    
    # 测试 tanh() 组合
    verify_gradient("tanh() 组合", lambda t: (t.tanh() ** 2), x_shape=(2, 3))
    
    # 测试 tanh() 在链式法则中
    verify_gradient("tanh() 链式", lambda t: t.tanh().tanh(), x_shape=(2, 2))
    
    # 测试 gelu() 精确版本
    verify_gradient("gelu() 精确", lambda t: t.gelu(approximate=False), x_shape=(3, 4))
    
    # 测试 gelu() 近似版本
    verify_gradient("gelu() 近似", lambda t: t.gelu(approximate=True), x_shape=(3, 4))
    
    # 测试 gelu() 组合
    verify_gradient("gelu() 组合", lambda t: (t.gelu() * 2), x_shape=(2, 3))
    
    # 测试 gelu() 在链式法则中
    verify_gradient("gelu() 链式", lambda t: t.gelu().gelu(), x_shape=(2, 2))

    # 测试 gather()
    verify_gradient(
        "gather()",
        lambda t: t.gather(1, Tensor([[2, 1], [0, 2], [1, 0]])).sum(),
        x_shape=(3, 3),
    )

    # 测试 scatter() (对 self 的梯度)
    verify_gradient(
        "scatter()",
        lambda t: t.scatter(1, Tensor([[0, 2], [1, 0], [2, 1]]), Tensor(np.ones((3, 2)))).sum(),
        x_shape=(3, 3),
    )

    # 测试 index_select()
    verify_gradient(
        "index_select()",
        lambda t: t.index_select(1, Tensor([2, 0])).sum(),
        x_shape=(3, 4),
    )

    # 测试 tril()/triu()
    verify_gradient("tril()", lambda t: t.tril().sum(), x_shape=(4, 4))
    verify_gradient("triu()", lambda t: t.triu(1).sum(), x_shape=(4, 4))

    # 测试 norm()
    verify_gradient("norm(p=2)", lambda t: t.norm(p=2, axis=1).sum(), x_shape=(3, 4))
    
    print("\n" + "="*60)
    print("✅ 所有梯度验证完成!")
    print("="*60)


if __name__ == "__main__":
    main()
