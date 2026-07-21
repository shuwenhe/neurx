# NeurX CompleteafterTrainingExecuteguide

## 📖 概述

本guidedescription如何Usage NeurX framework and 提供 of  S Languagescript,对 Qwen2.5-0.5B-Instruct Model进lineComplete of afterTraining(Post-Training),package括 LoRA SFT Training and ModelMerge.

**keyConfiguration:**
- 🎯 baseModel: `Qwen2.5-0.5B-Instruct`
- 📊 Dataset: `MedMCQA` (medical多选题)
- 🔧 Trainingmethod: LoRA SFT (Low-Rank Supervised Fine-Tuning)
- 💾 ConfigurationFile: `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml`
- 🎓 Outputlocation: `/home/shuwen/shuwen/train/model/base-model-posttrain`

---

## 🗂️ 项目structure

```
/home/shuwen/shuwen/train/
├── model/                          # Model存储
│   ├── Qwen2.5-0.5B-Instruct/     # baseModel ✓
│   └── base-model-posttrain/       # afterTrainingModelOutput (新建)
│
├── dataset/
│   └── medmcqa/
│       ├── train.jsonl             # TrainingData
│       └── val.jsonl               # VerificationData
│
└── neurx/                          # NeurX framework
    ├── configs/
    │   └── posttrain.yaml          # ⭐ afterTrainingConfiguration
    │
    ├── lib/                        # baseLibraries
    │   ├── tensor.s                # 张量计算
    │   ├── nn.s                    # 神经networklayer
    │   ├── loss.s                  # lossfunction
    │   ├── json.s                  # JSON parse
    │   └── fileio.s                # File I/O
    │
    ├── posttrain/                  # afterTrainingmodule
    │   └── adapter/
    │       ├── run_lora_sft_training_simple.s      # LoRA SFT Trainingscript
    │       ├── run_lora_merge.s                    # LoRA Mergescript
    │       ├── run_posttrain_pipeline.s            # ⭐ ConfigurationVerificationscript
    │       └── execute_posttrain_pipeline.s        # ⭐ Executeprocessscript
    │
    ├── artifacts/
    │   ├── checkpoints/
    │   │   └── lora_sft/           # LoRA adapterCheckpoint
    │   └── logs/                   # TrainingLog
    │
    └── s/bin/s_seed                # S compiledevice

```

---

## 📋 ConfigurationFile详解

ConfigurationFilelocation: `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml`

### ModelConfiguration
```yaml
model:
  base_model_path: /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct
  model_name: Qwen2.5-0.5B-Instruct
  model_type: qwen
```

### DataConfiguration
```yaml
data:
  train_data_path: /home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl
  val_data_path: /home/shuwen/shuwen/train/dataset/medmcqa/val.jsonl
  data_format: sft
  dataset_type: medmcqa
```

### OutputConfiguration
```yaml
output:
  adapter_output_dir: /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft
  merged_model_output_dir: /home/shuwen/shuwen/train/model/base-model-posttrain
  log_dir: /home/shuwen/shuwen/train/neurx/artifacts/logs
```

### LoRA Configuration
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

### TrainingConfiguration
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

### MergeConfiguration
```yaml
merge:
  merge_lora_after_training: true
```

---

## 🚀 ExecuteStep

### 第 1 步: VerificationConfiguration

首先RunConfigurationVerificationscript,确保allPath and Parameter都Configuration正确:

```bash
cd /home/shuwen/shuwen/train/neurx

# way 1: 直接用 S compiledeviceRun
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_posttrain_pipeline.s

# way 2: 通过 Makefile (如果haveConfiguration)
make posttrain-show-config
```

**expectedOutput:**
- ✓ allFilePathVerification
- ✓ ConfigurationParameter显示
- ✓ Training计划Confirm

### 第 2 步: ViewExecute计划

RunCompleteExecuteprocessscript,了解allExecuteStep:

```bash
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/execute_posttrain_pipeline.s
```

