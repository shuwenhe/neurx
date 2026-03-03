# Tensor 深度学习框架分析与 PyTorch 实现路线图

## 📊 一、现有功能总体分析

### 1. 核心框架基础
- ✅ **自动求导系统 (Autograd)**
  - 动态计算图构建
  - 链式法则反向传播 (`backward()`)
  - 梯度累积机制
  
- ✅ **张量 (Tensor) 对象**
  - NumPy 后端基础实现
  - 支持 CPU 和 CUDA 双设备
  - 基本的张量操作 (cat, stack, split, chunk 等)
  - 矩阵运算 (mm, bmm, matmul, inverse, svd, eig)

### 2. 神经网络层 (tensor.nn.modules)
已实现的层:

#### 基础层
| 层类型 | 实现状态 | 特性 |
|--------|--------|------|
| `Linear` | ✅ | 线性变换，支持 bias |
| `Embedding` | ✅ | 词嵌入，梯度更新支持 |
| `Dropout` | ✅ | 训练/评估模式切换 |
| `Module` 基类 | ✅ | 参数管理、状态字典 |
| `Parameter` | ✅ | 可训练参数包装 |

#### 归一化层
| 层类型 | 实现状态 | 特性 |
|--------|--------|------|
| `LayerNorm` | ✅ | 层归一化，支持 CUDA |
| `RMSNorm` | ✅ | 均方根归一化 (LLaMA 风格) |

#### 激活函数
| 激活函数 | 实现状态 | 特性 |
|---------|--------|------|
| `GELU` | ✅ | 高斯误差线性单元 (近似) |
| `Sigmoid` | ✅ | Sigmoid 激活 |
| `SiLU/Swish` | ✅ | Swish 激活 |

#### 注意力机制
| 组件 | 实现状态 | 特性 |
|-----|--------|------|
| `MultiHeadAttention` | ✅ | 多头自注意力 |
| 因果遮罩 | ✅ | 自回归生成 |
| RoPE (旋转位置编码) | ✅ | 支持可选 RoPE |
| KV Cache | ✅ | 推理加速 |

#### 容器类
| 容器 | 实现状态 | 特性 |
|-----|--------|------|
| `ModuleList` | ✅ | 模块列表管理 |
| `ModuleDict` | ✅ | 模块字典管理 |

#### 高级网络模块 (在 modules.py 中)
- `Softmax` - Softmax 激活
- `MLP` - 多层感知机 (包含 MoE 变体)
- `MoE` - 混合专家网络
- 其他注意力变体

### 3. 优化器 (tensor.optim)
| 优化器 | 实现状态 | 特性 |
|-------|--------|------|
| `AdamW` | ✅ | Adam with Weight Decay |
| `clip_grad_norm` | ✅ | 梯度裁剪 |
| `Optimizer` 基类 | ✅ | 通用优化器接口 |

### 4. 损失函数 (tensor.losses)
| 损失函数 | 实现状态 | 用途 |
|---------|--------|------|
| `cross_entropy` | ✅ | 交叉熵损失 |
| `cross_entropy_loss` | ✅ | 标量损失版本 |

### 5. 训练工具 (tensor.training)
| 工具 | 实现状态 | 功能 |
|-----|--------|------|
| `run_training_loop` | ✅ | 标准训练循环 |
| `CheckpointManager` | ✅ | 检查点管理 |
| `TrainingLogger` | ✅ | 训练日志记录 |
| `autocast` (AMP) | ✅ | 自动混合精度 |
| `GradScaler` | ✅ | 梯度缩放 |

### 6. 数据管道 (tensor.data)
| 组件 | 实现状态 | 功能 |
|-----|--------|------|
| `Dataset` | ✅ | 数据集基类 |
| `DataLoader` | ✅ | 数据加载器 |

### 7. CUDA 扩展 (tensor.cuda)
| 功能 | 实现状态 | 操作 |
|-----|--------|------|
| GPU 张量 | ✅ | 内存管理 |
| 算术运算 | ✅ | add, mul, bias_add, matmul |
| LayerNorm | ✅ | GPU 优化 |
| Softmax | ✅ | GPU 优化 |
| 归约操作 | ✅ | sum, mean, max, min |

