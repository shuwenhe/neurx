# 🚀 NeurX LLM English textmodeltrainingEnglish text

**English text**: 2026-07-01
**state**: ✅ completeEnglish text
**language**: S Language + Make

---

## 📋 Make English text

### English texttrainingEnglish text

```bash
# ===== English texttraining =====
make train              # runEnglish texttraining (run_training.sh)
make train-watch        # runtrainingEnglish textlog
make test               # run Transformer modeltest

# ===== LLM training =====
make train-llm          # run LLM training(recommended)
make train-llm-watch    # run LLM trainingEnglish textlog

# ===== English texttraining =====
make train-dp           # dataEnglish text (2 GPU DDP)
make train-dp-watch     # dataEnglish text + English textlog

# ===== inference =====
make infer              # runinference
make infer-watch        # runinferenceEnglish textlog
make infer-interactive  # English textinference (REPL)
```

---

## 🎯 quickstart (5 English text)

### English text: runEnglish text

```bash
cd /Users/feifei/shuwen/train/neurx

# English text 1: English texttrainingEnglish text
make train

# English text 2: LLM trainingEnglish text(recommended)
make train-llm

# English text 3: English textlog
make train-llm-watch
```

---

## 📊 LLM trainingEnglish text

### 1. **English text LLM training**

```bash
make train-llm
```

**English text**:
- usedefaultparameter
- 100 steptraining
- English text: 4
- English text: 8
- output: `artifacts/checkpoints/llm_training/`

### 2. **English textparametertraining**

```bash
# English texttrainingstepEnglish text 1000
make train-llm NEURX_TOTAL_STEPS=1000

# English text 32
make train-llm NEURX_BATCH_SIZE=32

# English text 2048
make train-llm NEURX_SEQ_LENGTH=2048

# English textlearning rate
make train-llm NEURX_LR=0.0005

# English textparameter
make train-llm \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_LR=0.0005 \
  NEURX_WARMUP_STEPS=100
```

### 3. **English textconfigurationEnglish text**

| English text | defaultEnglish text | English text | explanation |
|------|--------|------|------|
| `NEURX_TOTAL_STEPS` | 100 | 1-∞ | English texttrainingstepEnglish text |
| `NEURX_BATCH_SIZE` | 4 | 1-256 | English text |
| `NEURX_LR` | 0.001 | 0.00001-0.1 | learning rate |
| `NEURX_SEQ_LENGTH` | 8 | 1-8192 | English text |
| `NEURX_WARMUP_STEPS` | 10 | 0-1000 | English textstepEnglish text |
| `NEURX_CHECKPOINT_INTERVAL` | 10 | 1-∞ | checkpointEnglish text |

---

## 🔄 English texttrainingEnglish text

### English text GPU training

```bash
# defaultEnglish text GPU
make train-llm

# English text GPU
make train-llm NEURX_WORLD_SIZE=1
```

### English text GPU dataEnglish text (DDP)

```bash
# 2 GPU dataEnglish text
make train-dp

# 4 GPU dataEnglish text
make train-dp NEURX_WORLD_SIZE=4 NEURX_DATA_PARALLEL_SIZE=4

# 8 GPU dataEnglish text
make train-dp NEURX_WORLD_SIZE=8 NEURX_DATA_PARALLEL_SIZE=8
```

### advancedEnglish textconfiguration

```bash
# English text (Tensor Parallel) - 8 GPU English textweight
make train-llm \
  NEURX_WORLD_SIZE=8 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=1

# English text (Pipeline Parallel) - English textmodelEnglish text
make train-llm \
  NEURX_WORLD_SIZE=8 \
  NEURX_PIPELINE_PARALLEL_SIZE=4 \
  NEURX_DATA_PARALLEL_SIZE=2

# English text (DDP + Tensor Parallel)
make train-llm \
  NEURX_WORLD_SIZE=16 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_PIPELINE_PARALLEL_SIZE=1
```

---

## 🎓 trainingconfigurationexample

### English textmodelquicktraining

```bash
make train-llm \
  NEURX_TOTAL_STEPS=10 \
  NEURX_BATCH_SIZE=1 \
  NEURX_SEQ_LENGTH=8 \
  NEURX_LR=0.001
```

**configuration**:
- ⏱️ time: ~1-2 English text
- 💾 English text: ~1 GB
- 📊 parameter: ~1M

### English textmodeltraining

```bash
make train-llm \
  NEURX_TOTAL_STEPS=100 \
  NEURX_BATCH_SIZE=8 \
  NEURX_SEQ_LENGTH=512 \
  NEURX_LR=0.0005 \
  NEURX_WARMUP_STEPS=10
```

**configuration**:
- ⏱️ time: ~30-60 English text
- 💾 English text: ~8 GB (English text GPU)
- 📊 parameter: ~100M

### English textmodelcompletetraining

