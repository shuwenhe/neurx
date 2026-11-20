# NeurX MLU590 GEMM integration design

**Status: preparation complete. Native implementation is blocked on the approved Neuware SDK and device access.** Reuse the S runtime's Device ABI v1 descriptor, binding, tensor and lifecycle interfaces. The first hardware target is packed row-major BF16 and FP16 GEMM, with FP32 accumulation and FP32 output. Accept each dtype independently. See [P0 acceptance](P0_GEMM_ACCEPTANCE.md) and [runtime acceptance](MLU_RUNTIME_ACCEPTANCE.md).

## Existing call chains

| Entry | Path and endpoint |
| --- | --- |
| CPU reference | `backend/platform/cpu/compute_backend.s` → `backend_matmul` → `cpu_matmul` for a CPU context. The CPU loop computes row-major `A[i*K+p] * B[p*N+j]`. The same module has a separate CANN intrinsic branch. Reuse `cpu_matmul` for small independent expected-result fixtures. |
| Legacy GPU compute | `src/compute/gpu_gemm.s` → `gpu_gemm_validate` → `gpu_gemm` → output tensor metadata backed by the caller's C tensor. It uses the older `neurx.device.abi` tensor representation and does not submit a vendor call. The similarly named helper in `src/compute/core_kernels.s` also constructs metadata. |
| Live transformer dispatch | `device_transformer.s` builds `op_linear` → `vendor_lowering.s` selects a backend name → `transformer_descriptor_plan_compile` creates a stream and v1 operation → `linear_binding` supplies input, weight, optional bias, output and rows → `transformer_plan_execute` → S `device_operation_launch` → `neurx_device_op_launch` → C++ registry validates context ownership, translates `buffer.*` handles, and invokes the loaded v1 plugin's launch callback. Synchronization and release are separate calls. |
| CUDA endpoint | `backend/platform/cuda/device_abi_cuda.cu` accepts `linear`, parses bindings, resolves buffers and queue, and calls `cublaslt_linear` → row-major cuBLASLt layouts → `cublasLtMatmul`. Its GPU compute type is `CUBLAS_COMPUTE_32F`. This is a concrete vendor submission path. |
| CANN endpoint | `backend/platform/cann/device_abi_cann.cpp` accepts `linear`, selects the ACL stream and builds a `neurx_cann_kernel_request_v1` with typed native buffer pointers. It calls `neurx_cann_kernel_launch_v1` from the external kernel library configured by `NEURX_CANN_KERNEL_LIB`. The `aclnn_matmul` lowering label alone does not establish what that external provider calls. |
| MLU endpoint | The S runtime has the `mlu` identity with zero feature flags. `device_open` stops at the unavailable probe. The plugin table rejects create, allocation, stream and operation callbacks. The optional CNRT diagnostic resolves enumeration/selection symbols and can call enumeration in isolation. The generic lowering fallback would label an available MLU operation `reference`. There is no MLU GEMM descriptor lowering or CNNL dispatch. |

Reuse `op_descriptor` in `device_ops.s`, `binding_buffer` and `binding_join` in `device_binding.s`, `device_tensor`, dtype and storage metadata in `device_tensor.s`, and operation/stream wrappers in `device_abi.s`. Reuse the executor's compile/submit/synchronize pattern. It currently releases operations and stream without an explicit wait, so a GEMM plan with work in flight must synchronize successfully before release. Add one new **standalone `gemm` operation** for the first milestone. Keep the transformer `linear` contract and its bias/bindings in place. A future validated MLU `linear` lowering can reuse the same native matmul primitive by mapping its descriptor and supplying the correct weight layout and bias semantics.

## Vendor API evidence

The installed Neuware prefix exposes CNDev 3.12.4. `ldconfig -p` showed no CNRT or CNNL. No `cnnl.h` or `bang.h` was found in the inspected SDK paths, and `cncc` was absent from PATH. The locally staged `cnrt.h` came from the official cached CNRT 6.12.1 Ubuntu 22.04 package. Its library requires glibc 2.34 and fails to load on this glibc 2.31 host. Header evidence establishes signatures for that release. An approved Focal SDK matched to MLU590-M9 and driver/firmware 6.5.52 remains required. [Local compatibility matrix](../native_deployment/diagnosis/NEUWARE_COMPATIBILITY_MATRIX.md)

