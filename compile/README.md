# compile layer

This directory holds the graph-to-execution spine of neurx.

## Current modules

- `compiler.s`: compile options, validation, and module compile entry points
- `pipeline.s`: capture, optimize, lower, cache, and execute pipeline state
- `ir/ir.s`: IR graph and node representation
- `passes/pass_manager.s`: pass registration and pass application
- `lowering/lowering.s`: lowering plan and lowering state transitions
- `executor/executor.s`: execution plan and execution state transitions
- `cache/cache.s`: compile cache state and cache key helpers
- `runtime/runtime.s`: compile-time runtime state integration

## Layout

- `compile/` keeps the public compile facade
- `compile/ir/` owns graph and node shape state
- `compile/passes/` owns pass planning and application
- `compile/lowering/` owns lowering and legalization state
- `compile/executor/` owns execution handoff
- `compile/cache/` owns compilation cache helpers
- `compile/runtime/` owns compile-time runtime helpers

## Migration rule

Keep `compiler.s` and `pipeline.s` as the compatibility surface while the submodules carry the implementation.
