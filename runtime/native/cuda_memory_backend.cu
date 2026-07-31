#include "cuda_memory_backend.h"
#include "tensor_runtime_c.h"
#include <cuda_runtime.h>
namespace {
void* cuda_allocate(int device_id, size_t bytes, void*) {
  if (cudaSetDevice(device_id) != cudaSuccess) return nullptr;
  void* pointer = nullptr;
  return cudaMalloc(&pointer, bytes == 0 ? 1 : bytes) == cudaSuccess ? pointer : nullptr;
}
void cuda_deallocate(int device_id, void* pointer, void*) {
  if (pointer == nullptr) return;
  if (cudaSetDevice(device_id) == cudaSuccess) cudaFree(pointer);
}
int cuda_copy(int dst_device, void* dst, nx_device_type src_type, int src_device,
              const void* src, size_t bytes, nx_copy_kind kind, void*) {
  if (bytes == 0) return 0;
  cudaError_t status = cudaSuccess;
  switch (kind) {
    case NX_COPY_HOST_TO_DEVICE:
      status = cudaSetDevice(dst_device);
      if (status == cudaSuccess) status = cudaMemcpy(dst, src, bytes, cudaMemcpyHostToDevice);
      break;
    case NX_COPY_DEVICE_TO_HOST:
      if (src_type != NX_DEVICE_CUDA) return -1;
      status = cudaSetDevice(src_device);
      if (status == cudaSuccess) status = cudaMemcpy(dst, src, bytes, cudaMemcpyDeviceToHost);
      break;
    case NX_COPY_DEVICE_TO_DEVICE:
      if (src_type != NX_DEVICE_CUDA) return -1;
      status = cudaMemcpyPeer(dst, dst_device, src, src_device, bytes);
      break;
    case NX_COPY_HOST_TO_HOST:
      return -1;
  }
  return status == cudaSuccess ? 0 : -1;
}
int cuda_set(int device_id, void* pointer, int value, size_t bytes, void*) {
  if (cudaSetDevice(device_id) != cudaSuccess) return -1;
  return cudaMemset(pointer, value, bytes) == cudaSuccess ? 0 : -1;
}
int cuda_synchronize(int device_id, void*) {
  if (cudaSetDevice(device_id) != cudaSuccess) return -1;
  return cudaDeviceSynchronize() == cudaSuccess ? 0 : -1;
}
}
extern "C" int nx_register_cuda_memory_backend(void) {
  nx_memory_ops ops{};
  ops.allocate = cuda_allocate;
  ops.deallocate = cuda_deallocate;
  ops.copy = cuda_copy;
  ops.set = cuda_set;
  ops.synchronize = cuda_synchronize;
  return nx_register_memory_backend(NX_DEVICE_CUDA, ops);
}
