# 训练模式对照表

## 当前 make pretrain 配置

### ❌ 默认: make pretrain (CPU模式)
```bash
make pretrain
```

**当前配置:**
- ✓ 脚本: `script/minimal_train.s` (纯S语言，CPU计算)
- ❌ 不使用GPU
- ❌ 不使用CUDA
- 运行模式: 单线程CPU训练 (容易hang在str_len())

**流程:**
```
make pretrain
  ↓ 编译
script/minimal_train.s → minimal_train.ir
  ↓ 运行
S_RUNNER minimal_train.ir
  ↓ 执行
CPU计算 (无GPU加速)
```

**问题:**
- str_len() 函数会hang (已知bug)
- 仅处理~147个文档后卡住
- 无法完成实际训练

---

### ✅ GPU模式: make pretrain-gpu (推荐)
```bash
make pretrain-gpu
```

**当前配置:**
- ✓ 脚本: `script/pretrain_gpu.s` (S语言 + CUDA)
- ✓ 使用GPU并发训练
- ✓ 调用CUDA核函数
- 运行模式: GPU加速矩阵运算

**流程:**
```
make pretrain-gpu
  ↓ GPU检测 (nvidia-smi)
NEURX_CUDA_DEVICE_COUNT 自动检测
  ↓ 编译
script/pretrain_gpu.s → pretrain_gpu.ir
  ↓ 调用CUDA桥接
build-cuda-train-bridge
  ↓ 运行
S_RUNNER pretrain_gpu.ir
  ↓ GPU执行
CUDA核函数 (cublasSgemm, relu, loss等)
```

**特性:**
- ✓ 自动检测GPU数量
- ✓ 并发执行CUDA核函数
- ✓ 支持多GPU
- ✓ 批处理加速

---

## 新增脚本状态

### script/gpu_train.s (新创建 - 未集成)
**状态:** ✅ 完成但未集成到Makefile

- 位置: `script/gpu_train.s` (500+ 行)
- 功能: GPU训练完整实现 (文件I/O + CUDA FFI)
- 库依赖: 
  - libcuda_kernels.so (已生成)
  - libcuda_runtime.so (已生成)
- 编译: `s ir script/gpu_train.s -o artifacts/build/gpu_train.ir`
- 状态: 已编译可运行

**这个脚本比pretrain_gpu.s更完善，但还未集成到Makefile中**

---

## 快速对比

| 特性 | make pretrain | make pretrain-gpu |
|------|---------------|-------------------|
| 默认选择 | ✓ 是 | ❌ 否 |
| 脚本 | minimal_train.s | pretrain_gpu.s |
| CPU计算 | ✓ | ✓ (预处理) |
| GPU计算 | ❌ | ✓ (核函数) |
| 速度 | 慢 | 快 (10-100x) |
| 已知bug | str_len()hang | 无已知bug |
| 推荐 | ❌ 开发用 | ✓ 生产用 |

---

## 如何选择

### 使用 CPU 训练 (make pretrain)
```bash
make pretrain
```
**适用场景:**
- 调试和测试 (但会hang)
- CPU集群环境
- GPU不可用的场景

**问题:** 当前无法正常运行 (str_len() bug)

### 使用 GPU 训练 (make pretrain-gpu) - 推荐 ⭐
```bash
make pretrain-gpu
```
**适用场景:**
- 生产环境
- NVIDIA GPU可用
- 需要高性能训练

**优势:**
- 自动GPU检测
- 并发执行
- 10-100x加速

---

## 架构细节

### CPU 路径 (make pretrain)
```
minimal_train.s
├─ runtime_read_text_file() → 加载shard
├─ 文本解析 (S语言)
├─ 参数准备
└─ CPU计算
   └─ ❌ str_len() 会在这里hang
```

