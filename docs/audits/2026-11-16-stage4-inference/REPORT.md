# Stage4 inference migration audit — BLOCKED

Date: 2026-11-16 (Asia/Shanghai).
NeurX revision: `5a258ed2b87ad565e22fe23cf09e810f1851a879`.
External S source revision inspected read-only: `0f8f661dd84301d6bd277fbc94460831317e0c45`.

## Decision before implementation

Do not change compiler recipes yet. The required installed compiler is absent,
and the checked-out self-hosted compiler source does not implement the legacy
IR linking operation needed by this pipeline. This follows the request to stop
and document an unsupported operation rather than introduce a workaround.
These are source observations, not execution results from an accepted Stage4
binary. No compiler was rebuilt, replaced, or substituted.

## Original actual dependency graph

```text
make inference
  -> recursive make chat-gpu
     -> build-s-ir-runner: host CC builds tool/s_ir_runner.c with S C runtime
     -> build-s-gpu-cuda-runtime: nvcc + C++ build libneurx_s_cuda.so
     -> gpu_backend_enhanced.ir
        -> copy backend/platform/cuda/inference_server.s to /tmp
        -> s_seed source -> gpu_backend_enhanced_entry.ir
        -> s_seed src/model/formats/hf_config.s -> hf_config.ir
        -> s_seed --link-ir -> gpu_backend_enhanced.ir
     -> s_seed src/inference/llm/chat/chat_client.s -> chat_client.ir
     -> s_seed src/inference/runtime/wait_backend_ready.s -> wait_backend_ready.ir
     -> chat-gpu-run
        -> IR runner + LD_PRELOAD CUDA library: backend
        -> IR runner: readiness helper
        -> IR runner: chat client
```

The forced dry run records all five compiler invocations, including the link.
The normal dry run records what Make currently considers stale. Neither is an
actual compilation or inference run. Existing IR files cannot establish compiler
identity, and timestamp reuse would not establish a successful migration.

## Invocation classification

| Class | Invocation / implementation | In actual `inference` graph? |
|---|---|---|
| GPU backend compilation | `makefile:1089`, `S_SEED_COMPILER` on copied inference server | Yes |
| Model configuration | `makefile:1090`, `S_SEED_COMPILER` on `hf_config.s` | Yes |
| IR linking | `makefile:1091`, `S_SEED_COMPILER --link-ir` | Yes |
| Production control plane | `makefile:1165`, `S_SEED_COMPILER` on `chat_client.s` | Yes |
| Readiness helper | `makefile:1189`, `S_SEED_COMPILER` on `wait_backend_ready.s` | Yes |
| Model/tokenizer execution | C++ HF model, safetensors and BPE sources linked into CUDA shared library | Yes, host C++/CUDA compilation |
| Separate S model/tokenizer compilation | `transformer_real_inference.s`, `qwen_tokenizer.s` recipes, lines 1102–1124 | No |
| Broader production artifacts | CPU backend, basic GPU backend, production chat variants, streaming client, web UI and start helpers, lines 1056–1234 | Via `build-production-s-inference`, not default `inference` |
| Import closure compilation | `tool/build_legacy_ir.py --compiler S_SEED_COMPILER --compile-unit` for direct chat | Broader production target only |
| Test/diagnostic compilation | Device ABI, evaluation and other Seed recipes | No; leave separate |
| Native command compilation | `native-stage4` -> `tool/build_native.py`, `--compile-unit` and `--emit-bin` | No; not proof about `make inference` |
| Runtime execution | `chat-gpu-run`, runner `runtime_execute_file` | Yes; no compiler process launched by runner main |

`build/mk/inference.mk`, `backends.mk`, and `compiler.mk` contain aliases or layout
checks; they do not override these compilation recipes. Default inference invokes
no external shell script: its launch logic is inline in the Makefile. The separate
`start-inference` names a missing `scripts/start_inference.sh`. Remote inference
uses `scripts/deploy_two_node_inference.sh` to sync and launch remote processes;
it is outside the local graph and was not executed.

The runner is built with C Seed implementation files under `SEED_COMPILE_ONLY`.
That is an existing runtime dependency, distinct from invoking the `s_seed`
compiler executable. Retaining it alone would not satisfy IR format compatibility.

