"""
PyTorch 兼容层使用示例和测试
"""

import numpy as np
import sys

# 确保能导入 tensor 框架
try:
    from tensor import Tensor
    from tensor.nn.modules import Linear, LayerNorm, Module
    from tensor.pytorch_compat import (
        linear, relu, gelu, softmax, layer_norm, dropout, embedding,
        load_pytorch_checkpoint, save_pytorch_checkpoint,
        wrap_pytorch_module, wrap_tensor_module
    )
except ImportError as e:
    print(f"导入错误: {e}")
    print("请确保 tensor 框架已正确安装")
    sys.exit(1)


# ============================================================================
# 示例 1: 使用函数式接口
# ============================================================================

def example_functional_api():
    """演示函数式 API 的使用"""
    print("\n" + "="*60)
    print("示例 1: 函数式 API")
    print("="*60)
    
    # 创建输入
    x = Tensor(np.random.randn(2, 10))
    
    # 线性变换
    w = Tensor(np.random.randn(5, 10))  # (out_features, in_features)
    b = Tensor(np.random.randn(5))
    y = linear(x, w, b)
    print(f"linear: input {x.shape} -> output {y.shape}")
    
    # 激活函数
    y_relu = relu(y)
    print(f"relu: {y.shape} -> {y_relu.shape}")
    
    y_gelu = gelu(y)
    print(f"gelu: {y.shape} -> {y_gelu.shape}")
    
    y_sigmoid = sigmoid(y)
    print(f"sigmoid: {y.shape} -> {y_sigmoid.shape}")
    
    # Softmax
    logits = Tensor(np.random.randn(2, 10))
    probs = softmax(logits, dim=-1)
    print(f"softmax: {logits.shape} -> {probs.shape}")
    print(f"probs sum per sample: {probs.data.sum(axis=1)}")  # 应该都是 1.0


# ============================================================================
# 示例 2: 张量 API 对齐
# ============================================================================

def example_tensor_api():
    """演示张量 API 的 PyTorch 兼容性"""
    print("\n" + "="*60)
    print("示例 2: 张量 API 对齐")
    print("="*60)
    
    x = Tensor(np.random.randn(2, 3, 4))
    
    # 属性访问
    print(f"shape: {x.shape}")
    print(f"ndim: {x.ndim}")
    print(f"dtype: {x.dtype}")
    print(f"device: {x.device}")
    
    # 张量操作
    x_cloned = x.clone()
    print(f"clone(): 类型 {type(x_cloned).__name__}")
    
    x_detached = x.detach()
    print(f"detach(): requires_grad={x_detached.requires_grad}")
    
    # 形状操作
    x_reshaped = x.reshape(2, -1)
    print(f"reshape(2, -1): {x_reshaped.shape}")
    
    x_squeezed = x.unsqueeze(0)
    print(f"unsqueeze(0): {x_squeezed.shape}")
    
    # 聚合操作
    x_sum = x.sum(dim=1)
    print(f"sum(dim=1): {x_sum.shape}")
    
    x_mean = x.mean(dim=2)
    print(f"mean(dim=2): {x_mean.shape}")


# ============================================================================
# 示例 3: 模型定义与前向传播
# ============================================================================

class SimpleModel(Module):
    """简单的模型定义"""
    
    def __init__(self, input_dim=10, hidden_dim=20, output_dim=5):
        super().__init__()
        self.linear1 = Linear(input_dim, hidden_dim)
        self.norm1 = LayerNorm(hidden_dim)
        self.linear2 = Linear(hidden_dim, output_dim)
    
    def forward(self, x):
        x = self.linear1(x)
        x = relu(x)
        x = self.norm1(x)
        x = self.linear2(x)
        return x


def example_model_forward():
    """演示模型定义和前向传播"""
    print("\n" + "="*60)
    print("示例 3: 模型定义和前向传播")
    print("="*60)
    
    model = SimpleModel(input_dim=10, hidden_dim=20, output_dim=5)
    x = Tensor(np.random.randn(2, 10))
    
    # 前向传播
    y = model.forward(x)
    print(f"Model forward: {x.shape} -> {y.shape}")
    
    # 反向传播
    loss = y.sum()
    loss.backward()
    
    # 检查梯度
    for name, param in model.named_parameters():
        if param.grad is not None:
            print(f"Gradient {name}: shape={param.grad.shape}, "
                  f"norm={float(np.linalg.norm(param.grad)):.4f}")


