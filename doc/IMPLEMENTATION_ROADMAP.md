# neurx 框架补齐与优化 - 实施计划

**计划日期:** 2026-03-03  
**目标:** 从82% 提升到95%+ 完成度  
**总工作量:** 16,000+ 行代码  
**预计周期:** 6-8 周

---

## 🎯 阶段目标

### **第一阶段: 核心NLP功能 (2-3周)**
**目标完成度:** 82% → 88%  
**关键交付:**
- LSTM/GRU/RNN 实现
- Attention 机制
- Transformer 编码器

**预期效果:**
- ✅ 支持序列模型
- ✅ 支持基础 Transformer
- ✅ 能运行 BERT/GPT 风格小模型

---

### **第二阶段: 训练基础设施 (1-2周)**
**目标完成度:** 88% → 92%  
**关键交付:**
- 扩展损失函数
- 学习率调度器
- Embedding 层
- DataLoader 完善

**预期效果:**
- ✅ 完整的训练流程
- ✅ 灵活的学习率控制
- ✅ 高效的数据加载

---

### **第三阶段: 优化与扩展 (1-2周)**
**目标完成度:** 92% → 95%+  
**关键交付:**
- 更多视觉模型
- 分布式训练优化
- 编译和性能优化

**预期效果:**
- ✅ 生产级框架
- ✅ 可扩展的分布式训练
- ✅ 性能优化

---

## 📅 详细时间表

### **Week 1: RNN 基础**

**Day 1-2: LSTM 实现**
```
文件: python/neurx/nn/rnn.py
- LSTMCell 核心逻辑 (200行)
  ├─ 输入门 (Input gate)
  ├─ 遗忘门 (Forget gate)
  ├─ 输出门 (Output gate)
  └─ 单元状态更新 (Cell state)

- 测试: tests/test_lstm_cell.py (100行)
  ├─ 前向传播验证
  ├─ 梯度检查
  └─ 多批次处理
```

**Day 3-4: LSTM 序列处理**
```
- LSTM 模块 (300行)
  ├─ 多层支持
  ├─ 双向支持
  ├─ 初始隐状态处理
  └─ 返回值：output, (h_n, c_n)

- 测试: tests/test_lstm.py (150行)
  ├─ 可变长序列
  ├─ 梯度流验证
  └─ 与参考实现对比
```

**Day 5: GRU 实现**
```
- GRUCell (180行)
- GRU (280行)
- 测试: tests/test_gru.py (120行)
```

**本周交付:**
- LSTM/GRU 核心实现
- 400+ 单元测试
- 基础文档

---

### **Week 2: Attention & Transformer**

**Day 1-2: Attention 实现**
```
文件: python/neurx/nn/attention.py

ScaledDotProductAttention (150行):
  ├─ QK^T 计算
  ├─ sqrt(d_k) 缩放
  ├─ Softmax
  ├─ 与V相乘
  └─ Dropout

MultiheadAttention (350行):
  ├─ Q/K/V 线性投影
  ├─ h 个head的并行计算
  ├─ 头部拼接
  ├─ 输出投影
  ├─ 因果掩码支持
  └─ Attention权重dropout

测试: tests/test_attention.py (200行)
  ├─ 单头验证
  ├─ 多头一致性
  ├─ 掩码功能
  └─ 梯度流
```

**Day 3-4: Transformer 层**
```
文件: python/neurx/nn/transformer.py

PositionalEncoding (100行):
  ├─ 正弦位置编码
  └─ 不可训练参数

TransformerEncoderLayer (300行):
  ├─ MultiheadAttention
  ├─ FFN (线性-ReLU-线性)
  ├─ LayerNorm
  ├─ 残差连接
  ├─ Dropout
  └─ 预层归一化 (Pre-LN)

TransformerEncoder (200行):
  ├─ N个EncoderLayer堆叠
  ├─ 位置编码应用
  ├─ 序列长度掩码
  └─ 批处理支持

测试: tests/test_transformer.py (250行)
```

