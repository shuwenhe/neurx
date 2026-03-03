# PyTorch 兼容层实现指南

## 📋 快速参考

### 已创建的文件结构

```
tensor/
└── python/tensor/pytorch_compat/
    ├── __init__.py                 # 公共 API 导出
    ├── tensor_api.py               # Tensor 属性/方法增强
    ├── functional.py               # torch.nn.functional 兼容函数
    ├── weight_conversion.py        # 权重加载/保存
    └── modules_wrapper.py          # PyTorch 模块适配器

pytorch_compat_examples.py          # 使用示例和测试
```

---

## 🚀 快速开始

### 1. 导入和基本使用

```python
from tensor import Tensor
from tensor.pytorch_compat import linear, relu, gelu, softmax
import numpy as np

# 创建张量
x = Tensor(np.random.randn(2, 10))
w = Tensor(np.random.randn(10, 5))
b = Tensor(np.zeros(5))

# 使用函数式接口
y = linear(x, w, b)
y = relu(y)
y = softmax(y, dim=-1)

print(y.shape)  # (2, 5)
```

### 2. 张量 API 对齐

```python
x = Tensor(np.random.randn(2, 3, 4))

# PyTorch 兼容的属性
print(x.shape)    # (2, 3, 4)
print(x.ndim)     # 3
print(x.dtype)    # 'float64'
print(x.device)   # 'cpu'

# PyTorch 兼容的方法
x_cloned = x.clone()
x_detached = x.detach()
x = x.requires_grad_(True)
x = x.to('cpu')

# 形状操作
y = x.reshape(2, -1)
y = x.unsqueeze(0)
y = x.squeeze()

# 聚合操作
s = x.sum(dim=1)
m = x.mean(dim=2)
```

### 3. 权重转换

```python
from tensor.pytorch_compat import load_pytorch_checkpoint, save_pytorch_checkpoint

# 从 PyTorch 加载
model = MyTensorModel()
result = load_pytorch_checkpoint(model, 'pytorch_model.pt')
print(result['missing'], result['unexpected'])

# 保存为 PyTorch 格式
save_pytorch_checkpoint(
    model, 
    'tensor_model_as_pytorch.pt',
    additional_info={'epoch': 10, 'loss': 0.5}
)
```

### 4. 模块适配

```python
from tensor.pytorch_compat import wrap_pytorch_module, wrap_tensor_module

# 包装 PyTorch 模块
pytorch_linear = torch.nn.Linear(10, 5)
adapter = wrap_pytorch_module(pytorch_linear)

x = Tensor(np.random.randn(2, 10))
y = adapter(x)  # 自动转换输入/输出

# 包装 tensor 模块
tensor_model = MyTensorModel()
torch_compatible = wrap_tensor_module(tensor_model)

x = torch.randn(2, 10)
y = torch_compatible(x)  # 返回 torch.Tensor
```

---

## 📚 API 文档

### 函数式接口 (tensor.pytorch_compat.functional)

| 函数 | 签名 | 说明 |
|------|------|------|
| `linear` | `linear(input, weight, bias=None)` | 线性变换 |
| `relu` | `relu(input)` | ReLU 激活 |
| `gelu` | `gelu(input, approximate=False)` | GELU 激活 |
| `sigmoid` | `sigmoid(input)` | Sigmoid 激活 |
| `softmax` | `softmax(input, dim=-1)` | Softmax |
| `layer_norm` | `layer_norm(input, normalized_shape, weight=None, bias=None, eps=1e-5)` | 层归一化 |
| `dropout` | `dropout(input, p=0.5, training=True, inplace=False)` | Dropout |
| `embedding` | `embedding(input, weight, padding_idx=None)` | 嵌入层 |
| `cross_entropy` | `cross_entropy(input, target, reduction='mean')` | 交叉熵损失 |

### 张量 API 增强

