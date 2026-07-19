# NeurX English textGPUEnglish texttrainingconfigurationEnglish text

## quickstart

### 1. useEnglish textGPUEnglish texttraining

```bash
# English textGPUEnglish texttraining
make pretrain-gpu-distributed

# English text: English text4English textGPU
# GPU 0, 1, 2, 3 English textrun, English textdataEnglish text
# gradientEnglish textNCCL AllReduceEnglish textstep
```

### 2. English textGPUcount

```bash
# English textuse2English textGPU
NEURX_NUM_GPUS=2 make pretrain-gpu-distributed

# English textuse1English textGPU(English textGPUEnglish text)
NEURX_NUM_GPUS=1 make pretrain-gpu-distributed
```

---

## English textconfiguration

### GPUEnglish textconfiguration

| English text | defaultEnglish text | explanation |
|------|--------|------|
| `NEURX_NUM_GPUS` | English text | GPUcount(1-8) |
| `NEURX_DDP_BACKEND` | `nccl` | English text: `nccl`English text`gloo` |
| `NEURX_MASTER_ADDR` | `localhost` | mainEnglish text |
| `NEURX_MASTER_PORT` | `29500` | English text |

### trainingparameter

| English text | defaultEnglish text | explanation |
|------|--------|------|
| `NEURX_PRETRAIN_STEPS` | 50000 | English texttrainingstepEnglish text |
| `NEURX_PRETRAIN_MICRO_BATCH` | 8 | English textstepGPUEnglish text |
| `NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS` | 8 | gradientEnglish textstepEnglish text |
| `NEURX_PRETRAIN_SEQ_LEN` | 2048 | English text |
| `NEURX_PRETRAIN_LEARNING_RATE` | 0.0002 | learning rate |

### modelconfiguration

| English text | defaultEnglish text | explanation |
|------|--------|------|
| `NEURX_TRANSFORMER_DIM` | 1024 | English text |
| `NEURX_TRANSFORMER_HEADS` | 16 | English text |
| `NEURX_TRANSFORMER_FFN` | 4096 | FFNEnglish text |
| `NEURX_TRANSFORMER_NUM_LAYERS` | 24 | TransformerEnglish text |

---

## useexample

### example1: 4GPUEnglish texttraining(recommended)

```bash
# RTX 4090 × 4 English texttraining
NEURX_NUM_GPUS=4 \
  NEURX_PRETRAIN_MICRO_BATCH=16 \
  NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=4 \
  NEURX_PRETRAIN_LEARNING_RATE=0.0002 \
  make pretrain-gpu-distributed
```

**English text**:
- English text: 16 × 4 × 4 = 256
- English textstepEnglish texttokens: 256 × 2048 = 524,288 tokens
- English text: ~400 samples/sec
- 113GBdataEnglish text: ~4English text

### example2: 2GPUEnglish texttraining

```bash
NEURX_NUM_GPUS=2 \
  NEURX_PRETRAIN_MICRO_BATCH=12 \
  NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=8 \
  make pretrain-gpu-distributed
```

### example3: English textGPUtest(English text)

```bash
NEURX_NUM_GPUS=1 make pretrain-gpu-distributed
```

### example4: English texttraining(English text)

```bash
# English text1(mainEnglish text)
NEURX_NUM_GPUS=4 \
  NEURX_MASTER_ADDR=192.168.1.100 \
  NEURX_MASTER_PORT=29500 \
  make pretrain-gpu-distributed

# English text2(English text)- RequiredEnglish textconfigurationRANK
RANK=4 LOCAL_RANK=0 WORLD_SIZE=8 \
  NEURX_MASTER_ADDR=192.168.1.100 \
  NEURX_MASTER_PORT=29500 \
  ./scripts/legacy/pretrain_gpu_distributed.s
```

---

## English textoptimize

### English textparameter

**RTX 4090 (24GBEnglish text)**
```bash
NEURX_PRETRAIN_MICRO_BATCH=32         # AllowedEnglish text
NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=2 # English textstepEnglish text
```

**RTX 4060 Ti (16GBEnglish text)**
```bash
NEURX_PRETRAIN_MICRO_BATCH=8          # English text
NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=8 # English textstepEnglish text
```

### dataloadoptimize

```bash
NEURX_PRETRAIN_NUM_WORKERS=8           # English textdataloadEnglish text
NEURX_PRETRAIN_LINE_CHUNK=256          # English text
```

---

