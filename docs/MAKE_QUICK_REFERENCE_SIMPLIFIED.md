# 🚀 NeurX 简化版 - 两个命令

**原则**: 简洁就是力量

---

## 两个命令，掌握一切

### **1. 训练**
```bash
make train
```

### **2. 推理**
```bash
make infer
```

---

## 常用配置

### 训练
```bash
# 快速测试 (5 min)
make train NEURX_TOTAL_STEPS=10

# 标准训练 (1-2 小时)
make train NEURX_TOTAL_STEPS=1000 NEURX_BATCH_SIZE=32

# 大规模 (多天，多 GPU)
make train NEURX_TOTAL_STEPS=100000 NEURX_BATCH_SIZE=64 NEURX_WORLD_SIZE=8
```

### 推理
```bash
# 基础
make infer

# 高质量
make infer NEURX_TEMPERATURE=0.5 NEURX_MAX_TOKENS=256
```

---

## 环境变量一览

| 变量 | 训练 | 推理 | 说明 |
|------|------|------|------|
| `NEURX_TOTAL_STEPS` | ✅ | - | 训练步数 |
| `NEURX_BATCH_SIZE` | ✅ | ✅ | 批大小 |
| `NEURX_LR` | ✅ | - | 学习率 |
| `NEURX_SEQ_LENGTH` | ✅ | - | 序列长度 |
| `NEURX_WORLD_SIZE` | ✅ | - | GPU 数 |
| `NEURX_TEMPERATURE` | - | ✅ | 采样温度 |
| `NEURX_TOP_K` | - | ✅ | Top-K |
| `NEURX_TOP_P` | - | ✅ | Nucleus |
| `NEURX_MAX_TOKENS` | - | ✅ | 最大长度 |

---

## 实际例子

```bash
# 例 1: 快速验证环境
make train NEURX_TOTAL_STEPS=10

# 例 2: 实际训练一个模型
make train NEURX_TOTAL_STEPS=1000 NEURX_BATCH_SIZE=32 NEURX_SEQ_LENGTH=512

# 例 3: 多 GPU 训练
make train NEURX_WORLD_SIZE=4 NEURX_BATCH_SIZE=32 NEURX_TOTAL_STEPS=5000

# 例 4: 运行推理
make infer

# 例 5: 高质量推理
make infer NEURX_TEMPERATURE=0.3 NEURX_TOP_P=0.9 NEURX_MAX_TOKENS=512
```

---

## 监控

```bash
# 查看训练状态
make monitor

# 查看日志
tail -f /tmp/neurx_llm_train.log

# 查看检查点
ls artifacts/checkpoints/
```

---

**简洁优雅** ✨
