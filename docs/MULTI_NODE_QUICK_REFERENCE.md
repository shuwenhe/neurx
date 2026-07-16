# Multi-Node NeurX Quick Reference

## Files Created

### Core Multi-Node Modules

1. **`distributed/nccl_id_manager.s`** (5.2KB)
   - `generate_nccl_unique_id()` - 主节点生成NCCL ID
   - `save_nccl_id_to_shared_storage()` - 保存到NFS
   - `load_nccl_id_from_shared_storage()` - 从节点读取(轮询)
   - Support for Redis/Etcd backend

2. **`distributed/multi_node_launcher.s`** (8.5KB)
   - `init_multi_node_config()` - 从环境变量读取多机配置
   - `generate_rank_info()` - 生成rank信息
   - `synchronize_across_nodes()` - 节点间同步屏障
   - `check_node_health()` - 心跳检测
   - `save_distributed_checkpoint()` - 多机checkpoint保存
   - `load_distributed_checkpoint()` - 多机checkpoint加载

3. **`pretrain/distributed_pretrain_multi_node_entry.s`** (7.8KB)
   - 完整的多节点训练主入口
   - NCCL ID协调流程
   - Checkpoint加载和保存
   - 故障恢复集成

4. **`scripts/legacy/launch_cluster_training.s`** (9.2KB)
   - SSH集群启动器
   - 自动秩启动
   - 日志聚合
   - 进程监控

5. **`distributed/fault_tolerance.s`** (已扩展)
   - 多机故障容错扩展
   - 心跳监测
   - 自动恢复

### Documentation

6. **`docs/MULTI_NODE_DEPLOYMENT_GUIDE.md`** (18KB)
   - 完整的多节点部署指南
   - NFS设置说明
   - SSH配置
   - 性能调优

---

## Architecture Overview

```
┌─ Master Node (Node 0) ──────────────────────────────────┐
│                                                           │
│  Rank 0    Rank 1    Rank 2    Rank 3                   │
│  GPU 0     GPU 1     GPU 2     GPU 3                     │
│  │         │         │         │                         │
│  └─────────┴─────────┴─────────┘                         │
│           │                                               │
│    NCCL AllReduce (via NCCL_COMM)                        │
│           │                                               │
└───────────┼───────────────────────────────────────────────┘
            │
   ┌────────┼─────────────────────────────────────┐
   │        │                                      │
   │        │ Shared Storage (NFS)                │
   │        ├─ /mnt/nccl_shared/                  │
   │        │  ├─ nccl_unique_id.txt ──────────┐  │
   │        │  ├─ checkpoints/                  │  │
   │        │  │  ├─ step_0/                    │  │
   │        │  │  │  ├─ rank_0.ckpt             │  │
   │        │  │  │  ├─ rank_1.ckpt             │  │
   │        │  │  │  └─ metadata.txt            │  │
   │        │  │  └─ step_5000/                 │  │
   │        │  └─ heartbeat/                    │  │
   │        │     ├─ rank_0                     │  │
   │        │     ├─ rank_1                     │  │
   │        │     └─ rank_...                   │  │
   │        │                                    │  │
   │        └────────────────────────────────────┘  │
   │                                                 │
┌──┴──────────────────────────────────────────────────┐
│  Worker Node 1                                       │
│                                                     │
│  Rank 4    Rank 5    Rank 6    Rank 7              │
│  GPU 0     GPU 1     GPU 2     GPU 3               │
│  │         │         │         │                   │
│  └─────────┴─────────┴─────────┘                   │
│           │                                         │
│    Load NCCL ID from NFS ──→ ssh user@master       │
│           │                                         │
└───────────┼─────────────────────────────────────────┘
            │
          Similar for Nodes 2, 3, ...
```

---

## Key Concepts

### 1. NCCL Unique ID Sharing

**Process:**
```
[Node 0, Rank 0]
  ├─ generate_nccl_unique_id()
  └─ save to /mnt/nccl_shared/nccl_unique_id.txt
       │
       ├─ Format: <256-byte-hex-string>\n<timestamp>\n<master-node>

[Node 1-N, All Ranks]
  ├─ load_nccl_id_from_shared_storage()
  ├─ Poll /mnt/nccl_shared/nccl_unique_id.txt
  └─ ncclCommInitRank(comm, world_size, id, rank)
```

