# Distributed Training Acceleration Plan

This note summarizes the current NeurX distributed training path.

## Current framework layers

- `distributed/comm/comm.s`: process group and collective primitives
- `distributed/tp/tp.s`: tensor-parallel shard mapping
- `distributed/tp_collective/tp_collective.s`: TP collectives on top of process groups
- `distributed/ddp/ddp.s`: gradient bucket and sync bookkeeping
- `distributed/zero/zero.s`: ZeRO-style optimizer and gradient sharding bookkeeping
- `train/parallel.s`: composition layer that wires DDP, TP, and ZeRO together

## What acceleration means here

The framework should reduce training cost by combining:

1. Communication reduction
   - shard gradients and optimizer state
   - use reduce-scatter and all-gather where appropriate

2. Memory reduction
   - keep only local optimizer shards
   - avoid replicating all parameters on every rank

3. Compute overlap
   - overlap communication with backward computation
   - keep TP and DDP state separate so each can be improved independently

## Recommended execution order

1. Keep the existing single-process path working
2. Use `train.parallel` to enable TP/ZeRO bookkeeping
3. Add runtime tests for:
   - rank/world-size normalization
   - gradient sync counters
   - shard registration and reset
4. Later replace the mocked collectives with real backend bindings

## Near-term implementation targets

- ZeRO-1/2 style optimizer sharding
- gradient bucket tracking
- reduce-scatter for sharded gradients
- all-gather for parameter reconstruction
- overlap-friendly training loop hooks
