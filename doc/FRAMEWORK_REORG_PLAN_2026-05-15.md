# neurx Framework Reorganization Plan (2026-05-15)

## Goal

Unify neurx around a framework-first architecture:

1. Compiler-first execution pipeline (IR -> Pass -> Lowering -> Executor -> Cache)
2. Clear layer boundaries between core kernels and orchestration flows
3. Separate training and inference orchestration from runtime/kernel internals

## Priority Module

The highest ROI module is the compile pipeline.

Implemented S modules:

- compile/ir.s
- compile/pass_manager.s
- compile/lowering.s
- compile/executor.s
- compile/cache.s
- compile/pipeline.s

Compiler entry integration:

- compile/compiler.s now composes and runs the compile pipeline.

## Target Directory Layout

```text
neurx/
  ad/
  tensor/
  engine/
  nn/
  ops/

  compile/
    ir.s
    pass_manager.s
    lowering.s
    executor.s
    cache.s
    pipeline.s
    compiler.s
    runtime.s

  runtime/
    io.s
    control.s
    stage.s
    runtime.s
    runtime.py

  train/
  pretrain/
  posttrain/
  infer/

  distributed/
  platform/

  python/
  test/
  doc/
  script/
```

## Boundary Rules

1. Core kernels remain in ad/tensor/engine/nn/ops.
2. compile owns graph-level transformation and executable generation state.
3. runtime owns environment, IO, control-flow, and backend adapters.
4. pretrain/posttrain/infer own orchestration state machines only.
5. python is compatibility and tooling glue, not the new core logic host.

## Migration Steps

### Phase 1: Compiler consolidation

1. Keep compile/compiler.s as single framework compile entry.
2. Move graph transform logic into compile/pass_manager.s.
3. Keep runtime/compile.s as compatibility state adapter during transition.

### Phase 2: Runtime cleanup

1. Keep only runtime environment and backend adapter functions in runtime/.
2. Remove compile-overlap helpers from runtime when no callers remain.

### Phase 3: Orchestration alignment

1. pretrain and posttrain call unified compile pipeline before execute.
2. infer decode path consumes compiled artifacts and cache keys.

### Phase 4: Docs and tests

1. Add compile pipeline tests for pass order, cache key behavior, and execution transitions.
2. Add architecture map index in doc/README.

## Immediate Next Tasks

1. Add adapter functions from pretrain/posttrain/infer to compile/run pipeline.
2. Add compile pipeline smoke tests in test/.
3. Add backend target mapping for cuda/cann/mps in compile/lowering.s.
