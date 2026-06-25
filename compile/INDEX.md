# compile index

## Compatibility surface

- `compiler.s`
- `pipeline.s`
- `ir/ir.s`
- `passes/pass_manager.s`
- `lowering/lowering.s`
- `executor/executor.s`
- `cache/cache.s`
- `runtime/runtime.s`

## Suggested ownership

1. `compiler.s` and `pipeline.s` for the public framework spine
2. `compile/ir/` for graph capture and node bookkeeping
3. `compile/passes/` for optimization and rewrite passes
4. `compile/lowering/` for backend legalization
5. `compile/executor/` for runtime handoff
6. `compile/cache/` for compilation cache state
7. `compile/runtime/` for compile-time runtime helpers
