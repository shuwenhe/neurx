# 断点续训配置说明

## 功能概述
`make pretrain` 现已支持断点续训功能，训练出来的模型直接存放在 `/home/shuwen/shuwen/train/neurx/artifacts/checkpoints` 目录下。

## 关键改动

### 1. Makefile 变更
- **输出目录**: `$(CURDIR_UNIX)/artifacts/checkpoints/gpt_large_pretrain` → `$(CURDIR_UNIX)/artifacts/checkpoints`
- **断点续训**: 添加 `NEURX_PRETRAIN_RESUME=1` 环境变量
- **脚本**: 改用 `run_large_pretrain.sh` 替代 `run_cuda_pretrain.sh`

### 2. run_large_pretrain.sh 增强
- ✅ 添加检查点检测逻辑
- ✅ 自动发现 `latest_checkpoint.txt` 恢复训练
- ✅ 自动发现 `resume_state.json` 恢复训练状态
- ✅ 环境变量 `NEURX_PRETRAIN_CHECKPOINT_PATH` 用于指定恢复点
- ✅ 环境变量 `NEURX_PRETRAIN_RESUME_STATE_FILE` 用于恢复状态

### 3. minimal_train.s 增强
- ✅ 添加 `output_dir` 环境变量支持
- ✅ 添加 `save_interval` 参数配置（默认100）
- ✅ 训练完成后自动保存检查点到：
  - `final_model.neurx` - 最终模型
  - `best_model.neurx` - 最佳模型（符号链接）
  - `latest_checkpoint.txt` - 最新检查点路径
  - `resume_state.json` - 训练状态快照

## 输出目录结构

```
artifacts/checkpoints/
├── final_model.neurx              # 最终模型检查点
├── best_model.neurx               # 最佳模型（symlink指向final_model.neurx）
├── latest_checkpoint.txt           # 最新检查点路径
├── resume_state.json               # 恢复状态（JSON格式）
└── checkpoint_info.json            # 模型配置信息（可选）
```

## 使用方式

### 首次训练
```bash
cd /home/shuwen/shuwen/train/neurx
make pretrain
```

训练过程会自动：
1. 检测输出目录 `artifacts/checkpoints`
2. 如果没有检查点，从头开始训练
3. 完成后保存模型到 `artifacts/checkpoints/final_model.neurx`

### 断点续训
```bash
# 直接运行make命令，会自动检测上次的检查点并恢复
cd /home/shuwen/shuwen/train/neurx
make pretrain
```

续训过程会自动：
1. 读取 `artifacts/checkpoints/latest_checkpoint.txt` 获取检查点路径
2. 读取 `artifacts/checkpoints/resume_state.json` 恢复训练状态
3. 从上次中断的地方继续训练

### 禁用断点续训（强制从头开始）
```bash
cd /home/shuwen/shuwen/train/neurx
NEURX_PRETRAIN_RESUME=0 make pretrain
```

## 环境变量配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `NEURX_PRETRAIN_OUTPUT_DIR` | `artifacts/checkpoints` | 模型输出目录 |
| `NEURX_PRETRAIN_RESUME` | `1` | 是否启用断点续训（1=启用，0=禁用） |
| `NEURX_PRETRAIN_SAVE_INTERVAL` | `100` | 检查点保存间隔（步数） |
| `NEURX_PRETRAIN_CHECKPOINT_PATH` | 自动检测 | 指定恢复的检查点路径 |
| `NEURX_PRETRAIN_RESUME_STATE_FILE` | 自动检测 | 恢复状态文件路径 |

## 检查点信息格式

### resume_state.json
```json
{
  "step": 430,
  "docs_seen": 2500,
  "tokens_seen": 320000,
  "loss": 2.814500,
  "last_shard": "/path/to/shard_00042.jsonl"
}
```

### latest_checkpoint.txt
```
/home/shuwen/shuwen/train/neurx/artifacts/checkpoints/final_model.neurx
```

