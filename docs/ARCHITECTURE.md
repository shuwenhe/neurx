# NeurX Repository Architecture

NeurX is organized by product domain. New top-level source directories should
not be added when an existing domain can own the code.

## Target layout

```text
neurx/
|-- cmd/                       Executable entry points
|-- src/
|   |-- core/                  Tensor, autograd, operators, and contracts
|   |-- compiler/              IR, passes, lowering, and execution plans
|   |-- runtime/               Execution, scheduling, and worker management
|   |-- distributed/           Shared collectives and distributed control plane
|   |-- inference/             Engines, sampling, tokenization, and cache
|   |-- training/              Pretraining, post-training, and alignment
|   |-- models/                Model families and adapters
|   |-- serving/               APIs, protocols, routing, and streaming
|   |-- agent/                 Agents, tools, and retrieval
|   `-- observability/         Logging, metrics, tracing, and profiling
|-- backends/                  CPU, CUDA, CANN, MPS, and native backends
|-- apps/                      User-facing applications
|-- configs/                   Runtime and training configuration
|-- tests/                     Unit, integration, fixtures, and golden tests
|-- benchmarks/                Reproducible training and inference comparisons
|-- build/                     Modular build definitions
|-- examples/                  Focused usage examples
|-- tools/                     Developer tools
|-- scripts/                   Build and operational scripts
|-- deploy/                    Docker, Kubernetes, systemd, and installers
|-- docs/                      Architecture and user documentation
|-- experimental/              Unstable implementations
`-- artifacts/                 Generated output; never source code
```

The stable subdomain boundaries are now enforced by `scripts/check_layout.sh`.
Compiler code is split into `frontend`, `ir`, `passes`, `lowering`, and
`codegen`; models expose `registry`, `loaders`, `formats`, and `families`;
backends implement the contracts in `backends/api/`.

Physical source paths follow this layout. Existing `neurx.*` package names are
temporarily retained as compatibility APIs and will migrate domain by domain.

## Ownership rules

- `src/inference/` owns request-to-token inference behavior.
- `src/serving/` owns network transport and public protocols; it calls inference
  instead of implementing model execution.
- `src/runtime/` owns reusable execution primitives and does not depend on serving.
- `src/training/pretrain/` and `src/training/posttrain/` remain separate flows while sharing training
  primitives.
- Hardware-specific code belongs to a backend, not a model or serving layer.
- Generated binaries, logs, checkpoints, and reports belong under `artifacts/`.

## Naming rules

- Use one canonical implementation name. Do not add production modules with
  `_final`, `_complete`, `_fixed`, or `_enhanced` lifecycle suffixes.
- Put prototypes in `experimental/`; compare implementations in tests or
  benchmarks instead of encoding lifecycle state in filenames.
- Version names are reserved for real public protocol or algorithm versions,
  such as `src/serving/api/v1` or `flash_attention_v3`.
- Tests belong under `tests/` in the target layout and mirror source domains.

## Migration order

1. Consolidate unambiguous duplicate directories.
2. Split the root Makefile into files under `build/mk/` without changing targets.
3. Consolidate observability and serving modules.
4. Move core, runtime, and inference code after dependency checks are automated.
5. Remove compatibility paths only after all integration gates pass.

Run `make check-layout` before committing structural changes.
Run `make check-architecture` before merging. It also rejects new reverse-domain
dependencies and lifecycle-suffixed implementation names.

Target directories may initially contain ownership contracts while legacy
implementations remain at compatibility paths. A domain is considered migrated
only after its stable command calls the new API, tests pass, and the old path is
removed.

Stable command modules are linked with the S seed compiler's `--link-ir` stage
and emitted as standalone launchers under `artifacts/bin/`. Run
`make test-commands` to compile, link, emit, and verify their exit contracts.

Build targets are split by concern under `build/mk/`; the root Makefile remains the
stable entry point.

## Completed migrations

- `optim/` was consolidated into `src/training/optimizer/`.
- `platforms/` was consolidated into `backends/platform/`.
- `logging/`, `monitoring/`, `profiler/`, and `tracing/` were consolidated into
  `src/observability/`.
- The legacy `compilation/` prototype was isolated under
  `experimental/compiler/`; production compilation remains under `src/compiler/`.
- `workers/` was consolidated into `src/runtime/worker/`.
- Inference KV and request queues were consolidated under `src/inference/cache/`
  and `src/inference/scheduler/`.
- Decode, sampling, and KV state were removed from `src/serving/`; serving now
  owns transport and service governance only.
- Inference metrics and profiling moved under `src/observability/`.
- Inference-specific distributed coordination moved under
  `src/distributed/inference/`.
- MPS is now a first-class backend, while OS-kernel prototypes live under
  `experimental/os/`.
