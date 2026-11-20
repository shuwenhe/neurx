# Native GEMM implementation readiness

**BLOCKED at SDK compatibility.** No production GEMM adapter or kernel was added. Device ABI v1 and the existing CPU, CUDA, CANN, and MLU unavailable paths were preserved. `make device-abi-mlu-test` and `git diff --check` both exited 0. The prepared S-first architecture is the one in [the implementation design](MLU_GEMM_IMPLEMENTATION_DESIGN.md).

| Boundary | Planned work after the SDK gate |
| --- | --- |
| S API | Reuse the current v1 descriptor, binding, and tensor APIs. Validate A[M,K], B[K,N], and C[M,N], distinct output storage, common context, valid stream, dtype and checked byte counts. S owns dispatch, submission tracking and cleanup. |
| Layout | Row-major, no transpose, alpha 1, beta 0. Leading dimensions are measured in elements and fixed to `lda=K`, `ldb=N`, `ldc=N` for packed v1 buffers. Reject nonzero byte offsets and padded layouts in the first implementation. |
| Native adapter | Resolve exact vendor declarations from approved headers. Own native vendor handles, pointers, descriptors and function calls in typed code. Exchange only scalar handles and validated descriptor fields with S. |
| Transfers and queues | Reuse v1 synchronous copy for the first acceptance run. Provide typed host staging where needed. Bind the selected CNNL handle and its workspace to the named CNRT queue. Preserve v1 copy semantics and retain resources through synchronization. |
| Error and cleanup | Report the first failed operation and precise vendor result. Unwind completed acquisitions in reverse order. Preserve in-flight descriptors, buffers and workspace until completion or supported recovery. |

Execution order after the gate passes is CNRT initialization and device selection, queue creation, CNNL handle setup, buffer allocation and H2D, algorithm/workspace selection for the validated dtype tuple, real CNNL matmul, synchronization, D2H, CPU comparison, then cleanup. Run the numerical acceptance cases before benchmarking. A successful loader probe or CPU fixture does not satisfy any MLU execution requirement.
