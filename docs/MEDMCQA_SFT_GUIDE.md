# 用 MedMCQA DatasetafterTraining Qwen2.5-0.5B-Instruct  of Completeguide

## 📚 DatasetInformation

- **Data来源**: `/home/shuwen/shuwen/train/dataset/medmcqa/train.json`
- **总Data量**: 182,822 medical多选题
- **Format**: JSONL (每line一  JSON object)
- **Data字段**:
  - `question`: Medical question
  - `opa`, `opb`, `opc`, `opd`: 四 option
  - `cop`: 正确答案index (0-3)
  - `exp`: 详细解释
  - `subject_name`: medical学科
  - `topic_name`: 话题

## 🚀 Quick Start (3步)

### 1️⃣ ConvertDataset to  SFT Format

```bash
cd /home/shuwen/shuwen/train/neurx

# RunConvertscript
bash scripts/convert_medmcqa.sh

#  or settingcustomPath
export MEDMCQA_INPUT=/path/to/train.json
export MEDMCQA_OUTPUT_DIR=/path/to/output
bash scripts/convert_medmcqa.sh
```

**Output**:
```
/home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/
├── train.jsonl    (173,680 examples, 95%)
└── val.jsonl      (9,142 examples, 5%)
```

### 2️⃣ Update Makefile Configuration

Edit `/home/shuwen/shuwen/train/neurx/Makefile`,修改第 107 line:

```makefile
# 旧Configuration
POSTTRAIN_DATA_FILE ?= $(CURDIR_UNIX)/dataset/posttrain/instruction_data.jsonl

# 新Configuration(Usage MedMCQA Data)
POSTTRAIN_DATA_FILE ?= $(CURDIR_UNIX)/dataset/medmcqa_sft/train.jsonl
```

### 3️⃣ LaunchafterTraining

```bash
cd /home/shuwen/shuwen/train/neurx

# Run SFT Training
make posttrain

#  or 者ViewLog
tail -f artifacts/logs/posttrain_*.log
```

## 📊 expected结果

| Phase | Time | Output |
|------|------|------|
| **DataConvert** | ~5minutes | `dataset/medmcqa_sft/` |
| **SFT Training** | ~2-4hours | `artifacts/checkpoints/lora_sft/` |
| **ModelMerge** | ~10minutes | `/home/shuwen/shuwen/train/model/base-model-posttrain/` |

## 🔧 customConfiguration

### 调整超Parameter

Edit Makefile in of :

```makefile
POSTTRAIN_LORA_ALPHA ?= 16      # LoRA alpha
POSTTRAIN_LORA_RANK ?= 8        # LoRA rank
```

### 修改TrainingData量

```bash
# 只Usage前 5000 条DataTest
head -5000 dataset/medmcqa_sft/train.jsonl > dataset/medmcqa_sft/train_mini.jsonl
export POSTTRAIN_DATA_FILE=$(pwd)/dataset/medmcqa_sft/train_mini.jsonl
make posttrain
```

### 仅VerificationDataConvert

```bash
# ViewConvertafter of DataFormat
head -3 /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/train.jsonl | \
  python3 -m json.tool

# statisticsDatasetSize
echo "Train examples:" && wc -l dataset/medmcqa_sft/train.jsonl
echo "Val examples:" && wc -l dataset/medmcqa_sft/val.jsonl
```

## 📈 monitoringTraining进度

```bash
# ViewTrainingLog
tail -f artifacts/logs/posttrain_*.log

# monitoringCheckpoint
watch -n 10 'ls -lh artifacts/checkpoints/lora_sft/ | tail -5'

# monitoringfinalModel
watch -n 5 'ls -lh /home/shuwen/shuwen/train/model/base-model-posttrain/'
```

## ✅ Complete工作流script

```bash
#!/bin/bash
set -e

cd /home/shuwen/shuwen/train/neurx

echo "Step 1: Converting MedMCQA dataset..."
bash scripts/convert_medmcqa.sh

echo ""
echo "Step 2: Starting SFT training..."
make posttrain

echo ""
echo "✅ Training complete!"
echo "Model saved to: /home/shuwen/shuwen/train/model/base-model-posttrain/"
```

## 🐛 FAQ

### question1: DataConvertFailed
```bash
# CheckInputFile
ls -lh /home/shuwen/shuwen/train/dataset/medmcqa/train.json

# VerificationFormat
head -1 /home/shuwen/shuwen/train/dataset/medmcqa/train.json | python3 -m json.tool
```

### question2: Training报错 "DataFileNot存 in "
```bash
# ConfirmOutputDirectory存 in 
ls -lh /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/

# 重新ConvertData
rm -rf /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/
bash scripts/convert_medmcqa.sh
```

### question3: GPU 显存Not足
```bash
# 减少 batch size ( in  Makefile in)
#  or 减少TrainingData量
head -50000 dataset/medmcqa_sft/train.jsonl > dataset/medmcqa_sft/train_reduced.jsonl
```

## 📝 DataFormat对应关系

```
MedMCQA OriginalFormat:
{
  "question": "question文本",
  "opa": "optionA",
  "opb": "optionB",
  "opc": "optionC",
  "opd": "optionD",
  "cop": 0,              // 正确答案(0-3)
  "exp": "解释文本",
  "subject_name": "学科"
}

↓ Convertafter ↓

SFT Format:
{
  "instruction": "Answer the following medical multiple-choice question accurately.",
  "input": "question\n\nOptions:\nA) optionA\nB) optionB\nC) optionC\nD) optionD",
  "output": "Answer: A\n\nExplanation: 解释文本\n\nSubject: 学科"
}
```

## 🔄 after续Step(Optional)

TrainingAfter completion,你可以继续:

1. **DPO Alignment** (Step 2)
   ```bash
   cd /home/shuwen/shuwen/train/medical/Post_train/step2_DPO
   bash lora.sh
   ```

2. **GRPO Optimize** (Step 3)
   - need独立 of 奖励Model
   - Usage vLLM 进line回滚Generate

3. **Model评测**
   ```bash
   cd /home/shuwen/shuwen/train/neurx
   make eval-medical
   ```

## 📚 相关documentation

- NeurX SFT framework: `posttrain/sft/README_SFT.md`
- MedMCQA 详细description: `posttrain/adapter/README_PEFT.md`
- medical评测framework: `eval/README_MEDICAL_EVAL.md`
- afterTrainingCompleteguide: `posttrain/MEDICAL_INTEGRATION_GUIDE.md`

---

**StartTraining**:
```bash
cd /home/shuwen/shuwen/train/neurx && bash scripts/convert_medmcqa.sh && make posttrain
```