| Requirement | What is verified |
| --- | --- |
| CNNL BF16 GEMM | Cambricon's CNNL v1.20.0 notes list BF16 support for `cnnlMatMul_v2`. The v1.23.0 notes describe FP32 off-chip output with BF16 on-chip inputs for `cnnlMatMul`. The exact MLU590 tuple of operation, A/B storage, descriptor controls, accumulator and output still needs the approved release's header, API guide and execution evidence. |
| CNNL FP16 GEMM | The same v1.23.0 notes document Half on-chip input and FP32 off-chip output for `cnnlMatMul`. Check exact descriptor and algorithm support in the approved package before advertising the FP16 path. |
| BANG C matrix multiplication | Cambricon publishes a BANG matrix multiply tutorial, including a convolution-based example, and documents `mtp_592` for MLU590-M9. The tutorial and compiler target establish a development route. They do not establish a BF16/FP16/FP32-accumulation implementation for the target SDK. Use the release-specific BANG headers and guide if CNNL cannot satisfy the contract. |
| CNRT queues | Cached vendor declarations include `cnrtRet_t cnrtQueueCreate(cnrtQueue_t *pQueue)`, `cnrtRet_t cnrtQueueSync(cnrtQueue_t queue)`, and `cnrtRet_t cnrtQueueDestroy(cnrtQueue_t queue)`. |
| CNRT memory | Cached declarations include `cnrtRet_t cnrtMalloc(void **pPtr, size_t bytes)`, `cnrtRet_t cnrtFree(void *ptr)`, `cnrtHostMalloc` and `cnrtFreeHost` for pinned host storage. |
| CNRT transfers | Cached declarations include `cnrtRet_t cnrtMemcpy(void *dst, void *src, size_t bytes, cnrtMemTransDir_t dir)` and `cnrtRet_t cnrtMemcpyAsync(void *dst, void *src, size_t bytes, cnrtQueue_t queue, cnrtMemTransDir_t dir)`. The async example uses pinned host buffers and synchronizes before their release. |

Vendor references

