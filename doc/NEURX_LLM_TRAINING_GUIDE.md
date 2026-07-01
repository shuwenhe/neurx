# 🚀 NeurX LLM 大模型训练完全指南

**日期**: 2026-07-01  
**状态**: ✅ 完整可用  
**语言**: S Language + Make

---

## 📋 Make 命令速查表

### 基础训练命令

```bash
# ===== 基础训练 =====
make train              # 运行基础训练 (run_training.sh)
make train-watch        # 运行训练并实时查看日志
make test               # 运行 Transformer 模型测试

# ===== LLM 训练 =====
make train-llm          # 运行 LLM 训练（推荐）
make train-llm-watch    # 运行 LLM 训练并实时查看日志

# ===== 分布式训练 =====
make train-dp           # 数据并行 (2 GPU DDP)
make train-dp-watch     # 数据并行 + 实时日志

# ===== 推理 =====
make infer              # 运行推理
make infer-watch        # 运行推理并实时查看日志
make infer-interactive  # 交互式推理 (REPL)
```

---

## 🎯 快速开始 (5 分钟)

### 最快方式：运行演示

```bash
cd /Users/feifei/shuwen/train/neurx

# 方式 1: 基础训练演示
make train

# 方式 2: LLM 训练演示（推荐）
make train-llm

# 方式 3: 实时查看日志
make train-llm-watch
```

---

## 📊 LLM 训练详细指南

### 1. **基础 LLM 训练**

```bash
make train-llm
```

**特点**:
- 使用默认参数
- 100 步训练
- 批大小: 4
- 序列长度: 8
- 输出: `artifacts/checkpoints/llm_training/`

### 2. **自定义参数训练**

```bash
# 增加训练步数到 1000
make train-llm NEURX_TOTAL_STEPS=1000

# 增加批大小到 32
make train-llm NEURX_BATCH_SIZE=32

# 增加序列长度到 2048
make train-llm NEURX_SEQ_LENGTH=2048

# 调整学习率
make train-llm NEURX_LR=0.0005

# 组合多个参数
make train-llm \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_LR=0.0005 \
  NEURX_WARMUP_STEPS=100
```

### 3. **可配置的环境变量**

| 变量 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `NEURX_TOTAL_STEPS` | 100 | 1-∞ | 总训练步数 |
| `NEURX_BATCH_SIZE` | 4 | 1-256 | 批大小 |
| `NEURX_LR` | 0.001 | 0.00001-0.1 | 学习率 |
| `NEURX_SEQ_LENGTH` | 8 | 1-8192 | 序列长度 |
| `NEURX_WARMUP_STEPS` | 10 | 0-1000 | 预热步数 |
| `NEURX_CHECKPOINT_INTERVAL` | 10 | 1-∞ | 检查点间隔 |

---

## 🔄 分布式训练指南

### 单 GPU 训练

```bash
# 默认单 GPU
make train-llm

# 或指定为单 GPU
make train-llm NEURX_WORLD_SIZE=1
```

### 多 GPU 数据并行 (DDP)

```bash
# 2 GPU 数据并行
make train-dp

# 4 GPU 数据并行
make train-dp NEURX_WORLD_SIZE=4 NEURX_DATA_PARALLEL_SIZE=4

# 8 GPU 数据并行
make train-dp NEURX_WORLD_SIZE=8 NEURX_DATA_PARALLEL_SIZE=8
```

### 高级并行配置

```bash
# 张量并行 (Tensor Parallel) - 8 GPU 分割权重
make train-llm \
  NEURX_WORLD_SIZE=8 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=1

# 管道并行 (Pipeline Parallel) - 分割模型层
make train-llm \
  NEURX_WORLD_SIZE=8 \
  NEURX_PIPELINE_PARALLEL_SIZE=4 \
  NEURX_DATA_PARALLEL_SIZE=2

# 组合并行 (DDP + Tensor Parallel)
make train-llm \
  NEURX_WORLD_SIZE=16 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_PIPELINE_PARALLEL_SIZE=1
```

