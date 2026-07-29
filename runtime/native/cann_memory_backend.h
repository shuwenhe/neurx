#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Registers the dynamically loaded Ascend ACL memory backend. The function
// succeeds without ACL installed; allocation then reports a runtime error.
int nx_register_cann_memory_backend(void);

#ifdef __cplusplus
}
#endif
