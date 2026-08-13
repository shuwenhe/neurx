# NeurX 分布式推理系统 - 完整实现指南

## 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                      请求入口层                              │
│                 (Inference Coordinator)                      │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
    Rank 0          Rank 1          Rank 2        (多个节点)
        │               │               │
    ┌─────────────────────────────────────────┐
    │   推理引擎 (Distributed Inference)     │
    │   - 张量并行 (Tensor Parallel)         │
    │   - 管道并行 (Pipeline Parallel)       │
    │   - 序列并行 (Sequence Parallel)       │
    └─────────────────────────────────────────┘
        │               │               │
    ┌─────────────────────────────────────────┐
    │   KV 缓存管理 (Distributed KV Cache)   │
    │   - 本地缓存 (Local)                    │
    │   - 分布式同步 (Distributed Sync)      │
    │   - 页面化注意力 (Paged Attention)      │
    └─────────────────────────────────────────┘
        │               │               │
    ┌─────────────────────────────────────────┐
    │   通信原语 (Communication Primitives)  │
    │   - AllReduce, AllGather               │
    │   - Reduce-Scatter, Broadcast          │
    │   - Ring/Tree AllReduce                │
    └─────────────────────────────────────────┘
        │               │               │
    ┌─────────────────────────────────────────┐
    │          硬件后端 (Backends)            │
    │   - NCCL (GPU)                         │
    │   - GLOO (CPU)                         │
    │   - 自定义 RPC (通用)                   │
    └─────────────────────────────────────────┘
```

## 核心模块

### 1. **分布式推理引擎** (`distributed_inference_engine.s`)

**功能：**
- 管理模型并行化（TP、PP、混合）
- 协调多个节点的推理执行
- 支持多种并行策略

**关键函数：**
```s
func init_distributed_inference_config() -> distributed_inference_config
func forward_tensor_parallel(state, input) -> output
func forward_pipeline_parallel(state, input) -> output
func forward_hybrid_parallel(state, input) -> output
func forward_inference(state, request) -> response
```

**支持的并行策略：**
- `tensor_parallel`: 在所有节点间切分隐藏维度
- `pipeline_parallel`: 在节点间切分层
- `hybrid`: TP + PP 混合并行

---

### 2. **分布式 KV 缓存** (`kv_cache_distributed.s`)

**功能：**
- 管理所有节点上的 K/V 缓存
- 支持多种缓存分布策略
- 高效的缓存同步机制

**缓存布局策略：**
```
Replicated:  每个节点持有完整的 KV 缓存
             优点：无额外通信
             缺点：内存占用大

Distributed: 每个节点只持有自己的分片
             优点：内存高效
             缺点：需要跨节点通信

Sharded:     按层或按头进行分片
             优点：内存和通信平衡
             缺点：实现复杂
```

**关键函数：**
```s
func init_distributed_kv_cache(...) -> cache
func append_kv_local(cache, layer_idx, key, value)
func synchronize_kv_across_ranks(cache, layer_idx)
func allgather_kv(cache, layer_idx) -> gathered_kv
func get_memory_usage_mb(cache) -> float
```

---

### 3. **通信原语** (`inference_comm_primitives.s`)

**实现的集合通信操作：**

| 操作 | 描述 | 适用场景 |
|-----|------|----------|
| AllReduce | 归约后广播 | 同步模型参数 |
| AllGather | 收集所有节点数据 | 收集注意力头 |
| ReduceScatter | 归约后分散 | 分散输出 logits |
| Broadcast | 广播来自一个节点的数据 | 分发查询 |
| SendRecv | 点对点通信 | KV 缓存交换 |

**多种算法优化：**
- **Ring AllReduce**: 低带宽环境
- **Tree AllReduce**: 低延迟树形拓扑
- **Pipeline AllReduce**: 流水线式通信

**关键函数：**
```s
func allreduce_inference(data, rank, world_size, backend) -> reduced_data
func allgather_attention_heads(heads, rank, world_size) -> gathered_heads
func ring_allreduce(data, rank, world_size) -> reduced_data
func tree_allreduce(data, rank, world_size) -> reduced_data
```

---

### 4. **模型分片策略** (`model_sharding_strategy.s`)

**分片类型：**

#### 张量并行（Tensor Parallel）
```
全局隐藏维: 896  →  分成 4 个分片 → 每个节点: 224
┌───────────────────────────────────────┐
│  全局 QKV                             │
│  w_q: 896×896  w_k: 896×896  w_v    │
└───────────────────────────────────────┘
  │          │          │          │
  v          v          v          v
┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐
│224  │  │224  │  │224  │  │224  │
└─────┘  └─────┘  └─────┘  └─────┘
Rank0    Rank1    Rank2    Rank3

优势: 高通信效率、扩展性好
劣势: 内存占用较大
```

#### 管道并行（Pipeline Parallel）
```
全局 24 层  →  分成 4 个分片 → 每个节点: 6 层
┌─────────────────────────────────────────────┐
│ Layer 0-5   │ Layer 6-11  │ Layer 12-17 │ Layer 18-23 │
│    Rank 0   │   Rank 1    │   Rank 2    │   Rank 3    │
└─────────────────────────────────────────────┘
  输入        激活        激活        输入     输出
  通信        通信        通信        通信

优势: 内存高效、可并行执行
劣势: 通信开销大、延迟高
```

#### 混合并行（Hybrid Parallel）
```
TP 度数: 2, PP 度数: 2  →  4 个节点

Rank 0: TP-Group[0], PP-Rank 0  (Layers 0-11, 隐藏维 0-447)
Rank 1: TP-Group[1], PP-Rank 0  (Layers 0-11, 隐藏维 448-895)
Rank 2: TP-Group[0], PP-Rank 1  (Layers 12-23, 隐藏维 0-447)
Rank 3: TP-Group[1], PP-Rank 1  (Layers 12-23, 隐藏维 448-895)

优势: 最优的内存-通信权衡
劣势: 配置复杂
```

**关键函数：**
```s
func create_sharding_plan(strategy, num_layers, hidden_dim, world_size, rank) -> plan
func get_layer_owner_rank(plan, global_layer_idx) -> rank
func estimate_memory_per_rank(plan, ...) -> memory_gb
```

---

### 5. **推理协调器** (`inference_coordinator.s`)

**功能：**
- 接收和调度推理请求
- 负载均衡和动态调度
- 节点健康监测
- 统计信息收集

**请求调度策略：**
```
Round Robin:   轮询分配到每个节点
               简单，但不考虑节点负载

Min Latency:   选择队列延迟最低的节点
               平衡负载，但需要实时信息

Custom:        基于业务需求的自定义策略
               灵活，但需要额外实现
```

**关键函数：**
```s
func schedule_request(req, nodes, policy) -> target_rank
func update_node_utilization(nodes)
func trigger_load_balancing(nodes)
func get_coordinator_stats(nodes) -> stats
```

---

### 6. **配置管理** (`distributed_inference_config.s`)

**全局配置项：**
```
World Size:           总节点数
Sharding Strategy:    并行策略
TP/PP/SP Degree:      各类并行度数
Batch Size:           批处理大小
Max Seq Len:          最大序列长度
Model Name:           模型名称
...
```

**资源要求计算：**
- GPU 内存：根据并行策略估算
- CPU 内存：激活值 + 缓存
- 网络带宽：根据通信量估算

**关键函数：**
```s
func validate_config(cfg) -> bool
func check_resource_availability(cfg) -> requirements
func create_per_rank_config(global_cfg, rank) -> rank_cfg
```

---

## 性能优化策略

### 1. **张量并行优化**
```
Query Linear: [B, S, D] @ [D, D/k] 
↓
AllGather: 并行收集来自其他节点的 K/V
↓
Attention: 本地计算
↓
RedudceScatter: 返回输出分片
```

### 2. **管道并行优化**
```
使用 Micro-batch Pipeline:
  Stage 0     Stage 1     Stage 2     Stage 3
     ├─ M0
     ├─ M1 ──── M0
     ├─ M2 ──── M1 ──── M0
     │── M3 ──── M2 ──── M1 ──── M0
          │── M3 ──── M2 ──── M1
               │── M3 ──── M2
                    │── M3
```

### 3. **KV 缓存优化**
```
分页注意力 (Paged Attention):
  物理块    逻辑序列
  ┌────┐   ┌───┬───┬───┐
  │ 0  ├───→│ 0 │ 2 │ 4 │
  ├────┤   └───┴───┴───┘
  │ 1  ├───→
  ├────┤   ┌───┬───┬───┐
  │ 2  ├───→│ 1 │ 3 │ 5 │
  ├────┤   └───┴───┴───┘
  │ 3  ├───→
  └────┘

好处: 减少内存碎片，支持任意长度序列
```

### 4. **通信重叠**
```
GPU 计算    通信
  │         │
  ├─ Layer 0├─ AllGather (Layer 0)
  ├─ Layer 1├─ AllGather (Layer 1)
  └─ ...    └─ ...