**Day 5: TransformerDecoder**
```
TransformerDecoderLayer (350行):
  ├─ Self-attention (因果)
  ├─ Cross-attention
  ├─ FFN
  ├─ 三个LayerNorm
  └─ 残差连接

TransformerDecoder (200行):
  └─ N个DecoderLayer堆叠

完整集成测试
```

**本周交付:**
- Attention 和 Transformer 完整实现
- 500+ 单元测试
- 使用示例

---

### **Week 3: 归一化与损失函数**

**Day 1-2: 归一化层**
```
文件: python/neurx/nn/normalization.py

LayerNorm (400行):
  ├─ 特征维度归一化
  ├─ 可学习的 γ 和 β
  ├─ eps 参数
  ├─ 梯度计算
  └─ 批处理支持

GroupNorm (350行):
  ├─ 按组归一化
  ├─ 组数参数
  └─ 不依赖批大小

测试: 300行
```

**Day 3-4: 损失函数**
```
文件: python/neurx/losses.py (扩展)

新增:
├─ BCELoss (200行)
├─ BCEWithLogitsLoss (180行)
├─ NLLLoss (150行)
├─ L1Loss (100行)
├─ SmoothL1Loss (120行)
├─ HuberLoss (150行)
├─ KLDivLoss (140行)
└─ CosineEmbeddingLoss (180行)

总计: 1,220行新代码

测试: tests/test_losses.py (400行)
```

**Day 5: 激活函数扩展**
```
python/neurx/nn/functional.py (扩展)

新增激活函数:
├─ GELU (100行)
├─ Mish (80行)
├─ SiLU/Swish (70行)
├─ GLU变体 (120行)
└─ 其他现代激活函数

tests/test_activations.py (150行)
```

**本周交付:**
- 完整的归一化层
- 8+ 新损失函数
- 5+ 新激活函数
- 850+ 测试代码

---

### **Week 4: Embedding 与数据加载**

**Day 1-2: Embedding层**
```
文件: python/neurx/nn/embedding.py

Embedding (300行):
  ├─ 词汇表查询
  ├─ 参数初始化
  ├─ 梯度支持
  ├─ Padding IDX
  └─ 权重分享

EmbeddingBag (250行):
  ├─ 自动求平均/求和
  ├─ 稀疏梯度支持
  └─ 高效实现

测试: 200行
```

**Day 3-4: DataLoader 完善**
```
文件: python/neurx/data/ (完善)

Sampler 类:
├─ SequentialSampler (100行)
├─ RandomSampler (120行)
├─ SubsetRandomSampler (100行)
└─ BatchSampler (150行)

Collate 函数:
├─ default_collate (150行)
├─ 自定义collate支持
└─ 填充序列支持

DataLoader 优化:
├─ 多进程支持
├─ Prefetch机制
├─ 内存优化
└─ 采样器集成 (500行)

测试: tests/test_dataloader.py (300行)
```

**Day 5: 学习率调度器**
```
文件: python/neurx/optim/scheduler.py (扩展)

新增调度器:
├─ StepLR (120行)
├─ ExponentialLR (100行)
├─ CosineAnnealingLR (150行)
├─ ReduceLROnPlateau (180行)
├─ LambdaLR (130行)
├─ LinearLR (110行)
├─ PolynomialLR (140行)
├─ CyclicLR (180行)
└─ OneCycleLR (200行) ⭐ 流行

总计: 1,110行新代码

测试: tests/test_schedulers.py (400行)
```

**本周交付:**
- Embedding 层完整实现
- 完善的 DataLoader
- 9种 学习率调度器
- 900+ 测试代码

---

### **Week 5-6: 视觉模型与优化**

**Day 1-3: 视觉模型扩展**
```
新模型:
├─ VGG16/19 (600行)
├─ DenseNet (800行)
├─ EfficientNet (1000行)
├─ MobileNetV2 (700行)
└─ Vision Transformer 完整版 (1200行)

总计: 4,300行新代码

测试: tests/test_vision_models.py (500行)
```

