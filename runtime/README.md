# runtime layer

This directory holds runtime-facing orchestration and adapters for neurx.

## Current modules

- `runtime/runtime/runtime.s`: runtime availability and artifact discovery state
- `io/io.s`: text file, JSON, and environment helpers
- `control/control.s`: conditional execution, loop, and scan state
- `stage/stage.s`: staged execution state for jit, lower, compile, and execute
- `compile/compile.s`: compile-state bookkeeping used by the runtime pipeline

## Intended split

- `runtime/dispatch/`: backend and device dispatch
- `runtime/io/`: file, JSON, and environment adapters
- `control/control.s`: control-flow state and helpers
- `runtime/compile/`: compile-state bookkeeping and pipeline integration
- `runtime/stage/`: staged compilation and execution lifecycle
- `runtime/errors/`: error propagation and normalization
- `runtime/logging/`: runtime logging and diagnostics

## Migration rule

Keep the current files as compatibility shims until the new submodules are stable.
