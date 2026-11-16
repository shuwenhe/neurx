# NeurX Stage4 inference compatibility design

Date: 2026-11-16. Status: **PROPOSED — architecture approval required**.
Migration acceptance remains **BLOCKED**. This document changes no implementation.

## Recommendation

Choose **Architecture B: Stage4 native execution**, initially with an explicit
process boundary between a Stage4-built S control plane and a small native C++/CUDA
worker. Reuse the existing CUDA decoder, model loader, tokenizer, and session
implementation. Do not attempt to execute native assembly in the IR runner.

This is the smallest defensible GPU migration under the constraint that the
external compiler cannot change: the inspected native backend does not offer the
legacy IR output/linking contract or general dynamic C linkage required by the
current server. A process boundary avoids inventing an unverified S/C ABI and
keeps the existing numerical implementation. It adds a protocol adapter, not a
new transformer. Its feasibility is conditional on the accepted Stage4 binary
passing process-I/O tests; no binary is available to establish that today.

CPU compiler/runtime qualification proceeds separately through the existing
native S executor and numerical tests. It is not a substitute for qualifying the
current CUDA decoder or for proving migration of `make inference`.

## Scope and evidence quality

Baseline: [REPORT.md](REPORT.md), NeurX revision
`5a258ed2b87ad565e22fe23cf09e810f1851a879`; read-only external source revision
`0f8f661dd84301d6bd277fbc94460831317e0c45`. Paths beginning `../s/` below are
external source evidence, not files proposed for modification. They describe this
checkout and cannot attest to the behavior of a missing accepted binary.

No Makefile, compiler, source module, installed binary, or existing inference
artifact is changed in this phase. The pre-existing modified CUDA shared library
must remain untouched. No compiler execution, real inference, performance test,
or GPU acceptance is claimed by this design.

## Compiler formats and exact compatibility blockers

| Operation | Inspected implementation | Consequence |
|---|---|---|
| `compiler input.s output` | `../s/src/cmd/compile/internal/compiler/main.s:57` calls `emit_canonical_mir_public` | Canonical MIR is not demonstrated to be legacy target IR. File extension proves nothing. |
| `--compile-unit OUTPUT SOURCES...` | Same file, `handle_compile_unit`, lines 302–345 | Joins source closure, lowers canonical MIR, emits target assembly with `# S-NATIVE-AMD64-V1`. |
| `--emit-bin INPUT OUTPUT` | Same file, lines 347–359 | Requires native assembly header; emits native executable, not interpreter input. |
| `--emit-native-object INPUT OUTPUT` | Dispatcher and `../s/src/cmd/compile/internal/core/native_build.s` | Object construction exists for a source input; multi-module object export and mixed C++ linkage are not established by that fact. |
| `--link-ir OUTPUT INPUTS...` | No dispatcher handler | Existing enhanced backend command cannot be retained with a compiler-name substitution. |
| Installed accepted compiler | `../s/bin/s_compiler` absent; bootstrap stage4 absent | No binary identity, feature probe, output sample, or accepted provenance available. |

Current production target files use `SSEED-TARGET-V1`. Their generator is
`../s/src/cmd/compile/seed/code/generator.c:34`: escaped, pipe-delimited records
with four fields (`opcode`, `result`, `operand1`, `operand2`), function boundaries,
labels, calls, exports, and metadata. The consumer is the Seed C runtime parser,
which rejects another header at `runtime/runtime.c:3634`. This is an executable
instruction/host-call contract, not merely a serialization spelling.

`seed_link_ir_files` (`seed/s_seed.c:445`) validates module headers, emits a single
header, combines bodies, and prefixes matching local `L<number>` label operands
with module identifiers. It is not an ELF linker or a general semantic linker.
An equivalent linker must preserve cross-module symbols, local control-flow
references, metadata and escaping; malformed/duplicate/unresolved symbols need
tests rather than blind concatenation. Implementing that text linker alone would
not supply compatible instructions from Stage4.

**Can Stage4 produce compatible IR without external changes?** There is no
supported, demonstrated direct route in the inspected checkout. A NeurX-local
canonical-MIR-to-legacy-IR translator is possible as a research project, but would
be a new compiler backend: it must define mappings for all operations, types,
ownership, intrinsics, exports and host-call descriptors. No such translator is
present or verified. Assembly-to-IR conversion is not a viable minimal design.
Calling Seed to lower or serialize the program would violate the migration goal.
Binary probes must recheck this conclusion when the accepted compiler arrives.

