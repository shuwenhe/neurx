# 🎯 实时 Shard 处理日志改进总结

## 📊 问题诊断结果

### 原始问题
训练脚本在运行时，shard 处理过程无法实时显示进度：
```
Manifest loaded
Loading shard list file...
Shard list file loaded
（然后就没有更多输出）
```

### 根本原因
- `println()` 函数输出被 S 运行时缓冲
- 缓冲区只在程序结束或显式刷新时才输出内容
- 导致用户无法看到实时处理进度

---

## ✅ 解决方案

### 1️⃣ 增强训练脚本
**文件**: `script/minimal_train.s`

在关键处理步骤添加了 `runtime_run_command_output` 调用，直接将状态消息输出到 stderr（unbuffered）：

```s
// 方案A: 使用 runtime_run_command_output 绕过缓冲
runtime_run_command_output("echo '[STATUS] Starting shard processing...' >&2")

// 方案B: 同时保持 println 用于日志记录
println("[STATUS] Starting shard processing...")
```

**关键改进点**（850+ 行）:
- ✅ Shard 列表加载阶段
- ✅ Shard 数量计数阶段
- ✅ 每个 shard 处理开始阶段
- ✅ 数据块加载阶段
- ✅ 训练步骤更新阶段
- ✅ 处理完成及统计阶段

### 2️⃣ 实时监控脚本
**文件**: `tools/monitor-shard-processing.sh`

- 解析日志中的状态标记（`[STATUS]`, `[DEBUG]`, `[TRAIN]` 等）
- 彩色编码不同类型的消息
- 实时显示处理进度
- 计算总耗时

### 3️⃣ 自动编译与运行脚本
**文件**: `tools/run-with-shard-monitor.sh`

完整的启动流程：
```
检查 S 编译器 → 语法检查 → 编译到 IR → 启动监控 → 运行训练 → 解析输出
```

### 4️⃣ 详细文档
**文件**: `docs/SHARD_PROCESSING_REALTIME_LOGGING.md`

590 行完整文档，包含：
- 问题分析
- 解决方案概述
- 使用方法（3 种）
- 输出样例
- 环境变量配置
- 故障排查指南

---

## 🚀 快速使用

### 方式 1️⃣ - 推荐（一条命令启动）
```bash
cd /home/shuwen/shuwen/train/neurx
bash tools/quick-start-shard-logging.sh
```

### 方式 2️⃣ - 自动编译运行
```bash
cd /home/shuwen/shuwen/train/neurx
bash tools/run-with-shard-monitor.sh /home/shuwen/s/bin/s
```

### 方式 3️⃣ - 手动编译运行
```bash
cd /home/shuwen/shuwen/train/neurx

# 编译
/home/shuwen/s/bin/s ir script/minimal_train.s -o artifacts/build/run_large_pretrain/minimal_train.ir

# 运行（自动实时输出）
export NEURX_ROOT=/home/shuwen/shuwen/train/neurx
/home/shuwen/s/bin/s artifacts/build/run_large_pretrain/minimal_train.ir 2>&1
```

---

## 📋 新增文件清单

| 文件 | 类型 | 功能 |
|------|------|------|
| `script/minimal_train.s` | 改进 | 添加实时日志输出（4 处改进） |
| `tools/monitor-shard-processing.sh` | 新增 | 实时日志解析与监控 |
| `tools/run-with-shard-monitor.sh` | 新增 | 自动编译与运行 |
| `tools/quick-start-shard-logging.sh` | 新增 | 快速启动向导 |
| `docs/SHARD_PROCESSING_REALTIME_LOGGING.md` | 新增 | 详细文档（590 行） |

---

## 🎨 实时输出样例

```
═══════════════════════════════════════════════
NeurX Shard Processing - Real-time Monitor
═══════════════════════════════════════════════

[14:25:30] ✓ Starting shard processing

[14:25:31] ▶ Processing Shard 1/100
  Path: .../training_data-00001.jsonl

[14:25:32] 📊 Step: 1  Loss: 2.5432  LR: 0.00012345

[14:25:33] ✓ Shard complete: docs=1000 tokens=2048000

[14:25:34] ▶ Processing Shard 2/100
  ...

[14:35:00] ✓ COMPLETE: step=100 docs=5000 tokens=100000
  Total time: 0h 9m 30s
```

---

## 💡 主要改进点

| 功能 | 状态 | 说明 |
|------|------|------|
| 实时日志输出 | ✅ | 使用 `runtime_run_command_output` 绕过缓冲 |
| 分阶段进度 | ✅ | 明确的处理阶段标记 |
| 彩色编码 | ✅ | 不同消息类型用不同颜色显示 |
| 错误捕捉 | ✅ | `[ERROR]` 标记立即显示问题 |
| 统计信息 | ✅ | 最终显示总耗时、总 token 数等 |
| 环境配置 | ✅ | 支持 14 个环境变量自定义 |

---

## 🔧 环境变量支持

脚本支持以下环保变量进行自定义：

```bash
NEURX_PRETRAIN_BATCH_SIZE=32          # 批大小
NEURX_PRETRAIN_SEQ_LEN=2048           # 序列长度
NEURX_PRETRAIN_STEPS=1000             # 总训练步数
NEURX_PRETRAIN_LR=0.0002              # 学习率
NEURX_PRETRAIN_WEIGHT_DECAY=0.01      # 权重衰减
NEURX_PRETRAIN_WARMUP_STEPS=100       # 预热步数
NEURX_PRETRAIN_LOG_INTERVAL=10        # 日志输出间隔
NEURX_PRETRAIN_MAX_DOCS=100000000     # 最大文档数
NEURX_PRETRAIN_STEP_TOKENS=256        # 每步 token 数
NEURX_PRETRAIN_LINE_CHUNK=32          # 行块大小
NEURX_PRETRAIN_TEXT_TOKEN_CAP=256     # 文本 token 上限
NEURX_PRETRAIN_JSON_SCAN_CAP=4096     # JSON 扫描上限
NEURX_PRETRAIN_FAST_PREFIX=1          # 快速前缀模式
NEURX_ROOT=/path/to/neurx             # 项目根目录
```

---

## 📚 文档位置

查看详细文档：
```bash
cat /home/shuwen/shuwen/train/neurx/docs/SHARD_PROCESSING_REALTIME_LOGGING.md
```

或在编辑器中打开：
```
neurx/docs/SHARD_PROCESSING_REALTIME_LOGGING.md
```

---

## 🎯 下一步建议

1. **测试实时监控**
   ```bash
   bash tools/quick-start-shard-logging.sh
   ```

2. **验证日志输出**
   - 确认看到 `[STATUS]` 标记
   - 确认看到实时的 `[TRAIN]` 进度
   - 确认看到最终的 `[COMPLETE]` 统计

3. **性能优化**（可选）
   - 根据需要调整环境变量
   - 监控 GPU/CPU 使用情况

4. **故障排查**（如有问题）
   - 查看 `docs/SHARD_PROCESSING_REALTIME_LOGGING.md` 的故障排查章节
   - 检查 shard 文件是否存在
   - 验证 manifest 文件配置

---

**最后更新**: 2026-07-09  
**版本**: 1.0  
**作者**: NeurX Development Team
