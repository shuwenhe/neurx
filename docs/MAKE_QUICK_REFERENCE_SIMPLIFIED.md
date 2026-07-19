# 🚀 NeurX English text - English text

**principle**: English text

---

## English text, English text

### **1. training**
```bash
make train
```

### **2. inference**
```bash
make infer
```

---

## English textconfiguration

### training
```bash
# quicktest (5 min)
make train NEURX_TOTAL_STEPS=10

# English texttraining (1-2 English text)
make train NEURX_TOTAL_STEPS=1000 NEURX_BATCH_SIZE=32

# English text (English text, English text GPU)
make train NEURX_TOTAL_STEPS=100000 NEURX_BATCH_SIZE=64 NEURX_WORLD_SIZE=8
```

### inference
```bash
# English text
make infer

# English text
make infer NEURX_TEMPERATURE=0.5 NEURX_MAX_TOKENS=256
```

---

## English text

| English text | training | inference | explanation |
|------|------|------|------|
| `NEURX_TOTAL_STEPS` | ✅ | - | trainingstepEnglish text |
| `NEURX_BATCH_SIZE` | ✅ | ✅ | English text |
| `NEURX_LR` | ✅ | - | learning rate |
| `NEURX_SEQ_LENGTH` | ✅ | - | English text |
| `NEURX_WORLD_SIZE` | ✅ | - | GPU English text |
| `NEURX_TEMPERATURE` | - | ✅ | English text |
| `NEURX_TOP_K` | - | ✅ | Top-K |
| `NEURX_TOP_P` | - | ✅ | Nucleus |
| `NEURX_MAX_TOKENS` | - | ✅ | English text |

---

## actualEnglish text

```bash
# English text 1: quickEnglish text
make train NEURX_TOTAL_STEPS=10

# English text 2: actualtrainingEnglish textmodel
make train NEURX_TOTAL_STEPS=1000 NEURX_BATCH_SIZE=32 NEURX_SEQ_LENGTH=512

# English text 3: English text GPU training
make train NEURX_WORLD_SIZE=4 NEURX_BATCH_SIZE=32 NEURX_TOTAL_STEPS=5000

# English text 4: runinference
make infer

# English text 5: English textinference
make infer NEURX_TEMPERATURE=0.3 NEURX_TOP_P=0.9 NEURX_MAX_TOKENS=512
```

---

## monitoring

```bash
# English texttrainingstate
make monitor

# English textlog
tail -f /tmp/neurx_llm_train.log

# English textcheckpoint
ls artifacts/checkpoints/
```

---

**English text** ✨
