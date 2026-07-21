# NeurX 完整后训练执行指南

## 📖 概述

本指南说明如何使用 NeurX 框架和提供的 S 语言脚本，对 Qwen2.5-0.5B-Instruct 模型进行完整的后训练（Post-Training），包括 LoRA SFT 训练和模型合并。

**关键配置:**
- 🎯 基础模型: `Qwen2.5-0.5B-Instruct`
- 📊 数据集: `MedMCQA` (医学多选题)
- 🔧 训练方法: LoRA SFT (Low-Rank Supervised Fine-Tuning)
- 💾 配置文件: `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml`
- 🎓 输出位置: `/home/shuwen/shuwen/train/model/base-model-posttrain`

---

## 🗂️ 项目结构

```
/home/shuwen/shuwen/train/
├── model/                          # 模型存储
│   ├── Qwen2.5-0.5B-Instruct/     # 基础模型 ✓
│   └── base-model-posttrain/       # 后训练模型输出 (新建)
│
├── dataset/
│   └── medmcqa/
│       ├── train.jsonl             # 训练数据
│       └── val.jsonl               # 验证数据
│
└── neurx/                          # NeurX 框架
    ├── configs/
    │   └── posttrain.yaml          # ⭐ 后训练配置
    │
    ├── lib/                        # 基础库
    │   ├── tensor.s                # 张量计算
    │   ├── nn.s                    # 神经网络层
    │   ├── loss.s                  # 损失函数
    │   ├── json.s                  # JSON 解析
    │   └── fileio.s                # 文件 I/O
    │
    ├── posttrain/                  # 后训练模块
    │   └── adapter/
    │       ├── run_lora_sft_training_simple.s      # LoRA SFT 训练脚本
    │       ├── run_lora_merge.s                    # LoRA 合并脚本
    │       ├── run_posttrain_pipeline.s            # ⭐ 配置验证脚本
    │       └── execute_posttrain_pipeline.s        # ⭐ 执行流程脚本
    │
    ├── artifacts/
    │   ├── checkpoints/
    │   │   └── lora_sft/           # LoRA 适配器检查点
    │   └── logs/                   # 训练日志
    │
    └── s/bin/s_seed                # S 编译器

```

---

## 📋 配置文件详解

配置文件位置: `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml`

### 模型配置
```yaml
model:
  base_model_path: /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct
  model_name: Qwen2.5-0.5B-Instruct
  model_type: qwen
```

### 数据配置
```yaml
data:
  train_data_path: /home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl
  val_data_path: /home/shuwen/shuwen/train/dataset/medmcqa/val.jsonl
  data_format: sft
  dataset_type: medmcqa
```

### 输出配置
```yaml
output:
  adapter_output_dir: /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft
  merged_model_output_dir: /home/shuwen/shuwen/train/model/base-model-posttrain
  log_dir: /home/shuwen/shuwen/train/neurx/artifacts/logs
```

### LoRA 配置
```yaml
lora:
  rank: 8              # LoRA 秩
  alpha: 16            # LoRA alpha 系数
  dropout: 0.05        # LoRA dropout 概率
  target_modules:
    - q_proj
    - v_proj
    - k_proj
    - o_proj
    - gate_proj
    - up_proj
    - down_proj
```

### 训练配置
```yaml
training:
  training_method: sft
  num_epochs: 3
  batch_size: 32
  gradient_accumulation_steps: 1
  learning_rate: 0.0005
  lr_scheduler: cosine
  warmup_steps: 100
  max_steps: -1
  weight_decay: 0.01
  optimizer: adamw_8bit
  max_grad_norm: 1.0
```

### 合并配置
```yaml
merge:
  merge_lora_after_training: true
```

---

## 🚀 执行步骤

### 第 1 步: 验证配置

首先运行配置验证脚本，确保所有路径和参数都配置正确：

```bash
cd /home/shuwen/shuwen/train/neurx

# 方式 1: 直接用 S 编译器运行
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_posttrain_pipeline.s

# 方式 2: 通过 Makefile (如果已配置)
make posttrain-show-config
```

**预期输出:**
- ✓ 所有文件路径验证
- ✓ 配置参数显示
- ✓ 训练计划确认

### 第 2 步: 查看执行计划

运行完整执行流程脚本，了解所有执行步骤：

```bash
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/execute_posttrain_pipeline.s
```

