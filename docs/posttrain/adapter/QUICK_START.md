# NeurX 后训练快速开始指南

## 🎯 概述

本指南将指导您如何使用 NeurX 框架对 **Qwen2.5-0.5B-Instruct** 模型进行完整的后训练，并将生成的模型保存到 `/home/shuwen/shuwen/train/model` 目录。

### 关键信息
- 📍 **基础模型**: `/home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct`
- 📊 **数据集**: MedMCQA (医学多选题)
- 🎓 **方法**: LoRA SFT (Low-Rank Supervised Fine-Tuning)
- 📋 **配置**: `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml`
- 🎁 **输出**: `/home/shuwen/shuwen/train/model/base-model-posttrain` ✨

---

## 📋 前置条件

检查以下文件是否存在：

```bash
# 基础模型
ls /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/model.safetensors

# 训练数据
ls /home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl
ls /home/shuwen/shuwen/train/dataset/medmcqa/val.jsonl

# 配置文件
ls /home/shuwen/shuwen/train/neurx/configs/posttrain.yaml

# S 编译器
ls /home/shuwen/shuwen/train/s/bin/s_seed
```

---

## ⚡ 快速执行 (3 步)

### Step 1: 显示和验证配置

```bash
cd /home/shuwen/shuwen/train/neurx

# 编译并运行配置脚本
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_posttrain_pipeline.s \
  /tmp/posttrain_config.ir

# 执行配置脚本
/home/shuwen/shuwen/train/s/bin/s_seed --emit-bin \
  /tmp/posttrain_config.ir /tmp/posttrain_config.bin
```

**预期输出:**
```
╔════════════════════════════════════════════════════════════════╗
║   NeurX Post-Training Configuration                             ║
║   LoRA SFT + Model Merge Pipeline                              ║
╚════════════════════════════════════════════════════════════════╝

📋 CONFIGURATION SUMMARY
═══════════════════════════════════════════════════════════════

📦 Model Configuration
  Base Model        : Qwen2.5-0.5B-Instruct
  Model Path        : /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct
  ...

✅ Configuration Validation
  ✓ Base model path validated
  ✓ Training data file exists
  ...
```

### Step 2: 启动 LoRA SFT 训练

```bash
cd /home/shuwen/shuwen/train/neurx

# 编译训练脚本
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_sft_training_simple.s \
  /tmp/lora_training.ir

# 运行训练（需要 GPU）
# 预计时间: 1-2 小时
timeout 7200 /home/shuwen/shuwen/train/s/bin/s_seed --emit-bin \
  /tmp/lora_training.ir /tmp/lora_training.bin \
  2>&1 | tee artifacts/logs/training.log
```

**训练输出文件:**
```
artifacts/checkpoints/lora_sft/
├── adapter_model.safetensors    ← LoRA 权重 (~50-100MB)
├── adapter_config.json          ← 配置
└── training_state.json          ← 状态

artifacts/logs/
└── training.log                 ← 训练日志
```

### Step 3: 合并模型并保存

```bash
# 编译合并脚本
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_merge.s \
  /tmp/lora_merge.ir

# 执行合并（预计 5-10 分钟）
/home/shuwen/shuwen/train/s/bin/s_seed --emit-bin \
  /tmp/lora_merge.ir /tmp/lora_merge.bin
```

**最终输出文件:**
```
/home/shuwen/shuwen/train/model/base-model-posttrain/
├── model.safetensors            ← ✨ 最终合并模型 (~1.5GB)
├── config.json                  ← 模型配置
├── tokenizer.json               ← 分词器
├── generation_config.json       ← 生成配置
└── README.md                    ← 说明
```

---

## 🔍 配置详解

从 `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml` 读取的关键参数：

### 模型配置
```yaml
model:
  base_model_path: /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct
  model_name: Qwen2.5-0.5B-Instruct
  model_type: qwen
```

### LoRA 参数
```yaml
lora:
  rank: 8              # 秩大小 (参数效率)
  alpha: 16            # 缩放因子
  dropout: 0.05        # LoRA dropout
```

