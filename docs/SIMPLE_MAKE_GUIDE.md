# 🚀 NeurX English text - English text Make English text

**principle**: English text = English text

---

## 📋 English text

### 1. **make train** - training

```bash
make train
```

**English text**: runmodeltraining
**configuration**: English text

**English textconfiguration**:
```bash
# quicktest (5 English text)
make train NEURX_TOTAL_STEPS=10

# English texttraining (1-2 English text)
make train NEURX_TOTAL_STEPS=1000 NEURX_BATCH_SIZE=32

# English texttraining (English text)
make train NEURX_TOTAL_STEPS=100000 NEURX_BATCH_SIZE=64 NEURX_WORLD_SIZE=8
```

### 2. **make infer** - inference

```bash
make infer
```

**English text**: runmodelinference
**configuration**: English text

**English textconfiguration**:
```bash
# English textinference
make infer

# English textinference
make infer NEURX_TEMPERATURE=0.5 NEURX_MAX_TOKENS=256
```

---

## 🎯 quickuse

### trainingmodel

```bash
# stepEnglish text 1: English texttraining
make train NEURX_TOTAL_STEPS=100 NEURX_BATCH_SIZE=4

# stepEnglish text 2: English textlog
tail -f /tmp/neurx_llm_train.log

# stepEnglish text 3: English textcheckpoint
ls -lh artifacts/checkpoints/
```

### inference

```bash
# runinference
make infer

# English textinference
make infer-interactive
```

---

## 🎛️ English text

### trainingparameter

```
NEURX_TOTAL_STEPS         trainingstepEnglish text (default: 100)
NEURX_BATCH_SIZE          English text (default: 4)
NEURX_LR                  learning rate (default: 0.001)
NEURX_SEQ_LENGTH          English text (default: 8)
NEURX_WARMUP_STEPS        English textstepEnglish text (default: 10)
NEURX_WORLD_SIZE          GPU English text (default: 1)
NEURX_MIXED_PRECISION_MODE English text: bf16/fp16/fp32 (default: bf16)
```

### inferenceparameter

```
NEURX_TEMPERATURE         English text (default: 0.7)
NEURX_TOP_K              Top-K English text (default: 40)
NEURX_TOP_P              Nucleus English text (default: 0.9)
NEURX_MAX_TOKENS         English textgenerateEnglish text (default: 50)
```

---

## 💡 useexample

### English text 1: quickEnglish text (5 English text)
```bash
make train NEURX_TOTAL_STEPS=10
```

### English text 2: English text GPU training (2 English text)
```bash
make train \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=512
```

### English text 3: English text GPU training (1 English text)
```bash
make train \
  NEURX_WORLD_SIZE=4 \
  NEURX_BATCH_SIZE=32 \
  NEURX_TOTAL_STEPS=1000
```

### English text 4: English textinference
```bash
make infer \
  NEURX_TEMPERATURE=0.5 \
  NEURX_TOP_P=0.95 \
  NEURX_MAX_TOKENS=512
```

---

## ✅ English text

**training**:
```bash
make train NEURX_TOTAL_STEPS=1000
```

**inference**:
```bash
make infer
```

**English text!** 🎉

---

**English text**: 2026-07-01
**English text**: Keep It Simple, Stupid (KISS)
