# trainingEnglish text

## English text make pretrain configuration

### ❌ default: make pretrain (CPUEnglish text)
```bash
make pretrain
```

**English textconfiguration:**
- ✓ English text: `scripts/legacy/minimal_train.s` (English textSlanguage, CPUcompute)
- ❌ English textuseGPU
- ❌ English textuseCUDA
- runEnglish text: English textCPUtraining (English texthangEnglish textstr_len())

**pipeline:**
```
make pretrain
  ↓ compile
scripts/legacy/minimal_train.s → minimal_train.ir
  ↓ run
S_RUNNER minimal_train.ir
  ↓ English text
CPUcompute (English textGPUEnglish text)
```

**English text:**
- str_len() functionEnglish texthang (English textbug)
- English text~147English text
- English textactualtraining

---

### ✅ GPUEnglish text: make pretrain-gpu (recommended)
```bash
make pretrain-gpu
```

**English textconfiguration:**
- ✓ English text: `scripts/legacy/pretrain_gpu.s` (Slanguage + CUDA)
- ✓ useGPUEnglish texttraining
- ✓ English textCUDAEnglish textfunction
- runEnglish text: GPUEnglish text

**pipeline:**
```
make pretrain-gpu
  ↓ GPUEnglish text (nvidia-smi)
NEURX_CUDA_DEVICE_COUNT English text
  ↓ compile
scripts/legacy/pretrain_gpu.s → pretrain_gpu.ir
  ↓ English textCUDAEnglish text
build-cuda-train-bridge
  ↓ run
S_RUNNER pretrain_gpu.ir
  ↓ GPUEnglish text
CUDAEnglish textfunction (cublasSgemm, relu, lossEnglish text)
```

**English text:**
- ✓ English textGPUcount
- ✓ English textCUDAEnglish textfunction
- ✓ supportEnglish textGPU
- ✓ English text

---

## English textstate

### scripts/legacy/gpu_train.s (English text - English text)
**state:** ✅ English textMakefile

- English text: `scripts/legacy/gpu_train.s` (500+ English text)
- English text: GPUtrainingcompleteimplementation (fileI/O + CUDA FFI)
- English text:
  - libcuda_kernels.so (English textgenerate)
  - libcuda_runtime.so (English textgenerate)
- compile: `s ir scripts/legacy/gpu_train.s -o artifacts/build/gpu_train.ir`
- state: English textcompileEnglish textrun

**English textpretrain_gpu.sEnglish text, English textMakefileEnglish text**

---

## quickEnglish text

| English text | make pretrain | make pretrain-gpu |
|------|---------------|-------------------|
| defaultEnglish text | ✓ English text | ❌ English text |
| English text | minimal_train.s | pretrain_gpu.s |
| CPUcompute | ✓ | ✓ (English text) |
| GPUcompute | ❌ | ✓ (English textfunction) |
| English text | English text | English text (10-100x) |
| English textbug | str_len()hang | English textbug |
| recommended | ❌ English text | ✓ English text |

---

## English text

### use CPU training (make pretrain)
```bash
make pretrain
```
**English text:**
- English texttest (English texthang)
- CPUEnglish text
- GPUEnglish text

**English text:** English textrun (str_len() bug)

### use GPU training (make pretrain-gpu) - recommended ⭐
```bash
make pretrain-gpu
```
**English text:**
- English text
- NVIDIA GPUEnglish text
- RequiredEnglish texttraining

**English text:**
- English textGPUEnglish text
- English text
- 10-100xEnglish text

---

## English text

### CPU path (make pretrain)
```
minimal_train.s
├─ runtime_read_text_file() → loadshard
├─ English text (Slanguage)
├─ parameterEnglish text
└─ CPUcompute
   └─ ❌ str_len() English texthang
```

