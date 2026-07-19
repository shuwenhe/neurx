# neurx directory reorganization plan

## Goal

Keep the current tree working, but converge on a framework-first layout that separates:

- core tensor and training primitives
- compilation and lowering
- runtime dispatch and control
- distributed training
- serving / inference
- backend implementations
- examples and workflows
- legacy compatibility code

## Target layout

```text
neurx/
  core/
    tensor/
    ad/
    engine/
    nn/
    ops/
    data/
    losses/
    optim/
    train/
    runtime/
  compile/
    ir/
    passes/
    lowering/
    executor/
    cache/
  runtime/
    dispatch/
    io/
    control/
    stage/
    errors/
    logging/
  distributed/
    comm/
    ddp/
    tp/
    zero/
    pipelining/
    launcher/
  serving/
    infer/
    sampling/
    cache/
    decode/
  workflows/
    pretrain/
    posttrain/
    diffusion/
    robotics/
  backends/
    cuda/
    cann/
    mps/
  examples/
  tests/
  doc/
  legacy/
```

## Current to target mapping

| Current path | Target path | Notes |
|---|---|---|
| `tensor/` | `core/tensor/` | Tensor primitives and helpers |
| `ad/` | `core/ad/` | Autograd state and tracing |
| `engine/` | `core/engine/` | Backward execution |
| `nn/` | `core/nn/` | Neural network modules |
| `data/` | `core/data/` | Dataset and dataloader |
| `loss/` | `core/losses/` | Loss functions |
| `optimizer/` | `core/optim/` | Optimizers and schedulers |
| `train/` | `core/train/` | AMP, logging, checkpointing, loops |
| `runtime/` | `runtime/` | Keep runtime orchestration here |
| `compile/` | `compile/` | Keep compilation spine here |
| `distributed/` | `distributed/` | Keep communication and parallelism here |
| `infer/` | `serving/` | Decode, cache, sampling, request handling |
| `workflows/` | `workflows/` | Pretrain, posttrain, robotics, diffusion |
| `arch/` | `backends/` | CUDA, CANN, MPS implementations |
| `example/` | `examples/` | End-to-end runnable examples |
| `app/neurx/` | `examples/app/neurx/` or `apps/neurx/` | UI / bridge application code |
| `s/` | `legacy/s/` | Old S prototypes and compatibility shims |
| `scripts/legacy/` and `scripts/` | `tools/` or `devtools/` | Developer utilities and automation |

## Priority order

1. `compile/`
2. `distributed/`
3. `serving/`
4. `runtime/`
5. `legacy/` cleanup

## Migration rules

- Do not move files until import paths are mapped and compatibility shims are available.
- Keep the old top-level directories as thin wrappers during transition.
- Prefer one canonical implementation per concept.
- Keep backend-specific code out of core training logic.
- Put prototypes and experiments under `legacy/` or `doc/` unless they are production paths.

## Practical reading order

- `README.md` for high-level structure
- `doc/PYTORCH_GAP_ANALYSIS_2026.md` for framework gaps
- `doc/DIR_REORG_PLAN.md` for reorganization mapping
- `compile/compiler.s` and `compile/pipeline.s` for the framework spine