## Blocking evidence

1. `S_REPO_ROOT` defaults here to `/home/shuwen/shuwen/s`.
   Neither `bin/s_compiler` nor `.bootstrap/native-imports/stage4` exists there;
   `.bootstrap` itself is absent. Therefore accepted compiler version/hash and
   actual operation probes are unavailable. The other inspected S checkout at
   `/home/shuwen/s/bin` also has no `s_compiler`. The installed `s` executable
   has not been identified as the accepted Stage4 compiler and was not substituted.
2. The existing `S_NATIVE_COMPILER` default at `makefile:174` selects an extension
   compiler or bootstrap artifact, not the requested `bin/s_compiler`. Changing
   that variable alone would not migrate the five Seed invocations above.
3. External source `src/cmd/compile/internal/compiler/main.s:302` implements
   `--compile-unit` by writing `# S-NATIVE-AMD64-V1` native assembly (line 340).
   `--emit-bin` explicitly requires that format. The two-positional-argument
   mode emits canonical MIR, not a demonstrated legacy target artifact.
   The command dispatcher has no `--link-ir` handler.
4. Existing GPU backend IR starts with `SSEED-TARGET-V1`. The runner calls
   `runtime_execute_file`; its runtime parser rejects other headers at
   `src/cmd/compile/seed/runtime/runtime.c:3634`. Native assembly cannot be
   substituted for this IR merely by retaining an `.ir` suffix.
5. `nvidia-smi -L` exits 9 because it cannot communicate with the NVIDIA driver.
   `nvcc` exists at `/usr/bin/nvcc`; compiler availability does not prove GPU
   execution. The Qwen model directory exists, but weights were not loaded.

## Proposed graph, not implemented or accepted

```text
make inference -> verified bin/s_compiler
  -> compile each existing module to runner-compatible artifacts
  -> supported linking preserving existing interfaces
  -> unchanged IR runner + CUDA runtime -> Qwen inference
```

This graph requires demonstrated compatible emission and linking. Current source
instead offers native assembly emission, which would require a different runtime
integration. No such redesign is implemented or asserted to preserve the ABI.

## Verification and preservation

Recorded commands: `make -n inference`, `make -Bn chat-gpu`, `nvidia-smi -L`.
See adjacent logs. Full `make inference` was not run: stop conditions were found
before implementation; it would rebuild existing runtime artifacts without the
required accepted compiler. No build acceptance is claimed from dry runs.

`existing-artifacts.json` records SHA-256 and size of every existing production IR
and the CUDA library. No existing artifact was deleted or overwritten. The CPU
backend IR already has size zero; no accepted Seed baseline is established by
these files. The pre-existing uncommitted CUDA library modification is preserved.

Only this report and adjacent audit logs/manifests were added. No build recipe,
source module, test, external S file, compiler artifact or Git history was changed.

## Acceptance and performance

All migration acceptance items remain unverified/blocked: Stage4 compilation,
linking, compiler identity, reproducibility, runtime/ABI compatibility, real model
loading, 24-layer execution, tokenizer, greedy/EOS behavior, 32 generated tokens,
independent logits/argmax comparison and accepted output matching. Neither CPU
nor GPU inference was executed. No numerical tolerance, maximum absolute error,
or floating-point difference can be reported without measurements.

Native inference, Qwen loading, tokenizer, transformer forward, KV cache, GPU and
serving regressions were not run against a migrated build because none exists.
No historical failure is classified as a Stage4 regression.

| Metric | Seed baseline | Stage4 |
|---|---|---|
| Compilation time | Not measured | Blocked |
| Model loading time | Not measured | Blocked |
| TTFT | Not measured | Blocked |
| Average TPOT | Not measured | Blocked |
| Peak RSS | Not measured | Blocked |
| GPU utilization | Not measured | Blocked |
| Logits error | No validated baseline | Blocked |

To resume: make the accepted compiler available at the designated path, supply
its provenance and compatible IR emission/linking contract (or resolve that
compiler limitation outside this protected repository), and restore GPU access.
Then probe operations in separate output directories before touching production
artifacts, establish the Seed/reference baseline, and implement the scoped recipe
changes with explicit compiler identity logging and no fallback.
