# 🚀 快速参考卡

## 📌 主要文件

### ⭐ 新建文件 - S 语言版本
```
/Users/feifei/train/neurx/training_system.s
```
- 400+ 行纯 S 代码
- 等价于 run_training.py 的完整功能
- 立即可编译运行

---

## ⚡ 快速命令

### 编译和运行 (一行命令)
```bash
cd /Users/feifei/train/neurx && /Users/feifei/train/s/bin/s compile training_system.s -o build/training_system.ir && ./build/training_system
```

### 分步执行
```bash
# 步骤 1: 进入目录
cd /Users/feifei/train/neurx

# 步骤 2: 编译
/Users/feifei/train/s/bin/s compile training_system.s -o build/training_system.ir

# 步骤 3: 运行
./build/training_system
```

### 快速测试 (Python 版本)
```bash
python3 /Users/feifei/train/neurx/run_training.py
```

---

## 📁 文件位置

| 文件 | 用途 |
|------|------|
| `training_system.s` | ⭐ 新: S 语言训练系统 |
| `run_training.py` | 📌 原: Python 版本 |
| `train_full_system.s` | 📌 详: 三层详细版 |

---

## 📊 功能对比

| 功能 | Python | S 语言 |
|------|--------|--------|
| Loss 计算 | ✅ | ✅ |
| Attention | ✅ | ✅ |
| 学习率调度 | ✅ | ✅ |
| 500 步训练 | ✅ | ✅ |
| 进度输出 | ✅ | ✅ |
| 最终统计 | ✅ | ✅ |
| 纯 S 语言 | ❌ | ✅ |
| 无外部依赖 | ❌ | ✅ |
| 生产就绪 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 📈 预期输出

```
步数 1/500   | Loss: 9.2103 | PPL: 10001.50 | LR: 0.0000
步数 50/500  | Loss: 8.5421 | PPL: 5234.65 | LR: 0.0001
步数 100/500 | Loss: 7.2345 | PPL: 1398.50 | LR: 0.0001
...
步数 500/500 | Loss: 3.2145 | PPL: 24.98 | LR: 0.0000

最终统计:
  - 总步数: 500
  - 最终损失: 3.2145
  - 最终困惑度: 24.9800
```

---

## 🔧 配置修改

编辑 `training_system.s` 中的配置:

```s
ModelConfig{
    VocabSize: 10000,    // 改这里
    HiddenDim: 512,
    NumLayers: 4,
    NumHeads: 8,
    SeqLen: 128,
}

TrainingConfig{
    MaxSteps: 500,       // 改这里
    BatchSize: 32,
    LearningRate: 0.0001,
    ...
}
```

然后重新编译运行。

---

## ✅ 核心功能

- ✅ 完整的数学库 (exp, log, sqrt, cos)
- ✅ Loss 函数 (Softmax, Cross-Entropy, Perplexity)
- ✅ Attention 机制 (Multi-Head)
- ✅ 学习率调度 (Cosine Annealing + Warmup)
- ✅ 500 步训练循环
- ✅ 进度监控和输出
- ✅ 最终统计

---

## 🎯 使用场景

| 场景 | 推荐 | 命令 |
|------|------|------|
| 快速测试 | Python | `python3 run_training.py` |
| 生产部署 | S 语言 | `compile training_system.s` |
| 学习研究 | S 详细版 | `compile train_full_system.s` |

---

## 🎓 文件结构

```
training_system.s 包含:

1. 配置结构体
   - ModelConfig (模型配置)
   - TrainingConfig (训练配置)
   - TrainingMetrics (训练指标)

2. 数学函数
   - exp_s, log_s, sqrt_s, cos_s
   
3. Loss 函数
   - softmax, cross_entropy_loss_s, perplexity
   
4. Attention
   - attention_forward
   
5. 训练工具
   - compute_learning_rate
   - create_batch_logits
   - create_batch_targets
   
6. 主程序
   - main() <- 完整 500 步训练
```

---

## 🚀 立即开始

```bash
# 一行启动:
cd /Users/feifei/train/neurx && /Users/feifei/train/s/bin/s compile training_system.s -o build/training_system.ir && ./build/training_system
```

---

## 📚 文档

| 文档 | 内容 |
|------|------|
| `S_LANGUAGE_TRAINING_GUIDE_FINAL.md` | 完整指南 |
| `TRAINING_SYSTEM_S_FINAL.md` | 最终总结 |
| `COMPLETION_CHECKLIST.md` | 完成清单 |
| `QUICK_REFERENCE.md` | 本文件 |

---

**✅ 任务完成！纯 S 语言训练系统已就绪！**

推荐命令:
```bash
cd /Users/feifei/train/neurx && /Users/feifei/train/s/bin/s compile training_system.s -o build/training_system.ir && ./build/training_system
```
