# NeurX English textGPUEnglish texttrainingsystem

## systemEnglish text

English textsystemimplementationEnglish textcompleteEnglish textGPUEnglish texttrainingEnglish text, English text:

### 1. **English textstartEnglish text** (`distributed_pretrain_launcher.s`)
- **English text**: initializeEnglish text, managementEnglish text
- **English text**:
  - `distributed_env`: English textconfiguration(WORLD_SIZE, RANK, LOCAL_RANK)
  - `distributed_pretrain_launcher`: mainEnglish text
  - dataEnglish text: English textrankEnglish text

**English text**:
```bash
WORLD_SIZE=4          # English textGPUcount
RANK=0-3              # English textrank
LOCAL_RANK=0-3        # English textGPUEnglish text
MASTER_ADDR=localhost # mainEnglish text
MASTER_PORT=29500     # English text
```

### 2. **CUDAEnglish text** (`cuda_bridge.s`)
- **English text**: implementationGPUEnglish textgradientEnglish textstep
- **English text**:
  - `cuda_bridge_all_reduce_sum`: NCCL AllReduceEnglish textstepgradient
  - `cuda_bridge_reduce_scatter`: English textgradientEnglish text
  - `cuda_bridge_broadcast`: mainrankEnglish textrankEnglish text

**gradientEnglish textsteppipeline**:
```
English textrankEnglish textgradient ─> NCCL AllReduce ─> English text ─> English text ─> optimizeEnglish text
```

### 3. **English texttrainingEnglish text** (`distributed_pretrain_entry.s`)
- **English text**: maintrainingEnglish text, English text
- **pipeline**:
  1. initializeEnglish text
  2. English textrankloadEnglish textdataEnglish text
  3. gradientEnglish text
  4. English textNstepEnglish textNCCL AllReduceEnglish textstepgradient
  5. English textoptimizeEnglish text

### 4. **English textGPUstartEnglish text** (`launch_pretrain_distributed.s`)
- **English text**: English textstartEnglish textmanagement (English textSlanguageimplementation, English textshellEnglish text)
- **English text**:
  - English textstart: English textrankstartEnglish texttrainingEnglish text
  - GPUEnglish text: English textGPUcount
  - English textstepEnglish textmanagement: English textstart, English text
  - logEnglish text: English textrankEnglish textlogoutput
  - errorEnglish text: English textfailureEnglish text

**English text**:
- 100% Slanguageimplementation, English text
- English textshellEnglish text
- English text
- English text

---

## startEnglish text

### English textGPUstart (recommended - English textSlanguage)

```bash
# start4English textGPUEnglish texttraining
export NUM_GPUS=4 MASTER_ADDR=localhost MASTER_PORT=29500
./scripts/legacy/launch_pretrain_distributed.s

# start2English textGPU
export NUM_GPUS=2
./scripts/legacy/launch_pretrain_distributed.s

# start1English textGPU (English textGPUEnglish text)
./scripts/legacy/launch_pretrain_distributed.s
```

### English textstartEnglish text (English textRequiredEnglish text)

```bash
# Terminal 1 - rank 0
export RANK=0 LOCAL_RANK=0 WORLD_SIZE=4 MASTER_ADDR=localhost MASTER_PORT=29500
./pretrain/distributed_pretrain_entry.s

# Terminal 2 - rank 1
export RANK=1 LOCAL_RANK=1 WORLD_SIZE=4 MASTER_ADDR=localhost MASTER_PORT=29500
./pretrain/distributed_pretrain_entry.s

# Terminal 3 - rank 2
export RANK=2 LOCAL_RANK=2 WORLD_SIZE=4 MASTER_ADDR=localhost MASTER_PORT=29500
./pretrain/distributed_pretrain_entry.s

# Terminal 4 - rank 3
export RANK=3 LOCAL_RANK=3 WORLD_SIZE=4 MASTER_ADDR=localhost MASTER_PORT=29500
./pretrain/distributed_pretrain_entry.s
```

---

## dataEnglish text

### dataEnglish text

English textrankEnglish textdataEnglish text, English text:

```
5131English textshardsEnglish text4English textrank:
- Rank 0: shard_0, shard_4, shard_8, ...    (English text 5131/4 ≈ 1283English text)
- Rank 1: shard_1, shard_5, shard_9, ...    (English text 5131/4 ≈ 1283English text)
- Rank 2: shard_2, shard_6, shard_10, ...   (English text 5131/4 ≈ 1283English text)
- Rank 3: shard_3, shard_7, shard_11, ...   (English text 5131/4 ≈ 1283English text)
```

### English textcompute

```
micro_batch_size = 8          # English textstepGPUEnglish text
gradient_accum_steps = 8      # gradientEnglish textstepEnglish text
world_size = 4                # GPUcount

English text = 8 × 8 × 4 = 256
```

---

## gradientEnglish textstepEnglish text

### English textsteppipeline