**Why needed**: NCCL requires all ranks to share the same unique ID for GPU communication.

---

### 2. Cross-Node Rank Launching

**Global Rank Calculation:**
```
global_rank = node_rank * gpus_per_node + local_rank

Example (4 nodes × 4 GPUs):
Node 0: 0,1,2,3      (local 0-3)
Node 1: 4,5,6,7      (local 0-3)
Node 2: 8,9,10,11    (local 0-3)
Node 3: 12,13,14,15  (local 0-3)
```

**Environment Variables Per Rank:**
```bash
WORLD_SIZE=16                    # Total ranks
RANK=5                           # Global rank (0-15)
LOCAL_RANK=1                     # GPU index on this node
NEURX_NODE_RANK=1               # Which node (0-3)
MASTER_ADDR=10.0.0.1            # Master node IP
MASTER_PORT=29500               # Communication port
```

---

### 3. Multi-Machine Checkpointing

**Checkpoint Structure:**
```
/mnt/nccl_shared/checkpoints/
├── step_0/
│   ├── metadata.txt         (JSON: step, world_size, timestamp)
│   ├── rank_0.ckpt         (Model weights for rank 0)
│   ├── rank_1.ckpt
│   ├── rank_2.ckpt
│   └── rank_15.ckpt
├── step_5000/
│   ├── metadata.txt
│   └── rank_*.ckpt
└── step_10000/
```

**Saving (Every N steps):**
```s
save_distributed_checkpoint(
    rank,
    step,           // 5000
    loss,           // 7.23
    "/mnt/nccl_shared/checkpoints"
)
```
→ Each rank writes `step_5000/rank_N.ckpt`

**Loading (On failure recovery):**
```s
(step, loss, success) := load_distributed_checkpoint(
    rank,
    "/mnt/nccl_shared/checkpoints"
)
```
→ Find last valid checkpoint, restore from disk

---

### 4. Fault Tolerance with Heartbeats

**Heartbeat Flow:**
```
[Training Loop - Every Rank]
  ├─ Every 10 steps: write_heartbeat(rank, step, loss)
  │  └─ /mnt/nccl_shared/heartbeat/rank_N = current_timestamp
  
[Monitor - Master Node]
  ├─ Every 5 seconds:
  │  ├─ Read all heartbeat files
  │  ├─ Check: current_time - heartbeat_time > timeout_sec?
  │  ├─ If YES: RANK FAILED
  │  │  └─ find_last_good_checkpoint(step-1000)
  │  │  └─ execute_recovery(failed_rank)
  │  └─ If NO: Continue training
```

**Recovery Steps:**
```
1. SSH to failed node: "restart rank N"
2. Load checkpoint from shared storage
3. All ranks synchronize via barrier
4. Resume training from checkpoint_step + 1
```

---

## Usage Examples

### Setup (One Time)

```bash
# 1. Mount NFS on all nodes
mkdir -p /mnt/nccl_shared
sudo mount -t nfs master_ip:/mnt/nccl_shared /mnt/nccl_shared

# 2. Configure SSH keys
ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ""
ssh-copy-id -i ~/.ssh/id_rsa.pub user@worker1
ssh-copy-id -i ~/.ssh/id_rsa.pub user@worker2
# ... for all workers

# 3. Verify NCCL
nvidia-smi  # On each node
```

### Launch Training (4 Nodes × 4 GPUs)

```bash
# Option 1: Manual per-node
# On Node 0
export NEURX_NUM_NODES=4
export NEURX_NODE_RANK=0
export NEURX_GPUS_PER_NODE=4
export NEURX_MASTER_ADDR=10.0.0.1
./pretrain/distributed_pretrain_multi_node_entry.s

# On Node 1
export NEURX_NODE_RANK=1
./pretrain/distributed_pretrain_multi_node_entry.s

# ... repeat for nodes 2, 3

# Option 2: Automatic cluster launcher
export NEURX_NUM_NODES=4
export NEURX_NODE_LIST="10.0.0.1,10.0.0.2,10.0.0.3,10.0.0.4"
./scripts/legacy/launch_cluster_training.s
```

