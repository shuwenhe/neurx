# NeurX GPU Inference — Production Acceptance Plan

**Created:** 2026-11-10 16:13 UTC  
**Status:** Phase 1 Complete - Phase 2 Starting  
**Branch:** main  
**Model:** Qwen2.5-0.5B-Instruct @ `/home/shuwen/model/`

## Current State

### Git Status
- Repository: clean (no staged changes)
- Recent commits: GPU compilation fixes applied
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
- ⚠️ GPU Backend Native: Fails at runtime with "unknown arg value: int"

---

## Phase 2: Runtime Error Analysis

### Error Report
```
error[5] at 0:0: unknown arg value: int
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
[S Runtime] Parse arguments (FAILS HERE)
  ↓
Unknown arg value: int
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

