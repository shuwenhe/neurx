#!/usr/bin/env python3
"""
sigmoid(), tanh(), gelu() 激活函数使用示例
演示神经网络中最常用的三个激活函数的用法和特性
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
    
    x = Tensor([-2.0, -1.0, 0.0, 1.0, 2.0], requires_grad=False)
    print(f"输入: x = {x.data}")
    
    y_sigmoid = x.sigmoid()
    print(f"\nsigmoid(x) = {y_sigmoid.data}")
    print(f"范围: (0, 1)")
    
    y_tanh = x.tanh()
    print(f"\ntanh(x) = {y_tanh.data}")
    print(f"范围: (-1, 1)")
    
    y_gelu = x.gelu()
    print(f"\ngelu(x) = {y_gelu.data}")
    print(f"注: GELU 是平滑的 ReLU")


def example_activation_shapes():
    """激活函数形状特性"""
    print("\n" + "="*60)
    print("示例 2: 激活函数形状特性")
    print("="*60)
    
    x = np.linspace(-5, 5, 100)
    x_tensor = Tensor(x, requires_grad=False)
    
    # 计算激活函数值
    sigmoid = x_tensor.sigmoid().data
    tanh = x_tensor.tanh().data
    gelu = x_tensor.gelu().data
    
    print("函数值范围:")
    print(f"  sigmoid: [{sigmoid.min():.4f}, {sigmoid.max():.4f}]")
    print(f"  tanh:    [{tanh.min():.4f}, {tanh.max():.4f}]")
    print(f"  gelu:    [{gelu.min():.4f}, {gelu.max():.4f}]")
    
    print("\n中点值 (x=0):")
    print(f"  sigmoid(0) = {sigmoid[np.argmin(np.abs(x))]:.4f}")
    print(f"  tanh(0)    = {tanh[np.argmin(np.abs(x))]:.4f}")
    print(f"  gelu(0)    = {gelu[np.argmin(np.abs(x))]:.4f}")
    
    print("\n极值:")
    print(f"  sigmoid 在 x→∞ 时趋向于 1")
    print(f"  tanh 在 x→∞ 时趋向于 1")
    print(f"  gelu 在 x→∞ 时快速增长")


def example_gradient():
    """梯度计算示例"""
    print("\n" + "="*60)
    print("示例 3: 梯度计算与消失梯度问题")
    print("="*60)
    
    x = Tensor([-3.0, -1.0, 0.0, 1.0, 3.0], requires_grad=True)
    
    # Sigmoid 梯度
    y_sigmoid = x.sigmoid()
    loss = y_sigmoid.sum()
    loss.backward()
    sigmoid_grad = x.grad.copy()
    
    # Tanh 梯度
    x.grad = np.zeros_like(x.grad)  # 重置梯度
    y_tanh = x.tanh()
    loss = y_tanh.sum()
    loss.backward()
    tanh_grad = x.grad.copy()
    
    # GELU 梯度
    x.grad = np.zeros_like(x.grad)  # 重置梯度
    y_gelu = x.gelu()
    loss = y_gelu.sum()
    loss.backward()
    gelu_grad = x.grad.copy()
    
    print("\n梯度值对比:")
    print(f"{'x':>8} {'sigmoid':>12} {'tanh':>12} {'gelu':>12}")
    print("-" * 48)
    for i, xi in enumerate(x.data):
        print(f"{xi:>8.1f} {sigmoid_grad[i]:>12.6f} {tanh_grad[i]:>12.6f} {gelu_grad[i]:>12.6f}")
    
    print("\n梯度统计:")
    print(f"sigmoid 梯度范围: [{sigmoid_grad.min():.6f}, {sigmoid_grad.max():.6f}]")
    print(f"tanh    梯度范围: [{tanh_grad.min():.6f}, {tanh_grad.max():.6f}]")
    print(f"gelu    梯度范围: [{gelu_grad.min():.6f}, {gelu_grad.max():.6f}]")
    
    print("\n观察: sigmoid 在两端梯度接近 0（消失梯度问题）")
    print("      tanh 的梯度更强，但仍有消失梯度问题")
    print("      gelu 避免了消失梯度问题（无死区）")


def example_simple_neural_network():
    """简单神经网络示例"""
    print("\n" + "="*60)
    print("示例 4: 简单两层神经网络")
    print("="*60)
    
    # 模拟输入数据
    x = Tensor(np.random.randn(5, 10), requires_grad=True)  # batch_size=5, features=10
    
    # 第一层: 线性 + 激活
    print("使用 sigmoid 激活函数:")
    w1_sigmoid = Tensor(np.random.randn(10, 5) * 0.01, requires_grad=False)
    z1_sigmoid = x @ w1_sigmoid
    a1_sigmoid = z1_sigmoid.sigmoid()
    print(f"  输入形状: {x.shape}")
    print(f"  输出形状: {a1_sigmoid.shape}")
    print(f"  激活后范围: [{a1_sigmoid.data.min():.4f}, {a1_sigmoid.data.max():.4f}]")
    
    print("\n使用 tanh 激活函数:")
    x.grad = np.zeros_like(x.grad)
    w1_tanh = Tensor(np.random.randn(10, 5) * 0.01, requires_grad=False)
    z1_tanh = x @ w1_tanh
    a1_tanh = z1_tanh.tanh()
    print(f"  输入形状: {x.shape}")
    print(f"  输出形状: {a1_tanh.shape}")
    print(f"  激活后范围: [{a1_tanh.data.min():.4f}, {a1_tanh.data.max():.4f}]")
    
    print("\n使用 GELU 激活函数:")
    x.grad = np.zeros_like(x.grad)
    w1_gelu = Tensor(np.random.randn(10, 5) * 0.01, requires_grad=False)
    z1_gelu = x @ w1_gelu
    a1_gelu = z1_gelu.gelu()
    print(f"  输入形状: {x.shape}")
    print(f"  输出形状: {a1_gelu.shape}")
    print(f"  激活后范围: [{a1_gelu.data.min():.4f}, {a1_gelu.data.max():.4f}]")


def example_lstm_style():
    """LSTM 风格的 tanh 使用"""
    print("\n" + "="*60)
    print("示例 5: LSTM 风格的 tanh 激活")
    print("="*60)
    
    # 模拟候选隐藏状态
    h_tilde = Tensor(np.random.randn(3, 4), requires_grad=True)
    
    # LSTM 使用 tanh 压缩候选隐藏状态
    print(f"候选隐藏状态范围: [{h_tilde.data.min():.4f}, {h_tilde.data.max():.4f}]")
    
    h_candidate = h_tilde.tanh()
    print(f"tanh 压缩后范围: [{h_candidate.data.min():.4f}, {h_candidate.data.max():.4f}]")
    
    # 模拟遗忘门和输入门
    forget_gate = Tensor(np.random.rand(3, 4), requires_grad=False)  # (0, 1)
    input_gate = Tensor(np.random.rand(3, 4), requires_grad=False)   # (0, 1)
    
    # 更新单元状态: C_t = f_t * C_{t-1} + i_t * h_tilde
    c_prev = Tensor(np.random.randn(3, 4), requires_grad=False)
    c_curr = forget_gate * c_prev + input_gate * h_candidate
    
    print(f"\n更新后的单元状态范围: [{c_curr.data.min():.4f}, {c_curr.data.max():.4f}]")
    
    # 输出使用 tanh 压缩
    h_curr = c_curr.tanh()  # 简化：实际会有输出门
    print(f"tanh 压缩后隐藏状态: [{h_curr.data.min():.4f}, {h_curr.data.max():.4f}]")


def example_transformer_gelu():
    """Transformer 中的 GELU 使用"""
    print("\n" + "="*60)
    print("示例 6: Transformer 中的 GELU 激活")
    print("="*60)
    
    # 模拟 MLP (Position-wise Feed-Forward Network)
    batch_size, seq_len, d_model = 2, 4, 8
    d_ff = 32  # Feed-forward dimension
    
    x = Tensor(np.random.randn(batch_size, seq_len, d_model) * 0.1, requires_grad=True)
    
    # 第一层: 扩展维度
    w1 = Tensor(np.random.randn(d_model, d_ff) * np.sqrt(2.0 / d_model), requires_grad=False)
    b1 = Tensor(np.zeros(d_ff), requires_grad=False)
    
    # 计算线性变换
    x_reshaped = x.reshape((batch_size * seq_len, d_model))
    hidden = (x_reshaped @ w1) + b1  # 线性变换
    
    print(f"输入形状: {x.shape}")
    print(f"扩展前: {hidden.shape} (batch*seq, d_ff)")
    print(f"扩展前范围: [{hidden.data.min():.4f}, {hidden.data.max():.4f}]")
    
    # GELU 激活
    hidden_activated = hidden.gelu(approximate=True)  # 使用快速近似版本
    print(f"GELU 激活后: {hidden_activated.shape}")
    print(f"GELU 激活后范围: [{hidden_activated.data.min():.4f}, {hidden_activated.data.max():.4f}]")
    
    print("\n为什么 Transformer 使用 GELU:")
    print("  1. 相比 ReLU，GELU 更平滑，没有死区")
    print("  2. 实验表明 GELU 在大规模模型上效果更好")
    print("  3. 近似版本计算高效，适合高性能要求")


def example_gelu_approximation():
    """GELU 精确版本 vs 近似版本"""
    print("\n" + "="*60)
    print("示例 7: GELU 精确版本 vs 近似版本")
    print("="*60)
    
    x = Tensor(np.linspace(-3, 3, 13), requires_grad=False)
    
    gelu_exact = x.gelu(approximate=False).data
    gelu_approx = x.gelu(approximate=True).data
    
    diff = np.abs(gelu_exact - gelu_approx)
    rel_error = diff / (np.abs(gelu_exact) + 1e-8) * 100
    
    print(f"\n{'x':>7} {'精确':>12} {'近似':>12} {'绝对误差':>12} {'相对误差':>12}")
    print("-" * 60)
    for i, xi in enumerate(x.data):
        print(f"{xi:>7.2f} {gelu_exact[i]:>12.6f} {gelu_approx[i]:>12.6f} {diff[i]:>12.6e} {rel_error[i]:>11.4f}%")
    
    print(f"\n最大相对误差: {rel_error.max():.4f}%")
    print(f"平均相对误差: {rel_error.mean():.4f}%")
    print("\n结论: 近似版本精度很高，足以用于实际应用")


def example_numerical_stability():
    """数值稳定性演示"""
    print("\n" + "="*60)
    print("示例 8: 数值稳定性")
    print("="*60)
    
    # 极端值测试
    x_extreme = Tensor([-100.0, -10.0, 0.0, 10.0, 100.0], requires_grad=False)
    
    print(f"输入: {x_extreme.data}")
    
    try:
        sigmoid = x_extreme.sigmoid()
        print(f"sigmoid: {sigmoid.data}")
    except Exception as e:
        print(f"sigmoid 出错: {e}")
    
    try:
        tanh = x_extreme.tanh()
        print(f"tanh: {tanh.data}")
    except Exception as e:
        print(f"tanh 出错: {e}")
    
    try:
        gelu = x_extreme.gelu()
        print(f"gelu: {gelu.data}")
    except Exception as e:
        print(f"gelu 出错: {e}")
    
    print("\n所有激活函数都具有良好的数值稳定性")
    print("sigmoid 和 tanh 使用数值稳定的实现")
    print("gelu 使用 scipy.special.erf 确保数值精度")


def main():
    """运行所有示例"""
    print("="*60)
    print("NeurX 激活函数 (sigmoid, tanh, gelu) 使用示例")
    print("="*60)
    
    example_basic_usage()
    example_activation_shapes()
    example_gradient()
    example_simple_neural_network()
    example_lstm_style()
    example_transformer_gelu()
    example_gelu_approximation()
    example_numerical_stability()
    
    print("\n" + "="*60)
    print("✅ 所有示例运行完成!")
    print("="*60)


if __name__ == "__main__":
    main()