## 工作流示例

### 场景1：首次训练（1000步，100步间隔）
```bash
make pretrain NEURX_PRETRAIN_STEPS=1000 NEURX_PRETRAIN_SAVE_INTERVAL=100
# 输出: artifacts/checkpoints/final_model.neurx
```

### 场景2：中途中断并续训
```bash
# 中断（Ctrl+C）后，模型已保存：
# - artifacts/checkpoints/final_model.neurx
# - artifacts/checkpoints/resume_state.json
# - artifacts/checkpoints/latest_checkpoint.txt

# 重新运行make pretrain，自动恢复
make pretrain
# 将从latest_checkpoint.txt中的检查点继续训练
```

### 场景3：查看训练恢复信息
```bash
cat artifacts/checkpoints/latest_checkpoint.txt
cat artifacts/checkpoints/resume_state.json
```

## 技术细节

### 断点续训流程
1. **run_large_pretrain.sh** 检查 `latest_checkpoint.txt` 是否存在
2. 如果存在且检查点文件有效，设置 `NEURX_PRETRAIN_CHECKPOINT_PATH`
3. 如果存在 `resume_state.json`，设置 `NEURX_PRETRAIN_RESUME_STATE_FILE`
4. S编译和执行训练脚本
5. minimal_train.s 完成训练后保存新的检查点

### 检查点保存策略
- **final_model.neurx**: 每次训练完成时更新（包含最新权重）
- **best_model.neurx**: 指向best的符号链接（初始时等于final_model）
- **latest_checkpoint.txt**: 存储最新检查点的完整路径
- **resume_state.json**: 存储训练元数据（步数、文档数、损失等）

## 故障排除

### 问题：无法恢复检查点
**解决方案**：
1. 检查 `latest_checkpoint.txt` 是否存在：
   ```bash
   cat artifacts/checkpoints/latest_checkpoint.txt
   ```
2. 检查文件权限：
   ```bash
   ls -lah artifacts/checkpoints/
   ```

### 问题：要从头开始训练
**解决方案**：
```bash
# 删除旧的检查点
rm -f artifacts/checkpoints/latest_checkpoint.txt
rm -f artifacts/checkpoints/resume_state.json
# 重新开始训练
make pretrain
```

### 问题：检查点文件丢失
**解决方案**：
如果模型文件 `final_model.neurx` 被删除但 `latest_checkpoint.txt` 仍指向它：
```bash
# 清理检查点引用
rm -f artifacts/checkpoints/latest_checkpoint.txt
rm -f artifacts/checkpoints/resume_state.json
# 从头开始
make pretrain
```

---

# GPU 预训练断点续训指南 (GPU Pretrain Checkpoint Resume)

## 概述

NeurX GPU预训练现已支持完整的断点续训功能。训练状态保存在 `checkpoint/NeurX-1.3/training_state.txt`，中断后可以从上次保存的步数继续训练。

## GPU 预训练命令

### 1. 自动恢复模式（推荐）- Auto Resume (Default)

```bash
# 首次训练 - 从步数0开始
make pretrain-gpu

# 中断后 - 自动检测checkpoint并恢复
make pretrain-gpu
```

**工作原理**：
- 自动检查 `checkpoint/NeurX-1.3/training_state.txt`
- 如果存在，从上次保存的步数继续
- 如果不存在，从步数0开始新训练
- 环境变量：`NEURX_PRETRAIN_RESUME=auto`（默认）

### 2. 强制恢复模式 - Force Resume

```bash
NEURX_PRETRAIN_RESUME=yes make pretrain-gpu
```

**强制从checkpoint恢复，如果不存在则报错**

### 3. 新训练模式 - Fresh Start

```bash
make pretrain-gpu-fresh
```

或使用环境变量：

```bash
NEURX_PRETRAIN_RESUME=no make pretrain-gpu
```

**删除现有checkpoint并从步数0开始新训练**

