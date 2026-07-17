#pragma once

#include <cstdint>
#include <dlfcn.h>

namespace neurx::cann {

using Error = int;
using Stream = void*;
constexpr Error kSuccess = 0;

inline void* acl_library() {
  static void* library = [] {
    void* handle = dlopen("libascendcl.so", RTLD_NOW | RTLD_LOCAL);
    if (!handle) handle = dlopen("libascendcl.dylib", RTLD_NOW | RTLD_LOCAL);
    return handle;
  }();
  return library;
}

template <typename Function>
inline Function acl_symbol(const char* name) {
  void* library = acl_library();
  return library ? reinterpret_cast<Function>(dlsym(library, name)) : nullptr;
}

inline bool available() { return acl_library() != nullptr; }
inline Error init() {
  using Fn = Error (*)(const char*);
  auto fn = acl_symbol<Fn>("aclInit");
  return fn ? fn(nullptr) : -1;
}
inline Error finalize() {
  using Fn = Error (*)();
  auto fn = acl_symbol<Fn>("aclFinalize");
  return fn ? fn() : -1;
}
inline Error set_device(int32_t device) {
  using Fn = Error (*)(int32_t);
  auto fn = acl_symbol<Fn>("aclrtSetDevice");
  return fn ? fn(device) : -1;
}
inline Error create_stream(Stream* stream) {
  using Fn = Error (*)(Stream*);
  auto fn = acl_symbol<Fn>("aclrtCreateStream");
  return fn ? fn(stream) : -1;
}
inline Error destroy_stream(Stream stream) {
  using Fn = Error (*)(Stream);
  auto fn = acl_symbol<Fn>("aclrtDestroyStream");
  return fn ? fn(stream) : -1;
}
inline Error synchronize_stream(Stream stream) {
  using Fn = Error (*)(Stream);
  auto fn = acl_symbol<Fn>("aclrtSynchronizeStream");
  return fn ? fn(stream) : -1;
}

}  // namespace neurx::cann