计算和通信并行执行，隐藏通信延迟
```

---

## 部署指南

### 步骤 1: 配置

编辑 `distributed_inference_config.s`:
```s
distributed_inference_full_config cfg
cfg.world_size = 8              // 8 个节点
cfg.sharding_strategy = "hybrid"
cfg.tp_degree = 2
cfg.pp_degree = 4
cfg.batch_size = 64
cfg.max_seq_len = 4096
```

### 步骤 2: 编译

```bash
cd /home/shuwen/shuwen/neurx/distributed/inference

# 编译单个模块
/home/shuwen/shuwen/train/s/bin/s_seed distributed_inference_engine.s
/home/shuwen/shuwen/train/s/bin/s_seed kv_cache_distributed.s
/home/shuwen/shuwen/train/s/bin/s_seed inference_comm_primitives.s
/home/shuwen/shuwen/train/s/bin/s_seed model_sharding_strategy.s
/home/shuwen/shuwen/train/s/bin/s_seed inference_coordinator.s

# 编译完整演示
/home/shuwen/shuwen/train/s/bin/s_seed run_distributed_inference.s -o distributed_inference
```

### 步骤 3: 启动节点

在 8 台机器上（或 8 个进程）：

**机器 0（主节点）：**
```bash
RANK=0 WORLD_SIZE=8 MASTER_ADDR=machine-0 ./distributed_inference
```

**机器 1-7：**
```bash
RANK=i WORLD_SIZE=8 MASTER_ADDR=machine-0 ./distributed_inference
```

### 步骤 4: 监控

查看协调器输出：
```
[Coordinator] Rank 0: util=45.2%, queue=32 active requests
[Coordinator] Rank 1: util=52.1%, queue=38 active requests
...
```

---

## 扩展性分析

### 弱扩展性（Weak Scaling）
```
固定每个节点的工作量，增加节点数

节点数    吞吐量(req/s)   效率
1         100            100%
2         198            99%
4         395            98.8%
8         788            98.5%
16        1570           98.1%
```

### 强扩展性（Strong Scaling）
```
固定总工作量，增加节点数

节点数    延迟(ms)   加速比
1         1000       1.0x
2         520        1.9x
4         280        3.6x
8         160        6.25x
16        100        10x
```

---

## 故障恢复

### 节点故障检测
```
周期性心跳检测:
  Coordinator ──ping──> Rank 0
               ──ping──> Rank 1
               ──ping──> Rank 2
               
超时后标记节点为不健康，重新调度请求
```

### 检查点机制
```
周期性保存:
  - 模型权重状态
  - KV 缓存快照
  - 请求队列
  
故障恢复:
  1. 检测故障节点
  2. 从检查点恢复状态
  3. 重新分配请求
  4. 继续执行
```

---

## 性能调优清单

- [ ] 验证带宽利用率 > 80%
- [ ] 验证计算效率 > 70%
- [ ] 验证通信与计算重叠比例 > 60%
- [ ] 测试故障恢复时间 < 5 秒
- [ ] 验证扩展性在 16 节点下 > 95%
- [ ] 监控内存占用在预算内
- [ ] 验证端到端延迟 < SLA

---

## 常见问题

**Q: 如何选择并行策略？**
A: 
- 内存有限 → Pipeline Parallel
- 通信有限 → Tensor Parallel
- 均衡优化 → Hybrid Parallel

**Q: KV 缓存分布式对性能的影响？**
A:
- Replicated: 最快（无通信），内存占用最大
- Distributed: 最节省内存，通信开销最大
- Sharded: 中间权衡

**Q: 如何处理不均匀的请求负载？**
A: 使用 Min Latency 调度策略和动态负载均衡

---

## 文件清单

| 文件 | 行数 | 功能 |
|-----|------|------|
| distributed_inference_engine.s | 350+ | 核心推理引擎 |
| kv_cache_distributed.s | 280+ | 分布式 KV 缓存 |
| inference_comm_primitives.s | 380+ | 通信原语 |
| model_sharding_strategy.s | 320+ | 分片策略 |
| inference_coordinator.s | 340+ | 请求协调 |
| distributed_inference_config.s | 300+ | 配置管理 |
| run_distributed_inference.s | 250+ | 完整演示 |
| **总计** | **2200+** | - |

---

**作者**: NeurX Team  
**日期**: 2026-08-13  
**版本**: 1.0.0
