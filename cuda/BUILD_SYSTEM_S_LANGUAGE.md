# CUDA Build System - S Language Implementation

本目录包含纯S语言实现的CUDA构建系统，**完全替代了所有bash脚本**。

## 🎯 核心改变

| 原始文件 | 新实现 | 功能 |
|---------|-------|------|
| `build_kernels_simple.sh` | `build_kernels_simple.s` | 编译CUDA GPU核函数 |
| `build_cuda_runtime.sh` | `build_cuda_runtime.s` | 编译CUDA运行时库 |
| `build_cuda_runtime_alt.sh` | `build_cuda_runtime.s` | (合并) |
| `build.sh` | `build_cuda.s` | 主构建管理器 |
| `verify_environment.sh` | `verify_environment.s` | 环境检查 |

**关键优势:**
- ✅ 纯S语言实现，符合项目自举原则
- ✅ 无shell脚本依赖 (no bash/sh)
- ✅ 与Python完全隔离
- ✅ 代码清晰，易于维护

## 📦 快速开始

### 方式1: 直接运行S脚本

```bash
# 编译CUDA核函数
s ir cuda/build_kernels_simple.s

# 编译运行时
s ir cuda/build_cuda_runtime.s

# 清理构建
s ir cuda/clean_build.s
```

### 方式2: 使用综合管理器

```bash
# 编译全部
CUDA_TARGET=build-all s_runner <(s ir cuda/build_cuda.s -o /tmp/build_cuda.ir)

# 仅编译核函数
CUDA_TARGET=build-kernels s_runner <(s ir cuda/build_cuda.s -o /tmp/build_cuda.ir)

# 仅编译运行时
CUDA_TARGET=build-runtime s_runner <(s ir cuda/build_cuda.s -o /tmp/build_cuda.ir)

# 验证环境
CUDA_TARGET=verify-env s_runner <(s ir cuda/build_cuda.s -o /tmp/build_cuda.ir)

# 清理构建
CUDA_TARGET=clean s_runner <(s ir cuda/build_cuda.s -o /tmp/build_cuda.ir)
```

### 方式3: 使用Makefile集成

在项目Makefile中添加:

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

## 📄 各脚本说明

### `build_kernels_simple.s` - 编译GPU核函数

**功能:**
- 检测nvcc编译器
- 生成PTX中间代码（避免glibc冲突）
- 编译C包装层
- 链接libcuda_kernels.so

**输出:**
```
artifacts/build/cuda_kernels/libcuda_kernels.so (16KB)
artifacts/build/cuda_kernels/env.sh             (环境变量设置)
```

**核心代码流:**
```s
1. 检查nvcc → which nvcc
2. 获取GPU架构 → nvidia-smi compute_cap
3. 编译PTX → nvcc -ptx cuda/cuda_kernels.cu
4. 编译包装 → gcc -c cuda_kernels_wrapper.c
5. 链接库 → gcc -shared libcuda_kernels.so
```

### `build_cuda_runtime.s` - 编译运行时

**功能:**
- 编译CUDA运行时+cuBLAS包装
- 创建环境脚本

**输出:**
```
artifacts/build/cuda_runtime/libcuda_runtime.so (15KB)
artifacts/build/cuda_runtime/env.sh
```

### `clean_build.s` - 清理构建

**功能:**
- 删除所有编译输出
- 重置构建状态

**删除的目录:**
```
artifacts/build/cuda_kernels/
artifacts/build/cuda_runtime/
artifacts/build/verify_env/
```

### `verify_environment.s` - 验证CUDA环境

**检查项:**
- ✓ nvcc编译器
- ✓ CUDA运行时库
- ✓ cuBLAS库
- ✓ GPU设备

### `build_cuda.s` - 综合管理器

**支持的目标:**
- `build-all` - 编译全部 (默认)
- `build-kernels` - 仅核函数
- `build-runtime` - 仅运行时
- `build-verify` - 仅验证脚本
- `clean` - 清理所有
- `verify-env` - 验证环境

## 🔧 环境变量

| 变量 | 说明 | 示例 |
|-----|------|------|
| `S_COMPILER` | S语言编译器路径 | `/home/shuwen/.local/bin/s` |
| `CUDA_HOME` | CUDA安装路径 | `/usr/local/cuda` |
| `CUDA_TARGET` | 构建目标 | `build-all` |
| `LD_LIBRARY_PATH` | 库搜索路径 | (自动设置) |

## 📊 编译流程

### 核函数编译 (3步)
```
.cu源文件
    ↓ nvcc -ptx
PTX中间代码 (.ptx)
    ↓ 创建C包装 (.c)
C对象文件 (.o)
    ↓ gcc -shared
libcuda_kernels.so ✓
```

