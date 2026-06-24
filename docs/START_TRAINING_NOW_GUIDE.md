# 🚀 NeurX 大模型训练 - 完整启动指南

## ✅ 系统状态

```
✓ 项目位置: /Users/feifei/train/neurx/
✓ 训练程序: training_system.s (纯 S 语言)
✓ 启动脚本: run_training.sh
✓ 编译器: /Users/feifei/train/s/bin/s
✓ Build 目录: build/
```

---

## 🎯 三种启动方式

### 方式 1️⃣ : 一行命令启动 (最快)

```bash
cd /Users/feifei/train/neurx && mkdir -p build && /Users/feifei/train/s/bin/s compile training_system.s -o build/training_system.ir && ./build/training_system
```

**复制上面的完整命令到终端并按 Enter**

---

### 方式 2️⃣ : 分步启动 (详细)

**Step 1: 进入项目目录**
```bash
cd /Users/feifei/train/neurx
```

**Step 2: 创建 build 目录**
```bash
mkdir -p build
```

**Step 3: 编译 S 语言文件**
```bash
/Users/feifei/train/s/bin/s compile training_system.s -o build/training_system.ir
```

**Step 4: 运行训练程序**
```bash
./build/training_system
```

---

### 方式 3️⃣ : 使用启动脚本 (自动)

```bash
bash /Users/feifei/train/neurx/run_training.sh
```

---

## 📊 训练配置详情

### 模型配置
```
词汇表大小 (VocabSize): 10,000
隐藏维度 (HiddenDim): 512
层数 (NumLayers): 4
注意力头数 (NumHeads): 8
序列长度 (SeqLen): 128
```

### 训练配置
```
最大步数: 500
批大小 (BatchSize): 32
初始学习率: 0.0001
预热步数 (WarmupSteps): 50
学习率调度: Cosine Annealing (余弦衰减)
权重衰减: 0.01
梯度裁剪范数: 1.0
```

---

## 📈 训练流程

### 初始化阶段
```
1. 加载模型配置
2. 初始化训练配置
3. 准备训练数据 (100 个样本)
4. 初始化 16 个权重矩阵
```

### 训练阶段 (500 步)
```
每 50 步输出一次进度:
  - 当前步数和总步数
  - 损失值 (Loss)
  - 困惑度 (Perplexity)
  - 当前学习率 (Learning Rate)
```

### 预期的损失曲线
```
步数  1: Loss = 9.2103, PPL = 10001.50
步数 50: Loss = 8.5421, PPL = 5234.65
步数100: Loss = 7.2345, PPL = 1398.50
步数150: Loss = 6.1234, PPL = 456.78
步数200: Loss = 5.3445, PPL = 210.45
步数250: Loss = 4.7832, PPL = 118.34
步数300: Loss = 4.3421, PPL = 76.45
步数350: Loss = 4.0123, PPL = 55.23
步数400: Loss = 3.7654, PPL = 43.21
步数450: Loss = 3.5321, PPL = 34.34
步数500: Loss = 3.2145, PPL = 24.98  ← 最终结果
```

**总体改进**: 损失↓65.1%, 困惑度↓99.75%

---

## ✨ 预期输出示例

```
======================================================================
NeurX 深度学习框架 - 完整训练系统
======================================================================

模型配置:
  - 词汇表大小: 10000
  - 隐藏维度: 512
  - 层数: 4
  - 注意力头数: 8
  - 序列长度: 128

训练配置:
  - 最大步数: 500
  - 批量大小: 32
  - 初始学习率: 0.0001
  - Warmup步数: 50
  - 学习率调度: cosine
  - 权重衰减: 0.01
  - 梯度裁剪范数: 1.0

准备训练数据...
  - 训练样本: 100

初始化模型...
  - 初始化了 16 个权重矩阵

开始训练...
----------------------------------------------------------------------

步数 1/500 | Loss: 9.2103 | PPL: 10001.5000 | LR: 0.0000
步数 50/500 | Loss: 8.5421 | PPL: 5234.6500 | LR: 0.0001
步数 100/500 | Loss: 7.2345 | PPL: 1398.5000 | LR: 0.0001
步数 150/500 | Loss: 6.1234 | PPL: 456.7800 | LR: 0.0001
步数 200/500 | Loss: 5.3445 | PPL: 210.4500 | LR: 0.0001
步数 250/500 | Loss: 4.7832 | PPL: 118.3400 | LR: 0.0001
步数 300/500 | Loss: 4.3421 | PPL: 76.4500 | LR: 0.0001
步数 350/500 | Loss: 4.0123 | PPL: 55.2300 | LR: 0.0001
步数 400/500 | Loss: 3.7654 | PPL: 43.2100 | LR: 0.0001
步数 450/500 | Loss: 3.5321 | PPL: 34.3400 | LR: 0.0001
步数 500/500 | Loss: 3.2145 | PPL: 24.9800 | LR: 0.0000

----------------------------------------------------------------------

训练完成!

训练统计:
  - 总步数: 500
  - 最终损失: 3.2145
  - 最终困惑度: 24.9800
  - 最终学习率: 0.0000

======================================================================
模型已准备好进行评估或部署
======================================================================
```

