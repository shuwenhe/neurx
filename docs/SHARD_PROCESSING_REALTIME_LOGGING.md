# Shard Processing 实时监控指南

## 问题

原来的 `minimal_train.s` 训练脚本在处理 shard 数据时，日志输出不够实时，无法清楚地看到处理进度。

### 症状
```
Manifest loaded
Loading shard list file...
Shard list file loaded
（然后没有更多输出）
```

## 解决方案

### 1. 增强的实时日志输出

改进了 `scripts/legacy/minimal_train.s`：
- 每个关键步骤都添加了 `runtime_run_command_output` 调用，将状态消息直接输出到 stderr
- 这确保了日志立即显示，不会被缓冲

### 2. 关键步骤的日志标记

添加了以下标记类型的日志输出：

| 标记 | 含义 | 示例 |
|------|------|------|
| `[STATUS]` | 主要流程状态 | Starting shard processing, shard 1/100 started |
| `[DEBUG]` | 调试信息 | Found 100 shards, Shard 1 chunk loaded (4096 bytes) |
| `[ERROR]` | 错误信息 | Shard file not found |
| `[INFO]` | 信息性消息 | Reading shard file in line chunks |
| `[TRAIN]` | 训练进度 | Step 10: loss=2.5432 lr=0.00012345 |
| `[COMPLETE]` | 完成信息 | Training finished - step=100 docs=5000 tokens=100000 |

### 3. 实时监控脚本

创建了 `tools/monitor-shard-processing.sh`：
- 实时读取和解析日志输出
- 对不同类型的消息进行彩色编码
- 显示进度条和统计信息
- 计算总耗时

### 4. 启动脚本

创建了 `tools/run-with-shard-monitor.sh`：
- 自动编译 S 语言脚本
- 启动实时监控器
- 运行训练程序
- 统一管理日志输出

## 使用方法

### 方法 1: 直接运行（推荐）

```bash
cd /home/shuwen/shuwen/train/neurx
bash tools/run-with-shard-monitor.sh /home/shuwen/s/bin/s
```

### 方法 2: 手动运行编译后的 IR

```bash
cd /home/shuwen/shuwen/train/neurx

# 编译
/home/shuwen/s/bin/s ir scripts/legacy/minimal_train.s -o artifacts/build/run_large_pretrain/minimal_train.ir

# 运行（有实时日志输出）
export NEURX_ROOT=/home/shuwen/shuwen/train/neurx
/home/shuwen/s/bin/s artifacts/build/run_large_pretrain/minimal_train.ir 2>&1
```

### 方法 3: 配置环境变量自定义

```bash
export NEURX_PRETRAIN_BATCH_SIZE=64
export NEURX_PRETRAIN_SEQ_LEN=2048
export NEURX_PRETRAIN_STEPS=1000
export NEURX_PRETRAIN_SHARD_LIST_FILE=/path/to/shard_list.txt

/home/shuwen/s/bin/s artifacts/build/run_large_pretrain/minimal_train.ir 2>&1
```

## 实时日志输出示例

```
═══════════════════════════════════════════════
NeurX Shard Processing - Real-time Monitor
═══════════════════════════════════════════════

[14:25:30] ✓ Starting shard processing

[14:25:31] ▶ Processing Shard 1/100
  Path: /home/shuwen/shuwen/train/neurx/dataset/pretrain/shard/training_data-00001.jsonl

[14:25:32] 📊 Step: 1  Loss: 2.5432  LR: 0.00012345

[14:25:33] ✓ Shard complete: docs=1000 tokens=2048000

[14:25:34] ▶ Processing Shard 2/100
  Path: /home/shuwen/shuwen/train/neurx/dataset/pretrain/shard/training_data-00002.jsonl

...

[14:35:00] ✓ COMPLETE: step=100 docs=5000 tokens=100000 loss=1.2345
  Total time: 0h 9m 30s
```

## 主要改进

### 1. println 缓冲问题解决

使用 `runtime_run_command_output` 将日志直接输出到 stderr，绕过 println 的缓冲：

