#!/usr/bin/env python3
"""
log() 函数使用示例
演示如何使用新实现的 log(), log10(), log2() 函数
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
    
    x = Tensor([1.0, np.e, np.e**2, np.e**3], requires_grad=True)
    print(f"输入: x = {x.data}")
    
    y = x.log()
    print(f"输出: ln(x) = {y.data}")
    print(f"期望: [0, 1, 2, 3]")
    
    # log10 示例
    x10 = Tensor([1.0, 10.0, 100.0, 1000.0], requires_grad=False)
    print(f"\n输入: x = {x10.data}")
    y10 = x10.log10()
    print(f"输出: log10(x) = {y10.data}")
    print(f"期望: [0, 1, 2, 3]")
    
    # log2 示例
    x2 = Tensor([1.0, 2.0, 4.0, 8.0, 16.0], requires_grad=False)
    print(f"\n输入: x = {x2.data}")
    y2 = x2.log2()
    print(f"输出: log2(x) = {y2.data}")
    print(f"期望: [0, 1, 2, 3, 4]")


def example_gradient():
    """梯度计算示例"""
    print("\n" + "="*60)
    print("示例 2: 梯度计算")
    print("="*60)
    
    x = Tensor([1.0, 2.0, 4.0], requires_grad=True)
    print(f"输入: x = {x.data}")
    
    y = x.log()
    print(f"y = ln(x) = {y.data}")
    
    # 计算 loss = sum(y)
    loss = y.sum()
    print(f"loss = sum(y) = {loss.data}")
    
    # 反向传播
    loss.backward()
    print(f"\n梯度 d(loss)/dx = {x.grad}")
    print(f"期望 (应该等于 1/x): {1.0 / x.data}")


def example_log_softmax():
    """使用 log() 实现 log-softmax"""
    print("\n" + "="*60)
    print("示例 3: 实现 Log-Softmax")
    print("="*60)
    
    # Log-Softmax 在数值稳定性和计算效率上优于 Softmax
    # log_softmax(x_i) = x_i - log(sum(exp(x_j)))
    
    logits = Tensor([2.0, 1.0, 0.1], requires_grad=True)
    print(f"输入 logits: {logits.data}")
    
    # 数值稳定版本
    max_val = logits.data.max()
    logits_shifted = logits - max_val
    
    # log_softmax = x - log(sum(exp(x)))
    exp_sum = logits_shifted.exp().sum()
    log_exp_sum = exp_sum.log()
    log_softmax = logits_shifted - log_exp_sum
    
    print(f"Log-Softmax 输出: {log_softmax.data}")
    
    # 验证: exp(log_softmax) 应该是 softmax
    softmax = log_softmax.exp()
    print(f"Softmax (通过 exp): {softmax.data}")
    print(f"总和 (应该为 1): {softmax.data.sum():.6f}")


def example_cross_entropy():
    """使用 log() 实现交叉熵损失"""
    print("\n" + "="*60)
    print("示例 4: 交叉熵损失")
    print("="*60)
    
    # 模拟分类问题
    logits = Tensor([2.0, 1.0, 0.1], requires_grad=True)
    target = 0  # 真实类别
    
    print(f"Logits: {logits.data}")
    print(f"目标类别: {target}")
    
    # 计算 log-softmax
    max_val = logits.data.max()
    logits_shifted = logits - max_val
    log_sum_exp = logits_shifted.exp().sum().log()
    log_softmax = logits_shifted - log_sum_exp
    
    # 交叉熵损失 = -log_softmax[target]
    loss = -log_softmax.data[target]
    
    print(f"Log-Softmax: {log_softmax.data}")
    print(f"交叉熵损失: {loss:.6f}")


def example_information_theory():
    """信息论应用示例"""
    print("\n" + "="*60)
    print("示例 5: 信息论 - 熵和互信息")
    print("="*60)
    
    # 计算离散分布的熵: H(X) = -sum(p(x) * log(p(x)))
    probs = Tensor([0.5, 0.3, 0.2], requires_grad=False)
    print(f"概率分布: {probs.data}")
    
    # 熵
    log_probs = probs.log()
    entropy = -(probs * log_probs).sum()
    
    print(f"熵 H(X): {entropy.data:.6f} nats")
    print(f"熵 H(X): {entropy.data / np.log(2):.6f} bits")
    
    # 最大熵 (均匀分布)
    uniform_probs = Tensor([1/3, 1/3, 1/3], requires_grad=False)
    max_entropy = -(uniform_probs * uniform_probs.log()).sum()
    print(f"最大熵 (均匀分布): {max_entropy.data:.6f} nats")
    print(f"最大熵 (均匀分布): {max_entropy.data / np.log(2):.6f} bits")


def example_exp_log_relationship():
    """exp 和 log 的关系示例"""
    print("\n" + "="*60)
    print("示例 6: exp 和 log 的关系")
    print("="*60)
    
    x = Tensor([0.5, 1.0, 2.0, 3.0], requires_grad=True)
    print(f"原始值: x = {x.data}")
    
    # exp(log(x)) = x (对于 x > 0)
    y1 = x.exp().log()
    print(f"\nlog(exp(x)) = {y1.data}")
    print(f"应该等于 x: {np.allclose(y1.data, x.data)}")
    
    # log(exp(x)) = x
    x2 = Tensor([1.0, 2.0, 3.0], requires_grad=True)
    y2 = x2.log().exp()
    print(f"\nexp(log(x)) = {y2.data}")
    print(f"应该等于 x: {np.allclose(y2.data, x2.data)}")
    
    # 梯度传播
    loss = y2.sum()
    loss.backward()
    print(f"\n梯度 d(exp(log(x)))/dx = {x2.grad}")
    print(f"应该全部为 1: {np.allclose(x2.grad, np.ones_like(x2.data))}")


def example_logarithmic_scale():
    """对数尺度示例"""
    print("\n" + "="*60)
    print("示例 7: 对数尺度变换")
    print("="*60)
    
    # 将数据转换到对数空间进行处理
    data = Tensor([1.0, 10.0, 100.0, 1000.0, 10000.0], requires_grad=False)
    print(f"原始数据 (跨度大): {data.data}")
    print(f"数据范围: {data.data.min():.0f} - {data.data.max():.0f}")
    
    # 对数变换
    log_data = data.log10()
    print(f"\nlog10 变换后: {log_data.data}")
    print(f"变换后范围: {log_data.data.min():.0f} - {log_data.data.max():.0f}")
    
    # 对数变换可以将大范围的数据压缩到小范围
    print(f"\n压缩比: {(data.data.max() - data.data.min()) / (log_data.data.max() - log_data.data.min()):.1f}x")


def example_numerical_precision():
    """数值精度示例"""
    print("\n" + "="*60)
    print("示例 8: 数值精度和稳定性")
    print("="*60)
    
    # 测试接近 0 的值
    x_small = Tensor([1e-10, 1e-5, 1e-3, 0.1, 1.0], requires_grad=True)
    y_small = x_small.log()
    print(f"小值输入: {x_small.data}")
    print(f"log 输出: {y_small.data}")
    
    # 梯度应该是 1/x
    y_small.sum().backward()
    expected_grad = 1.0 / x_small.data
    print(f"\n梯度: {x_small.grad}")
    print(f"期望: {expected_grad}")
    print(f"匹配: {np.allclose(x_small.grad, expected_grad)}")


def example_change_of_base():
    """对数换底公式示例"""
    print("\n" + "="*60)
    print("示例 9: 对数换底公式")
    print("="*60)
    
    x = Tensor([8.0, 16.0, 32.0], requires_grad=False)
    print(f"输入: x = {x.data}")
    
    # log_a(x) = log_b(x) / log_b(a)
    # 例如: log2(x) = ln(x) / ln(2)
    
    log2_direct = x.log2()
    log2_via_ln = x.log() / np.log(2)
    
    print(f"\nlog2(x) 直接计算: {log2_direct.data}")
    print(f"log2(x) 通过 ln: {log2_via_ln.data}")
    print(f"两者相等: {np.allclose(log2_direct.data, log2_via_ln.data)}")
    
    # 验证公式
    print(f"\n换底公式验证:")
    print(f"log10(x) = ln(x) / ln(10)")
    log10_direct = x.log10()
    log10_via_ln = x.log() / np.log(10)
    print(f"直接计算: {log10_direct.data}")
    print(f"通过换底: {log10_via_ln.data}")
    print(f"相等: {np.allclose(log10_direct.data, log10_via_ln.data)}")


def main():
    """运行所有示例"""
    print("="*60)
    print("NeurX log() 系列函数使用示例")
    print("="*60)
    
    example_basic_usage()
    example_gradient()
    example_log_softmax()
    example_cross_entropy()
    example_information_theory()
    example_exp_log_relationship()
    example_logarithmic_scale()
    example_numerical_precision()
    example_change_of_base()
    
    print("\n" + "="*60)
    print("✅ 所有示例运行完成!")
    print("="*60)


if __name__ == "__main__":
    main()
