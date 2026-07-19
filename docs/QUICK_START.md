# neurx 1T MoE trainingframework - quickstartEnglish text

## 🎯 30English text

**neurx** English text 1T parameter MoE Transformer English texttrainingframework, supportEnglish text 1024 GPU English text 4-6 English texttraining.

| English text | English text |
|------|-----|
| **modelEnglish text** | 1 Trillion parameter (1T) |
| **modelEnglish text** | 256-Expert MoE Transformer |
| **trainingEnglish text** | 1024 × H100 80GB GPUs |
| **trainingEnglish text** | 4-6 English text |
| **English text** | 3000+ tokens/sec |
| **English text** | 8×DP × 8×TP × 8×PP × 16×EP |

---

## 🚀 5English textquickEnglish text

### English text
- 1024 GPU H100 English text (English text: English textrun)
- S compileEnglish text (`/opt/s/bin/s`)
- SLURM English textmanagement
- Python 3.9+

### stepEnglish text 1: English text (5 English text)

```bash
# English text neurx directory
cd /Users/feifei/shuwen/train/neurx

# English textframeworkcompleteEnglish text
bash scripts/legacy/verify_framework.sh
```

**English textoutput:**
```
✅ English text:
  English text:  14 English textfile/English text
  English text:  0 English textfile/English text
```

### stepEnglish text 2: English textdata (1-2 English text)

```bash
# English text 3T tokens English texttrainingdata(English text 8192 English text JSONL file)
# dataEnglish text: English text JSON {"text": "..."}

mkdir -p data/training_data_splits
# English textgenerate 8192 English textfileEnglish textdirectory

# generate manifest file
ls data/training_data_splits/*.jsonl > data/training_data_shards/manifest.txt
```

### stepEnglish text 3: English text (< 1 English text)

```bash
# English textmainEnglish texttrainingEnglish text
cd /opt/neurx
sbatch scripts/legacy/submit_training_job.sh

# English textstate
squeue -j <job_id>

# English textlog
tail -f artifacts/logs/training_rank0_*.log
```

### stepEnglish text 4: monitoringtraining (English text 4-6 English text)

```bash
# monitoringEnglish text
watch -n 10 'tail -20 artifacts/logs/training_rank0_*.log'

# English text GPU English text
nvidia-smi dmon -s pucvmet

# English textcheckpoint
ls -lh artifacts/checkpoints/
```

---

## 📚 English text

### 1. MoE All-to-All English text

**file**: `distributed/moe_all_to_all.s` (473 English text)

**English textfunction**:
```s
func moe_alltoall_forward(
  tokens: Tensor[B×S, H],
  router_logits: Tensor[B×S, E]
) -> (routed_tokens: Tensor, expert_idx: Tensor, weights: Tensor, aux_loss: f64)
```

**useEnglish text**: English text 256 English text MoE English text, support top-k=2 English text.

### 2. English text (TP)

**file**: `distributed/tensor_parallel.s` (329 English text)

**English textfunction**:
```s
func tp_qkv_forward(x: Tensor[B×S, H], tp_rank: i32, tp_size: i32) -> Tensor[B×S, H/8]
func tp_ffn_column_parallel(x: Tensor[B×S, H], W_up: Tensor[H, 4H/8]) -> Tensor[B×S, 4H/8]
func tp_ffn_row_parallel(x: Tensor[B×S, 4H/8], W_down: Tensor[4H/8, H]) -> Tensor[B×S, H]
```

**useEnglish text**: English textweightEnglish text 8 English text GPU, supportEnglish text (QKV) English text (FFN).

### 3. ZeRO Stage 3

**file**: `distributed/zero_gradient_reduce.s` (504 English text)

**English textfunction**:
```s
func zero_stage3_new(world_size: i32, param_count: i64) -> ZeroState
func zero_stage3_accumulate_gradients(state: &ZeroState, grads: Tensor)
func zero_stage3_optimizer_step(state: &ZeroState, lr: f64)
```

**useEnglish text**: parameterEnglish text (1/world_size = 1GB/GPU), English textstepgradientEnglish text.

### 4. losscompute

**file**: `moe/llm_moe_1t_loss.s` (495 English text)

**lossfunction**:
```
L_total = L_CE + 0.01 × L_aux + 0.05 × L_kl

English text:
  L_CE = Cross-Entropy(logits, labels)
  L_aux = MoE English textloss (English text)
  L_kl = English text KL English text (English text)
```