| 属性/方法 | 类型 | 说明 |
|----------|------|------|
| `.shape` | 属性 | 张量形状 |
| `.ndim` | 属性 | 维度数 |
| `.dtype` | 属性 | 数据类型 |
| `.device` | 属性 | 所在设备 |
| `.clone()` | 方法 | 克隆张量 |
| `.detach()` | 方法 | 分离梯度 |
| `.to(device)` | 方法 | 转移设备 |
| `.requires_grad_(True/False)` | 方法 | 设置梯度需求 |
| `.zero_grad()` | 方法 | 梯度清零 |
| `.item()` | 方法 | 获取标量值 |
| `.numel()` | 方法 | 元素总数 |
| `.reshape(*shape)` | 方法 | 改变形状 |
| `.transpose(dim0, dim1)` | 方法 | 转置维度 |
| `.permute(*dims)` | 方法 | 排列维度 |
| `.squeeze(dim=None)` | 方法 | 移除维度 |
| `.unsqueeze(dim)` | 方法 | 插入维度 |
| `.sum(dim=None, keepdim=False)` | 方法 | 求和 |
| `.mean(dim=None, keepdim=False)` | 方法 | 均值 |

### 权重转换 (tensor.pytorch_compat.weight_conversion)

| 函数 | 说明 |
|------|------|
| `load_pytorch_checkpoint(model, path, strict=True, device='cpu')` | 从 PyTorch 检查点加载 |
| `save_pytorch_checkpoint(model, path, additional_info=None)` | 保存为 PyTorch 格式 |
| `pytorch_state_to_tensor(state_dict, layer_mapping=None)` | 转换权重格式 |
| `tensor_state_to_pytorch(state_dict, layer_mapping=None)` | 反向转换 |
| `load_huggingface_weights(model, model_name_or_path, device='cpu')` | 从 HF Hub 加载 |

### 模块适配 (tensor.pytorch_compat.modules_wrapper)

| 类 | 说明 |
|----|------|
| `TorchModuleAdapter` | 将 PyTorch 模块适配到 tensor 框架 |
| `TensorModuleTorch` | 将 tensor 模块适配到 PyTorch 接口 |

---

## 💡 最佳实践

### 1. 数值精度

确保转换后的权重数值一致：

```python
import numpy as np

# 验证转换
pytorch_state = pytorch_model.state_dict()
tensor_state = pytorch_state_to_tensor(pytorch_state)

for name, param in pytorch_state.items():
    torch_data = param.detach().cpu().numpy()
    tensor_data = tensor_state[name]
    
    # 检查是否需要转置
    if torch_data.ndim == 2:
        torch_data = torch_data.T
    
    assert np.allclose(torch_data, tensor_data, rtol=1e-5)
```

### 2. 批量转换

对于大型模型，使用批量转换来节省内存：

```python
def batch_convert_checkpoint(pytorch_ckpt_path, tensor_model, batch_size=1000):
    """分批加载大型检查点"""
    import torch
    
    checkpoint = torch.load(pytorch_ckpt_path)
    state_dict = checkpoint['state_dict']
    
    # 分批处理
    keys = list(state_dict.keys())
    for i in range(0, len(keys), batch_size):
        batch_keys = keys[i:i+batch_size]
        batch_state = {k: state_dict[k] for k in batch_keys}
        
        tensor_batch = pytorch_state_to_tensor(batch_state)
        tensor_model.load_state_dict(tensor_batch, strict=False)
```

### 3. 设备管理

正确处理不同设备上的张量：

```python
# CPU 到 CUDA
x_cpu = Tensor(np.random.randn(2, 10))
x_cuda = x_cpu.to('cuda')

# CUDA 到 CPU
x_back = x_cuda.to('cpu')

# 检查设备
assert x_cuda.device == 'cuda'
assert x_back.device == 'cpu'
```

### 4. 梯度管理

在推理时禁用梯度计算以节省内存：

```python
model.eval()

# 或使用上下文管理器
x.requires_grad_(False)

# 前向传播 (无梯度)
with torch.no_grad():  # 如果与 PyTorch 混合使用
    y = model(x)
```

---

## 🧪 测试

运行示例测试：

