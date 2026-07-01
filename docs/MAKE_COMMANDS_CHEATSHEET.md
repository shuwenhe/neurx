# 🚀 NeurX Make 命令速查表

**快速参考** | 最常用的命令一目了然

---

## 📋 核心命令

### 训练命令
```bash
make train              # 基础训练
make train-llm          # LLM 训练 ⭐ 推荐
make train-llm-watch    # LLM 训练 + 日志
make train-dp           # 2 GPU 数据并行
make train-dp-watch     # 2 GPU + 日志
make train-small        # 小模型训练
```

### 推理命令
```bash
make infer              # 运行推理
make infer-watch        # 推理 + 日志
make infer-interactive  # 交互式推理（多轮对话）
```

### 测试命令
```bash
make test               # Transformer 单元测试
make test-transformer-e2e  # 端到端测试
```

---

## ⚡ 快速示例

### 最快开始 (1 分钟)
```bash
make train-llm NEURX_TOTAL_STEPS=10
```

### 标准训练 (30 分钟)
```bash
make train-llm \
  NEURX_TOTAL_STEPS=100 \
  NEURX_BATCH_SIZE=8 \
  NEURX_SEQ_LENGTH=512
```

### 多 GPU 训练 (2+ 小时)
```bash
make train-dp \
  NEURX_WORLD_SIZE=4 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=16
```

---

## 🎛️ 环境变量配置

| 变量 | 默认 | 示例用法 |
|------|------|--------|
| `NEURX_TOTAL_STEPS` | 100 | `NEURX_TOTAL_STEPS=1000` |
| `NEURX_BATCH_SIZE` | 4 | `NEURX_BATCH_SIZE=32` |
| `NEURX_LR` | 0.001 | `NEURX_LR=0.0005` |
| `NEURX_SEQ_LENGTH` | 8 | `NEURX_SEQ_LENGTH=2048` |
| `NEURX_WARMUP_STEPS` | 10 | `NEURX_WARMUP_STEPS=100` |
| `NEURX_CHECKPOINT_INTERVAL` | 10 | `NEURX_CHECKPOINT_INTERVAL=50` |
| `NEURX_WORLD_SIZE` | 1 | `NEURX_WORLD_SIZE=8` |
| `NEURX_DATA_PARALLEL_SIZE` | 1 | `NEURX_DATA_PARALLEL_SIZE=4` |
| `NEURX_TENSOR_PARALLEL_SIZE` | 1 | `NEURX_TENSOR_PARALLEL_SIZE=2` |
| `NEURX_MIXED_PRECISION_MODE` | bf16 | `NEURX_MIXED_PRECISION_MODE=fp16` |

---

## 🔥 常用命令组合

### 场景 1: 快速测试（5 分钟）
```bash
make train-llm NEURX_TOTAL_STEPS=10
```

### 场景 2: 验证模型（30 分钟）
```bash
make train-llm \
  NEURX_TOTAL_STEPS=100 \
  NEURX_BATCH_SIZE=4
```

### 场景 3: 单 GPU 完整训练（2-4 小时）
```bash
make train-llm \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=16 \
  NEURX_SEQ_LENGTH=512 \
  NEURX_LR=0.0001 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

### 场景 4: 多 GPU 训练（多天）
```bash
make train-dp \
  NEURX_WORLD_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TENSOR_PARALLEL_SIZE=2 \
  NEURX_TOTAL_STEPS=10000 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

### 场景 5: 张量并行（大模型）
```bash
make train-llm \
  NEURX_WORLD_SIZE=8 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_BATCH_SIZE=16 \
  NEURX_SEQ_LENGTH=4096
```

---

## 📊 推荐配置模板

### 小模型（< 100M）
```bash
make train-llm \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=512 \
  NEURX_LR=0.001
```

### 中等模型（100M - 1B）
```bash
make train-dp \
  NEURX_WORLD_SIZE=2 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=16 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_LR=0.0005 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

### 大模型（1B - 10B）
```bash
make train-dp \
  NEURX_WORLD_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TENSOR_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=4096 \
  NEURX_LR=0.0001 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

### Claude 级别（70B+）
```bash
make train-llm \
  NEURX_WORLD_SIZE=32 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_PIPELINE_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=8192 \
  NEURX_LR=0.00005 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

---

## 📂 输出位置

| 类型 | 位置 | 说明 |
|------|------|------|
| 检查点 | `artifacts/checkpoints/llm_training/` | 模型权重 |
| 日志 | `/tmp/neurx_llm_train.log` | 训练日志 |
| 输出 | `artifacts/checkpoints/llm_s_pretrain/` | 预训练输出 |

---

## 🔧 故障排查

### 问题: "make: command not found"
```bash
# 安装 make
apt-get install make      # Linux
brew install make         # macOS
```

### 问题: 内存不足
```bash
# 减少批大小和序列长度
make train-llm NEURX_BATCH_SIZE=2 NEURX_SEQ_LENGTH=256
```

### 问题: GPU 未检测到
```bash
# 检查 GPU
nvidia-smi

# 检查 CUDA
nvcc --version
```

### 问题: 训练缓慢
```bash
# 启用混合精度
make train-llm NEURX_MIXED_PRECISION_MODE=bf16

# 增加批大小
make train-llm NEURX_BATCH_SIZE=64
```

---

## 💡 性能建议

| 优化 | 命令 | 效果 |
|------|------|------|
| 启用混合精度 | `NEURX_MIXED_PRECISION_MODE=bf16` | 🚀 2× 快速 |
| 增加批大小 | `NEURX_BATCH_SIZE=64` | 📈 更高吞吐 |
| 多 GPU | `make train-dp` | ⚡ 线性扩展 |
| 长序列 | `NEURX_SEQ_LENGTH=2048` | 📊 更好的学习 |
| 降低学习率 | `NEURX_LR=0.0001` | 🎯 稳定收敛 |

---

## 📖 详细文档

- **完整指南**: [NEURX_LLM_TRAINING_GUIDE.md](NEURX_LLM_TRAINING_GUIDE.md)
- **快速开始**: [QUICK_START.md](QUICK_START.md)
- **训练指南**: [TRAINING_GUIDE.md](TRAINING_GUIDE.md)
- **管道说明**: [COMPLETE_PIPELINE_GUIDE.md](COMPLETE_PIPELINE_GUIDE.md)

---

## 🎯 常见目标

```bash
make help                   # 显示所有可用命令
make install                # 安装 NeurX
make clean                  # 清理构建产物
make neurx                  # 编译 NeurX 框架
make code-agent             # 运行代码助手
```

---

## ✅ 检查清单

启动训练前：

- [ ] `nvidia-smi` 显示 GPU
- [ ] `neurx --version` 正常
- [ ] `make help` 显示命令
- [ ] 有足够磁盘空间
- [ ] 网络连接正常

---

## 🚀 立即开始

```bash
# 1. 查看所有命令
make help

# 2. 运行快速测试
make train-llm NEURX_TOTAL_STEPS=10

# 3. 查看日志
tail -f /tmp/neurx_llm_train.log

# 4. 完整训练
make train-llm NEURX_TOTAL_STEPS=1000
```

---

**状态**: ✅ 完整可用  
**最后更新**: 2026-07-01
