#include "cuda_adapter.h"
#include <cuda_runtime.h>
namespace neurx::inference {
cuda_adapter::cuda_adapter(kernel_launcher prefill, kernel_launcher decode)
    : prefill_(prefill), decode_(decode) {}
cuda_adapter::~cuda_adapter() {
  if (stream_) cuda_stream_destroy(static_cast<cuda_stream_t>(stream_));
}
adapter_status cuda_adapter::initialize(int device_id) {
  if (cuda_set_device(device_id) != cuda_success) return adapter_status::failure("cudaSetDevice failed");
  cuda_stream_t stream = nullptr;
  if (cuda_stream_create_with_flags(&stream, cuda_stream_non_blocking) != cuda_success)
    return adapter_status::failure("CUDA non-blocking stream creation failed");
  stream_ = stream;
  ready_ = true;
  return adapter_status::success();
}
adapter_status cuda_adapter::execute(const device_batch& batch) {
  if (!ready_) return adapter_status::failure("CUDA adapter is not initialized");
  device_batch launch = batch;
  if (!launch.stream) launch.stream = stream_;
  kernel_launcher launcher = launch.schedule.phase == phase::prefill ? prefill_ : decode_;
  if (!launcher) return adapter_status::failure("CUDA kernel launcher is not bound");
  return launcher(launch);
}
adapter_status cuda_adapter::synchronize() {
  if (!ready_) return adapter_status::failure("CUDA adapter is not initialized");
  return cuda_stream_synchronize(static_cast<cuda_stream_t>(stream_)) == cuda_success
             ? adapter_status::success()
             : adapter_status::failure("CUDA stream synchronization failed");
}
}
