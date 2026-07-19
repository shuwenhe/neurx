# 🚀 NeurX Make English text - quickEnglish text

**English text, English text** - English text

---

## English textstart (2 step)

```bash
# 1️⃣  English textdirectory
cd /Users/feifei/shuwen/train/neurx

# 2️⃣  runEnglish text
make train          # training
make infer          # inference
```

---

## 🚀 trainingEnglish text

### English texttraining
| English text | time | GPU | English text |
|------|------|-----|------|
| `make train-llm` | English text | 1× | English text GPU training |
| `make train-dp` | English text | 2-4× | dataEnglish text |
| `make train-large` | 1-2 English text | 8× | English text |
| `make train-xlarge` | 1-4 English text | 32× | English text |

### English text
| English text | GPU | model | explanation |
|------|-----|------|------|
| `make train-tensor` | 8-16× | 20B-70B | weightEnglish text |
| `make train-pipeline` | 16× | 70B-175B | English text |
| `make train-dist` | 32+ | English text | English text |

---

## 🔮 inferenceEnglish text

| English text | English text | explanation |
|------|------|------|
| `make infer-interactive` | 💬 English text | English text REPL |
| `make infer-batch` | 📊 English text | English textfileEnglish textprompt |
| `make infer-stream` | ⚡ English text | English textgenerate |
| `make infer-serving` | 🌐 English text | English textinference API |

---

## 🎛️ English text

### training
```
NEURX_TOTAL_STEPS=1000         # stepEnglish text
NEURX_BATCH_SIZE=32            # English text
NEURX_LR=0.00005               # learning rate
NEURX_SEQ_LENGTH=2048          # English text
NEURX_WORLD_SIZE=8             # GPU English text
NEURX_MIXED_PRECISION_MODE=bf16 # bf16/fp16/fp32
```

### inference
```
NEURX_TEMPERATURE=0.7          # English text
NEURX_TOP_K=40                 # Top-K
NEURX_TOP_P=0.9                # Nucleus
NEURX_MAX_TOKENS=256           # English text
NEURX_BATCH_SIZE=32            # English text
```

### English text
```
NEURX_WORLD_SIZE=8             # English text GPU
NEURX_DATA_PARALLEL_SIZE=4     # dataEnglish text
NEURX_TENSOR_PARALLEL_SIZE=2   # English text
NEURX_PIPELINE_PARALLEL_SIZE=1 # English text
```

---

## 💡 English text

### quickEnglish text (5 English text)
```bash
make train-llm NEURX_TOTAL_STEPS=10
```

### English text GPU completetraining (2-4 English text)
```bash
make train-llm \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=32 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

### 4 GPU DDP (1-2 English text)
```bash
make train-dp \
  NEURX_WORLD_SIZE=4 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_BATCH_SIZE=32
```

### 8 GPU English text (1-2 English text)
```bash
make train-large \
  NEURX_WORLD_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TENSOR_PARALLEL_SIZE=2
```

### 32 GPU English text (1-4 English text)
```bash
make train-xlarge
```

### English textinference
```bash
make infer-batch \
  NEURX_TEMPERATURE=0.5 \
  NEURX_TOP_P=0.95 \
  NEURX_MAX_TOKENS=512
```

---

## ⚠️ English text

| English text | English text |
|------|------|
| English text | ↓ English text, ↓ English text, English text BF16 |
| trainingEnglish text | ↑ English text, English text BF16, ↑ GPU English text |
| English text GPU | English text `nvidia-smi`, English text CUDA English text |
| logEnglish text | runEnglish text `/tmp/neurx*.log` |
| checkpointEnglish text | English text `artifacts/checkpoints/llm_training/` |

---

## 📊 English text

### English text GPU (A100-40GB)
- **1B parameter**: 50ms/step = 6K tokens/sec
- **7B parameter**: 100ms/step = 12K tokens/sec

### English text GPU (4× A100)
- **DDP 4×**: 4ms/step = 8K tokens/sec (93% English text)
- **Tensor TP 4×**: 30ms/step = 25K tokens/sec (90% English text)

---

## 🔍 monitoring

```bash
# English textstate
make monitor

# English textlog(English textrun)
make train-llm-watch

# English textlog
tail -f /tmp/neurx_llm_train.log

# English textcheckpoint
ls artifacts/checkpoints/llm_training/
```

---

## 🧹 English text

```bash
# English textlog
make clean-logs

# English text
make clean
```

---

## 📚 completeEnglish text

- **quickEnglish text**: [MAKE_COMMANDS_CHEATSHEET.md](MAKE_COMMANDS_CHEATSHEET.md)
- **English text**: [LARGE_MODEL_MAKE_GUIDE.md](LARGE_MODEL_MAKE_GUIDE.md)
- **English text**: `bash make_launcher.sh`

---

## 🎯 English text

| English text... | English text |
|---------|------|
| quicktest | `make train-llm NEURX_TOTAL_STEPS=10` |
| English text GPU training | `make train-llm NEURX_TOTAL_STEPS=1000` |
| English text GPU training | `make train-dp NEURX_WORLD_SIZE=4` |
| English textmodeltraining | `make train-large` |
| English text | `make infer-interactive` |
| English textinference | `make infer-batch` |
| API English text | `make infer-serving` |
| monitoringtraining | `make monitor` |
| English text | `make train-help` |

---

## 🚀 English textstart

```bash
# 1. English textdirectory
cd /Users/feifei/shuwen/train/neurx

# 2. quicktest
make train-llm NEURX_TOTAL_STEPS=10

# 3. completeEnglish text
bash make_launcher.sh
```

---

**English text**: 2026-07-01
**English text**: v1.0
**state**: ✅ English text
