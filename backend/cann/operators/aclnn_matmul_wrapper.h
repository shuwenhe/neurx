#pragma once
#include <cstddef>
extern "C" {
int neurx_aclnn_matmul(const float* a, const float* b, float* out, int m, int k, int n);
int neurx_aclnn_last_run_device();
}
