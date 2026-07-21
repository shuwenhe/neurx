# NeurX afterTrainingQuick Startguide

## 🎯 概述

本guideWill指导您如何Usage NeurX framework对 **Qwen2.5-0.5B-Instruct** ModelenterlineComplete of afterTraining,andWillGenerate of Model saving to  `/home/shuwen/shuwen/train/model` Directory.

### keyInformation
- 📍 **baseModel**: `/home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct`
- 📊 **Dataset**: MedMCQA (medical多选题)
- 🎓 **method**: LoRA SFT (Low-Rank Supervised Fine-Tuning)
- 📋 **Configuration**: `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml`
- 🎁 **Output**: `/home/shuwen/shuwen/train/model/base-model-posttrain` ✨

---

## 📋 前置condition

Check以下File是否store in :

```bash
# baseModel
ls /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/model.safetensors

# TrainingData
ls /home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl
ls /home/shuwen/shuwen/train/dataset/medmcqa/val.jsonl

# ConfigurationFile
ls /home/shuwen/shuwen/train/neurx/configs/posttrain.yaml

# S compiledevice
ls /home/shuwen/shuwen/train/s/bin/s_seed
```

---

## ⚡ 快速Execute (3 step)

### Step 1: display and VerificationConfiguration

```bash
cd /home/shuwen/shuwen/train/neurx

# compileandRunConfigurationscript
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_posttrain_pipeline.s \
  /tmp/posttrain_config.ir

# ExecuteConfigurationscript
/home/shuwen/shuwen/train/s/bin/s_seed --emit-bin \
  /tmp/posttrain_config.ir /tmp/posttrain_config.bin
```

**expectedOutput:**
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

### Step 2: Launch LoRA SFT Training

```bash
cd /home/shuwen/shuwen/train/neurx

# compileTrainingscript
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_sft_training_simple.s \
  /tmp/lora_training.ir

# RunTraining(need GPU)
# 预计Time: 1-2 hours
timeout 7200 /home/shuwen/shuwen/train/s/bin/s_seed --emit-bin \
  /tmp/lora_training.ir /tmp/lora_training.bin \
  2>&1 | tee artifacts/logs/training.log
```

**TrainingOutputFile:**
```
artifacts/checkpoints/lora_sft/
├── adapter_model.safetensors    ← LoRA weights (~50-100MB)
├── adapter_config.json          ← Configuration
└── training_state.json          ← status

artifacts/logs/
└── training.log                 ← TrainingLog
```

### Step 3: MergeModelandsave

```bash
# compileMergescript
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_merge.s \
  /tmp/lora_merge.ir

# ExecuteMerge(预计 5-10 minutes)
/home/shuwen/shuwen/train/s/bin/s_seed --emit-bin \
  /tmp/lora_merge.ir /tmp/lora_merge.bin
```

**finalOutputFile:**
```
/home/shuwen/shuwen/train/model/base-model-posttrain/
├── model.safetensors            ← ✨ finalMergeModel (~1.5GB)
├── config.json                  ← ModelConfiguration
├── tokenizer.json               ← 分词device
├── generation_config.json       ← GenerateConfiguration
└── README.md                    ← description
```

---

## 🔍 Configuration详解

 from  `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml` read of keyParameter:

### ModelConfiguration
```yaml
model:
  base_model_path: /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct
  model_name: Qwen2.5-0.5B-Instruct
  model_type: qwen
```

### LoRA Parameter
```yaml
lora:
  rank: 8              # rankSize (Parameterefficiency)
  alpha: 16            # scaling因子
  dropout: 0.05        # LoRA dropout
```

### TrainingParameter
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

### Outputlocation
```yaml
output:
  adapter_output_dir: /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft
  merged_model_output_dir: /home/shuwen/shuwen/train/model/base-model-posttrain
  log_dir: /home/shuwen/shuwen/train/neurx/artifacts/logs
  
merge:
  merge_lora_after_training: true  # 自动Merge
```

---

## 📊 expectedPerformance

| Phase | time | Output | GPU 要求 |
|------|------|------|----------|
| LoRA Training | 1-2 hours | adapter_model.safetensors (~100MB) | 1x 8GB+ GPU |
| ModelMerge | 5-10 minutes | model.safetensors (~1.5GB) | CPU 足够 |
| **总计** | **1-2.5 hours** | **CompleteModel** | |

---

## ✅ Verify output

TrainingAfter completionVerificationGenerate of File:

```bash
# Check LoRA adapter
ls -lah /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/
# 应该display: adapter_model.safetensors, adapter_config.json

# CheckfinalModel
ls -lah /home/shuwen/shuwen/train/model/base-model-posttrain/
# 应该display: model.safetensors, config.json, tokenizer.json, ...

# ViewModelSize
du -sh /home/shuwen/shuwen/train/model/base-model-posttrain/model.safetensors

# ViewTrainingLog
tail -50 /home/shuwen/shuwen/train/neurx/artifacts/logs/training.log
```

---

## 🛠️ FAQ

### Q: 如何modificationTrainingParameter?
**A:** Edit `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml`,然after重新RunTrainingscript.

### Q: Training因为 GPU MemoryNot足而Failed?
**A:**  in  `posttrain.yaml` in减小Parameter:
```yaml
training:
  batch_size: 16        #  from  32 改为 16
  gradient_accumulation_steps: 4  # Increasegradient累积
lora:
  rank: 4               #  from  8 改为 4
```

### Q: 如何Restorein断 of Training?
**A:** Check `artifacts/checkpoints/lora_sft/training_state.json` in of status,然after重新Runscript.

### Q: finalModelstoreWhere?
**A:** Complete of afterTrainingModel saving in :
```
/home/shuwen/shuwen/train/model/base-model-posttrain/
```

---

## 📚 correlationdocumentation

| documentation | Path |
|------|------|
| CompleteExecuteguide | [POSTTRAIN_EXECUTION_GUIDE.md](./POSTTRAIN_EXECUTION_GUIDE.md) |
| LoRA adapter | [README_PEFT.md](./README_PEFT.md) |
| SFT Training | [../sft/README_SFT.md](../sft/README_SFT.md) |
| ConfigurationFile | [../configs/posttrain.yaml](../configs/posttrain.yaml) |

---

## 🎯 next step

TrainingAfter completion,您可以:

1. **TestModel**
   ```bash
   python -c "from transformers import AutoModelForCausalLM, AutoTokenizer; \
   model = AutoModelForCausalLM.from_pretrained('/home/shuwen/shuwen/train/model/base-model-posttrain'); \
   tokenizer = AutoTokenizer.from_pretrained('/home/shuwen/shuwen/train/model/base-model-posttrain')"
   ```

2. **deploymentModel**
   ```bash
   # Usage Hugging Face  of inference API
   #  or deployment to privateServer
   ```

3. **EvaluationPerformance**
   ```bash
   cd /home/shuwen/shuwen/train/neurx
   python evaluation/evaluate_*.py \
     --model_path /home/shuwen/shuwen/train/model/base-model-posttrain \
     --dataset medmcqa
   ```

---

## 💡 PerformanceOptimize建议

- **LoRA Rank**: 8 适合小型Model,大型Model可用 16-32
- **Batch Size**: 根据 GPU Memory调整,32 通常是好 of 起point
- **learning_rate**: 0.0005 对 LoRA 通常很好,可尝试 0.0001-0.001
- **epochs**: 3 是benchmark,可根据DatasetSize调整为 1-5

---

**最aftermodification:** 2026-07-21  
**framework:** NeurX  
**编程Language:** S Language (allscript)  
**support:** 详见 POSTTRAIN_EXECUTION_GUIDE.md
