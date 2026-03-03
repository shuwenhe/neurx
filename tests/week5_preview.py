"""
Week 5 Preview: 权重初始化、梯度操作、模型分析演示

本脚本展示 Week 5 计划中的核心功能。
注意: 这些是计划功能，将在 Week 5 实施。
"""

import numpy as np

# 模拟权重初始化函数
class InitFunctions:
    """权重初始化函数演示"""
    
    @staticmethod
    def xavier_uniform(shape):
        """Xavier 均匀初始化"""
        fan_in = shape[0] if len(shape) > 0 else 1
        fan_out = shape[1] if len(shape) > 1 else 1
        limit = np.sqrt(6.0 / (fan_in + fan_out))
        return np.random.uniform(-limit, limit, shape)
    
    @staticmethod
    def kaiming_normal(shape, a=0):
        """Kaiming 正态初始化 (for ReLU)"""
        fan_in = shape[0] if len(shape) > 0 else 1
        std = np.sqrt(2.0 / fan_in)
        return np.random.normal(0, std, shape)
    
    @staticmethod
    def orthogonal(shape):
        """正交初始化"""
        if len(shape) < 2:
            raise ValueError("Orthogonal init requires at least 2D tensor")
        # 简化的 QR 分解
        a = np.random.normal(0, 1, shape)
        q, r = np.linalg.qr(a.reshape(-1, shape[-1]))
        return q.reshape(shape)[:shape[0], :shape[-1]]

# 模拟梯度操作
class GradOperations:
    """梯度操作函数演示"""
    
    @staticmethod
    def clip_grad_norm(gradients, max_norm):
        """梯度范数裁剪"""
        total_norm = 0.0
        for grad in gradients:
            param_norm = np.sqrt(np.sum(grad ** 2))
            total_norm += param_norm ** 2
        total_norm = np.sqrt(total_norm)
        
        if total_norm > max_norm:
            clip_coef = max_norm / (total_norm + 1e-6)
            for i in range(len(gradients)):
                gradients[i] *= clip_coef
        
        return total_norm
    
    @staticmethod
    def clip_grad_value(gradients, clip_value):
        """梯度值裁剪"""
        for i in range(len(gradients)):
            gradients[i] = np.clip(gradients[i], -clip_value, clip_value)

# 模型分析工具
class ModelAnalysis:
    """模型分析工具演示"""
    
    @staticmethod
    def count_parameters(shapes):
        """统计参数数量"""
        total = 0
        for shape in shapes:
            param_count = np.prod(shape)
            total += param_count
        return total
    
    @staticmethod
    def estimate_flops(layer_specs):
        """估算 FLOPs"""
        total_flops = 0
        
        for layer in layer_specs:
            if layer['type'] == 'conv2d':
                # Conv2d: FLOPs = 2 * kernel_h * kernel_w * in_ch * out_ch * out_h * out_w
                flops = (2 * layer['kernel_h'] * layer['kernel_w'] * 
                        layer['in_channels'] * layer['out_channels'] * 
                        layer['out_h'] * layer['out_w'])
                total_flops += flops
            
            elif layer['type'] == 'linear':
                # Linear: FLOPs = 2 * in_features * out_features * batch_size
                flops = 2 * layer['in_features'] * layer['out_features'] * layer['batch_size']
                total_flops += flops
        
        return total_flops
    
    @staticmethod
    def print_summary(model_name, layers):
        """打印模型摘要"""
        print(f"\nModel: {model_name}")
        print("=" * 70)
        print(f"{'Layer':<20} {'Output Shape':<20} {'Parameters':<15}")
        print("-" * 70)
        
        total_params = 0
        for layer in layers:
            params = np.prod(layer['shape'])
            total_params += params
            print(f"{layer['name']:<20} {str(layer['shape']):<20} {params:<15,}")
        
        print("-" * 70)
        print(f"{'Total':<20} {'':<20} {total_params:<15,}")
        print("=" * 70)


def demo_weight_initialization():
    """演示权重初始化"""
    print("\n" + "=" * 70)
    print("DEMO 1: 权重初始化 (Weight Initialization)")
    print("=" * 70)
    
    init = InitFunctions()
    
    # Test 1: Xavier Uniform
    print("\n1.1 Xavier Uniform Initialization")
    shape = (100, 100)
    weights = init.xavier_uniform(shape)
    print(f"  Shape: {shape}")
    print(f"  Mean: {np.mean(weights):.6f} (should be ~0)")
    print(f"  Std:  {np.std(weights):.6f}")
    print(f"  Min:  {np.min(weights):.6f}")
    print(f"  Max:  {np.max(weights):.6f}")
    
    # Test 2: Kaiming Normal
    print("\n1.2 Kaiming Normal Initialization (for ReLU)")
    shape = (128, 256)
    weights = init.kaiming_normal(shape)
    print(f"  Shape: {shape}")
    print(f"  Mean: {np.mean(weights):.6f}")
    print(f"  Std:  {np.std(weights):.6f} (should be ~{np.sqrt(2.0/128):.4f})")
    
    # Test 3: Orthogonal
    print("\n1.3 Orthogonal Initialization")
    shape = (64, 64)
    weights = init.orthogonal(shape)
    print(f"  Shape: {shape}")
    # Check orthogonality: W^T @ W ≈ I
    gram = weights.T @ weights
    is_orth = np.allclose(gram, np.eye(shape[1]), atol=1e-5)
    print(f"  Orthogonal: {is_orth} (W^T @ W should be Identity)")
    print(f"  Gram matrix diagonal (should be ~1): {np.diag(gram)[:5]}")


