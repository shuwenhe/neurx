#include "operator_library.h"

#include <cstdint>
#include <dlfcn.h>

namespace neurx::cann {

OperatorLibrary::~OperatorLibrary() { unload(); }

status OperatorLibrary::load(const std::string& path) {
  unload();
  if (path.empty()) return status::failure("CANN operator library path is empty");
  handle_ = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
  if (!handle_) {
    const char* error = dlerror();
    return status::failure(std::string("cannot load CANN operator library: ") +
                           (error ? error : "unknown loader error"));
  }

  using AbiVersion = uint32_t (*)();
  auto version = reinterpret_cast<AbiVersion>(
      dlsym(handle_, "neurx_cann_operator_abi_version"));
  prefill_ = reinterpret_cast<RawLauncher>(dlsym(handle_, "neurx_cann_prefill"));
  decode_ = reinterpret_cast<RawLauncher>(dlsym(handle_, "neurx_cann_decode"));
  if (!version || version() != 2 || !prefill_ || !decode_) {
    unload();
    return status::failure(
        "CANN operator library must export ABI v2 prefill and decode launchers");
  }
  return status::success();
}

void OperatorLibrary::unload() {
  prefill_ = nullptr;
  decode_ = nullptr;
  if (handle_) dlclose(handle_);
  handle_ = nullptr;
}

inference::KernelLauncher OperatorLibrary::prefill_launcher() const {
  const RawLauncher launcher = prefill_;
  return [launcher](const inference::device_batch& batch) {
    if (!launcher) {
      return inference::adapter_status::failure(
          "CANN prefill launcher is unavailable");
    }
    const neurx_cann_operator_status status = launcher(batch);
    return status.code == 0
               ? inference::adapter_status::success()
               : inference::adapter_status::failure(
                     status.message ? status.message
                                    : "CANN prefill operator failed");
  };
}

inference::KernelLauncher OperatorLibrary::decode_launcher() const {
  const RawLauncher launcher = decode_;
  return [launcher](const inference::device_batch& batch) {
    if (!launcher) {
      return inference::adapter_status::failure(
          "CANN decode launcher is unavailable");
    }
    const neurx_cann_operator_status status = launcher(batch);
    return status.code == 0
               ? inference::adapter_status::success()
               : inference::adapter_status::failure(
                     status.message ? status.message
                                    : "CANN decode operator failed");
  };
}

}
