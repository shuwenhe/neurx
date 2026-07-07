# make train 问题诊断报告

## 问题
`make train` 执行后没有输出日志到终端，看起来卡住了。

## 根本原因

### 1️⃣ 日志重定向
```bash
# Makefile中的关键行:
cd '$(CURDIR_UNIX)' && ( ... ) 2>&1 | tee -a $(LOG_DIR)/train_$(shell date +%Y%m%d_%H%M%S).log
```
所有输出都被重定向到 **日志文件** 而不是终端，但同时也通过 `tee` 输出到终端。如果没有看到输出，可能是：
- 脚本执行了但没有产生输出
- 脚本在某个命令上等待输入
- 脚本在I/O操作上阻塞

### 2️⃣ 实际进度
根据文件系统分析，`make train` 实际上已经完成了很多工作：

✅ **数据清洗** - 完成
- 处理了24GB的Wikipedia XML.bz2文件
- 生成了304MB的清洁数据：`pretrain_data_cleaned.jsonl`
- 训练集：`train.jsonl` (9.8M)
- 验证集：`val.jsonl` (0B - 可能需要修复)
- 测试集：`test.jsonl` (0B - 可能需要修复)

✅ **数据分片** - 完成
- 生成了128个分片（每个20MB左右）
- 总大小：1.9GB
- 总文档数：71,451

✅ **Manifest生成** - 完成
- `dataset/pretrain/manifest.json` 已正确生成
- 包含所有分片的元数据

⏳ **实际训练** - 未知（可能正在进行或已卡住）
- `run_large_pretrain.sh` 脚本应该被调用
- 这个脚本编译S代码并运行训练
- 无法从文件系统确定其状态

## 如何监控进度

### 方法1：查看实时日志
```bash
# 查看最新的训练日志
tail -f artifacts/logs/train_*.log | grep "training\|Training\|TRAIN\|epoch\|loss"

# 或指定具体的日志文件
tail -f artifacts/logs/train_20260707_094802.log
```

### 方法2：监控S编译过程
```bash
# 查看是否有S编译过程在运行
ps aux | grep -i "s.*compile\|s.*ir\|neurx_train"

# 查看S编译输出
watch -n 1 'ls -lh build/training/ 2>/dev/null || echo "No output yet"'
```

### 方法3：检查训练输出
```bash
# 查看是否生成了checkpoint
ls -lh artifacts/checkpoints/

# 监控文件大小变化
watch -n 2 'du -sh artifacts/checkpoints/*'
```

## 问题：数据验证集和测试集为空

文件大小：
- `train.jsonl`: 9.8M ✅
- `val.jsonl`: 0B ❌ （应该有内容）
- `test.jsonl`: 0B ❌ （应该有内容）

**原因**：`clean_data.sh` 中的分割逻辑问题。

### 修复步骤

编辑 `script/clean_data.sh`，找到分割代码部分：

```bash
# 查找这一部分:
total = sum(1 for _ in output_file.open("r", encoding="utf-8"))
train_size = total * 8 // 10
val_size = total // 10
test_size = total - train_size - val_size
```

问题可能是在计算过程中。建议打印调试信息：

```python
total = sum(1 for _ in output_file.open("r", encoding="utf-8"))
train_size = total * 8 // 10
val_size = total // 10
test_size = total - train_size - val_size

print(f"DEBUG: total={total}, train_size={train_size}, val_size={val_size}, test_size={test_size}")
```

## 建议的解决方案

### 快速方案1：增加日志输出
修改 Makefile 中的 train 目标，移除日志重定向的 `tee` 部分来看实时输出：

```bash
# 找到这一行:
cd '$(CURDIR_UNIX)' && ... 2>&1 | tee -a $(LOG_DIR)/train_...

# 改为:
cd '$(CURDIR_UNIX)' && ... 2>&1
```

### 快速方案2：后台运行并监控
```bash
# 启动训练流程（不阻塞终端）
make train &

# 等待1秒让它开始
sleep 1

# 实时查看日志
tail -f artifacts/logs/train_*.log

# 需要时按 Ctrl+C 停止日志查看（不会停止训练）
```

### 快速方案3：分阶段运行
```bash
# 只运行数据清洁（已完成，可以跳过）
bash script/clean_data.sh

# 单独运行大模型预训练
bash script/run_large_pretrain.sh
```

## run_large_pretrain.sh 应该做什么

根据Makefile，这个脚本应该：
1. 编译 `training/industrial_1t_training.s` 或类似文件为IR
2. 生成二进制可执行文件
3. 运行训练循环
4. 生成checkpoint文件到 `artifacts/checkpoints/`

## 检查清单

- [ ] 查看最新的 train_*.log 文件是否在更新
- [ ] 检查 `training/` 目录中是否有新的 `.ir` 文件
- [ ] 检查 `artifacts/checkpoints/` 中是否有新文件
- [ ] 运行 `ps aux | grep make` 看make进程是否还在
- [ ] 运行 `ps aux | grep s` 看S编译器是否在运行
- [ ] 修复验证集和测试集为空的问题

## 日志文件位置
```
artifacts/logs/train_20260707_094802.log  # 最新的训练日志
artifacts/logs/train_20260707_094321.log  # 前一次
...
```

## 文件准备状态总结
| 阶段 | 状态 | 文件 |
|------|------|------|
| 原始数据 | ✅ | dataset/pretrain/raw/*.bz2 (24GB) |
| 清洁数据 | ✅ | dataset/pretrain/cleaned/*.jsonl (304MB) |
| 数据分片 | ✅ | dataset/pretrain/shard/*.jsonl (1.9GB) |
| Manifest | ✅ | dataset/pretrain/manifest.json |
| S编译 | ? | build/training/*.ir |
| 训练运行 | ? | artifacts/checkpoints/* |
