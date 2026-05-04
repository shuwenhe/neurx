# Tensor Framework - 新增功能说明

## 🎉 最新更新 (2026-03-03)

本次更新为Tensor框架添加了一系列重要功能，显著缩小了与PyTorch的差距。

---

## 📦 新增模块

### 1. **Einstein Summation (einsum)**

高效的张量运算工具，支持复杂的多维数组操作。

```python
import neurx

# 矩阵乘法
A = neurx.rand((3, 4))
B = neurx.rand((4, 5))
C = neurx.einsum('ij,jk->ik', A, B)

# 批量矩阵乘法
A = neurx.rand((10, 3, 4))
B = neurx.rand((10, 4, 5))
C = neurx.einsum('bij,bjk->bik', A, B)

# 矩阵的迹
A = neurx.rand((5, 5))
trace = neurx.einsum('ii', A)

# 转置
A_T = neurx.einsum('ij->ji', A)

# 批量点积
dots = neurx.einsum('bi,bi->b', A, B)
```

**特性：**
- ✅ 支持任意维度的张量操作
- ✅ 自动求导支持
- ✅ CPU/CUDA设备支持
- ✅ 与numpy.einsum兼容的语法

---

### 2. **Vision Module (neurx.vision)**

计算机视觉工具包，包含图像变换和预训练模型。

#### 2.1 图像变换 (neurx.vision.transforms)

```python
from neurx.vision import transforms

# 基础变换
transform = transforms.Compose([
    transforms.Resize(256),                    # 调整大小
    transforms.CenterCrop(224),                # 中心裁剪
    transforms.ToTensor(),                     # 转换为张量
    transforms.Normalize(                      # 归一化
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )
])

# 应用变换
from PIL import Image
img = Image.open('image.jpg')
tensor_img = transform(img)
```

**可用的变换：**

| 变换 | 功能 | 示例 |
|------|------|------|
| `ToTensor` | PIL Image → Tensor (C×H×W) | `ToTensor()` |
| `Normalize` | 标准化 (减均值除标准差) | `Normalize(mean=[0.5], std=[0.5])` |
| `Resize` | 调整图像大小 | `Resize(256)` 或 `Resize((224, 224))` |
| `CenterCrop` | 中心裁剪 | `CenterCrop(224)` |
| `RandomCrop` | 随机裁剪 | `RandomCrop(224, padding=4)` |
| `RandomHorizontalFlip` | 随机水平翻转 | `RandomHorizontalFlip(p=0.5)` |
| `RandomVerticalFlip` | 随机垂直翻转 | `RandomVerticalFlip(p=0.5)` |
| `ColorJitter` | 随机颜色抖动 | `ColorJitter(brightness=0.2, contrast=0.2)` |
| `Compose` | 组合多个变换 | `Compose([transform1, transform2])` |

#### 2.2 预训练模型 (neurx.vision.models)

```python
from neurx.vision import models

# 创建ResNet-18模型 (ImageNet分类)
model = models.resnet18(num_classes=1000)

# 创建ResNet-18模型 (CIFAR-10分类)
model = models.resnet18(num_classes=10)

# 前向传播
output = model(input_tensor)  # input: (N, 3, 224, 224)
```

**可用的模型：**

| 模型 | 参数量 | 层数 | 用途 |
|------|--------|------|------|
| `resnet18` | ~11M | 18 | 图像分类 |
| `resnet34` | ~21M | 34 | 图像分类 |
| `resnet50` | ~25M | 50 | 图像分类 |
| `resnet101` | ~44M | 101 | 图像分类 |
| `resnet152` | ~60M | 152 | 图像分类 |

**注意：** 预训练权重尚未提供，但模型结构完整可用于从头训练。

---

## 🚀 完整示例

### 示例1：使用ResNet-18进行CIFAR-10分类

```python
import neurx
from neurx.vision import transforms, models
from neurx.data import DataLoader, TensorDataset

# 1. 准备数据变换
train_transform = transforms.Compose([
    transforms.RandomCrop(32, padding=4),
    transforms.RandomHorizontalFlip(),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.4914, 0.4822, 0.4465],
                        std=[0.2023, 0.1994, 0.2010])
])

# 2. 创建模型
model = models.resnet18(num_classes=10)

# 3. 定义优化器和损失函数
optimizer = neurx.optim.AdamW(model.parameters(), lr=0.001)
criterion = neurx.nn.CrossEntropyLoss()

# 4. 训练循环
for epoch in range(10):
    for batch_idx, (images, labels) in enumerate(train_loader):
        # 前向传播
        outputs = model(images)
        loss = criterion(outputs, labels)
        
        # 反向传播
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        
        if batch_idx % 100 == 0:
            print(f'Epoch [{epoch}] Batch [{batch_idx}] Loss: {loss.to_numpy():.4f}')
```

