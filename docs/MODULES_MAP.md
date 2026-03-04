# Tensor Library nn.modules 功能导图

## 🏗️ 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                   Module (基础类)                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 核心方法:                                              │ │
│  │ • forward()           - 前向传播                       │ │
│  │ • __call__()          - 调用接口                       │ │
│  │ • parameters()        - 获取参数                       │ │
│  │ • named_parameters()  - 获取命名参数                   │ │
│  │ • zero_grad()         - 梯度清零                       │ │
│  │ • train() / eval()    - 模式切换                       │ │
│  │ • state_dict()        - 状态字典                       │ │
│  │ • load_state_dict()   - 加载权重                       │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
         ▼          ▼          ▼          ▼          ▼
    ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
    │ Linear │ │Conv2d  │ │Embed   │ │Dropout │ │Softmax │
    └────────┘ └────────┘ └────────┘ └────────┘ └────────┘
         ▼          ▼          ▼          ▼          ▼
    ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
    │BatchN1d│ │BatchN2d│ │MaxPool │ │AvgPool │ │LayerNm │
    └────────┘ └────────┘ └────────┘ └────────┘ └────────┘
         ▼          ▼          ▼          ▼          ▼
    ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
    │RMSNorm │ │  GELU  │ │Sigmoid │ │ SiLU   │ │  MHA   │
    └────────┘ └────────┘ └────────┘ └────────┘ └────────┘
         ▼          ▼          ▼
    ┌────────┐ ┌────────┐ ┌────────┐
    │  MLP   │ │  MoE   │ │TransBk  │
    └────────┘ └────────┘ └────────┘
         ▼          ▼
    ┌──────────────────────┐
    │  ModuleList / Dict   │
    └──────────────────────┘
         ▼
    ┌──────────────────────┐
    │   Sequential         │  ⭐ 新增
    └──────────────────────┘
```

---

## 📦 按功能分类

### 🎨 归一化层 (Normalization)
```
LayerNorm          → 层级别归一化（最后几维）
├─ 参数: weight, bias
├─ 用途: Transformer模块
└─ 特性: 与batch size无关

RMSNorm            → 均方根归一化（LLM优化）
├─ 参数: weight
├─ 用途: LLaMA, Deepseek等
└─ 特性: 更稳定的梯度

BatchNorm1d        → 1D批量归一化 ⭐ 新增
├─ 参数: weight, bias, running_mean, running_var
├─ 用途: 全连接层后
└─ 特性: 动量更新，训练/评估不同

BatchNorm2d        → 2D批量归一化 ⭐ 新增
├─ 参数: weight, bias, running_mean, running_var
├─ 用途: 卷积层后
└─ 特性: 通道维度归一化
```

### 🔄 激活函数 (Activation)
```
GELU               → 高斯误差线性单元
├─ 变种: 近似版本（GELU~Swish）
└─ 用途: Vision/NLP Transformer

Sigmoid            → S形曲线激活
├─ 范围: (0, 1)
└─ 用途: 二分类、概率输出

SiLU/Swish         → Sigmoid线性单元
├─ 形式: x * sigmoid(1.702*x)
└─ 用途: EfficientNet, Transformer
```

### 📊 池化层 (Pooling) ⭐ 新增
```
MaxPool2d          → 最大值池化
├─ 参数: kernel_size, stride, padding
├─ 输出: 每个窗口的最大值
└─ 梯度: 仅最大值位置接收

AvgPool2d          → 平均值池化
├─ 参数: kernel_size, stride, padding
├─ 输出: 每个窗口的平均值
└─ 梯度: 均匀分配到窗口内所有值
```

### 🧬 基础层 (Basic Layers)
```
Linear             → 全连接层
├─ 参数: weight (out_features × in_features)
├─ 参数: bias (out_features,)
└─ 计算: y = x @ W + b

Conv2d             → 2D卷积层
├─ 参数: weight (out_ch × in_ch × K × K)
├─ 参数: bias (out_ch,)
├─ 特性: Groups, Dilation支持
└─ 计算: 2D卷积操作

