# 快速参考: `make pretrain` 实时进度显示

## 问题解决

之前 `make pretrain` 时卡在这里：
```
[STARTUP][runner] waiting for the first training heartbeat
compiled .ir → .ir.runner.bin
```

现在已修复！JIT 编译期间会看到**实时进度**。

---

## 预期输出时间线

### 第 0 秒 - 启动
```
Real training log: /path/to/run_large_pretrain_20260711_080134.log
Training started. Monitor progress with: tail -f ...
[STARTUP][runner] S IR runner launching now
[STARTUP][runner] executing training pipeline from ...
[STARTUP][runner] waiting for the first training heartbeat
```

### 第 1-2 秒 - 编译开始（显示加载动画）
```
[STARTUP][runner] ⠋ JIT compiling S IR runner binary (waiting for heartbeat)...
[STARTUP][runner] ⠙ JIT compiling S IR runner binary (waiting for heartbeat)...
```

### 第 2-4 秒 - 初始化第 1-2 阶段
```
[STARTUP][init] 📥 phase 1: loading environment variables
[STARTUP][init] ✓ phase 1 complete: environment variables loaded
[STARTUP][init] 📥 phase 2: loading configuration...
[STARTUP][init] ✓ phase 2 complete: configuration loaded
```

### 第 4-6 秒 - 配置显示和第 3 阶段
```
[CONFIG] Project Settings:
  Project root  : /Users/shuwen/shuwen/train/neurx
  Batch size    : 32
  Seq len       : 2048
  Max steps     : 1000
  Vocab size    : 50257

[STARTUP][init] 📥 phase 3: validating paths...
[STARTUP][init] ✓ phase 3 complete: paths validated
```

### 第 6-10 秒 - 数据路径和第 4 阶段
```
[CONFIG] Data Paths:
  Manifest file : /path/to/manifest.json
  Shard list    : /path/to/shard_list.txt
  Shard dir     : /path/to/shard
  Output dir    : /path/to/checkpoint

[STARTUP][init] 📥 phase 4: initializing training parameters...
[STARTUP][init] ✓ phase 4 complete: training parameters ready
```

### 第 10-15 秒 - 编译进度更新
```
[STARTUP][runner] ⠹ JIT compiling S IR runner binary (waiting for heartbeat)...
[STARTUP][compiler] ⚙️  JIT compiling: 2.5 MB generated
[STARTUP][runner] ⠸ JIT compiling S IR runner binary (waiting for heartbeat)...
```

### 第 15-25 秒 - 继续编译进度
```
[STARTUP][compiler] ⚙️  JIT compiling: 5.2 MB generated
[STARTUP][compiler] ⚙️  JIT compiling: 8.1 MB generated
[STARTUP][compiler] ⚙️  JIT compiling: 12.4 MB generated
```

### 第 25+ 秒 - 编译完成，训练开始
```
[STARTUP][compiler] ⚙️  JIT compiling: 18.2 MB generated

========================================
📊 Stage 2: Pre-Training Data Scan
========================================

[STARTUP][manifest] ✓ manifest found
[STARTUP][shard-scan] 📋 loading pre-generated shard list
🔹 [SHARD PROCESSING] Starting shard_00000
📥 [READING] shard_00000.jsonl (doc 0-100)
```

---

## 关键改进

| 改进项 | 前 | 后 |
|--------|----|----|
| 进度检查间隔 | 15秒 | 0.5秒 |
| 编译过程反馈 | 无 | 实时文件大小 |
| 加载动画 | 无 | Unicode 旋转 |
| 初始化阶段 | 1个消息 | 4个阶段+8个消息 |
| 预期卡顿感 | ❌ 30秒无输出 | ✅ 每秒有进度 |

---

## 超时行为

如果 JIT 编译超过 30 秒，会看到：

```
[STARTUP][compiler] ⚠️  JIT compilation taking longer than expected (~15s)
[STARTUP][compiler] This is normal for the first run; subsequent runs will use cached binary
...（继续编译）...
```

如果达到 30 秒硬限制，会看到：

```
[ERROR] ❌ Startup timeout: S IR runner did not start within 30 seconds
[ERROR] Check if S compiler is properly configured
[ERROR] Log file: /path/to/run_large_pretrain_20260711_080134.log
```

---

## 故障排除

### 还是看不到进度？
```bash
# 用这个命令监控启动进度
make pretrain 2>&1 | grep "\[STARTUP\]"
```

### 如果卡在编译阶段超过 30 秒
```bash
# 1. 检查日志文件
tail -100f /Users/shuwen/shuwen/train/neurx/artifacts/logs/run_large_pretrain_*.log

# 2. 检查编译器配置
echo $S_COMPILER
echo $S_RUNNER_BIN
```

### 清除缓存重新编译
```bash
cd /Users/shuwen/shuwen/train/neurx
rm -f artifacts/build/run_large_pretrain/*.runner.bin
make pretrain  # 这次会重新编译，但之后会快速
```

---

## 参考文档

- [JIT_COMPILATION_PROGRESS.md](JIT_COMPILATION_PROGRESS.md) - 技术实现细节
- [STARTUP_LOGGING_GUIDE.md](STARTUP_LOGGING_GUIDE.md) - 完整启动日志参考
- [SHARD_PROGRESS_QUICK_REFERENCE.md](SHARD_PROGRESS_QUICK_REFERENCE.md) - 训练进度日志

---

## 快速测试

想立即看到效果，运行：

```bash
cd /Users/shuwen/shuwen/train/neurx
make pretrain 2>&1 | head -50
```

你应该在前 10 秒内看到至少 10-15 行进度输出。