# ============================================================================
# 示例 4: 权重转换 (如果有 PyTorch)
# ============================================================================

def example_weight_conversion():
    """演示权重转换"""
    print("\n" + "="*60)
    print("示例 4: 权重转换")
    print("="*60)
    
    try:
        import torch
        
        # 创建 PyTorch 模型
        pytorch_model = torch.nn.Sequential(
            torch.nn.Linear(10, 20),
            torch.nn.ReLU(),
            torch.nn.Linear(20, 5)
        )
        
        # 创建 tensor 模型
        tensor_model = SimpleModel(input_dim=10, hidden_dim=20, output_dim=5)
        
        # 从 PyTorch 转换权重
        pytorch_state = pytorch_model.state_dict()
        
        from tensor.pytorch_compat.weight_conversion import pytorch_state_to_tensor
        tensor_state = pytorch_state_to_tensor(pytorch_state)
        
        print(f"PyTorch 权重键: {list(pytorch_state.keys())[:2]}...")
        print(f"Tensor 权重键: {list(tensor_state.keys())[:2]}...")
        
        # 验证转换后的形状
        for name, param in tensor_state.items():
            print(f"  {name}: {param.shape}")
        
    except ImportError:
        print("PyTorch 未安装，跳过权重转换示例")


# ============================================================================
# 示例 5: 梯度计算
# ============================================================================

def example_gradient_computation():
    """演示梯度计算"""
    print("\n" + "="*60)
    print("示例 5: 梯度计算")
    print("="*60)
    
    # 创建可训练的参数
    x = Tensor(np.array([[1.0, 2.0], [3.0, 4.0]]), requires_grad=True)
    w = Tensor(np.array([[0.5, 0.3], [0.2, 0.1]]), requires_grad=True)
    
    # 前向传播
    y = x @ w  # 矩阵乘法
    
    # 计算损失
    loss = y.sum()
    
    # 反向传播
    loss.backward()
    
    print(f"输入梯度:\n{x.grad}")
    print(f"权重梯度:\n{w.grad}")


def sigmoid(input):
    """导入缺失的 sigmoid"""
    from tensor.pytorch_compat.functional import sigmoid as sigmoid_fn
    return sigmoid_fn(input)


# ============================================================================
# 主测试函数
# ============================================================================

def run_all_examples():
    """运行所有示例"""
    print("\n" + "#"*60)
    print("# PyTorch 兼容层示例")
    print("#"*60)
    
    try:
        example_functional_api()
    except Exception as e:
        print(f"示例 1 错误: {e}")
        import traceback
        traceback.print_exc()
    
    try:
        example_tensor_api()
    except Exception as e:
        print(f"示例 2 错误: {e}")
        import traceback
        traceback.print_exc()
    
    try:
        example_model_forward()
    except Exception as e:
        print(f"示例 3 错误: {e}")
        import traceback
        traceback.print_exc()
    
    try:
        example_weight_conversion()
    except Exception as e:
        print(f"示例 4 错误: {e}")
        import traceback
        traceback.print_exc()
    
    try:
        example_gradient_computation()
    except Exception as e:
        print(f"示例 5 错误: {e}")
        import traceback
        traceback.print_exc()
    
    print("\n" + "#"*60)
    print("# 所有示例完成")
    print("#"*60 + "\n")


# ============================================================================
# 性能对比
# ============================================================================

def benchmark_operations():
    """性能基准测试"""
    print("\n" + "="*60)
    print("性能基准测试")
    print("="*60)
    
    import time
    
    # 矩阵乘法性能
    sizes = [10, 100, 1000]
    
    for size in sizes:
        x = Tensor(np.random.randn(size, size))
        w = Tensor(np.random.randn(size, size))
        
        start = time.time()
        for _ in range(10):
            y = x @ w
        elapsed = (time.time() - start) / 10
        
        print(f"矩阵乘法 ({size}x{size}): {elapsed*1000:.2f}ms")


if __name__ == '__main__':
    run_all_examples()
    
    # 可选: 运行性能基准
    # benchmark_operations()