```bash
make train-dp \
  NEURX_WORLD_SIZE=4 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=16 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_LR=0.0001 \
  NEURX_WARMUP_STEPS=100 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

**configuration**:
- ⏱️ time: ~2-4 English text
- 💾 English text: ~30 GB (4× A100)
- 📊 parameter: ~1B
- 🚀 English text: ~50K tokens/sec

### Claude English texttraining (70B+)

```bash
make train-llm \
  NEURX_WORLD_SIZE=32 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_PIPELINE_PARALLEL_SIZE=2 \
  NEURX_TOTAL_STEPS=10000 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=8192 \
  NEURX_LR=0.00005 \
  NEURX_WARMUP_STEPS=500 \
  NEURX_MIXED_PRECISION_MODE=bf16 \
  NEURX_CHECKPOINT_INTERVAL=100
```

**configuration**:
- ⏱️ time: English text
- 💾 English text: ~1-2 TB (32× A100)
- 📊 parameter: 70B
- 🚀 English text: ~100K+ tokens/sec

---

## 💡 advancedconfigurationEnglish text

### English texttraining

```bash
# BF16 (recommended, English text)
make train-llm \
  NEURX_MIXED_PRECISION_MODE=bf16

# FP16 (English text)
make train-llm \
  NEURX_MIXED_PRECISION_MODE=fp16

# FP32 (English text)
make train-llm \
  NEURX_MIXED_PRECISION_MODE=fp32
```

### lossEnglish text

```bash
# default 1.0
make train-llm NEURX_LOSS_SCALE=1.0

# English text(recommended)
make train-llm NEURX_LOSS_SCALE=65536.0
```

### dataEnglish text

```bash
# English textmodelEnglish text (default)
make train-llm NEURX_DP_MODE=small

# English text
make train-llm NEURX_DP_MODE=standard

# English textmodelEnglish text
make train-llm NEURX_DP_MODE=large
```

---

## 🔍 monitoringEnglish text

### English texttraininglog

```bash
# English text
make train-llm-watch

# English textparameter + log
make train-llm-watch \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=32
```

### English textcompletelog

```bash
# English textlog
tail -f /tmp/neurx_llm_train.log

# English textcompletelog
cat /tmp/neurx_llm_train.log | less

# English textsearchEnglish text
tail -f /tmp/neurx_llm_train.log | grep "loss"
```

### checkpointEnglish text

```bash
# English textsaveEnglish textcheckpoint
ls -lh artifacts/checkpoints/llm_training/

# English text epoch English textcheckpoint
ls -lh artifacts/checkpoints/llm_training/epoch_*
```

---

## 📈 English textoptimizeEnglish text

### 1. English text

```bash
# English text + English text
make train-llm \
  NEURX_MIXED_PRECISION_MODE=bf16 \
  NEURX_BATCH_SIZE=32

# usedataEnglish text
make train-dp \
  NEURX_WORLD_SIZE=4 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_BATCH_SIZE=32
```

### 2. English textuse

```bash
# English textgradientcheckpoint + English text
make train-llm \
  NEURX_SEQ_LENGTH=512 \
  NEURX_BATCH_SIZE=8
```

### 3. English text

```bash
# English textstepEnglish text + English textlearning rate
make train-llm \
  NEURX_WARMUP_STEPS=100 \
  NEURX_LR=0.0001 \
  NEURX_TOTAL_STEPS=1000
```

### 4. English text GPU English textconfiguration

```bash
make train-dp \
  NEURX_WORLD_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TENSOR_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_MIXED_PRECISION_MODE=bf16
```

---

## 🎯 inferenceEnglish textgenerate

### English textinference

```bash
# English text GPU inference
make infer

# English textparameter
make infer \
  NEURX_BATCH_SIZE=1 \
  NEURX_SEQ_LENGTH=512
```

### English textinferencelog

```bash
make infer-watch
```

### English textinference (English text)

```bash
make infer-interactive

# English text REPL English textinputpromptEnglish text, AllowedEnglish text
# Prompt: Your LLM question here
# [Generated response]
# Prompt: Follow-up question
```

---

## 🔧 use Bash English textrun

### English text Make English text

```bash
# English text
export NEURX_TOTAL_STEPS=100
export NEURX_BATCH_SIZE=4
export NEURX_LR=0.001
export NEURX_SEQ_LENGTH=8

# English textrunEnglish text
bash scripts/legacy/run_llm_training_with_compiler.sh

# English textlog
tail -f /tmp/neurx_llm_train.log
```

### use NeurX compileEnglish texttraining

```bash
# compileEnglish textrun
neurx compile train_and_infer.s -o bin/train_and_infer --optimize=2
./bin/train_and_infer

# English textrun
neurx run train_and_infer.s

# English textusecompleteEnglish text
neurx run complete_pipeline.s
```

---

## 📊 English texttrainingEnglish text

### English text 1: quickEnglish text (5 English text)

```bash
make train-llm \
  NEURX_TOTAL_STEPS=10 \
  NEURX_BATCH_SIZE=1 \
  NEURX_SEQ_LENGTH=8
```

**English text**:
- time: ~3-5 English text
- English text: ~500 MB
- English textcompileEnglish texttrainingpipeline

### English text 2: modelEnglish text (30 English text)

```bash
make train-llm \
  NEURX_TOTAL_STEPS=100 \
  NEURX_BATCH_SIZE=4 \
  NEURX_SEQ_LENGTH=128
