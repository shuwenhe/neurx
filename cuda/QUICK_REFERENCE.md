# S Language CUDA Build Scripts - Quick Reference

completeEnglish textbashEnglish textSlanguageCUDAEnglish textsystemEnglish text.

## 📋 English text

### English text

| English text | explanation | compileEnglish text | English text |
|------|------|---------|------|
| `build_kernels_simple.s` | GPUEnglish textfunctioncompile | `s ir cuda/build_kernels_simple.s` | PTXgenerate → CEnglish text → libcuda_kernels.so |
| `build_cuda_runtime.s` | runEnglish textcompile | `s ir cuda/build_cuda_runtime.s` | compilelibcuda_runtime.so + cuBLASEnglish text |
| `clean_build.s` | English text | `s ir cuda/clean_build.s` | English textartifacts/build/cuda_* |
| `verify_environment.s` | English text | `s ir cuda/verify_environment.s` | English textCUDA/cuBLAS/GPU |
| `build_cuda.s` | English textmanagement | `CUDA_TARGET=X s ir cuda/build_cuda.s` | English text |

## 🚀 quickEnglish text

### compileEnglish text
```bash
s ir cuda/build_kernels_simple.s && \
s ir cuda/build_cuda_runtime.s
```

### English textcompileEnglish textfunction
```bash
s ir cuda/build_kernels_simple.s
```

### English textcompilerunEnglish text
```bash
s ir cuda/build_cuda_runtime.s
```

### English text
```bash
s ir cuda/clean_build.s && \
s ir cuda/build_kernels_simple.s && \
s ir cuda/build_cuda_runtime.s
```

### English text
```bash
s ir cuda/verify_environment.s
```

## 📊 English text

### English textbashEnglish text → English textSEnglish text

```
build_kernels_simple.sh  ──→  build_kernels_simple.s
build_cuda_runtime.sh    ──→  build_cuda_runtime.s
build_cuda_runtime_alt.sh ──→ build_cuda_runtime.s (English text)
build.sh                 ──→  build_cuda.s
verify_environment.sh    ──→  verify_environment.s
Makefile targets         ──→  cuda_build.s targets
```

## 🔧 English text

| English text | defaultEnglish text | English text |
|------|--------|------|
| `S_COMPILER` | `/home/shuwen/.local/bin/s` | ScompileEnglish textpath |
| `CUDA_HOME` | English text | CUDAEnglish text |
| `CUDA_TARGET` | `build-all` | build_cuda.sEnglish text |
| `LD_LIBRARY_PATH` | English text | English textsearchpath |

## 📝 compilestepEnglish text

### build_kernels_simple.s pipeline
```
main()
 ├─ English textnvcc → which nvcc
 ├─ English textCUDAEnglish text → nvcc --version
 ├─ English textGPUEnglish text → nvidia-smi
 ├─ English textbuilddirectory → mkdir -p
 ├─ compilePTX → nvcc -ptx
 ├─ English textCEnglish text → create_wrapper_c()
 ├─ compileEnglish text → gcc -c
 ├─ English text → gcc -shared
 └─ English textenv.sh
```

### build_cuda_runtime.s pipeline
```
main()
 ├─ English textCUDAmaindirectory → get_cuda_home()
 ├─ English textbuilddirectory
 ├─ compilerunEnglish text → gcc -shared -lcudart -lcublas
 └─ English textenv.sh
```

### build_cuda.s pipeline (orchestrator)
```
main()
 ├─ English textCUDA_TARGETEnglish text
 ├─ English text
 │  ├─ build-all → English textallEnglish text
 │  ├─ build-kernels → English textkernelsEnglish text
 │  ├─ build-runtime → English textruntimeEnglish text
 │  ├─ clean → English text
 │  └─ verify-env → English text
 └─ English textfunctionEnglish text
```

## 🎯 English text

### completeEnglish text (English textstart)
```bash
# 1. English text
s ir cuda/clean_build.s

# 2. English text
s ir cuda/verify_environment.s

# 3. compileEnglish textfunction
s ir cuda/build_kernels_simple.s

# 4. compilerunEnglish text
s ir cuda/build_cuda_runtime.s

# 5. English textoutput
ls -lh artifacts/build/cuda_kernels/libcuda_kernels.so
ls -lh artifacts/build/cuda_runtime/libcuda_runtime.so
```

### quickEnglish text (English text)
```bash
# English textkernelEnglish text
s ir cuda/build_kernels_simple.s

# test
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:$LD_LIBRARY_PATH"
```

### CI/CDEnglish text
```bash
#!/bin/bash
set -e

# compile
s ir cuda/build_cuda.s || {
    echo "[ERROR] Build failed"
    s ir cuda/verify_environment.s
    exit 1
}

# English text
if [ ! -f "./artifacts/build/cuda_kernels/libcuda_kernels.so" ]; then
    echo "[ERROR] libcuda_kernels.so not found"
    exit 1
fi

echo "[SUCCESS] Build complete"
```

