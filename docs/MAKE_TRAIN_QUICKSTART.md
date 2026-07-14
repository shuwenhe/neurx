# make train 快速诊断和解决方案

## 🔍 当前状态总结

| 阶段 | 状态 | 详情 |
|------|------|------|
| ✅ 数据清洁 | 完成 | 304MB 的清洁数据 |
| ✅ 数据分片 | 完成 | 128个分片，1.9GB |
| ✅ Manifest | 完成 | 71,451个文档 |
| ⚠️ 验证/测试集 | 需修复 | val和test文件为空 |
| ⏳ 实际训练 | 进行中或卡住 | 最后修改：09:50:00 |

## ⚠️ 为什么没有终端输出？

### 原因
```bash
# Makefile中的关键行：
... 2>&1 | tee -a $(LOG_DIR)/train_$(shell date +%Y%m%d_%H%M%S).log
```

**所有输出都被重定向到日志文件**。如果脚本在运行但终端没有输出，这是正常的。

### 解决方案

#### 🚀 快速方案1：查看实时日志
```bash
# 进入项目目录
cd /home/shuwen/shuwen/train/neurx

# 查看最新日志
tail -f artifacts/logs/train_*.log

# 或指定具体文件
tail -f artifacts/logs/train_20260707_094802.log
```

#### 🚀 快速方案2：使用监控脚本
```bash
# 直接运行监控脚本
bash script/monitor_training.sh

# 或查看当前状态
bash script/monitor_training.sh status

# 或实时监控日志
bash script/monitor_training.sh realtime
```

#### 🚀 快速方案3：启动并监控
```bash
# 一条命令启动训练和监控
bash script/start_train.sh
```

#### 🚀 快速方案4：后台启动+手动监控
```bash
# 后台启动
make train &

# 等待日志文件生成
sleep 2

# 查看日志
tail -f artifacts/logs/train_*.log | grep -E "Training|training|loss|Loss|step|Step"
```

## 🐛 已知问题

### 问题1：验证集和测试集为空
**症状**：
```
val.jsonl - 0 bytes ❌
test.jsonl - 0 bytes ❌
train.jsonl - 9.8M ✅
```

**原因**：数据分割算法问题

**快速修复**：
```bash
# 重新生成数据（会重新处理24GB文件）
rm dataset/pretrain/cleaned/*
rm dataset/pretrain/shard/*
make train
```

**或临时跳过验证集**：
在 `script/run_large_pretrain.sh` 中添加：
```bash
export NEURX_SKIP_VAL=1
export NEURX_SKIP_TEST=1
```

### 问题2：没有训练输出
**症状**：
- 没有生成checkpoint文件
- 日志停留在某个点不更新

**诊断**：
```bash
# 检查S编译是否成功
ls -lh build/training/

# 查看最后的日志
tail -50 artifacts/logs/train_*.log

# 查看是否有错误
grep -i error artifacts/logs/train_*.log

# 查看进程状态
ps aux | grep -E "make|train|clean"
```

## 📋 完整工作流

### 方案A：后台启动+监控
```bash
cd /home/shuwen/shuwen/train/neurx

# 1. 启动训练（后台）
make train &

# 2. 等待日志初始化
sleep 2

# 3. 监控进度（按Ctrl+C停止监控，训练继续）
tail -f artifacts/logs/train_*.log
```

### 方案B：分阶段执行
```bash
# 1. 检查数据准备（已完成，可跳过）
bash script/clean_data.sh
bash script/generate_shards.sh

# 2. 运行训练
bash script/run_large_pretrain.sh

# 3. 在另一个终端监控
tail -f artifacts/logs/train_*.log
```

### 方案C：完全前台执行（看完整输出）
```bash
# 临时修改Makefile，移除tee的日志重定向
# 或使用脚本直接调用而不经过make

cd /home/shuwen/shuwen/train/neurx
bash script/run_large_pretrain.sh 2>&1
```

## 🔧 配置环境变量

在 `script/run_large_pretrain.sh` 中可以设置：
```bash
# 模型大小
export MODEL_SIZE=1t

# 数据路径
export NEURX_PRETRAIN_MANIFEST='path/to/manifest.json'
export NEURX_TRAIN_SPLIT_PATH='path/to/train.jsonl'

# 编译器
export S_COMPILER='/home/shuwen/s/bin/s'
export S_SOURCE_ROOT='/home/shuwen/s'

# 允许完整1T模型
export NEURX_ALLOW_FULL_1T_LOCAL=1
```

## 📊 监控指标

### 查看数据处理进度
```bash
# 实时监控文件大小变化
watch -n 1 'ls -lh artifacts/logs/train_*.log'

# 查看checkpoint生成
watch -n 2 'ls -lh artifacts/checkpoints/'

# 监控磁盘占用
watch -n 5 'du -sh artifacts/ dataset/'
```

### 查看日志统计
```bash
# 统计日志中的step数
grep "step" artifacts/logs/train_*.log | wc -l

# 查看loss变化
grep "loss" artifacts/logs/train_*.log | tail -20

# 查看所有错误
grep -i error artifacts/logs/train_*.log
```

## 🆘 故障排除

### 训练完全没有开始
```bash
# 1. 检查make命令是否成功
make train 2>&1 | head -50

# 2. 检查日志目录权限
ls -ld artifacts/logs

# 3. 检查S编译器
which s
s --version
```

### 训练卡在某个阶段
```bash
# 1. 查看最新日志的最后100行
tail -100 artifacts/logs/train_*.log

# 2. 查看是否有错误
tail -100 artifacts/logs/train_*.log | grep -i error

# 3. 检查进程
ps aux | grep -E "s|python|train"

# 4. 检查系统资源
top -b -n 1 | head -15
free -h
```

### 日志文件停止更新
```bash
# 1. 检查进程是否还在运行
ps aux | grep make
ps aux | grep -E "train|clean"

# 2. 重新启动
make train

# 3. 监控新日志
tail -f artifacts/logs/train_*.log
```

## 📝 文件位置参考

```
项目根目录: /home/shuwen/shuwen/train/neurx/

日志:
  artifacts/logs/train_*.log              # 训练日志
  artifacts/logs/train_20260707_094802.log # 最新日志

数据:
  dataset/pretrain/raw/                   # 原始数据 (24GB)
  dataset/pretrain/cleaned/               # 清洁数据
  dataset/pretrain/shard/                 # 数据分片 (128个文件)
  dataset/pretrain/manifest.json          # 元数据

模型:
  training/                               # 训练脚本 (S语言)
  build/training/                         # 编译输出
  artifacts/checkpoints/                  # 训练检查点

监控工具:
  script/monitor_training.sh              # 监控脚本
  script/start_train.sh                   # 快速启动脚本
  script/clean_data.sh                    # 数据清洁脚本
  script/generate_shards.sh               # 分片生成脚本
  script/run_large_pretrain.sh            # 训练脚本
```

## 🎯 建议的操作步骤

### 第一步：检查当前状态
```bash
tail -30 artifacts/logs/train_*.log | grep -v "^$"
```

### 第二步：根据情况选择
- **有新的日志输出** → 训练仍在进行，继续监控
- **日志停滞** → 检查错误或重启
- **无日志文件** → 检查make命令

### 第三步：实时监控
```bash
bash script/monitor_training.sh
# 或
tail -f artifacts/logs/train_*.log
```

### 第四步：问题排除
参考本文档的**故障排除**部分

---

**相关文档**：
- `MAKE_TRAIN_DIAGNOSIS.md` - 详细诊断报告
- `script/monitor_training.sh` - 监控脚本源代码
