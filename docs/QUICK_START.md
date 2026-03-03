<!-- 快速参考卡片 -->
# PyTorch 兼容层 - 快速参考

## 🔴 一句话总结
tensor 框架 + PyTorch API = 无缝互操作！

---

## 📦 三步开始使用

### 1️⃣ 安装 (已完成)
```bash
# PyTorch 兼容层已在:
/home/shuwen/tensor/python/tensor/pytorch_compat/
```

### 2️⃣ 导入
```python
from tensor import Tensor
from tensor.pytorch_compat import linear, relu, gelu, softmax
```

### 3️⃣ 使用
```python
x = Tensor(np.random.randn(2, 10))
y = linear(x, w, b)
y = relu(y)
```

---

## 🎯 最常用的 API

| 功能 | 代码 |
|------|------|
| **张量属性** | `x.shape`, `x.ndim`, `x.dtype`, `x.device` |
| **张量方法** | `x.clone()`, `x.reshape()`, `x.to('cuda')` |
| **线性层** | `y = linear(x, weight, bias)` |
| **激活函数** | `y = relu(x)`, `y = gelu(x)`, `y = sigmoid(x)` |
| **归一化** | `y = layer_norm(x, normalized_shape)` |
| **权重加载** | `load_pytorch_checkpoint(model, 'model.pt')` |
| **权重保存** | `save_pytorch_checkpoint(model, 'model.pt')` |

---

## 💾 权重互转

```python
# PyTorch → tensor
from tensor.pytorch_compat import pytorch_state_to_tensor
tensor_state = pytorch_state_to_tensor(pytorch_state_dict)

# tensor → PyTorch  
from tensor.pytorch_compat import tensor_state_to_pytorch
pytorch_state = tensor_state_to_pytorch(tensor_state_dict)
```

---

## 📊 框架现有功能

| 功能 | 状态 | 
|------|------|
| 自动求导 | ✅ 完整 |
| 神经网络层 | ✅ 完整 |
| 优化器 (AdamW) | ✅ 完整 |
| 损失函数 | ✅ 完整 |
| 训练工具 | ✅ 完整 |
| GPU 支持 | ✅ 完整 |
| PyTorch 兼容 | ✅ 新增 |

---

## 🧪 运行示例

```bash
python /home/shuwen/tensor/pytorch_compat_examples.py
```

---

## 📚 详细文档

| 文档 | 内容 |
|------|------|
| `PYTORCH_COMPAT_GUIDE.md` | 完整 API 参考 |
| `FRAMEWORK_ANALYSIS_AND_PYTORCH_ROADMAP.md` | 框架分析与路线图 |
| `IMPLEMENTATION_SUMMARY.md` | 实现总结 |
| `pytorch_compat_examples.py` | 代码示例 |

---

## ⚡ 常见操作模式

### 模式 1: 加载 PyTorch 权重
```python
model = TensorModel()
load_pytorch_checkpoint(model, 'pytorch_weights.pt')
```

### 模式 2: 转换输入格式
```python
x_torch = torch.randn(2, 10)
x_tensor = Tensor(x_torch.numpy())
y_tensor = model(x_tensor)
y_torch = torch.from_numpy(y_tensor.data)
```

### 模式 3: 混合使用
```python
# 在 tensor 中使用 PyTorch 模块
pytorch_layer = torch.nn.Linear(10, 5)
adapter = wrap_pytorch_module(pytorch_layer)
y = adapter(x_tensor)
```

---

## 🔗 快速导航

```
项目根目录:                /home/shuwen/tensor
PyTorch 兼容层:            /home/shuwen/tensor/python/tensor/pytorch_compat
示例代码:                 /home/shuwen/tensor/pytorch_compat_examples.py
实现指南:                 /home/shuwen/tensor/PYTORCH_COMPAT_GUIDE.md
框架分析:                 /home/shuwen/tensor/FRAMEWORK_ANALYSIS_AND_PYTORCH_ROADMAP.md
完整总结:                 /home/shuwen/tensor/IMPLEMENTATION_SUMMARY.md
```

---

## ✅ 验证你的安装

```python
from tensor import Tensor
from tensor.pytorch_compat import linear, relu

# 如果没有错误，说明安装成功! ✅
print("✅ PyTorch 兼容层已就绪")
```

---

## 🚀 3 分钟快速开始

```python
import numpy as np
from tensor import Tensor
from tensor.pytorch_compat import linear, relu, gelu

# 1. 创建张量
x = Tensor(np.random.randn(2, 10))

# 2. 使用兼容的操作
w = Tensor(np.random.randn(10, 20))
b = Tensor(np.zeros(20))

# 3. 前向传播
y = linear(x, w, b)
y = relu(y)
y = gelu(y)

print(f"输出形状: {y.shape}")  # (2, 20)

# 4. 反向传播
loss = y.sum()
loss.backward()

# 5. 检查梯度
print(f"权重梯度形状: {w.grad.shape}")  # (10, 20)
```

---

## 🎓 学习路径

1. **新手** → `pytorch_compat_examples.py`
2. **开发者** → `PYTORCH_COMPAT_GUIDE.md`
3. **深度学习** → `FRAMEWORK_ANALYSIS_AND_PYTORCH_ROADMAP.md`

---

## 🐛 常见问题 FAQ

**Q: tensor 框架与 PyTorch 有何不同?**  
A: tensor 用 NumPy 实现,更易理解源码;PyTorch 性能更好。兼容层让两者结合!

**Q: 性能如何?**  
A: NumPy 实现易于学习和调试。生产环境可用 CUDA 加速。

**Q: 如何加载预训练模型?**  
A: 用 `load_pytorch_checkpoint()` 从 PyTorch 格式直接加载!

**Q: 支持分布式训练吗?**  
A: 框架支持分布式配置检测,完整支持在规划中。

---

## 💡 Tips & Tricks

- 🔥 用 `.to('cuda')` 切换到 GPU 加速
- 🎯 用 `.detach()` 分离不需要梯度的张量
- 📊 用 `.clone()` 创建独立副本
- ⚡ 在评估时用 `model.eval()` 禁用 Dropout

---

**版本**: 1.0.0  
**发布**: 2026-03-03  
**状态**: ✅ 生产就绪

---

📖 [完整指南](PYTORCH_COMPAT_GUIDE.md) | 🔗 [框架分析](FRAMEWORK_ANALYSIS_AND_PYTORCH_ROADMAP.md) | 💻 [代码示例](pytorch_compat_examples.py)
