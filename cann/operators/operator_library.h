#pragma once

#include "../../inference/runtime/backends/backend_adapter.h"
#include "operator_abi.h"
#include "../runtime/acl_runtime.h"

#include <string>

namespace neurx::cann {

// ABI exported by a CANN operator plugin:
//   uint32_t neurx_cann_operator_abi_version();
//   NeurxCannOperatorStatus neurx_cann_prefill(const DeviceBatch&);
//   NeurxCannOperatorStatus neurx_cann_decode(const DeviceBatch&);
class OperatorLibrary {
 public:
  OperatorLibrary() = default;
  ~OperatorLibrary();
  OperatorLibrary(const OperatorLibrary&) = delete;
  OperatorLibrary& operator=(const OperatorLibrary&) = delete;

  Status load(const std::string& path);
  void unload();
  bool loaded() const { return handle_ != nullptr; }
  inference::KernelLauncher prefill_launcher() const;
  inference::KernelLauncher decode_launcher() const;

 private:
  using RawLauncher = NeurxCannOperatorStatus (*)(
      const inference::DeviceBatch&);
  void* handle_ = nullptr;
  RawLauncher prefill_ = nullptr;
  RawLauncher decode_ = nullptr;
};

}  // namespace neurx::cann