## ABI, calling conventions and ownership

### Existing interpreter/CUDA boundary

`tool/s_ir_runner.c` calls `runtime_execute_file`. The interpreter operates on
tagged `runtime_data_value` values, not native S pointers. Its
`host_dispatch_libc_ffi` (`runtime/runtime.c:1056`) resolves encoded
`__ffi_...` descriptors using `dlsym(RTLD_DEFAULT, symbol)`. It accepts up to six
integer/string arguments, passes C string bytes, interprets integer results as
signed 32-bit values, and copies returned C strings into runtime-owned values.
It is not a general floating-point or aggregate C ABI.

`backend/platform/cuda/inference_server.s:16` declares
`extern "libc:neurx_s_cuda_*"` calls. `chat-gpu-run` makes these symbols available
through `LD_PRELOAD=libneurx_s_cuda.so` in a normal host-linked interpreter process.
Neither the declarations nor LD_PRELOAD demonstrate native S support.

`backend/platform/cuda/s_inference_cuda_bridge.cu` exports `extern "C"` functions
with `int` handles/statuses and borrowed `const char*` results. Global C++ smart
pointers own the model/tokenizer; session objects own logits, output, generated
IDs and CUDA KV caches. Returned `c_str()` pointers must be copied before another
mutation, session destruction, or model reset, and must never be freed by S.
The bridge uses mutexes and shared session ownership, but a borrowed pointer can
still become invalid after the export returns. Serialize access and copy results
inside the worker. Preserve `next`: token ID >= 0, EOS -1, error -2. Do not merge
EOS and error paths. Ensure the caller enforces maximum tokens; `session_next`
does not itself count down the requested generation limit.

### Native S boundary

`../s/src/cmd/compile/internal/codegen/amd64_program.s:136` places the first six
internal argument slots in general-purpose registers, additional slots on an
aligned stack, and uses generated function symbols. Internal representations are
compiler-specific; these observations do **not** certify System V interoperability
for floats, arrays, records, strings or returned aggregates. Native string helper
assembly uses length-bearing allocations and explicit conversion to C strings.
Passing an S string allocation directly as `const char*` is invalid.

The native allocation helper in that file calls `s_native_gc_alloc` with saved
register/stack context. The native-construction tests explicitly exercise GC roots,
array value semantics and builder handles. Do not transfer native GC objects to
C++ or assume interpreter ownership rules apply. Foreign-held references would
require a proven rooting/pinning and release contract.

`emit_function_ssa_amd64` rejects unresolved external functions (line 383).
Recognized intrinsics have explicit native runtime implementations; arbitrary
`extern "libc:..."` declarations are not thereby supported. The build path in
`../s/src/cmd/compile/internal/core/native_build.s:88–143` assembles with GNU `as`
and links using `ld -nostdlib` with its own startup/runtime. It supplies no proven
dynamic-loader/libc/C++ initialization path for the CUDA shared library.
Adding linker flags alone cannot establish string conversion, symbol exports,
exception isolation, startup compatibility or GC safety.

## Architecture comparison

| Dimension | A: Stage4 → compatible IR → existing runner | B: Stage4 → native runtime → CUDA worker |
|---|---|---|
| Compiler capabilities | Complete legacy IR emitter, host-call lowering, stable serialization; equivalent IR linking | Native unit compilation/emission; tested file/process or socket intrinsics; no arbitrary C FFI needed for worker variant |
| Runtime changes | Small if exact legacy compatibility exists; otherwise a major adapter/backend | Native S control-plane adapter and C++ worker/protocol; existing interpreter retained only for explicit legacy use |
| ABI | Must reproduce interpreter values, calls and host descriptors | Separate address spaces; versioned byte protocol instead of shared S/C layouts |
| CUDA | Existing preload path can remain only after compatible IR is proven | Worker links normally to existing CUDA/C++ bridge and dependencies |
| Memory | Retains interpreter value ownership and C-string copying | S GC and C++/CUDA allocators remain isolated; explicit session lifetime and copied payloads |
| Performance | Retains interpreter dispatch; translator overhead affects builds | Native control overhead plus IPC; GPU compute remains unchanged; no promised speedup |
| Tests | Opcode/type/control-flow equivalence, linker collisions, FFI and full model checks | Native I/O, framing, cancellation, lifecycle, worker equivalence and full model checks |
| Complexity | High under current compiler: new lowering backend plus compatibility maintenance | Moderate, conditional on accepted native I/O support; direct in-process ABI variant is higher risk |
| Maintenance | Ties Stage4 MIR evolution to legacy interpreter semantics | Versioned NeurX-owned protocol; compiler internals and CUDA implementation evolve independently |

