# GPU 预训练断点续训 - 快速参考 (Quick Reference)

## 三行上手

```bash
# 首次训练（自动从头开始）
make pretrain-gpu

# 中断后恢复训练（自动检测checkpoint）
make pretrain-gpu

# 强制新训练（忽略现有checkpoint）
make pretrain-gpu-fresh
```

## 4种模式

| 命令 | 行为 | 何时使用 |
|------|------|--------|
| `make pretrain-gpu` | 自动恢复或新训练 | ✅ 推荐，默认模式 |
| `make pretrain-gpu-resume` | 显式恢复 | 明确指定意图 |
| `make pretrain-gpu-fresh` | 强制新训练 | 要从头开始 |
| `NEURX_PRETRAIN_RESUME=no make pretrain-gpu` | 新训练 | 命令行覆盖 |

## Checkpoint文件位置

```
checkpoint/NeurX-1.3/training_state.txt
```

**格式**: `step=<N> docs=<N> shards=<N> loss=<F>`

**示例**: `step=1000 docs=5000 shards=3 loss=2.45`

## 常见操作

### 查看当前训练状态
```bash
cat checkpoint/NeurX-1.3/training_state.txt
```

### 实时监控训练进度
```bash
watch -n 1 'cat checkpoint/NeurX-1.3/training_state.txt'
```

### 查看训练日志
```bash
tail -f artifacts/logs/pretrain_gpu_*.log
```

### 清除checkpoint并重新开始
```bash
make pretrain-gpu-fresh
```

### 在N个GPU上训练并恢复
```bash
NEURX_NUM_GPUS=4 make pretrain-gpu
```

### 手动编辑checkpoint（谨慎！）
```bash
# 从步数5000恢复
echo "step=5000 docs=25000 shards=15 loss=2.10" > checkpoint/NeurX-1.3/training_state.txt

# 然后继续训练
make pretrain-gpu
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `NEURX_PRETRAIN_RESUME` | `auto` | 恢复模式: auto/yes/no |
| `NEURX_NUM_GPUS` | 自动检测 | GPU数量 |
| `NEURX_PRETRAIN_STEPS` | 1000000000 | 最大训练步数 |
| `NEURX_PRETRAIN_OUTPUT_DIR` | `checkpoint/NeurX-1.3` | Checkpoint保存目录 |

## 完整工作流示例

```bash
# 1. 首次训练（60分钟）
make pretrain-gpu
# 日志: [Phase 1] No existing checkpoint found, starting fresh training
# 训练进行中... 
# 最后保存: checkpoint/NeurX-1.3/training_state.txt

# 2. 中断（Ctrl+C）
# [中断信号收到]

# 3. 查看保存状态
cat checkpoint/NeurX-1.3/training_state.txt
# 输出: step=1000 docs=5000 shards=3 loss=2.45

# 4. 恢复训练
make pretrain-gpu
# 日志: [Phase 1] Existing checkpoint found
#       [Phase 1] Loaded state: step=1000 docs=5000 shards=3 loss=2.45
#       [Phase 3] Starting training from step 1000
# 训练继续... 从第1000步继续

# 5. 完成后或想重新开始
make pretrain-gpu-fresh
# 日志: Starting fresh training (ignoring any existing checkpoint)
# [Phase 1] No existing checkpoint found, starting fresh training
```

## 故障排除

### Checkpoint检测失败
```bash
# 验证文件存在
test -f checkpoint/NeurX-1.3/training_state.txt && echo "存在" || echo "不存在"

# 如果不存在，强制新训练
make pretrain-gpu-fresh
```

### GPU不可用
```bash
# 检查GPU
nvidia-smi

# 降级到CPU训练
make pretrain
```

### 想使用不同的checkpoint目录
```bash
NEURX_PRETRAIN_OUTPUT_DIR=checkpoint/NeurX-1.3-v2 make pretrain-gpu
```

## 查看详细文档

- 完整指南: [docs/CHECKPOINT_RESUME_GUIDE.md](docs/CHECKPOINT_RESUME_GUIDE.md)
- 实现细节: [docs/GPU_CHECKPOINT_IMPLEMENTATION_SUMMARY.md](docs/GPU_CHECKPOINT_IMPLEMENTATION_SUMMARY.md)

## 一行命令集合

```bash
# 首次训练
make pretrain-gpu

# 恢复训练
make pretrain-gpu

# 新训练
make pretrain-gpu-fresh

# 监控
watch -n 1 'cat checkpoint/NeurX-1.3/training_state.txt'

# 日志
tail -f artifacts/logs/pretrain_gpu_*.log

# 4GPU恢复
NEURX_NUM_GPUS=4 make pretrain-gpu
```

## 关键点

1. ✅ 默认自动检测checkpoint并恢复
2. ✅ Checkpoint保存在 `checkpoint/NeurX-1.3/training_state.txt`
3. ✅ 格式: `step=<N> docs=<N> shards=<N> loss=<F>`
4. ✅ 随时可以中断（Ctrl+C），下次会自动恢复
5. ✅ 要重新开始用 `make pretrain-gpu-fresh`

---

**更多帮助**: `make help | grep pretrain` 或查看完整文档
