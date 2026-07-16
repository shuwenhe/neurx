#include "ascend_adapter.h"

#include "../../../arch/cann/runtime/acl_dynamic.h"

namespace neurx::inference {

AscendAdapter::AscendAdapter(KernelLauncher prefill, KernelLauncher decode)
    : prefill_(prefill), decode_(decode) {}

AscendAdapter::~AscendAdapter() {
  if (stream_) cann::destroy_stream(stream_);
  if (acl_initialized_) cann::finalize();
}

AdapterStatus AscendAdapter::initialize(int device_id) {
  if (!cann::available()) return AdapterStatus::failure("CANN ACL runtime library is unavailable");
  if (cann::init() != cann::kSuccess) return AdapterStatus::failure("aclInit failed");
  acl_initialized_ = true;
  if (cann::set_device(device_id) != cann::kSuccess) return AdapterStatus::failure("aclrtSetDevice failed");
  if (cann::create_stream(&stream_) != cann::kSuccess)
    return AdapterStatus::failure("ACL stream creation failed");
  ready_ = true;
  return AdapterStatus::success();
}

AdapterStatus AscendAdapter::execute(const DeviceBatch& batch) {
  if (!ready_) return AdapterStatus::failure("Ascend adapter is not initialized");
  DeviceBatch launch = batch;
  if (!launch.stream) launch.stream = stream_;
  KernelLauncher launcher = launch.schedule.phase == Phase::prefill ? prefill_ : decode_;
  if (!launcher) return AdapterStatus::failure("CANN operator launcher is not bound");
  return launcher(launch);
}

AdapterStatus AscendAdapter::synchronize() {
  if (!ready_) return AdapterStatus::failure("Ascend adapter is not initialized");
  return cann::synchronize_stream(stream_) == cann::kSuccess
             ? AdapterStatus::success()
             : AdapterStatus::failure("ACL stream synchronization failed");
}

}  // namespace neurx::inference
