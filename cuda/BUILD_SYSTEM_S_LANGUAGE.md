# CUDA Build System - S Language Implementation

English textdirectoryEnglish textSlanguageimplementationEnglish textCUDAEnglish textsystem, **English textbashEnglish text**.

## 🎯 English text

| English textfile | English textimplementation | English text |
|---------|-------|------|
| `build_kernels_simple.sh` | `build_kernels_simple.s` | compileCUDA GPUEnglish textfunction |
| `build_cuda_runtime.sh` | `build_cuda_runtime.s` | compileCUDArunEnglish text |
| `build_cuda_runtime_alt.sh` | `build_cuda_runtime.s` | (English text) |
| `build.sh` | `build_cuda.s` | mainEnglish textmanagementEnglish text |
| `verify_environment.sh` | `verify_environment.s` | English text |

**English text:**
- ✅ English textSlanguageimplementation, English textprinciple
- ✅ English textshellEnglish text (no bash/sh)
- ✅ English textPythonEnglish text
- ✅ English text, English text

## 📦 quickstart

### English text1: English textrunSEnglish text

```bash
# compileCUDAEnglish textfunction
s ir cuda/build_kernels_simple.s

# compilerunEnglish text
s ir cuda/build_cuda_runtime.s

# English text
s ir cuda/clean_build.s
```

### English text2: useEnglish textmanagementEnglish text

```bash
# compileEnglish text
CUDA_TARGET=build-all s_runner <(s ir cuda/build_cuda.s -o /tmp/build_cuda.ir)

# English textcompileEnglish textfunction
CUDA_TARGET=build-kernels s_runner <(s ir cuda/build_cuda.s -o /tmp/build_cuda.ir)

# English textcompilerunEnglish text
CUDA_TARGET=build-runtime s_runner <(s ir cuda/build_cuda.s -o /tmp/build_cuda.ir)

# English text
CUDA_TARGET=verify-env s_runner <(s ir cuda/build_cuda.s -o /tmp/build_cuda.ir)

# English text
CUDA_TARGET=clean s_runner <(s ir cuda/build_cuda.s -o /tmp/build_cuda.ir)
```

### English text3: useMakefileEnglish text

English textMakefileEnglish text:

```makefile
.PHONY: build-cuda-kernels build-cuda-runtime cuda-clean cuda-verify

build-cuda-kernels:
	s ir cuda/build_kernels_simple.s -o artifacts/build/build_kernels.ir
	s_runner artifacts/build/build_kernels.ir

build-cuda-runtime:
	s ir cuda/build_cuda_runtime.s -o artifacts/build/build_runtime.ir
	s_runner artifacts/build/build_runtime.ir

cuda-clean:
	s ir cuda/clean_build.s -o artifacts/build/clean_build.ir
	s_runner artifacts/build/clean_build.ir

cuda-verify:
	CUDA_TARGET=verify-env s ir cuda/build_cuda.s -o artifacts/build/verify_cuda.ir
	CUDA_TARGET=verify-env s_runner artifacts/build/verify_cuda.ir
```

## 📄 English textexplanation

### `build_kernels_simple.s` - compileGPUEnglish textfunction

**English text:**
- English textnvcccompileEnglish text
- generatePTXEnglish text(English textglibcEnglish text)
- compileCEnglish text
- English textlibcuda_kernels.so

**output:**
```
artifacts/build/cuda_kernels/libcuda_kernels.so (16KB)
artifacts/build/cuda_kernels/env.sh             (English text)
```

**English text:**
```s
1. English textnvcc → which nvcc
2. English textGPUEnglish text → nvidia-smi compute_cap
3. compilePTX → nvcc -ptx cuda/cuda_kernels.cu
4. compileEnglish text → gcc -c cuda_kernels_wrapper.c
5. English text → gcc -shared libcuda_kernels.so
```

### `build_cuda_runtime.s` - compilerunEnglish text

**English text:**
- compileCUDArunEnglish text+cuBLASEnglish text
- English text

**output:**
```
artifacts/build/cuda_runtime/libcuda_runtime.so (15KB)
artifacts/build/cuda_runtime/env.sh
```

### `clean_build.s` - English text

**English text:**
- English textcompileoutput
- English textstate

**English textdirectory:**
```
artifacts/build/cuda_kernels/
artifacts/build/cuda_runtime/
artifacts/build/verify_env/
```

### `verify_environment.s` - English textCUDAEnglish text

**English text:**
- ✓ nvcccompileEnglish text
- ✓ CUDArunEnglish text
- ✓ cuBLASEnglish text
- ✓ GPUEnglish text

### `build_cuda.s` - English textmanagementEnglish text

**supportEnglish text:**
- `build-all` - compileEnglish text (default)
- `build-kernels` - English textfunction
- `build-runtime` - English textrunEnglish text
- `build-verify` - English text
- `clean` - English text
- `verify-env` - English text

## 🔧 English text

| English text | explanation | example |
|-----|------|------|
| `S_COMPILER` | SlanguagecompileEnglish textpath | `/home/shuwen/.local/bin/s` |
| `CUDA_HOME` | CUDAEnglish textpath | `/usr/local/cuda` |
| `CUDA_TARGET` | English text | `build-all` |
| `LD_LIBRARY_PATH` | English textsearchpath | (English text) |

## 📊 compilepipeline

### English textfunctioncompile (3step)
```
.cuEnglish textfile
    ↓ nvcc -ptx
PTXEnglish text (.ptx)
    ↓ English textCEnglish text (.c)
CEnglish textfile (.o)
    ↓ gcc -shared
libcuda_kernels.so ✓
```