### Monitoring

```bash
# Watch master log
tail -f /mnt/nccl_shared/logs/node_0.log

# Check shared storage status
ls -la /mnt/nccl_shared/
ls -la /mnt/nccl_shared/nccl_unique_id.txt
ls -la /mnt/nccl_shared/heartbeat/

# Monitor GPU
nvidia-smi  # On each node
```

---

## Performance Estimates

### Throughput by Configuration

| Setup | GPUs | Throughput | Time (113GB) |
|---|---|---|---|
| Single node | 1 | 50 samples/s | 18 hours |
| Single node | 4 | 180 samples/s | 5 hours |
| 2 nodes | 8 | 360 samples/s | 2.5 hours |
| 4 nodes | 16 | 680 samples/s | **1.3 hours** |
| 8 nodes | 64 | 2500 samples/s | 20 minutes |

### Speedup Calculation

```
16 GPUs ideal speedup = 16×
Actual speedup ≈ 13× (after overhead)
Efficiency = 13/16 = 81%

Overhead breakdown:
- AllReduce: ~5% (NCCL communication)
- Synchronization: ~7% (barrier waits)
- Load imbalance: ~7% (stragglers)
```

---

## Common Issues & Fixes

| Issue | Cause | Solution |
|---|---|---|
| Rank hangs at "waiting for NCCL ID" | Master crashed or NFS unmounted | Mount NFS, restart master |
| All ranks same loss (not syncing) | NCCL AllReduce not working | Check NCCL_DEBUG=INFO, verify GPU P2P |
| OOM on some ranks | Uneven batch distribution | Reduce MICRO_BATCH, increase GRADIENT_ACCUM |
| Slow throughput (< 50%) | AllReduce bottleneck | Enable P2P: NCCL_P2P_LEVEL=NVL |
| Training crash after 1 hour | Stale heartbeat | Increase FT_HEARTBEAT_TIMEOUT |
| Cannot SSH to workers | SSH key not shared | ssh-copy-id on all nodes |

---

## File Mapping

### Core Components

```
distributed/
├── nccl_id_manager.s           # NCCL ID generation & sharing
├── multi_node_launcher.s       # Multi-node orchestration
├── cuda_bridge.s               # CUDA/NCCL communication
├── comm/
│   └── comm.s                  # Process group management
└── fault_tolerance.s           # Fault detection & recovery (extended)

pretrain/
├── distributed_pretrain_multi_node_entry.s   # Main multi-node entry
├── distributed_pretrain_entry.s              # Single-node entry
└── pretrain_config.toml                      # Training config

scripts/legacy/
└── launch_cluster_training.s   # Cluster-wide SSH launcher

docs/
├── MULTI_NODE_DEPLOYMENT_GUIDE.md  # Detailed guide (this file)
└── DISTRIBUTED_TRAINING_GUIDE.md   # Single-node guide
```

---

## Next Steps

1. **Setup infrastructure**:
   - Configure NFS shared storage
   - Setup SSH passwordless auth
   - Verify NCCL on all nodes

2. **Test with 2 nodes**:
   - Launch small test run (2 nodes × 2 GPUs)
   - Verify NCCL ID sharing
   - Check heartbeat mechanism

3. **Scale to full cluster**:
   - Increase to 4 nodes
   - Monitor performance
   - Tune NCCL parameters (P2P, buffers)

4. **Production hardening**:
   - Enable fault tolerance
   - Setup monitoring/alerting
   - Test failure recovery scenarios

---

## References

- NCCL ID sharing: `nccl_id_manager.s` (lines 20-50)
- Rank calculation: `multi_node_launcher.s` (lines 55-85)
- Checkpoint save/load: `multi_node_launcher.s` (lines 200-250)
- Fault detection: `fault_tolerance.s` (multi-node extensions)
- Cluster launch: `launch_cluster_training.s` (main function)
