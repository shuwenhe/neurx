#include "matmul_bridge.h"
#include <cstring>

extern "C" void __neurx_cann_matmul(const float* a, const float* b, float* out, int m, int k, int n) {
  // Placeholder implementation: naive CPU matmul.
  // Replace this with CANN/ACL calls to invoke Ascend native kernels.
  // Initialize output
  int mn = m * n;
  for (int i = 0; i < mn; ++i) out[i] = 0.0f;

  for (int i = 0; i < m; ++i) {
    for (int p = 0; p < k; ++p) {
      float av = a[i * k + p];
      const float* brow = b + (p * n);
      float* orow = out + (i * n);
      for (int j = 0; j < n; ++j) {
        orow[j] += av * brow[j];
      }
    }
  }
}
