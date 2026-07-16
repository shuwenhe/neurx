#pragma once

#include "backend_adapter.h"

namespace neurx::inference {

// CUDA runtime ownership stays in the .cu implementation. Model-specific
// FlashAttention/GEMM launchers are injected so the control plane is reusable.
class CudaAdapter final : public BackendAdapter {
 public:
  CudaAdapter(KernelLauncher prefill, KernelLauncher decode);
  ~CudaAdapter() override;
  Backend kind() const override { return Backend::cuda; }
  const char* name() const override { return "nvidia-cuda"; }
  AdapterStatus initialize(int device_id) override;
  bool ready() const override { return ready_; }
  AdapterStatus execute(const DeviceBatch& batch) override;
  AdapterStatus synchronize() override;

 private:
  KernelLauncher prefill_ = nullptr;
  KernelLauncher decode_ = nullptr;
  void* stream_ = nullptr;
  bool ready_ = false;
};

}  // namespace neurx::inference
