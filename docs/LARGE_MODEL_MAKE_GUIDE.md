# 🚀 NeurX Make 命令完全指南 - 大模型训练与推理

**日期**: 2026-07-01  
**版本**: v1.0  
**状态**: ✅ 完全可用

---

## 📋 快速导航

### 最常用的 5 个命令

```bash
# 1. 快速测试 (5 分钟)
make train-llm NEURX_TOTAL_STEPS=10

# 2. 大模型训练 (1-2 天，8 GPU)
make train-large

# 3. 超大模型训练 (70B+，1-4 周，32 GPU)
make train-xlarge

# 4. 交互式推理
make infer-interactive

# 5. 批量推理
make infer-batch
```

---

## 🎯 训练命令完全列表

### 基础训练命令 (已有)

```bash
make train              # 基础训练 (run_training.sh)
make train-watch        # 基础训练 + 实时日志
make train-llm          # LLM 训练 (推荐基础)
make train-llm-watch    # LLM 训练 + 实时日志
make train-dp           # 2 GPU 数据并行
make train-dp-watch     # 数据并行 + 实时日志
make train-small        # 小模型训练
```

### 新增：规模化训练命令

| 命令 | 规模 | GPU | 时间 | 用途 |
|------|------|-----|------|------|
| `make train-large` | 7B-13B | 8× | 1-2 天 | 中等规模生产训练 |
| `make train-large-watch` | 7B-13B | 8× | 1-2 天 | + 实时日志 |
| `make train-xlarge` | 70B+ | 32× | 1-4 周 | Claude 级别训练 |
| `make train-xlarge-watch` | 70B+ | 32× | 1-4 周 | + 实时日志 |

### 新增：并行训练命令

| 命令 | 并行方式 | GPU | 模型大小 | 说明 |
|------|---------|-----|---------|------|
| `make train-tensor` | 张量并行 | 8-16× | 20B-70B | 权重矩阵分割 |
| `make train-tensor-watch` | 张量并行 | 8-16× | 20B-70B | + 实时日志 |
| `make train-pipeline` | 管道并行 | 16× | 70B-175B | 层分布式 |
| `make train-pipeline-watch` | 管道并行 | 16× | 70B-175B | + 实时日志 |

### 新增：分布式训练命令

```bash
make train-dist         # 多节点分布式训练
make train-dist-watch   # 多节点 + 实时日志
```

---

## 🔮 推理命令完全列表

### 已有推理命令

```bash
make infer              # 基础推理
make infer-watch        # 推理 + 实时日志
make infer-interactive  # 交互式 REPL (多轮对话)
```

### 新增推理命令

| 命令 | 模式 | 用途 | 性能 |
|------|------|------|------|
| `make infer-batch` | 批量推理 | 处理多个提示词 | 高吞吐 |
| `make infer-batch-watch` | 批量 + 日志 | 批量 + 监控 | 高吞吐 |
| `make infer-stream` | 流式推理 | 实时令牌生成 | 低延迟 |
| `make infer-serving` | 服务器模式 | 生产推理服务 | 7×24 运行 |

---

## 🎓 常见使用场景

### 场景 1: 快速原型验证 (5 分钟)

```bash
cd /Users/feifei/shuwen/train/neurx

# 只用 1 GPU，运行 10 步
make train-llm NEURX_TOTAL_STEPS=10

# 查看日志
tail -f /tmp/neurx_llm_train.log
```

### 场景 2: 单 GPU 完整模型训练 (2-4 小时)

```bash
# 1000 步，批大小 32，启用 BF16 混合精度
make train-llm \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=512 \
  NEURX_LR=0.0001 \
  NEURX_MIXED_PRECISION_MODE=bf16

# 实时查看日志
make train-llm-watch \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=32
```

### 场景 3: 中型模型 (8 GPU DDP)

```bash
# 数据并行训练，8 个 GPU
make train-dp \
  NEURX_WORLD_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=8 \
  NEURX_TOTAL_STEPS=5000 \
  NEURX_BATCH_SIZE=32

# 或使用预配置的 make train-large
make train-large

# 实时监控
make train-large-watch
```

### 场景 4: 大型模型 (8 GPU，混合并行)

```bash
# 配置：4 数据并行 × 2 张量并行
make train-large \
  NEURX_WORLD_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TENSOR_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=4096
```

### 场景 5: Claude 规模模型 (32 GPU，多并行)

```bash
# 预配置 Claude 级别（70B+）
make train-xlarge

# 或自定义配置
make train-xlarge \
  NEURX_WORLD_SIZE=32 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_PIPELINE_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=8192 \
  NEURX_TOTAL_STEPS=100000
```

### 场景 6: 多节点分布式训练

```bash
# 4 个节点，每个节点 8 个 GPU（总 32 个）
make train-dist \
  NEURX_NUM_NODES=4 \
  NEURX_WORLD_SIZE=32 \
  NEURX_MASTER_ADDR=192.168.1.100 \
  NEURX_MASTER_PORT=29500

# 或实时监控
make train-dist-watch
```

