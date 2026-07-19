# 🚀 NeurX Make English text - English textmodeltrainingEnglish textinference

**English text**: 2026-07-01
**English text**: v1.0
**state**: ✅ English text

---

## 📋 quickEnglish text

### English text 5 English text

```bash
# 1. quicktest (5 English text)
make train-llm NEURX_TOTAL_STEPS=10

# 2. English textmodeltraining (1-2 English text, 8 GPU)
make train-large

# 3. English textmodeltraining (70B+, 1-4 English text, 32 GPU)
make train-xlarge

# 4. English textinference
make infer-interactive

# 5. English textinference
make infer-batch
```

---

## 🎯 trainingEnglish text

### English texttrainingEnglish text (English text)

```bash
make train              # English texttraining (run_training.sh)
make train-watch        # English texttraining + English textlog
make train-llm          # LLM training (recommendedEnglish text)
make train-llm-watch    # LLM training + English textlog
make train-dp           # 2 GPU dataEnglish text
make train-dp-watch     # dataEnglish text + English textlog
make train-small        # English textmodeltraining
```

### English text: English texttrainingEnglish text

| English text | English text | GPU | time | English text |
|------|------|-----|------|------|
| `make train-large` | 7B-13B | 8× | 1-2 English text | English texttraining |
| `make train-large-watch` | 7B-13B | 8× | 1-2 English text | + English textlog |
| `make train-xlarge` | 70B+ | 32× | 1-4 English text | Claude English texttraining |
| `make train-xlarge-watch` | 70B+ | 32× | 1-4 English text | + English textlog |

### English text: English texttrainingEnglish text

| English text | English text | GPU | modelEnglish text | explanation |
|------|---------|-----|---------|------|
| `make train-tensor` | English text | 8-16× | 20B-70B | weightEnglish text |
| `make train-tensor-watch` | English text | 8-16× | 20B-70B | + English textlog |
| `make train-pipeline` | English text | 16× | 70B-175B | English text |
| `make train-pipeline-watch` | English text | 16× | 70B-175B | + English textlog |

### English text: English texttrainingEnglish text

```bash
make train-dist         # English texttraining
make train-dist-watch   # English text + English textlog
```

---

## 🔮 inferenceEnglish text

### English textinferenceEnglish text

```bash
make infer              # English textinference
make infer-watch        # inference + English textlog
make infer-interactive  # English text REPL (English text)
```

### English textinferenceEnglish text

| English text | English text | English text | English text |
|------|------|------|------|
| `make infer-batch` | English textinference | English textpromptEnglish text | English text |
| `make infer-batch-watch` | English text + log | English text + monitoring | English text |
| `make infer-stream` | English textinference | English textgenerate | English text |
| `make infer-serving` | English text | English textinferenceEnglish text | 7×24 run |

---

## 🎓 English textuseEnglish text

### English text 1: quickEnglish text (5 English text)

```bash
cd /Users/feifei/shuwen/train/neurx

# English text 1 GPU, run 10 step
make train-llm NEURX_TOTAL_STEPS=10

# English textlog
tail -f /tmp/neurx_llm_train.log
```

### English text 2: English text GPU completemodeltraining (2-4 English text)

```bash
# 1000 step, English text 32, English text BF16 English text
make train-llm \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=512 \
  NEURX_LR=0.0001 \
  NEURX_MIXED_PRECISION_MODE=bf16

# English textlog
make train-llm-watch \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=32
```

### English text 3: English textmodel (8 GPU DDP)

```bash
# dataEnglish texttraining, 8 English text GPU
make train-dp \
  NEURX_WORLD_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=8 \
  NEURX_TOTAL_STEPS=5000 \
  NEURX_BATCH_SIZE=32

# English textuseEnglish textconfigurationEnglish text make train-large
make train-large

# English textmonitoring
make train-large-watch
```

### English text 4: English textmodel (8 GPU, English text)

```bash
# configuration: 4 dataEnglish text × 2 English text
make train-large \
  NEURX_WORLD_SIZE=8 \
  NEURX_DATA_PARALLEL_SIZE=4 \
  NEURX_TENSOR_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=4096
```

### English text 5: Claude English textmodel (32 GPU, English text)

```bash
# English textconfiguration Claude English text(70B+)
make train-xlarge

# English textconfiguration
make train-xlarge \
  NEURX_WORLD_SIZE=32 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_PIPELINE_PARALLEL_SIZE=2 \
  NEURX_BATCH_SIZE=32 \
  NEURX_SEQ_LENGTH=8192 \
  NEURX_TOTAL_STEPS=100000
```

### English text 6: English texttraining

