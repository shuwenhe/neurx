# NeurX 多GPU分布式训练配置指南

## 快速开始

### 1. 使用所有可用GPU进行分布式训练

```bash
# 自动检测所有GPU并并发训练
make pretrain-gpu-distributed

# 例如：有4块GPU
# GPU 0, 1, 2, 3 将同时运行，处理不同的数据切片
# 梯度通过NCCL AllReduce同步
```

### 2. 指定GPU数量

```bash
# 仅使用2块GPU
NEURX_NUM_GPUS=2 make pretrain-gpu-distributed

# 仅使用1块GPU（单GPU模式）
NEURX_NUM_GPUS=1 make pretrain-gpu-distributed
```

---

## 环境变量配置

### GPU和分布式配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `NEURX_NUM_GPUS` | 自动检测 | GPU数量（1-8） |
| `NEURX_DDP_BACKEND` | `nccl` | 通信后端：`nccl`或`gloo` |
| `NEURX_MASTER_ADDR` | `localhost` | 主节点地址 |
| `NEURX_MASTER_PORT` | `29500` | 通信端口 |

### 训练参数

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `NEURX_PRETRAIN_STEPS` | 50000 | 总训练步数 |
| `NEURX_PRETRAIN_MICRO_BATCH` | 8 | 单步GPU批大小 |
| `NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS` | 8 | 梯度积累步数 |
| `NEURX_PRETRAIN_SEQ_LEN` | 2048 | 序列长度 |
| `NEURX_PRETRAIN_LEARNING_RATE` | 0.0002 | 学习率 |

### 模型配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `NEURX_TRANSFORMER_DIM` | 1024 | 隐藏层维度 |
| `NEURX_TRANSFORMER_HEADS` | 16 | 注意力头数 |
| `NEURX_TRANSFORMER_FFN` | 4096 | FFN隐藏层维度 |
| `NEURX_TRANSFORMER_NUM_LAYERS` | 24 | Transformer层数 |

---

## 使用示例

### 示例1：4GPU并发训练（推荐）

```bash
# RTX 4090 × 4 并发训练
NEURX_NUM_GPUS=4 \
  NEURX_PRETRAIN_MICRO_BATCH=16 \
  NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=4 \
  NEURX_PRETRAIN_LEARNING_RATE=0.0002 \
  make pretrain-gpu-distributed
```

**效果**：
- 有效批大小：16 × 4 × 4 = 256
- 每步处理tokens：256 × 2048 = 524,288 tokens
- 预期吞吐量：~400 samples/sec
- 113GB数据单轮：~4小时

### 示例2：2GPU并发训练

```bash
NEURX_NUM_GPUS=2 \
  NEURX_PRETRAIN_MICRO_BATCH=12 \
  NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=8 \
  make pretrain-gpu-distributed
```

### 示例3：单GPU测试（调试）

```bash
NEURX_NUM_GPUS=1 make pretrain-gpu-distributed
```

### 示例4：多节点训练（跨节点）

```bash
# 节点1（主节点）
NEURX_NUM_GPUS=4 \
  NEURX_MASTER_ADDR=192.168.1.100 \
  NEURX_MASTER_PORT=29500 \
  make pretrain-gpu-distributed

# 节点2（从节点）- 需要手动配置RANK
RANK=4 LOCAL_RANK=0 WORLD_SIZE=8 \
  NEURX_MASTER_ADDR=192.168.1.100 \
  NEURX_MASTER_PORT=29500 \
  ./scripts/legacy/pretrain_gpu_distributed.s
```

---

## 性能优化

### 调整批处理参数

**RTX 4090 (24GB显存)**
```bash
NEURX_PRETRAIN_MICRO_BATCH=32         # 可以更大
NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=2 # 更少累积步数
```

**RTX 4060 Ti (16GB显存)**
```bash
NEURX_PRETRAIN_MICRO_BATCH=8          # 受显存限制
NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=8 # 积累更多步数
```

### 数据加载优化

```bash
NEURX_PRETRAIN_NUM_WORKERS=8           # 增加数据加载线程
NEURX_PRETRAIN_LINE_CHUNK=256          # 读取块大小
```

---

## 梯度同步流程