### 8. 运行时平台 (tensor.platform)
| 组件 | 实现状态 | 功能 |
|-----|--------|------|
| `RuntimeConfig` | ✅ | 配置管理 |
| `doctor` | ✅ | 诊断工具 |
| 环境变量配置 | ✅ | TENSOR_DEVICE, TENSOR_LOG_LEVEL 等 |

### 9. 编译 API (tensor.compile)
| 功能 | 实现状态 | 状态 |
|-----|--------|------|
| `compile_module` | ✅ | API 边界定义 |
| 图编译 | 📋 | 规划中 |
| 内核融合 | 📋 | 规划中 |

### 10. 分布式 (tensor.distributed)
| 功能 | 实现状态 | 状态 |
|-----|--------|------|
| `detect_distributed_config` | ✅ | 配置检测 |
| 分布式启动器 | 📋 | 规划中 |

---

## 🎯 二、PyTorch 兼容层实现路线图

### 第一阶段：API 兼容性层 (基础)

#### Phase 1.1: 张量 API 对齐
```python
# tensor/pytorch_compat/tensor_api.py
- torch.Tensor 兼容的属性访问
- .shape, .dtype, .device 属性
- .to(device) 设备转移
- .clone(), .detach(), .requires_grad_() 方法
- 广播规则对齐
- 索引和切片 (getitem, setitem)
```

**优先度**: 🔴 **必须**

#### Phase 1.2: 操作算子兼容 (torch.nn.functional)
```python
# tensor/pytorch_compat/functional.py
- F.linear(input, weight, bias)
- F.conv2d / F.conv1d (如果支持卷积)
- F.relu, F.gelu, F.sigmoid, F.softmax
- F.layer_norm, F.batch_norm
- F.dropout
- F.embedding
- F.cross_entropy, F.mse_loss
- F.attention, F.scaled_dot_product_attention
```

**优先度**: 🔴 **必须**

#### Phase 1.3: 通用 Module 包装
```python
# tensor/pytorch_compat/modules_wrapper.py
class TorchModuleAdapter(Module):
    """将 PyTorch 模块自动包装为 tensor 框架兼容"""
    def forward(self, *args, **kwargs):
        # 自动转换输入/输出
        pass

class TensorModuleTorch(torch.nn.Module):
    """将 tensor 模块包装为 PyTorch 兼容"""
    def forward(self, *args, **kwargs):
        pass
```

**优先度**: 🟡 **重要**

---

### 第二阶段：模型加载与保存 (互操作性)

#### Phase 2.1: 模型权重转换
```python
# tensor/pytorch_compat/weight_conversion.py
- 从 PyTorch state_dict 加载到 tensor
- 从 tensor state_dict 导出为 PyTorch 格式
- 处理命名约定差异
- 权重格式对齐 (转置等)

函数:
- load_pytorch_checkpoint(model, path)
- save_as_pytorch_checkpoint(model, path)
- convert_pytorch_weights(state_dict, reverse=False)
```

**优先度**: 🔴 **必须**

#### Phase 2.2: 模型架构映射
```python
# tensor/pytorch_compat/model_mapping.py
预定义映射:
- Linear ↔ torch.nn.Linear
- LayerNorm ↔ torch.nn.LayerNorm
- Embedding ↔ torch.nn.Embedding
- Dropout ↔ torch.nn.Dropout
- MultiHeadAttention ↔ torch.nn.MultiheadAttention
```

**优先度**: 🟡 **重要**

---

### 第三阶段：推理与导出 (生产就绪)

#### Phase 3.1: ONNX 导出
```python
# tensor/pytorch_compat/onnx_export.py
- export_to_onnx(model, input_shape, output_path)
- 支持动态批大小
- 优化器追踪
```

**优先度**: 🟡 **重要**

