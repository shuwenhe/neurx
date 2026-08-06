#pragma once
#include "../../inference/runtime/backends/backend_adapter.h"
#include "operator_abi.h"
#include "../runtime/acl_runtime.h"
#include <string>
namespace neurx::cann {
class operator_library {
 public:
  operator_library() = default;
  ~operator_library();
  operator_library(const operator_library&) = delete;
  operator_library& operator=(const operator_library&) = delete;
  status load(const std::string& path);
  void unload();
  bool loaded() const { return handle_ != nullptr; }
  inference::kernel_launcher prefill_launcher() const;
  inference::kernel_launcher decode_launcher() const;
 private:
  using raw_launcher = neurx_cann_operator_status (*)(
      const inference::device_batch&);
  void* handle_ = nullptr;
  raw_launcher prefill_ = nullptr;
  raw_launcher decode_ = nullptr;
};
}
