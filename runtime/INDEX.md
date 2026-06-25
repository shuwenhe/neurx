# runtime index

## Compatibility surface

- `runtime.s`
- `io.s`
- `control.s`
- `stage.s`
- `compile.s`

## New subdirectories

- `dispatch/`
- `io/`
- `control/`
- `stage/`
- `errors/`
- `logging/`

## Suggested migration order

1. `io.s` -> `runtime/io/io.s`
2. `control.s` -> `runtime/control/control.s`
3. `stage.s` -> `runtime/stage/stage.s`
4. `compile.s` -> `compile/runtime/runtime.s`
5. `runtime.s` -> `runtime/runtime/runtime.s`

Pipeline parallel now lives in `distributed/pp/pp.s`.
