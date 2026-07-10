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

## 后续改进

- [ ] 支持多个检查点版本管理
- [ ] 添加检查点验证机制
- [ ] 实现周期性自动保存
- [ ] 添加检查点压缩功能
- [ ] 支持分布式训练的检查点同步