### 4. 显式恢复命令 - Explicit Resume

```bash
make pretrain-gpu-resume
```

**等同于 `make pretrain-gpu`，但更明确意图**

## GPU 预训练 Checkpoint 结构

```
checkpoint/NeurX-1.3/
├── training_state.txt      # 训练状态（步数、文档数、分片数、损失）
├── transformer_v2.ckpt     # 模型权重检查点
├── NeurX-1.3.neurx         # 模型元数据
└── ...                     # 其他检查点文件
```

### training_state.txt 格式

```
step=1000 docs=5000 shards=3 loss=2.45
```

**字段说明**：
- `step`: 当前已完成的训练步数
- `docs`: 已处理的文档总数
- `shards`: 已完成的数据分片数
- `loss`: 最后记录的平均损失值

## GPU 预训练环境变量

| 变量 | 说明 | 默认值 | 可选值 |
|------|------|--------|--------|
| `NEURX_PRETRAIN_RESUME` | 恢复模式 | `auto` | `auto` / `yes` / `no` |
| `NEURX_PRETRAIN_OUTPUT_DIR` | checkpoint保存目录 | `checkpoint/NeurX-1.3` | 任何有效路径 |
| `NEURX_PRETRAIN_STEPS` | 最大训练步数 | `1000000000` | 整数 |
| `NEURX_NUM_GPUS` | GPU数量 | 自动检测 | 整数 (1-8) |

## 高级用法 (Advanced Usage)

### 指定checkpoint目录

```bash
NEURX_PRETRAIN_OUTPUT_DIR=/custom/checkpoint/path make pretrain-gpu
```

### 设置训练步数并恢复

```bash
NEURX_PRETRAIN_STEPS=10000 NEURX_PRETRAIN_RESUME=yes make pretrain-gpu
```

### 多GPU训练并恢复

```bash
NEURX_NUM_GPUS=4 make pretrain-gpu
```

### 查看当前checkpoint状态

```bash
cat checkpoint/NeurX-1.3/training_state.txt
```

### 编辑checkpoint状态（高级）

```bash
# 手动修改training_state.txt（谨慎使用）
echo "step=5000 docs=25000 shards=15 loss=2.10" > checkpoint/NeurX-1.3/training_state.txt
```

## GPU 预训练工作流示例

### 场景1：首次GPU预训练

```bash
cd /home/shuwen/shuwen/train/neurx
make pretrain-gpu

# 日志输出:
# [Phase 1] Checking for existing checkpoint...
# [Phase 1] No existing checkpoint found, starting fresh training
# [Phase 2] Setting up GPU environment
# [Phase 3] Starting training from step 0
```

### 场景2：中断并恢复

```bash
# 训练中（假设已完成1000步）
# 按 Ctrl+C 中断

# 查看checkpoint状态
cat checkpoint/NeurX-1.3/training_state.txt
# 输出: step=1000 docs=5000 shards=3 loss=2.45

# 重新运行 - 自动恢复
make pretrain-gpu
# 日志输出:
# [Phase 1] Existing checkpoint found
# [Phase 1] Loaded state: step=1000 docs=5000 shards=3 loss=2.45
# [Phase 3] Starting training from step 1000
```

### 场景3：从新checkpoint开始

```bash
# 删除现有checkpoint并重新开始
make pretrain-gpu-fresh

# 或等同于：
NEURX_PRETRAIN_RESUME=no make pretrain-gpu
```

### 场景4：在多个GPU上恢复训练

```bash
# 原始训练在4个GPU上
NEURX_NUM_GPUS=4 make pretrain-gpu

# 中断后，继续在4个GPU上恢复
NEURX_NUM_GPUS=4 make pretrain-gpu
```

## 日志和监控

### 查看预训练日志

```bash
# 最新日志
tail -f artifacts/logs/pretrain_gpu_*.log

# 特定日期的日志
ls -lh artifacts/logs/pretrain_gpu_*.log

# 搜索特定信息
grep "checkpoint" artifacts/logs/pretrain_gpu_*.log
grep "resume" artifacts/logs/pretrain_gpu_*.log
```

