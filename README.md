# neurx

neurx is a deep learning framework written in S.

## Layout

- `app/neurx/`: app shell, bridge code, and UI entry points
- `tensor/`: tensor primitives and helpers
- `ad/`: automatic differentiation
- `engine/`: backward execution and autograd state
- `data/`: datasets and dataloading
- `lf/`: loss functions
- `train/`: training utilities
- `runtime/`: runtime state, I/O adapters, stage state, and control-flow helpers
- `nn/`: neural network building blocks
- `opt/`: optimizers
- `compile/`: graph capture, IR, passes, lowering, executor, and cache
- `distributed/`: communication, DDP, TP, ZeRO, pipeline parallel, and launcher
- `infer/`: inference serving, decode, cache, and sampling
- `model/`: family-level model definitions and composition helpers
- `workflows/`: pretrain, posttrain, diffusion, robotics, and evaluation flows
- `arch/`: backend-specific support for CUDA, CANN, and MPS
- `examples/`: runnable examples and templates
- `doc/`: design notes, implementation reports, and gap analysis
- `s/`: legacy S entry scripts and prototypes
- `build/ir/`: generated S IR artifacts
- `build/logs/`: generated compiler and runtime logs

## Canonical Layering

The current top-level folders are kept for compatibility. The target layout is:

- `core/`: tensor, autograd, engine, nn, ops, losses, optim, data, train, runtime
- `compile/`: graph, IR, passes, lowering, executor, cache
- `runtime/`: device/runtime dispatch, I/O, logging, errors, and stage control
- `distributed/`: communication, DDP, TP, ZeRO, PP, and launcher
- `serving/`: inference serving, decode, cache, and sampling
- `workflows/`: pretrain, posttrain, diffusion, robotics, and evaluation
- `backends/`: CUDA, CANN, and MPS backend implementations
- `examples/`: runnable end-to-end examples
- `tests/`: regression and integration tests
- `legacy/`: historical S prototypes and compatibility shims

## Recommended Priority

1. Strengthen `compile/` so graph capture, lowering, caching, and execution are a real framework spine.
2. Expand `distributed/` so DDP, TP, ZeRO, and pipeline parallel share one consistent control plane.
3. Consolidate `serving/` so decode, sampling, and KV cache are first-class inference primitives.
4. Rehome compatibility shims into `legacy/` after the new layout stabilizes.

## S Modules

- `ad/ad.s`: automatic differentiation state, grad mode, record tracking, and backward skeleton
- `engine/backward.s`: backward engine entrypoint
- `engine/state.s`: autograd state helpers
- `tensor/tensor.s`: tensor structure, construction, views, elementwise ops, matmul
- `tensor/creation.s`: tensor creation and fill helpers
- `tensor/indexing.s`: indexing, concatenation, and splitting helpers
- `tensor/stats.s`: sorting and statistical helpers
- `tensor/linalg.s`: linear algebra helpers
- `tensor/einsum.s`: einsum entry point
- `ops.s`: operator entry points
- `autograd.s`: automatic differentiation prototype
- `schedule.s`: scheduling prototype
- `nn/nn.s`: linear layer and basic nn entry points
- `multimodal.s`: multimodal batch abstraction
- `trainer.s`: training config and step state
- `opt/optim_mvp.s`: minimal SGD and learning rate implementation
- `dataloader_mvp.s`: minimal dataloader for batch/sequence slicing
- `data/dataset.s`: dataset abstraction, slicing, splitting, and concatenation
- `data/dataloader.s`: data loading, batching, and dataloader state
- `lf/losses.s`: loss function entry point and core loss implementations
- `train/amp.s`: autocast and GradScaler state utilities
- `train/checkpoint_manager.s`: checkpoint retention and best-score tracking
- `train/logging.s`: training logging state and flush tracking
- `train/loop.s`: training loop and single-step training pipeline state machine
- `runtime/runtime/runtime.s`: runtime state and discovery helpers
- `runtime/io/io.s`: file, JSON, and environment adapters for the runtime layer
- `runtime/stage/stage.s`: staged compile state helpers for jit/lower/compile/execute
- `compile/runtime/runtime.s`: compile-state bookkeeping used by the runtime pipeline
- `runtime/control/control.s`: control-flow state helpers and simple cond/loop/scan primitives
- `distributed/comm/comm.s`: process-group and collective primitives
- `distributed/ddp/ddp.s`: DDP gradient bucket and synchronization state
- `distributed/tp/tp.s`: tensor-parallel shard mapping
- `distributed/tp_collective/tp_collective.s`: TP collective wrappers
- `distributed/pp/pp.s`: pipeline-parallel execution state
- `distributed/zero/zero.s`: ZeRO-style shard bookkeeping
- `distributed/pipelining/pipelining.s`: pipeline stage and schedule state
- `distributed/launcher/launcher.s`: distributed config detection and launcher helpers
- `model/README.md`: model-family layout and placement rules
- `model/core/README.md`: shared model building blocks
- `model/vision/README.md`: vision families
- `model/llm/README.md`: language model families
- `model/diffusion/README.md`: diffusion families
- `model/multimodal/README.md`: multimodal compositions
- `model/audio/README.md`: audio and speech families
- `model/video/README.md`: video families
- `model/reward/README.md`: reward and preference families

## Notes

The S modules are compiled into runtime IR during the `s-compile-runtime` step and written under `build/ir/`.

## Hardware Backends

- `arch/cuda/`: CUDA/NVIDIA GPU support
- `arch/cann/`: Ascend NPU support
- `arch/mps/`: Apple M1/M2 GPU support
