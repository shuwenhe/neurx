# trainingEnglish textoptimizeEnglish text

## 📊 English text

### English textconfiguration
- **GPU**: NVIDIA RTX 4060 Ti (16GBEnglish text)
- **model**: 1Tparameter (configurationfileEnglish text)
- **actualEnglish text**: ~2.5 tokens/step ⚠️ English text

### English text
```
RTX 4060 TiEnglish text:
├─ FP32English text: 10 TFLOPS
├─ BF16English text: 20 TFLOPS
├─ INT8English text: 40 TFLOPS
└─ English text:
    ├─ 1.5Bmodel: 500-1000 tokens/sec ✓
    ├─ 7Bmodel: 50-100 tokens/sec ⚠️ English text
    └─ 1Tmodel: 0.1-1 tokens/sec ❌ English text
```

### English text
```
configuration vs English text English text:

1. modelEnglish text
   ├─ configuration: 1Tparameter (1,000 billion)
   ├─ Required: ~4TBEnglish text (FP32) / ~1TB (BF16)
   └─ English text: 16GB ❌ English text62,500English text

2. English text
   ├─ configuration: world_size=1024, tensor_parallel=64
   ├─ English text: English texttraining1024English textGPU
   └─ actual: 1English textGPU ❌ English textconfiguration

3. English text
   ├─ global_batch: 4096
   ├─ micro_batch: 2
   ├─ accumulation: 512step
   └─ actualEnglish text: 16-32 ❌ English text

4. English textoptimize
   ├─ CPUEnglish text: English text (English text)
   ├─ gradientcheckpoint: English text (English textcompute)
   └─ ZeRO-3: English text (English text)
```

---

## 🚀 optimizeEnglish text

### English text1: useEnglish textmodelconfiguration (recommended)

**English text: 10-100English text**

```bash
# useoptimizeEnglish textconfiguration
cp config_optimized_4060ti.json train_config.yaml

# starttraining
make pretrain-gpu
```

**configurationEnglish text**:
```json
{
  "modelparameter": "1.5B (vs 1T)",
  "English text": "1024 (vs 12800)",
  "English text": "24 (vs 96)",
  "BatchEnglish text": "32 (vs 4096)",
  "MicroBatch": "4 (vs 2)",
  "gradientEnglish text": "8 (vs 512)",
  "world_size": "1 (vs 1024)",
  "English text": "BF16 (English text)",
  "gradientcheckpoint": "English text (English text)",
  "CPUEnglish text": "English text"
}
```

**English text**:
- **tokens/step**: 256-512 (vs 2.5)
- **English text**: 12-14GB (vs OOMEnglish text)
- **trainingEnglish text**: 250-500 tokens/sec
- **stepEnglish texttime**: 0.5-1 sec/step (vs English text)

---

### English text2: quickparameterEnglish text (English text1Tconfiguration)

English textuse1Tmodelconfiguration, English text:

#### English text1English text - English text (English textgradientEnglish text)
```bash
export NEURX_PRETRAIN_MICRO_BATCH=4
export NEURX_PRETRAIN_GRADIENT_ACCUMULATION=4
# English text: 3-5English text, tokens/step: 10-12
```

#### English text2English text - English text (English text)
```bash
export NEURX_MIXED_PRECISION=int8
export NEURX_ACTIVATION_CHECKPOINTING=1
# English text: English text3-5English text, tokens/step: 30-60
```

#### English text3English text - English textCPUEnglish text (English text)
```bash
export NEURX_CPU_OFFLOAD=1
export NEURX_CPU_OFFLOAD_DIR=/tmp/neurx_offload
mkdir -p /tmp/neurx_offload
# English text: English text2-3English text, tokens/step: 60-180
# English text: English textCPU↔GPUdataEnglish text, English text
```

---

### English text3: English texttraining (English text)

English textGPU:

```bash
# 4English textGPUtraining1Tmodel
export NEURX_HOSTFILE=configs/4gpu.hosts
cat > configs/4gpu.hosts << 'EOF'
localhost 4
EOF

bash scripts/legacy/launch_multinode_pretrain.sh

# English text:
# ├─ tokens/step: 100-200 (4English text)
# ├─ gradientEnglish textstepEnglish text: ~10-15%
# └─ English text: 400-800 tokens/sec
```