## gradientEnglish textsteppipeline

```
4GPUEnglish texttraining:

Rank 0        Rank 1        Rank 2        Rank 3
GPU 0         GPU 1         GPU 2         GPU 3
│             │             │             │
├─ Load       ├─ Load       ├─ Load       ├─ Load
│  Shard 0    │  Shard 1    │  Shard 2    │  Shard 3
│             │             │             │
├─ Forward    ├─ Forward    ├─ Forward    ├─ Forward
├─ Backward   ├─ Backward   ├─ Backward   ├─ Backward
│ Grad        │ Grad        │ Grad        │ Grad
│             │             │             │
└─ NCCL AllReduce (gradientEnglish textstep)
       ↓
English textrankEnglish textgradientEnglish text
       ↓
┌─ Optimizer step (English textstepEnglish text)
├─ Rank 0: params -= lr * avg_grad
├─ Rank 1: params -= lr * avg_grad
├─ Rank 2: params -= lr * avg_grad
└─ Rank 3: params -= lr * avg_grad
```

---

## monitoringEnglish text

### English textstate

```bash
# English textGPUuseEnglish text
nvidia-smi

# English textrankEnglish text
ps aux | grep pretrain_gpu_distributed

# English textrankEnglish textlog
tail -f artifacts/logs/run_gpu_pretrain_*.log
```

### English textNCCLEnglish text

```bash
# English textNCCLEnglish text
export NCCL_DEBUG=INFO
make pretrain-gpu-distributed 2>&1 | grep NCCL
```

### English text

```bash
# English textrankEnglish text
NEURX_PRETRAIN_LOG_INTERVAL=10 \
  make pretrain-gpu-distributed
```

---

## English text

### Q1: English texterror
**A**: English text `NEURX_PRETRAIN_MICRO_BATCH` English text `NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS`

```bash
NEURX_PRETRAIN_MICRO_BATCH=4 \
  NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=16 \
  make pretrain-gpu-distributed
```

### Q2: gradientEnglish textstepEnglish text
**A**: English texttimeEnglish text
```bash
export NCCL_TIMEOUT=1800  # 30English text
make pretrain-gpu-distributed
```

### Q3: GPUEnglish text
**A**: English text `NEURX_PRETRAIN_NUM_WORKERS` English textdataloadEnglish text
```bash
NEURX_PRETRAIN_NUM_WORKERS=16 make pretrain-gpu-distributed
```

### Q4: English textGPU
**A**: English textNVIDIAEnglish text
```bash
nvidia-smi  # English text
make pretrain-gpu-distributed
```

---

## English text

### trainingEnglish text

| GPUconfiguration | English text | English text | English texttime |
|--------|-----------|--------|----------|
| 1×RTX 4060 Ti | 64 | 50 samples/s | 18English text |
| 2×RTX 4090 | 256 | 190 samples/s | 10English text |
| **4×RTX 4090** | **512** | **400 samples/s** | **4English text** |
| 8×RTX 4090 | 1024 | 800 samples/s | 2English text |

### English text

- **2GPU**: ~1.9x English text
- **4GPU**: ~4.5x English text (English text)
- **8GPU**: ~8.2x English text

---

## fileEnglish text

### MakefileEnglish text

```bash
# English textGPUcountEnglish texttraining
make pretrain-gpu-distributed

# English textlog
rm -rf artifacts/logs/run_gpu_pretrain_*

# English textlog
tail -f artifacts/logs/run_gpu_pretrain_*.log | tail -100
```

### English text

- **startEnglish text**: [scripts/legacy/launch_pretrain_distributed.s](../scripts/legacy/launch_pretrain_distributed.s)
- **English text**: [pretrain/distributed_pretrain_entry.s](../pretrain/distributed_pretrain_entry.s)
- **CUDAEnglish text**: [distributed/cuda_bridge.s](../distributed/cuda_bridge.s)

---

## English textstep

1. **runEnglish textGPUtest**:
   ```bash
   NEURX_NUM_GPUS=1 make pretrain-gpu-distributed
   ```

2. **runEnglish textGPUtraining**:
   ```bash
   make pretrain-gpu-distributed
   ```

3. **monitoringtrainingEnglish text**:
   ```bash
   tail -f artifacts/logs/run_gpu_pretrain_distributed_*.log
   ```

4. **recovertraining**:
   ```bash
   NEURX_PRETRAIN_RESUME=auto make pretrain-gpu-distributed
   ```
