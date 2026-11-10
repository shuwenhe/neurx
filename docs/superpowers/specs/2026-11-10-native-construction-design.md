# Native construction: semantic audit and design

Status: implemented and tested; final specified-Qwen evidence is in `docs/NATIVE_INFERENCE_ACCEPTANCE.md`; architecture selected by the implementer under the user's explicit instruction to evaluate and choose the smallest safe mechanism. Not an acceptance claim.

## Scope and state

All operations stay in `/home/shuwen/shuwen/neurx`. Top-level repository and the nested compiler-source checkout both use `main`; previous source changes are uncommitted and preserved. Existing bundles have passed `git bundle verify`; the existing byte-index patch has been inspected. A new pre-change snapshot lives in `artifact/local-inference/array-construction-20261110/recovery`.

## Current semantics before changes

- Canonical MIR and SSA use `array_make`, `array_new`, `array_get`, `array_set`, `array_append`, and `array_len` with verified element/result types. Arrays have value semantics. A copied array or record field must continue to observe its prior elements when another alias is updated.
- Native array ABI is a pointer to an eight-byte element count followed by eight-byte cells. Float cells contain f64 bits, integer cells contain int64, and string/record cells contain GC pointers. This ABI is separate from Seed's tagged standalone representation.
- `amd64_emit_array_with_values` checks bounds, allocates `(length+1)*8`, copies every cell, then writes the requested element. The resulting pointer is a new SSA value; the old one remains valid. This enforces value semantics without ownership/alias analysis or reference counts.
- Allocation goes through `.Ls_native_alloc` and the non-moving conservative mark/sweep collector. Stack/register snapshots and the `s_native_gc_roots_begin..end` range are roots. The collector scans whole reachable objects and rounds requested sizes to power-of-two size classes. Large tensors consequently have predictable rounding overhead, which must be recorded separately from requested bytes.
- There is no proven uniqueness signal attached to ordinary `array_set`. Changing it globally to an in-place store would break aliases.
- NeurX's current `hf_float_slice`, tensor decoding, model assembly, and tokenizer vocabulary assembly build arrays by repeated value writes, causing O(N²) copying. Slices are currently eager copies. Neither the source nor ABI implements retained immutable views.

## Alternatives evaluated

A. Dedicated mutable builder: isolates mutation to a construction phase and consumes its handle on publication. Small runtime/ABI addition, ordinary arrays unchanged.

B. Bulk operations: needed for file decode, slice/copy, and assembly. Pure bulk functions can allocate once and preserve value semantics; on their own they do not provide efficient general indexed construction.

C. Copy-on-write with verified uniqueness: would require sound alias/ownership propagation through MIR, phi nodes, records, calls and loops, or runtime reference counting. Too broad for the first construction mechanism.

D. General Native TensorBuffer: adds long-lived tensor ownership, views and lifecycle to every operation. More invasive than a bounded builder phase.

E. Immutable views: require retaining base storage plus offsets/strides and changing consumers/ABI. Useful later, but a linear copying slice suffices to remove the current quadratic behavior.

Decision: A plus B. Keep ordinary array operations unchanged. Use a small GC-rooted builder registry and pure bulk construction helpers. No unrestricted raw pointers are exposed.

## Builder lifecycle and safety

- Opaque monotonically increasing integer IDs identify registry entries. An ID is not a raw pointer. Invalid/stale IDs are looked up safely and return errors; IDs are never reused. Overflow fails creation.
- Registry descriptors and their normal-ABI array backing storage are GC allocated. A single registry-head pointer is placed inside the existing native GC root range in both programs with globals and programs without globals. Descriptors retain `next` and backing storage, so GC also retains strings held by string builders.
- Typed builders support float, integer and string cells. Runtime kind checks prevent publishing string bits as floats or vice versa. MIR and SSA whitelist exact signatures for all new intrinsics.
- Construction is zero initialized once. Indexed writes check kind, liveness and bounds, perform one store, and allocate/copy no arrays.
- Handle copies explicitly refer to the same mutable construction state. This does not change S array value semantics: backing arrays cannot be obtained before publication.
- Finish removes the entry from the registry before returning its backing storage as a normal S array. It allocates/copies nothing. All aliases of the consumed handle become invalid. A second finish, release or write fails. Returned array aliases continue to use unchanged copy-on-write-by-copy behavior.
- Release unlinks the entry, making descriptor/backing storage eligible for ordinary GC. There is no manual free of a potentially published object. Forgotten release of an unfinished builder is an explicit lifecycle leak; integration must release on every error, and repeated/failure tests will check bounded memory and zero live-builder count.
- Allocation failures follow existing native allocator behavior (fatal exit 126). Negative lengths, invalid kinds and overflow are rejected before allocation. Bounds errors return status, not unchecked memory writes.
- The runtime remains single-threaded, matching its existing collector. No thread safety is claimed.

## ABI and bulk operations

New intrinsics use existing native-intrinsic lowering and exact MIR/SSA signatures. Float-builder write/fill accept S `float`, passed as its existing eight-byte slot bits to an integer-register C adapter, which stores those bits. No floating return ABI change is required. All other arguments/results are integer handles, existing pointers or status codes. This convention must be tested, not assumed.

Bulk operations:

1. Read a validated byte range of F32/BF16/F16 tensor data directly into one normal-ABI float array, using bounded stack read buffers and exact short-read/error handling. Preserve IEEE decoding and reject invalid offsets/length arithmetic.
2. Copy an integer-byte array to one length-counted native string, preserving NUL bytes.
3. Copy a float slice once; clone-and-patch a float array once, leaving all input aliases unchanged.
4. Copy an existing array range into a live typed builder with full source/destination bounds checks.

