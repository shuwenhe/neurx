# 🚀 NeurX Make English text

**quickEnglish text** | English text

---

## 📋 English text

### trainingEnglish text
```bash
make train              # English texttraining
make train-llm          # LLM training ⭐ recommended
make train-llm-watch    # LLM training + log
make train-dp           # 2 GPU dataEnglish text
make train-dp-watch     # 2 GPU + log
make train-small        # English textmodeltraining
```

### inferenceEnglish text
```bash
make infer              # runinference
make infer-watch        # inference + log
make infer-interactive  # English textinference(English text)
```

### testEnglish text
```bash
make test               # Transformer English texttest
make test-transformer-e2e  # English texttest
```

---

## ⚡ quickexample

### English textstart (1 English text)
```bash
make train-llm NEURX_TOTAL_STEPS=10
```

### English texttraining (30 English text)
```bash
make train-llm \
  NEURX_TOTAL_STEPS=100 \
  NEURX_BATCH_SIZE=8 \
  NEURX_SEQ_LENGTH=512
```

### English text GPU training (2+ English text)
```bash
make train-dp \
  NEURX_WORLD_SIZE=4 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=16
```

---

## 🎛️ English textconfiguration

| English text | default | exampleEnglish text |
|------|------|--------|
| `NEURX_TOTAL_STEPS` | 100 | `NEURX_TOTAL_STEPS=1000` |
| `NEURX_BATCH_SIZE` | 4 | `NEURX_BATCH_SIZE=32` |
| `NEURX_LR` | 0.001 | `NEURX_LR=0.0005` |
| `NEURX_SEQ_LENGTH` | 8 | `NEURX_SEQ_LENGTH=2048` |
| `NEURX_WARMUP_STEPS` | 10 | `NEURX_WARMUP_STEPS=100` |
| `NEURX_CHECKPOINT_INTERVAL` | 10 | `NEURX_CHECKPOINT_INTERVAL=50` |
| `NEURX_WORLD_SIZE` | 1 | `NEURX_WORLD_SIZE=8` |
| `NEURX_DATA_PARALLEL_SIZE` | 1 | `NEURX_DATA_PARALLEL_SIZE=4` |
| `NEURX_TENSOR_PARALLEL_SIZE` | 1 | `NEURX_TENSOR_PARALLEL_SIZE=2` |
| `NEURX_MIXED_PRECISION_MODE` | bf16 | `NEURX_MIXED_PRECISION_MODE=fp16` |

---

## 🔥 English text

### English text 1: quicktest(5 English text)
```bash
make train-llm NEURX_TOTAL_STEPS=10
```

### English text 2: English textmodel(30 English text)
```bash
make train-llm \
  NEURX_TOTAL_STEPS=100 \
  NEURX_BATCH_SIZE=4
```

### English text 3: English text GPU completetraining(2-4 English text)
```bash
make train-llm \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=16 \
  NEURX_SEQ_LENGTH=512 \
  NEURX_LR=0.0001 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

### English text 4: English text GPU training(English text)
```bash
make train-dp \
  NEURX_WORLD_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TENSOR_PARALLEL_SIZE=2 \
  NEURX_TOTAL_STEPS=10000 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

### English text 5: English text(English textmodel)
```bash
make train-llm \
  NEURX_WORLD_SIZE=8 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_BATCH_SIZE=16 \
  NEURX_SEQ_LENGTH=4096
```

---

## 📊 recommendedconfigurationEnglish text

### English textmodel(< 100M)
```bash
make train-llm \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=512 \
  NEURX_LR=0.001
```

### English textmodel(100M - 1B)
```bash
make train-dp \
  NEURX_WORLD_SIZE=2 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=16 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_LR=0.0005 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

### English textmodel(1B - 10B)
```bash
make train-dp \
  NEURX_WORLD_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TENSOR_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=4096 \
  NEURX_LR=0.0001 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

### Claude English text(70B+)
```bash
make train-llm \
  NEURX_WORLD_SIZE=32 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_PIPELINE_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=8192 \
  NEURX_LR=0.00005 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

---

## 📂 outputEnglish text

| English text | English text | explanation |
|------|------|------|
| checkpoint | `artifacts/checkpoints/llm_training/` | modelweight |
| log | `/tmp/neurx_llm_train.log` | traininglog |
| output | `artifacts/checkpoints/llm_s_pretrain/` | English texttrainingoutput |

---

## 🔧 English text

### English text: "make: command not found"
```bash
# English text make
apt-get install make      # Linux
brew install make         # macOS
```

### English text: English text
```bash
# English text
make train-llm NEURX_BATCH_SIZE=2 NEURX_SEQ_LENGTH=256
```

### English text: GPU English text
```bash
# English text GPU
nvidia-smi

# English text CUDA
nvcc --version
```

### English text: trainingEnglish text
```bash
# English text
make train-llm NEURX_MIXED_PRECISION_MODE=bf16

# English text
make train-llm NEURX_BATCH_SIZE=64
```

---

## 💡 English text

| optimize | English text | English text |
|------|------|------|
| English text | `NEURX_MIXED_PRECISION_MODE=bf16` | 🚀 2× quick |
| English text | `NEURX_BATCH_SIZE=64` | 📈 English text |
| English text GPU | `make train-dp` | ⚡ English textextension |
| English text | `NEURX_SEQ_LENGTH=2048` | 📊 English text |
| English textlearning rate | `NEURX_LR=0.0001` | 🎯 English text |

---

## 📖 English text

- **completeEnglish text**: [NEURX_LLM_TRAINING_GUIDE.md](NEURX_LLM_TRAINING_GUIDE.md)
- **quickstart**: [QUICK_START.md](QUICK_START.md)
- **trainingEnglish text**: [TRAINING_GUIDE.md](TRAINING_GUIDE.md)
- **English textexplanation**: [COMPLETE_PIPELINE_GUIDE.md](COMPLETE_PIPELINE_GUIDE.md)

---

## 🎯 English text

```bash
make help                   # English text
make install                # English text NeurX
make clean                  # English text
make neurx                  # compile NeurX framework
make code-agent             # runEnglish text
```

---

## ✅ English text

starttrainingEnglish text:

- [ ] `nvidia-smi` English text GPU
- [ ] `neurx --version` English text
- [ ] `make help` English text
- [ ] English text
- [ ] English text

---

## 🚀 English textstart

```bash
# 1. English text
make help

# 2. runquicktest
make train-llm NEURX_TOTAL_STEPS=10

# 3. English textlog
tail -f /tmp/neurx_llm_train.log

# 4. completetraining
make train-llm NEURX_TOTAL_STEPS=1000
```

---

**state**: ✅ completeEnglish text
**English text**: 2026-07-01