### runEnglish textcompile (2step)
```
CEnglish textfile (.cu/.c)
    ↓ gcc -shared -lcudart -lcublas
libcuda_runtime.so ✓
```

## 🚀 completeEnglish text

### 1. English text
```bash
s ir cuda/verify_environment.s
```

### 2. English text
```bash
s ir cuda/clean_build.s
```

### 3. compileEnglish textfunction
```bash
s ir cuda/build_kernels_simple.s
```

### 4. compilerunEnglish text
```bash
s ir cuda/build_cuda_runtime.s
```

### 5. compiletrainingEnglish text
```bash
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:./artifacts/build/cuda_runtime:$LD_LIBRARY_PATH"
s ir scripts/legacy/gpu_train.s -o artifacts/build/gpu_train.ir
```

### 6. runtraining
```bash
source ./artifacts/build/cuda_kernels/env.sh
s_runner artifacts/build/gpu_train.ir
```

## 🔍 English text

### English text: "nvcc not found"
```bash
# English text: English textCUDA Toolkit English textpath
export PATH="/usr/local/cuda/bin:$PATH"
```

### English text: "libcuda_kernels.so not created"
```bash
# English text: compileEnglish textoutput
s ir cuda/build_kernels_simple.s 2>&1 | grep ERROR
```

### English text: "LD_LIBRARY_PATH issue"
```bash
# English text: English text
source ./artifacts/build/cuda_kernels/env.sh
source ./artifacts/build/cuda_runtime/env.sh
```

## 📝 SEnglish text

### English text
- ✅ English text, English text
- ✅ English text
- ✅ compileEnglish text, English textquick
- ✅ English text

### English textbashEnglish text

| Bash | Slanguage |
|------|-------|
| `if command -v X` | `contains_string(output, "not_found")` |
| `export VAR=val` | `runtime_env_get("VAR", default)` |
| `mkdir -p` | `runtime_run_command_output("mkdir -p")` |
| `grep/awk` | `substring()`, `contains_string()` |
| `${VAR}` | `runtime_env_get("VAR")` |
| `echo "text"` | `println("text")` |

## 🎓 English textexample

### English text
```s
string output = runtime_run_command_output("nvcc --version 2>/dev/null")
```

### English textfileEnglish text
```s
if runtime_file_exists(build_dir + "/libcuda_kernels.so") {
    println("[SUCCESS]")
}
```

### English text
```s
string trimmed = trim(output)  // English text
bool found = contains_string(output, "error")
```

### English text
```s
string cuda_home = runtime_env_get("CUDA_HOME", "/usr/local/cuda")
```

## 📦 outputfileEnglish text

compileEnglish text:
```
artifacts/build/
├── cuda_kernels/
│   ├── libcuda_kernels.so      ← GPUEnglish textfunctionEnglish text
│   ├── cuda_kernels.ptx        ← PTXEnglish text
│   ├── cuda_kernels_wrapper.c  ← CEnglish text
│   ├── cuda_kernels_wrapper.o  ← English textfile
│   └── env.sh                  ← English textconfiguration
│
└── cuda_runtime/
    ├── libcuda_runtime.so      ← runEnglish text
    └── env.sh                  ← English textconfiguration
```

## ✅ English text

```bash
# English textfile
ls -lh artifacts/build/cuda_kernels/libcuda_kernels.so
ls -lh artifacts/build/cuda_runtime/libcuda_runtime.so

# testEnglish text
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:./artifacts/build/cuda_runtime:$LD_LIBRARY_PATH"
ldd artifacts/build/cuda_kernels/libcuda_kernels.so
ldd artifacts/build/cuda_runtime/libcuda_runtime.so
```

## 🔄 English textMakefile

```makefile
# CUDA Build Targets (S Language)
.PHONY: cuda-build cuda-kernels cuda-runtime cuda-clean cuda-verify

cuda-build: cuda-kernels cuda-runtime cuda-verify

cuda-kernels:
	@echo "[BUILD] CUDA Kernels"
	@s ir cuda/build_kernels_simple.s

cuda-runtime:
	@echo "[BUILD] CUDA Runtime"
	@s ir cuda/build_cuda_runtime.s

cuda-clean:
	@echo "[CLEAN] CUDA Build"
	@s ir cuda/clean_build.s

cuda-verify:
	@echo "[VERIFY] CUDA Environment"
	@CUDA_TARGET=verify-env s ir cuda/build_cuda.s
```

## 📚 English textfile

- [CUDA_GPU_ARCHITECTURE.md](../CUDA_GPU_ARCHITECTURE.md) - English text
- [S_CUDA_IMPLEMENTATION_GUIDE.md](../S_CUDA_IMPLEMENTATION_GUIDE.md) - implementationEnglish text
- [scripts/legacy/gpu_train.s](../scripts/legacy/gpu_train.s) - GPUtrainingEnglish text
- [cuda/cuda_kernels.cu](cuda_kernels.cu) - CUDAEnglish textfunctionEnglish text

## 📋 English text

| English text | bash | Slanguage |
|------|------|--------|
| English text | ✅ | ❌ |
| PythonEnglish text | ⚠️ English text | ❌ |
| English text | ⚠️ | ✅ |
| English text | ⚠️ | ✅ |
| English text | ❌ | ✅ |
| English text | ⚠️ | ✅ |

**English text:** SlanguageimplementationEnglish text, English text, English textsystem.

---

**Author:** NeurX Project
**Date:** 2026-07-13
**Status:** ✅ Production Ready