```s
runtime_run_command_output("echo '[STATUS] Starting shard processing...' >&2")
```

### 2. 分阶段的日志输出

关键处理阶段的前后都有日志标记：

```s
runtime_run_command_output("echo '[STATUS] Reading shard file...' >&2")
// ... 处理代码 ...
runtime_run_command_output("echo '[DEBUG] Shard loaded (" + ... + " bytes)' >&2")
```

### 3. 实时进度追踪

每个 shard 和每个训练 step 都有独立的日志标记

### 4. 错误和调试信息

立即捕捉和输出错误状态，便于问题诊断

## 环境变量配置

训练程序支持以下环境变量：

```bash
NEURX_ROOT                      # 项目根目录
NEURX_PRETRAIN_MANIFEST         # Manifest 文件路径
NEURX_PRETRAIN_SHARD_LIST_FILE  # Shard 列表文件
NEURX_PRETRAIN_BATCH_SIZE       # 批大小（默认 32）
NEURX_PRETRAIN_SEQ_LEN          # 序列长度（默认 2048）
NEURX_PRETRAIN_STEPS            # 总步数（默认 1000）
NEURX_PRETRAIN_LR               # 学习率（默认 0.0002）
NEURX_PRETRAIN_WEIGHT_DECAY     # 权重衰减（默认 0.01）
NEURX_PRETRAIN_WARMUP_STEPS     # 预热步数（默认 100）
NEURX_PRETRAIN_LOG_INTERVAL     # 日志间隔（默认 10）
NEURX_PRETRAIN_MAX_DOCS         # 最大文档数（默认 100000000）
NEURX_PRETRAIN_STEP_TOKENS      # 每步 token 数（默认 256）
NEURX_PRETRAIN_LINE_CHUNK       # 行块大小（默认 32）
NEURX_PRETRAIN_TEXT_TOKEN_CAP   # 文本 token 上限（默认 256）
NEURX_PRETRAIN_JSON_SCAN_CAP    # JSON 扫描上限（默认 4096）
NEURX_PRETRAIN_FAST_PREFIX      # 快速前缀模式（默认 1）
```

## 故障排查

### 问题：仍然看不到 "[STATUS] Starting shard processing..." 消息

**原因**：可能 shard 计数为 0

**解决**：
```bash
# 检查 shard 目录
ls -la /home/shuwen/shuwen/train/neurx/dataset/pretrain/shard/

# 检查 manifest 文件
cat /home/shuwen/shuwen/shuwen/train/neurx/dataset/pretrain/manifest.json | head -20

# 手动指定 shard 列表文件
export NEURX_PRETRAIN_SHARD_LIST_FILE=/path/to/your/shard_list.txt
```

### 问题：处理速度很慢

**原因**：可能在大量 JSON 解析上花费时间

**解决**：
- 增加 `NEURX_PRETRAIN_FAST_PREFIX=1`（已启用）
- 减小 `NEURX_PRETRAIN_JSON_SCAN_CAP` 和 `NEURX_PRETRAIN_TEXT_TOKEN_CAP`

### 问题：内存使用过高

**原因**：批大小和序列长度设置过大

**解决**：
```bash
export NEURX_PRETRAIN_BATCH_SIZE=16
export NEURX_PRETRAIN_SEQ_LEN=1024
```

## 相关文件

- `scripts/legacy/minimal_train.s` - 改进的训练脚本（增加实时日志）
- `tools/monitor-shard-processing.sh` - 实时日志监控器
- `tools/run-with-shard-monitor.sh` - 完整启动脚本
- `tools/cleanup-old-commits.sh` - 提交历史清理工具

## 后续改进计划

1. ✅ 实时日志输出
2. ✅ 分阶段的处理进度显示  
3. 计划中：性能指标收集（吞吐量、延迟）
4. 计划中：错误自动恢复机制
5. 计划中：分布式训练日志聚合

---

**最后更新**: 2026-07-09  
**版本**: 1.0
