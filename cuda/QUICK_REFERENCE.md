# S Language CUDA Build Scripts - Quick Reference

完整替代bash脚本的纯S语言CUDA构建系统参考卡片。

## 📋 脚本清单

### 核心脚本

| 脚本 | 说明 | 编译命令 | 功能 |
|------|------|---------|------|
| `build_kernels_simple.s` | GPU核函数编译 | `s ir cuda/build_kernels_simple.s` | PTX生成 → C包装 → libcuda_kernels.so |
| `build_cuda_runtime.s` | 运行时编译 | `s ir cuda/build_cuda_runtime.s` | 编译libcuda_runtime.so + cuBLAS绑定 |
| `clean_build.s` | 清理构建 | `s ir cuda/clean_build.s` | 删除artifacts/build/cuda_* |
| `verify_environment.s` | 环境检查 | `s ir cuda/verify_environment.s` | 验证CUDA/cuBLAS/GPU |
| `build_cuda.s` | 综合管理 | `CUDA_TARGET=X s ir cuda/build_cuda.s` | 统一入口点 |

## 🚀 快速命令

### 编译全部
```bash
s ir cuda/build_kernels_simple.s && \
s ir cuda/build_cuda_runtime.s
```

### 仅编译核函数
```bash
s ir cuda/build_kernels_simple.s
```

### 仅编译运行时
```bash
s ir cuda/build_cuda_runtime.s
```

### 清理并重建
```bash
s ir cuda/clean_build.s && \
s ir cuda/build_kernels_simple.s && \
s ir cuda/build_cuda_runtime.s
```

### 验证环境
```bash
s ir cuda/verify_environment.s
```

## 📊 脚本功能对照

### 原bash脚本 → 新S脚本

```
build_kernels_simple.sh  ──→  build_kernels_simple.s
build_cuda_runtime.sh    ──→  build_cuda_runtime.s
build_cuda_runtime_alt.sh ──→ build_cuda_runtime.s (合并)
build.sh                 ──→  build_cuda.s
verify_environment.sh    ──→  verify_environment.s
Makefile targets         ──→  cuda_build.s targets
```

## 🔧 环境变量

| 变量 | 默认值 | 用途 |
|------|--------|------|
| `S_COMPILER` | `/home/shuwen/.local/bin/s` | S编译器路径 |
| `CUDA_HOME` | 自动检测 | CUDA安装位置 |
| `CUDA_TARGET` | `build-all` | build_cuda.s的目标 |
| `LD_LIBRARY_PATH` | 自动更新 | 库搜索路径 |

## 📝 编译步骤详解

### build_kernels_simple.s 流程
```
main()
 ├─ 检查nvcc → which nvcc
 ├─ 检测CUDA版本 → nvcc --version
 ├─ 检测GPU架构 → nvidia-smi
 ├─ 创建build目录 → mkdir -p
 ├─ 编译PTX → nvcc -ptx
 ├─ 创建C包装 → create_wrapper_c()
 ├─ 编译对象 → gcc -c
 ├─ 链接共享库 → gcc -shared
 └─ 创建env.sh
```

### build_cuda_runtime.s 流程
```
main()
 ├─ 检测CUDA主目录 → get_cuda_home()
 ├─ 创建build目录
 ├─ 编译运行时 → gcc -shared -lcudart -lcublas
 └─ 创建env.sh
```

### build_cuda.s 流程 (orchestrator)
```
main()
 ├─ 读取CUDA_TARGET环境变量
 ├─ 路由到对应处理
 │  ├─ build-all → 执行all脚本
 │  ├─ build-kernels → 执行kernels脚本
 │  ├─ build-runtime → 执行runtime脚本
 │  ├─ clean → 清理
 │  └─ verify-env → 验证
 └─ 对应处理函数执行
```

## 🎯 典型工作流

### 完整构建 (从零开始)
```bash
# 1. 清理旧构建
s ir cuda/clean_build.s

# 2. 验证环境
s ir cuda/verify_environment.s

# 3. 编译核函数
s ir cuda/build_kernels_simple.s

# 4. 编译运行时
s ir cuda/build_cuda_runtime.s

# 5. 验证输出
ls -lh artifacts/build/cuda_kernels/libcuda_kernels.so
ls -lh artifacts/build/cuda_runtime/libcuda_runtime.so
```

### 快速重建 (已有源代码)
```bash
# 假设kernel源代码已修改
s ir cuda/build_kernels_simple.s

# 测试
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:$LD_LIBRARY_PATH"
```