An in-process B variant could eventually use native objects plus a narrow C shim.
It requires demonstrated external relocation/export support, supported startup
without conflicting `_start`, normal C++ initialization, integer/string ABI
adapters, GC rooting and a supported link contract. Those capabilities are not
established now. Do not patch assembly or the external compiler as a shortcut.

## Minimum viable migration: B with a persistent worker

```text
accepted bin/s_compiler --compile-unit -> S-NATIVE-AMD64-V1
                       --emit-bin -> native S control plane
                                              |
                                  versioned process protocol
                                              |
                              NeurX native C++ CUDA worker
                                              |
                    existing neurx_s_cuda session/config exports
                                              |
                    existing HF loader + BPE tokenizer + CUDA decoder
```

Use `tool/build_native.py` source indexing/closure and atomic publication patterns,
not its default compiler discovery: it currently prefers an extension compiler or
bootstrap artifact. An explicit accepted `bin/s_compiler` plus SHA-256 is mandatory.
Its existing script deletes outputs before builds; future probes must use a new
isolated directory, never a directory containing accepted artifacts.

Compile the existing server/client/readiness source closures as far as supported
before adding adapters. Preserve source files and module boundaries; document
the exact unsupported externs. For the MVP, replace the CUDA call boundary with
a NeurX-local native process adapter, reusing existing protocol formatting and
configuration logic wherever compatible. This is a scoped source integration,
not a claim that the original sources already compile unchanged.

The worker is a new native entry point linked to the existing bridge and decoder;
it must execute without an S IR runner or Seed compiler. It is not an IR service
hidden behind a Stage4 launcher. It owns a persistent loaded model and sessions;
never start/reload the model per generated token.

Proposed MVP transport: persistent C++ worker supervised by the existing launch
layer, native S adapter using loopback TCP. Readiness, reconnect failure and exit
status are explicit. Native socket/read/write support is an early feasibility
gate. If only captured-process I/O is supported, qualify bounded one-shot request
execution separately; do not call it streaming or accept repeated model reloads
as the performance target. If neither transport passes, stop B implementation.

Use a versioned, length-prefixed UTF-8 JSON envelope with a bounded frame size,
request ID, operation, protocol version and typed status. Operations: capability,
initialize/configure, create, begin, next, result, destroy, shutdown. Session IDs
are process-local integers, never addresses. Handle partial reads/writes, EOF,
timeouts, malformed frames, worker restart and stale session IDs. Token events
carry exact integer IDs; EOS and errors have distinct status fields. Worker
shutdown releases sessions/model and synchronizes outstanding device work. Keep
weights, KV cache and tensors inside the worker; bulk logits use a separate
test-only bounded dump format with dtype, shape and checksum. Do not serialize
model tensors per token. Bind locally and associate a per-run capability token
with the endpoint; the protocol grants model/session access.

Preserve `hf_decoder_cuda`, safetensors/HF loading, `bpe_tokenizer`, greedy and
stop-token logic. The alternative native S CPU path (`cmd/serve/main.s` →
`src/inference/executor/native_executor.s`) already loads HF weights and BPE and
uses the S CPU transformer. Use it for CPU qualification, not to rewrite or replace
the CUDA path. Existing `device_abi.s` libc declarations face the same native FFI
problem; they do not solve it by renaming exports.

## Minimal implementation plan — only after approval

1. Obtain the accepted compiler from its owner without rebuilding or modifying
   it. Record resolved path, executable hash, provenance, target and available
   version output. Probe native emission and expected failures in a fresh directory.
