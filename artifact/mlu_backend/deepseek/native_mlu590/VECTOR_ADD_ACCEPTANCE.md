# Native Vector Add acceptance

**BLOCKED** on device access and SDK. All hardware steps are **NOT_TESTED**. No native kernel file, build result, device result, or performance number was produced.

After administrator-confirmed device allocation and vendor-approved native SDK verification, use one allocated MLU590-M9. Record native CNRT initialization, device count and properties, then create a context and named stream. Allocate native device buffers, transfer two distinct FP32 inputs, submit a real BANG C Vector Add, synchronize successfully, and read the entire output back. Check all elements against an exact predeclared fixture such as inputs `A[i]=i`, `B[i]=-i+1`, with expected value 1 for every element at sizes well within exact FP32 integer range. Compute the output only on MLU. Check stream and device-buffer cleanup and preserve the first vendor error. Log real commands, statuses, device identity and mismatch count. Start BF16 GEMM only after native Vector Add passes.
