# NeurX 多GPU分布式预训练系统

## 系统架构

本系统实现了完整的多GPU分布式预训练管道，包括三个核心模块：

### 1. **分布式启动器** (`distributed_pretrain_launcher.s`)
- **功能**: 初始化分布式环境，管理进程间通信
- **核心组件**:
  - `distributed_env`: 环境配置（WORLD_SIZE、RANK、LOCAL_RANK）
  - `distributed_pretrain_launcher`: 主控制器
  - 数据分片分配：每个rank只处理分配给它的切片

**环境变量**:
```bash
WORLD_SIZE=4          # 总GPU数量
RANK=0-3              # 当前进程rank
LOCAL_RANK=0-3        # 本机GPU索引  
MASTER_ADDR=localhost # 主节点地址
MASTER_PORT=29500     # 通信端口
```

### 2. **CUDA通信桥接** (`cuda_bridge.s`)
- **功能**: 实现GPU间梯度同步
- **核心操作**:
  - `cuda_bridge_all_reduce_sum`: NCCL AllReduce同步梯度
  - `cuda_bridge_reduce_scatter`: 内存高效的梯度分散
  - `cuda_bridge_broadcast`: 主rank到其他rank的广播

**梯度同步流程**:
```
所有rank的梯度 ─> NCCL AllReduce ─> 求和 ─> 平均 ─> 优化器更新
```

### 3. **分布式预训练入口** (`distributed_pretrain_entry.s`)
- **功能**: 主训练循环，集成上述两个模块
- **流程**:
  1. 初始化分布式环境
  2. 为当前rank加载分配的数据切片
  3. 梯度积累循环
  4. 每N步后调用NCCL AllReduce同步梯度
  5. 执行优化器更新

---

## 启动方式

### 单机多GPU启动 (推荐)

```bash
# 启动4块GPU分布式训练
bash ./script/launch_pretrain_multi_gpu.sh 4

# 或使用torchrun
torchrun --nproc_per_node=4 \
    ./pretrain/distributed_pretrain_entry.s \
    --config=./pretrain/pretrain_config.toml \
    --epochs=1
```

### 手动启动多个进程

```bash
# Terminal 1 - rank 0
export RANK=0 LOCAL_RANK=0 WORLD_SIZE=4 MASTER_ADDR=localhost MASTER_PORT=29500
./pretrain/distributed_pretrain_entry.s

# Terminal 2 - rank 1
export RANK=1 LOCAL_RANK=1 WORLD_SIZE=4 MASTER_ADDR=localhost MASTER_PORT=29500
./pretrain/distributed_pretrain_entry.s

# Terminal 3 - rank 2
export RANK=2 LOCAL_RANK=2 WORLD_SIZE=4 MASTER_ADDR=localhost MASTER_PORT=29500
./pretrain/distributed_pretrain_entry.s

# Terminal 4 - rank 3
export RANK=3 LOCAL_RANK=3 WORLD_SIZE=4 MASTER_ADDR=localhost MASTER_PORT=29500
./pretrain/distributed_pretrain_entry.s
```

---

## 数据分片分配

### 数据并行策略

每个rank处理不同的数据切片，避免重复：

```
5131个shards分配给4个rank:
- Rank 0: shard_0, shard_4, shard_8, ...    (处理 5131/4 ≈ 1283个)
- Rank 1: shard_1, shard_5, shard_9, ...    (处理 5131/4 ≈ 1283个)
- Rank 2: shard_2, shard_6, shard_10, ...   (处理 5131/4 ≈ 1283个)
- Rank 3: shard_3, shard_7, shard_11, ...   (处理 5131/4 ≈ 1283个)
```

### 有效批大小计算

```
micro_batch_size = 8          # 单步GPU显存大小
gradient_accum_steps = 8      # 梯度积累步数
world_size = 4                # GPU数量

有效批大小 = 8 × 8 × 4 = 256
```

---

## 梯度同步细节

### 同步流程

```
Step 1: 前向传播（micro_batch_size=8）
        ├─ Rank 0: loss_0, grad_0
        ├─ Rank 1: loss_1, grad_1
        ├─ Rank 2: loss_2, grad_2
        └─ Rank 3: loss_3, grad_3

Step 2: 梯度积累（积累8步后）
        ├─ Rank 0: sum_0 = Σ(grad_0)
        ├─ Rank 1: sum_1 = Σ(grad_1)
        ├─ Rank 2: sum_2 = Σ(grad_2)
        └─ Rank 3: sum_3 = Σ(grad_3)

Step 3: NCCL AllReduce (所有rank同时执行)
        ├─ 收集所有rank的梯度
        ├─ 全局求和: grad_sync = sum_0 + sum_1 + sum_2 + sum_3
        ├─ 平均: grad_avg = grad_sync / 4
        └─ 分发回所有rank

Step 4: 优化器更新（所有rank同步执行）
        ├─ Rank 0: params_0 -= lr * grad_avg
        ├─ Rank 1: params_1 -= lr * grad_avg
        ├─ Rank 2: params_2 -= lr * grad_avg
        └─ Rank 3: params_3 -= lr * grad_avg
```

