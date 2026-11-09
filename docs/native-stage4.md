# Build NeurX with the self-hosted S compiler

Use the accepted Stage4 binary from the adjacent S checkout:

```sh
make native-stage4 NATIVE_COMMANDS="train benchmark"
make native-stage4-test
```

The commands are written to `artifact/build/native-stage4/train` and
`artifact/build/native-stage4/benchmark`. These are native Linux/amd64 executables.
`train` validates configuration and launches the existing Make training workflow;
compiling this launcher does not compile or validate the training engine.
`benchmark` launches an external measurement executable and validates its result;
it does not implement an inference engine or establish performance claims.

To select another accepted compiler:

```sh
make native-stage4 NATIVE_COMMANDS="train benchmark" \
  S_REPO_ROOT=/path/to/s \
  S_NATIVE_COMPILER=/path/to/s/.bootstrap/native-imports/stage4
```

No seed compiler, seed IR runner or legacy backend is used. The build tool records
the selected compiler path and SHA-256 in `manifest.json`, source closures in
`*.sources`, and compiler/emitter output in `*.log`. It resolves NeurX package
names from source declarations, including historical terminal-dot/member imports.
It does not rewrite or discard imported source. Unresolved imports fail explicitly.
Each requested command is built independently. Failed rebuilds remove that
command's previous binary and assembly so they cannot be mistaken for new output.

`make native-stage4` attempts all five commands and returns nonzero if any fails.
Currently `worker`, `controller` and `serve` remain blocked:

- `worker`/`controller` depend on `std` imports without a resolvable source package.
- Their source closures use prefix array types such as `[]cluster_node_spec`;
  the current canonical parser expects suffix arrays such as `cluster_node_spec[]`.
- `serve` fails on `[]int` in `src/inference/executor/native_executor.s`.
- Beyond syntax, cluster utilization and model weights require floating point.
  Stage4 rejects a minimal `float weight = 1.5` program, and its SSA supported-type
  set omits floating point. Replacing these with integers would change behavior.
- The cluster code declares socket intrinsics such as `__sys_socket`; a minimal
  Stage4 program calling that intrinsic fails with `unresolved external function`.

The current native regression tests execute the real train and benchmark binaries,
including configuration errors, child failure status and shell quoting. Training,
GPU/NPU execution, distributed orchestration and full model serving have not been
validated. The existing unrelated `quality-gate` still references missing scripts
and old repository paths; it is not bypassed or claimed to pass by these targets.