### 示例2：使用einsum进行高级张量操作

```python
import neurx

# 注意力机制中的计算
Q = neurx.rand((32, 8, 64, 64))  # (batch, heads, seq_len, dim)
K = neurx.rand((32, 8, 64, 64))
V = neurx.rand((32, 8, 64, 64))

# 计算注意力分数: Q @ K^T
attn_scores = neurx.einsum('bhqd,bhkd->bhqk', Q, K)

# 应用softmax
attn_probs = neurx.nn.functional.softmax(attn_scores, axis=-1)

# 加权求和: attn_probs @ V
output = neurx.einsum('bhqk,bhkd->bhqd', attn_probs, V)
```

### 示例3：数据增强流水线

```python
from neurx.vision import transforms

# 训练集增强
train_transform = transforms.Compose([
    transforms.Resize(256),
    transforms.RandomCrop(224),
    transforms.RandomHorizontalFlip(p=0.5),
    transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                        std=[0.229, 0.224, 0.225])
])

# 验证集变换（无增强）
val_transform = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                        std=[0.229, 0.224, 0.225])
])
```

---

## 📊 与PyTorch的兼容性

### API兼容性

| 功能 | PyTorch | Tensor | 兼容性 |
|------|---------|--------|--------|
| `einsum` | `torch.einsum` | `neurx.einsum` | ✅ 高度兼容 |
| `ToTensor` | `torchvision.transforms.ToTensor` | `neurx.vision.transforms.ToTensor` | ✅ 完全兼容 |
| `Normalize` | `torchvision.transforms.Normalize` | `neurx.vision.transforms.Normalize` | ✅ 完全兼容 |
| `ResNet-18` | `torchvision.models.resnet18` | `neurx.vision.models.resnet18` | ✅ 架构兼容 |

### 迁移指南

从PyTorch迁移到Tensor：

```python
# PyTorch
import torch
import torchvision.transforms as transforms
import torchvision.models as models

# Tensor
import neurx
from neurx.vision import transforms, models

# 大部分API保持一致！
```

---

## 🧪 运行测试

我们提供了完整的测试套件来验证新功能：

```bash
cd /home/shuwen/neurx
python tests/test_new_features.py
```

测试内容：
- ✅ einsum的各种操作模式
- ✅ 图像变换的正确性
- ✅ ResNet模型的实例化和前向传播

---

## 📝 依赖要求

### 核心依赖（必需）
```bash
pip install numpy
```

### 视觉模块依赖（可选）
```bash
pip install Pillow  # 用于图像处理
```

如果不安装Pillow，`neurx.vision.transforms`将无法使用，但其他功能不受影响。

---

## 🔮 后续规划

根据分析报告 (`docs/pytorch_comparison_analysis.md`)，以下是下一步计划：

### P0 优先级（1-2个月内）

1. **分布式训练**
   - [ ] `DistributedDataParallel`
   - [ ] 集合通信原语 (all_reduce, all_gather)

2. **高级张量操作**
   - [ ] `scatter/gather`
   - [ ] `meshgrid`
   - [ ] Boolean indexing增强

3. **模型序列化**
   - [ ] 完整的`save/load`机制
   - [ ] `state_dict`支持

### P1 优先级（3-6个月内）

1. **更多CV模型**
   - [ ] VGG系列
   - [ ] EfficientNet
   - [ ] Vision Transformer

2. **性能优化**
   - [ ] 集成cuBLAS/cuDNN
   - [ ] Kernel fusion
   - [ ] 内存池

3. **开发工具**
   - [ ] Profiler
   - [ ] Memory profiler
   - [ ] TensorBoard集成

---

## 📖 相关文档

- **完整对比分析**: [`docs/pytorch_comparison_analysis.md`](../docs/pytorch_comparison_analysis.md)
- **主README**: [`README.md`](../README.md)
- **API文档**: (待补充)

---

## 🙏 贡献

欢迎贡献代码！优先领域：
- 🎯 分布式训练支持
- 🎯 更多预训练模型
- 🎯 性能优化（CUDA kernels）
- 🎯 文档和示例

---

## 📄 许可证

与主项目保持一致

---

**最后更新**: 2026-03-03  
**版本**: 参见 `neurx.__version__`
