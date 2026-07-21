# 🚀 NeurX MedMCQA afterTraining快速Reference

## 📋 快速command

### 一lineLaunchafterTraining
```bash
cd /home/shuwen/shuwen/train/neurx && make posttrain
```

### MergeModel
```bash
cd /home/shuwen/shuwen/train/neurx && make posttrain-merge-lora
```

### TestModel
```bash
cd /home/shuwen/shuwen/train/neurx && make chat
```

---

## 📊 Completeprocess

```
Step 1: afterTraining (2-4 hours)
  $ cd /home/shuwen/shuwen/train/neurx
  $ make posttrain
  └─ Output: artifacts/checkpoints/lora_adapter/

Step 2: ModelMerge (5-10 minutes)  
  $ make posttrain-merge-lora
  └─ Output: ../model/base-model-posttrain/

Step 3: 交互Test
  $ make chat
  └─ Launch聊天会话,TestModel
```

---

## 📁 keyPath

| 用途 | Path |
|------|------|
| **Dataset** | `/home/shuwen/shuwen/train/dataset/medmcqa/` |
| TrainingData | `train.jsonl` (173,680 条) |
| VerificationData | `val.jsonl` (9,142 条) |
| **baseModel** | `/home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/` |
| **LoRA adapter** | `/home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_adapter/` |
| **MergeafterModel** | `/home/shuwen/shuwen/train/model/base-model-posttrain/` |
| **Log** | `/home/shuwen/shuwen/train/neurx/artifacts/logs/posttrain_*.log` |

---

## 🔍 monitoringmethod

### View实时Log
```bash
tail -f /home/shuwen/shuwen/train/neurx/artifacts/logs/posttrain_*.log
```

### monitoringCheckpoint
```bash
watch -n 10 'ls -lh /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_*/'
```

### Check GPU Usage
```bash
nvidia-smi
```

---

## 🎯 ConfigurationInformation

```bash
# Makefile Configuration
POSTTRAIN_MODEL_PATH = /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct
POSTTRAIN_DATA_FILE = /home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl
POSTTRAIN_LORA_ALPHA = 16
POSTTRAIN_LORA_RANK = 8
```

---

## ✅ Verification清单

- [x] Dataset存 in :`/home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl` (136MB)
- [x] baseModel存 in :`/home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/`
- [x] Makefile Configuration正确
- [x] NeurX frameworkhaveinitialize

---

## 🆘 FAQ

### Q1: afterTraining卡住
```bash
# ViewLog
tail -f artifacts/logs/posttrain_*.log

# Check GPU
nvidia-smi
```

### Q2: MergeFailed
```bash
# CheckInputFile
ls -lh artifacts/checkpoints/lora_adapter/
ls -lh ../model/Qwen2.5-0.5B-Instruct/
```

### Q3: Model对话无Response
```bash
# ConfirmMergeModel存 in 
ls -lh ../model/base-model-posttrain/
```

---

## 📈 expected结果

| 指标 | 值 |
|------|-----|
| TrainingData | 173,680 条 |
| afterTrainingtime | 2-4 hours |
| LoRA adapterSize | ~100-200MB |
| MergeafterModelSize | ~500MB-1GB |
| Mergetime | 5-10 minutes |

---

## 🔧 custom超Parameter

Edit `Makefile` 修改:

```makefile
# LoRA Configuration
POSTTRAIN_LORA_ALPHA ?= 16    # 增大提高表现力
POSTTRAIN_LORA_RANK ?= 8      # 增大提高表现力

# TrainingConfiguration( in  posttrain 子DirectoryConfigurationFilein)
batch_size = 4
learning_rate = 5e-4
num_epochs = 3
```

---

## 📝 CompleteExecuteprocessscript

```bash
#!/bin/bash
cd /home/shuwen/shuwen/train/neurx

echo "Step 1: afterTraining..."
make posttrain || exit 1

echo "Step 2: MergeModel..."
make posttrain-merge-lora || exit 1

echo "Step 3: TestModel..."
make chat

echo "✅ Complete!"
```

---

**Quick Start**: 复制以下command直接Execute
```bash
cd /home/shuwen/shuwen/train/neurx && make posttrain && make posttrain-merge-lora && make chat
```
