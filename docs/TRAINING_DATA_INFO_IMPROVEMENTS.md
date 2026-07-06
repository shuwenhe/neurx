# 📊 NeurX 训练数据信息显示改进

## 概述
增强了 NeurX 训练系统，使其在训练前和训练中显示详细的训练数据信息，包括：
- 当前加载的是哪个训练数据源
- 具体的文件路径
- 数据统计信息（样本数、文件大小等）
- 训练中实时显示当前处理的数据文件

## 改进内容

### 1. 新增训练数据信息打印脚本 ✅
**文件**: `script/print_training_data_info.sh`

功能：
- 自动检测所有可用的数据源（分片、训练集、清洁数据、原始数据）
- 按优先级显示将使用的数据源
- 列出具体的数据文件及其统计信息
- 显示日志和检查点输出目录

**使用方法**:
```bash
bash script/print_training_data_info.sh
```

**输出示例**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 NeurX 训练数据信息统计
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣  数据源检测
✓ 分片数据集 (Shard Dataset)
    分片数量: 676
    样本总数: 55148 条

✓ 训练集 (Train Split)
    样本数量: 51312 条
    文件大小: 3.1M

✓ 验证集 (Validation Split)
    样本数量: 6414 条
    文件大小: 385K

✓ 测试集 (Test Split)
    样本数量: 6414 条
    文件大小: 393K

✓ 清洁数据集 (Cleaned Dataset)
    样本数量: 64140 条
    文件大小: 3.9M

✓ 原始数据 (Raw Dataset)
    原始文件: 7 个
    总大小: 7.9M

2️⃣  数据文件详细列表
分片文件 (Shard Files):
  [000] shard_00000.jsonl               401 条     16K
  [001] shard_00001.jsonl               401 条     16K
  ... 以及 666 个其他分片

3️⃣  训练优先级和数据源选择
训练数据加载优先级:
  [1] 分片数据集 (Shard Dataset)
  [2] 训练集切分 (Train Split)
  [3] 清洁数据集 (Cleaned Dataset)
  [4] 原始数据 (Raw Dataset)

4️⃣  最终选择
✓ 将使用: 分片数据集 (Shard Dataset)
```

### 2. 增强训练数据加载显示 ✅
**文件**: `script/run_model_large_pretrain.sh`

改进：
- **自动检测数据源**: 按优先级检测分片、训练集、清洁数据、原始数据
- **详细的加载信息**: 显示数据源类型、路径、样本数
- **分片列表展示**: 显示前5个分片的详细信息
- **验证/测试集显示**: 如果存在，显示验证集和测试集路径
- **日志记录**: 所有信息同时写入日志文件

**输出示例**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ 检测到分片数据源
  数据源路径: /Users/feifei/shuwen/train/neurx/data/pretrain_dataset/shard
  分片总数:   676 个
  总样本数:   55148 条
  分片样本:
    - shard_00000.jsonl (  401 条, 16K)
    - shard_00001.jsonl (  401 条, 16K)
    - shard_00002.jsonl (  401 条, 16K)
    ... 还有 673 个分片

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 训练数据配置摘要
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
数据源类型: Shard Dataset (分片数据集)
数据路径:   /Users/feifei/shuwen/train/neurx/data/pretrain_dataset/shard
样本总数:   55148 条
模型配置:   neurx-1t-moe (参数: 1000000M)
batch size: 2
序列长度:   4096
训练步数:   500000
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 3. 训练过程中的文件显示 ✅
**文件**: `script/run_model_large_pretrain.sh` (train_epoch 函数)

改进：
- **实时显示当前处理文件**: 在每个训练步骤显示正在处理的数据文件名
- **日志记录**: 每个训练步骤记录到日志文件，包含文件名信息

**输出示例**:
```
Epoch 1/3 训练进行中
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📂 数据源: Shard Dataset (分片数据集)
📍 路径:   /Users/feifei/shuwen/train/neurx/data/pretrain_dataset/shard