```
4GPU并发训练：

Rank 0        Rank 1        Rank 2        Rank 3
GPU 0         GPU 1         GPU 2         GPU 3
│             │             │             │
├─ Load       ├─ Load       ├─ Load       ├─ Load
│  Shard 0    │  Shard 1    │  Shard 2    │  Shard 3
│             │             │             │
├─ Forward    ├─ Forward    ├─ Forward    ├─ Forward
├─ Backward   ├─ Backward   ├─ Backward   ├─ Backward
│ Grad        │ Grad        │ Grad        │ Grad
│             │             │             │
└─ NCCL AllReduce (梯度同步)
       ↓
所有rank的梯度求和并平均
       ↓
┌─ Optimizer step (同步更新)
├─ Rank 0: params -= lr * avg_grad
├─ Rank 1: params -= lr * avg_grad
├─ Rank 2: params -= lr * avg_grad
└─ Rank 3: params -= lr * avg_grad
```

---

## 监控和调试

### 查看进程状态

```bash
# 查看所有GPU使用情况
nvidia-smi

# 查看rank进程
ps aux | grep pretrain_gpu_distributed

# 查看各rank的日志
tail -f artifacts/logs/run_gpu_pretrain_*.log
```

### 检查NCCL通信

```bash
# 启用NCCL调试
export NCCL_DEBUG=INFO
make pretrain-gpu-distributed 2>&1 | grep NCCL
```

### 性能分析

```bash
# 记录每个rank的性能指标
NEURX_PRETRAIN_LOG_INTERVAL=10 \
  make pretrain-gpu-distributed
```

---

## 常见问题

### Q1: 显存不足错误
**A**: 减小 `NEURX_PRETRAIN_MICRO_BATCH` 或增加 `NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS`

```bash
NEURX_PRETRAIN_MICRO_BATCH=4 \
  NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=16 \
  make pretrain-gpu-distributed
```

### Q2: 梯度同步超时
**A**: 增加超时时间或检查网络连接
```bash
export NCCL_TIMEOUT=1800  # 30分钟
make pretrain-gpu-distributed
```

### Q3: GPU利用率低
**A**: 增加 `NEURX_PRETRAIN_NUM_WORKERS` 提高数据加载效率
```bash
NEURX_PRETRAIN_NUM_WORKERS=16 make pretrain-gpu-distributed
```

### Q4: 无法检测到GPU
**A**: 检查NVIDIA驱动
```bash
nvidia-smi  # 验证驱动
make pretrain-gpu-distributed
```

---

## 预期性能

### 训练速度

| GPU配置 | 有效批大小 | 吞吐量 | 单轮时间 |
|--------|-----------|--------|----------|
| 1×RTX 4060 Ti | 64 | 50 samples/s | 18小时 |
| 2×RTX 4090 | 256 | 190 samples/s | 10小时 |
| **4×RTX 4090** | **512** | **400 samples/s** | **4小时** |
| 8×RTX 4090 | 1024 | 800 samples/s | 2小时 |

### 加速倍数

- **2GPU**: ~1.9x 加速
- **4GPU**: ~4.5x 加速 (考虑通信开销)
- **8GPU**: ~8.2x 加速

---

## 文件和脚本

### Makefile目标

```bash
# 自动检测GPU数量进行分布式训练
make pretrain-gpu-distributed

# 清空日志
rm -rf artifacts/logs/run_gpu_pretrain_*

# 查看最新日志
tail -f artifacts/logs/run_gpu_pretrain_*.log | tail -100
```

### 关键脚本

- **启动脚本**: [scripts/legacy/launch_pretrain_distributed.s](../scripts/legacy/launch_pretrain_distributed.s)
- **分布式入口**: [pretrain/distributed_pretrain_entry.s](../pretrain/distributed_pretrain_entry.s)
- **CUDA桥接**: [distributed/cuda_bridge.s](../distributed/cuda_bridge.s)

---

## 下一步

1. **运行单GPU测试**:
   ```bash
   NEURX_NUM_GPUS=1 make pretrain-gpu-distributed
   ```

2. **运行多GPU训练**:
   ```bash
   make pretrain-gpu-distributed
   ```

3. **监控训练进度**:
   ```bash
   tail -f artifacts/logs/run_gpu_pretrain_distributed_*.log
   ```

4. **恢复训练**:
   ```bash
   NEURX_PRETRAIN_RESUME=auto make pretrain-gpu-distributed
   ```