### 5. learning rateEnglish text

**file**: `optimizer/lr_scheduler_moe_1t.s` (422 English text)

**supportEnglish text**:
- ✅ English text (default): 10K stepEnglish text → 750K stepEnglish text
- ✅ English text
- ✅ English text
- ✅ One-Cycle

**English text**:
```s
let scheduler = lr_scheduler_new(base_lr=0.0002, warmup_steps=10000, total_steps=750000)
let lr = scheduler.step()  // English textstepEnglish text
```

### 6. dataload

**file**: `data/moe_1t_jsonl_loader.s` (430 English text)

**English text**:
- JSONL English textload (8192 English textfile)
- BPE English text (128K English text)
- English text (round-robin) DP English text
- English text seq_len=4096

**use**:
```s
let loader = jsonl_loader_new(batch_size=2, seq_len=4096, dp_rank=0, dp_size=8)
let (input_ids, attn_mask) = loader.get_next_batch()
```

### 7. English textmonitoring

**file**: `monitoring/moe_1t_metrics.s` (598 English text)

**English text**:
- **training**: loss, loss_ce, loss_aux, perplexity, LR, grad_norm
- **MoE**: 256 English text, English text, English text
- **English text**: AllGather, AllReduce, ReduceScatter English text
- **system**: GPU English text, English text, English text, English text

**logEnglish text**:
```
Step=1000 Loss=3.45 LR=0.000198 Perplexity=31.4 GradNorm=2.1 MoE-Load=0.98 Throughput=2850 Memory=78.5%
```

### 8. English textsupport

**file**: `model/llm/long_context_32k.s` (461 English text)

**English text**:
- RoPE (English text)
- NTK English text (English text)
- support 32K tokens English text
- English text 4K, 8K, 16K, 32K

---

## ⚙️ configurationparameterexplanation

### modelconfiguration (`training_startup.env`)

```bash
NEURX_MODEL_NAME="neurx-1t-moe"           # modelName
NEURX_MODEL_PARAMETER_COUNT_M=1000000    # 1T parameter
NEURX_MODEL_ACTIVE_PARAMETER_COUNT_M=111111  # English textparameter
NEURX_LLM_VOCAB_SIZE=128000              # English text
NEURX_LLM_HIDDEN_SIZE=12288              # English text
NEURX_LLM_NUM_HEADS=96                   # English text
NEURX_LLM_NUM_LAYERS=80                  # Transformer English text
NEURX_LLM_INTERMEDIATE_SIZE=49152        # FFN English text
NEURX_LLM_MAX_SEQ_LEN=32768              # English text
```

### English textconfiguration

```bash
NEURX_TENSOR_PARALLEL_SIZE=8             # TP English text
NEURX_PIPELINE_PARALLEL_SIZE=8           # PP English text
NEURX_MOE_EXPERT_PARALLEL_SIZE=16        # EP English text (256/16=16 experts/GPU)
NEURX_ZERO_STAGE=3                       # ZeRO phase
```

### trainingconfiguration

```bash
NEURX_PRETRAIN_STEPS=500000              # English textstepEnglish text (3T tokens)
NEURX_PRETRAIN_LR=0.0002                 # English textlearning rate
NEURX_PRETRAIN_MIN_LR=0.00002            # English textlearning rate
NEURX_PRETRAIN_WARMUP_STEPS=10000        # English textstepEnglish text
NEURX_PRETRAIN_WEIGHT_DECAY=0.01         # weightEnglish text
NEURX_PRETRAIN_MICRO_BATCH=2             # English text
NEURX_PRETRAIN_SEQ_LEN=4096              # English text
NEURX_PRETRAIN_GRAD_ACCUMULATION=8       # gradientEnglish textstepEnglish text
```

---

## 🔍 English text

### English text 1: S compileEnglish text
```
Error: S compiler not found
```
**English text**:
```bash
# English text S compileEnglish text
which s  # English textoutput /opt/s/bin/s

# English textpath
export S_COMPILER=/opt/s/bin/s
```

### English text 2: English texttrainingEnglish textstep
```
Error: NCCL operation timed out
```
**English text**:
```bash
# English text
ping $MASTER_ADDR

# English texttime
export NCCL_TIMEOUT=1800  # 30 English text

# English text P2P English text
export NCCL_P2P_DISABLE=1
```