### 训练参数
```yaml
training:
  training_method: sft
  num_epochs: 3
  batch_size: 32
  learning_rate: 0.0005
  lr_scheduler: cosine
  warmup_steps: 100
  max_grad_norm: 1.0
  weight_decay: 0.01
  optimizer: adamw_8bit
```

### 输出位置
```yaml
output:
  adapter_output_dir: /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft
  merged_model_output_dir: /home/shuwen/shuwen/train/model/base-model-posttrain
  log_dir: /home/shuwen/shuwen/train/neurx/artifacts/logs
  
merge:
  merge_lora_after_training: true  # 自动合并
```

---

## 📊 预期性能

| 阶段 | 耗时 | 输出 | GPU 要求 |
|------|------|------|----------|
| LoRA 训练 | 1-2 小时 | adapter_model.safetensors (~100MB) | 1x 8GB+ GPU |
| 模型合并 | 5-10 分钟 | model.safetensors (~1.5GB) | CPU 足够 |
| **总计** | **1-2.5 小时** | **完整模型** | |

---

## ✅ 验证输出

训练完成后验证生成的文件：

```bash
# 检查 LoRA 适配器
ls -lah /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/
# 应该显示: adapter_model.safetensors, adapter_config.json

# 检查最终模型
ls -lah /home/shuwen/shuwen/train/model/base-model-posttrain/
# 应该显示: model.safetensors, config.json, tokenizer.json, ...

# 查看模型大小
du -sh /home/shuwen/shuwen/train/model/base-model-posttrain/model.safetensors

# 查看训练日志
tail -50 /home/shuwen/shuwen/train/neurx/artifacts/logs/training.log
```

---

## 🛠️ 常见问题

### Q: 如何修改训练参数？
**A:** 编辑 `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml`，然后重新运行训练脚本。

### Q: 训练因为 GPU 内存不足而失败？
**A:** 在 `posttrain.yaml` 中减小参数:
```yaml
training:
  batch_size: 16        # 从 32 改为 16
  gradient_accumulation_steps: 4  # 增加梯度累积
lora:
  rank: 4               # 从 8 改为 4
```

### Q: 如何恢复中断的训练？
**A:** 检查 `artifacts/checkpoints/lora_sft/training_state.json` 中的状态，然后重新运行脚本。

### Q: 最终模型存在哪里？
**A:** 完整的后训练模型保存在:
```
/home/shuwen/shuwen/train/model/base-model-posttrain/
```

---

## 📚 相关文档

| 文档 | 路径 |
|------|------|
| 完整执行指南 | [POSTTRAIN_EXECUTION_GUIDE.md](./POSTTRAIN_EXECUTION_GUIDE.md) |
| LoRA 适配器 | [README_PEFT.md](./README_PEFT.md) |
| SFT 训练 | [../sft/README_SFT.md](../sft/README_SFT.md) |
| 配置文件 | [../configs/posttrain.yaml](../configs/posttrain.yaml) |

---

## 🎯 下一步

训练完成后，您可以:

1. **测试模型**
   ```bash
   python -c "from transformers import AutoModelForCausalLM, AutoTokenizer; \
   model = AutoModelForCausalLM.from_pretrained('/home/shuwen/shuwen/train/model/base-model-posttrain'); \
   tokenizer = AutoTokenizer.from_pretrained('/home/shuwen/shuwen/train/model/base-model-posttrain')"
   ```

2. **部署模型**
   ```bash
   # 使用 Hugging Face 的推理 API
   # 或部署到私有服务器
   ```

3. **评估性能**
   ```bash
   cd /home/shuwen/shuwen/train/neurx
   python evaluation/evaluate_*.py \
     --model_path /home/shuwen/shuwen/train/model/base-model-posttrain \
     --dataset medmcqa
   ```

---

## 💡 性能优化建议

- **LoRA Rank**: 8 适合小型模型，大型模型可用 16-32
- **Batch Size**: 根据 GPU 内存调整，32 通常是好的起点
- **学习率**: 0.0005 对 LoRA 通常很好，可尝试 0.0001-0.001
- **epochs**: 3 是基准，可根据数据集大小调整为 1-5

---

**最后修改:** 2026-07-21  
**框架:** NeurX  
**编程语言:** S Language (所有脚本)  
**支持:** 详见 POSTTRAIN_EXECUTION_GUIDE.md
