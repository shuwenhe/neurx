# compile layer

This directory holds the graph-to-execution spine of neurx.

## Current modules

- `compiler.s`: compile options, validation, and module compile entry points
- `pipeline.s`: capture, optimize, lower, cache, and execute pipeline state
- `ir.s`: IR graph and node representation
- `pass_manager.s`: pass registration and pass application
- `lowering.s`: lowering plan and lowering state transitions
- `executor.s`: execution plan and execution state transitions
- `cache.s`: compile cache state and cache key helpers
- `runtime.s`: compile-time runtime state integration

## Intended split

- `compile/ir/`: graph, nodes, edges, and capture helpers
- `compile/passes/`: optimization and rewrite passes
- `compile/lowering/`: backend lowering and legalization
- `compile/executor/`: runtime execution handoff
- `compile/cache/`: compilation cache and artifact lookup

## Migration rule

Keep the existing files as the compatibility surface until the new submodules are wired in.