**expectedOutput:**
```
╔════════════════════════════════════════════════════════════════╗
║   NeurX CompleteafterTrainingExecuteprocess                                      ║
║   afterTrainingmethod: LoRA SFT (Low-Rank Supervised Fine-Tuning)       ║
║   baseModel: Qwen2.5-0.5B-Instruct                              ║
║   Dataset: MedMCQA (medical多选题)                                 ║
╚════════════════════════════════════════════════════════════════╝

Step 1: Verification环境
  ✓ baseModelPath
  ✓ TrainingDataPath
  ...

Step 2: ConfigurationConfirm
  LoRA Configuration:
    • Rank        : 8
    • Alpha       : 16
    ...

Step 3: Launch LoRA SFT Training
  Executecommand:
    /home/shuwen/shuwen/train/s/bin/s_seed \
    /home/shuwen/shuwen/train/neurx/posttrain/adapter/run_lora_sft_training_simple.s

Step 4: Merge LoRA adapter to baseModel
  Executecommand:
    /home/shuwen/shuwen/train/s/bin/s_seed \
    /home/shuwen/shuwen/train/neurx/posttrain/adapter/run_lora_merge.s

Step 5: Verify output
  LoRA adapterCheckpointlocation:
    /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/
  
  Mergeafter of Modellocation:
    /home/shuwen/shuwen/train/model/base-model-posttrain/
```

### 第 3 步: Execute LoRA SFT Training

这是整 processin最time of Step,need GPU.

```bash
cd /home/shuwen/shuwen/train/neurx

# way 1: 直接RunTrainingscript
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_sft_training_simple.s

# way 2: 通过 Makefile (如果haveConfiguration)
make posttrain-sft-train

# way 3: after台Run并saveLog
nohup /home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_sft_training_simple.s \
  > artifacts/logs/training.log 2>&1 &
```

**Trainingprocess:**

```
1. loadbaseModel: Qwen2.5-0.5B-Instruct
   └─  from  /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct load
   
2. initialize LoRA adapter
   └─ Rank: 8, Alpha: 16
   
3. loadTrainingData
   └─ train.jsonl (Trainingset)
   └─ val.jsonl (Verificationset)
   
4. Execute 3 轮Training
   └─ 每轮Usage 32  of 批次Size
   └─ learning_rate: 0.0005 (Usage余弦调度)
   
5. saveCheckpoint
   └─ /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/
   
OutputFile:
  • adapter_model.safetensors     (LoRA weights, ~50-100MB)
  • adapter_config.json           (ConfigurationParameter)
  • training_state.json           (Trainingstatus)
  • training_log.txt              (TrainingLog)
```

**expectedOutput:**
- ✓ Training进度Information
- ✓ 每 轮次 of loss值
- ✓ VerificationsetPerformance
- ✓ Checkpointsavelocation

**如何monitoringTraining:**

```bash
# View实时Log
tail -f artifacts/logs/training.log

# ViewTrainingParameterstatistics
cat artifacts/logs/training_metrics.json | python -m json.tool

# CheckGenerate of Checkpoint
ls -lah artifacts/checkpoints/lora_sft/
```

### 第 4 步: Merge LoRA adapter to baseModel

TrainingAfter completion,Merge LoRA adapter into base model,GenerateComplete of afterTrainingModel.

```bash
cd /home/shuwen/shuwen/train/neurx

# way 1: 直接RunMergescript
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_merge.s

# way 2: 通过 Makefile (如果haveConfiguration)
make posttrain-merge-lora

# way 3: 指定InputOutputPath
/home/shuwen/shuwen/train/s/bin/s_seed \
  posttrain/adapter/run_lora_merge.s \
  --base-model /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct \
  --adapter /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft \
  --output /home/shuwen/shuwen/train/model/base-model-posttrain
```

**Mergeprocess:**

```
1. Load base model weights
   └─ /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/model.safetensors
   
2. Load LoRA adapter weights
   └─ /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/adapter_model.safetensors
   
3. 应用 LoRA Merge公式
   └─ W_new = W_base + (α/r) × B × A
   └─ 对all目标layer应用Merge
   
4. saveComplete of MergeModel
   └─ /home/shuwen/shuwen/train/model/base-model-posttrain/

OutputFile:
  • model.safetensors           (CompleteMergeModel)
  • config.json                 (ModelConfiguration)
  • generation_config.json      (GenerateConfiguration)
  • tokenizer.json              (分词device)
  • tokenizer_config.json       (分词deviceConfiguration)
  • README.md                   (descriptiondocumentation)
```

**expectedOutput:**
- ✓ MergeCompleteConfirm
- ✓ OutputFileSize
- ✓ ModelVerificationInformation

### 第 5 步: Verify output

CheckGenerate of allOutputFile.

```bash
# Check LoRA adapterCheckpoint
ls -lah /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/
# expectedFile:
#   adapter_model.safetensors (LoRA weights)
#   adapter_config.json       (Configuration)

# CheckMergeafter of Model
ls -lah /home/shuwen/shuwen/train/model/base-model-posttrain/
# expectedFile:
#   model.safetensors
#   config.json
#   tokenizer.json
#   ...

# VerificationModelFileSize
du -sh /home/shuwen/shuwen/train/model/base-model-posttrain/*

# ViewTrainingLog
cat /home/shuwen/shuwen/train/neurx/artifacts/logs/training_log.txt
```

