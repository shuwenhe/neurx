# NeurX Multi-Node Distributed Training Guide

## Overview

This guide covers deploying NeurX distributed training across **multiple nodes** with:
- **NCCL Unique ID** sharing for GPU communication
- **Cross-node rank launching** via SSH
- **Multi-node checkpointing** for fault recovery
- **Automatic failover** and recovery

---

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│  Master Node (rank 0)                                        │
│  - Generates NCCL Unique ID                                  │
│  - Saves to shared storage (/mnt/nccl_shared)                │
│  - Monitors all ranks                                         │
└─────────────────────────────────────────────────────────────┘
         │
         │ NCCL AllReduce via NCCL_COMM_INIT_RANK
         │
┌────────┴────────┐
│                 │
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Worker Node 1   │ │ Worker Node 2   │ │ Worker Node N   │
│ Ranks 0-N1      │ │ Ranks N1+1-N2   │ │ Ranks N2+1-...  │
│ GPUs 0-N1       │ │ GPUs 0-N2       │ │ GPUs 0-NN       │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

### Data Flow

1. **Master generates NCCL ID** → Saves to `/mnt/nccl_shared/nccl_unique_id.txt`
2. **All workers load NCCL ID** from shared storage
3. **Each rank initializes NCCL communicator** with its global rank
4. **Training loop**: Forward → Backward → AllReduce (sync gradients)
5. **Periodic checkpointing** to `/mnt/nccl_shared/checkpoints/`
6. **Fault detection** via heartbeat monitoring
7. **Auto-recovery** from last good checkpoint

---

## Setup Requirements

### 1. NFS Shared Storage

All nodes must access shared storage for NCCL ID and checkpoints:

```bash
# On master node
sudo mkdir -p /mnt/nccl_shared
sudo chown -R $USER:$USER /mnt/nccl_shared
sudo chmod 755 /mnt/nccl_shared

# Export NFS
echo "/mnt/nccl_shared 10.0.0.0/24(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
sudo exportfs -ra
sudo systemctl restart nfs-server

# On each worker node
sudo mkdir -p /mnt/nccl_shared
sudo mount -t nfs master_ip:/mnt/nccl_shared /mnt/nccl_shared
```

### 2. SSH Passwordless Access

Configure SSH keys for all nodes:

```bash
# On master node
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copy to all workers
for node in worker1 worker2 worker3; do
    ssh-copy-id -i ~/.ssh/id_rsa.pub user@$node
done

# Test
ssh worker1 "hostname"
```

### 3. GPU Drivers and NCCL

Ensure all nodes have:
- NVIDIA GPU drivers (≥ 530.00)
- NCCL runtime libraries (≥ 2.18)
- CUDA Toolkit (≥ 12.0)

```bash
# Check NVIDIA setup
nvidia-smi
nccl-tests/build/all_reduce_perf -b 8 -e 256M -f 2 -g 4
```

---

## Configuration

### Environment Variables

```bash
# Cluster topology
export NEURX_NUM_NODES=4                 # Total nodes
export NEURX_NODE_RANK=${NODE_RANK}      # Current node index (0-based)
export NEURX_GPUS_PER_NODE=4             # GPUs per node
export NEURX_NODE_LIST="10.0.0.1,10.0.0.2,10.0.0.3,10.0.0.4"

# Master coordination
export NEURX_MASTER_ADDR=10.0.0.1        # Master node IP
export NEURX_MASTER_PORT=29500           # Master port

# Distributed training
export NEURX_DDP_BACKEND=nccl            # NCCL for GPU, gloo for CPU
export NEURX_NCCL_STORE_PATH=/mnt/nccl_shared

# Training parameters
export NEURX_PRETRAIN_STEPS=50000
export NEURX_PRETRAIN_MICRO_BATCH=8
export NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=8
export NEURX_PRETRAIN_LEARNING_RATE=0.0002

# Fault tolerance
export NEURX_ENABLE_FT=true              # Enable fault tolerance
export NEURX_FT_CHECKPOINT_INTERVAL=5000 # Checkpoint every N steps
export NEURX_FT_HEARTBEAT_TIMEOUT=30     # Heartbeat timeout (seconds)
export NEURX_FT_MAX_RETRIES=3            # Max recovery attempts

# Logging
export NEURX_LOG_DIR=/mnt/nccl_shared/logs
export NEURX_LOG_LEVEL=INFO
```

---

## Launching Multi-Node Training

### Quick Start (4 Nodes × 4 GPUs = 16 GPUs)

