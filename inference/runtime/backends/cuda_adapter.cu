#include "cuda_adapter.h"
#include <cuda_runtime.h>
namespace neurx::inference {
CudaAdapter::CudaAdapter(KernelLauncher prefill, KernelLauncher decode)
    : prefill_(prefill), decode_(decode) {}
CudaAdapter::~CudaAdapter() {
  if (stream_) cudaStreamDestroy(static_cast<cudaStream_t>(stream_));
}
adapter_status CudaAdapter::initialize(int device_id) {
  if (cudaSetDevice(device_id) != cudaSuccess) return adapter_status::failure("cudaSetDevice failed");
  cudaStream_t stream = nullptr;
  if (cudaStreamCreateWithFlags(&stream, cudaStreamNonBlocking) != cudaSuccess)
    return adapter_status::failure("CUDA non-blocking stream creation failed");
  stream_ = stream;
  ready_ = true;
  return adapter_status::success();
}
adapter_status CudaAdapter::execute(const device_batch& batch) {
  if (!ready_) return adapter_status::failure("CUDA adapter is not initialized");
  device_batch launch = batch;
  if (!launch.stream) launch.stream = stream_;
  KernelLauncher launcher = launch.schedule.phase == Phase::prefill ? prefill_ : decode_;
  if (!launcher) return adapter_status::failure("CUDA kernel launcher is not bound");
  return launcher(launch);
}
adapter_status CudaAdapter::synchronize() {
  if (!ready_) return adapter_status::failure("CUDA adapter is not initialized");
  return cudaStreamSynchronize(static_cast<cudaStream_t>(stream_)) == cudaSuccess
             ? adapter_status::success()
             : adapter_status::failure("CUDA stream synchronization failed");
}
}
