# DeepSpeed ZeRO-1 Implementation (S Language)

## Overview

Pure S language implementation of DeepSpeed ZeRO Stage 1 optimizer state partitioning for distributed large model training.

## Architecture

```
distributed/
├── comm_primitives.s      # Communication primitives (AllReduce, AllGather, ReduceScatter)
├── partition_utils.s      # Parameter partitioning utilities
└── zero_optimizer.s       # ZeRO-1 AdamW optimizer with state sharding
```

## Features

### ✅ Implemented

1. **ZeRO Stage 1**: Optimizer state partitioning
   - Each GPU stores 1/N of optimizer states (momentum + variance)
   - Memory saving: 50% (2 GPUs), 75% (4 GPUs), 87.5% (8 GPUs)

2. **Communication Primitives** (Stub implementation)
   - `all_reduce()`: Sum gradients across all GPUs
   - `all_gather()`: Gather local data from all GPUs
   - `reduce_scatter()`: Reduce and scatter to each GPU
   - `broadcast()`: Broadcast from root to all GPUs
   - `barrier()`: Synchronization barrier

3. **AdamW Optimizer**
   - Momentum and variance tracking
   - Bias correction
   - Weight decay
   - Distributed parameter updates

4. **Partition Utilities**
   - Automatic parameter partitioning
   - Load balancing (handles non-divisible sizes)
   - Local/global index mapping

### 🚧 TODO

1. **S Runtime Integration**
   - Execute compiled IR
   - Real tensor operations

2. **Real Distributed Backend**
   - NCCL for NVIDIA GPUs
   - GLOO for CPU/generic
   - Replace stub implementations

3. **CPU Offload**
   - Move optimizer states to CPU memory
   - Async PCIe transfers
   - Overlap computation and communication

4. **ZeRO Stage 2**
   - Gradient partitioning
   - Additional 50% memory saving

5. **ZeRO Stage 3**
   - Parameter partitioning
   - Maximum memory efficiency
   - Train 100B+ models on single node

## Usage

### Build

```bash
make build-deepspeed-zero
```

### Test

```bash
make test-zero-optimizer
```

## Memory Savings Example

**Model**: 1M parameters (4 MB)  
**Optimizer**: AdamW (momentum + variance)

| GPUs | Optimizer State/GPU | Memory Saved |
|------|---------------------|--------------|
| 1    | 8 MB (baseline)     | 0%           |
| 2    | 4 MB                | 50%          |
| 4    | 2 MB                | 75%          |
| 8    | 1 MB                | 87.5%        |

## Algorithm

### ZeRO-1 Step

```
1. Forward pass: all_gather(local_params) → full_params
2. Backward pass: compute gradients
3. Gradient reduction: all_reduce(grads)
4. Optimizer update (local):
   - Update only 1/N of optimizer states
   - momentum[local] = β₁·momentum + (1-β₁)·grad
   - variance[local] = β₂·variance + (1-β₂)·grad²
   - param -= lr · m̂/(√v̂ + ε) + weight_decay·lr·param
5. Parameter broadcast: all_gather(local_params) for next step
```

## Code Structure

### comm_primitives.s

```s
struct CommContext {
    int world_size      // Total number of GPUs
    int rank            // Current GPU ID
    string backend      // "nccl" or "gloo"
    bool initialized
}

func all_reduce(CommContext ctx, []float data, string op) []float
func all_gather(CommContext ctx, []float local_data) []float
func reduce_scatter(CommContext ctx, []float data) []float
```

### zero_optimizer.s

```s
struct ZeROConfig {
    int stage              // 1, 2, or 3
    bool cpu_offload
    float lr, beta1, beta2, eps, weight_decay
}

struct ZeROState {
    []float local_momentum    // 1/N of full momentum
    []float local_variance    // 1/N of full variance
    []float params, grads
    int step, partition_id, world_size
}

func zero_step(ZeROState state, ZeROConfig cfg) ZeROState
```

## Performance Characteristics

| Metric                  | Single GPU | ZeRO-1 (4 GPUs) |
|-------------------------|------------|-----------------|
| Optimizer Memory        | 100%       | 25%             |
| Parameter Memory        | 100%       | 100%            |
| Gradient Memory         | 100%       | 100%            |
| Communication Overhead  | 0          | AllGather + ReduceScatter |
| Computation             | 100%       | 100%            |

## Integration with NeurX

### Phase 2A Training

Replace standard optimizer:

```s
// Before (baseline)
adamw_step(params, grads, optimizer_state)

// After (ZeRO-1)
zero_step(zero_state, zero_config)
```

### Expected Improvements

- **Qwen2.5-0.5B** (0.5B params):
  - Baseline: ~4 GB optimizer state
  - ZeRO-1 (4 GPUs): ~1 GB per GPU
  - **75% memory saved**

- **Larger models** (7B params):
  - Baseline: ~56 GB optimizer state (OOM on single GPU)
  - ZeRO-1 (8 GPUs): ~7 GB per GPU
  - **Can train on commodity hardware**

## References

- [DeepSpeed ZeRO Paper](https://arxiv.org/abs/1910.02054)
- [DeepSpeed GitHub](https://github.com/microsoft/DeepSpeed)
- [ZeRO Offload Paper](https://arxiv.org/abs/2101.06840)

## Status

- ✅ **Compilation**: All components compile successfully
- ⏳ **Runtime**: Awaiting S runtime execution support
- ⏳ **Distributed Backend**: Stub implementation (needs NCCL/GLOO)
- ⏳ **Integration**: Ready to integrate with Phase 2A training

## Next Milestone

**M3: Distributed Training with ZeRO-1**

1. Connect to real distributed backend
2. Run ZeRO-1 on 2-8 GPUs
3. Verify memory savings
4. Measure communication overhead
5. Compare training speed vs baseline