```bash
cd /home/neurx/train/neurx

# Set cluster config
export NEURX_NUM_NODES=4
export NEURX_GPUS_PER_NODE=4
export NEURX_MASTER_ADDR=10.0.0.1
export NEURX_NODE_LIST="10.0.0.1,10.0.0.2,10.0.0.3,10.0.0.4"

# Launch on all nodes
make pretrain-gpu-distributed-multi-node
```

### Manual Launch Per Node

**On Master Node (rank 0-3):**

```bash
cd /home/neurx/train/neurx

export NEURX_NUM_NODES=4
export NEURX_NODE_RANK=0
export NEURX_GPUS_PER_NODE=4
export NEURX_MASTER_ADDR=10.0.0.1
export NEURX_MASTER_PORT=29500
export WORLD_SIZE=16

# Launch training script
./pretrain/distributed_pretrain_multi_node_entry.s 2>&1 | tee /mnt/nccl_shared/logs/node_0.log &
```

**On Worker Node 2 (rank 4-7):**

```bash
cd /home/neurx/train/neurx

export NEURX_NUM_NODES=4
export NEURX_NODE_RANK=1
export NEURX_GPUS_PER_NODE=4
export NEURX_MASTER_ADDR=10.0.0.1
export NEURX_MASTER_PORT=29500
export WORLD_SIZE=16

./pretrain/distributed_pretrain_multi_node_entry.s 2>&1 | tee /mnt/nccl_shared/logs/node_1.log &
```

### Using Cluster Launcher

The `launch_cluster_training.s` script handles SSH coordination:

```bash
export NEURX_NUM_NODES=4
export NEURX_NODE_LIST="10.0.0.1,10.0.0.2,10.0.0.3,10.0.0.4"
export NEURX_MASTER_ADDR=10.0.0.1
export NEURX_SSH_USER=root
export NEURX_SSH_KEY=/root/.ssh/id_rsa

./scripts/legacy/launch_cluster_training.s
```

---

## NCCL ID Sharing

### Master Node Flow

```
[Rank 0] → generate_nccl_unique_id()
         → save_nccl_id_to_shared_storage("/mnt/nccl_shared")
         → Write to /mnt/nccl_shared/nccl_unique_id.txt
```

**File Format:**
```
0123456789abcdef0123456789abcdef0123456789abcdef...
20260714_161200
10.0.0.1
```

### Worker Node Flow

```
[Rank N] → load_nccl_id_from_shared_storage("/mnt/nccl_shared", timeout=300s)
         → Poll for /mnt/nccl_shared/nccl_unique_id.txt
         → Read NCCL ID from file
         → Initialize NCCL communicator with this ID
```

### Using Redis (Optional)

For clusters without NFS:

```bash
# Start Redis on master
redis-server --bind 10.0.0.1 --port 6379

# Set environment
export NEURX_NCCL_STORE=redis
export NEURX_NCCL_STORE_ADDR=10.0.0.1
export NEURX_NCCL_STORE_PORT=6379

# Redis will store NCCL ID at key: nccl:unique_id
```

---

## Rank Launching

### Global Rank Calculation

For **4 nodes × 4 GPUs**:

```
Node 0: Rank 0,1,2,3     (global = 0*4 + local_rank)
Node 1: Rank 4,5,6,7     (global = 1*4 + local_rank)
Node 2: Rank 8,9,10,11   (global = 2*4 + local_rank)
Node 3: Rank 12,13,14,15 (global = 3*4 + local_rank)
```

Formula:
```
global_rank = node_rank * gpus_per_node + local_rank
```

### Environment Variables Per Rank

```bash
# Each GPU process gets:
export WORLD_SIZE=16
export RANK=4              # Global rank (0-15)
export LOCAL_RANK=0        # GPU index on this node (0-3)
export NEURX_NODE_RANK=1   # Which node (0-3)
export MASTER_ADDR=10.0.0.1
export MASTER_PORT=29500
```

---

## Checkpointing & Recovery

### Checkpoint Structure

```
/mnt/nccl_shared/checkpoints/
├── step_0/
│   ├── metadata.txt
│   ├── rank_0.ckpt
│   ├── rank_1.ckpt
│   └── rank_16.ckpt
├── step_5000/
│   ├── metadata.txt
│   ├── rank_0.ckpt
│   ├── rank_1.ckpt
│   └── rank_16.ckpt
└── step_10000/
    ├── metadata.txt
    └── rank_*.ckpt
```