### CI/CD集成
```bash
#!/bin/bash
set -e

# 编译
s ir cuda/build_cuda.s || {
    echo "[ERROR] Build failed"
    s ir cuda/verify_environment.s
    exit 1
}

# 验证
if [ ! -f "./artifacts/build/cuda_kernels/libcuda_kernels.so" ]; then
    echo "[ERROR] libcuda_kernels.so not found"
    exit 1
fi

echo "[SUCCESS] Build complete"
```

## 📦 输出物

### 成功编译后的输出
```
artifacts/build/
├── cuda_kernels/
│   ├── libcuda_kernels.so      ✓ 16KB
│   ├── cuda_kernels.ptx        ✓ (中间文件)
│   ├── cuda_kernels_wrapper.c  ✓ (源)
│   ├── cuda_kernels_wrapper.o  ✓ (对象)
│   └── env.sh                  ✓ (环境脚本)
└── cuda_runtime/
    ├── libcuda_runtime.so      ✓ 15KB
    └── env.sh                  ✓ (环境脚本)
```

## ✅ 验证检查表

编译后验证:
```bash
# ✓ 文件存在且大小合理
ls -lh artifacts/build/cuda_kernels/libcuda_kernels.so
ls -lh artifacts/build/cuda_runtime/libcuda_runtime.so

# ✓ 库的依赖关系正确
ldd artifacts/build/cuda_kernels/libcuda_kernels.so | grep cuda

# ✓ 符号表完整
nm artifacts/build/cuda_kernels/libcuda_kernels.so | grep cuda_

# ✓ 可以加载到内存
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:$LD_LIBRARY_PATH"
python3 -c "import ctypes; ctypes.CDLL('./artifacts/build/cuda_kernels/libcuda_kernels.so')"
```

## 🐛 调试技巧

### 查看编译详细输出
在S脚本中修改:
```s
string cmd = "nvcc -ptx ... -v"  // 添加 -v 选项
```

### 查看S脚本执行过程
```bash
# 编译到IR后检查
s ir cuda/build_kernels_simple.s -o /tmp/build.ir
# 查看字节码
file /tmp/build.ir
```

### 环境变量调试
```bash
export CUDA_TARGET=verify-env
export S_COMPILER=$(which s)
s ir cuda/build_cuda.s
```

## 📚 S脚本关键函数

### I/O函数
```s
runtime_run_command_output(cmd)      // 执行命令获取输出
runtime_env_get(var, default)        // 读取环境变量
runtime_file_exists(path)            // 检查文件存在
runtime_read_text_file(path)         // 读取文件
runtime_write_text_file(path, text)  // 写入文件
```

### 字符串函数
```s
str_len(s)                 // 字符串长度
trim(s)                    // 移除首尾空格
substring(s, start, end)   // 子字符串
contains_string(h, n)      // 包含检查
eq_string(a, b)            // 字符串相等
```

## 🔄 Makefile集成示例

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

## ⚠️ 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| `nvcc not found` | CUDA未安装 | `export PATH="/usr/local/cuda/bin:$PATH"` |
| `libcuda_kernels.so not created` | 编译失败 | 查看编译输出，检查gcc/nvcc |
| `undefined reference to cuda_*` | 链接失败 | 检查LD_LIBRARY_PATH |
| `S compiler not found` | 路径错误 | `export S_COMPILER=$(which s)` |

## 📖 相关文档

| 文件 | 说明 |
|------|------|
| [BUILD_SYSTEM_S_LANGUAGE.md](BUILD_SYSTEM_S_LANGUAGE.md) | 完整使用指南 |
| [../CUDA_GPU_ARCHITECTURE.md](../CUDA_GPU_ARCHITECTURE.md) | GPU架构详解 |
| [../S_CUDA_IMPLEMENTATION_GUIDE.md](../S_CUDA_IMPLEMENTATION_GUIDE.md) | S vs CUDA 实现指南 |
| [../scripts/legacy/gpu_train.s](../scripts/legacy/gpu_train.s) | GPU训练脚本 |
| [cuda_kernels.cu](cuda_kernels.cu) | CUDA核函数源代码 |

## 🎓 学习要点

1. **S语言优势**: 自包含、跨平台、易维护
2. **构建流程**: PTX生成 → C包装 → 对象文件 → 共享库
3. **环境配置**: 自动检测CUDA路径、GPU架构
4. **模块化**: 每个脚本独立可运行
5. **集成**: 可无缝集成到现有Makefile

---

**版本:** 1.0
**日期:** 2026-07-13
**状态:** ✅ 生产就绪