Embedding          → 词嵌入层
├─ 参数: weight (vocab_size × embedding_dim)
├─ 计算: 索引查表
└─ 用途: NLP输入层
```

### 🎯 注意力机制 (Attention)
```
MultiHeadAttention → 多头自注意力
├─ 参数: qkv_proj, out_proj
├─ 特性: 
│  ├─ 因果遮罩（自回归）
│  ├─ RoPE位置编码 (可选)
│  ├─ KV缓存（推理优化）
│  └─ Dropout正则化
└─ 输出: 注意力加权特征
```

### 🏗️ 容器 (Containers)
```
Sequential         → 顺序容器 ⭐ 新增
├─ 用法: Sequential(layer1, layer2, ...)
├─ 特性: 自动前向传播、参数收集
└─ 访问: 支持索引和切片

ModuleList         → 模块列表
├─ 用法: ModuleList([m1, m2, ...])
├─ 特性: 迭代访问、参数收集
└─ 差别: 不自动前向传播

ModuleDict         → 模块字典
├─ 用法: ModuleDict({'name1': m1, ...})
├─ 特性: 命名访问、参数收集
└─ 差别: 基于字符串键
```

### 🚀 高级模块 (Advanced)
```
MLP                → 多层感知机
├─ 架构: Linear → Activation → Linear → Dropout
├─ 变种: SwiGLU支持
└─ 用途: Transformer中的FFN

MoE                → 专家混合网络
├─ 架构: 多个MLPExperts + TopK路由
├─ 参数: num_experts, top_k
└─ 用途: 扩展参数而不增加计算

TransformerBlock   → Transformer块
├─ 架构: LN → Attention → LN → FFN
├─ 特性: 
│  ├─ Pre-norm设置
│  ├─ 可选MoE
│  ├─ RoPE支持
│  └─ RMSNorm支持
└─ 用途: 语言模型、视觉Transformer
```

---

## 🛠️ 工具函数

### 权重初始化 ⭐ 新增

```
Kaiming初始化
├─ kaiming_uniform_()  → 均匀分布
├─ kaiming_normal_()   → 正态分布
├─ mode: fan_in (默认) / fan_out / fan_avg
├─ nonlinearity: leaky_relu (默认) / ...
└─ 用途: ReLU及其变种

Xavier初始化
├─ xavier_uniform_()   → 均匀分布
├─ xavier_normal_()    → 正态分布
├─ gain: 1.0 (默认)
└─ 用途: Sigmoid/tanh

计算公式
├─ Kaiming: std = gain / √(fan_in)
├─ Xavier: std = gain * √(2/(fan_in + fan_out))
└─ bound = √3 * std  (均匀分布)
```

### Module方法 ⭐ 新增

```
requires_grad_(bool)   → 控制梯度计算
├─ requires_grad_(True)  → 启用梯度（默认）
├─ requires_grad_(False) → 禁用梯度（冻结）
└─ 用途: 迁移学习

设备转移
├─ to(device)  → 转移到指定设备
├─ cpu()       → 转到CPU
├─ cuda()      → 转到CUDA
└─ 用途: CPU/GPU切换

精度转换
├─ float()     → float32
├─ double()    → float64
└─ 用途: 精度调整

特性
├─ 支持链式调用: model.double().to('cuda').requires_grad_(True)
├─ 对所有参数递归应用
└─ 返回self便于继续使用
```

---

## 🔗 依赖关系

```
Parameter
├─ 基于: Tensor类
└─ 用途: 可学习的参数

Module
├─ 基于: Python class
├─ 组成:
│  ├─ _buffers (非参数缓冲)
│  ├─ 子Module (递归)
│  └─ Parameter (参数)
└─ 特点: 自动参数收集

Tensor
├─ 用途: 数据容器
├─ 支持: requires_grad, backward()
└─ 集成: 自动微分

BatchNorm*d
├─ 依赖: Tensor, Parameter
├─ 缓冲: running_mean, running_var, num_batches_tracked
└─ 特点: 动态统计更新

MaxPool2d / AvgPool2d
├─ 依赖: Tensor
├─ 特点: 梯度路由规则不同
└─ 用途: 特征图降维

Sequential
├─ 依赖: Module列表
├─ 自动化: 参数收集、前向传播
└─ 方便: 快速构建线性网络
```

---

## 🎓 学习路径

### 初级 (基础使用)
```
1. 学习基础层: Linear, Conv2d
2. 学习激活函数: GELU, Sigmoid
3. 学习正则化: BatchNorm, Dropout
4. 练习Sequential容器
5. 学习权重初始化
```

### 中级 (模型构建)
```
1. 学习池化层: MaxPool, AvgPool
2. 学习LayerNorm / RMSNorm
3. 实现小型CNN/MLP
4. 学习Module工具方法
5. 掌握train/eval切换
```

### 高级 (特殊应用)
```
1. 学习MultiHeadAttention
2. 学习MLP / MoE
3. 构建TransformerBlock
4. 实现完整模型
5. 性能优化和调试
```

---

## 📊 功能矩阵

### 按维度分类
```
维度    层类型                   状态
─────────────────────────────────
0D     Parameter               ✓
1D     Linear, LayerNorm       ✓
       BatchNorm1d             ⭐新增
       Dropout                 ✓
       
