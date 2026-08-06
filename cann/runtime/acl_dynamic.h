#pragma once
#include <cstddef>
#include <cstdint>
#include <dlfcn.h>
namespace neurx::cann {
using error = int;
using context = void*;
using stream = void*;
using event = void*;
constexpr error k_success = 0;
enum class memcpy_kind : int {
  host_to_host = 0,
  host_to_device = 1,
  device_to_host = 2,
  device_to_device = 3,
};
enum class malloc_policy : int {
  huge_first = 0,
  huge_only = 1,
  normal_only = 2,
};
inline void* acl_library() {
  static void* library = [] {
    void* handle = dlopen("libascendcl.so", RTLD_NOW | RTLD_LOCAL);
    if (!handle) handle = dlopen("libascendcl.dylib", RTLD_NOW | RTLD_LOCAL);
    return handle;
  }();
  return library;
}
template <typename function>
inline function acl_symbol(const char* name) {
  void* library = acl_library();
  return library ? reinterpret_cast<function>(dlsym(library, name)) : nullptr;
}
inline bool available() { return acl_library() != nullptr; }
inline error init() {
  using fn = error (*)(const char*);
  auto fn = acl_symbol<fn>("aclInit");
  return fn ? fn(nullptr) : -1;
}
inline error finalize() {
  using fn = error (*)();
  auto fn = acl_symbol<fn>("aclFinalize");
  return fn ? fn() : -1;
}
inline error set_device(int32_t device) {
  using fn = error (*)(int32_t);
  auto fn = acl_symbol<fn>("aclrtSetDevice");
  return fn ? fn(device) : -1;
}
inline error reset_device(int32_t device) {
  using fn = error (*)(int32_t);
  auto fn = acl_symbol<fn>("aclrtResetDevice");
  return fn ? fn(device) : -1;
}
inline error create_context(context* context, int32_t device) {
  using fn = error (*)(context*, int32_t);
  auto fn = acl_symbol<fn>("aclrtCreateContext");
  return fn ? fn(context, device) : -1;
}
inline error destroy_context(context context) {
  using fn = error (*)(context);
  auto fn = acl_symbol<fn>("aclrtDestroyContext");
  return fn ? fn(context) : -1;
}
inline error set_current_context(context context) {
  using fn = error (*)(context);
  auto fn = acl_symbol<fn>("aclrtSetCurrentContext");
  return fn ? fn(context) : -1;
}
inline error create_stream(stream* stream) {
  using fn = error (*)(stream*);
  auto fn = acl_symbol<fn>("aclrtCreateStream");
  return fn ? fn(stream) : -1;
}
inline error destroy_stream(stream stream) {
  using fn = error (*)(stream);
  auto fn = acl_symbol<fn>("aclrtDestroyStream");
  return fn ? fn(stream) : -1;
}
inline error synchronize_stream(stream stream) {
  using fn = error (*)(stream);
  auto fn = acl_symbol<fn>("aclrtSynchronizeStream");
  return fn ? fn(stream) : -1;
}
inline error synchronize_device() {
  using fn = error (*)();
  auto fn = acl_symbol<fn>("aclrtSynchronizeDevice");
  return fn ? fn() : -1;
}
inline error malloc_device(void** address, std::size_t bytes,
                           malloc_policy policy = malloc_policy::huge_first) {
  using fn = error (*)(void**, std::size_t, int);
  auto fn = acl_symbol<fn>("aclrtMalloc");
  return fn ? fn(address, bytes, static_cast<int>(policy)) : -1;
}
inline error free_device(void* address) {
  using fn = error (*)(void*);
  auto fn = acl_symbol<fn>("aclrtFree");
  return fn ? fn(address) : -1;
}
inline error malloc_host(void** address, std::size_t bytes) {
  using fn = error (*)(void**, std::size_t);
  auto fn = acl_symbol<fn>("aclrtMallocHost");
  return fn ? fn(address, bytes) : -1;
}
inline error free_host(void* address) {
  using fn = error (*)(void*);
  auto fn = acl_symbol<fn>("aclrtFreeHost");
  return fn ? fn(address) : -1;
}
inline error memcpy_async(void* destination, std::size_t destination_bytes,
                          const void* source, std::size_t source_bytes,
                          memcpy_kind kind, stream stream) {
  using fn = error (*)(void*, std::size_t, const void*, std::size_t, int, stream);
  auto fn = acl_symbol<fn>("aclrtMemcpyAsync");
  return fn ? fn(destination, destination_bytes, source, source_bytes,
                 static_cast<int>(kind), stream)
            : -1;
}
inline error memset_async(void* destination, std::size_t destination_bytes,
                          uint32_t value, std::size_t count, stream stream) {
  using fn = error (*)(void*, std::size_t, uint32_t, std::size_t, stream);
  auto fn = acl_symbol<fn>("aclrtMemsetAsync");
  return fn ? fn(destination, destination_bytes, value, count, stream) : -1;
}
inline error create_event(event* event) {
  using fn = error (*)(event*);
  auto fn = acl_symbol<fn>("aclrtCreateEvent");
  return fn ? fn(event) : -1;
}
inline error destroy_event(event event) {
  using fn = error (*)(event);
  auto fn = acl_symbol<fn>("aclrtDestroyEvent");
  return fn ? fn(event) : -1;
}
inline error record_event(event event, stream stream) {
  using fn = error (*)(event, stream);
  auto fn = acl_symbol<fn>("aclrtRecordEvent");
  return fn ? fn(event, stream) : -1;
}
inline error synchronize_event(event event) {
  using fn = error (*)(event);
  auto fn = acl_symbol<fn>("aclrtSynchronizeEvent");
  return fn ? fn(event) : -1;
}
inline const char* recent_error() {
  using fn = const char* (*)();
  auto fn = acl_symbol<fn>("aclGetRecentErrMsg");
  const char* message = fn ? fn() : nullptr;
  return message ? message : "CANN ACL call failed";
}
}