Step 0/100 [░░░░░░░░░░░░░░░░░░░░] 📄 shard_00000.jsonl | Loss: 2.4123 LR: 6.00e-04 | Tokens: 0K
Step 10/100 [██░░░░░░░░░░░░░░░░░░] 📄 shard_00001.jsonl | Loss: 2.3421 LR: 5.88e-04 | Tokens: 327680K
Step 20/100 [████░░░░░░░░░░░░░░░░] 📄 shard_00002.jsonl | Loss: 2.2718 LR: 5.76e-04 | Tokens: 655360K
Step 30/100 [██████░░░░░░░░░░░░░░] 📄 shard_00000.jsonl | Loss: 2.2015 LR: 5.64e-04 | Tokens: 983040K
```

### 4. Makefile 新增目标 ✅
**文件**: `Makefile`

新增:
- `make print-data-info`: 显示训练数据信息
- `make train` 自动调用 `print-data-info` 在训练前显示数据信息

**使用方法**:
```bash
# 只查看数据信息
make print-data-info

# 训练（自动显示数据信息）
make train
```

### 5. .gitignore 更新 ✅
**文件**: `.gitignore`

新增排除规则：
- `data/pretrain_dataset/raw/` - 原始数据
- `data/pretrain_dataset/cleaned/` - 清洁数据
- `data/pretrain_dataset/shard/` - 分片数据
- `data/training_data_splits/` - 训练集
- `artifacts/logs/` - 训练日志
- `artifacts/checkpoints/` - 模型检查点
- `*.jsonl` - 所有 JSONL 数据文件

防止大型数据文件被意外提交到 git 仓库。

## 文件修改总结

| 文件 | 类型 | 改动 |
|------|------|------|
| `script/print_training_data_info.sh` | 新增 | 📊 训练数据信息统计脚本 |
| `script/run_model_large_pretrain.sh` | 修改 | 增强数据加载和训练显示 |
| `Makefile` | 修改 | 新增 `print-data-info` 目标 |
| `.gitignore` | 修改 | 添加数据目录排除规则 |

## 日志记录信息

所有训练信息同时记录到日志文件：
```
/Users/feifei/shuwen/train/neurx/artifacts/logs/model_large_pretrain_TIMESTAMP.log
```

**日志格式示例**:
```
[data] 检测到分片数据源
[data] 分片总数: 676 个
[data] 样本总数: 55148 条
[train] Step 0 - File: shard_00000.jsonl - Loss: 2.4123 - Tokens: 0K
[train] Step 10 - File: shard_00001.jsonl - Loss: 2.3421 - Tokens: 327680K
[train] Step 100 - File: shard_00010.jsonl - Loss: 2.1234 - Tokens: 3276800K
[epoch] Epoch 1 completed - Loss: 2.4123 → 1.5734 - Throughput: 32000 tokens/sec
```

## 使用指南

### 查看训练数据信息
```bash
cd /Users/feifei/shuwen/train/neurx
make print-data-info
```

### 开始训练（自动显示数据信息）
```bash
make train
```

### 查看训练日志
```bash
tail -f artifacts/logs/model_large_pretrain_*.log
```

### 快速检查数据文件
```bash
# 列出所有分片
ls -lh data/pretrain_dataset/shard/shard_*.jsonl | head -20

# 统计总样本数
wc -l data/pretrain_dataset/shard/shard_*.jsonl | tail -1

# 查看训练集信息
wc -l data/pretrain_dataset/cleaned/train.jsonl
du -h data/pretrain_dataset/cleaned/train.jsonl
```

## 关键特性

✅ **自动数据检测**: 按优先级自动发现可用的训练数据
✅ **详细信息显示**: 显示数据源类型、路径、样本数、文件大小
✅ **实时文件名**: 训练中显示当前处理的具体文件名
✅ **日志记录**: 所有信息同时写入日志文件便于查看
✅ **优先级管理**: 明确的数据源加载优先级
✅ **分片支持**: 完整支持分片数据集的显示和加载
✅ **测试集支持**: 显示训练/验证/测试集的完整信息

## 下一步

建议在以下场景中使用这些改进：
1. **排查训练问题**: 快速确认使用的是哪个数据源
2. **性能调优**: 通过日志查看数据加载时的详细信息
3. **数据管理**: 清楚地知道所有可用的训练数据
4. **调试**: 实时看到训练过程中处理的文件名