**Day 4-5: 分布式与编译优化**
```
分布式训练:
├─ DistributedDataParallel 优化 (400行)
├─ 梯度累积工具 (150行)
├─ 同步批归一化 (200行)
└─ 通信优化 (250行)

编译优化:
├─ 操作融合 (300行)
├─ 图优化 (400行)
└─ 内存优化 (200行)

总计: 1,900行

测试: tests/test_distributed.py (300行)
```

**本周交付:**
- 5 个新视觉模型
- 优化的分布式训练
- 图编译基础设施
- 800+ 测试代码

---

## 📊 进度追踪

### **关键里程碑**

| 周数 | 目标 | 完成度 | 测试覆盖 |
|------|------|--------|---------|
| W1 | RNN基础 | 82% → 84% | 400 tests |
| W2 | Attention | 84% → 87% | 700 tests |
| W3 | 归一化+损失 | 87% → 89% | 1,050 tests |
| W4 | Embedding+调度器 | 89% → 91% | 1,350 tests |
| W5-6 | 视觉+优化 | 91% → 95% | 1,650 tests |

---

## 🔧 工作流程

### **每周迭代流程**

```
① 代码实现
   ├─ 编写核心功能
   ├─ 优化性能
   └─ 添加文档

② 单元测试
   ├─ 功能测试
   ├─ 梯度验证
   ├─ 边界情况
   └─ 性能基准

③ 集成测试
   ├─ 跨模块兼容性
   ├─ 端到端流程
   └─ 与PyTorch对比

④ 文档更新
   ├─ API文档
   ├─ 使用示例
   ├─ 最佳实践
   └─ 性能说明
```

---

## 📈 代码质量标准

### **必须满足**
- ✅ 100%单元测试覆盖
- ✅ 梯度检查通过
- ✅ 与PyTorch数值一致性 (误差 < 1e-5)
- ✅ 完整的类型提示
- ✅ 详细的文档字符串

### **推荐达成**
- 📊 性能指标记录
- 📊 内存使用最优化
- 📊 边界情况处理
- 📊 错误信息清晰

---

## 🎁 快速启动指令

### **立即开始实现 RNN**

```bash
cd /home/shuwen/neurx

# 1. 创建RNN模块
mkdir -p python/neurx/nn/rnn_impl
touch python/neurx/nn/rnn.py

# 2. 运行测试
make test-rnn

# 3. 检查覆盖率
python3 -m pytest tests/test_lstm.py -v --cov=neurx.nn
```

---

## ✨ 成功指标

### **第一阶段成功标志**
- [ ] LSTM/GRU 通过所有单元测试
- [ ] MultiheadAttention 与PyTorch对比数值一致
- [ ] Transformer 可以运行BERT/GPT推理
- [ ] 完成度达到 88%+
- [ ] 文档完整并包含示例

### **最终成功标志**
- [ ] 完成度达到 95%+
- [ ] 1,650+ 个单元测试全部通过
- [ ] 16,000+ 行新代码
- [ ] 完整的模型库和工具链
- [ ] PyTorch 迁移指南完成

---

## 💾 交付物清单

### **代码**
- [ ] python/neurx/nn/rnn.py (RNN系)
- [ ] python/neurx/nn/attention.py (注意力)
- [ ] python/neurx/nn/transformer.py (Transformer)
- [ ] python/neurx/nn/normalization.py (归一化)
- [ ] python/neurx/nn/embedding.py (嵌入)
- [ ] python/neurx/losses.py (扩展)
- [ ] python/neurx/data/ (完善)
- [ ] python/neurx/optim/scheduler.py (扩展)
- [ ] python/neurx/vision/models/ (扩展)

### **测试**
- [ ] tests/test_rnn.py
- [ ] tests/test_lstm.py
- [ ] tests/test_attention.py
- [ ] tests/test_transformer.py
- [ ] tests/test_losses.py
- [ ] tests/test_schedulers.py
- [ ] tests/test_vision_models.py

### **文档**
- [ ] 更新README.md
- [ ] RNN 使用指南
- [ ] Transformer 最佳实践
- [ ] 模型迁移指南
- [ ] 性能优化建议

---

**推荐:** 从W1开始实现LSTM核心！