```bash
# 4 English text, English text 8 English text GPU(English text 32 English text)
make train-dist \
  NEURX_NUM_NODES=4 \
  NEURX_WORLD_SIZE=32 \
  NEURX_MASTER_ADDR=192.168.1.100 \
  NEURX_MASTER_PORT=29500

# English textmonitoring
make train-dist-watch
```

### English text 7: English textinference (English text)

```bash
# start REPL, supportEnglish text
make infer-interactive

# inputpromptEnglish text, English text, English text
# Prompt: What is the capital of France?
# [Generated response...]
# Prompt: Tell me more about its history
# [Follow-up response...]
```

### English text 8: English textinference (English textfileEnglish textprompt)

```bash
# English text data/prompts.txt English textpromptEnglish text
make infer-batch

# English textresult
cat artifacts/inference_output/results.jsonl
```

### English text 9: inferenceEnglish text (English text)

```bash
# startinferenceEnglish text, English text 0.0.0.0:8000
make infer-serving

# English texttest
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello", "max_tokens": 50}'
```

### English text 10: English text (LoRA)

```bash
# English texttrainingmodelEnglish text
make finetune \
  NEURX_TOTAL_STEPS=1000 \
  NEURX_BATCH_SIZE=8 \
  NEURX_LR=0.0001 \
  NEURX_LORA_RANK=8

# English textmonitoring
make finetune-watch
```

---

## 🎛️ English text

### trainingparameter

```bash
NEURX_TOTAL_STEPS           # trainingEnglish textstepEnglish text (default: 100)
NEURX_BATCH_SIZE            # English text GPU English text (default: 4)
NEURX_LR                    # English textlearning rate (default: 0.001)
NEURX_SEQ_LENGTH            # English text (default: 8)
NEURX_WARMUP_STEPS          # English textstepEnglish text (default: 10)
NEURX_CHECKPOINT_INTERVAL   # checkpointsaveEnglish text (default: 10)
```

### English textparameter

```bash
NEURX_WORLD_SIZE            # English text GPU English text (default: 1)
NEURX_DATA_PARALLEL_SIZE    # dataEnglish text GPU English text (default: 1)
NEURX_TENSOR_PARALLEL_SIZE  # English text GPU English text (default: 1)
NEURX_PIPELINE_PARALLEL_SIZE # English text GPU English text (default: 1)
```

### English textparameter

```bash
NEURX_NUM_NODES             # computeEnglish text (default: 1)
NEURX_RANK                  # English text rank (default: 0)
NEURX_MASTER_ADDR           # Master English text (default: localhost)
NEURX_MASTER_PORT           # Master English text (default: 29500)
```

### optimizeparameter

```bash
NEURX_MIXED_PRECISION_MODE  # English text: bf16/fp16/fp32 (default: bf16)
NEURX_LOSS_SCALE            # English textlossEnglish text (default: 1.0)
NEURX_GRADIENT_ACCUMULATION # gradientEnglish textstepEnglish text (default: 1)
```

### inferenceparameter

```bash
NEURX_TEMPERATURE           # English text (default: 0.7)
NEURX_TOP_K                 # Top-K English text (default: 40)
NEURX_TOP_P                 # Nucleus English text (default: 0.9)
NEURX_MAX_TOKENS            # English textgenerateEnglish text (default: 50)
NEURX_BEAM_SIZE             # Beam search English text (default: 1)
```

### English textparameter

```bash
NEURX_FINETUNE_MODE         # English text (default: false)
NEURX_LORA_RANK             # LoRA English text (default: 8)
NEURX_LORA_ALPHA            # LoRA α (default: 16)
NEURX_CHECKPOINT_PATH       # English texttrainingmodelpath
```

### inferenceEnglish textparameter

```bash
NEURX_SERVE_PORT            # English text (default: 8000)
NEURX_SERVE_HOST            # English text (default: 0.0.0.0)
NEURX_SERVE_WORKERS         # English text (default: 4)
```

---

## 🔧 advancedEnglish text

### English textparameterexample

```bash
# English text 1: English textmodeltraining
make train-large \
  NEURX_TOTAL_STEPS=10000 \
  NEURX_BATCH_SIZE=64 \
  NEURX_SEQ_LENGTH=2048 \
  NEURX_LR=0.00005 \
  NEURX_WARMUP_STEPS=1000 \
  NEURX_MIXED_PRECISION_MODE=bf16 \
  NEURX_CHECKPOINT_INTERVAL=200

# English text 2: English texttraining
make train-tensor \
  NEURX_WORLD_SIZE=8 \
  NEURX_TENSOR_PARALLEL_SIZE=8 \
  NEURX_BATCH_SIZE=16 \
  NEURX_SEQ_LENGTH=4096

# English text 3: English text + dataEnglish text
make train-pipeline \
  NEURX_WORLD_SIZE=16 \
  NEURX_DATA_PARALLEL_SIZE=2 \
  NEURX_TENSOR_PARALLEL_SIZE=2 \
  NEURX_PIPELINE_PARALLEL_SIZE=4

# English text 4: English text(4 English text, English text 8 GPU)
make train-dist \
  NEURX_NUM_NODES=4 \
  NEURX_RANK=$RANK \
  NEURX_MASTER_ADDR=192.168.1.100 \
  NEURX_MASTER_PORT=29500

# English text 5: English textinference
make infer-batch \
  NEURX_TEMPERATURE=0.5 \
  NEURX_TOP_K=20 \
  NEURX_TOP_P=0.95 \
  NEURX_MAX_TOKENS=256
```

