#include "cuda_adapter.h"

#include <cuda_runtime.h>

namespace neurx::inference {

CudaAdapter::CudaAdapter(KernelLauncher prefill, KernelLauncher decode)
    : prefill_(prefill), decode_(decode) {}

CudaAdapter::~CudaAdapter() {
  if (stream_) cudaStreamDestroy(static_cast<cudaStream_t>(stream_));
}

AdapterStatus CudaAdapter::initialize(int device_id) {
  if (cudaSetDevice(device_id) != cudaSuccess) return AdapterStatus::failure("cudaSetDevice failed");
  cudaStream_t stream = nullptr;
  if (cudaStreamCreateWithFlags(&stream, cudaStreamNonBlocking) != cudaSuccess)
    return AdapterStatus::failure("CUDA non-blocking stream creation failed");
  stream_ = stream;
  ready_ = true;
  return AdapterStatus::success();
}

AdapterStatus CudaAdapter::execute(const DeviceBatch& batch) {
  if (!ready_) return AdapterStatus::failure("CUDA adapter is not initialized");
  DeviceBatch launch = batch;
  if (!launch.stream) launch.stream = stream_;
  KernelLauncher launcher = launch.schedule.phase == Phase::prefill ? prefill_ : decode_;
  if (!launcher) return AdapterStatus::failure("CUDA kernel launcher is not bound");
  return launcher(launch);
}

AdapterStatus CudaAdapter::synchronize() {
  if (!ready_) return AdapterStatus::failure("CUDA adapter is not initialized");
  return cudaStreamSynchronize(static_cast<cudaStream_t>(stream_)) == cudaSuccess
             ? AdapterStatus::success()
             : AdapterStatus::failure("CUDA stream synchronization failed");
}

}
