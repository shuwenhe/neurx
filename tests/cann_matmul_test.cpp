#include <iostream>
#include <vector>
#include <cmath>
#include "../cann/operators/aclnn_matmul_wrapper.h"

extern "C" void __neurx_cann_matmul(const float* a, const float* b, float* out, int m, int k, int n);

static void cpu_matmul(const float* a, const float* b, float* out, int m, int k, int n) {
  for (int i = 0; i < m * n; ++i) out[i] = 0.0f;
  for (int i = 0; i < m; ++i) {
    for (int p = 0; p < k; ++p) {
      float av = a[i * k + p];
      for (int j = 0; j < n; ++j) out[i * n + j] += av * b[p * n + j];
    }
  }
}

int main() {
  int m = 4, k = 3, n = 5;
  std::vector<float> A(m * k), B(k * n), Out(m * n), Ref(m * n);
  for (int i = 0; i < m * k; ++i) A[i] = (float)((i % 7) - 3);
  for (int i = 0; i < k * n; ++i) B[i] = (float)((i % 5) - 2);

  cpu_matmul(A.data(), B.data(), Ref.data(), m, k, n);

  // call bridge
  // Try to invoke the ACLNN wrapper first (it will fall back to CPU).
  extern int neurx_aclnn_matmul(const float*, const float*, float*, int,int,int);
  neurx_aclnn_matmul(A.data(), B.data(), Out.data(), m, k, n);

  // compare
  float maxdiff = 0.0f;
  for (int i = 0; i < m * n; ++i) {
    float d = std::fabs(Out[i] - Ref[i]);
    if (d > maxdiff) maxdiff = d;
  }
  if (maxdiff > 1e-5f) {
    std::cerr << "MATMUL TEST FAILED maxdiff=" << maxdiff << "\n";
    return 2;
  }
  // Verify operator executed on-device (910B4) when available.
  extern int neurx_aclnn_last_run_device();
  int used = neurx_aclnn_last_run_device();
  if (!used) {
    std::cerr << "MATMUL TEST FAILED: did not execute on device\n";
    return 3;
  }
  std::cout << "MATMUL TEST OK (device)\n";
  return 0;
}