**预期输出:**
```
╔════════════════════════════════════════════════════════════════╗
║   NeurX 完整后训练执行流程                                      ║
║   后训练方法: LoRA SFT (Low-Rank Supervised Fine-Tuning)       ║
║   基础模型: Qwen2.5-0.5B-Instruct                              ║
║   数据集: MedMCQA (医学多选题)                                 ║
╚════════════════════════════════════════════════════════════════╝

步骤 1: 验证环境
  ✓ 基础模型路径
  ✓ 训练数据路径
  ...

步骤 2: 配置确认
  LoRA 配置:
    • Rank        : 8
    • Alpha       : 16
    ...

步骤 3: 启动 LoRA SFT 训练
  执行命令:
    /home/shuwen/shuwen/train/s/bin/s_seed \
    /home/shuwen/shuwen/train/neurx/posttrain/adapter/run_lora_sft_training_simple.s

步骤 4: 合并 LoRA 适配器到基础模型
  执行命令:
    /home/shuwen/shuwen/train/s/bin/s_seed \
    /home/shuwen/shuwen/train/neurx/posttrain/adapter/run_lora_merge.s

步骤 5: 验证输出
  LoRA 适配器检查点位置:
    /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/
  
  合并后的模型位置:
    /home/shuwen/shuwen/train/model/base-model-posttrain/
```

### 第 3 步: 执行 LoRA SFT 训练

这是整个流程中最耗时的步骤，需要 GPU。

```bash
cd /home/shuwen/shuwen/train/neurx

# 方式 1: 直接运行训练脚本
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_sft_training_simple.s

# 方式 2: 通过 Makefile (如果已配置)
make posttrain-sft-train

# 方式 3: 后台运行并保存日志
nohup /home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_sft_training_simple.s \
  > artifacts/logs/training.log 2>&1 &
```

**训练流程:**

```
1. 加载基础模型: Qwen2.5-0.5B-Instruct
   └─ 从 /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct 加载
   
2. 初始化 LoRA 适配器
   └─ Rank: 8, Alpha: 16
   
3. 加载训练数据
   └─ train.jsonl (训练集)
   └─ val.jsonl (验证集)
   
4. 执行 3 轮训练
   └─ 每轮使用 32 的批次大小
   └─ 学习率: 0.0005 (使用余弦调度)
   
5. 保存检查点
   └─ /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/
   
输出文件:
  • adapter_model.safetensors     (LoRA 权重, ~50-100MB)
  • adapter_config.json           (配置参数)
  • training_state.json           (训练状态)
  • training_log.txt              (训练日志)
```

**预期输出:**
- ✓ 训练进度信息
- ✓ 每个轮次的损失值
- ✓ 验证集性能
- ✓ 检查点保存位置

**如何监控训练:**

```bash
# 查看实时日志
tail -f artifacts/logs/training.log

# 查看训练参数统计
cat artifacts/logs/training_metrics.json | python -m json.tool

# 检查生成的检查点
ls -lah artifacts/checkpoints/lora_sft/
```

### 第 4 步: 合并 LoRA 适配器到基础模型

训练完成后，将 LoRA 适配器合并到基础模型，生成完整的后训练模型。

```bash
cd /home/shuwen/shuwen/train/neurx

# 方式 1: 直接运行合并脚本
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_merge.s

# 方式 2: 通过 Makefile (如果已配置)
make posttrain-merge-lora

# 方式 3: 指定输入输出路径
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_merge.s \
  --base-model /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct \
  --adapter /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft \
  --output /home/shuwen/shuwen/train/model/base-model-posttrain
```

**合并流程:**

```
1. 加载基础模型权重
   └─ /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/model.safetensors
   
2. 加载 LoRA 适配器权重
   └─ /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/adapter_model.safetensors
   
3. 应用 LoRA 合并公式
   └─ W_new = W_base + (α/r) × B × A
   └─ 对所有目标层应用合并
   
4. 保存完整的合并模型
   └─ /home/shuwen/shuwen/train/model/base-model-posttrain/

输出文件:
  • model.safetensors           (完整合并模型)
  • config.json                 (模型配置)
  • generation_config.json      (生成配置)
  • tokenizer.json              (分词器)
  • tokenizer_config.json       (分词器配置)
  • README.md                   (说明文档)
```

**预期输出:**
- ✓ 合并完成确认
- ✓ 输出文件大小
- ✓ 模型验证信息

### 第 5 步: 验证输出

检查生成的所有输出文件。