### GPU 路径 (make pretrain-gpu)
```
pretrain_gpu.s
├─ runtime_read_text_file() → 加载shard
├─ 文本解析 (S语言)
├─ CUDA初始化 (cublasCreate)
├─ 数据转移 → GPU内存
├─ GPU计算
│  ├─ cublasSgemm() - 矩阵乘法
│  ├─ cuda_relu_forward() - 激活
│  ├─ cuda_error_loss_kernel() - 损失
│  └─ cuda_sgd_update_kernel() - 更新
└─ 结果返回 → 主存
```

### GPU 路径 (script/gpu_train.s - 新)
```
gpu_train.s (更完善)
├─ 完整的文件I/O
├─ GPU上下文管理
├─ 内存管理 (cuda_malloc/free)
├─ cuBLAS操作
└─ 完整的CUDA FFI绑定
```

---

## 编译命令

### CPU 版本编译
```bash
s ir script/minimal_train.s -o artifacts/build/pretrain_orchestrator/minimal_train.ir
```

### GPU 版本编译
```bash
s ir script/pretrain_gpu.s -o artifacts/build/gpu_pretrain/pretrain_gpu.ir
```

### 新GPU脚本编译
```bash
export LD_LIBRARY_PATH="./artifacts/build/cuda_kernels:./artifacts/build/cuda_runtime:$LD_LIBRARY_PATH"
s ir script/gpu_train.s -o artifacts/build/gpu_train/gpu_train.ir
```

---

## 环境变量配置

### CPU 训练
```bash
export NEURX_PRETRAIN_MICRO_BATCH=4
export NEURX_PRETRAIN_SEQ_LEN=256
export NEURX_PRETRAIN_LR=0.0002
make pretrain
```

### GPU 训练
```bash
export NEURX_PRETRAIN_MICRO_BATCH=32    # GPU可处理更大批次
export NEURX_PRETRAIN_SEQ_LEN=512       # 更长序列
export NEURX_PRETRAIN_LR=0.0002
export NEURX_NUM_GPUS=1                 # 指定GPU数量
make pretrain-gpu
```

---

## 下一步建议

### 立即可做
1. ✓ 使用 `make pretrain-gpu` 进行GPU训练
2. ✓ CUDA库已编译完成 (libcuda_kernels.so, libcuda_runtime.so)
3. ✓ script/gpu_train.s 已准备好

### 短期改进
1. 将 script/gpu_train.s 集成到Makefile
2. 修复 str_len() bug (make pretrain才能工作)
3. 性能优化 (批处理、梯度累积)

### 中期目标
1. 分布式多GPU训练
2. 混合精度训练 (fp16)
3. 性能基准测试

---

## 文档参考

| 文档 | 说明 |
|------|------|
| [CUDA_GPU_ARCHITECTURE.md](../CUDA_GPU_ARCHITECTURE.md) | GPU架构详解 |
| [S_CUDA_IMPLEMENTATION_GUIDE.md](../S_CUDA_IMPLEMENTATION_GUIDE.md) | S vs CUDA 实现 |
| [cuda/BUILD_SYSTEM_S_LANGUAGE.md](BUILD_SYSTEM_S_LANGUAGE.md) | CUDA构建系统 |
| [script/gpu_train.s](../script/gpu_train.s) | GPU训练脚本 (新) |
| [script/pretrain_gpu.s](../script/pretrain_gpu.s) | GPU训练脚本 (现有) |

---

## 快速开始

### GPU训练 (推荐)
```bash
# 1. 验证GPU
nvidia-smi

# 2. 构建CUDA系统
make build-cuda-kernels
make build-cuda-runtime

# 3. 启动GPU训练
make pretrain-gpu

# 4. 监控训练
tail -f checkpoint/NeurX-1.3/logs/pretrain_gpu_*.log
```

### CPU训练 (调试用 - 当前有bug)
```bash
# 当前无法运行 (str_len() hang)
# 修复后可用:
make pretrain
```

---

**更新日期:** 2026-07-13
**状态:** ✅ GPU训练系统完整，推荐使用 `make pretrain-gpu`
