#pragma once

#include <cstddef>

extern "C" {
// Attempt to run a MatMul via Ascend ACL/ACLNN. Returns 0 on success,
// non-zero on failure (caller should fall back to CPU matmul).
int neurx_aclnn_matmul(const float* a, const float* b, float* out, int m, int k, int n);
// Returns 1 if the last call executed the operator on-device, 0 otherwise.
int neurx_aclnn_last_run_device();
}
