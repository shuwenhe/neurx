#include "aclnn_matmul_wrapper.h"
#include "../runtime/acl_dynamic.h"
#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <dlfcn.h>
#include <iostream>
#include <vector>
#include <cstring>

using namespace neurx::cann;

// Simple wrapper: try to initialize ACL runtime and allocate/copy buffers.
// If a real ACLNN matmul symbol exists we will attempt to call it (best-effort).
// Otherwise the function falls back to performing CPU matmul and returns 0.

namespace {
static std::atomic<int> g_initialized{0};
static std::atomic<int> last_run_device{0};
}

static void cpu_matmul(const float* a, const float* b, float* out, int m,
                       int k, int n) {
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

int neurx_aclnn_matmul(const float* a, const float* b, float* out, int m,
                       int k, int n) {
  if (!available()) {
    // ACL not present -- CPU fallback
    cpu_matmul(a, b, out, m, k, n);
    return 0;
  }

  // Ensure ACL is initialized once
  if (g_initialized.load(std::memory_order_acquire) == 0) {
    if (init() != kSuccess) {
      std::cerr << "[aclnn_matmul_wrapper] aclInit failed, using CPU fallback\n";
      cpu_matmul(a, b, out, m, k, n);
      return 0;
    }
    g_initialized.store(1, std::memory_order_release);
    std::cerr << "[aclnn_matmul_wrapper] aclInit succeeded\n";
  }

  // Try to perform an actual aclnnMatmul invocation. We'll create aclTensors
  // for inputs/outputs, query workspace via `aclnnMatmulGetWorkspaceSize`,
  // allocate workspace, then call `aclnnMatmul`. We use dlsym against the
  // ACL library so the code can be built on machines without SDK.

  bool device_executed = false;

  // Create aclTensor objects using dynamic symbol lookup for `aclCreateTensor`.
  using aclCreateTensorFn = void* (*)(const int64_t*, int, int, const int64_t*,
                                     size_t, int, const int64_t*, int, void*);
  using aclDestroyTensorFn = void (*)(void*);

  auto create_tensor_sym = reinterpret_cast<aclCreateTensorFn>(
      dlsym(acl_library(), "aclCreateTensor"));
  auto destroy_tensor_sym = reinterpret_cast<aclDestroyTensorFn>(
      dlsym(acl_library(), "aclDestroyTensor"));

  if (create_tensor_sym && destroy_tensor_sym) {
    // Prepare dimensions and strides
    int64_t a_dims[2] = {m, k};
    int64_t b_dims[2] = {k, n};
    int64_t y_dims[2] = {m, n};
    int64_t a_strides[2] = {k, 1};
    int64_t b_strides[2] = {n, 1};
    int64_t y_strides[2] = {n, 1};

    void* a_tensor = create_tensor_sym(a_dims, 2, /*dtype*/ 0 /*ACL_FLOAT?*/,
                                       a_strides, 0, /*format*/ 0 /*ACL_FORMAT_ND*/,
                                       a_dims, 2, const_cast<float*>(a));
    void* b_tensor = create_tensor_sym(b_dims, 2, /*dtype*/ 0, b_strides, 0,
                                       0, b_dims, 2, const_cast<float*>(b));
    void* y_tensor = create_tensor_sym(y_dims, 2, /*dtype*/ 0, y_strides, 0,
                                       0, y_dims, 2, out);

    if (a_tensor && b_tensor && y_tensor) {
      // Attempt to find aclnn get-workspace and execute symbols
      using GetWFn = int (*)(void*, void*, void*, uint64_t*, void**);
      using ExecFn = int (*)(void*, uint64_t, void*, void*);

      GetWFn getw = reinterpret_cast<GetWFn>(
          dlsym(acl_library(), "aclnnMatmulGetWorkspaceSize"));
      ExecFn exec = reinterpret_cast<ExecFn>(
          dlsym(acl_library(), "aclnnMatmul"));

      if (getw && exec) {
        uint64_t workspace_bytes = 0;
        void* executor = nullptr;
        // Call get-workspace. ABI may differ; if this call fails we fall
        // back to CPU.
        int gw = getw(a_tensor, b_tensor, y_tensor, &workspace_bytes,
                     &executor);
        if (gw == 0) {
          void* workspace_dev = nullptr;
          if (workspace_bytes > 0) {
            if (malloc_device(&workspace_dev, workspace_bytes) != kSuccess) {
              std::cerr << "[aclnn_matmul_wrapper] workspace alloc failed\n";
            }
          }

          // Create stream and run
          Stream stream = nullptr;
          if (create_stream(&stream) == kSuccess) {
            int rc = exec(workspace_dev, workspace_bytes, executor, stream);
            synchronize_stream(stream);
            destroy_stream(stream);
            if (workspace_dev) free_device(workspace_dev);
            if (rc == 0) {
              device_executed = true;
            } else {
              std::cerr << "[aclnn_matmul_wrapper] aclnnMatmul returned " << rc << "\n";
            }
          } else {
            std::cerr << "[aclnn_matmul_wrapper] create_stream failed\n";
            if (workspace_dev) free_device(workspace_dev);
          }
        } else {
          std::cerr << "[aclnn_matmul_wrapper] aclnnMatmulGetWorkspaceSize returned " << gw << "\n";
        }
      } else {
        std::cerr << "[aclnn_matmul_wrapper] aclnnMatmul symbols not found\n";
      }

      destroy_tensor_sym(a_tensor);
      destroy_tensor_sym(b_tensor);
      destroy_tensor_sym(y_tensor);
    } else {
      std::cerr << "[aclnn_matmul_wrapper] aclCreateTensor failed; falling back\n";
      if (a_tensor && destroy_tensor_sym) destroy_tensor_sym(a_tensor);
      if (b_tensor && destroy_tensor_sym) destroy_tensor_sym(b_tensor);
      if (y_tensor && destroy_tensor_sym) destroy_tensor_sym(y_tensor);
    }
  } else {
    std::cerr << "[aclnn_matmul_wrapper] aclCreateTensor symbol missing; cannot run aclnn\n";
  }

  if (device_executed) {
    // copy device-out to host if necessary. We assume operator wrote into
    // the user-provided host pointer via acl tensor; if not, more copies
    // would be required. Mark success.
    last_run_device.store(1, std::memory_order_release);
    return 0;
  }

  // If we reached here, the device operator could not be launched; fall
  // back to CPU implementation.
  // CPU fallback path (naive)
  last_run_device.store(0, std::memory_order_release);
  cpu_matmul(a, b, out, m, k, n);
  return 0;
}

int neurx_aclnn_last_run_device() { return last_run_device.load(std::memory_order_acquire); }
