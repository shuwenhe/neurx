#include "hf_decoder_cuda.h"

#include <cuda_runtime.h>

#include <cstdio>
#include <exception>
#include <vector>

void print_logits(const char* name, const std::vector<float>& logits) {
  std::printf("%s %zu", name, logits.size());
  for (float value : logits) std::printf(" %.9g", value);
  std::printf("\n");
}

int main(int argc, char** argv) {
  if (argc < 4) return 2;
  int devices = 0;
  if (cudaGetDeviceCount(&devices) != cudaSuccess || devices == 0) {
    std::puts("SKIP no-CUDA-device");
    return 0;
  }
  try {
    std::vector<int32_t> ids;
    for (int index = 2; index < argc; ++index) ids.push_back(std::stoi(argv[index]));
    neurx::cuda::HfDecoderCuda model(argv[1]);
    neurx::cuda::HfCudaKvCache full_cache;
    const auto full = model.prefill(ids, &full_cache);
    const int32_t last = ids.back();
    ids.pop_back();
    neurx::cuda::HfCudaKvCache incremental_cache;
    (void)model.prefill(ids, &incremental_cache);
    const auto incremental = model.decode(last, &incremental_cache);
    print_logits("full", full);
    print_logits("cached", incremental);
    std::printf("cache_length %zu\n", incremental_cache.length());
    return 0;
  } catch (const std::exception& error) {
    std::fprintf(stderr, "%s\n", error.what());
    return 1;
  }
}