---

## 🔄 Complete一键Executeprocess

如果have经Configuration了 Makefile 规则,可以Usage一条commandExecuteCompleteprocess:

```bash
cd /home/shuwen/shuwen/train/neurx

# Verification + 显示Configuration
make posttrain-show-config

# LaunchCompleteTraining + Mergeprocess (after台Run)
make posttrain-complete

# 只MergeModel
make posttrain-merge-to-model

# Verify output
make posttrain-verify-output
```

---

## 📊 expected结果

### TrainingTime估算

| Phase | time | GPU 需求 |
|------|------|----------|
| LoRA SFT Training | 1-2 hours | 1x GPU (8GB+) |
| ModelMerge | 5-10 minutes | CPU 即可 |
| **总计** | **1-2.5 hours** | |

### OutputFile

| Path | File | description |
|------|------|------|
| `artifacts/checkpoints/lora_sft/` | `adapter_model.safetensors` | LoRA weights (~50-100MB) |
| | `adapter_config.json` | LoRA Configuration |
| | `training_state.json` | Trainingstatus |
| `artifacts/logs/` | `training_log.txt` | TrainingLog |
| | `training_metrics.json` | Training指标 |
| `model/base-model-posttrain/` | `model.safetensors` | MergeafterCompleteModel (~1.5GB) |
| | `config.json` | ModelConfiguration |
| | `tokenizer.json` | 分词device |

### ModelPerformance对比

| 指标 | baseModel | afterTrainingModel |
|------|---------|----------|
| ModelSize | ~1.5GB | ~1.5GB |
| inferenceSpeed | 基准 | ≈ 基准 |
| MedMCQA accuracy | X% | X+Y% |

---

## 🛠️ 故障排查

### question 1: "找Not to baseModel"
```
ErrorInformation: Base model not found at /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct
```

**resolve:**
```bash
# CheckModelFile
ls -la /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/

# 如果Not存 in ,download or 复制Model
# 确保package含: model.safetensors, config.json, tokenizer.json 等
```

### question 2: "DataFileNot存 in "
```
ErrorInformation: Training data file not found
```

**resolve:**
```bash
# CheckDataFile
ls -la /home/shuwen/shuwen/train/dataset/medmcqa/

# 确保package含: train.jsonl, val.jsonl
```

### question 3: "GPU MemoryNot足"
```
ErrorInformation: CUDA out of memory
```

**resolve:**
- 减小 batch_size: `batch_size: 16` (改为 8  or  16)
- Increasegradient累积: `gradient_accumulation_steps: 4`
- 减小 LoRA rank: `rank: 4` (改为 4)

### question 4: "S compiledeviceError"
```
ErrorInformation: s_seed: command not found
```

**resolve:**
```bash
# Check S compiledevicePath
ls -la /home/shuwen/shuwen/train/s/bin/s_seed

# 添加 to  PATH
export PATH="/home/shuwen/shuwen/train/s/bin:$PATH"
```

---

## 📚 相关documentation

- [NeurX frameworkIntroduction](../README.md)
- [LoRA adapterdocumentation](../adapter/README_PEFT.md)
- [SFT Trainingdocumentation](../sft/README_SFT.md)
- [S Language编程guide](../../s/README.md)

---

## ✨ Summary

通过本guide,您可以:

1. ✅ **VerificationConfiguration** - 确保allPath and Parameter正确
2. ✅ **LaunchTraining** - 对 Qwen Model进line LoRA SFT Fine-tuning
3. ✅ **MergeModel** - Will LoRA adapterintegration to baseModel
4. ✅ **Verify output** - 确保Generate of Model可用

**finalOutput:**
```
✨ afterTrainingComplete!
📁 Outputlocation: /home/shuwen/shuwen/train/model/base-model-posttrain/
🎯 ModelhaveReady好进line部署 and inference
```

---

## 🤝 获取帮助

如有question,请Check:
1. ConfigurationFile: `/home/shuwen/shuwen/train/neurx/configs/posttrain.yaml`
2. TrainingLog: `/home/shuwen/shuwen/train/neurx/artifacts/logs/training_log.txt`
3. 项目documentation: `../README.md`  and  `../IMPLEMENTATION_SUMMARY.md`

**最after修改:** 2026-07-21
**frameworkVersion:** NeurX
**supportLanguage:** S Language
