#pragma once
#include "../../inference/runtime/backends/backend_adapter.h"
#include "../runtime/acl_runtime.h"
namespace neurx::inference {
class ascend_adapter final : public backend_adapter {
 public:
  ascend_adapter(kernel_launcher prefill = {}, kernel_launcher decode = {});
  ~ascend_adapter() override;
  backend kind() const override { return backend::ascend; }
  const char* name() const override { return "ascend-cann"; }
  adapter_status initialize(int device_id) override;
  bool ready() const override { return session_.ready(); }
  adapter_status execute(const device_batch& batch) override;
  adapter_status synchronize() override;
  void bind_launchers(kernel_launcher prefill, kernel_launcher decode);
  cann::device_session& native_session() { return session_; }
  const cann::device_session& native_session() const { return session_; }
 private:
  kernel_launcher prefill_ = nullptr;
  kernel_launcher decode_ = nullptr;
  cann::device_session session_;
};
}