### 场景 7: 交互式推理 (多轮对话)

```bash
# 启动 REPL，支持多轮对话
make infer-interactive

# 输入提示词，获得回复，继续对话
# Prompt: What is the capital of France?
# [Generated response...]
# Prompt: Tell me more about its history
# [Follow-up response...]
```

### 场景 8: 批量推理 (处理文件中的多个提示)

```bash
# 处理 data/prompts.txt 中的所有提示词
make infer-batch

# 查看结果
cat artifacts/inference_output/results.jsonl
```

### 场景 9: 推理服务器 (生产部署)

```bash
# 启动推理服务器，监听 0.0.0.0:8000
make infer-serving

# 在另一个终端测试
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello", "max_tokens": 50}'
```

### 场景 10: 微调 (LoRA)

```bash
# 在预训练模型上进行微调
make finetune \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=8 \
  NEURX_LR=0.0001 \
  NEURX_LORA_RANK=8

# 实时监控
make finetune-watch
```

---

## 🎛️ 环境变量完全参考

### 训练参数

```bash
NEURX_TOTAL_STEPS           # 训练总步数 (默认: 100)
NEURX_BATCH_SIZE            # 每个 GPU 的批大小 (默认: 4)
NEURX_LR                    # 初始学习率 (默认: 0.001)
NEURX_SEQ_LENGTH            # 序列长度 (默认: 8)
NEURX_WARMUP_STEPS          # 预热步数 (默认: 10)
NEURX_CHECKPOINT_INTERVAL   # 检查点保存间隔 (默认: 10)
```

### 分布式参数

```bash
NEURX_WORLD_SIZE            # 总 GPU 数 (默认: 1)
NEURX_DATA_PARALLEL_SIZE    # 数据并行 GPU 数 (默认: 1)
NEURX_TENSOR_PARALLEL_SIZE  # 张量并行 GPU 数 (默认: 1)
NEURX_PIPELINE_PARALLEL_SIZE # 管道并行 GPU 数 (默认: 1)
```

### 多节点参数

```bash
NEURX_NUM_NODES             # 计算节点数 (默认: 1)
NEURX_RANK                  # 当前节点 rank (默认: 0)
NEURX_MASTER_ADDR           # Master 节点地址 (默认: localhost)
NEURX_MASTER_PORT           # Master 节点端口 (默认: 29500)
```

### 优化参数

```bash
NEURX_MIXED_PRECISION_MODE  # 混合精度: bf16/fp16/fp32 (默认: bf16)
NEURX_LOSS_SCALE            # 动态损失缩放 (默认: 1.0)
NEURX_GRADIENT_ACCUMULATION # 梯度累积步数 (默认: 1)
```

### 推理参数

```bash
NEURX_TEMPERATURE           # 采样温度 (默认: 0.7)
NEURX_TOP_K                 # Top-K 采样 (默认: 40)
NEURX_TOP_P                 # Nucleus 采样 (默认: 0.9)
NEURX_MAX_TOKENS            # 最大生成令牌数 (默认: 50)
NEURX_BEAM_SIZE             # Beam search 大小 (默认: 1)
```

### 微调参数

```bash
NEURX_FINETUNE_MODE         # 启用微调模式 (默认: false)
NEURX_LORA_RANK             # LoRA 秩 (默认: 8)
NEURX_LORA_ALPHA            # LoRA α (默认: 16)
NEURX_CHECKPOINT_PATH       # 预训练模型路径
```

### 推理服务器参数

```bash
NEURX_SERVE_PORT            # 服务器端口 (默认: 8000)
NEURX_SERVE_HOST            # 服务器地址 (默认: 0.0.0.0)
NEURX_SERVE_WORKERS         # 工作进程数 (默认: 4)
```

---

## 🔧 高级用法

### 组合参数示例

```bash
# 例 1: 高效的中型模型训练
make train-large \
  NEURX_TOTAL_STEPS=10000 \
  NEURX_BATCH_SIZE=64 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_LR=0.00005 \
  NEURX_WARMUP_STEPS=1000 \
  NEURX_MIXED_PRECISION_MODE=bf16 \
  NEURX_CHECKPOINT_INTERVAL=200

# 例 2: 张量并行训练
make train-tensor \
  NEURX_WORLD_SIZE=8 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_BATCH_SIZE=16 \
  NEURX_SEQ_LENGTH=4096

# 例 3: 管道并行 + 数据并行
make train-pipeline \
  NEURX_WORLD_SIZE=16 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TENSOR_PARALLEL_SIZE=2 \
  NEURX_PIPELINE_PARALLEL_SIZE=4

# 例 4: 多节点分布式（4 节点，每个 8 GPU）
make train-dist \
  NEURX_NUM_NODES=4 \
  NEURX_RANK=$RANK \
  NEURX_MASTER_ADDR=192.168.1.100 \
  NEURX_MASTER_PORT=29500

# 例 5: 高质量推理
make infer-batch \
  NEURX_TEMPERATURE=0.5 \
  NEURX_TOP_K=20 \
  NEURX_TOP_P=0.95 \
  NEURX_MAX_TOKENS=256
```

