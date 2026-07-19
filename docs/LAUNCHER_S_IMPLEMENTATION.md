# NeurX Launcher (S Language English text)

## fileexplanation

### 1. English textShellEnglish text(English text)
**file**: `scripts/legacy/launch_multinode_pretrain.sh`

**English textcontent**: English texttrainingEnglish textcheckpointpathEnglish text
```bash
# English text: English textrankEnglish text, English textcheckpointEnglish text
NEURX_PRETRAIN_RESUME_FROM=$OUT/rank_${rank}/transformer_v2.ckpt

# English text: English textrankEnglish text
if (( ${#HOSTS[@]} == 1 )); then
  ckpt_path="$OUT/transformer_v2.ckpt"
else
  ckpt_path="$OUT/rank_${rank}/transformer_v2.ckpt"
fi
```

---

### 2. SlanguagestartEnglish textframework
**file**: `scripts/legacy/launch_multinode_pretrain.s`

**English text**:
- English texthostfile
- configurationmanagementEnglish text
- English text
- English textstartEnglish text

**English text**:
- English textsafetyEnglish textconfigurationEnglish text
- English text
- English textextensionEnglish text

**compileEnglish textrun**:
```bash
# compile
cd /home/shuwen/shuwen/train/neurx
s compile scripts/legacy/launch_multinode_pretrain.s -o artifacts/build/launcher

# run
./artifacts/build/launcher
```

---

### 3. SlanguageEnglish textgenerateEnglish text(recommended)
**file**: `scripts/legacy/generate_launcher.s`

**English text**:
- English textconfiguration
- English textconfigurationparameter
- generateoptimizeEnglish textshellEnglish text
- English textcomputeworld_size

**English text**:
- configurationEnglish text
- English textparameter
- generateEnglish textshellEnglish text

**usepipeline**:
```bash
# 1. compilegenerateEnglish text
cd /home/shuwen/shuwen/train/neurx
s compile scripts/legacy/generate_launcher.s -o artifacts/build/generate_launcher

# 2. generateEnglish text
NEURX_ROOT=$(pwd) ./artifacts/build/generate_launcher

# 3. English textgenerateEnglish text
bash scripts/legacy/launch_multinode_pretrain_generated.sh
```

---

## quickstart(English text)

### English texttraining(recommendedEnglish text)
```bash
cd /home/shuwen/shuwen/train/neurx

# English text1: useEnglish textshellEnglish text
make pretrain-gpu

# English text2: English text
bash scripts/legacy/launch_multinode_pretrain.sh
```

**outputEnglish text**:
```
[trainer-v2] rank=0 world_size=1 local_rank=0 shards=5131 checkpoint=/home/shuwen/shuwen/train/neurx/checkpoint/NeurX-1.3
[checkpoint] restored v2 step=360 shard=0 line=2 micro=0  ← English textsuccess!
[trainer-v2] tokenizer=bpe vocab=374 layers=24 seq=256 dim=1024 heads=16 ffn=4096 micro_batch=1 grad_accum=8 effective_sequences=8
[trainer-v2] step=360/1000000000 optimizer_step=45 loss=12.482535 tokens=92160 shard=0 line=2 accum=0/8  ← English text360stepEnglish text
```

### English texttraining
```bash
# English texthostfile
cat > configs/pretrain.hosts << 'EOF'
node1 8
node2 8
node3 8
EOF

# starttraining
NEURX_HOSTFILE=$(pwd)/configs/pretrain.hosts bash scripts/legacy/launch_multinode_pretrain.sh
```

---

## English textconfiguration

### English textparameter
```bash
NEURX_ROOT                      # NeurXEnglish textdirectory
NEURX_HOSTFILE                  # Hostfilepath
NEURX_PRETRAIN_OUTPUT_DIR       # Checkpointsavedirectory
```

