#pragma once

#include "../../inference/runtime/backends/backend_adapter.h"
#include "../runtime/acl_runtime.h"

#include <string>

namespace neurx::cann {

// ABI exported by a CANN operator plugin:
//   uint32_t neurx_cann_operator_abi_version();
//   AdapterStatus neurx_cann_prefill(const DeviceBatch&);
//   AdapterStatus neurx_cann_decode(const DeviceBatch&);
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
  using RawLauncher = inference::AdapterStatus (*)(const inference::DeviceBatch&);
  void* handle_ = nullptr;
  RawLauncher prefill_ = nullptr;
  RawLauncher decode_ = nullptr;
};

}  // namespace neurx::cann
