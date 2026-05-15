# neurx Framework Reorganization Plan (2026-05-15)

## Goal

Use a benchmark-driven architecture plan, aligned with the strengths of PyTorch, JAX, TensorFlow, TVM, and DeepSpeed, while keeping new core logic S-language first.

Primary outcomes:

1. High-throughput serving runtime (vLLM/SGLang-style capabilities).
2. Scalable distributed training runtime (TP plus ZeRO-style optimizer sharding).
3. Compiler and runtime optimization pipeline (JAX/TVM-style graph and lowering flow).

## Priority Stack (ROI Order)

1. Serving Runtime (highest ROI now)
2. Distributed Runtime (training scale)
3. Compile Optimization (long-term peak performance)

Rationale:

1. Serving throughput and latency directly dominate production cost.
2. TP and ZeRO determine whether larger models can train efficiently.
3. Compiler passes deliver compounding gains once runtime/data path are stable.

## S-Language Modules To Build First

### P0: Serving Runtime

1. infer/serve/continuous_batch.s (already scaffolded)
2. infer/cache/paged_kv_cache.s (already scaffolded)
3. infer/cache/prefix_cache.s (next)
4. infer/decode/speculative_decode.s (next)
5. infer/serve/admission_control.s (next)

### P1: Distributed Runtime

1. distributed/tp.s (tensor parallel state and shard mapping)
2. distributed/tp_collective.s (TP all-reduce/all-gather contract)
3. distributed/zero.s (optimizer/grad shard state)
4. train/parallel/train_parallel.s (compose DP, PP, TP)

### P2: Compiler and Lowering

1. compile/pass_fusion.s
2. compile/pass_const_fold.s
3. compile/pass_memory_plan.s
4. compile/lowering_cuda.s
5. compile/lowering_cann.s
6. compile/lowering_mps.s

## Target Directory Layout

```text
neurx/
  core/
    ad/
    tensor/
    nn/
    ops/
    engine/

  compile/
    ir.s
    pass_manager.s
    pass_fusion.s
    pass_const_fold.s
    pass_memory_plan.s
    lowering.s
    lowering_cuda.s
    lowering_cann.s
    lowering_mps.s
    executor.s
    cache.s
    pipeline.s
    compiler.s

  runtime/
    runtime.s
    runtime.py
    io.s
    control.s
    stage.s
    pp.s

  distributed/
    comm.s
    launcher.s
    pipelining.s
    tp.s
    tp_collective.s
    zero.s

  training/
    train/
    pretrain/
    posttrain/
    diffusion/

  serving/
    infer/
      decode/
      cache/
      sampling/
      serve/
      eval/

  platform/
  arch/
  python/
  test/
  doc/
  script/
```

## Compatibility Strategy

Do not break current imports while migrating:

1. Keep current top-level folders as compatibility entry points.
2. Add forwarding wrappers from old paths to new layered paths.
3. Remove old paths only after two stable release cycles.

## Phase Plan

### Phase 1 (Week 1-2): Serving path hardening

1. Complete continuous batching lifecycle (enqueue, prefill, decode, finish).
2. Add prefix cache state and hit/miss accounting.
3. Add decode scheduler policies (FCFS and shortest-remaining).
4. Add runtime tests for multi-request progress fairness.

Exit criteria:

1. infer pipeline handles multiple concurrent requests.
2. paged kv and prefix cache counters are test-covered.

### Phase 2 (Week 3-4): TP and ZeRO MVP

1. Implement tensor shard metadata and shard/merge helpers.
2. Add TP collective calls over existing distributed collectives.
3. Implement ZeRO state partition for optimizer states.
4. Wire train loop with configurable parallel strategy.

Exit criteria:

1. Single-node multi-rank TP simulation passes.
2. optimizer state memory footprint drops in sharded mode.

### Phase 3 (Week 5-6): Compiler pass upgrades

1. Add constant folding and dead-op elimination.
2. Add fusion pass for linear plus activation, norm plus affine patterns.
3. Add backend-aware lowering stubs for cuda/cann/mps.
4. Add pass timing and cache hit telemetry.

Exit criteria:

1. Pass pipeline is deterministic and tested.
2. compile cache key stability is verified across runs.

## Test Matrix To Add

1. test/test_s_infer_scheduler_runtime.py
2. test/test_s_infer_prefix_cache_runtime.py
3. test/test_s_distributed_tp_runtime.py
4. test/test_s_distributed_zero_runtime.py
5. test/test_s_compile_pass_runtime.py

## Immediate Next Tasks (Do Now)

1. Add infer/cache/prefix_cache.s with state and accounting helpers.
2. Add infer/serve/admission_control.s and integrate into infer/infer.s.
3. Add distributed/tp.s skeleton and runtime function exposure checks.
4. Add one end-to-end infer runtime test with two concurrent requests.
