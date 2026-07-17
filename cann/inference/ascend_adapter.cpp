#include "ascend_adapter.h"

#include <utility>

namespace neurx::inference {

AscendAdapter::AscendAdapter(KernelLauncher prefill, KernelLauncher decode)
    : prefill_(prefill), decode_(decode) {}

AscendAdapter::~AscendAdapter() = default;

void AscendAdapter::bind_launchers(KernelLauncher prefill,
                                   KernelLauncher decode) {
  prefill_ = std::move(prefill);
  decode_ = std::move(decode);
}

AdapterStatus AscendAdapter::initialize(int device_id) {
  const auto status = session_.initialize(device_id);
  return status.ok ? AdapterStatus::success() : AdapterStatus::failure(status.message);
}

AdapterStatus AscendAdapter::execute(const DeviceBatch& batch) {
  if (!session_.ready()) return AdapterStatus::failure("Ascend adapter is not initialized");
  DeviceBatch launch = batch;
  if (!launch.stream) launch.stream = session_.stream();
  KernelLauncher launcher = launch.schedule.phase == Phase::prefill ? prefill_ : decode_;
  if (!launcher) return AdapterStatus::failure("CANN operator launcher is not bound");
  return launcher(launch);
}

AdapterStatus AscendAdapter::synchronize() {
  const auto status = session_.synchronize();
  return status.ok ? AdapterStatus::success() : AdapterStatus::failure(status.message);
}

}  // namespace neurx::inference