### English textparameter(English textdefaultEnglish text)
```bash
# trainingconfiguration
NEURX_PRETRAIN_STEPS=1000000000
NEURX_PRETRAIN_MICRO_BATCH=1
NEURX_PRETRAIN_SEQ_LEN=256
NEURX_PRETRAIN_LR=0.0002
NEURX_PRETRAIN_LOG_INTERVAL=10
NEURX_PRETRAIN_SAVE_INTERVAL=100

# modelconfiguration
NEURX_TRANSFORMER_DIM=1024
NEURX_TRANSFORMER_HEADS=16
NEURX_TRANSFORMER_FFN=4096
NEURX_TRANSFORMER_NUM_LAYERS=24
NEURX_GRADIENT_ACCUMULATION_STEPS=8

# Tokenizer
NEURX_TOKENIZER_VOCAB=${NEURX_ROOT}/data/corpus/vocab.json
NEURX_TOKENIZER_MERGES=${NEURX_ROOT}/data/corpus/merges.txt

# English text
MASTER_ADDR=localhost
MASTER_PORT=29500
```

---

## English text

### English textCheckpointfile
```bash
# English textcheckpointEnglish text
ls -lh checkpoint/NeurX-1.3/transformer_v2.ckpt

# English textcheckpointEnglish text
ls -lh checkpoint/NeurX-1.3/rank_0/transformer_v2.ckpt
ls -lh checkpoint/NeurX-1.3/rank_1/transformer_v2.ckpt
```

### English text
```bash
# English textactualEnglish textNEURX_PRETRAIN_RESUME_FROMEnglish text
echo $NEURX_PRETRAIN_RESUME_FROM

# English textstartEnglish text
grep "NEURX_PRETRAIN_RESUME_FROM" scripts/legacy/launch_multinode_pretrain.sh
```

### monitoringtraininglog
```bash
# English text
tail -f checkpoint/NeurX-1.3/rank_0.log | grep -E "(checkpoint|trainer-v2|step=)"

# English text
tail -f checkpoint/NeurX-1.3/rank_*/rank_*.log
```

---

## English text

| English text | ShellEnglish text | SlanguageEnglish text | SgenerateEnglish text |
|------|---------|---------|--------|
| English text | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| English textsafety | ❌ | ✅ | ✅ |
| parameterEnglish text | English text | English text | English text |
| English text | English text | English text | English text |
| English text | English text | English text | English text |
| extensionEnglish text | English text | English text | English text |

---

## English text

### English text1: English text(step=1)

**English text**:
```
[trainer-v2] step=1/1000000000 ...  ← English textstep=1start, English text
```

**English text**: CheckpointpathEnglish text

**English text**:
```bash
# English textcheckpointfileEnglish text
ls -lh checkpoint/NeurX-1.3/transformer_v2.ckpt

# English textlauncherEnglish textNEURX_PRETRAIN_RESUME_FROM
grep "ckpt_path" scripts/legacy/launch_multinode_pretrain.sh

# English textrankEnglish text
# ✅ English text: $OUT/transformer_v2.ckpt
# ❌ error: $OUT/rank_0/transformer_v2.ckpt
```

### English text2: NCCLinitializeEnglish text

**English text**:
```
[multinode] shared NCCL id: /path/to/unique_id
# English text60English text...
```

**English text**:
```bash
# English textNCCL IDfileEnglish text
ls -l artifacts/nccl/unique_id

# English text
rm -f artifacts/nccl/unique_id*

# English texttraining
make pretrain-gpu
```

### English text3: GPUEnglish text

**English text**:
```
CUDA error: out of memory
```

**English text**:
```bash
# English textmicro_batchEnglish textseq_len
NEURX_PRETRAIN_MICRO_BATCH=1 \
NEURX_PRETRAIN_SEQ_LEN=128 \
make pretrain-gpu
```

---

## English textoptimizeEnglish text

1. **English textGPU**: use `scripts/legacy/launch_multinode_pretrain.sh`, world_sizeEnglish text
2. **English text**: useEnglish text(InfiniBand)English text `NCCL_SOCKET_IFNAME`
3. **English textmodel**: English text: `NEURX_MIXED_PRECISION=bf16`
4. **dataload**: useSSDEnglish textshards, English textstepdataload

---

## SlanguageEnglish text

| English text | Shell | Slanguage |
|------|-------|-------|
| **English text** | ❌ | ✅ compileEnglish text |
| **parameterEnglish text** | English text | English text |
| **configurationmanagement** | English text | English text |
| **errorEnglish text** | try-catchEnglish text | English text |
| **English text** | English text | English textCEnglish text |
| **English text** | English text | English text |

recommendeduse **SgenerateEnglish text**: English textSEnglish textmanagementEnglish text, generateoptimizeEnglish textshellEnglish text.
