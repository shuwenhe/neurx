#include "operator_library.h"

#include <cstdint>
#include <dlfcn.h>

namespace neurx::cann {

OperatorLibrary::~OperatorLibrary() { unload(); }

Status OperatorLibrary::load(const std::string& path) {
  unload();
  if (path.empty()) return Status::failure("CANN operator library path is empty");
  handle_ = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
  if (!handle_) {
    const char* error = dlerror();
    return Status::failure(std::string("cannot load CANN operator library: ") +
                           (error ? error : "unknown loader error"));
  }

  using AbiVersion = uint32_t (*)();
  auto version = reinterpret_cast<AbiVersion>(
      dlsym(handle_, "neurx_cann_operator_abi_version"));
  prefill_ = reinterpret_cast<RawLauncher>(dlsym(handle_, "neurx_cann_prefill"));
  decode_ = reinterpret_cast<RawLauncher>(dlsym(handle_, "neurx_cann_decode"));
  if (!version || version() != 1 || !prefill_ || !decode_) {
    unload();
    return Status::failure(
        "CANN operator library must export ABI v1 prefill and decode launchers");
  }
  return Status::success();
}

void OperatorLibrary::unload() {
  prefill_ = nullptr;
  decode_ = nullptr;
  if (handle_) dlclose(handle_);
  handle_ = nullptr;
}

inference::KernelLauncher OperatorLibrary::prefill_launcher() const {
  return prefill_;
}

inference::KernelLauncher OperatorLibrary::decode_launcher() const {
  return decode_;
}

}  // namespace neurx::cann
