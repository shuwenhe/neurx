#include "matmul_bridge.h"
#include <cstring>
#include <cstdlib>
#include <dlfcn.h>
#include <atomic>
#include <iostream>

static std::atomic<int> g_cann_probe{-1};

// Try to detect Ascend lib at runtime. Returns 1 if found, 0 if not.
static int probe_cann() {
  int v = g_cann_probe.load(std::memory_order_acquire);
  if (v != -1) return v;
  const char* env = std::getenv("ASCEND_HOME_PATH");
  const char* candidate = nullptr;
  void* handle = nullptr;
  if (env && env[0]) {
    std::string path = std::string(env) + "/lib64/libascendcl.so";
    handle = dlopen(path.c_str(), RTLD_LAZY | RTLD_LOCAL);
    candidate = path.c_str();
  }
  if (!handle) {
    // fallback to system library name
    handle = dlopen("libascendcl.so", RTLD_LAZY | RTLD_LOCAL);
    candidate = "libascendcl.so";
  }
  if (handle) {
    dlclose(handle);
    g_cann_probe.store(1, std::memory_order_release);
    std::cerr << "[matmul_bridge] Ascend runtime found: " << (candidate ? candidate : "(unknown)") << "\n";
    return 1;
  }
  g_cann_probe.store(0, std::memory_order_release);
  std::cerr << "[matmul_bridge] Ascend runtime not found, using CPU fallback" << "\n";
  return 0;
}

extern "C" void __neurx_cann_matmul(const float* a, const float* b, float* out, int m, int k, int n) {
  // If Ascend runtime available, initialize ACL (via dlopen/dlsym) and
  // eventually call the device kernel. For safety we currently fall back
  // to the CPU matmul until a full ACL kernel launcher is implemented.
  int has_cann = probe_cann();

  static std::atomic<int> initialized{0};
  if (has_cann && initialized.load(std::memory_order_acquire) == 0) {
    // Try to dynamically load minimal ACL init/fini symbols. This is a
    // best-effort runtime probe; real kernel invocation requires more
    // thorough integration and is TODO below.
    void* handle = dlopen("libascendcl.so", RTLD_LAZY | RTLD_LOCAL);
    if (!handle) handle = dlopen((std::string(std::getenv("ASCEND_HOME_PATH" ? std::getenv("ASCEND_HOME_PATH") : "" ) + "/lib64/libascendcl.so").c_str(), RTLD_LAZY | RTLD_LOCAL);
    if (handle) {
      using aclInitFn = int(*)(const char*);
      using aclFinalizeFn = int(*)();
      aclInitFn aclInit = (aclInitFn)dlsym(handle, "aclInit");
      aclFinalizeFn aclFinalize = (aclFinalizeFn)dlsym(handle, "aclFinalize");
      if (aclInit) {
        // call aclInit with nullptr for default config
        int rc = aclInit(nullptr);
        if (rc == 0) {
          initialized.store(1, std::memory_order_release);
          std::cerr << "[matmul_bridge] aclInit succeeded\n";
          if (aclFinalize) {
            std::atexit([aclFinalize]{ aclFinalize(); });
          }
        } else {
          std::cerr << "[matmul_bridge] aclInit returned " << rc << ", will use CPU fallback\n";
        }
      } else {
        std::cerr << "[matmul_bridge] aclInit symbol not found, CPU fallback\n";
      }
      dlclose(handle);
    } else {
      std::cerr << "[matmul_bridge] failed to dlopen libascendcl.so\n";
    }
  }

  // TODO: When ACL device/kernel launching is implemented, perform these steps here:
  // 1. Allocate device buffers with aclrtMalloc or aclrtMallocHost as appropriate.
  // 2. Copy `a` and `b` to device memory (aclrtMemcpy).
  // 3. Launch the matmul kernel (aclmdlExecute or custom operator plugin API).
  // 4. Copy result back to `out` (aclrtMemcpy) and free device buffers.
  // 5. Return success status to the S runtime; on failure, fall back to CPU matmul.

  // CPU fallback (naive) - correct by construction
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