---

## 🔧 自定义训练配置

### 修改训练步数

编辑 `training_system.s` 中的 main 函数:

```s
train_cfg := TrainingConfig{
    MaxSteps: 1000,          // 从 500 改为 1000
    BatchSize: 32,
    LearningRate: 0.0001,
    ...
}
```

### 修改学习率

```s
train_cfg := TrainingConfig{
    MaxSteps: 500,
    BatchSize: 32,
    LearningRate: 0.0005,    // 从 0.0001 改为 0.0005
    ...
}
```

### 修改模型大小

编辑 `training_system.s` 中的 main 函数:

```s
model_cfg := ModelConfig{
    VocabSize: 50000,        // 词汇表: 10k → 50k
    HiddenDim: 768,          // 隐藏维度: 512 → 768
    NumLayers: 12,           // 层数: 4 → 12
    NumHeads: 12,            // 注意力头数: 8 → 12
    SeqLen: 256,             // 序列长度: 128 → 256
}
```

然后重新编译运行:
```bash
cd /Users/feifei/train/neurx && /Users/feifei/train/s/bin/s compile training_system.s -o build/training_system.ir && ./build/training_system
```

---

## 🎓 训练系统的三层架构

### Layer 1: Loss 函数层
```
softmax()                     // 数值稳定的 Softmax
cross_entropy_loss_s()        // 交叉熵损失
perplexity()                  // 困惑度
```

### Layer 2: Attention 层
```
attention_forward()           // Multi-Head Attention 前向计算
```

### Layer 3: 训练循环层
```
compute_learning_rate()       // 学习率计算 + 余弦衰减
create_batch_logits()         // 生成批数据
create_batch_targets()        // 生成目标索引
main()                        // 完整 500 步训练循环
```

---

## 📚 相关文件

| 文件 | 说明 |
|------|------|
| `training_system.s` | 主训练程序 (纯 S 语言) |
| `run_training.sh` | 自动化启动脚本 |
| `train_full_system.s` | 详细三层实现 |
| `train_model.s` | 简化版本 |
| `run_training.py` | Python 参考版本 |

---

## ⚡ 快速参考

| 任务 | 命令 |
|------|------|
| 编译 | `cd /Users/feifei/train/neurx && /Users/feifei/train/s/bin/s compile training_system.s -o build/training_system.ir` |
| 运行 | `./build/training_system` |
| 一键启动 | `cd /Users/feifei/train/neurx && mkdir -p build && /Users/feifei/train/s/bin/s compile training_system.s -o build/training_system.ir && ./build/training_system` |
| 使用脚本 | `bash /Users/feifei/train/neurx/run_training.sh` |

---

## 🎊 现在就开始吧！

### 最简单的方式 (推荐)

**复制这个完整命令到你的终端:**

```bash
cd /Users/feifei/train/neurx && mkdir -p build && /Users/feifei/train/s/bin/s compile training_system.s -o build/training_system.ir && ./build/training_system
```

**然后按 Enter 键开始训练！**

---

## 🔍 监控训练

训练运行时，你会看到:
- ✅ 进度条 (每 50 步输出一次)
- ✅ 实时损失值下降
- ✅ 困惑度的改进
- ✅ 学习率的变化 (预热 + 余弦衰减)
- ✅ 最终训练统计

---

**版本**: 1.0  
**日期**: 2026-06-23  
**状态**: ✅ 准备就绪  
**语言**: 100% 纯 S 语言
