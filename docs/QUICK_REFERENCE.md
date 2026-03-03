# Tensor Library 新功能快速参考

## 🚀 快速开始

### 1. 批量归一化 (Batch Normalization)

```python
from tensor.nn.modules import BatchNorm1d, BatchNorm2d
from tensor.tensor import Tensor
import numpy as np

# 1D: 适用于全连接层后
bn1d = BatchNorm1d(num_features=64)
x = Tensor(np.random.randn(32, 64))
y = bn1d(x)

# 2D: 适用于卷积层后
bn2d = BatchNorm2d(num_features=64)
x = Tensor(np.random.randn(2, 64, 32, 32))
y = bn2d(x)
```

**参数说明：**
- `num_features`: 特征/通道数
- `eps`: 防止除以0的小数值（默认1e-5）
- `momentum`: 运行统计的动量（默认0.1）
- `affine`: 是否使用可学习的weight/bias（默认True）
- `track_running_stats`: 是否跟踪运行统计（默认True）

---

### 2. 池化层 (Pooling)

```python
from tensor.nn.modules import MaxPool2d, AvgPool2d

# 最大池化：保留每个窗口的最大值
maxpool = MaxPool2d(kernel_size=2, stride=2, padding=0)
x = Tensor(np.random.randn(2, 64, 32, 32))
y = maxpool(x)  # → (2, 64, 16, 16)

# 平均池化：计算每个窗口的平均值
avgpool = AvgPool2d(kernel_size=3, stride=1, padding=1)
y = avgpool(x)  # → (2, 64, 32, 32)
```

**参数说明：**
- `kernel_size`: 池化窗口大小（int或tuple）
- `stride`: 步长（默认=kernel_size）
- `padding`: 填充（默认0）

---

### 3. Sequential 容器

```python
from tensor.nn.modules import Sequential, Linear, GELU, BatchNorm1d

# 方式1：直接传入模块
model = Sequential(
    Linear(10, 64),
    GELU(),
    BatchNorm1d(64),
    Linear(64, 32),
    GELU(),
    Linear(32, 5)
)

# 方式2：用索引访问
layer = model[0]  # Linear(10, 64)

# 方式3：用切片访问
first_three = model[0:3]

# 方式4：遍历
for i, layer in enumerate(model):
    print(f"Layer {i}: {layer}")

# 前向传播
x = Tensor(np.random.randn(32, 10))
y = model(x)  # 自动逐层传播
```

---

### 4. 权重初始化

```python
from tensor.nn.modules import (
    kaiming_uniform_, kaiming_normal_,
    xavier_uniform_, xavier_normal_,
    Parameter
)

# Kaiming初始化（推荐用于ReLU/LeakyReLU）
w = Parameter(np.empty((64, 32)))
kaiming_normal_(w, mode='fan_in', nonlinearity='leaky_relu')
# 或使用均匀分布
kaiming_uniform_(w, mode='fan_out')

# Xavier初始化（推荐用于Sigmoid/tanh）
w = Parameter(np.empty((64, 32)))
xavier_normal_(w)  # 正态分布
xavier_uniform_(w, gain=1.0)  # 均匀分布
```

**模式说明：**
- `mode='fan_in'`: 基于输入维度（默认）
- `mode='fan_out'`: 基于输出维度
- `mode='fan_avg'`: 基于平均值

**推荐搭配：**
| 激活函数 | 初始化方法 | 模式 |
|---------|----------|------|
| ReLU / LeakyReLU | Kaiming | fan_in |
| Sigmoid / tanh | Xavier | fan_in |
| 默认 | Xavier | fan_avg |

---

### 5. Module 工具方法

```python
from tensor.nn.modules import Sequential, Linear

model = Sequential(
    Linear(10, 64),
    Linear(64, 5)
)

# 控制梯度计算
model.requires_grad_(True)   # 启用梯度（默认）
model.requires_grad_(False)  # 冻结所有参数

# 检查特定参数
for param in model.parameters():
    print(f"requires_grad: {param.requires_grad}")

# 设备转移
model.to('cpu')     # 转移到CPU
model.cuda()        # 转移到CUDA
model.to('cuda')    # 等同于cuda()

# 数据类型转换
model.float()       # 转为float32
model.double()      # 转为float64

# 链式调用
model.double().to('cuda').requires_grad_(True)
```

---

## 📚 完整例子：ResNet风格的网络

```python
from tensor.nn.modules import (
    Sequential, Linear, Conv2d, BatchNorm2d, 
    ReLU, MaxPool2d, AvgPool2d, GELU,
    kaiming_normal_
)
from tensor.tensor import Tensor
import numpy as np

class SimpleResNet(Module):
    def __init__(self):
        super().__init__()
        
        # 特征提取
        self.features = Sequential(
            Conv2d(3, 64, kernel_size=7, stride=2, padding=3),
            BatchNorm2d(64),
            GELU(),
            MaxPool2d(kernel_size=3, stride=2, padding=1),
            
            Conv2d(64, 128, kernel_size=3, padding=1),
            BatchNorm2d(128),
            GELU(),
            MaxPool2d(kernel_size=2, stride=2),
            
            Conv2d(128, 256, kernel_size=3, padding=1),
            BatchNorm2d(256),
            GELU(),
            AvgPool2d(kernel_size=4, stride=1),
        )
        
        # 分类头
        self.classifier = Sequential(
            Linear(256, 128),
            GELU(),
            Linear(128, 10)
        )
        
        self._init_weights()
    
    def _init_weights(self):
        for param in self.parameters():
            if len(param.data.shape) > 1:
                kaiming_normal_(param, nonlinearity='relu')
    
    def forward(self, x):
        x = self.features(x)
        x = x.reshape(x.shape[0], -1)  # flatten
        x = self.classifier(x)
        return x

# 使用
model = SimpleResNet()
model.train()

x = Tensor(np.random.randn(4, 3, 224, 224))
logits = model(x)

# 冻结特征层，只训练分类头
model.features.requires_grad_(False)
model.classifier.requires_grad_(True)
```