```bash
cd /home/shuwen/tensor
python pytorch_compat_examples.py
```

预期输出：
```
############################################################
# PyTorch 兼容层示例
############################################################

============================================================
示例 1: 函数式 API
============================================================
linear: input (2, 10) -> output (2, 5)
relu: (2, 5) -> (2, 5)
...

============================================================
示例 2: 张量 API 对齐
============================================================
shape: (2, 3, 4)
ndim: 3
dtype: float64
device: cpu
...
```

---

## 🔄 与 PyTorch 的互操作

### 从 PyTorch 迁移到 tensor

```python
# PyTorch 代码
import torch
model = torch.nn.Linear(10, 5)
x = torch.randn(2, 10)
y = model(x)

# 转换为 tensor
from tensor.pytorch_compat import load_pytorch_checkpoint, wrap_tensor_module

tensor_model = MyTensorLinear(10, 5)
load_pytorch_checkpoint(tensor_model, 'pytorch_model.pt')

x_tensor = Tensor(x.numpy())
y_tensor = tensor_model(x_tensor)
```

### 从 tensor 迁移到 PyTorch

```python
# tensor 代码
from tensor import Tensor
from tensor.nn.modules import Linear

model = Linear(10, 5)
x = Tensor(np.random.randn(2, 10))
y = model(x)

# 转换为 PyTorch
from tensor.pytorch_compat import save_pytorch_checkpoint, wrap_tensor_module

save_pytorch_checkpoint(model, 'model_as_pytorch.pt')

torch_model = wrap_tensor_module(model)
x_torch = torch.from_numpy(x.data)
y_torch = torch_model(x_torch)
```

---

## 🐛 常见问题

### Q1: 权重转置问题

**问题**: 加载的权重形状不匹配

**解决**: PyTorch Linear 权重是 (out_features, in_features)，而 tensor 可能期望 (in_features, out_features)。

```python
# 自动处理
tensor_state = pytorch_state_to_tensor(pytorch_state)
# 已自动转置 Linear 层的权重
```

### Q2: 数值不一致

**问题**: 转换后的数值略有不同

**解决**: 检查数据类型和精度

```python
# 确保使用相同的数据类型
assert pytorch_param.dtype == torch.float32
assert tensor_param.dtype == np.float32

# 使用合适的容差进行比较
np.testing.assert_allclose(pytorch_data, tensor_data, rtol=1e-5, atol=1e-7)
```

### Q3: 模块参数未更新

**问题**: 加载权重后参数未改变

**解决**: 确保使用 `strict=False` 或检查参数名称

```python
# 查看缺失的参数
result = tensor_model.load_state_dict(tensor_state, strict=False)
print(result['missing'])
```

---

## 📈 后续开发方向

### Phase 2 (已规划)

- [ ] Batch Normalization 支持
- [ ] 卷积层支持 (Conv1d, Conv2d)
- [ ] 更多优化器 (SGD, Adam, etc.)
- [ ] 序列化格式优化

### Phase 3 (长期)

- [ ] ONNX 导出支持
- [ ] TorchScript 兼容
- [ ] 量化和剪枝
- [ ] 分布式训练支持

---

## 📞 获取帮助

如有问题，请参考：

1. **官方文档**: `/home/shuwen/tensor/FRAMEWORK_ANALYSIS_AND_PYTORCH_ROADMAP.md`
2. **示例代码**: `/home/shuwen/tensor/pytorch_compat_examples.py`
3. **测试用例**: `/home/shuwen/tensor/tests/test_pytorch_compat.py` (待创建)

---

## ✅ 检查清单

在使用 PyTorch 兼容层时，确保：

- [ ] `tensor` 框架已正确安装
- [ ] NumPy 版本 >= 1.20
- [ ] Python 版本 >= 3.8
- [ ] (可选) PyTorch 已安装用于权重转换
- [ ] (可选) transformers 已安装用于 HuggingFace 模型加载

---

**版本**: 0.1.0  
**最后更新**: 2026-03-03
