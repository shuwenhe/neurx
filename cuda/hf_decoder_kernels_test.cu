#include "hf_decoder_kernels.cuh"
#include <cuda_runtime.h>
#include <cmath>
#include <cstdio>
#include <vector>
namespace {
bool close(float actual, float expected, float tolerance = 2.0e-5F) {
  return std::fabs(actual - expected) <= tolerance;
}
template <typename T>
T* device_copy(const std::vector<T>& values) {
  T* result = nullptr;
  cudaMalloc(&result, values.size() * sizeof(T));
  cudaMemcpy(result, values.data(), values.size() * sizeof(T), cudaMemcpyHostToDevice);
  return result;
}
std::vector<float> host_copy(float* values, std::size_t count) {
  std::vector<float> result(count);
  cudaMemcpy(result.data(), values, count * sizeof(float), cudaMemcpyDeviceToHost);
  return result;
}
}
int main() {
  int devices = 0;
  if (cudaGetDeviceCount(&devices) != cudaSuccess || devices == 0) {
    std::puts("hf-decoder-cuda-kernels SKIP reason=no-CUDA-device (binary compiled)");
    return 0;
  }
  using namespace neurx::cuda::kernels;
  bool ok = true;
  float* rms_input = device_copy<float>({1.0F, 2.0F, -1.0F, -2.0F});
  float* rms_weight = device_copy<float>({0.5F, 1.5F, 2.0F, 0.25F});
  float* rms_output = nullptr;
  cudaMalloc(&rms_output, 4 * sizeof(float));
  rms_norm<<<1, 1>>>(rms_input, rms_weight, rms_output, 1, 4, 1.0e-6F);
  const auto rms = host_copy(rms_output, 4);
  const float inverse = 1.0F / std::sqrt(2.5F + 1.0e-6F);
  const float rms_expected[] = {0.5F * inverse, 3.0F * inverse,
                                -2.0F * inverse, -0.5F * inverse};
  for (int i = 0; i < 4; ++i) ok = ok && close(rms[i], rms_expected[i]);
  float* rope_values = device_copy<float>({1.0F, 2.0F, 3.0F, 4.0F});
  rope_half<<<1, 2>>>(rope_values, 1, 1, 4, 1, 10000.0F);
  const auto rope = host_copy(rope_values, 4);
  ok = ok && close(rope[0], std::cos(1.0F) - 3.0F * std::sin(1.0F));
  ok = ok && close(rope[2], 3.0F * std::cos(1.0F) + std::sin(1.0F));
  ok = ok && close(rope[1], 2.0F * std::cos(0.01F) - 4.0F * std::sin(0.01F));
  ok = ok && close(rope[3], 4.0F * std::cos(0.01F) + 2.0F * std::sin(0.01F));
  float* query = device_copy<float>({1.0F, 0.0F, 0.0F, 1.0F,
                                      1.0F, 1.0F, 1.0F, -1.0F});
  float* key = device_copy<float>({1.0F, 0.0F, 0.0F, 1.0F});
  float* value = device_copy<float>({2.0F, 3.0F, 5.0F, 7.0F});
  float* attention = nullptr;
  cudaMalloc(&attention, 8 * sizeof(float));
  attention_gqa<<<1, 4>>>(query, key, value, attention, 2, 0, 2, 1, 2);
  const auto result = host_copy(attention, 8);
  ok = ok && close(result[0], 2.0F) && close(result[1], 3.0F);
  ok = ok && close(result[2], 2.0F) && close(result[3], 3.0F);
  void* allocations[] = {rms_input, rms_weight, rms_output, rope_values,
                         query, key, value, attention};
  for (void* pointer : allocations) cudaFree(pointer);
  if (cudaGetLastError() != cudaSuccess || !ok) {
    std::puts("hf-decoder-cuda-kernels FAIL");
    return 1;
  }
  std::puts("hf-decoder-cuda-kernels PASS rmsnorm=1 rope=1 gqa=1");
  return 0;
}