---

## 📈 English text (English textconfigurationEnglish text)

| model | English text | Batch | tokens/sec | steps/day |
|------|------|-------|-----------|----------|
| 1.5B (recommended) | 12GB | 32 | **300-500** | **25.9M** |
| 7B | 14GB | 16 | 80-120 | 6.9M |
| 13B | OOM | - | - | - |
| 1TEnglish text | OOM | - | **0.1-1** | **8.6k** |
| 1T 4English text | 4x16GB | 128 | 300-500 | 25.9M |

---

## 🔧 quickoptimizeEnglish text

### English text
```bash
cd /home/shuwen/shuwen/train/neurx

# English texttrainingEnglish text
tail -100 checkpoint/NeurX-1.3/rank_0.log | grep trainer-v2 | tail -5

# compute tokens/sec
# tokens = (step - prev_step) * seq_len
# English text: stepEnglish text9010English text9030 = 20step, 256 tokens/step
#     timeEnglish text = 30English text => 20*256/30 = 170 tokens/sec
```

### English textuseoptimizeconfiguration
```bash
# 1. English texttraining (Ctrl+C)
# 2. English textconfiguration
cat config_optimized_4060ti.json > train_config.yaml

# 3. English textcheckpointEnglish textstart
rm -f checkpoint/NeurX-1.3/transformer_v2.ckpt

# 4. English text
make pretrain-gpu
```

### monitoringEnglish text
```bash
# English text1: starttraining
make pretrain-gpu

# English text2: English textmonitoring
watch -n 10 'tail -20 checkpoint/NeurX-1.3/rank_0.log | grep trainer-v2'

# English text3: GPUmonitoring
watch -n 1 'nvidia-smi'
```

---

## 💡 English text?

### English text

**1TparametermodelRequiredEnglish text** (English text):
```
modelweight (BF16):      1T params * 2 bytes = 2TB
gradient:                2TB (English text)
optimizeEnglish textstate(AdamW):    2TB * 2 (m, v) = 4TB
English text:               ~200GB (batch=4096, seq=256)
English text:                ~8.2TB ❌❌❌
```

**RTX 4060 TiEnglish text: 16GB**

English textsystemEnglish text:
- ✗ English text (English textI/OEnglish text)
- ✗ gradientEnglish textCPUEnglish textGPUEnglish text (PCIe 3.0English text)
- ✗ modelweightEnglish textCPUEnglish text (English text)
- ✗ English textcomputeEnglish text (CPUtimeEnglish text)

**result**: English textstepEnglish textactualEnglish texttimeEnglish textcomputetime

### English textconfigurationEnglish text

**1.5BmodelEnglish text**:
```
modelweight:        1.5B * 2B = 3GB
gradient:            3GB
optimizeEnglish textstate:      6GB
English text:          2GB
English text:            14GB ✓ English text
```

**English text**:
- 1Tmodel: 16GBEnglish text99%English textI/OEnglish text
- 1.5Bmodel: 16GBEnglish text99%English textactualcompute

---

## 📋 English text

- [ ] English text (tokens/sec)
- [ ] English textoptimizeEnglish text (English text1recommended)
- [ ] English textcheckpoint
- [ ] English textconfiguration
- [ ] English texttraining
- [ ] monitoringEnglish text
- [ ] computeEnglish texttime

---

## English text

**Q: English text1TconfigurationEnglish text?**
A: AllowedEnglish textrecommended.RequiredEnglish text32English textGPUEnglish text.

**Q: English text1.5BEnglish text7BEnglish text?**
A: Allowed,English text14-15GB,English text100-200 tokens/sec.

**Q: English text?**
A: BF16English text,English text.FP8RequiredEnglish textsupport.

**Q: English textLoRA?**
A: English texttraining,English text.LoRAEnglish text.

---

## English textstep

1. **English text**: useEnglish text1 (optimizeconfiguration) - 10-100English text
2. **English text**: English textsupportEnglish textextensionEnglish text1T
3. **English text**: English textGPUEnglish textuseEnglish textcompute

English text 2.5 tokens/step English text 256-512 tokens/step! 🚀