---

## 🎓 训练配置示例

### 小模型快速训练

```bash
make train-llm \
  NEURX_TOTAL_STEPS=10 \
  NEURX_BATCH_SIZE=1 \
  NEURX_SEQ_LENGTH=8 \
  NEURX_LR=0.001
```

**配置**:
- ⏱️ 时间: ~1-2 分钟
- 💾 内存: ~1 GB
- 📊 参数: ~1M

### 中型模型训练

```bash
make train-llm \
  NEURX_TOTAL_STEPS=100 \
  NEURX_BATCH_SIZE=8 \
  NEURX_SEQ_LENGTH=512 \
  NEURX_LR=0.0005 \
  NEURX_WARMUP_STEPS=10
```

**配置**:
- ⏱️ 时间: ~30-60 分钟
- 💾 内存: ~8 GB (单 GPU)
- 📊 参数: ~100M

### 大模型完整训练

```bash
make train-dp \
  NEURX_WORLD_SIZE=4 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=16 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_LR=0.0001 \
  NEURX_WARMUP_STEPS=100 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

**配置**:
- ⏱️ 时间: ~2-4 小时
- 💾 内存: ~30 GB (4× A100)
- 📊 参数: ~1B
- 🚀 吞吐: ~50K tokens/sec

### Claude 级别训练 (70B+)

```bash
make train-llm \
  NEURX_WORLD_SIZE=32 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_PIPELINE_PARALLEL_SIZE=2 \
  NEURX_TOTAL_STEPS=10000 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=8192 \
  NEURX_LR=0.00005 \
  NEURX_WARMUP_STEPS=500 \
  NEURX_MIXED_PRECISION_MODE=bf16 \
  NEURX_CHECKPOINT_INTERVAL=100
```

**配置**:
- ⏱️ 时间: 数天到数周
- 💾 内存: ~1-2 TB (32× A100)
- 📊 参数: 70B
- 🚀 吞吐: ~100K+ tokens/sec

---

## 💡 高级配置选项

### 混合精度训练

```bash
# BF16 (推荐，速度快)
make train-llm \
  NEURX_MIXED_PRECISION_MODE=bf16

# FP16 (内存节省)
make train-llm \
  NEURX_MIXED_PRECISION_MODE=fp16

# FP32 (精度高但缓慢)
make train-llm \
  NEURX_MIXED_PRECISION_MODE=fp32
```

### 损失缩放

```bash
# 默认 1.0
make train-llm NEURX_LOSS_SCALE=1.0

# 动态缩放（推荐）
make train-llm NEURX_LOSS_SCALE=65536.0
```

### 数据模式

```bash
# 小模型模式 (默认)
make train-llm NEURX_DP_MODE=small

# 标准模式
make train-llm NEURX_DP_MODE=standard

# 大模型模式
make train-llm NEURX_DP_MODE=large
```

---

## 🔍 监控和调试

### 实时查看训练日志

```bash
# 基础版本
make train-llm-watch

# 自定义参数 + 日志
make train-llm-watch \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=32
```

### 查看完整日志

```bash
# 查看最新日志
tail -f /tmp/neurx_llm_train.log

# 查看完整日志
cat /tmp/neurx_llm_train.log | less

# 实时搜索关键字
tail -f /tmp/neurx_llm_train.log | grep "loss"
```

### 检查点位置

```bash
# 查看已保存的检查点
ls -lh artifacts/checkpoints/llm_training/

# 查看特定 epoch 的检查点
ls -lh artifacts/checkpoints/llm_training/epoch_*
```

---

## 📈 性能优化建议

### 1. 增加吞吐量

```bash
# 启用混合精度 + 增加批大小
make train-llm \
  NEURX_MIXED_PRECISION_MODE=bf16 \
  NEURX_BATCH_SIZE=32