```bash
# 检查 LoRA 适配器检查点
ls -lah /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/
# 预期文件:
#   adapter_model.safetensors (LoRA 权重)
#   adapter_config.json       (配置)

# 检查合并后的模型
ls -lah /home/shuwen/shuwen/train/model/base-model-posttrain/
# 预期文件:
#   model.safetensors
#   config.json
#   tokenizer.json
#   ...

# 验证模型文件大小
du -sh /home/shuwen/shuwen/train/model/base-model-posttrain/*

# 查看训练日志
cat /home/shuwen/shuwen/train/neurx/artifacts/logs/training_log.txt
```

---

## 🔄 完整一键执行流程

如果已经配置了 Makefile 规则，可以使用一条命令执行完整流程：

```bash
cd /home/shuwen/shuwen/train/neurx

# 验证 + 显示配置
make posttrain-show-config

# 启动完整训练 + 合并流程 (后台运行)
make posttrain-complete

# 只合并模型
make posttrain-merge-to-model

# 验证输出
make posttrain-verify-output
```

---

## 📊 预期结果

### 训练时间估算

| 阶段 | 耗时 | GPU 需求 |
|------|------|----------|
| LoRA SFT 训练 | 1-2 小时 | 1x GPU (8GB+) |
| 模型合并 | 5-10 分钟 | CPU 即可 |
| **总计** | **1-2.5 小时** | |

### 输出文件

| 路径 | 文件 | 说明 |
|------|------|------|
| `artifacts/checkpoints/lora_sft/` | `adapter_model.safetensors` | LoRA 权重 (~50-100MB) |
| | `adapter_config.json` | LoRA 配置 |
| | `training_state.json` | 训练状态 |
| `artifacts/logs/` | `training_log.txt` | 训练日志 |
| | `training_metrics.json` | 训练指标 |
| `model/base-model-posttrain/` | `model.safetensors` | 合并后完整模型 (~1.5GB) |
| | `config.json` | 模型配置 |
| | `tokenizer.json` | 分词器 |

### 模型性能对比

| 指标 | 基础模型 | 后训练模型 |
|------|---------|----------|
| 模型大小 | ~1.5GB | ~1.5GB |
| 推理速度 | 基准 | ≈ 基准 |
| MedMCQA 准确率 | X% | X+Y% |

---

## 🛠️ 故障排查

### 问题 1: "找不到基础模型"
```
错误信息: Base model not found at /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct
```

**解决:**
```bash
# 检查模型文件
ls -la /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/

# 如果不存在，下载或复制模型
# 确保包含: model.safetensors, config.json, tokenizer.json 等
```

### 问题 2: "数据文件不存在"
```
错误信息: Training data file not found
```

**解决:**
```bash
# 检查数据文件
ls -la /home/shuwen/shuwen/train/dataset/medmcqa/

# 确保包含: train.jsonl, val.jsonl
```

### 问题 3: "GPU 内存不足"
```
错误信息: CUDA out of memory
```

**解决:**
- 减小 batch_size: `batch_size: 16` (改为 8 或 16)
- 增加梯度累积: `gradient_accumulation_steps: 4`
- 减小 LoRA rank: `rank: 4` (改为 4)

### 问题 4: "S 编译器错误"
```
错误信息: s_seed: command not found
```

**解决:**
```bash
# 检查 S 编译器路径
ls -la /home/shuwen/shuwen/train/s/bin/s_seed

# 添加到 PATH
export PATH="/home/shuwen/shuwen/train/s/bin:$PATH"
```

---

## 📚 相关文档

- [NeurX 框架介绍](../README.md)
- [LoRA 适配器文档](../adapter/README_PEFT.md)
- [SFT 训练文档](../sft/README_SFT.md)
- [S 语言编程指南](../../s/README.md)

---

## ✨ 总结

通过本指南，您可以:

1. ✅ **验证配置** - 确保所有路径和参数正确
2. ✅ **启动训练** - 对 Qwen 模型进行 LoRA SFT 微调
3. ✅ **合并模型** - 将 LoRA 适配器集成到基础模型
4. ✅ **验证输出** - 确保生成的模型可用

**最终输出:**
```
✨ 后训练完成！
📁 输出位置: /home/shuwen/shuwen/train/model/base-model-posttrain/
🎯 模型已准备好进行部署和推理
```

---

## 🤝 获取帮助

如有问题，请检查:
1. 配置文件: `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml`
2. 训练日志: `/home/shuwen/shuwen/train/neurx/artifacts/logs/training_log.txt`
3. 项目文档: `../README.md` 和 `../IMPLEMENTATION_SUMMARY.md`

**最后修改:** 2026-07-21
**框架版本:** NeurX
**支持语言:** S Language