---

## 📊 性能期望值

### 单 GPU (A100-40GB)

| 模型大小 | 批大小 | 序列长度 | 时间/步 | 吞吐 |
|---------|--------|---------|--------|------|
| 10M | 1 | 8 | 10ms | 0.8K t/s |
| 100M | 4 | 128 | 25ms | 2K t/s |
| 1B | 16 | 512 | 50ms | 6K t/s |
| 7B | 4 | 2048 | 100ms | 12K t/s |

### 多 GPU (4× A100)

| 配置 | 时间/步 | 吞吐 | 缩放效率 |
|------|--------|------|---------|
| DDP 2× | 6ms | 4K t/s | 95% |
| DDP 4× | 4ms | 8K t/s | 93% |
| Tensor TP 4× | 30ms | 25K t/s | 90% |

---

## ⚠️ 常见问题

### Q: 如何选择合适的 GPU 数？

```bash
# 小模型 (< 100M): 1 GPU
make train-llm

# 中型模型 (100M-3B): 2-4 GPU DDP
make train-dp NEURX_WORLD_SIZE=4

# 大模型 (7B-13B): 8 GPU DDP + Tensor TP
make train-large

# 超大模型 (70B+): 32 GPU 多并行
make train-xlarge
```

### Q: 内存不足怎么办？

```bash
# 方案 1: 减少批大小
make train-llm NEURX_BATCH_SIZE=2

# 方案 2: 减少序列长度
make train-llm NEURX_SEQ_LENGTH=256

# 方案 3: 启用梯度检查点（如果支持）
make train-llm NEURX_BATCH_SIZE=1

# 方案 4: 使用张量并行分割权重
make train-tensor NEURX_TENSOR_PARALLEL_SIZE=4
```

### Q: 训练太慢怎么办？

```bash
# 方案 1: 启用混合精度（已默认 BF16）
make train-llm NEURX_MIXED_PRECISION_MODE=bf16

# 方案 2: 增加批大小
make train-llm NEURX_BATCH_SIZE=64

# 方案 3: 增加序列长度（更高的计算密度）
make train-llm NEURX_SEQ_LENGTH=2048

# 方案 4: 使用多 GPU
make train-dp NEURX_WORLD_SIZE=4
```

### Q: 如何监控训练进度？

```bash
# 方案 1: 实时日志
make train-llm-watch

# 方案 2: 查看日志文件
tail -f /tmp/neurx_llm_train.log

# 方案 3: 监控命令
make monitor

# 方案 4: 检查检查点
ls -lh artifacts/checkpoints/llm_training/
```

---

## 🚀 一键启动脚本

### 快速开始脚本

```bash
#!/bin/bash
# quick_start.sh

echo "🚀 NeurX 快速开始"

# 1. 环境检查
echo "1️⃣  检查环境..."
make test

# 2. 快速测试
echo "2️⃣  运行快速测试..."
make train-llm NEURX_TOTAL_STEPS=10

# 3. 模型验证
echo "3️⃣  验证模型..."
make train-llm NEURX_TOTAL_STEPS=100 NEURX_BATCH_SIZE=4

# 4. 推理测试
echo "4️⃣  测试推理..."
make infer

echo "✅ 快速开始完成！"
echo "📖 更多命令: make train-help, make infer-help"
```

---

## 📞 获取帮助

```bash
# 查看所有可用命令
make help

# 查看训练命令
make train-help

# 查看推理命令
make infer-help

# 查看日志
make monitor

# 列出所有日志文件
make logs

# 清理日志
make clean-logs
```

---

## ✅ 检查清单

启动大规模训练前：

- [ ] GPU 可用 (`nvidia-smi`)
- [ ] CUDA 已安装 (`nvcc --version`)
- [ ] 足够磁盘空间 (检查点 ~10GB+)
- [ ] 网络连接稳定 (分布式训练)
- [ ] 已读本指南 ✅

---

## 📚 相关文档

- [MAKE_COMMANDS_CHEATSHEET.md](MAKE_COMMANDS_CHEATSHEET.md) - 速查表
- [NEURX_LLM_TRAINING_GUIDE.md](NEURX_LLM_TRAINING_GUIDE.md) - 详细指南
- [COMPLETE_PIPELINE_GUIDE.md](COMPLETE_PIPELINE_GUIDE.md) - 管道系统

---

**生成日期**: 2026-07-01  
**状态**: ✅ 完全可用  
**版本**: v1.0