### 运行时编译 (2步)
```
C包装源文件 (.cu/.c)
    ↓ gcc -shared -lcudart -lcublas
libcuda_runtime.so ✓
```

## 🚀 完整工作流

### 1. 验证环境
```bash
s ir cuda/verify_environment.s
```

### 2. 清理旧构建
```bash
s ir cuda/clean_build.s
```

### 3. 编译核函数
```bash
s ir cuda/build_kernels_simple.s
```

### 4. 编译运行时
```bash
s ir cuda/build_cuda_runtime.s
```

### 5. 编译训练脚本
```bash
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:./artifacts/build/cuda_runtime:$LD_LIBRARY_PATH"
s ir scripts/legacy/gpu_train.s -o artifacts/build/gpu_train.ir
```

### 6. 运行训练
```bash
source ./artifacts/build/cuda_kernels/env.sh
s_runner artifacts/build/gpu_train.ir
```

## 🔍 故障排除

### 问题: "nvcc not found"
```bash
# 解决: 安装CUDA Toolkit 或设置路径
export PATH="/usr/local/cuda/bin:$PATH"
```

### 问题: "libcuda_kernels.so not created"
```bash
# 检查: 编译器输出
s ir cuda/build_kernels_simple.s 2>&1 | grep ERROR
```

### 问题: "LD_LIBRARY_PATH issue"
```bash
# 解决: 手动设置
source ./artifacts/build/cuda_kernels/env.sh
source ./artifacts/build/cuda_runtime/env.sh
```

## 📝 S脚本特点

### 优点
- ✅ 自包含，无外部依赖
- ✅ 跨平台兼容性更好
- ✅ 编译为字节码，执行快速
- ✅ 符合项目自举哲学

### 与bash的对应关系

| Bash | S语言 |
|------|-------|
| `if command -v X` | `contains_string(output, "not_found")` |
| `export VAR=val` | `runtime_env_get("VAR", default)` |
| `mkdir -p` | `runtime_run_command_output("mkdir -p")` |
| `grep/awk` | `substring()`, `contains_string()` |
| `${VAR}` | `runtime_env_get("VAR")` |
| `echo "text"` | `println("text")` |

## 🎓 代码示例

### 调用外部命令
```s
string output = runtime_run_command_output("nvcc --version 2>/dev/null")
```

### 检查文件存在
```s
if runtime_file_exists(build_dir + "/libcuda_kernels.so") {
    println("[SUCCESS]")
}
```

### 字符串处理
```s
string trimmed = trim(output)  // 移除空格
bool found = contains_string(output, "error")
```

### 环境变量
```s
string cuda_home = runtime_env_get("CUDA_HOME", "/usr/local/cuda")
```

## 📦 输出文件结构

编译完成后:
```
artifacts/build/
├── cuda_kernels/
│   ├── libcuda_kernels.so      ← GPU核函数库
│   ├── cuda_kernels.ptx        ← PTX中间代码
│   ├── cuda_kernels_wrapper.c  ← C包装源
│   ├── cuda_kernels_wrapper.o  ← 对象文件
│   └── env.sh                  ← 环境配置
│
└── cuda_runtime/
    ├── libcuda_runtime.so      ← 运行时库
    └── env.sh                  ← 环境配置
```

## ✅ 验证安装

```bash
# 检查库文件
ls -lh artifacts/build/cuda_kernels/libcuda_kernels.so
ls -lh artifacts/build/cuda_runtime/libcuda_runtime.so

# 测试库
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:./artifacts/build/cuda_runtime:$LD_LIBRARY_PATH"
ldd artifacts/build/cuda_kernels/libcuda_kernels.so
ldd artifacts/build/cuda_runtime/libcuda_runtime.so
```

## 🔄 集成到Makefile

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

## 📚 相关文件

- [CUDA_GPU_ARCHITECTURE.md](../CUDA_GPU_ARCHITECTURE.md) - 架构详解
- [S_CUDA_IMPLEMENTATION_GUIDE.md](../S_CUDA_IMPLEMENTATION_GUIDE.md) - 实现指南
- [scripts/legacy/gpu_train.s](../scripts/legacy/gpu_train.s) - GPU训练脚本
- [cuda/cuda_kernels.cu](cuda_kernels.cu) - CUDA核函数源代码

## 📋 总结

| 特性 | bash | S语言 |
|------|------|--------|
| 依赖外壳 | ✅ | ❌ |
| Python依赖 | ⚠️ 可能 | ❌ |
| 代码清晰度 | ⚠️ | ✅ |
| 执行速度 | ⚠️ | ✅ |
| 自举兼容 | ❌ | ✅ |
| 跨平台 | ⚠️ | ✅ |

**结论:** S语言实现提供了更清晰、更易维护、完全符合项目哲学的构建系统。

---

**Author:** NeurX Project
**Date:** 2026-07-13
**Status:** ✅ Production Ready
