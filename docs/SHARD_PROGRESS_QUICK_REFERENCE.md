# 快速参考：Shard 进度日志增强

## ⚡ 一句话总结
现在 `minimal_train.s` 会在每条日志中清晰显示**当前正在训练哪个切片文件**，实现了按进度输出切片日志的功能。

---

## 📌 核心改动（7 处 + 1 个函数）

| # | 位置 | 改动 | 标记 |
|---|------|------|------|
| 1 | +524 | 新增 `extract_filename()` | - |
| 2 | ~145 | Shard 开始时显示文件名 | `📥 SHARD_START` |
| 3 | ~230 | 每100个文档的进度 | `📊 SHARD_PROGRESS` |
| 4 | ~263 | 训练步骤#1 的日志 | `🔹 Shard` |
| 5 | ~314 | 训练步骤#2 的日志 | `🔹 Shard` |
| 6 | ~345 | Shard 完成时显示文件名 | `✅ SHARD_COMPLETE` |
| 7 | ~371 | 最后梯度更新的日志 | `✓ FINAL FLUSH` |

---

## 🎯 日志输出对比

### 改动前
```
[Training] step=50/1000 [...] | shard 1/5 [...] | loss=0.1234 | docs=500 | tokens=256000
```

### 改动后
```
[Training] step=50/1000 [...] | 🔹 Shard [1/5] shard_001.jsonl (docs: 500/5000) [...] | loss=0.1234 | total_docs=500 | total_tokens=256000
```

**改进**：
- ✅ 显示了**切片文件名** `shard_001.jsonl`（不只是数字）
- ✅ 显示了**切片内文档进度** `(docs: 500/5000)`
- ✅ 清晰的**视觉标记** `🔹`

---

## 🔍 日志过滤命令

### 看所有 Shard 的开始和完成
```bash
./minimal_train.s 2>&1 | grep -E "SHARD_START|SHARD_COMPLETE"
```

### 看当前正在处理哪个切片
```bash
./minimal_train.s 2>&1 | grep "🔹 Shard"
```

### 看每个 Shard 的文档处理进度
```bash
./minimal_train.s 2>&1 | grep "📊 SHARD_PROGRESS"
```

### 保存完整日志（包括stderr）
```bash
./minimal_train.s 2>&1 | tee training_$(date +%Y%m%d_%H%M%S).log
```

---

## 📋 验证清单

运行以下命令验证改动已正确应用：

```bash
# 1. 检查 extract_filename 函数是否存在
grep -c "func extract_filename" /Users/shuwen/shuwen/train/neurx/script/minimal_train.s
# 预期输出: 1

# 2. 检查新的日志标记
grep -c "SHARD_START\|SHARD_PROGRESS\|SHARD_COMPLETE" /Users/shuwen/shuwen/train/neurx/script/minimal_train.s
# 预期输出: 3

# 3. 检查文件总行数（应该增加了约30行）
wc -l /Users/shuwen/shuwen/train/neurx/script/minimal_train.s
# 预期输出: 875 minimal_train.s
```

---

## 📖 完整改动文档位置

详细的改动说明请查看：
```
/Users/shuwen/shuwen/train/neurx/SHARD_PROGRESS_ENHANCEMENT.md
```

---

## ✨ 关键特性

| 特性 | 说明 |
|------|------|
| **Shard 文件名** | 所有日志都显示简洁的文件名（如 `shard_001.jsonl`） |
| **文档进度** | 显示 `(docs: 当前/目标)` |
| **全局进度** | 总步数、总文档、总tokens |
| **清晰标记** | 用 emoji 和特殊标记易于识别日志类型 |
| **Stderr 输出** | 关键事件也输出到stderr，便于实时监控 |
| **完全兼容** | 不改变训练逻辑，只增强日志 |

---

## 🚀 立即使用

1. **编译/运行**：`./minimal_train.s`
2. **查看Shard进度**：`./minimal_train.s 2>&1 | grep "🔹 Shard"`
3. **看完整流程**：`./minimal_train.s 2>&1 | tee training.log`

---

**文件修改日期**: 2026-07-10  
**修改文件**: `/Users/shuwen/shuwen/train/neurx/script/minimal_train.s`  
**新增工具函数**: `extract_filename(string) string`
