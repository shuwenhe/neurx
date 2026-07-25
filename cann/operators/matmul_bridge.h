#pragma once

#include <cstddef>

extern "C" {
// Minimal C ABI for a matmul bridge.
// a: pointer to A data (row-major, m x k)
// b: pointer to B data (row-major, k x n)
// out: pointer to output buffer (row-major, m x n) already allocated by caller
// m,k,n: dimensions
void __neurx_cann_matmul(const float* a, const float* b, float* out, int m, int k, int n);
}