No compiler-generated validation is disabled. Runtime extension assembly is regenerated from its C source with the existing generator; generated-output checks remain mandatory.

## NeurX integration

- Tensor decode and embedding-row loads use the bulk reader, eliminating expanded int-byte arrays and per-element output copies.
- Full-model field assembly uses builders and bulk range copies, retains existing hf_model_weights field layouts, and closes all outstanding builders on failure.
- Transformer output-vector construction uses float builders; cache updates and weight slices use pure bulk operations. Ordinary caller arrays remain immutable values.
- Tokenizer JSON is read as text; vocabulary/merge tables use int/string builders. Parse errors must close every active builder before returning invalid state.
- Required shapes are checked before copying tensor values. The 24-layer execution path, tokenizer behavior, and fail-closed errors remain observable.

## Tests and measurements

- Preserve ordinary alias behavior across array assignment, function parameters, nested records, and slices.
- Builder alias invalidation; negative/out-of-range indices, wrong kind, fake IDs, double finish/release, empty arrays, length overflow, writes after finish and release.
- GC stress with string builders whose only roots are their handles/registry, including programs both with and without globals; repeated construction/finalization/release.
- BF16/F32/F16 decoding versus independent byte-level reference; offset/length/short read and missing file tests; slice/copy overlap and untouched source aliases.
- Measure 4K, 8K, 16K, 32K, 1M and 10M. Record wall/CPU, peak RSS, logical allocation calls, requested/rounded bytes, bytes copied, indexed writes and live builders. Indexed writes and finish must cause zero full-array copies; expected construction allocations are constant in N.
- Run existing native float, GC, intrinsic, bootstrap-execution and NeurX regressions. Keep RED/GREEN evidence for repaired behavior.
- Only after these gates, run the official complete bootstrap in a new directory, verify Stage1–4 and install through the official target inside NeurX. Do not accept diagnostic stages as Stage4.
- Build using the installed compiler, then attempt the real checkpoint. Record complete loading, all 24 layers, genuine logits compared independently, >=32 generated tokens, TTFT/token latency/peak RSS. Python may generate/check independent test references but cannot replace native inference.

Any failed gate preserves logs and yields NOT DONE. Passing builder benchmarks or compiler tests alone is insufficient.

## Builder-check resolutions and exact internal contract

Independent builder review found no architectural blocker and required the following precision:

- Allocate/zero a descriptor, link it into the rooted registry, then allocate backing storage. A forced collection between the two allocations must retain the descriptor. The root is an actual slot named `s_native_tensor_builders` inside both emitted root-range variants.
- Internal creation returns a positive ID or a negative error code; zero is never a valid ID. Reserve `INT64_MAX` as the last possible ID and fail further creation rather than wrap.
- Finalization is an explicit checked two-step boundary: `seal(id,kind) -> int` returns 0 on success or a negative error and never consumes on kind mismatch; `take_float/int/string(id)` is used only after successful seal, unlinks the sealed entry and returns its existing backing pointer without allocation. S-facing finish wrappers return a typed `{ok, values, error}` result and never expose a failed take. This distinguishes valid empty arrays from failures. A copied handle cannot write once sealed or taken.
- Bulk tensor read returns a positive unsealed float-builder ID or a negative error. It never returns a partially populated normal array; failures close the file and unlink the builder. The ordinary S result wrapper seals and takes it only on success.
- Internal float slice/copy primitives are invoked after S-facing subtraction-based bounds validation; native code repeats all checks. No invalid/null output is used as a valid result by the wrapper.
- Byte-array conversion intentionally takes the low 8 bits of each integer, matching existing `__std_byte_string` behavior, and preserves embedded NUL.
- Decode tests cover independent IEEE signed-zero, subnormal, infinity and NaN reference values. Model-level finite-value policy is distinct from representation decoding.
- Releasing an entry guarantees zero live registry references, not immediate OS RSS reduction under conservative GC. Measurements will identify requested bytes and GC size-class rounded bytes separately.

Internal signatures (all exact MIR/SSA-checked):

```
__native_builder_new(int count, int kind) int
__native_builder_set_float(int id, int index, float value) int
__native_builder_set_int(int id, int index, int value) int
__native_builder_set_string(int id, int index, string value) int
__native_builder_fill_float(int id, float value) int
__native_builder_copy_float(int id, int offset, float[] source) int
__native_builder_seal(int id, int kind) int
__native_builder_take_float(int id) float[]
__native_builder_take_int(int id) int[]
__native_builder_take_string(int id) string[]
__native_builder_release(int id) int
__native_builder_open(int id) bool
__native_builder_stats(int metric) int
__native_builder_stats_reset() int
__native_tensor_read(string path, int offset, int count, int dtype) int
__native_float_slice(float[] source, int offset, int count) float[]
__native_float_patch(float[] target, int offset, float[] source) float[]
__native_bytes_string(int[] bytes) string
```

Kinds: float=0, int=1, string=2. Tensor dtype codes: F32=0, BF16=1, F16=2. Statuses: invalid arguments/kind=-22, invalid/stale handle=-9, index/range=-34, already sealed=-114, overflow=-75, premature EOF=-61; syscall I/O failures retain their negative errno. Successful mutation/release/seal/reset returns 0. Wrong-kind seal leaves an open builder intact.

The user delegated architecture choice and implementation in the mission and subsequently required main-only execution. This document records the implementer's selection; no additional architecture preference is being attributed to the user.