2. Run small native CPU programs for strings, arrays, integer errors, GC pressure,
   process exit and framed socket I/O. Record unsupported features and stop if
   required operations fail. Run existing native I/O/numerical tests with the
   explicit compiler rather than extension defaults.
3. Establish immutable legacy/reference evidence: source/model/tokenizer hashes,
   prompt IDs, chat template, dtype, backend/device, greedy/EOS settings, tokens,
   logits and timing. Old IR hashes alone are not an accepted baseline.
4. Build a separate worker entry point around existing C++ bridge exports. Qualify
   framing with a deterministic CPU fixture, then compare direct bridge calls
   with worker calls; the fixture is never reported as CUDA inference.
5. Add only the native S CUDA adapter and isolated build orchestration. Preserve
   existing source closures and CPU/GPU implementation. Record every tool command,
   compiler/source hash and native artifact; no Seed/extension fallback.
6. On a working GPU, qualify real model loading, complete layer execution, tokens,
   logits and performance through the actual Stage4-control-plane/worker route.
7. Only after approval for implementation and all relevant gates pass, propose the
   separate production recipe change. Recheck actual `make inference` process
   graph and artifact provenance. Keep explicit legacy entry points and old
   artifacts for comparison; never silently retry Seed or CPU after failure.

## Acceptance gates and test matrix

Each gate has independent evidence. Current status is **not run/blocked** for all
execution gates; source analysis is not a passing result. CPU acceptance can pass
G1–G4 without a GPU; full production GPU acceptance requires G1–G10 on that route.

| Gate | Test and required evidence | CPU versus GPU / dependencies |
|---|---|---|
| G1 Availability/identity | Executable at accepted path, resolved path/hash/provenance matches acceptance record; log identity before any compilation; reject missing/mismatched compiler | CPU; prerequisite for compiler claims |
| G2 Output compatibility | Compile arithmetic, branches, cross-module calls, strings, arrays, records and intrinsics; inspect native header/ELF machine; compare execution values. For A require full legacy opcode/serialization coverage instead | CPU; G1; reject native assembly supplied to IR runner |
| G3 Linking | Multi-module closure, duplicate/unresolved symbols, correct main/startup, deterministic commands, no Seed execution. B worker resolves C++/CUDA symbols separately; A requires label-safe IR linking | CPU build checks; G2; native S and worker linkage are separate results |
| G4 Runtime | Native execution, GC/value semantics, I/O, errors, framed protocol, EOF/timeouts and session lifecycle. Trace process tree to exclude runner/Seed fallback | CPU fixture allowed and labelled; G3 |
| G5 CUDA interoperability | Real device identity/context, actual kernel/API trace, bridge/session calls, failure paths, KV-cache lifetime; no CPU fallback | GPU required; G4 and working driver |
| G6 Qwen loading | Hash accepted Qwen2.5-0.5B-Instruct files; config reports 24 layers; validate dtype/shapes/tied head and tokenizer IDs/template/stop tokens; compare malformed-input failures | Separate CPU loader result and actual GPU worker load; G4/G5 respectively |
| G7 24-layer forward | Runtime trace/counters or test hooks prove layers 0–23 executed for prefill and decode; finite activations and layer checksums against reference | CPU/GPU separately; G6; config alone fails this gate |
| G8 32-token generation | Fixed identical tokenized prompt, greedy settings, exact IDs for >=32 actual generated tokens; compare frozen accepted output; additional forced-EOS and error tests | CPU/GPU separately; G7; choose a baseline prompt that reaches 32 without suppressing EOS |
| G9 Independent logits | Full vocabulary at final prefill plus each of 32 decode decisions; finite checks, max absolute/relative errors, argmax equality, tie policy; per-layer diagnostics on mismatch | CPU/GPU separate budgets; G7–G8; independent arithmetic reference |
| G10 Performance | Compilation, load, TTFT, TPOT, peak RSS, GPU memory/utilization; repeated runs and environment manifest, separate startup/IPC/compute costs | CPU and GPU separately; correctness gates first |

Regression suites to preserve: `test/native-stage4` (including `test_io.py`,
`test_serving.py`, `test_hf_numerics.py`), `test/native-construction` (GC/builders,
loader/checkpoint validation), existing tokenizer, transformer forward, KV-cache,
GPU bridge/kernel and inference-serving tests. Select and record exact test
commands from repository targets at implementation time; some legacy targets need
Seed and belong in a separately labelled baseline run. Never silently substitute
the extension compiler used by several test defaults. Report old unrelated
failures separately from newly introduced failures and from environment blocks.

