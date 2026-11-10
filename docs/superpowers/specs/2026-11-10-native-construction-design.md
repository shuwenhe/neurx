# Native construction: semantic audit and design

Status: proposed implementation design; architecture selected by the implementer under the user's explicit instruction to evaluate and choose the smallest safe mechanism. Not an acceptance claim.

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
