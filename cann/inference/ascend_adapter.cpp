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

adapter_status AscendAdapter::initialize(int device_id) {
  const auto status = session_.initialize(device_id);
  return status.ok ? adapter_status::success() : adapter_status::failure(status.message);
}

adapter_status AscendAdapter::execute(const device_batch& batch) {
  if (!session_.ready()) return adapter_status::failure("Ascend adapter is not initialized");
  device_batch launch = batch;
  if (!launch.stream) launch.stream = session_.stream();
  KernelLauncher launcher = launch.schedule.phase == Phase::prefill ? prefill_ : decode_;
  if (!launcher) return adapter_status::failure("CANN operator launcher is not bound");
  return launcher(launch);
}

adapter_status AscendAdapter::synchronize() {
  const auto status = session_.synchronize();
  return status.ok ? adapter_status::success() : adapter_status::failure(status.message);
}

}
