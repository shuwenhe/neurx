# CANN - Ascend Computing Language

## 概述

CANN (Ascend Computing Language) 是华为 Ascend NPU 的核心计算库和运行时环境。本目录包含 CANN 的集成代码、工具脚本和配置文件。

## 目录结构

```
cann/
├── CMakeLists.txt              # CANN C++ 构建配置
├── env.s                       # 环境变量配置脚本
├── device_abi_cann.cpp         # 设备 ABI 适配层
│
├── cache/                      # 缓存管理模块
├── configs/                    # CANN 配置文件
├── deploy/                     # 部署脚本和工具
├── hccl/                       # HCCL 分布式通信集成
├── inference/                  # 推理引擎集成
├── model/                      # 模型加载和管理
├── operators/                  # CANN 算子库
├── runtime/                    # CANN 运行时
└── scripts/                    # 辅助脚本
```

## 环境设置

### 设置 Ascend 工具链

```bash
cd /app/shuwen/neurx/backend/platform/cann
s env.s > ascend_env.sh
source ascend_env.sh
```

或直接设置环境变量：

```bash
export ASCEND_HOME_PATH=/usr/local/Ascend/ascend-toolkit/latest
export ASCEND_OPP_PATH=${ASCEND_HOME_PATH}/opp
export ASCEND_AICPU_PATH=${ASCEND_HOME_PATH}
export PATH=${ASCEND_HOME_PATH}/bin:${ASCEND_HOME_PATH}/compiler/ccec_compiler/bin:${PATH}
export LD_LIBRARY_PATH=${ASCEND_HOME_PATH}/lib64:${ASCEND_HOME_PATH}/runtime/lib64:${ASCEND_HOME_PATH}/compiler/lib64:${LD_LIBRARY_PATH}
```

## 关键模块

### 1. 设备 ABI (device_abi_cann.cpp)
- 华为 Ascend NPU 设备接口适配
- 内存管理和数据传输
- 内核启动和同步机制

### 2. HCCL 分布式通信 (hccl/)
- 多卡通信库集成
- All-Reduce, All-Gather 等集体操作
- 拓扑感知的通信优化

### 3. 运行时环境 (runtime/)
- Ascend 运行时初始化
- 设备内存池管理
- 事件和流管理

### 4. 推理引擎 (inference/)
- 模型推理接口
- Batch 处理
- KV 缓存管理

### 5. 算子库 (operators/)
- 注意力机制
- 激活函数
- 规范化层
- 采样和生成

### 6. 模型管理 (model/)
- 模型权重加载
- 量化参数管理
- 动态形状处理

## 与 NPU 后端的关系

CANN 是 `/app/shuwen/neurx/backend/platform/npu/` 后端的**实现基础**。

- **NPU 后端** (`platform/npu/`) 
  - 提供统一的设备管理接口
  - 跨 Ascend 加速器的抽象
  - 支持 Ascend 910/910B/910C/DA 等多个芯片
  
- **CANN 库** (`platform/cann/`)
  - 提供具体的计算实现
  - 低级运行时和算子库
  - 硬件特定的优化

关系图：

```
NeurX 推理引擎
    ↓
NPU Backend (neurx.platform.npu)
    ↓
CANN Runtime (platform/cann)
    ↓
Ascend Hardware (910/910B/910C/DA)
```

## 编译和构建

### 编译 CANN 支持

```bash
cd /app/shuwen/neurx/backend/platform/cann
mkdir -p build
cd build
cmake .. -DCANN_INSTALL_DIR=/usr/local/Ascend/ascend-toolkit/latest
make -j$(nproc)
make install
```

### 与主项目集成

```bash
cd /app/shuwen/neurx
mkdir -p build
cd build
cmake .. -DWITH_CANN=ON
make -j$(nproc)
```

## 使用示例

### S 语言中使用 NPU

```s
import "neurx.platform.npu" as npu

func main() {
    device_count = npu.npu_device_count()
    println("Available NPU devices: " + string(device_count))
    
    device = npu.npu_get_device(0)
    println("Device: " + device.name)
    
    ctx = npu.npu_initialize_context(0)
    
    npu.npu_acl_init()
    
    op = npu.npu_create_op("MatMul")
    npu.npu_execute_op(op, input, output)
    npu.npu_destroy_op(op)
}
```

### HCCL 分布式训练

```s
import "neurx.platform.cann" as cann

func setup_distributed() {
    rank = cann.hccl_get_rank()
    world_size = cann.hccl_get_world_size()
    
    if rank == 0 {
        println("Running distributed training on " + string(world_size) + " devices")
    }
    
    cann.hccl_all_reduce(data)
    cann.hccl_barrier()
}
```

## 相关文档

- [NPU Backend Documentation](../npu/README.md)
- [Platform Registry](../registry.s)
- [Ascend CANN Official Docs](https://www.hiascend.com/)

## 支持的芯片

| 芯片 | 代号 | 性能 | 内存 | 状态 |
|------|------|------|------|------|
| Ascend 910 | da | ~500 TFLOPS | 32GB | ✓ |
| Ascend 910B | 910b | ~600 TFLOPS | 32GB | ✓ |
| Ascend 910C | 910c | ~700 TFLOPS | 40GB | ✓ |
| Ascend DA | da | ~300 TFLOPS | 16GB | ✓ |

## 分布式后端

- **HCCL** - Huawei Collective Communication Library
  - All-Reduce, All-Gather, Reduce-Scatter
  - Broadcast, Send/Recv
  - 支持多卡和多机分布式

## 性能优化

### 内存优化
- KV 缓存预分配
- 内存池管理
- 碎片整理

### 计算优化
- 算子融合
- 量化加速
- 图优化

### 通信优化
- 拓扑感知调度
- 通信计算重叠
- 带宽优化

## 故障排查

### 1. 找不到 Ascend 工具链

```bash
export ASCEND_HOME_PATH=/path/to/ascend-toolkit/latest
source /app/shuwen/neurx/backend/platform/cann/env.s
```

### 2. 运行时初始化失败

检查环境变量：
```bash
echo $ASCEND_HOME_PATH
echo $ASCEND_OPP_PATH
echo $LD_LIBRARY_PATH
```

### 3. HCCL 通信错误

验证多卡连接：
```bash
npu-smi info
```

## 许可证

遵循 NeurX 主项目的许可证。

## 联系方式

问题和反馈请提交到项目 issue 跟踪器。
