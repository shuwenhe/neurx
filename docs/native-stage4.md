# Build NeurX with the self-hosted S compiler

```sh
cd /root/shuwen/neurx
make native-stage4
make native-stage4-test
```

All five command entry points (`train`, `benchmark`, `worker`, `controller`,
`serve`) build as native Linux/amd64 ELF executables in
`artifact/build/native-stage4/`. No seed IR interpreter or legacy backend is used
to compile or execute these commands.

The local default selects the extended self-hosted compiler at
`../s/.bootstrap/neurx-extension/compiler-final` when present, otherwise the
standard `../s/.bootstrap/native-imports/stage4`. The original accepted Stage4
predates the floating-point/runtime additions and is preserved. On another
checkout, first bootstrap the updated S sources or explicitly select an extended
native compiler:

```sh
make native-stage4 S_REPO_ROOT=/path/to/s \
  S_NATIVE_COMPILER=/path/to/extended/native/compiler
make native-stage4 NATIVE_COMMANDS="worker serve"
```

The S extension development directory contains immutable compiler source
snapshots, source hashes, native assembly and build logs. Its native compiler
chain starts with the previously verified Stage4, which compiles the extension;
that native compiler then compiles the updated compiler sources. The final
artifact has been tested as a compiler, separately from seed-hosted development
builds. This development chain is distinct from rerunning the repository's full
fresh four-stage clean-room acceptance/install workflow.

The NeurX build tool records compiler path/SHA-256 in `manifest.json`, source
closures in `*.sources`, and compiler/emitter diagnostics in `*.log`. It resolves
packages and declared historical member imports from source; missing imports
fail explicitly. Each requested command is independent, and a failed rebuild
removes its old executable/assembly before preflight. All requested commands must
succeed for the overall build to return zero.

## Validated behavior

- Train configuration checks and launching a controlled Make target.
- Benchmark configuration, measured-result validation and child exit propagation.
- Shell argument quoting, including single quotes and shell metacharacters.
- Worker configuration and execution of a local child with rank/master variables.
- Cluster collection builders preserve counts and exclude default/empty entries.
- Runtime file/binary/range operations, empty/missing environment keys, process
  stdout capture and error handling; socket extensions have local loopback probes.
- Native serving for a reference model, a tiny safetensors embedding model, and a
  tiny HF model; KV caches propagate across forward/prefill/decode steps and HF
  numeric configuration accepts scientific notation.

`train` remains a launcher of the existing Make training workflow, and
`benchmark` launches an external measurement executable. Compiling them does not
compile the complete training engine or establish performance measurements.
The controller has been exercised in local dry-run mode; remote multi-node
launch, GPU/NPU training and production deployment are not validated here.
The existing unrelated `quality-gate` still references missing scripts and old
paths; it is not bypassed or claimed to pass.

The RL/PPO/GRPO files outside these command closures also remain unvalidated as a
real training pipeline. Some rollout/reward paths are explicitly placeholders,
and compiling these five commands does not establish RL infrastructure readiness.