### GPU path (make pretrain-gpu)
```
pretrain_gpu.s
├─ runtime_read_text_file() → loadshard
├─ English text (Slanguage)
├─ CUDAinitialize (cublasCreate)
├─ dataEnglish text → GPUEnglish text
├─ GPUcompute
│  ├─ cublasSgemm() - English text
│  ├─ cuda_relu_forward() - English text
│  ├─ cuda_error_loss_kernel() - loss
│  └─ cuda_sgd_update_kernel() - English text
└─ resultEnglish text → mainEnglish text
```

### GPU path (scripts/legacy/gpu_train.s - English text)
```
gpu_train.s (English text)
├─ completeEnglish textfileI/O
├─ GPUEnglish textmanagement
├─ English textmanagement (cuda_malloc/free)
├─ cuBLASEnglish text
└─ completeEnglish textCUDA FFIEnglish text
```

---

## compileEnglish text

### CPU English textcompile
```bash
s ir scripts/legacy/minimal_train.s -o artifacts/build/pretrain_orchestrator/minimal_train.ir
```

### GPU English textcompile
```bash
s ir scripts/legacy/pretrain_gpu.s -o artifacts/build/gpu_pretrain/pretrain_gpu.ir
```

### English textGPUEnglish textcompile
```bash
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:./artifacts/build/cuda_runtime:$LD_LIBRARY_PATH"
s ir scripts/legacy/gpu_train.s -o artifacts/build/gpu_train/gpu_train.ir
```

---

## English textconfiguration

### CPU training
```bash
export NEURX_PRETRAIN_MICRO_BATCH=4
export NEURX_PRETRAIN_SEQ_LEN=256
export NEURX_PRETRAIN_LR=0.0002
make pretrain
```

### GPU training
```bash
export NEURX_PRETRAIN_MICRO_BATCH=32    # GPUEnglish textbatch
export NEURX_PRETRAIN_SEQ_LEN=512       # English text
export NEURX_PRETRAIN_LR=0.0002
export NEURX_NUM_GPUS=1                 # English textGPUcount
make pretrain-gpu
```

---

## English textstepEnglish text

### English text
1. ✓ use `make pretrain-gpu` English textGPUtraining
2. ✓ CUDAEnglish textcompileEnglish text (libcuda_kernels.so, libcuda_runtime.so)
3. ✓ scripts/legacy/gpu_train.s English text

### English text
1. English text scripts/legacy/gpu_train.s English textMakefile
2. English text str_len() bug (make pretrainEnglish text)
3. English textoptimize (English text, gradientEnglish text)

### English text
1. English textGPUtraining
2. English texttraining (fp16)
3. English texttest

---

## English text

| English text | explanation |
|------|------|
| [CUDA_GPU_ARCHITECTURE.md](../CUDA_GPU_ARCHITECTURE.md) | GPUEnglish text |
| [S_CUDA_IMPLEMENTATION_GUIDE.md](../S_CUDA_IMPLEMENTATION_GUIDE.md) | S vs CUDA implementation |
| [cuda/BUILD_SYSTEM_S_LANGUAGE.md](BUILD_SYSTEM_S_LANGUAGE.md) | CUDAEnglish textsystem |
| [scripts/legacy/gpu_train.s](../scripts/legacy/gpu_train.s) | GPUtrainingEnglish text (English text) |
| [scripts/legacy/pretrain_gpu.s](../scripts/legacy/pretrain_gpu.s) | GPUtrainingEnglish text (English text) |

---

## quickstart

### GPUtraining (recommended)
```bash
# 1. English textGPU
nvidia-smi

# 2. English textCUDAsystem
make build-cuda-kernels
make build-cuda-runtime

# 3. startGPUtraining
make pretrain-gpu

# 4. monitoringtraining
tail -f checkpoint/NeurX-1.3/logs/pretrain_gpu_*.log
```

### CPUtraining (English text - English textbug)
```bash
# English textrun (str_len() hang)
# English text:
make pretrain
```

---

**English text:** 2026-07-13
**state:** ✅ GPUtrainingsystemcomplete, recommendeduse `make pretrain-gpu`