#### Phase 3.2: TorchScript 兼容
```python
# tensor/pytorch_compat/torchscript.py
- JIT 编译追踪
- 静态类型注解
- 序列化格式
```

**优先度**: 🟡 **重要**

#### Phase 3.3: 量化与剪枝
```python
# tensor/pytorch_compat/quantization.py
- 动态量化
- 静态量化
- 结构化剪枝
```

**优先度**: 🟢 **可选** (后期)

---

### 第四阶段：运行时融合 (高性能)

#### Phase 4.1: 融合算子
```python
# tensor/pytorch_compat/fused_ops.py
- fused_linear_gelu
- fused_linear_dropout
- fused_attention
- fused_normalization_linear
```

**优先度**: 🟢 **可选** (优化阶段)

#### Phase 4.2: 混合精度训练 (AMP)
```python
# tensor/pytorch_compat/amp.py
- torch.cuda.amp.autocast() 兼容
- torch.cuda.amp.GradScaler() 兼容
```

**优先度**: 🟡 **重要** (CUDA 场景)

---

## 🛠️ 三、实现建议与最佳实践

### 3.1 架构设计
```
tensor/
  pytorch_compat/
    __init__.py                 # 公共 API 导出
    tensor_api.py               # Tensor 属性/方法
    functional.py               # F.* 操作
    modules_wrapper.py          # 模块适配器
    weight_conversion.py        # 权重加载/保存
    model_mapping.py            # 架构映射
    onnx_export.py             # ONNX 导出
    torchscript.py             # TorchScript
    fused_ops.py               # 融合算子
    amp.py                     # 混合精度
    test_pytorch_compat.py     # 集成测试
```

### 3.2 优先级建议

**第一个月** (MVP)：
1. Phase 1.1: 张量 API 对齐 (必须)
2. Phase 1.2: 核心操作 (必须)
3. Phase 2.1: 权重转换 (必须)

**第二个月** (扩展):
1. Phase 1.3: 模块适配器
2. Phase 2.2: 模型映射
3. Phase 4.2: AMP 支持

**第三个月** (优化):
1. Phase 3.1: ONNX 导出
2. Phase 4.1: 融合算子
3. 性能优化与基准测试

### 3.3 测试策略
```python
# tests/test_pytorch_compat.py

def test_tensor_properties():
    """测试 Tensor 属性兼容性"""
    pass

def test_functional_ops():
    """测试 F.* 操作数值正确性"""
    # 与 PyTorch 结果对比
    pass

def test_module_forward_backward():
    """测试模块前向和反向传播"""
    pass

def test_checkpoint_conversion():
    """测试检查点转换"""
    pass

def test_numerical_precision():
    """数值精度测试"""
    # FP32, FP16, BF16
    pass
```

### 3.4 性能基准
```python
# tools/benchmark_pytorch_compat.py
- 与官方 PyTorch 的性能对比
- 内存占用测试
- 推理延迟测试
```

---

## 📈 四、实施步骤示例

### 示例 1: 实现 torch.nn.functional.linear

```python
# tensor/pytorch_compat/functional.py

import numpy as np
from tensor.tensor import Tensor
from tensor.nn.modules import Linear

def linear(input: Tensor, weight: Tensor, bias: Tensor = None) -> Tensor:
    """
    PyTorch 兼容的线性层函数
    
    Args:
        input: (..., in_features) 输入张量
        weight: (out_features, in_features) 权重矩阵
        bias: (out_features,) 可选偏置
    
    Returns:
        输出张量 (..., out_features)
    """
    # 确保输入为 Tensor
    if not isinstance(input, Tensor):
        input = Tensor(input)
    if not isinstance(weight, Tensor):
        weight = Tensor(weight)
    
    # 执行矩阵乘法
    # PyTorch: input @ weight.T
    # 我们的框架: input @ weight
    output = input @ weight  # 假设权重格式匹配
    
    if bias is not None:
        if not isinstance(bias, Tensor):
            bias = Tensor(bias)
        output = output + bias
    
    return output
```