**Metadata Format:**
```
step=5000
world_size=16
timestamp=20260714_161200
complete=true
```

### Saving Checkpoints

```s
save_distributed_checkpoint(
    rank_info,
    step,        // Step number
    loss,        // Training loss
    "/mnt/nccl_shared/checkpoints"
)
```

Each rank saves `rank_N.ckpt` containing:
- Model weights
- Optimizer state
- Training metadata

### Loading from Checkpoint

```s
(step, loss, success) := load_distributed_checkpoint(
    rank_info,
    "/mnt/nccl_shared/checkpoints"
)

if success {
    resume_training_from_step(step)
}
```

---

## Fault Tolerance

### Heartbeat Mechanism

Each rank writes heartbeat every 10 seconds:
```
/mnt/nccl_shared/heartbeat/rank_0: timestamp=1721004000
/mnt/nccl_shared/heartbeat/rank_1: timestamp=1721004000
...
```

Master node monitors:
```bash
# Check for stale heartbeats
current_time - heartbeat_time > NEURX_FT_HEARTBEAT_TIMEOUT (30s)
```

### Failure Detection

```
[Master Monitor Loop]
  ├─ Read all rank heartbeats from shared storage
  ├─ Check if any heartbeat is stale (> 30 seconds old)
  ├─ If stale: Mark rank as FAILED
  │   └─ Find last good checkpoint
  │   └─ Plan recovery for failed rank
  ├─ Execute recovery:
  │   ├─ SSH to node hosting failed rank
  │   ├─ Restart rank process
  │   ├─ Load checkpoint from shared storage
  │   ├─ Synchronize all ranks
  │   └─ Resume training from checkpoint
  └─ Repeat every 10 seconds
```

### Recovery Example (Rank 5 fails)

```
[t=0s] Training at step 50000
[t=35s] Master detects rank 5 has no heartbeat for 35s (timeout=30s)
[t=35s] Find last good checkpoint at step 49000
[t=40s] SSH to node 1: "restart rank 5 with checkpoint"
[t=45s] All ranks re-sync via barrier
[t=50s] Resume training from step 49001
```

### Configuration

```bash
export NEURX_ENABLE_FT=true
export NEURX_FT_HEARTBEAT_INTERVAL=10        # Write heartbeat every 10s
export NEURX_FT_HEARTBEAT_TIMEOUT=30         # Mark failed if no HB for 30s
export NEURX_FT_CHECKPOINT_INTERVAL=5000     # Save checkpoint every 5000 steps
export NEURX_FT_MAX_RETRIES=3                # Max 3 recovery attempts
```

---

## Performance Tuning

### Expected Throughput

For **4 nodes × 4 GPUs (16 GPU total)**:

| Configuration | Throughput | Training Time |
|---|---|---|
| 1 GPU (RTX 4060 Ti) | 50 samples/s | 18 hours |
| 4 GPUs (1 node) | 180 samples/s | 5 hours |
| 8 GPUs (2 nodes) | 360 samples/s | 2.5 hours |
| **16 GPUs (4 nodes)** | **680 samples/s** | **1.3 hours** |

### Optimization Tips

1. **Reduce NCCL latency**:
   ```bash
   export NCCL_P2P_LEVEL=NVL  # Enable PCIe/NVLink P2P
   export NCCL_P2P_DISABLE=0
   export NCCL_SOCKET_NTHREADS=4
   ```

2. **Increase gradient buffer**:
   ```bash
   export NEURX_PRETRAIN_MICRO_BATCH=16
   export NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS=4
   ```

3. **Async communication**:
   ```bash
   export NCCL_ASYNC_ERROR_HANDLING=1  # Handle errors asynchronously
   ```

---

## Monitoring

### Real-time Monitoring

```bash
# Watch training progress
tail -f /mnt/nccl_shared/logs/node_0.log

# Expected output:
# [MAIN] Multi-Node Configuration:
#   - Total nodes: 4
#   - Current node rank: 0
#   - World size: 16
#   - Current global rank: 0
# [MAIN] Rank 0 loaded NCCL ID from shared storage
# [TRAIN] step=100 loss=8.45
# [TRAIN] step=200 loss=7.23
```

### Check Rank Status

```bash
# List all training processes
ps aux | grep distributed_pretrain_multi_node_entry

# Check NCCL ID is shared
cat /mnt/nccl_shared/nccl_unique_id.txt

# View heartbeats
ls -la /mnt/nccl_shared/heartbeat/
```

### GPU Monitoring

