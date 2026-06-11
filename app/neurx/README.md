# app/neurx

Application shell for deploying and running NeurX services.

This tree should stay thin. It is the UI, bridge, launch, and deployment layer on top of the framework.

## Keep Here

- `bin/`: startup scripts and CLI entry points
- `configs/`: example configuration files
- `bridge/`: thin bridge code to platform or UI
- `deploy/`: Docker, systemd, and k8s snippets
- `examples/`: app-level runnable examples
- `tests/`: smoke tests for app wiring
- `docs/`: usage and deployment docs
- `ci/`: app-level CI snippets
- `s/`: transitional S scaffolding only, while the canonical framework modules live elsewhere

## Do Not Put Here

- tensor, autograd, IR, or optimizer core logic
- compiler passes or lowering
- distributed runtime internals
- serving/cache/sampling primitives
- backend kernels

Those belong in the framework tree under `core/`, `compile/`, `runtime/`, `distributed/`, `serving/`, or `backends/`.

## Practical Rule

- If the code decides how the framework works, it does not belong here.
- If the code only connects NeurX to an app, UI, launcher, or deployment target, it belongs here.