### 实时监控训练状态

```bash
# 每秒更新一次状态
watch -n 1 'cat checkpoint/NeurX-1.3/training_state.txt'

# 或使用tail -f动态监控
tail -f checkpoint/NeurX-1.3/training_state.txt
```

## 故障排除

### 问题1：无法找到checkpoint
**症状**：看到 "No existing checkpoint found" 但预期应该恢复

**解决**：
```bash
# 检查目录是否存在
ls -la checkpoint/NeurX-1.3/

# 检查training_state.txt
cat checkpoint/NeurX-1.3/training_state.txt

# 如果文件不存在，强制从头开始
make pretrain-gpu-fresh
```

### 问题2：checkpoint损坏
**症状**：恢复失败或产生parse错误

**解决**：
```bash
# 备份旧checkpoint
cp checkpoint/NeurX-1.3/training_state.txt checkpoint/NeurX-1.3/training_state.txt.bak

# 从新checkpoint开始
make pretrain-gpu-fresh
```

### 问题3：GPU不可用
**症状**：CUDA错误或GPU检测失败

**解决**：
```bash
# 检查GPU
nvidia-smi

# 指定GPU数量为0（CPU模式）
NEURX_NUM_GPUS=0 make pretrain-gpu

# 或使用CPU预训练
make pretrain
```

### 问题4：想切换配置

**解决**：创建新的checkpoint目录
```bash
# 方案A：使用新的输出目录
NEURX_PRETRAIN_OUTPUT_DIR=checkpoint/NeurX-1.3-v2 make pretrain-gpu

# 方案B：备份现有checkpoint
mv checkpoint/NeurX-1.3 checkpoint/NeurX-1.3-prod
make pretrain-gpu-fresh
```

## 最佳实践

1. **定期备份重要checkpoint**：
   ```bash
   cp -r checkpoint/NeurX-1.3 checkpoint/NeurX-1.3-backup-$(date +%Y%m%d-%H%M%S)
   ```

2. **监控training_state.txt**：
   ```bash
   watch -n 5 'cat checkpoint/NeurX-1.3/training_state.txt'
   ```

3. **检查日志**：
   ```bash
   tail -100f artifacts/logs/pretrain_gpu_*.log
   ```

4. **设置合理的训练步数**：
   ```bash
   NEURX_PRETRAIN_STEPS=100000 make pretrain-gpu
   ```

5. **在中断前等待checkpoint保存**：
   - 等待日志显示 "Checkpoint saved" 消息
   - 然后再按 Ctrl+C

## 相关文件和脚本

- **主脚本**: [scripts/legacy/pretrain_gpu.s](../scripts/legacy/pretrain_gpu.s)
- **Makefile配置**: [Makefile](../Makefile) (pretrain-gpu 目标)
- **模型配置**: [config_1t_model.json](../config_1t_model.json)
- **CUDA桥接**: [neurx_cuda_train_bridge.cu](../cuda/neurx_cuda_train_bridge.cu)

## 相关命令总览

```bash
# GPU预训练
make pretrain-gpu          # 自动恢复或新训练
make pretrain-gpu-resume   # 显式恢复
make pretrain-gpu-fresh    # 从新checkpoint开始

# CPU预训练
make pretrain              # 也支持checkpoint恢复

# 查看所有预训练相关命令
make help | grep pretrain

# 查看logs
make logs                  # 显示所有日志
make logs-tail             # 跟踪日志
```

## 后续改进

- [ ] 支持多个checkpoint版本管理
- [ ] 添加checkpoint验证和校验和机制
- [ ] 实现周期性自动保存
- [ ] 添加checkpoint压缩功能
- [ ] 支持分布式训练的checkpoint同步
- [ ] 实现CUDA桥接与保存状态的集成
