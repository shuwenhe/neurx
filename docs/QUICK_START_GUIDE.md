# 🎯 NeurX Claude级LLM训练 - 用户快速开始指南

**最后更新**: 2026-01-01  
**状态**: ✅ 完整系统就绪  

---

## 📋 目录

1. [系统检查](#系统检查)
2. [核心命令](#核心命令)
3. [训练流程](#训练流程)
4. [监控和评估](#监控和评估)
5. [故障排除](#故障排除)
6. [性能优化](#性能优化)

---

## 系统检查

在开始前，验证系统状态:

```bash
cd /Users/feifei/shuwen/train/neurx

# 1. 检查系统状态
make status

# 2. 查看帮助
make help

# 3. 检查依赖
which s          # S编译器
python3 --version  # Python
```

**预期输出**:
```
📊 NeurX System Status:
  Platform: macos
  S Compiler: /Users/feifei/shuwen/train/s/.local/bin/s
  Python: Python 3.9+
  
  ✓ Config file found
  ✓ Training data present (5,500 samples)
  ✓ Model configured (GPT-Large 346M params)
```

---

## 核心命令

### 🔨 构建和准备

```bash
# 构建所有评估工具
make build-eval-tools

# 显示结果
# ✓ Tokenizer
# ✓ Evaluator  
# ✓ Checkpoint Manager
# ✓ Training Monitor
```

### 🚀 开始训练

#### 方法1: 基础训练
```bash
make train

# 输出:
# [=================>                              ] 15.0% | Step 15000/100000
# Loss: 1.2345 | LR: 5.00e-04 | Speed: 1050 tok/s | Elapsed: 3h 45m | ETA: 21h 15m
```

#### 方法2: 带监控的训练
```bash
make train-with-monitoring

# 同时显示:
# - 实时进度条
# - 损失曲线
# - 吞吐量
# - 内存使用
```

#### 方法3: 快速验证
```bash
make quick-train

# 相当于:
# 1. 构建工具
# 2. 验证配置
# 3. 启动训练
```

---

## 训练流程

### 详细步骤

#### 步骤 1: 数据准备

```bash
# 分割数据为train/val/test
make split

# 输出:
# ✂️  Splitting dataset into train/val/test...
# ✓ Train: 4400 samples (80%)
# ✓ Val: 550 samples (10%)
# ✓ Test: 550 samples (10%)
```

#### 步骤 2: 分片优化 (可选)

```bash
# 为大规模训练创建分片
make shard

# 输出:
# 📦 Created 6 shards
# Shard 1: data/training_data_shards/shard-1.jsonl.gz
# ...
```

#### 步骤 3: Tokenization

```bash
# 预先tokenize数据 (可选但推荐)
make tokenize

# 输出:
# 🔤 Tokenized 5500 samples
# Output: data/training_data_tokenized.jsonl
```

#### 步骤 4: 开始训练

```bash
make train

# 首次执行时:
# 1. 自动构建评估工具
# 2. 初始化检查点目录
# 3. 创建日志
# 4. 启动训练循环
```

---

## 监控和评估

### 📈 实时监控

#### 方法1: 从终端查看进度

```bash
# 已在训练窗口显示的信息
[=====================>                          ] 42.5% | Step 42500/100000
Loss: 1.2345 | LR: 4.85e-04 | Speed: 1050 tok/s | Mem: 512MB
Elapsed: 12h 30m | ETA: 17h 15m
```

#### 方法2: 打开单独的监控窗口

```bash
# 新终端窗口
make monitor

# 输出:
# 📈 Training Monitor Started
# Watching: logs/training_20260101_120000.jsonl
# 
# [Real-time updates every 10 seconds]
```

#### 方法3: 查看日志文件

```bash
# 查看最新日志
tail -20 logs/training_*.jsonl | jq '.'

# 输出示例:
# {
#   "step": 45000,
#   "epoch": 1,
#   "loss": 1.2015,
#   "learning_rate": 0.000485,
#   "throughput": 1075.3,
#   "timestamp": "2026-01-01T15:45:00Z"
# }
```

### 📊 评估和指标

#### 计算困惑度

```bash
# 在训练过程中自动计算
# 或手动计算
make eval

# 输出:
# 📊 Computing Perplexity...
# 
# Initial Perplexity: 1000.2
# Current Perplexity: 45.3
# Best Perplexity: 42.8
# Improvement: 95.7%
```

#### 检查点列表

```bash
make checkpoint-list

# 输出:
# 📂 Available checkpoints:
#   Step 1000: 623.5
#   Step 2000: 287.3
#   Step 3000: 145.2
#   Step 4000: 75.1
#   Step 5000: 45.3
```

#### 生成报告

```bash
# 简要报告
make report

# 详细分析
make report-detailed

# 输出:
# 📊 Training Analysis:
#   Total steps: 5000
#   Min loss: 0.9823
#   Max loss: 4.5601
#   Avg loss: 1.8945
#   Improvement: 78.4%
```

---

## 检查点管理

### 💾 保存和加载

#### 自动管理

```bash
# 训练时自动保存
# - 每1000步保存一个检查点
# - 只保留最近5个检查点
# - 自动清理旧的检查点
```

#### 手动操作

```bash
# 列出检查点
make checkpoint-list

# 清理旧检查点 (保留5个)
make checkpoint-cleanup

# 手动保存
make checkpoint-save

# 加载最新检查点
make checkpoint-load
```

### 📂 检查点内容

```
artifacts/checkpoints/
├── checkpoint-1000/
│   ├── model_state.json      # 模型权重
│   ├── optimizer_state.json  # 优化器状态
│   ├── config.json           # 配置
│   └── metadata.json         # 元数据
│       {
│         "step": 1000,
│         "loss": 2.1234,
│         "perplexity": 8.37,
│         "timestamp": "2026-01-01T10:00:00Z"
│       }
└── checkpoint-2000/
    └── ...
```

### 🔄 从检查点恢复

```bash
# 自动: 训练脚本会检测最新检查点并恢复

# 手动: 编辑 config_large_model.json
{
  "training": {
    "resume_from_checkpoint": "artifacts/checkpoints/checkpoint-5000",
    "resume_step": 5000
  }
}

# 然后启动训练
make train
```

---

## 高级功能

### 🎓 模型评估

#### 困惑度分析

```bash
# 困惑度是衡量模型性能的关键指标

# 定义: PPL = exp(-1/N * Σ log(p(w_i)))

# 理解:
# PPL = 5     → 模型学习很好
# PPL = 50    → 平均质量
# PPL = 500   → 模型学习不足

# 目标 (Claude级):
# - 初期: 1000+
# - 中期: 100-200  
# - 最终: < 50

# 查看困惑度趋势
grep -o '"perplexity": [0-9.]*' logs/training.jsonl | sort -u
```

### 🏃 性能优化

#### 提高吞吐量

```bash
# 1. 增加批大小 (config_large_model.json)
{
  "training": {
    "batch_size": 64        # 从32增加到64
  }
}

# 2. 启用混合精度 (待实现)
NEURX_USE_MIXED_PRECISION=1 make train

# 3. 启用梯度检查 (待实现)
NEURX_USE_GRADIENT_CHECKPOINTING=1 make train

# 4. 增加number of workers
{
  "data": {
    "num_workers": 8  # 从4增加到8
  }
}
```

#### 监控资源使用

```bash
# 在训练过程中查看
# - GPU内存使用
# - CPU负载
# - 网络I/O

# 系统命令
nvidia-smi              # GPU监控
top                    # CPU监控
iostat 1               # I/O监控
```

---

## 故障排除

### ❌ 常见问题

#### 问题1: S编译器找不到

```bash
# 错误信息:
# S compiler not found - using bash fallbacks

# 解决方案:
which s
# 如果输出为空

# 手动设置路径
export PATH="/Users/feifei/shuwen/train/s/.local/bin:$PATH"

# 验证
s --version
```

#### 问题2: 显存不足

```bash
# 错误信息:
# RuntimeError: out of memory

# 解决方案:
# 减小批大小
{
  "training": {
    "batch_size": 16,  # 从32减小
    "micro_batch_size": 4
  }
}

# 或启用梯度检查点
NEURX_GRADIENT_CHECKPOINTING=1 make train
```

#### 问题3: 训练缓慢

```bash
# 检查吞吐量
# 如果 < 500 tok/s

# 1. 检查数据I/O
make tokenize  # 预处理数据

# 2. 增加workers
{
  "data": {
    "num_workers": 8,
    "prefetch_factor": 4
  }
}

# 3. 检查系统资源
make status
```

#### 问题4: 困惑度不下降

```bash
# 训练不收敛

# 检查点:
# 1. 学习率太高 - 降低LR
# 2. 学习率太低 - 增加LR
# 3. 数据问题 - 检查数据质量
# 4. 模型问题 - 调整模型大小

# 查看学习率调度
grep -o '"learning_rate": [0-9.e-]*' logs/training.jsonl
```

### 🔧 调试模式

```bash
# 启用详细日志
NEURX_DEBUG=1 make train

# 启用内存分析
NEURX_MEMORY_PROFILING=1 make train

# 启用性能分析
NEURX_PROFILE=1 make train

# 输出调试信息
make status --verbose
```

---

## 性能优化

### 🚀 优化检查表

- [ ] 数据预处理完成 (`make tokenize`)
- [ ] 检查点系统可用 (`make checkpoint-list`)
- [ ] 监控工具就绪 (`make build-eval-tools`)
- [ ] 批大小优化 (config: batch_size=64)
- [ ] 启用梯度累积 (config: gradient_accumulation=4)
- [ ] Workers数量优化 (data: num_workers=8)
- [ ] 启用混合精度 (待实现)
- [ ] 启用梯度检查 (待实现)
- [ ] 启用分布式训练 (待实现)

### 📈 期望的性能指标

| 指标 | 目标 |
|------|------|
| **吞吐量** | > 1000 tok/s |
| **显存效率** | 80%+ |
| **困惑度改进** | 每小时< 1% |
| **收敛时间** | 24-48小时 |
| **最终困惑度** | < 50 |

---

## 📚 更多资源

### 相关文档
- [MISSING_COMPONENTS_ANALYSIS.md](docs/MISSING_COMPONENTS_ANALYSIS.md) - 完整缺失组件分析
- [CRITICAL_COMPONENTS_CREATED.md](docs/CRITICAL_COMPONENTS_CREATED.md) - 新创建组件详解
- [INDUSTRIAL_JSONL_FORMAT.md](docs/INDUSTRIAL_JSONL_FORMAT.md) - 数据格式规范

### 配置文件
- [config_large_model.json](config_large_model.json) - 完整的模型和训练配置

### 脚本
- [scripts/legacy/integration.sh](scripts/legacy/integration.sh) - 训练集成脚本
- [scripts/legacy/tokenizer.s](scripts/legacy/tokenizer.s) - Tokenizer框架
- [scripts/legacy/evaluator.s](scripts/legacy/evaluator.s) - 评估框架
- [scripts/legacy/checkpoint_manager.s](scripts/legacy/checkpoint_manager.s) - 检查点管理
- [scripts/legacy/training_monitor.s](scripts/legacy/training_monitor.s) - 监控框架

---

## 📞 支持

如遇问题，检查以下内容:

1. **系统检查**: `make status`
2. **依赖验证**: `which s`, `python3 --version`
3. **日志分析**: `tail -50 logs/training_*.jsonl`
4. **配置检查**: `cat config_large_model.json | head -30`

---

**快速命令速查**:

```bash
# 一键完整流程
make build-eval-tools && make split && make train

# 监控训练进度
make monitor

# 查看评估指标
make report

# 管理检查点
make checkpoint-list
make checkpoint-cleanup

# 恢复训练
make checkpoint-load
make train
```

**祝你训练顺利！** 🚀
