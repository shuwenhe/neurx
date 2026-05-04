#!/usr/bin/env python3
"""
exp() 函数使用示例
演示如何使用新实现的 exp() 函数
"""
import numpy as np
import sys
sys.path.insert(0, '/home/shuwen/neurx/python')

from neurx.core.neurx import Tensor


def example_basic_usage():
    """基本使用示例"""
    print("\n" + "="*60)
    print("示例 1: 基本使用")
    print("="*60)
    
    x = Tensor([0, 1, 2, 3], requires_grad=True)
    print(f"输入: x = {x.data}")
    
    y = x.exp()
    print(f"输出: exp(x) = {y.data}")
    print(f"期望: [1, e, e², e³] ≈ {np.exp([0, 1, 2, 3])}")


def example_gradient():
    """梯度计算示例"""
    print("\n" + "="*60)
    print("示例 2: 梯度计算")
    print("="*60)
    
    x = Tensor([1.0, 2.0], requires_grad=True)
    print(f"输入: x = {x.data}")
    
    y = x.exp()
    print(f"y = exp(x) = {y.data}")
    
    # 计算 loss = sum(y)
    loss = y.sum()
    print(f"loss = sum(y) = {loss.data}")
    
    # 反向传播
    loss.backward()
    print(f"\n梯度 d(loss)/dx = {x.grad}")
    print(f"期望 (应该等于 exp(x)): {np.exp([1.0, 2.0])}")


def example_neural_network():
    """在神经网络中的使用示例"""
    print("\n" + "="*60)
    print("示例 3: 神经网络激活函数")
    print("="*60)
    
    # 更简单的示例：元素级操作
    # 假设我们有一些经过线性层的输出
    z = Tensor(np.random.randn(3, 4), requires_grad=True)
    
    # 使用 exp 作为激活函数
    y = z.exp()
    
    print(f"输入维度: {z.data.shape}")
    print(f"输出维度: {y.data.shape}")
    print(f"输出值样本: {y.data[0]}")
    
    # 计算损失
    loss = y.sum()
    loss.backward()
    
    print(f"\n梯度已计算:")
    print(f"  dL/dz: {z.grad.shape}")
    print(f"  梯度等于输出 (exp的性质): {np.allclose(z.grad, y.data)}")


def example_softmax():
    """使用 exp() 实现 softmax"""
    print("\n" + "="*60)
    print("示例 4: 使用 exp() 实现 Softmax")
    print("="*60)
    
    # Softmax: softmax(x_i) = exp(x_i) / sum(exp(x_j))
    x = Tensor([1.0, 2.0, 3.0], requires_grad=True)
    print(f"输入: x = {x.data}")
    
    # 数值稳定版本: 先减去最大值
    x_max = x.data.max()
    x_shifted = x - x_max
    
    exp_x = x_shifted.exp()
    sum_exp = exp_x.sum()
    softmax = exp_x / sum_exp
    
    print(f"Softmax 输出: {softmax.data}")
    print(f"总和 (应该为 1): {softmax.data.sum()}")
    
    # 反向传播
    loss = softmax.sum()
    loss.backward()
    print(f"梯度: {x.grad}")


def example_exponential_decay():
    """指数衰减示例"""
    print("\n" + "="*60)
    print("示例 5: 指数衰减 (学习率调度)")
    print("="*60)
    
    # 学习率: lr(t) = lr_0 * exp(-decay_rate * t)
    lr_0 = 0.1
    decay_rate = 0.01
    
    t = Tensor(np.arange(0, 10), requires_grad=False)
    lr = lr_0 * (-decay_rate * t).exp()
    
    print(f"时间步: {t.data}")
    print(f"学习率: {lr.data}")
    print(f"\n学习率从 {lr.data[0]:.4f} 衰减到 {lr.data[-1]:.4f}")


def example_numerical_stability():
    """数值稳定性示例"""
    print("\n" + "="*60)
    print("示例 6: 数值稳定性")
    print("="*60)
    
    # 测试大数和小数
    x_large = Tensor([10.0, 20.0, 50.0], requires_grad=False)
    x_small = Tensor([-10.0, -20.0, -50.0], requires_grad=False)
    
    y_large = x_large.exp()
    y_small = x_small.exp()
    
    print(f"大数输入: {x_large.data}")
    print(f"exp(大数): {y_large.data}")
    print(f"是否溢出: {np.any(np.isinf(y_large.data))}")
    
    print(f"\n小数输入: {x_small.data}")
    print(f"exp(小数): {y_small.data}")
    print(f"是否下溢: {np.any(y_small.data == 0)}")


def main():
    """运行所有示例"""
    print("="*60)
    print("NeurX exp() 函数使用示例")
    print("="*60)
    
    example_basic_usage()
    example_gradient()
    example_neural_network()
    example_softmax()
    example_exponential_decay()
    example_numerical_stability()
    
    print("\n" + "="*60)
    print("✅ 所有示例运行完成!")
    print("="*60)


if __name__ == "__main__":
    main()