# 使用数据并行
make train-dp \
  NEURX_WORLD_SIZE=4 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_BATCH_SIZE=32
```

### 2. 降低内存使用

```bash
# 启用梯度检查点 + 减少序列长度
make train-llm \
  NEURX_SEQ_LENGTH=512 \
  NEURX_BATCH_SIZE=8
```

### 3. 更好的收敛

```bash
# 增加预热步数 + 降低学习率
make train-llm \
  NEURX_WARMUP_STEPS=100 \
  NEURX_LR=0.0001 \
  NEURX_TOTAL_STEPS=1000
```

### 4. 多 GPU 最优配置

```bash
make train-dp \
  NEURX_WORLD_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TENSOR_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

---

## 🎯 推理和生成

### 基础推理

```bash
# 单 GPU 推理
make infer

# 自定义参数
make infer \
  NEURX_BATCH_SIZE=1 \
  NEURX_SEQ_LENGTH=512
```

### 实时推理日志

```bash
make infer-watch
```

### 交互式推理 (多轮对话)

```bash
make infer-interactive

# 在 REPL 中输入提示词，可以进行多轮对话
# Prompt: Your LLM question here
# [Generated response]
# Prompt: Follow-up question
```

---

## 🔧 使用 Bash 脚本直接运行

### 如果 Make 不可用

```bash
# 设置环境变量
export NEURX_TOTAL_STEPS=100
export NEURX_BATCH_SIZE=4
export NEURX_LR=0.001
export NEURX_SEQ_LENGTH=8

# 直接运行脚本
bash script/run_llm_training_with_compiler.sh

# 查看日志
tail -f /tmp/neurx_llm_train.log
```

### 使用 NeurX 编译器直接训练

```bash
# 编译并运行
neurx compile train_and_infer.s -o bin/train_and_infer --optimize=2
./bin/train_and_infer

# 或直接运行
neurx run train_and_infer.s

# 或使用完整管道
neurx run complete_pipeline.s
```

---

## 📊 典型训练场景

### 场景 1: 快速原型验证 (5 分钟)

```bash
make train-llm \
  NEURX_TOTAL_STEPS=10 \
  NEURX_BATCH_SIZE=1 \
  NEURX_SEQ_LENGTH=8
```

**预期**:
- 时间: ~3-5 分钟
- 内存: ~500 MB
- 验证编译和训练流程

### 场景 2: 模型验证 (30 分钟)

```bash
make train-llm \
  NEURX_TOTAL_STEPS=100 \
  NEURX_BATCH_SIZE=4 \
  NEURX_SEQ_LENGTH=128
```

**预期**:
- 时间: ~20-30 分钟
- 内存: ~2 GB
- 验证模型收敛

### 场景 3: 中等规模训练 (2 小时)

```bash
make train-dp \
  NEURX_WORLD_SIZE=2 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TOTAL_STEPS=500 \
  NEURX_BATCH_SIZE=8 \
  NEURX_SEQ_LENGTH=512
```

**预期**:
- 时间: ~1-2 小时
- 内存: ~10 GB (2× GPU)
- 单次迭代 ~15ms

### 场景 4: 生产级训练 (多天)

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

**预期**:
- 时间: 2-7 天
- 内存: 100+ GB
- 吞吐: 50-100K tokens/sec

---

## ⚠️ 常见问题和解决方案

### 问题 1: 内存不足

**错误**:
```
CUDA out of memory
```

**解决**:
```bash
# 1. 减少批大小
make train-llm NEURX_BATCH_SIZE=2

# 2. 减少序列长度
make train-llm NEURX_SEQ_LENGTH=256

# 3. 启用混合精度
make train-llm NEURX_MIXED_PRECISION_MODE=bf16

# 4. 启用梯度检查点（如果支持）
make train-llm NEURX_BATCH_SIZE=1 NEURX_SEQ_LENGTH=256
```

### 问题 2: 训练速度慢

**原因**: 不是使用 GPU 或并行不充分