---

## 📊 English text

### English text GPU (A100-40GB)

| modelEnglish text | English text | English text | time/step | English text |
|---------|--------|---------|--------|------|
| 10M | 1 | 8 | 10ms | 0.8K t/s |
| 100M | 4 | 128 | 25ms | 2K t/s |
| 1B | 16 | 512 | 50ms | 6K t/s |
| 7B | 4 | 2048 | 100ms | 12K t/s |

### English text GPU (4× A100)

| configuration | time/step | English text | English text |
|------|--------|------|---------|
| DDP 2× | 6ms | 4K t/s | 95% |
| DDP 4× | 4ms | 8K t/s | 93% |
| Tensor TP 4× | 30ms | 25K t/s | 90% |

---

## ⚠️ English text

### Q: English text GPU English text?

```bash
# English textmodel (< 100M): 1 GPU
make train-llm

# English textmodel (100M-3B): 2-4 GPU DDP
make train-dp NEURX_WORLD_SIZE=4

# English textmodel (7B-13B): 8 GPU DDP + Tensor TP
make train-large

# English textmodel (70B+): 32 GPU English text
make train-xlarge
```

### Q: English text?

```bash
# English text 1: English text
make train-llm NEURX_BATCH_SIZE=2

# English text 2: English text
make train-llm NEURX_SEQ_LENGTH=256

# English text 3: English textgradientcheckpoint(English textsupport)
make train-llm NEURX_BATCH_SIZE=1

# English text 4: useEnglish textweight
make train-tensor NEURX_TENSOR_PARALLEL_SIZE=4
```

### Q: trainingEnglish text?

```bash
# English text 1: English text(English textdefault BF16)
make train-llm NEURX_MIXED_PRECISION_MODE=bf16

# English text 2: English text
make train-llm NEURX_BATCH_SIZE=64

# English text 3: English text(English textcomputeEnglish text)
make train-llm NEURX_SEQ_LENGTH=2048

# English text 4: useEnglish text GPU
make train-dp NEURX_WORLD_SIZE=4
```

### Q: English textmonitoringtrainingEnglish text?

```bash
# English text 1: English textlog
make train-llm-watch

# English text 2: English textlogfile
tail -f /tmp/neurx_llm_train.log

# English text 3: monitoringEnglish text
make monitor

# English text 4: English textcheckpoint
ls -lh artifacts/checkpoints/llm_training/
```

---

## 🚀 English textstartEnglish text

### quickstartEnglish text

```bash
#!/bin/bash
# quick_start.sh

echo "🚀 NeurX quickstart"

# 1. English text
echo "1️⃣  English text..."
make test

# 2. quicktest
echo "2️⃣  runquicktest..."
make train-llm NEURX_TOTAL_STEPS=10

# 3. modelEnglish text
echo "3️⃣  English textmodel..."
make train-llm NEURX_TOTAL_STEPS=100 NEURX_BATCH_SIZE=4

# 4. inferencetest
echo "4️⃣  testinference..."
make infer

echo "✅ quickstartEnglish text!"
echo "📖 English text: make train-help, make infer-help"
```

---

## 📞 English text

```bash
# English text
make help

# English texttrainingEnglish text
make train-help

# English textinferenceEnglish text
make infer-help

# English textlog
make monitor

# English textlogfile
make logs

# English textlog
make clean-logs
```

---

## ✅ English text

startEnglish texttrainingEnglish text:

- [ ] GPU English text (`nvidia-smi`)
- [ ] CUDA English text (`nvcc --version`)
- [ ] English text (checkpoint ~10GB+)
- [ ] English text (English texttraining)
- [ ] English text ✅

---

## 📚 English text

- [MAKE_COMMANDS_CHEATSHEET.md](MAKE_COMMANDS_CHEATSHEET.md) - English text
- [NEURX_LLM_TRAINING_GUIDE.md](NEURX_LLM_TRAINING_GUIDE.md) - English text
- [COMPLETE_PIPELINE_GUIDE.md](COMPLETE_PIPELINE_GUIDE.md) - English textsystem

---

**generateEnglish text**: 2026-07-01
**state**: ✅ English text
**English text**: v1.0
