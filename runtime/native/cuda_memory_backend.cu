#include "cuda_memory_backend.h"
#include "tensor_runtime_c.h"
#include <cuda_runtime.h>
namespace {
void* cuda_allocate(int device_id, size_t bytes, void*) {
  if (cuda_set_device(device_id) != cuda_success) return nullptr;
  void* pointer = nullptr;
  return cuda_malloc(&pointer, bytes == 0 ? 1 : bytes) == cuda_success ? pointer : nullptr;
}
void cuda_deallocate(int device_id, void* pointer, void*) {
  if (pointer == nullptr) return;
  if (cuda_set_device(device_id) == cuda_success) cuda_free(pointer);
}
int cuda_copy(int dst_device, void* dst, nx_device_type src_type, int src_device,
              const void* src, size_t bytes, nx_copy_kind kind, void*) {
  if (bytes == 0) return 0;
  cuda_error_t status = cuda_success;
  switch (kind) {
    case NX_COPY_HOST_TO_DEVICE:
      status = cuda_set_device(dst_device);
      if (status == cuda_success) status = cuda_memcpy(dst, src, bytes, cuda_memcpy_host_to_device);
      break;
    case NX_COPY_DEVICE_TO_HOST:
      if (src_type != NX_DEVICE_CUDA) return -1;
      status = cuda_set_device(src_device);
      if (status == cuda_success) status = cuda_memcpy(dst, src, bytes, cuda_memcpy_device_to_host);
      break;
    case NX_COPY_DEVICE_TO_DEVICE:
      if (src_type != NX_DEVICE_CUDA) return -1;
      status = cuda_memcpy_peer(dst, dst_device, src, src_device, bytes);
      break;
    case NX_COPY_HOST_TO_HOST:
      return -1;
  }
  return status == cuda_success ? 0 : -1;
}
int cuda_set(int device_id, void* pointer, int value, size_t bytes, void*) {
  if (cuda_set_device(device_id) != cuda_success) return -1;
  return cuda_memset(pointer, value, bytes) == cuda_success ? 0 : -1;
}
int cuda_synchronize(int device_id, void*) {
  if (cuda_set_device(device_id) != cuda_success) return -1;
  return cuda_device_synchronize() == cuda_success ? 0 : -1;
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
