#pragma once

#include "backend_adapter.h"

namespace neurx::inference {

class AscendAdapter final : public BackendAdapter {
 public:
  AscendAdapter(KernelLauncher prefill, KernelLauncher decode);
  ~AscendAdapter() override;
  Backend kind() const override { return Backend::ascend; }
  const char* name() const override { return "ascend-cann"; }
  AdapterStatus initialize(int device_id) override;
  bool ready() const override { return ready_; }
  AdapterStatus execute(const DeviceBatch& batch) override;
  AdapterStatus synchronize() override;

 private:
  KernelLauncher prefill_ = nullptr;
  KernelLauncher decode_ = nullptr;
  void* stream_ = nullptr;
  bool acl_initialized_ = false;
  bool ready_ = false;
};

}  // namespace neurx::inference
