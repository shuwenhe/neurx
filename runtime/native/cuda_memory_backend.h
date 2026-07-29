#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Registers CUDA allocation/copy/synchronization callbacks with the unified
// tensor runtime. Registration does not select a device or allocate memory.
int nx_register_cuda_memory_backend(void);

#ifdef __cplusplus
}
#endif