---

## ⚙️ 常见操作速查表

| 操作 | 代码 |
|-----|-----|
| 创建BatchNorm | `BatchNorm2d(64)` |
| 创建MaxPool | `MaxPool2d(2, stride=2)` |
| 创建Sequential | `Sequential(layer1, layer2, ...)` |
| Kaiming初始化 | `kaiming_normal_(w, mode='fan_in')` |
| Xavier初始化 | `xavier_normal_(w)` |
| 冻结参数 | `model.requires_grad_(False)` |
| 解冻参数 | `model.requires_grad_(True)` |
| 转到GPU | `model.cuda()` |
| 转为float64 | `model.double()` |
| 获取所有参数 | `model.parameters()` |
| 按名字获取参数 | `model.named_parameters()` |
| 切换到训练模式 | `model.train()` |
| 切换到评估模式 | `model.eval()` |
| 梯度清零 | `model.zero_grad()` |
| 保存模型 | `state = model.state_dict()` |
| 加载模型 | `model.load_state_dict(state)` |

---

## 🔍 调试技巧

### 1. 检查形状变化
```python
from tensor.nn.modules import Sequential, Conv2d, MaxPool2d

model = Sequential(
    Conv2d(3, 64, 3, padding=1),
    MaxPool2d(2),
)

x = Tensor(np.random.randn(1, 3, 32, 32))
print(f"Input: {x.shape}")

for i, layer in enumerate(model):
    x = layer(x)
    print(f"After layer {i}: {x.shape}")
```

### 2. 检查梯度流
```python
model.train()
x = Tensor(np.random.randn(4, 3, 32, 32), requires_grad=True)
y = model(x)

loss = y.sum()
loss.backward()

for name, param in model.named_parameters():
    has_grad = param.grad is not None and param.grad.any()
    print(f"{name}: grad_shape={param.grad.shape if has_grad else None}, has_grad={has_grad}")
```

### 3. 检查运行统计
```python
bn = BatchNorm2d(64)
bn.train()

for i in range(10):
    x = Tensor(np.random.randn(4, 64, 32, 32))
    y = bn(x)

print(f"Running mean: {bn.running_mean[:5]}")
print(f"Running var: {bn.running_var[:5]}")
print(f"Batches tracked: {bn.num_batches_tracked}")
```

---

## ✅ 性能提示

1. **使用Sequential减少代码量**
   ```python
   # 不好
   x = layer1(x)
   x = layer2(x)
   x = layer3(x)
   
   # 好
   model = Sequential(layer1, layer2, layer3)
   x = model(x)
   ```

2. **及时冻结不需要训练的参数**
   ```python
   # 迁移学习：冻结预训练权重
   model.load_state_dict(pretrained_weights)
   model.requires_grad_(False)
   
   # 只解冻顶层
   model.classifier.requires_grad_(True)
   ```

3. **初始化很重要**
   ```python
   # 好的初始化能加快收敛
   model = MyModel()
   for param in model.parameters():
       if len(param.data.shape) > 1:
           kaiming_normal_(param, nonlinearity='relu')
   ```

4. **合理使用Batch Norm**
   ```python
   # 在激活函数前添加BN
   model = Sequential(
       Conv2d(3, 64, 3),
       BatchNorm2d(64),    # ← 在这里
       GELU(),
   )
   ```

---

## 📞 常见问题

**Q: BatchNorm在评估时不会更新running stats吗？**
A: 正确。设置`model.eval()`后，BN会使用accumulated running stats，不再更新。

**Q: MaxPool和AvgPool有什么区别？**
A: MaxPool保留最大值（提取突出特征），AvgPool平均所有值（保留整体特征）。

**Q: 什么时候用Kaiming什么时候用Xavier？**
A: ReLU及其变种用Kaiming，Sigmoid/tanh用Xavier。大多数现代网络用Kaiming。

**Q: 如何只冻结某些层？**
A: 只对那些层调用`requires_grad_(False)`
   ```python
   model.backbone.requires_grad_(False)
   model.head.requires_grad_(True)
   ```

**Q: Sequential支持嵌套吗？**
A: 支持！
   ```python
   encoder = Sequential(...)
   decoder = Sequential(...)
   full_model = Sequential(encoder, decoder)
   ```

---

## 📖 相关资源

- [测试文件](../test_new_modules.py) - 完整的单元测试
- [实现分析](../IMPLEMENTATION_ANALYSIS.md) - 详细的功能对比
- [Module源码](./modules.py) - 完整的实现代码