### English text 3: GPU English text
```
Error: CUDA out of memory
```
**English text**:
- English text: `--batch-size 1`
- English text: `--seq-len 2048`
- English textgradientEnglish text: `--grad-accumulation 16`
- English text activation checkpointing (English text)

### English text 4: checkpointloadfailure
```
Error: Checkpoint format mismatch
```
**English text**:
```bash
# English textcheckpointcompleteEnglish text
ls -lh artifacts/checkpoints/

# English textcheckpoint
rm -f artifacts/checkpoints/corrupt_*.pt

# English textcheckpointrecover
export RESUME_CHECKPOINT=artifacts/checkpoints/step_100000.pt
```

---

## 📊 English texttest

### English text GPU English text (H100 80GB)

| English text | English text | English text |
|------|--------|------|
| English text | 2000 token/s | 0.5ms |
| English text | 1000 token/s | 1.0ms |
| AllGather (TP) | 500 token/s | 2.0ms |
| ReduceScatter (ZeRO) | 800 token/s | 1.25ms |

### English text (1024 GPU)

| English text | English text |
|------|-----|
| English text | 3000+ token/s |
| English text | < 20% |
| computeEnglish text | > 80% |
| English text | 75% (18-20GB / 80GB) |

### trainingtimeEnglish text

```
dataEnglish text: 3 trillion tokens
English text: 3000 token/s

English texttime = 3T tokens / 3000 token/s = 1M seconds = 11.6 days

actualtime = English texttime × (1/0.9) = 12.8 days (English text 90% English text)

optimizeEnglish text = ~4-6 days (English text + English textstepoptimize)
```

---

## 📖 English text

| English text | content | English text |
|------|------|------|
| **quickEnglish text** | API English text, English textexample | `QUICK_REFERENCE.md` |
| **English text** | English textstepEnglish text, completeEnglish text | `docs/INTEGRATION_GUIDE.md` |
| **implementationEnglish text** | English text, English text | `IMPLEMENTATION_SUMMARY.md` |
| **stateEnglish text** | English text, English text | `STATUS_REPORT.md` |

---

## 🎓 English text

### 4D English text

```
         DP=8 (dataEnglish text)
         ├─ GPU 0-7 (English text 0)
         ├─ GPU 8-15 (English text 1)
         └─ ...

         TP=8 (English text)
         ├─ [H/8] QKV weightEnglish text
         ├─ [4H/8] FFN weightEnglish text
         └─ AllGather/ReduceScatter English text

         PP=8 (English text)
         ├─ Layers 0-9 (GPU 0)
         ├─ Layers 10-19 (GPU 1)
         └─ ...

         EP=16 (English text)
         ├─ Experts 0-15 (GPU 0)
         ├─ Experts 16-31 (GPU 1)
         └─ All-to-All English text
```

### English text/English textdataEnglish text

**English text**:
1. AllGather (TP) → completeweight
2. QKV/Attention compute
3. All-to-All (MoE) → English text
4. FFN compute (TP English text)
5. ReduceScatter (TP) → outputEnglish text

**English text**:
1. gradientcompute (English text FFN, English text)
2. AllGather (TP) → completegradient
3. Async ReduceScatter (ZeRO3) → gradientEnglish text
4. optimizeEnglish text (Adam per-partition)

---

## 🔐 English text

- [ ] S compileEnglish text >= 2.0
- [ ] NCCL English text >= 2.14
- [ ] SLURM English textconfigurationEnglish text
- [ ] 1024 × H100 GPU English text
- [ ] 3TB NFS English text
- [ ] SSH English textconfiguration
- [ ] trainingdataEnglish text (8192 shards)
- [ ] recoverEnglish textconfiguration
- [ ] monitoringsystemEnglish text
- [ ] errorrecoverEnglish texttest

---

## 📞 English text

### English text
1. **modelEnglish text**: English textlearning rate, English text LR 50%
2. **GPU English text**: English text
3. **trainingEnglish text**: English text, English textstepEnglish text
4. **checkpointEnglish text**: English textrecover

### English text
- English text: English text `/docs` directory
- English text: English textfileEnglish text
- log: English text `artifacts/logs/` directory

---

**English text**: 1.0 (S languageimplementation)
**English text**: 2026-07-02
**English text**: neurx trainingframeworkEnglish text
