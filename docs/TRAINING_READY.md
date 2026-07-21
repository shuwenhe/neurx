# ✅ MedMCQA SFT TrainingCompleteReady

## 📋 Current status

- ✅ DatasetConvertComplete:182,822  Medical question
  - Trainingset:173,680 条 (95%)
  - Verificationset:9,142 条 (5%)
  - Format:JSONL (指令-Input-Output)
  - Size:136MB Training + 7.2MB Verification

- ✅ NeurX frameworkConfigurationComplete
  - baseModel:Qwen2.5-0.5B-Instruct
  - DataFile:`neurx/dataset/medmcqa_sft/train.jsonl`
  - LoRA Configuration:rank=8, alpha=16

- ✅ allscriptReady
  - DataConvert:`scripts/convert_medmcqa.sh`
  - CompleteTraining:`scripts/train_medmcqa_sft.sh`

## 🚀 立即StartTraining

### way 1:一linecommand(Recommendation)

```bash
cd /home/shuwen/shuwen/train/neurx && bash scripts/train_medmcqa_sft.sh
```

### way 2:分stepExecute

```bash
# 1. Only convertData
cd /home/shuwen/shuwen/train/neurx
bash scripts/convert_medmcqa.sh

# 2. RunTraining
make posttrain

# 3. Merge LoRA adapter
make posttrain-merge-lora
```

### way 3:试Run(NotactualTraining)

```bash
bash scripts/train_medmcqa_sft.sh --dry-run
```

## 📊 expectedOutput

| Phase | Time | Outputlocation |
|------|------|---------|
| SFT Training | 2-4 hours | `artifacts/checkpoints/lora_sft/` |
| ModelMerge | 10 minutes | `../model/base-model-posttrain/` |

## 🔍 VerificationDataExample

```bash
# View第一条TrainingData
head -1 /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/train.jsonl | python3 -m json.tool

# statisticsData量
echo "Train:" && wc -l /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/train.jsonl
echo "Val:" && wc -l /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/val.jsonl
```

## 💾 Key fileslocation

```
/home/shuwen/shuwen/train/
├── dataset/
│   └── medmcqa/
│       └── train.json                    [OriginalData]
├── neurx/
│   ├── dataset/
│   │   └── medmcqa_sft/
│   │       ├── train.jsonl               [✓ haveGenerate]
│   │       └── val.jsonl                 [✓ haveGenerate]
│   ├── scripts/
│   │   ├── convert_medmcqa.sh            [Convertscript]
│   │   └── train_medmcqa_sft.sh          [Trainingscript]
│   ├── artifacts/
│   │   ├── checkpoints/
│   │   │   ├── lora_sft/                 [SFT adapter]
│   │   │   └── lora_adapter/             [finaladapter]
│   │   └── logs/
│   └── Makefile                          [haveUpdate]
└── model/
    ├── Qwen2.5-0.5B-Instruct/            [baseModel]
    └── base-model-posttrain/             [Mergeafter of Model]
```

## 🎯 next step

### 立即Execute(2-4 hours)
```bash
cd /home/shuwen/shuwen/train/neurx && bash scripts/train_medmcqa_sft.sh
```

### 然after评测
```bash
cd /home/shuwen/shuwen/train/neurx
make eval-medical
```

### Optional:continueAlignment
```bash
# DPO Alignment(第2Phase)
cd /home/shuwen/shuwen/train/medical/Post_train/step2_DPO
bash lora.sh

# GRPO Optimize(第3Phase)
cd /home/shuwen/shuwen/train/medical/Post_train/step3_GRPO
bash lora.sh
```

## 📝 DataConvert详情

### InputFormat(MedMCQA)

```json
{
  "question": "Chronic urethral obstruction due to benign prismatic hyperplasia...",
  "opa": "Hyperplasia",
  "opb": "Hyperophy",
  "opc": "Atrophy",
  "opd": "Dyplasia",
  "cop": 3,
  "exp": "Chronic urethral obstruction because of urinary calculi...",
  "subject_name": "Anatomy",
  "topic_name": "Urinary tract"
}
```

### OutputFormat(SFT)

```json
{
  "instruction": "Answer the following medical multiple-choice question accurately.",
  "input": "Chronic urethral obstruction...\n\nOptions:\nA) Hyperplasia\nB) Hyperophy\nC) Atrophy\nD) Dyplasia",
  "output": "Answer: D\n\nExplanation: Chronic urethral obstruction because of urinary calculi...\n\nSubject: Anatomy | Topic: Urinary tract"
}
```

## ⚙️ customConfiguration

Edit `Makefile` in of Parameter:

```makefile
# 改变 LoRA Size
POSTTRAIN_LORA_RANK ?= 8        # 增大 to  16 以提高table现力

# 改变批Size( in ConfigurationFilein)
# vim posttrain/sft/config.json  
```

## 🐛 故障排查

### question:找Not to Model
```bash
ls -lh /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/
```

### question:找Not to Data
```bash
ls -lh /home/shuwen/shuwen/train/neurx/dataset/medmcqa_sft/
```

### question:Training卡住
```bash
# ViewLog
tail -f /home/shuwen/shuwen/train/neurx/artifacts/logs/posttrain_*.log

# Check GPU
nvidia-smi
```

---

**最after一step**:Execute以下commandStartTraining!