```
Step 1: English text(micro_batch_size=8)
        ├─ Rank 0: loss_0, grad_0
        ├─ Rank 1: loss_1, grad_1
        ├─ Rank 2: loss_2, grad_2
        └─ Rank 3: loss_3, grad_3

Step 2: gradientEnglish text(English text8stepEnglish text)
        ├─ Rank 0: sum_0 = Σ(grad_0)
        ├─ Rank 1: sum_1 = Σ(grad_1)
        ├─ Rank 2: sum_2 = Σ(grad_2)
        └─ Rank 3: sum_3 = Σ(grad_3)

Step 3: NCCL AllReduce (English textrankEnglish text)
        ├─ English textrankEnglish textgradient
        ├─ English text: grad_sync = sum_0 + sum_1 + sum_2 + sum_3
        ├─ English text: grad_avg = grad_sync / 4
        └─ English textrank

Step 4: optimizeEnglish text(English textrankEnglish textstepEnglish text)
        ├─ Rank 0: params_0 -= lr * grad_avg
        ├─ Rank 1: params_1 -= lr * grad_avg
        ├─ Rank 2: params_2 -= lr * grad_avg
        └─ Rank 3: params_3 -= lr * grad_avg
```

### NCCL AllReduceEnglish textCUDAimplementation

```c
// English text
ncclAllReduce(
    d_gradients,        // GPUgradientEnglish text
    d_gradients,        // outputEnglish text
    num_gradients,      // gradientcount
    ncclFloat,          // dataEnglish text
    ncclSum,            // English text: English text
    comm,               // NCCL communicator
    stream              // CUDAEnglish text
);

// English textGPUEnglish text, English textCPUEnglish text
```

---

## English textoptimize

### 1. English textstepgradientEnglish text

```python
# English textcomputeEnglish textstepEnglish text, English textgradient
handle = cuda_bridge_all_reduce_async(launcher.cb, gradients)
# English textcompute
next_batch = load_next_batch()
# English textgradientEnglish textstepEnglish text
synced_grads = async_all_reduce_wait(handle)
```

### 2. English textoptimize

```toml
# pretrain_config.tomlconfiguration
gradient_checkpointing = true    # English text
activation_checkpointing = true  # English text
flash_attention = true           # English text
fused_kernels = true             # English textCUDAEnglish text
```

### 3. English textoptimize

```
Ring AllReduce:
- gradientEnglish textNEnglish textchunks
- English textrankEnglish textrankEnglish text
- N-1English textstep
- English text: O(log N) -> O(N)English text
```

---

## English text

### RTX 4060 Ti English textGPU vs English textGPU

| configuration | English text | English text | English text | English texttime |
|------|--------|------|--------|----------|
| **1×RTX 4060 Ti** | 64 | 16GB | ~50 samples/s | ~18English text |
| **2×RTX 4060 Ti** | 64×2=128 | 16GB×2 | ~95 samples/s | ~10English text |
| **4×RTX 4090** | 256 | 24GB×4 | ~400 samples/s | ~4English text |

**English text**:
- 2English textGPU: ~1.9xEnglish text
- 4English textGPU: ~4.5xEnglish text(English text)

---

## English textmonitoring

### logoutput

```
[trainer-v2] step=531/1000000000 optimizer_step=66 loss=8.665277
             tokens=543744 shard=0 line=70 accum=3/8

English text:
- step: English textstepEnglish text
- optimizer_step: optimizeEnglish textstepEnglish text
- loss: lossEnglish text
- tokens: English texttokenEnglish text
- shard: English textshardEnglish text
- line: English textshardEnglish text
- accum: gradientEnglish text (3/8)
```

### monitoringGPUEnglish text

```bash
# English textmonitoringEnglish textGPU
watch -n 1 'nvidia-smi'

# English texttrainingEnglish text
cuda_bridge_log_status(launcher.cb)
# output: [CUDA Bridge rank=0] device=0 memory=24576MB free=12288MB
```

### English textstateEnglish text

```bash
# English texttrainingEnglish text
ps aux | grep distributed_pretrain_entry

# English textrankEnglish text
# (RequiredEnglish textNVIDIA NCCL debugger)
```

---

## English text

### Q1: English text
**A**: English textmicro_batch_sizeEnglish textgradient_accum_steps

### Q2: trainingEnglish text
**A**:
- English textNCCLEnglish textinitializesuccess
- English textdataEnglish textrank
- English textAllReduceEnglish textgradientEnglish text(English text)

### Q3: gradientEnglish text
**A**:
- English textrankuseEnglish text
- English textAllReduceEnglish text

### Q4: English text
**A**:
- English textMASTER_PORTEnglish text
- English text
- English text

---

## fileEnglish text

```
neurx/
├── distributed/
│   ├── cuda_bridge.s                    # CUDAEnglish text (NCCL AllReduce)
│   ├── distributed_pretrain_launcher.s  # English textstartEnglish text
│   ├── ddp/
│   └── ...
├── pretrain/
│   ├── distributed_pretrain_entry.s     # mainEnglish text
│   ├── pretrain_config.toml             # trainingconfiguration
│   └── ...
└── scripts/legacy/
    ├── launch_pretrain_distributed.s    # English textGPUstartEnglish text (English textSlanguage)
    └── ...
```

---

## English textstep

1. **compileSlanguageEnglish text**: `make build-distributed`
2. **runEnglish textGPUtest**: `./scripts/legacy/launch_pretrain_distributed.s` (English textuse1English textGPU)
3. **runEnglish textGPUtraining**: `export NUM_GPUS=4 && ./scripts/legacy/launch_pretrain_distributed.s`
4. **monitoringtrainingEnglish text**: English text `artifacts/logs/distributed_pretrain/` English textlog

---

## English text

- [PyTorch Distributed Data Parallel](https://pytorch.org/docs/stable/generated/torch.nn.parallel.DistributedDataParallel.html)
- [NCCL Documentation](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/)
- [torchrun](https://pytorch.org/docs/stable/elastic/run.html)