```

**English text**:
- time: ~20-30 English text
- English text: ~2 GB
- English textmodelEnglish text

### English text 3: English texttraining (2 English text)

```bash
make train-dp \
  NEURX_WORLD_SIZE=2 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TOTAL_STEPS=500 \
  NEURX_BATCH_SIZE=8 \
  NEURX_SEQ_LENGTH=512
```

**English text**:
- time: ~1-2 English text
- English text: ~10 GB (2× GPU)
- English text ~15ms

### English text 4: English texttraining (English text)

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

**English text**:
- time: 2-7 English text
- English text: 100+ GB
- English text: 50-100K tokens/sec

---

## ⚠️ English text

### English text 1: English text

**error**:
```
CUDA out of memory
```

**English text**:
```bash
# 1. English text
make train-llm NEURX_BATCH_SIZE=2

# 2. English text
make train-llm NEURX_SEQ_LENGTH=256

# 3. English text
make train-llm NEURX_MIXED_PRECISION_MODE=bf16

# 4. English textgradientcheckpoint(English textsupport)
make train-llm NEURX_BATCH_SIZE=1 NEURX_SEQ_LENGTH=256
```

### English text 2: trainingEnglish text

**English text**: English textuse GPU English text

**English text**:
```bash
# 1. English text GPU use
nvidia-smi

# 2. useEnglish text
make train-llm NEURX_BATCH_SIZE=32

# 3. English text
make train-llm NEURX_MIXED_PRECISION_MODE=bf16

# 4. useEnglish text GPU
make train-dp NEURX_WORLD_SIZE=4
```

### English text 3: lossEnglish text

**English text**: learning rate, dataEnglish textmodelEnglish text

**English text**:
```bash
# 1. English textstepEnglish text
make train-llm NEURX_WARMUP_STEPS=100

# 2. English textlearning rate
make train-llm NEURX_LR=0.00001

# 3. English textdata
# English text artifacts/checkpoints/llm_training/ English textdata

# 4. English textcheckpointrecover
# useEnglish textsaveEnglish textcheckpointEnglish texttraining
```

### English text 4: GPU English text

**English text**:
```bash
# 1. English text
make train-llm NEURX_BATCH_SIZE=64

# 2. English text
export OMP_NUM_THREADS=8

# 3. English text
make train-llm NEURX_MIXED_PRECISION_MODE=bf16

# 4. useEnglish text
make train-llm NEURX_SEQ_LENGTH=2048
```

---

## 📚 English textfileEnglish text

### English text

| file | explanation |
|------|------|
| `run_llm_training_with_compiler.sh` | LLM trainingmainEnglish text |
| `run_training.sh` | English texttrainingEnglish text |
| `run_full_inference.sh` | inferenceEnglish text |
| `train_and_infer.s` | S languagetrainingimplementation |
| `complete_pipeline.s` | completeEnglish text 8 phaseEnglish text |

### configurationfile

| file | explanation |
|------|------|
| `train_config.yaml` | trainingconfiguration |
| `neurx.config.example.toml` | exampleconfiguration |

### English text

| file | explanation |
|------|------|
| `QUICK_START.md` | quickstart |
| `TRAINING_GUIDE.md` | trainingEnglish text |
| `COMPLETE_PIPELINE_GUIDE.md` | English text |

---

## 🎓 English text

### English text Make English text

```bash
# English text Makefile English text
make help

# English text Makefile content
cat Makefile | head -100
```

### English texttrainingpipeline

```bash
# English textcompleteEnglish texttrainingEnglish text
cat scripts/legacy/run_llm_training_with_compiler.sh

# English text S languagetrainingEnglish text
cat train_and_infer.s

# English textcompleteEnglish text
cat complete_pipeline.s
```

### English texttrainingEnglish text

```bash
# English textlog
make train-llm NEURX_TOTAL_STEPS=10 -v

# English text
env | grep NEURX

# English textcompileoutput
bash -x scripts/legacy/run_llm_training_with_compiler.sh
```

---

## ✅ English text

English textstartEnglish texttrainingEnglish text:

- [ ] GPU English text
- [ ] CUDA English text NCCL English text
- [ ] neurx compileEnglish text
- [ ] English text (checkpoint)
- [ ] English text GPU English text (English text)
- [ ] English text (English texttraining)
- [ ] monitoringtoolEnglish text (nvidia-smi English text)

---

## 🚀 English text

### English text 3 English text

```bash
# 1. quicktest
make train-llm NEURX_TOTAL_STEPS=10

# 2. English texttraining
make train-llm

# 3. English text GPU training
make train-dp NEURX_WORLD_SIZE=4
```

### completeEnglish text

```bash
# 1. quickEnglish text
make train-llm NEURX_TOTAL_STEPS=10

# 2. modeltraining
make train-llm NEURX_TOTAL_STEPS=1000 NEURX_BATCH_SIZE=32

# 3. inferencetest
make infer

# 4. English text
make infer-interactive
```

---

**English text**: 2026-07-01
**English text**: NeurX Team
**state**: ✅ English text