2D     Conv2d                  ✓
       MaxPool2d               ⭐新增
       AvgPool2d               ⭐新增
       BatchNorm2d             ⭐新增
       
ND     Embedding               ✓
       Softmax                 ✓
       MultiHeadAttention      ✓
       
       GELU, Sigmoid, SiLU     ✓
       MLP, MoE                ✓
       TransformerBlock        ✓
       
工具   Sequential              ⭐新增
       ModuleList              ✓
       ModuleDict              ✓
       init函数                ⭐新增
```

### 按应用分类
```
应用类型              必需层
─────────────────────────────
全连接网络           Linear, Dropout, init
       (MLP)

卷积神经网络         Conv2d, BatchNorm2d,
       (CNN)         MaxPool2d/AvgPool2d

Transformer          LayerNorm, MultiHeadAttention,
                     MLP, Dropout

参数高效             Linear (with LoRA),
微调                 requires_grad_()

迁移学习             requires_grad_(),
                     to(), load_state_dict()
```

---

## 🚀 快速开始模板

### Template 1: CNN
```python
from neurx.nn.modules import *

model = Sequential(
    Conv2d(3, 64, 3, padding=1),
    BatchNorm2d(64),
    GELU(),
    MaxPool2d(2),
    
    Conv2d(64, 128, 3, padding=1),
    BatchNorm2d(128),
    GELU(),
    AvgPool2d(2)
)
```

### Template 2: Transformer Encoder
```python
from neurx.nn.modules import *

block = TransformerBlock(
    n_embd=512,
    n_heads=8,
    dropout=0.1,
    use_rmsnorm=True,
    use_rope=True
)
```

### Template 3: MLP Classifier
```python
from neurx.nn.modules import *

model = Sequential(
    Linear(784, 512),
    BatchNorm1d(512),
    GELU(),
    Dropout(0.2),
    
    Linear(512, 256),
    BatchNorm1d(256),
    GELU(),
    Dropout(0.2),
    
    Linear(256, 10)
)
```

### Template 4: 权重初始化
```python
model = MyModel()

for param in model.parameters():
    if len(param.data.shape) > 1:
        kaiming_normal_(param)
```

---

## 💡 常见模式

### Pattern 1: 冻结/解冻
```python
model.requires_grad_(False)      # 冻结所有
model.head.requires_grad_(True)  # 仅解冻头部
```

### Pattern 2: 设备管理
```python
model.to('cuda').float()
```

### Pattern 3: 模型继承
```python
class MyModel(Module):
    def __init__(self):
        super().__init__()
        self.backbone = Sequential(...)
        self.head = Sequential(...)
    
    def forward(self, x):
        x = self.backbone(x)
        x = self.head(x)
        return x
```

### Pattern 4: Train/Eval
```python
model.train()        # 启用Dropout, BatchNorm更新
# 训练循环...

model.eval()         # 禁用Dropout, 使用running stats
# 推理循环...
```

---

## 📈 版本进度

```
v1.0 (原始)
├─ Module基类
├─ Linear, Conv2d
├─ LayerNorm, RMSNorm, Dropout
├─ GELU, Sigmoid, SiLU
├─ MultiHeadAttention
├─ MLP, MoE, TransformerBlock
└─ ModuleList, ModuleDict

v1.1 (当前) ⭐
├─ BatchNorm1d/2d
├─ MaxPool2d, AvgPool2d
├─ Sequential
├─ 权重初始化函数
├─ Module工具方法
└─ 完整文档和测试

v1.2 (计划)
├─ Functional接口
├─ Hooks机制
├─ GroupNorm, InstanceNorm
├─ AdaptivePool
└─ 更多初始化方法

v2.0 (愿景)
├─ 计算图优化
├─ 混合精度
├─ 分布式训练
├─ JIT编译
└─ 完整生态
```

---

本导图展示了Tensor库nn.modules的完整功能生态。⭐标记表示在v1.1版本中新增的功能。
