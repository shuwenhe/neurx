# Gate 0: Vector Add 实现和测试指南

## 🎯 目标

验证整个 S 语言 → Device ABI → CUDA Runtime → GPU → 返回的完整链路。

```
用户代码 (S 语言)
    ↓
Device ABI (abi.s)
    ↓
Device Bridge (device_bridge.s)
    ↓
CUDA 实现 (gate0_cuda_impl.s)
    ↓
CUDA Runtime (外部库)
    ↓
NVIDIA GPU
```

## 📁 代码结构

```
neurx/src/device/
├── abi.s                           # Device ABI 定义（已有）
├── device_bridge.s (NEW)           # ABI ↔ CUDA 桥接层
├── gate0_cuda_impl.s (NEW)         # CUDA 最小实现
└── gate0_test_vector_add.s (NEW)   # 单元测试

neurx/src/
└── gate0_integration_test.s (NEW)  # 集成测试
```

## 🔧 编译

### 前置条件

- S 语言编译器：`/home/shuwen/.local/bin/s_seed`
- CUDA Toolkit（可选，如果要真实编译和运行）

### 编译步骤

```bash
cd /home/shuwen/shuwen/neurx

# 1. 编译 Device ABI（已存在，仅检查）
s_seed compile -o build/abi.o src/device/abi.s

# 2. 编译 CUDA 实现
s_seed compile -o build/cuda_impl.o src/device/gate0_cuda_impl.s

# 3. 编译 Device Bridge
s_seed compile -o build/device_bridge.o src/device/device_bridge.s

# 4. 编译集成测试
s_seed compile -o build/gate0_test.o src/gate0_integration_test.s

# 5. 链接所有对象文件
s_seed link -o build/gate0_test \
    build/abi.o \
    build/cuda_impl.o \
    build/device_bridge.o \
    build/gate0_test.o \
    -lcudart -lcuda

# 或使用构建脚本
./build_gate0.sh
```

### 简化构建命令

```bash
# 一键构建
make gate0

# 或
./scripts/build_gate0.sh
```

## ▶️ 运行

```bash
# 运行集成测试
./build/gate0_test

# 预期输出：
# Gate 0 Integration Test Summary: 4 passed, 0 failed
# ✓ Test 1 (Basic Workflow): Basic workflow test passed
# ✓ Test 2 (Memory Management): Memory management test passed
# ✓ Test 3 (Tensor Operations): Tensor operations test passed
# ✓ Test 4 (Scale and Performance): Scale and performance test passed
# Total: 4/4 tests passed
```

## 📊 验证清单

每个测试验证一个关键步骤：

### ✓ 测试 1: 基础工作流

```
初始化 CUDA
  ↓
创建张量 (A, B, C)
  ↓
创建流
  ↓
执行 Vector Add (C = A + B)
  ↓
同步
```

**验收标准**：所有操作返回成功

### ✓ 测试 2: 内存管理

```
获取初始内存 (free_before)
  ↓
分配 10 个张量 × 100K 元素
  ↓
获取分配后内存 (free_after)
  ↓
验证：free_before - free_after ≥ 4MB
  ↓
释放所有张量
```

**验收标准**：内存分配大小正确，能够释放

### ✓ 测试 3: 张量操作

```
创建 3 个张量
  ↓
调用 device_vector_add()
  ↓
同步设备
```

**验收标准**：Vector Add 返回成功

### ✓ 测试 4: 规模测试

```
测试向量大小：1K, 10K, 100K, 1M
  ↓
对每个大小执行 Vector Add
  ↓
验证所有大小都成功
```

**验收标准**：从 1K 到 1M 元素都能成功执行

## 🔍 调试

### 启用详细日志

```bash
# 编译时启用调试信息
s_seed compile -g -o build/gate0_test.o src/gate0_integration_test.s

# 运行时启用追踪
CUDA_LAUNCH_BLOCKING=1 ./build/gate0_test
```

### 常见问题

#### 问题 1: CUDA 不可用
```
Error: cuda not available
```

**解决**：
```bash
# 检查 CUDA 安装
nvidia-smi

# 检查 CUDA 库
ldconfig -p | grep cuda
```

#### 问题 2: 内存不足
```
Error: Pool memory exhausted
```

**解决**：
```bash
# 减少测试大小
VECTOR_SIZE=10000 ./build/gate0_test

# 或清理 GPU 内存
nvidia-smi --gpu-reset
```

#### 问题 3: S 编译器找不到模块
```
Error: Module not found: neurx.device.abi
```

**解决**：
```bash
# 检查 SPATH
export SPATH=/home/shuwen/shuwen:$SPATH

# 或使用完整路径编译
cd /home/shuwen/shuwen
s_seed compile neurx/src/gate0_integration_test.s
```

## 📈 性能基准

Gate 0 完成后，预期性能指标：

```
Vector Size    | Execution Time | Throughput
───────────────┼────────────────┼─────────────
1K elements    | < 0.1 ms       | > 40 GB/s
10K elements   | < 0.2 ms       | > 200 GB/s
100K elements  | < 0.5 ms       | > 800 GB/s
1M elements    | < 2 ms         | > 2 TB/s
```

## 🚀 下一步 (Gate 1)

Gate 0 完成后，进入 Gate 1: Device Tensor 完善

```
Gate 1 任务：
  1. Reshape/View/Transpose 实现
  2. Memory Pooling
  3. Ref Counting
  4. 内存泄漏检测
```

详见：`COMPLETE_IMPLEMENTATION_ROADMAP.md`

## 📝 验收标准

Gate 0 成功完成时：

- ✅ 所有 4 个集成测试通过
- ✅ Vector Add 在 GPU 上正确执行
- ✅ 内存分配/释放无泄漏
- ✅ 支持向量大小 1K-1M 元素
- ✅ P99 延迟 < 2ms
- ✅ S → CUDA 完整链路验证

## 🔗 相关文件

- [abi.s](abi.s) - Device ABI 定义
- [gate0_cuda_impl.s](gate0_cuda_impl.s) - CUDA 实现
- [device_bridge.s](device_bridge.s) - 桥接层
- [gate0_integration_test.s](../gate0_integration_test.s) - 集成测试
- [COMPLETE_IMPLEMENTATION_ROADMAP.md](../../COMPLETE_IMPLEMENTATION_ROADMAP.md) - 完整规划

