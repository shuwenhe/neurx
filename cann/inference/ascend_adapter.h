#pragma once
#include "../../inference/runtime/backends/backend_adapter.h"
#include "../runtime/acl_runtime.h"
namespace neurx::inference {
class AscendAdapter final : public BackendAdapter {
 public:
  AscendAdapter(KernelLauncher prefill = {}, KernelLauncher decode = {});
  ~AscendAdapter() override;
  Backend kind() const override { return Backend::ascend; }
  const char* name() const override { return "ascend-cann"; }
  adapter_status initialize(int device_id) override;
  bool ready() const override { return session_.ready(); }
  adapter_status execute(const device_batch& batch) override;
  adapter_status synchronize() override;
  void bind_launchers(KernelLauncher prefill, KernelLauncher decode);
  cann::DeviceSession& native_session() { return session_; }
  const cann::DeviceSession& native_session() const { return session_; }
 private:
  KernelLauncher prefill_ = nullptr;
  KernelLauncher decode_ = nullptr;
  cann::DeviceSession session_;
};
}
