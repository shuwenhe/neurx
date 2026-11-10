# NeurX GPU Inference — Production Acceptance Plan

**Created:** 2026-11-10 16:13 UTC  
**Status:** Phase 1-3 Complete - Phase 4 In Progress  
**Branch:** main  
**Model:** Qwen2.5-0.5B-Instruct @ `/home/shuwen/model/`

## Current State

### Git Status
- Repository: clean (no staged changes)
- Recent commits: Phase 3 fix applied (commit 586d142d)
- Artifacts: `artifact/build/production_s_inference/` exists

### Existing Acceptance Evidence
- ✅ CPU inference works via `make chat-cpu`
- ✅ S compiler bootstrap artifacts preserved
- ✅ Array syntax migration results in `test/array-syntax/`
- ✅ Local inference docs: `docs/local-inference-2026-11-10.md`

### Compilation Status
- ✅ GPU Backend Enhanced: Successfully compiles
- ✅ Chat Client: Successfully compiles
- ✅ Health Check: Successfully compiles
- ✅ GPU Backend Runtime: READY (Phase 3 fixed)

---

## Phase 3: GPU Runtime Fix ✅ COMPLETE

### Root Cause Identified
The S compiler has a bug in code generation for typed variable declarations.

**Pattern:**
```s
int[] bytes = __host_read_binary_file(path)  // TRIGGERS BUG
```

**Generated IR:**
```
ARG|int|_|_
ARG|_|_|_
CALL|t0|__index_get|2
```

The bare type name `int` is generated as an ARG instruction, which the S runtime parser tries to resolve as a variable/literal and fails with "unknown arg value: int".

### Workaround Applied
Remove explicit type annotations and use type inference:
```s
bytes := __host_read_binary_file(path)  // WORKS - no type annotation
```

This avoids triggering the compiler bug entirely.

### Secondary Issue: Missing Intrinsic
The `__std_byte_string` intrinsic was declared but not available in the linked GPU backend IR. Implemented local `byte_to_string()` helper function instead.

### Verification
GPU backend now successfully:
- ✅ Initializes S runtime without FFI errors
- ✅ Initializes CUDA
- ✅ Detects GPU: NVIDIA GeForce RTX 4060 Ti
- ✅ Loads model configuration (24 transformer layers, 896 hidden dimension)
- ✅ Binds to socket on 127.0.0.1:18084
- ✅ Responds to health checks

**Backend Log Snippet:**
```
╔════════════════════════════════════════════════════════════════╗
║  NeurX GPU Backend - Enhanced Pure S Implementation            ║
║  GPU-Accelerated Inference Engine (Real Inference)             ║
╚════════════════════════════════════════════════════════════════╝

Configuration:
  Model: /home/shuwen/model/Qwen2.5-0.5B-Instruct
  Device: gpu
  Host: 127.0.0.1
  Port: 18084

Backend Status: ✓ READY
GPU Available: YES ✓
GPU Device: NVIDIA GeForce RTX 4060 Ti
Total Layers: 24
Active Layers: 24
Hidden Dimension: 896

Backend Status: ✓ READY
HTTP server listening on 127.0.0.1:18084
[Socket] Ready to accept connections
```

---

## Phase 2: Root Cause Analysis ✅ COMPLETE

### Error Report (RESOLVED)
```
error[5] at 0:0: unknown arg value: int  ← FIXED
error[5] at 0:0: unknown function: __std_byte_string  ← FIXED
```

**Execution Path:**
```
make chat-gpu
  ↓
make chat-gpu-run
  ↓
LD_PRELOAD="$(S_GPU_RUNTIME_LIB)" ... "$(S_RUNNER_BIN)" "$(PRODUCTION_S_INFERENCE_DIR)/gpu_backend_enhanced.ir"
  ↓
/home/shuwen/shuwen/neurx/artifact/build/s_runner/NeurX gpu_backend_enhanced.ir
  ↓
[S Runtime] Load IR module
  ↓
[S Runtime] Parse arguments → SUCCEEDS ✓
  ↓
[CUDA] Initialize → SUCCEEDS ✓
  ↓
[S Runtime] Listen for connections → READY ✓
```
```

### Investigation Required
1. What environment variables are being parsed?
2. Which variable contains "int"?
3. Is it a type annotation leak from IR?
4. Is the S runner expecting a different format?

### Minimal Reproduction Target
Create test case with:
- Exact IR linking command
- Exact environment variables
- Trace S runner argument parsing
- Print what's being parsed

---

## Phase 3: GPU Native Compilation

### Error Report
```
error[5] at 703:5: index expression expects int index, got '()'
File: [CPU Backend compilation, not GPU]
```

This appears separate from GPU issue.

---

## Phase 4-7: TBD

Will proceed after Phases 2-3 complete.

---

## Files Modified This Session
- `backend/platform/cuda/inference_server.s` — String arithmetic fixes
- `src/model/formats/hf_config.s` — String indexing fixes  
- `makefile` — Inference target changes

All changes await git commit after GPU fix validation.


---

## Phase 2: ROOT CAUSE IDENTIFIED ✅

### Error Details
```
error[5] at 0:0: unknown arg value: int
```

### Root Cause
**IR Encoding Bug in S Compiler**

The S compiler is incorrectly encoding FFI function signatures in the IR module. When generating IR for:

```s
extern "libc:neurx_s_cuda_device_count" func neurx_s_cuda_device_count() int
```

The compiler generates:
```
CALL|t273|__ffi_libc$neurx_s_cuda_device_count$int$|0
```

The return type `int` is being **appended to the function name** instead of being stored in type metadata. When the S runtime tries to resolve this, it sees:

```
__ffi_libc$neurx_s_cuda_device_count$int$
```

And parses it as three components separated by `$`, where the second `int` looks like a type value rather than a function name component.

### Affected Code
- File: `backend/platform/cuda/inference_server.s`
- Line: 15
- Declaration: `extern "libc:neurx_s_cuda_device_count" func neurx_s_cuda_device_count() int`
- Generated IR: `__ffi_libc$neurx_s_cuda_device_count$int$`

### Verification
```bash
grep "__ffi_libc" artifact/build/production_s_inference/gpu_backend_enhanced.ir
# Output: CALL|t273|__ffi_libc$neurx_s_cuda_device_count$int$|0
```

### Next Steps
Two options:

1. **Fix S Compiler** (upstream): Report type encoding bug in IR generation
2. **Workaround** (local): Avoid using typed extern declarations by:
   - Wrapping the call in a non-extern function
   - Or switching to a different FFI convention
   - Or working around with type-erasure pattern

Will attempt Option 2 first (workaround), then escalate to compiler if needed.


---

## Phase 4: GPU Execution Verification (IN PROGRESS)

### Objective
Verify that the GPU backend can:
1. Accept inference requests
2. Load model weights into GPU memory
3. Execute CUDA kernels
4. Return predictions

### Current Status
- ✅ GPU backend initializes and listens on 127.0.0.1:18084
- ✅ Health checks succeed
- ⏳ Need to test actual inference request

### Next Steps
1. Send test inference request to backend
2. Verify model tokens are generated
3. Check GPU memory utilization
4. Verify CUDA kernel execution

---

## Phase 5-7: Pending

Model acceptance, performance profiling, and production makefile after Phase 4 succeeds.