### Numerical reference contract

Reuse `test/native-construction/qwen_reference.cpp`: independent double-precision
transformer arithmetic over BF16 weights. It currently writes a full logit vector
only at the first generation step, shares the C++ tokenizer, uses a fixed raw
prompt rather than the production chat template, and does not implement production
EOS acceptance. Therefore its current output alone cannot satisfy G8/G9. After
approval, extend its test interface for explicit prompt token IDs and per-step
logit dumps, preserving its independent arithmetic. Verify tokenization separately
using the tokenizer reference and frozen independently accepted IDs. Existing
tiny-model NumPy checks in `test_hf_numerics.py` use absolute `1e-6`; retain them,
but do not extrapolate that tolerance to the real GPU model.

Proposed real-model initial acceptance budget (requires baseline review before
runs): finite logits and `abs(candidate-reference) <= 1e-3 + 1e-3*abs(reference)`
for every compared logit, with exact argmax and generated IDs. Record maximum
absolute error, relative error with denominator `max(abs(reference),1e-8)`,
worst index/step and top-two margin. This is a proposed threshold, not a measured
or previously accepted one. Freeze the budget before evaluating candidates;
do not widen it after a failure. CPU/GPU FMA, accumulation precision and reduction
order may differ; investigate per-layer error and report these differences even
when the gate passes. Compare against both the independent reference and the
same-backend legacy baseline. No available frozen accepted 32-token output or
compiler identity is established by the earlier audit.

### Measurement and reproducibility contract

Use isolated output directories and fixed compiler, source closure, toolchain,
model, tokenizer, prompt IDs and runtime settings. Store commands, hashes, logs,
manifest, repeat-build artifact comparisons and any nondeterministic metadata.
Trace executed compiler processes; absence of `s_seed` in a Makefile search alone
is insufficient. Count C/C++ compiler use separately: it is expected for the
existing CUDA implementation and does not imply the S code used Seed.

Measure clean S compilation separately from C++/CUDA worker compilation; never
delete the working baseline. Record cold and warm model load, request start to
first token (TTFT), per-token intervals and aggregate TPOT excluding first token,
median and spread over at least five measured runs after warmup. Record compiler
and server peak RSS separately; for B, include the S process plus worker and
separate device memory. GPU timings require synchronization at measurement
boundaries and sampled device/process utilization. Compare Seed and Stage4 under
identical GPU clocks/configuration, prompt/template, max tokens and concurrency.
Report IPC contribution and idle persistent-worker memory. No improvement is
predicted or accepted without these measurements.

## Risks, dependencies and stop conditions

- Accepted compiler provenance and capabilities are external dependencies. Checked
  source is not proof of the accepted binary; unsupported native I/O blocks B.
- Extension-only intrinsics may be required by existing native tests or model
  code. An extension compiler is not an authorized substitute for accepted Stage4.
- Worker IPC adds lifecycle/protocol work and possible TPOT overhead. Persistent
  model/session state and small messages limit data movement but need measurement.
- Model globals and borrowed error/output strings make concurrent reset dangerous.
  MVP serializes initialization and session operations; concurrency needs separate
  qualification, including cleanup after disconnect or crash.
- Direct native object/CUDA linkage remains unproven. Do not bypass unresolved
  external diagnostics, patch compiler assembly, or pass native heap layouts to C++.
- Full logits and layer evidence require test-only observation hooks; current
  session exports return tokens/text, not complete logits. Use decoder APIs for
  test hooks without replacing the numerical implementation.
- GPU driver availability, accepted model/reference files and frozen output are
  independent prerequisites. CPU success never grants GPU acceptance.
- Architecture B migrates the S control plane to accepted native code while
  retaining existing C++/CUDA inference. It does not make transformer kernels
  S-native. Any future production-native claim must state this boundary.

Approval sought: Architecture B with the persistent native CUDA worker boundary,
the gated CPU-first feasibility sequence, and preservation of existing CUDA/model
components. Until approval, this document is the complete change for this phase.
