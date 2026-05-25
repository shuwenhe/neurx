# neurx
NeurX is AI operating system written in S.

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
- `workflows/`: task orchestration trees for `llm/`, `vision/`, `diffusion/`, `multimodal/`, `agent/`, `benchmark/`, and `dataset/`
- `arch/`: backend-specific support for CUDA, CANN, and MPS
- `examples/`: runnable examples and templates
- `doc/`: design notes, implementation reports, and gap analysis
- `s/`: legacy S entry scripts and prototypes
- `build/ir/`: generated S IR artifacts
- `build/logs/`: generated compiler and runtime logs

## AI OS Skeleton

To evolve NeurX into an AI operating system, the repository should keep a system-oriented top layer:

- `kernel/`: task loop, lifecycle, quotas, and module orchestration
- `memory/`: short-term memory, long-term memory, retrieval state, and checkpoints
- `planner/`: goal decomposition, task queues, budgeting, and replanning
- `reflection/`: self-critique, correction suggestions, and post-step review
- `context/`: context assembly, token budgeting, and compression
- `reasoning/`: route selection, verification, and decision policies
- `perception/`: repository, file, UI, and multimodal input understanding
- `executor/`: action execution, tool dispatch, and observation capture
- `scheduler/`: multi-task, multi-agent, and background job scheduling
- `tool/`: tool interfaces, adapters, and execution contracts
- `skills/`: skill packaging, evaluation, and composition
- `registry/`: shared registries for tools, skills, agents, and workflows
- `session/`: user sessions, resumability, and conversation/task state
- `safety/`: risk checks, approval gates, and policy enforcement
- `security/`: sandboxing, auth, secrets, and capability control
- `storage/`: artifacts, state stores, indexes, and durable persistence
- `observability/`: traces, metrics, logs, and replay/debug snapshots
- `services/`: background model, indexing, and orchestration services
- `api/`: HTTP, RPC, CLI, and external integration surfaces
- `shell/`: interactive system shell and command entrypoints
- `ui/`: desktop, mobile, and web system interfaces
- `sdk/`: developer-facing integration and extension APIs

## Canonical Layering

The current top-level folders are kept for compatibility. The target layout is:

- `core/`: tensor, autograd, engine, nn, ops, losses, optim, data, train, runtime
- `compile/`: graph, IR, passes, lowering, executor, cache
- `runtime/`: device/runtime dispatch, I/O, logging, errors, and stage control
- `distributed/`: communication, DDP, TP, ZeRO, PP, and launcher
- `serving/`: inference serving, decode, cache, and sampling
- `workflows/`: orchestration layer for active multi-stage pipelines
- `backends/`: CUDA, CANN, and MPS backend implementations
- `examples/`: runnable end-to-end examples
- `tests/`: regression and integration tests
- `legacy/`: historical S prototypes and compatibility shims

## Recommended Priority

1. Strengthen `compile/` so graph capture, lowering, caching, and execution are a real framework spine.
2. Expand `distributed/` so DDP, TP, ZeRO, and pipeline parallel share one consistent control plane.
3. Consolidate `serving/` so decode, sampling, and KV cache are first-class inference primitives.
4. Rehome compatibility shims into `legacy/` after the new layout stabilizes.

## Workflows Boundary

- `workflows/` is the orchestration layer for active multi-stage pipelines.
- LLM, vision, diffusion, multimodal, agent, benchmark, and dataset workflows live here.
- Agent skills evolution belongs under `workflows/agent/skills/`.
- Model definitions still belong in `model/`.
- Shared reusable training helpers still belong in `train/`, `pretrain/`, and `posttrain/`.
- Keep workflow code focused on config, pipeline, launch, and dataset wiring.

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

## Notes

The S modules are compiled into runtime IR during the `s-compile-runtime` step and written under `build/ir/`.

For the current NeurX agent capability boundary and the roadmap toward a GPT/Codex-style coding agent, see [doc/AGENT_CAPABILITY_GAP.md](doc/AGENT_CAPABILITY_GAP.md).

## Hardware Backends

- `arch/cuda/`: CUDA/NVIDIA GPU support
- `arch/cann/`: Ascend NPU support
- `arch/mps/`: Apple M1/M2 GPU support