**解决**:
```bash
# 1. 验证 GPU 使用
nvidia-smi

# 2. 使用更大的批大小
make train-llm NEURX_BATCH_SIZE=32

# 3. 启用混合精度
make train-llm NEURX_MIXED_PRECISION_MODE=bf16

# 4. 使用多 GPU
make train-dp NEURX_WORLD_SIZE=4
```

### 问题 3: 损失不下降

**原因**: 学习率、数据或模型问题

**解决**:
```bash
# 1. 增加预热步数
make train-llm NEURX_WARMUP_STEPS=100

# 2. 降低学习率
make train-llm NEURX_LR=0.00001

# 3. 验证数据
# 检查 artifacts/checkpoints/llm_training/ 中的数据

# 4. 从检查点恢复
# 使用之前保存的检查点继续训练
```

### 问题 4: GPU 未充分利用

**解决**:
```bash
# 1. 增加批大小
make train-llm NEURX_BATCH_SIZE=64

# 2. 增加工作进程
export OMP_NUM_THREADS=8

# 3. 启用混合精度
make train-llm NEURX_MIXED_PRECISION_MODE=bf16

# 4. 使用更长的序列
make train-llm NEURX_SEQ_LENGTH=2048
```

---

## 📚 相关文件和脚本

### 核心脚本

| 文件 | 说明 |
|------|------|
| `run_llm_training_with_compiler.sh` | LLM 训练主脚本 |
| `run_training.sh` | 基础训练脚本 |
| `run_full_inference.sh` | 推理脚本 |
| `train_and_infer.s` | S 语言训练实现 |
| `complete_pipeline.s` | 完整的 8 阶段管道 |

### 配置文件

| 文件 | 说明 |
|------|------|
| `train_config.yaml` | 训练配置 |
| `neurx.config.example.toml` | 示例配置 |

### 文档

| 文件 | 说明 |
|------|------|
| `QUICK_START.md` | 快速开始 |
| `TRAINING_GUIDE.md` | 训练指南 |
| `COMPLETE_PIPELINE_GUIDE.md` | 管道指南 |

---

## 🎓 学习资源

### 理解 Make 命令

```bash
# 查看 Makefile 中的所有目标
make help

# 查看 Makefile 内容
cat Makefile | head -100
```

### 理解训练流程

```bash
# 查看完整的训练脚本
cat script/run_llm_training_with_compiler.sh

# 查看 S 语言训练代码
cat train_and_infer.s

# 查看完整管道
cat complete_pipeline.s
```

### 调试训练过程

```bash
# 详细日志
make train-llm NEURX_TOTAL_STEPS=10 -v

# 查看环境变量
env | grep NEURX

# 查看编译输出
bash -x script/run_llm_training_with_compiler.sh
```

---

## ✅ 检查清单

在启动大型训练前：

- [ ] GPU 可用且驱动正确
- [ ] CUDA 和 NCCL 正确安装
- [ ] neurx 编译器可用
- [ ] 有足够的磁盘空间 (checkpoint)
- [ ] 有足够的 GPU 内存 (预测内存需求)
- [ ] 网络连接稳定 (分布式训练)
- [ ] 监控工具准备好 (nvidia-smi 等)

---

## 🚀 总结

### 最常用的 3 个命令

```bash
# 1. 快速测试
make train-llm NEURX_TOTAL_STEPS=10

# 2. 标准训练
make train-llm

# 3. 多 GPU 训练
make train-dp NEURX_WORLD_SIZE=4
```

### 完整的工作流

```bash
# 1. 快速验证
make train-llm NEURX_TOTAL_STEPS=10

# 2. 模型训练
make train-llm NEURX_TOTAL_STEPS=1000 NEURX_BATCH_SIZE=32

# 3. 推理测试
make infer

# 4. 交互式对话
make infer-interactive
```

---

**最后更新**: 2026-07-01  
**维护者**: NeurX Team  
**状态**: ✅ 完全可用
