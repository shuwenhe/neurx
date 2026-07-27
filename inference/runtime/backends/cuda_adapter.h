#pragma once

#include "backend_adapter.h"

namespace neurx::inference {

class CudaAdapter final : public BackendAdapter {
 public:
  CudaAdapter(KernelLauncher prefill, KernelLauncher decode);
  ~CudaAdapter() override;
  Backend kind() const override { return Backend::cuda; }
  const char* name() const override { return "nvidia-cuda"; }
  adapter_status initialize(int device_id) override;
  bool ready() const override { return ready_; }
  adapter_status execute(const device_batch& batch) override;
  adapter_status synchronize() override;

 private:
  KernelLauncher prefill_ = nullptr;
  KernelLauncher decode_ = nullptr;
  void* stream_ = nullptr;
  bool ready_ = false;
};

}
