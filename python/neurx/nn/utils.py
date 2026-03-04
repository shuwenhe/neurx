"""
模型分析工具 (Model Analysis)

提供模型摘要、参数计数、FLOPs 估算等分析工具。

使用示例:
    from neurx.nn.utils import summary, count_parameters, count_flops
    
    # 打印模型摘要
    summary(model, input_shape=(32, 3, 224, 224))
    
    # 统计参数
    total_params = count_parameters(model)
    print(f"总参数数: {total_params:,}")
"""

import numpy as np


def count_parameters(model_or_layers):
    """
    统计模型或层的参数总数
    
    Args:
        model_or_layers: 模型或层列表
        
    Returns:
        int: 参数总数
    """
    total = 0
    
    if isinstance(model_or_layers, (list, tuple)):
        # 处理层列表
        for layer in model_or_layers:
            if isinstance(layer, dict):
                # 字典形式
                if 'weight' in layer and layer['weight'] is not None:
                    w = layer['weight']
                    total += int(np.prod(w.shape)) if hasattr(w, 'shape') else int(np.prod(w))
                if 'bias' in layer and layer['bias'] is not None:
                    b = layer['bias']
                    total += int(np.prod(b.shape)) if hasattr(b, 'shape') else int(np.prod(b))
            else:
                # 对象形式
                if hasattr(layer, 'weight'):
                    total += np.prod(layer.weight.shape) if hasattr(layer.weight, 'shape') else np.prod(layer.weight)
                if hasattr(layer, 'bias') and layer.bias is not None:
                    total += np.prod(layer.bias.shape) if hasattr(layer.bias, 'shape') else np.prod(layer.bias)
    else:
        # 处理单个模型
        if hasattr(model_or_layers, 'layers'):
            return count_parameters(model_or_layers.layers)
        elif hasattr(model_or_layers, 'weight'):
            total += np.prod(model_or_layers.weight.shape) if hasattr(model_or_layers.weight, 'shape') else np.prod(model_or_layers.weight)
            if hasattr(model_or_layers, 'bias') and model_or_layers.bias is not None:
                total += np.prod(model_or_layers.bias.shape) if hasattr(model_or_layers.bias, 'shape') else np.prod(model_or_layers.bias)
    
    return int(total)


def count_flops(layers_config):
    """
    估算模型的 FLOPs（浮点运算数）
    
    Args:
        layers_config: 层配置列表，每个配置是一个字典，包含:
            - 'type': 层类型 ('conv2d', 'linear', 'pooling' 等)
            - 相关的维度信息
            
    Returns:
        int: 总 FLOPs 数
    """
    total_flops = 0
    
    for config in layers_config:
        layer_type = config.get('type', '').lower()
        
        if layer_type == 'conv2d':
            # Conv2d FLOPs = 2 * kernel_h * kernel_w * in_ch * out_ch * out_h * out_w
            kernel_h = config.get('kernel_h', 1)
            kernel_w = config.get('kernel_w', 1)
            in_channels = config.get('in_channels', 1)
            out_channels = config.get('out_channels', 1)
            out_h = config.get('out_h', 1)
            out_w = config.get('out_w', 1)
            
            flops = 2 * kernel_h * kernel_w * in_channels * out_channels * out_h * out_w
            total_flops += flops
            
        elif layer_type == 'conv3d':
            # Conv3d FLOPs
            kernel_d = config.get('kernel_d', 1)
            kernel_h = config.get('kernel_h', 1)
            kernel_w = config.get('kernel_w', 1)
            in_channels = config.get('in_channels', 1)
            out_channels = config.get('out_channels', 1)
            out_d = config.get('out_d', 1)
            out_h = config.get('out_h', 1)
            out_w = config.get('out_w', 1)
            
            flops = 2 * kernel_d * kernel_h * kernel_w * in_channels * out_channels * out_d * out_h * out_w
            total_flops += flops
            
        elif layer_type == 'linear':
            # Linear FLOPs = 2 * in_features * out_features * batch_size
            in_features = config.get('in_features', 1)
            out_features = config.get('out_features', 1)
            batch_size = config.get('batch_size', 1)
            
            flops = 2 * in_features * out_features * batch_size
            total_flops += flops
            
        elif layer_type in ['maxpool', 'maxpool2d']:
            # MaxPool FLOPs = kernel_h * kernel_w * out_h * out_w * batch_size * channels
            kernel_h = config.get('kernel_h', 2)
            kernel_w = config.get('kernel_w', 2)
            out_h = config.get('out_h', 1)
            out_w = config.get('out_w', 1)
            channels = config.get('channels', 1)
            batch_size = config.get('batch_size', 1)
            
            flops = kernel_h * kernel_w * out_h * out_w * batch_size * channels
            total_flops += flops
            
        elif layer_type in ['avgpool', 'avgpool2d']:
            # AvgPool FLOPs
            flops = config.get('kernel_h', 2) * config.get('kernel_w', 2) * config.get('out_h', 1) * config.get('out_w', 1) * config.get('batch_size', 1) * config.get('channels', 1)
            total_flops += flops
    
    return int(total_flops)


