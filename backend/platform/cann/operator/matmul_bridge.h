#pragma once
#include <cstddef>
extern "C" {
void __neurx_cann_matmul(const float* a, const float* b, float* out, int m, int k, int n);
}