def demo_gradient_operations():
    """演示梯度操作"""
    print("\n" + "=" * 70)
    print("DEMO 2: 梯度操作 (Gradient Operations)")
    print("=" * 70)
    
    grad_ops = GradOperations()
    
    # Test 1: Gradient Norm
    print("\n2.1 梯度范数计算和裁剪")
    grads = [
        np.random.randn(128, 256),
        np.random.randn(256, 64),
        np.random.randn(64, 10)
    ]
    
    print(f"  梯度数量: {len(grads)}")
    
    # 计算原始范数
    original_norm = grad_ops.clip_grad_norm(grads.copy(), float('inf'))
    print(f"  原始梯度范数: {original_norm:.4f}")
    
    # 裁剪梯度
    grads_clipped = [g.copy() for g in grads]
    clipped_norm = grad_ops.clip_grad_norm(grads_clipped, max_norm=1.0)
    print(f"  裁剪后梯度范数: {clipped_norm:.4f} (should be <= 1.0)")
    
    # Test 2: Gradient Value Clipping
    print("\n2.2 梯度值裁剪")
    grads_val = [np.random.randn(100, 100) * 10]  # Large gradients
    print(f"  原始梯度范围: [{np.min(grads_val[0]):.4f}, {np.max(grads_val[0]):.4f}]")
    
    grad_ops.clip_grad_value(grads_val, clip_value=5.0)
    print(f"  裁剪后梯度范围: [{np.min(grads_val[0]):.4f}, {np.max(grads_val[0]):.4f}]")


def demo_model_analysis():
    """演示模型分析"""
    print("\n" + "=" * 70)
    print("DEMO 3: 模型分析 (Model Analysis)")
    print("=" * 70)
    
    analysis = ModelAnalysis()
    
    # Test 1: Parameter Counting
    print("\n3.1 参数计数")
    layers = [
        {'name': 'Conv2d_1', 'shape': (32, 3, 3, 3)},      # 32 filters, 3x3, 3 input channels
        {'name': 'Conv2d_2', 'shape': (64, 32, 3, 3)},     # 64 filters, 3x3, 32 input channels
        {'name': 'Linear_1', 'shape': (256, 128)},         # 256 -> 128
        {'name': 'Linear_2', 'shape': (128, 10)},          # 128 -> 10 (output)
    ]
    
    analysis.print_summary("SimpleCNN", layers)
    
    # Test 2: FLOPs Estimation
    print("\n3.2 FLOPs 估算")
    layer_specs = [
        {
            'type': 'conv2d',
            'kernel_h': 3, 'kernel_w': 3,
            'in_channels': 3, 'out_channels': 32,
            'out_h': 32, 'out_w': 32
        },
        {
            'type': 'conv2d',
            'kernel_h': 3, 'kernel_w': 3,
            'in_channels': 32, 'out_channels': 64,
            'out_h': 16, 'out_w': 16
        },
        {
            'type': 'linear',
            'in_features': 64 * 16 * 16,
            'out_features': 10,
            'batch_size': 32
        }
    ]
    
    flops = analysis.estimate_flops(layer_specs)
    print(f"  总 FLOPs: {flops:,} (~{flops/1e9:.2f}G)")
    print(f"  Conv2d_1 FLOPs: {analysis.estimate_flops([layer_specs[0]]):,}")
    print(f"  Conv2d_2 FLOPs: {analysis.estimate_flops([layer_specs[1]]):,}")
    print(f"  Linear FLOPs: {analysis.estimate_flops([layer_specs[2]]):,}")


def demo_batchnorm_preview():
    """演示 BatchNorm 预览"""
    print("\n" + "=" * 70)
    print("DEMO 4: BatchNorm 预览 (Batch Normalization)")
    print("=" * 70)
    
    print("\n4.1 批归一化的数学原理")
    print("  训练模式:")
    print("    y = (x - batch_mean) / sqrt(batch_var + eps)")
    print("    output = gamma * y + beta")
    print("    更新: running_mean = momentum * running_mean + (1-momentum) * batch_mean")
    print()
    print("  评估模式:")
    print("    y = (x - running_mean) / sqrt(running_var + eps)")
    print("    output = gamma * y + beta")
    
    print("\n4.2 模拟 BatchNorm 效果")
    # 生成样本数据
    x = np.random.randn(32, 128)  # batch_size=32, features=128
    
    # 批归一化前
    print(f"  原始数据 Mean: {np.mean(x):.4f}, Std: {np.std(x):.4f}")
    
    # 批归一化后
    batch_mean = np.mean(x, axis=0)
    batch_var = np.var(x, axis=0)
    x_norm = (x - batch_mean) / np.sqrt(batch_var + 1e-5)
    
    print(f"  归一化后 Mean: {np.mean(x_norm):.4f}, Std: {np.std(x_norm):.4f}")
    print(f"  ✓ BatchNorm 使分布标准化，加速训练收敛")


def main():
    """运行所有演示"""
    print("\n" + "=" * 70)
    print("WEEK 5 PREVIEW: 权重初始化、梯度操作、模型分析")
    print("=" * 70)
    print("\n注: 这是 Week 5 计划功能的演示，展示将在 Week 5 实施的核心概念")
    
    demo_weight_initialization()
    demo_gradient_operations()
    demo_model_analysis()
    demo_batchnorm_preview()
    
    print("\n" + "=" * 70)
    print("WEEK 5 PREVIEW COMPLETED ✓")
    print("=" * 70)
    print("\n下周实施计划:")
    print("  ✓ 权重初始化: 7 个函数 + 7 个测试")
    print("  ✓ 梯度操作: 4 个函数 + 4 个测试")
    print("  ✓ 模型分析: 4 个函数 + 4 个测试")
    print("  ✓ BatchNorm: 3 个类 + 6 个测试")
    print("\n目标: 89% → 91% (+2%)")
    print("=" * 70)


if __name__ == '__main__':
    main()
