# NeurX Compatibility Assessment

## Existing architecture

NeurX has a backend-oriented device abstraction in `src/runtime/device/`.

Relevant source:
- `src/runtime/device/device_abi.s`: external device ABI and `cuda`, `cann`, and `cpu` backend names.
- `src/runtime/device/device_tensor.s`: backend, dtype, shape, strides, allocation, views, and release.
- `src/runtime/device/device_ops.s`: embedding, RMSNorm, linear, RoPE, paged attention, SwiGLU, and residual operation descriptors.
- `src/runtime/device/device_binding.s`: buffer and scalar bindings for operations.
- `src/compute/gpu_gemm.s`: GEMM shape validation and CUDA-named kernels.
- `src/compute/gpu_attention.s`: attention validation and CUDA-named kernels.
- `src/compute/cublas_binding.s`: direct cuBLAS declarations.
- `src/distributed/nccl_comm.s`: NCCL-shaped communication API and placeholder state handling.
- `src/distributed/tensor_parallel.s`: tensor-sharding and collectives-shaped functions.

## MLU readiness

The architecture does not yet contain an MLU backend. There is an existing CANN capability path, but CANN is Ascend-specific and must not be treated as Cambricon compatibility.

The CUDA code is not sufficient for MLU execution:
- Direct cuBLAS functions are CUDA-specific.
- CUDA-named attention and GEMM entry points contain validation/placeholders rather than verified vendor kernels.
- The runtime lowerer is not evidence of CNRT/CNNL/CNCL bindings.
- NCCL-shaped functions do not call NCCL or CNCL.

## Minimum implementation layers

1. Add `mlu` to the backend ABI while preserving `cpu`.
2. Implement CNRT context, stream, device, allocation, copy, synchronization, and error handling.
3. Add an MLU-specific operation lowering table.
4. Bind CNNL for GEMM, RMSNorm, RoPE, SwiGLU, embedding, softmax, and paged attention where supported.
5. Bind CNCL for all-reduce, all-gather, reduce-scatter, broadcast, send/receive, and all-to-all.
6. Implement BF16/FP16 tensor layouts and conversion rules.
7. Add KV-cache allocation and paged-attention integration.
8. Replace NCCL-only names for MLU with explicit CNCL calls or a backend-neutral collective dispatcher.
9. Add NUMA-aware pinning and process-to-card mapping.
10. Preserve CPU backend behavior and add tests that fail if MLU is unavailable.

## BF16 and native inference

NeurX source contains BF16-related device dtype support, but this is not evidence of MLU BF16 execution. Required evidence is a CNRT/CNNL BF16 kernel result with numerical checking.

Native Qwen inference cannot be declared MLU-ready until:
- Host-visible CNRT and CNNL are approved and installed,
- an MLU context can be created by a NeurX process,
- BF16/FP16 kernels execute,
- host/device copies succeed,
- weight loading and KV-cache memory fit,
- attention and decoding run end to end.

## Classification

- **CONFIRMED:** CPU backend abstraction and device ABI structures exist.
- **PARTIALLY CONFIRMED:** tensor, operation, BF16 dtype, attention, KV-cache, tensor-parallel source concepts.
- **NOT FOUND:** MLU backend implementation, CNRT bindings, CNNL bindings, CNCL bindings.
- **BLOCKED:** native MLU execution without host runtime components.