- [Cambricon CNNL release notes and platform support](https://sdk.cambricon.com/static/independent/CNNL/1.23.2/releasenote/1.23.2/build/html/cnnl.html)
- [Cambricon BANG C matrix multiplication tutorial](https://developer.cambricon.com/index/curriculum/expdetails/id/8/classid/8.html)
- [Cambricon CNToolkit architecture and compiler targets](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_components/index.html)

The proposed first choice is CNNL. Select the concrete function signature and descriptor/algorithm/workspace calls from the approved `cnnl.h` and its matching guide. Distinguish on-chip representation and FP32 output from FP32 accumulation. Require explicit evidence that the selected mode accumulates in FP32. Reject the configuration if the library cannot provide that mode.

## Proposed S public interface

One typed plan covers both input dtypes. Names below describe new S functions, independent of vendor symbols.

```text
gemm_spec { m, n, k, lda, ldb, ldc, input_dtype, accumulate_dtype, output_dtype }
gemm_prepare(context, stream, spec) -> gemm_plan
gemm_submit(plan, a: device_tensor, b: device_tensor, c: device_tensor) -> int
gemm_wait(plan) -> int
gemm_release(plan) -> int
```

The plan borrows the caller's context and named stream and owns its v1 operation. Input and output tensors are caller-owned. Prepare validates the immutable spec and opens the operation through the existing device API. S serializes a proposed descriptor such as `v1;op=gemm;m=128;n=128;k=128;lda=128;ldb=128;ldc=128;input_dtype=bf16;accumulate_dtype=fp32;output_dtype=fp32;layout=row_major`. Submit builds `buffer.a`, `buffer.b`, and `buffer.c` using existing binding helpers and calls the existing operation-launch wrapper. Wait uses the existing stream synchronization wrapper. The plugin validates the descriptor and bindings again at the v1 boundary so direct ABI callers cannot bypass memory safety. Keep the public v1 struct, callbacks, and handle semantics unchanged.

| Mode | A/B storage | Accumulation | C storage |
| --- | --- | --- | --- |
| BF16 | BF16, two bytes per element | FP32 | FP32, four bytes per element |
| FP16 | FP16, two bytes per element | FP32 | FP32, four bytes per element |

First scope is overwrite GEMM `C=A×B` with alpha 1, beta 0, no bias, no transpose or batching. The vendor path must guarantee beta-zero overwrite semantics, or explicitly initialize output when required by that API. Narrower output and fused operations are separate acceptance cases.

Leading dimensions are row strides measured in elements. A is `[M,K]` at `i*lda+p`, B is `[K,N]` at `p*ldb+j`, and C is `[M,N]` at `i*ldc+j`. General lower bounds are `lda>=K`, `ldb>=N`, `ldc>=N`. Initially require packed strides `lda=K`, `ldb=N`, `ldc=N`, inner stride 1 and byte offset zero. Deferred padded/view support needs a confirmed vendor stride API and explicit offset transfer; the v1 binding currently forwards handles only. Compute required bytes by checked arithmetic as `((rows-1)*ld+cols)*element_bytes`. Check dimensions, strides, valid tensors, dtype, backend, context, buffer size, output overlap, and the signed v1 `int` byte limits before narrowing. Require distinct output storage from either input. Reject unvalidated device/dtype combinations explicitly.

## Lifecycle and boundary

1. S acquires the context, stream, buffers and operation in dependency order and unwinds completed acquisitions in reverse order on failure. The native adapter owns typed queue, pointer, CNNL descriptors, handle and algorithm/workspace records indexed by integer IDs. Device selection is thread-sensitive, so set or verify the correct device at native call boundaries. Retain workspace and plan resources until completion. Use a per-stream vendor handle or serialize queue binding on a shared handle.
2. Keep descriptor semantics, capability decisions and lifetime tracking in S. The current shared S exporter accepts only integer arguments and results. C may tokenize incoming ABI text into fixed scalar fields, validate representability, and pass those fields to private integer-only S exports for policy decisions. Keep native pointers and typed symbol calls in C. The adapter rechecks resolved native allocation ranges and ownership before submission. Do not pass `dlopen` handles, queue pointers or raw buffer addresses through integer-only S FFI. Avoid re-entering a held registry or S interpreter lock from callbacks.
3. Use ordered synchronous copies for this milestone. v1 copy accepts context, two buffer handles, count and direction. It has no stream selector or host pointer. A real CPU-to-device round trip needs a typed staging path to populate/read host storage; use an existing compatible staging interface if available or a private host staging bridge before claiming transfer support. Later asynchronous transfers require an explicit stream-aware private interface or a versioned extension, pinned host storage, and validated completion semantics. Do not silently change v1 copy semantics.
4. Submit enqueues work and leaves the plan and its buffers live. The initial plan permits one in-flight submission. Wait establishes completion before D2H or release. Do not recycle buffers/workspace or destroy submitted resources after a failed synchronization until completion or a supported recovery is established. Preserve the first error and expose vendor operation, status and useful context through `last_error`. Never turn a loader check or successful enqueue into a completion result.
5. Preserve the existing unavailable MLU path until device initialization and dtype-specific tests pass. The current v1 probe exposes a single availability integer, and S currently publishes zero MLU feature bits. Use an explicit S capability policy backed by approved, validated configurations before publishing BF16/FP16 readiness. CPU, CUDA and CANN implementations remain untouched.

## Implementation gates

1. Obtain the vendor-approved native package manifest and device allocation. Check loaded library versions, required symbols and exact header signatures. Revalidate the device runtime before GEMM. Device nodes were absent in the P0 runtime gate.
2. Cover pure S spec parsing, shape/stride/byte overflow, wrong context, aliasing and unsupported dtype. Exercise v1 descriptor and handle translation, then partial allocation cleanup and synchronization failure. Preserve the existing unavailable contract test.
3. Certify native allocations, H2D/D2H and queue synchronization before real GEMM. Test the five P0 square sizes and rectangular order checks separately for BF16 and FP16. Use the existing CPU oracle with dtype-rounded inputs and compare FP32 results. Include repeated launches, deterministic fixtures, nonfinite detection and cleanup checks. Publish latency and throughput only for successful hardware runs.

Verification during preparation: `make device-abi-mlu-test` and `git diff --check` exited 0. No vendor runtime or GEMM was executed. This document is the only change made for the preparation task.
