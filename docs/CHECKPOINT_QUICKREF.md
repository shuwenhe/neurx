# GPU English texttrainingEnglish text - quickEnglish text (Quick Reference)

## English text

```bash
# English texttraining(English textstart)
make pretrain-gpu

# English textrecovertraining(English textcheckpoint)
make pretrain-gpu

# English texttraining(English textcheckpoint)
make pretrain-gpu-fresh
```

## 4English text

| English text | English text | English textuse |
|------|------|--------|
| `make pretrain-gpu` | English textrecoverEnglish texttraining | ✅ recommended, defaultEnglish text |
| `make pretrain-gpu-resume` | English textrecover | English text |
| `make pretrain-gpu-fresh` | English texttraining | English textstart |
| `NEURX_PRETRAIN_RESUME=no make pretrain-gpu` | English texttraining | English text |

## CheckpointfileEnglish text

```
checkpoint/NeurX-1.3/training_state.txt
```

**English text**: `step=<N> docs=<N> shards=<N> loss=<F>`

**example**: `step=1000 docs=5000 shards=3 loss=2.45`

## English text

### English texttrainingstate
```bash
cat checkpoint/NeurX-1.3/training_state.txt
```

### English textmonitoringtrainingEnglish text
```bash
watch -n 1 'cat checkpoint/NeurX-1.3/training_state.txt'
```

### English texttraininglog
```bash
tail -f artifacts/logs/pretrain_gpu_*.log
```

### English textcheckpointEnglish textstart
```bash
make pretrain-gpu-fresh
```

### English textNEnglish textGPUEnglish texttrainingEnglish textrecover
```bash
NEURX_NUM_GPUS=4 make pretrain-gpu
```

### English textcheckpoint(English text!)
```bash
# English textstepEnglish text5000recover
echo "step=5000 docs=25000 shards=15 loss=2.10" > checkpoint/NeurX-1.3/training_state.txt

# English texttraining
make pretrain-gpu
```

## English text

| English text | defaultEnglish text | explanation |
|------|--------|------|
| `NEURX_PRETRAIN_RESUME` | `auto` | recoverEnglish text: auto/yes/no |
| `NEURX_NUM_GPUS` | English text | GPUcount |
| `NEURX_PRETRAIN_STEPS` | 1000000000 | English texttrainingstepEnglish text |
| `NEURX_PRETRAIN_OUTPUT_DIR` | `checkpoint/NeurX-1.3` | Checkpointsavedirectory |

## completeEnglish textexample

```bash
# 1. English texttraining(60English text)
make pretrain-gpu
# log: [Phase 1] No existing checkpoint found, starting fresh training
# trainingEnglish text...
# English textsave: checkpoint/NeurX-1.3/training_state.txt

# 2. English text(Ctrl+C)
# [English text]

# 3. English textsavestate
cat checkpoint/NeurX-1.3/training_state.txt
# output: step=1000 docs=5000 shards=3 loss=2.45

# 4. recovertraining
make pretrain-gpu
# log: [Phase 1] Existing checkpoint found
#       [Phase 1] Loaded state: step=1000 docs=5000 shards=3 loss=2.45
#       [Phase 3] Starting training from step 1000
# trainingEnglish text... English text1000stepEnglish text

# 5. English textstart
make pretrain-gpu-fresh
# log: Starting fresh training (ignoring any existing checkpoint)
# [Phase 1] No existing checkpoint found, starting fresh training
```

## English text

### CheckpointEnglish textfailure
```bash
# English textfileEnglish text
test -f checkpoint/NeurX-1.3/training_state.txt && echo "English text" || echo "English text"

# English text, English texttraining
make pretrain-gpu-fresh
```

### GPUEnglish text
```bash
# English textGPU
nvidia-smi

# English textCPUtraining
make pretrain
```

### English textuseEnglish textcheckpointdirectory
```bash
NEURX_PRETRAIN_OUTPUT_DIR=checkpoint/NeurX-1.3-v2 make pretrain-gpu
```

## English text

- completeEnglish text: [docs/CHECKPOINT_RESUME_GUIDE.md](docs/CHECKPOINT_RESUME_GUIDE.md)
- implementationEnglish text: [docs/GPU_CHECKPOINT_IMPLEMENTATION_SUMMARY.md](docs/GPU_CHECKPOINT_IMPLEMENTATION_SUMMARY.md)

## English text

```bash
# English texttraining
make pretrain-gpu

# recovertraining
make pretrain-gpu

# English texttraining
make pretrain-gpu-fresh

# monitoring
watch -n 1 'cat checkpoint/NeurX-1.3/training_state.txt'

# log
tail -f artifacts/logs/pretrain_gpu_*.log

# 4GPUrecover
NEURX_NUM_GPUS=4 make pretrain-gpu
```

## English text

1. ✅ defaultEnglish textcheckpointEnglish textrecover
2. ✅ CheckpointsaveEnglish text `checkpoint/NeurX-1.3/training_state.txt`
3. ✅ English text: `step=<N> docs=<N> shards=<N> loss=<F>`
4. ✅ English textAllowedEnglish text(Ctrl+C), English textrecover
5. ✅ English textstartEnglish text `make pretrain-gpu-fresh`

---

**English text**: `make help | grep pretrain` English textcompleteEnglish text
