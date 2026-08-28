#include "../../backend/api/collective_abi.h"

#include <dlfcn.h>
#include <array>
#include <cmath>
#include <cstring>
#include <iostream>
#include <thread>

namespace {
struct cuda_api {
  void* library = nullptr;
  int (*get_device_count)(int*) = nullptr;
  int (*set_device)(int) = nullptr;
  int (*malloc_device)(void**, size_t) = nullptr;
  int (*free_device)(void*) = nullptr;
  int (*copy)(void*, const void*, size_t, int) = nullptr;
  int (*stream_create)(void**) = nullptr;
  int (*stream_destroy)(void*) = nullptr;
};

template <typename T>
T load_symbol(void* library, const char* name) {
  return reinterpret_cast<T>(dlsym(library, name));
}

bool load_cuda(cuda_api* api) {
  const char* candidates[] = {"libcudart.so", "libcudart.so.12", "libcudart.so.11.0"};
  for (const char* candidate : candidates) {
    if (!api->library) api->library = dlopen(candidate, RTLD_NOW | RTLD_LOCAL);
  }
  if (!api->library) return false;
  api->get_device_count = load_symbol<decltype(api->get_device_count)>(api->library, "cudaGetDeviceCount");
  api->set_device = load_symbol<decltype(api->set_device)>(api->library, "cudaSetDevice");
  api->malloc_device = load_symbol<decltype(api->malloc_device)>(api->library, "cudaMalloc");
  api->free_device = load_symbol<decltype(api->free_device)>(api->library, "cudaFree");
  api->copy = load_symbol<decltype(api->copy)>(api->library, "cudaMemcpy");
  api->stream_create = load_symbol<decltype(api->stream_create)>(api->library, "cudaStreamCreate");
  api->stream_destroy = load_symbol<decltype(api->stream_destroy)>(api->library, "cudaStreamDestroy");
  return api->get_device_count && api->set_device && api->malloc_device && api->free_device &&
         api->copy && api->stream_create && api->stream_destroy;
}

struct rank_result {
  std::array<float, 4> output{};
  std::string error;
};

void run_rank(cuda_api* cuda, int rank, const char* unique_id, rank_result* result) {
  constexpr int cuda_memcpy_host_to_device = 1;
  constexpr int cuda_memcpy_device_to_host = 2;
  const std::array<float, 4> input = rank == 0
      ? std::array<float, 4>{1.0f, 2.0f, 3.0f, 4.0f}
      : std::array<float, 4>{10.0f, 20.0f, 30.0f, 40.0f};
  void* send = nullptr;
  void* receive = nullptr;
  void* stream = nullptr;
  int communicator = 0;
  auto fail = [&](const std::string& message) { result->error = "rank " + std::to_string(rank) + ": " + message; };

  if (cuda->set_device(rank) != 0 ||
      cuda->malloc_device(&send, sizeof(input)) != 0 ||
      cuda->malloc_device(&receive, sizeof(input)) != 0 ||
      cuda->stream_create(&stream) != 0 ||
      cuda->copy(send, input.data(), sizeof(input), cuda_memcpy_host_to_device) != 0) {
    fail("CUDA allocation or H2D copy failed");
    goto cleanup;
  }
  communicator = neurx_collective_init_rank("nccl", rank, 2, rank, unique_id);
  if (communicator <= 0) {
    fail(neurx_collective_last_error(0));
    goto cleanup;
  }
  if (neurx_collective_all_reduce(communicator,
          reinterpret_cast<uint64_t>(send), reinterpret_cast<uint64_t>(receive),
          input.size(), NEURX_COLLECTIVE_FLOAT32, NEURX_COLLECTIVE_SUM,
          reinterpret_cast<uint64_t>(stream)) != 0 ||
      neurx_collective_synchronize(communicator, reinterpret_cast<uint64_t>(stream)) != 0 ||
      neurx_collective_async_error(communicator) != 0) {
    fail(neurx_collective_last_error(communicator));
    goto cleanup;
  }
  if (cuda->copy(result->output.data(), receive, sizeof(input), cuda_memcpy_device_to_host) != 0) {
    fail("D2H verification copy failed");
  }

cleanup:
  if (communicator > 0 && neurx_collective_destroy(communicator) != 0 && result->error.empty())
    fail(neurx_collective_last_error(communicator));
  if (stream) cuda->stream_destroy(stream);
  if (receive) cuda->free_device(receive);
  if (send) cuda->free_device(send);
}
}  // namespace

int main() {
  cuda_api cuda;
  if (!load_cuda(&cuda)) {
    std::cout << "SKIP G-C3: CUDA runtime unavailable\n";
    return 77;
  }
  int device_count = 0;
  if (cuda.get_device_count(&device_count) != 0 || device_count < 2) {
    std::cout << "SKIP G-C3: requires at least 2 NVIDIA GPUs; detected " << device_count << '\n';
    return 77;
  }
  if (neurx_collective_probe("nccl") != 1) {
    std::cout << "SKIP G-C3: " << neurx_collective_last_error(0) << '\n';
    return 77;
  }
  char unique_id[NEURX_COLLECTIVE_UNIQUE_ID_HEX_CAPACITY]{};
  if (neurx_collective_get_unique_id("nccl", unique_id, sizeof(unique_id)) != 0) {
    std::cerr << "FAIL G-C2: " << neurx_collective_last_error(0) << '\n';
    return 1;
  }
  rank_result ranks[2];
  std::thread rank0(run_rank, &cuda, 0, unique_id, &ranks[0]);
  std::thread rank1(run_rank, &cuda, 1, unique_id, &ranks[1]);
  rank0.join();
  rank1.join();
  for (const rank_result& rank : ranks) {
    if (!rank.error.empty()) {
      std::cerr << "FAIL G-C3: " << rank.error << '\n';
      return 1;
    }
  }
  const std::array<float, 4> expected{11.0f, 22.0f, 33.0f, 44.0f};
  for (int rank = 0; rank < 2; ++rank) {
    for (size_t i = 0; i < expected.size(); ++i) {
      if (std::fabs(ranks[rank].output[i] - expected[i]) > 1e-5f) {
        std::cerr << "FAIL G-C3: rank " << rank << " element " << i
                  << " expected " << expected[i] << " got " << ranks[rank].output[i] << '\n';
        return 1;
      }
    }
  }
  std::cout << "PASS G-C2/G-C3: 2-GPU NCCL device AllReduce SUM = [11,22,33,44] on both ranks\n";
  return 0;
}