def model_size(model_or_layers, precision_bytes=4):
    """
    估算模型大小（以字节为单位）
    
    Args:
        model_or_layers: 模型或层列表
        precision_bytes: 每个参数的字节数（默认 4 字节 = 32 位浮点）
        
    Returns:
        dict: 包含 'params', 'size_mb' 的字典
    """
    params = count_parameters(model_or_layers)
    size_bytes = params * precision_bytes
    size_mb = size_bytes / (1024 * 1024)
    
    return {
        'params': params,
        'size_bytes': size_bytes,
        'size_mb': round(size_mb, 2),
    }


def summary(model, layers_info=None, input_shape=None):
    """
    打印模型摘要
    
    Args:
        model: 模型对象或名称字符串
        layers_info: 层信息列表，每个元素为 {'name': str, 'shape': tuple}
        input_shape: 输入形状（用于计算参数）
        
    Returns:
        None（打印到标准输出）
    """
    print("\n" + "=" * 80)
    print(f"Model: {model if isinstance(model, str) else model.__class__.__name__}")
    print("=" * 80)
    print(f"{'Layer Name':<25} {'Output Shape':<25} {'Param Count':<15}")
    print("-" * 80)
    
    total_params = 0
    
    if layers_info:
        for layer in layers_info:
            name = layer.get('name', 'unknown')
            shape = layer.get('shape', ())
            
            # 计算该层参数数
            if 'param_count' in layer:
                params = layer['param_count']
            else:
                params = int(np.prod(shape)) if shape else 0
            
            total_params += params
            
            print(f"{name:<25} {str(shape):<25} {params:<15,}")
    
    print("-" * 80)
    print(f"{'Total':<25} {'':<25} {total_params:<15,}")
    print("=" * 80)
    
    # 估计模型大小
    size_info = model_size([{'params': total_params}] if isinstance(model, str) else [], precision_bytes=4)
    print(f"Trainable params: {total_params:,}")
    print(f"Model size: {size_info['size_mb']:.2f} MB")
    print("=" * 80 + "\n")


def analyze_network(layers_config):
    """
    综合分析网络
    
    Args:
        layers_config: 层配置列表
        
    Returns:
        dict: 包含 params, flops, size_mb 的分析结果
    """
    # 计算参数
    params = sum(
        int(np.prod(layer.get('shape', (1,)))) 
        for layer in layers_config 
        if 'shape' in layer
    )
    
    # 计算 FLOPs
    flops = count_flops(layers_config)
    
    # 估计大小
    size_mb = (params * 4) / (1024 * 1024)
    
    return {
        'params': params,
        'flops': flops,
        'size_mb': round(size_mb, 2),
        'flops_giga': round(flops / 1e9, 2),
    }


class ModelAnalyzer:
    """
    模型分析器
    
    便利的类用于分析模型的各个方面。
    """
    
    def __init__(self, model):
        """初始化分析器"""
        self.model = model
        self.layers = []
    
    def add_layer(self, name, shape):
        """添加层信息"""
        self.layers.append({'name': name, 'shape': shape})
        return self
    
    def get_summary(self):
        """获取模型摘要"""
        summary(self.model, self.layers)
    
    def get_param_count(self):
        """获取参数数量"""
        return count_parameters(self.layers)
    
    def get_size(self):
        """获取模型大小"""
        return model_size(self.layers)


__all__ = [
    'count_parameters',
    'count_flops',
    'model_size',
    'summary',
    'analyze_network',
    'ModelAnalyzer',
]
