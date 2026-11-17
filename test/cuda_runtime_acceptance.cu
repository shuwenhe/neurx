#include <cuda.h>
#include <cuda_runtime.h>
#include <cmath>
#include <cstdio>
#include <stdexcept>
#include <string>
#include <vector>

// Exit 77 means BLOCKED, never PASS. No CPU fallback.
static void check(cudaError_t result, const char* operation) {
  if (result != cudaSuccess)
    throw std::runtime_error(std::string(operation) + ": " + cudaGetErrorString(result));
}
__global__ void add(const float* a, const float* b, float* out, int n) {
  const int i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i < n) out[i] = a[i] + b[i];
}
int main() {
  const CUresult driver = cuInit(0);
  if (driver != CUDA_SUCCESS) {
    const char* name = nullptr;
    const char* message = nullptr;
    cuGetErrorName(driver, &name);
    cuGetErrorString(driver, &message);
    std::printf("BLOCKED cuInit: %d %s: %s\n", int(driver), name, message);
    return 77;
  }
  float *a = nullptr, *b = nullptr, *out = nullptr;
  try {
    int count = 0, driver_count = 0, runtime = 0, version = 0;
    if (cuDeviceGetCount(&driver_count) != CUDA_SUCCESS)
      throw std::runtime_error("cuDeviceGetCount failed");
    check(cudaGetDeviceCount(&count), "cudaGetDeviceCount");
    if (count < 1) { std::puts("BLOCKED zero visible GPUs"); return 77; }
    if (count != driver_count) throw std::runtime_error("Driver/runtime enumeration differs");
    check(cudaRuntimeGetVersion(&runtime), "runtime version");
    check(cudaDriverGetVersion(&version), "driver version");
    cudaDeviceProp prop{};
    check(cudaGetDeviceProperties(&prop, 0), "properties");
    std::printf("GPU=%s count=%d SM=%d.%d memory=%zu runtime=%d driver_API=%d\n",
                prop.name, count, prop.major, prop.minor, prop.totalGlobalMem, runtime, version);
    check(cudaSetDevice(0), "select device / primary context");
    check(cudaFree(nullptr), "initialize context");
    constexpr int n = 4099;
    constexpr size_t bytes = n * sizeof(float);
    std::vector<float> x(n), y(n), actual(n), roundtrip(n);
    for (int i = 0; i < n; ++i) { x[i] = (i - 2000) * 0.125f; y[i] = (i % 17) * 0.25f; }
    // Warm up the context before checking free memory after explicit cleanup.
    check(cudaMalloc(&a, bytes), "warmup allocation");
    check(cudaFree(a), "warmup free"); a = nullptr;
    size_t before = 0, total = 0, after = 0;
    check(cudaMemGetInfo(&before, &total), "memory before");
    check(cudaMalloc(&a, bytes), "allocate a");
    check(cudaMalloc(&b, bytes), "allocate b");
    check(cudaMalloc(&out, bytes), "allocate output");
    check(cudaMemcpy(a, x.data(), bytes, cudaMemcpyHostToDevice), "H2D a");
    check(cudaMemcpy(b, y.data(), bytes, cudaMemcpyHostToDevice), "H2D b");
    check(cudaMemcpy(roundtrip.data(), a, bytes, cudaMemcpyDeviceToHost), "D2H roundtrip");
    if (roundtrip != x) throw std::runtime_error("transfer mismatch");
    add<<<(n + 255) / 256, 256>>>(a, b, out, n);
    check(cudaGetLastError(), "kernel launch");
    check(cudaDeviceSynchronize(), "kernel synchronization");
    check(cudaMemcpy(actual.data(), out, bytes, cudaMemcpyDeviceToHost), "D2H output");
    for (int i = 0; i < n; ++i)
      if (!std::isfinite(actual[i]) || actual[i] != x[i] + y[i])
        throw std::runtime_error("independent CPU vector-add mismatch (exact tolerance)");
    check(cudaFree(a), "free a"); a = nullptr;
    check(cudaFree(b), "free b"); b = nullptr;
    check(cudaFree(out), "free output"); out = nullptr;
    check(cudaDeviceSynchronize(), "cleanup synchronization");
    check(cudaMemGetInfo(&after, &total), "memory after");
    std::printf("free_memory_before=%zu after=%zu (other processes may affect this)\n", before, after);
    check(cudaDeviceReset(), "release primary context");
    std::puts("PASS CUDA allocation, transfers, real kernel, CPU reference and explicit cleanup; use compute-sanitizer --leak-check full for leak verification");
    return 0;
  } catch (const std::exception& error) {
    std::fprintf(stderr, "FAIL %s\n", error.what());
    if (a) check(cudaFree(a), "error cleanup a");
    if (b) check(cudaFree(b), "error cleanup b");
    if (out) check(cudaFree(out), "error cleanup out");
    return 1;
  }
}