### NCCL AllReduce的CUDA实现

```c
// 伪代码
ncclAllReduce(
    d_gradients,        // GPU梯度指针
    d_gradients,        // 输出到同一位置
    num_gradients,      // 梯度数量
    ncclFloat,          // 数据类型
    ncclSum,            // 操作: 求和
    comm,               // NCCL communicator
    stream              // CUDA流
);

// 这个操作在GPU上并行执行，效率远高于CPU循环
```

---

## 性能优化

### 1. 异步梯度传输

```python
# 在计算下一步时，后台传输梯度
handle = cuda_bridge_all_reduce_async(launcher.cb, gradients)
# 执行其他计算
next_batch = load_next_batch()
# 等待梯度同步完成
synced_grads = async_all_reduce_wait(handle)
```

### 2. 内存优化

```toml
# pretrain_config.toml配置
gradient_checkpointing = true    # 减少显存占用
activation_checkpointing = true  # 激活值不保留
flash_attention = true           # 高效注意力
fused_kernels = true             # 融合CUDA核心
```

### 3. 通信优化

```
Ring AllReduce:
- 梯度分割成N个chunks
- 每个rank只与相邻rank通信
- N-1轮通信完成全局同步
- 通信复杂度: O(log N) -> O(N)但并行度高
```

---

## 预期性能提升

### RTX 4060 Ti 单GPU vs 多GPU

| 配置 | 批大小 | 显存 | 吞吐量 | 单轮时间 |
|------|--------|------|--------|----------|
| **1×RTX 4060 Ti** | 64 | 16GB | ~50 samples/s | ~18小时 |
| **2×RTX 4060 Ti** | 64×2=128 | 16GB×2 | ~95 samples/s | ~10小时 |
| **4×RTX 4090** | 256 | 24GB×4 | ~400 samples/s | ~4小时 |

**加速倍数**: 
- 2个GPU: ~1.9x加速
- 4个GPU: ~4.5x加速（考虑通信开销）

---

## 调试和监控

### 日志输出

```
[trainer-v2] step=531/1000000000 optimizer_step=66 loss=8.665277 
             tokens=543744 shard=0 line=70 accum=3/8

解释:
- step: 全局步数
- optimizer_step: 优化器更新步数
- loss: 损失值
- tokens: 处理的token总数
- shard: 当前shard索引
- line: 当前shard中的行索引
- accum: 梯度积累进度 (3/8)
```

### 监控GPU内存

```bash
# 实时监控所有GPU
watch -n 1 'nvidia-smi'

# 在训练脚本中
cuda_bridge_log_status(launcher.cb)
# 输出: [CUDA Bridge rank=0] device=0 memory=24576MB free=12288MB
```

### 进程状态检查

```bash
# 查看所有训练进程
ps aux | grep distributed_pretrain_entry

# 查看rank间通信
# (需要安装NVIDIA NCCL debugger)
```

---

## 常见问题

### Q1: 显存溢出
**A**: 减少micro_batch_size或增加gradient_accum_steps

### Q2: 训练速度没有提升
**A**: 
- 检查NCCL通信是否初始化成功
- 确保数据分片确实分散到了各rank
- 检查AllReduce的梯度尺寸（可能过大）

### Q3: 梯度不一致
**A**: 
- 确保所有rank使用相同的随机种子
- 验证AllReduce操作是否正确

### Q4: 进程间通信超时
**A**:
- 增加MASTER_PORT端口范围
- 检查防火墙设置
- 验证网络连接

---

## 文件结构

```
neurx/
├── distributed/
│   ├── cuda_bridge.s              # CUDA通信桥接 (NCCL AllReduce)
│   ├── distributed_pretrain_launcher.s  # 分布式启动器
│   ├── ddp/
│   └── ...
├── pretrain/
│   ├── distributed_pretrain_entry.s     # 主入口
│   ├── pretrain_config.toml             # 训练配置
│   └── ...
└── script/
    ├── launch_pretrain_multi_gpu.sh     # 多GPU启动脚本
    └── ...
```

---

## 下一步

1. **编译S语言代码**: `make build-distributed`
2. **运行单GPU测试**: `./script/launch_pretrain_multi_gpu.sh 1`
3. **运行多GPU训练**: `./script/launch_pretrain_multi_gpu.sh 4`
4. **监控训练进度**: 查看 `artifacts/logs/distributed_pretrain/` 下的日志

---

## 参考资源

- [PyTorch Distributed Data Parallel](https://pytorch.org/docs/stable/generated/torch.nn.parallel.DistributedDataParallel.html)
- [NCCL Documentation](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/)
- [torchrun](https://pytorch.org/docs/stable/elastic/run.html)
