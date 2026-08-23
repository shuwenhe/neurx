# NeurX Repository Architecture

NeurX is organized by product domain. New top-level source directories should
not be added when an existing domain can own the code.

## Target layout

```text
neurx/
|-- cmd/                 Executable entry points
|-- src/
|   |-- core/            Tensor, autograd, operators, and contracts
|   |-- runtime/         Execution, scheduling, and memory management
|   |-- inference/       Engines, sampling, tokenization, and inference cache
|   |-- training/        Pretraining, post-training, and alignment
|   |-- models/          Model families and adapters
|   |-- serving/         APIs, protocols, routing, and streaming
|   |-- agent/           Agents, tools, and workflows
|   |-- observability/   Logging, metrics, tracing, and profiling
|   `-- backends/        CPU, CUDA, CANN, and MPS implementations
|-- apps/                User-facing applications
|-- configs/             Runtime and training configuration
|-- tests/               Unit, integration, fixture, and golden tests
|-- examples/            Focused usage examples
|-- tools/               Developer tools
|-- scripts/             Build and operational scripts
|-- deploy/              Docker, Kubernetes, and systemd assets
|-- docs/                Architecture and user documentation
|-- experimental/        Unstable implementations
`-- artifacts/           Generated output; never source code
```

The repository is being migrated incrementally to this layout. Moving one
domain at a time keeps imports, build targets, and deployment paths reviewable.

## Ownership rules

- `inference/` owns request-to-token inference behavior.
- `serving/` owns network transport and public protocols; it calls inference
  instead of implementing model execution.
- `runtime/` owns reusable execution primitives and does not depend on serving.
- `pretrain/` and `posttrain/` remain separate flows while sharing training
  primitives.
- Hardware-specific code belongs to a backend, not a model or serving layer.
- Generated binaries, logs, checkpoints, and reports belong under `artifacts/`.

## Naming rules

- Use one canonical implementation name. Do not add production modules with
  `_final`, `_complete`, `_fixed`, or `_enhanced` lifecycle suffixes.
- Put prototypes in `experimental/`; compare implementations in tests or
  benchmarks instead of encoding lifecycle state in filenames.
- Version names are reserved for real public protocol or algorithm versions,
  such as `api/v1` or `flash_attention_v3`.
- Tests belong under `tests/` in the target layout and mirror source domains.

## Migration order

1. Consolidate unambiguous duplicate directories.
2. Split the root Makefile into files under `mk/` without changing targets.
3. Consolidate observability and serving modules.
4. Move core, runtime, and inference code after dependency checks are automated.
5. Remove compatibility paths only after all integration gates pass.

Run `make check-layout` before committing structural changes.

Build targets are split by concern under `mk/`; the root Makefile remains the
stable entry point.

## Completed migrations

- `optim/` was consolidated into `optimizer/`.
- `platforms/` was consolidated into `platform/`.
- `logging/`, `monitoring/`, `profiler/`, and `tracing/` were consolidated into
  `observability/`.
- `workers/` was consolidated into `worker/`.
