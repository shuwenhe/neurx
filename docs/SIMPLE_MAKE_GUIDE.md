# 🚀 NeurX 简化版 - 两个基本 Make 命令

**原则**: 简洁 = 力量

---

## 📋 仅有的两个命令

### 1. **make train** - 训练

```bash
make train
```

**功能**: 运行模型训练  
**配置**: 通过环境变量

**常用配置**:
```bash
# 快速测试 (5 分钟)
make train NEURX_TOTAL_STEPS=10

# 标准训练 (1-2 小时)
make train NEURX_TOTAL_STEPS=1000 NEURX_BATCH_SIZE=32

# 大规模训练 (多天)
make train NEURX_TOTAL_STEPS=100000 NEURX_BATCH_SIZE=64 NEURX_WORLD_SIZE=8
```

### 2. **make infer** - 推理

```bash
make infer
```

**功能**: 运行模型推理  
**配置**: 通过环境变量

**常用配置**:
```bash
# 基础推理
make infer

# 高质量推理
make infer NEURX_TEMPERATURE=0.5 NEURX_MAX_TOKENS=256
```

---

## 🎯 快速使用

### 训练模型

```bash
# 步骤 1: 基础训练
make train NEURX_TOTAL_STEPS=100 NEURX_BATCH_SIZE=4

# 步骤 2: 查看日志
tail -f /tmp/neurx_llm_train.log

# 步骤 3: 检查检查点
ls -lh artifacts/checkpoints/
```

### 推理

```bash
# 运行推理
make infer

# 交互式推理
make infer-interactive
```

---

## 🎛️ 环境变量

### 训练参数

```
NEURX_TOTAL_STEPS         训练步数 (默认: 100)
NEURX_BATCH_SIZE          批大小 (默认: 4)
NEURX_LR                  学习率 (默认: 0.001)
NEURX_SEQ_LENGTH          序列长度 (默认: 8)
NEURX_WARMUP_STEPS        预热步数 (默认: 10)
NEURX_WORLD_SIZE          GPU 总数 (默认: 1)
NEURX_MIXED_PRECISION_MODE 精度模式: bf16/fp16/fp32 (默认: bf16)
```

### 推理参数

```
NEURX_TEMPERATURE         采样温度 (默认: 0.7)
NEURX_TOP_K              Top-K 采样 (默认: 40)
NEURX_TOP_P              Nucleus 采样 (默认: 0.9)
NEURX_MAX_TOKENS         最大生成令牌 (默认: 50)
```

---

## 💡 使用示例

### 例 1: 快速原型 (5 分钟)
```bash
make train NEURX_TOTAL_STEPS=10
```

### 例 2: 单 GPU 训练 (2 小时)
```bash
make train \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=512
```

### 例 3: 多 GPU 训练 (1 小时)
```bash
make train \
  NEURX_WORLD_SIZE=4 \
  NEURX_BATCH_SIZE=32 \
  NEURX_TOTAL_STEPS=1000
```

### 例 4: 高精度推理
```bash
make infer \
  NEURX_TEMPERATURE=0.5 \
  NEURX_TOP_P=0.95 \
  NEURX_MAX_TOKENS=512
```

---

## ✅ 就是这么简单

**训练**: 
```bash
make train NEURX_TOTAL_STEPS=1000
```

**推理**:
```bash
make infer
```

**完成！** 🎉

---

**日期**: 2026-07-01  
**哲学**: Keep It Simple, Stupid (KISS)