### 示例 2: 权重转换

```python
# tensor/pytorch_compat/weight_conversion.py

def load_pytorch_checkpoint(tensor_model, pytorch_checkpoint_path):
    """从 PyTorch 检查点加载权重"""
    import torch
    
    # 加载 PyTorch 模型
    torch_state = torch.load(pytorch_checkpoint_path)
    
    # 转换权重格式
    tensor_state = {}
    for name, param in torch_state.items():
        # 转换为 NumPy
        numpy_param = param.detach().cpu().numpy()
        
        # 处理 Linear 层: PyTorch 是 (out, in) 需要转置
        if 'weight' in name and param.dim() == 2:
            numpy_param = numpy_param.T
        
        tensor_state[name] = numpy_param
    
    # 加载到 tensor 模型
    tensor_model.load_state_dict(tensor_state)
```

---

## 🔗 五、与现有功能的集成点

### 5.1 利用现有强项
- ✅ **Autograd 系统**: 直接使用现有反向传播
- ✅ **CUDA 支持**: 融合 CUDA 算子
- ✅ **Module 系统**: 扩展现有的 Module 基类
- ✅ **检查点机制**: 重用 CheckpointManager
- ✅ **训练循环**: 兼容 run_training_loop

### 5.2 需要完善的部分
- 📌 **归约操作** (sum, mean 对齐)
- 📌 **广播规则** (NumPy 广播兼容)
- 📌 **卷积支持** (如果要支持 CV 模型)
- 📌 **Batch Norm** (目前无实现)

---

## 📝 六、快速开始方案

### 最小可行产品 (MVP)

创建一个最小的 PyTorch 兼容层:

```python
# tensor/pytorch_compat/__init__.py

from .tensor_api import make_torch_compatible
from .functional import linear, relu, gelu, layer_norm
from .weight_conversion import load_pytorch_checkpoint, save_pytorch_checkpoint

__all__ = [
    "make_torch_compatible",
    "linear", "relu", "gelu", "layer_norm",
    "load_pytorch_checkpoint", "save_pytorch_checkpoint",
]

def make_torch_compatible(tensor_model):
    """将 tensor 模型包装为 PyTorch 兼容"""
    # 动态添加 PyTorch 风格的方法
    pass
```

### 测试用例

```python
# tests/test_pytorch_basic.py

import tensor as t
from tensor.pytorch_compat import linear, load_pytorch_checkpoint

def test_linear_forward():
    """测试线性层与 PyTorch 数值一致"""
    # 创建输入
    x = t.Tensor(np.random.randn(2, 10))
    w = t.Tensor(np.random.randn(10, 5))
    b = t.Tensor(np.zeros(5))
    
    # 前向传播
    y = linear(x, w, b)
    
    # 验证形状
    assert y.shape == (2, 5)
    
    # 验证与 PyTorch 一致
    import torch
    x_torch = torch.tensor(x.data)
    w_torch = torch.tensor(w.data.T)  # 转置
    b_torch = torch.tensor(b.data)
    y_torch = torch.nn.functional.linear(x_torch, w_torch, b_torch)
    
    np.testing.assert_allclose(y.data, y_torch.numpy(), rtol=1e-5)
```

---

## 🎯 总结

| 方面 | 现状 | PyTorch 兼容层目标 |
|-----|------|-----------------|
| **张量操作** | 基础完整 | API 对齐 |
| **模块系统** | 完整 | 权重转换 |
| **优化器** | AdamW | 兼容加载 |
| **推理** | 支持 | ONNX/TorchScript |
| **性能** | NumPy 基础 | 融合算子 |
| **生态** | 独立框架 | 互操作性 |

通过实现 PyTorch 兼容层，可以:
1. 重用海量 PyTorch 预训练模型
2. 降低用户迁移成本
3. 对标业界标准
4. 扩大框架应用范围
5. 建立良好的生态

**建议首先从 Phase 1 (API 兼容性) 开始，这样可以最快实现最大的兼容性价值！**