```bash
# On each node, monitor GPU usage
watch -n 1 nvidia-smi

# Expected: Each GPU at ~90-95% utilization
```

---

## Troubleshooting

### Issue: Rank hangs at "waiting for NCCL ID"

**Cause**: Master node failed or shared storage not accessible

**Fix**:
```bash
# Check NFS mounting
mount | grep nccl_shared

# Check master generated ID
ls -la /mnt/nccl_shared/nccl_unique_id.txt

# If missing, manually trigger master:
ssh master_node "cd /home/neurx/train/neurx && ./pretrain/distributed_pretrain_multi_node_entry.s"
```

### Issue: Low throughput (< 50% of expected)

**Cause**: NCCL communication bottleneck or stragglers

**Fix**:
```bash
# Check NCCL diagnostics
NCCL_DEBUG=INFO ./pretrain/distributed_pretrain_multi_node_entry.s 2>&1 | grep -i nccl

# Reduce batch size to reduce AllReduce payload
export NEURX_PRETRAIN_MICRO_BATCH=4

# Enable P2P
export NCCL_P2P_LEVEL=NVL
```

### Issue: Training crashes after recovery

**Cause**: Checkpoint corruption or version mismatch

**Fix**:
```bash
# Clean checkpoints and restart
rm -rf /mnt/nccl_shared/checkpoints/*
rm -rf /mnt/nccl_shared/heartbeat/*

# Restart training from scratch
make pretrain-gpu-distributed-multi-node
```

### Issue: SSH timeout when launching nodes

**Cause**: Network latency or SSH key issues

**Fix**:
```bash
# Increase SSH timeout
export NEURX_SSH_TIMEOUT=60

# Debug SSH
ssh -vvv user@worker_node "hostname"

# Ensure passwordless sudo if needed
echo "user ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
```

---

## Performance Metrics

### Step Timing Breakdown

Expected for **16 GPU (4 nodes)**:

```
Per-iteration time: 150ms
├─ Forward pass: 40ms
├─ Backward pass: 70ms
├─ Gradient AllReduce: 30ms  (most expensive!)
└─ Optimizer step: 10ms

AllReduce time for 16 GPUs:
  - Single GPU gradient: ~512MB
  - AllReduce time ≈ 2 × (log2(16) × latency + 512MB/bandwidth)
  - With NCCL: ≈ 30ms for all-reduce sum
```

### Expected Speedup

```
16 GPUs = 4 nodes × 4 GPUs

Ideal speedup: 16× (if perfect scaling)
Actual speedup: ~13× (after overhead)
Efficiency: 13/16 = 81%

Bottlenecks:
- AllReduce: 5% overhead
- Synchronization: 7% overhead
- Load imbalance: 7% overhead
```

---

## Multi-Node Deployment Examples

### Example 1: 2 Nodes × 4 GPUs Each

```bash
# On master node
export NEURX_NUM_NODES=2
export NEURX_NODE_RANK=0
export NEURX_GPUS_PER_NODE=4
export NEURX_NODE_LIST="10.0.0.1,10.0.0.2"
export NEURX_MASTER_ADDR=10.0.0.1
./pretrain/distributed_pretrain_multi_node_entry.s

# On worker node
export NEURX_NUM_NODES=2
export NEURX_NODE_RANK=1
export NEURX_GPUS_PER_NODE=4
export NEURX_NODE_LIST="10.0.0.1,10.0.0.2"
export NEURX_MASTER_ADDR=10.0.0.1
./pretrain/distributed_pretrain_multi_node_entry.s
```

**Result**: 8 GPUs, 8× speedup, ~2.5 hour training

### Example 2: 8 Nodes × 8 GPUs Each (64 GPUs Total)

```bash
export NEURX_NUM_NODES=8
export NEURX_GPUS_PER_NODE=8
export NEURX_MASTER_ADDR=10.0.0.1
export NEURX_NODE_LIST="10.0.0.1,10.0.0.2,...,10.0.0.8"

# Use cluster launcher for automatic SSH deployment
./scripts/legacy/launch_cluster_training.s
```

**Result**: 64 GPUs, ~50× speedup, ~15 min training

---

## References

- [NCCL Documentation](https://docs.nvidia.com/deeplearning/nccl/user-guide/)
- [PyTorch DDP Guide](https://pytorch.org/tutorials/intermediate/ddp_tutorial.html)
- [NFS Setup](https://linux.die.net/man/5/exports)
- [SSH Hardening](https://man.openbsd.org/sshd_config)