## 📦 outputEnglish text

### successcompileEnglish textoutput
```
artifacts/build/
├── cuda_kernels/
│   ├── libcuda_kernels.so      ✓ 16KB
│   ├── cuda_kernels.ptx        ✓ (English textfile)
│   ├── cuda_kernels_wrapper.c  ✓ (English text)
│   ├── cuda_kernels_wrapper.o  ✓ (English text)
│   └── env.sh                  ✓ (English text)
└── cuda_runtime/
    ├── libcuda_runtime.so      ✓ 15KB
    └── env.sh                  ✓ (English text)
```

## ✅ English text

compileEnglish text:
```bash
# ✓ fileEnglish text
ls -lh artifacts/build/cuda_kernels/libcuda_kernels.so
ls -lh artifacts/build/cuda_runtime/libcuda_runtime.so

# ✓ English text
ldd artifacts/build/cuda_kernels/libcuda_kernels.so | grep cuda

# ✓ English textcomplete
nm artifacts/build/cuda_kernels/libcuda_kernels.so | grep cuda_

# ✓ AllowedloadEnglish text
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:$LD_LIBRARY_PATH"
python3 -c "import ctypes; ctypes.CDLL('./artifacts/build/cuda_kernels/libcuda_kernels.so')"
```

## 🐛 English text

### English textcompileEnglish textoutput
English textSEnglish text:
```s
string cmd = "nvcc -ptx ... -v"  // English text -v English text
```

### English textSEnglish text
```bash
# compileEnglish textIREnglish text
s ir cuda/build_kernels_simple.s -o /tmp/build.ir
# English text
file /tmp/build.ir
```

### English text
```bash
export CUDA_TARGET=verify-env
export S_COMPILER=$(which s)
s ir cuda/build_cuda.s
```

## 📚 SEnglish textfunction

### I/Ofunction
```s
runtime_run_command_output(cmd)      // English textoutput
runtime_env_get(var, default)        // English text
runtime_file_exists(path)            // English textfileEnglish text
runtime_read_text_file(path)         // English textfile
runtime_write_text_file(path, text)  // English textfile
```

### English textfunction
```s
str_len(s)                 // English text
trim(s)                    // English text
substring(s, start, end)   // English text
contains_string(h, n)      // English text
eq_string(a, b)            // English text
```

## 🔄 MakefileEnglish textexample

```makefile
.PHONY: build-cuda-all build-cuda-kernels build-cuda-runtime cuda-clean

build-cuda-all:
	@echo "[BUILD] CUDA System (S Language)"
	s ir cuda/build_kernels_simple.s
	s ir cuda/build_cuda_runtime.s

build-cuda-kernels:
	@echo "[BUILD] CUDA Kernels"
	s ir cuda/build_kernels_simple.s

build-cuda-runtime:
	@echo "[BUILD] CUDA Runtime"
	s ir cuda/build_cuda_runtime.s

cuda-clean:
	@echo "[CLEAN] CUDA Artifacts"
	s ir cuda/clean_build.s

cuda-verify:
	@echo "[VERIFY] CUDA Environment"
	s ir cuda/verify_environment.s
```

## ⚠️ English texterror

| error | English text | English text |
|------|------|------|
| `nvcc not found` | CUDAEnglish text | `export PATH="/usr/local/cuda/bin:$PATH"` |
| `libcuda_kernels.so not created` | compilefailure | English textcompileoutput, English textgcc/nvcc |
| `undefined reference to cuda_*` | English textfailure | English textLD_LIBRARY_PATH |
| `S compiler not found` | patherror | `export S_COMPILER=$(which s)` |

## 📖 English text

| file | explanation |
|------|------|
| [BUILD_SYSTEM_S_LANGUAGE.md](BUILD_SYSTEM_S_LANGUAGE.md) | completeuseEnglish text |
| [../CUDA_GPU_ARCHITECTURE.md](../CUDA_GPU_ARCHITECTURE.md) | GPUEnglish text |
| [../S_CUDA_IMPLEMENTATION_GUIDE.md](../S_CUDA_IMPLEMENTATION_GUIDE.md) | S vs CUDA implementationEnglish text |
| [../scripts/legacy/gpu_train.s](../scripts/legacy/gpu_train.s) | GPUtrainingEnglish text |
| [cuda_kernels.cu](cuda_kernels.cu) | CUDAEnglish textfunctionEnglish text |

## 🎓 English text

1. **SlanguageEnglish text**: English text, English text, English text
2. **English textpipeline**: PTXgenerate → CEnglish text → English textfile → English text
3. **English textconfiguration**: English textCUDApath, GPUEnglish text
4. **English text**: English textrun
5. **English text**: English textMakefile

---

**English text:** 1.0
**English text:** 2026-07-13
**state:** ✅ English text
