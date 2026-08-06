#pragma once
#include "backend_adapter.h"
namespace neurx::inference {
class cuda_adapter final : public backend_adapter {
 public:
  cuda_adapter(kernel_launcher prefill, kernel_launcher decode);
  ~cuda_adapter() override;
  backend kind() const override { return backend::cuda; }
  const char* name() const override { return "nvidia-cuda"; }
  adapter_status initialize(int device_id) override;
  bool ready() const override { return ready_; }
  adapter_status execute(const device_batch& batch) override;
  adapter_status synchronize() override;
 private:
  kernel_launcher prefill_ = nullptr;
  kernel_launcher decode_ = nullptr;
  void* stream_ = nullptr;
  bool ready_ = false;
};
}
