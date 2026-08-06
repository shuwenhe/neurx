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
template <typename function_t>
inline function_t acl_symbol(const char* name) {
  void* library = acl_library();
  return library ? reinterpret_cast<function_t>(dlsym(library, name)) : nullptr;
}
inline bool available() { return acl_library() != nullptr; }
inline error init() {
  using function_t = error (*)(const char*);
  auto function_ptr = acl_symbol<function_t>("aclInit");
  return function_ptr ? function_ptr(nullptr) : -1;
}
inline error finalize() {
  using function_t = error (*)();
  auto function_ptr = acl_symbol<function_t>("aclFinalize");
  return function_ptr ? function_ptr() : -1;
}
inline error set_device(int32_t device) {
  using function_t = error (*)(int32_t);
  auto function_ptr = acl_symbol<function_t>("aclrtSetDevice");
  return function_ptr ? function_ptr(device) : -1;
}
inline error reset_device(int32_t device) {
  using function_t = error (*)(int32_t);
  auto function_ptr = acl_symbol<function_t>("aclrtResetDevice");
  return function_ptr ? function_ptr(device) : -1;
}
inline error create_context(context* context, int32_t device) {
  using function_t = error (*)(context*, int32_t);
  auto function_ptr = acl_symbol<function_t>("aclrtCreateContext");
  return function_ptr ? function_ptr(context, device) : -1;
}
inline error destroy_context(context context) {
  using function_t = error (*)(context);
  auto function_ptr = acl_symbol<function_t>("aclrtDestroyContext");
  return function_ptr ? function_ptr(context) : -1;
}
inline error set_current_context(context context) {
  using function_t = error (*)(context);
  auto function_ptr = acl_symbol<function_t>("aclrtSetCurrentContext");
  return function_ptr ? function_ptr(context) : -1;
}
inline error create_stream(stream* stream) {
  using function_t = error (*)(stream*);
  auto function_ptr = acl_symbol<function_t>("aclrtCreateStream");
  return function_ptr ? function_ptr(stream) : -1;
}
inline error destroy_stream(stream stream) {
  using function_t = error (*)(stream);
  auto function_ptr = acl_symbol<function_t>("aclrtDestroyStream");
  return function_ptr ? function_ptr(stream) : -1;
}
inline error synchronize_stream(stream stream) {
  using function_t = error (*)(stream);
  auto function_ptr = acl_symbol<function_t>("aclrtSynchronizeStream");
  return function_ptr ? function_ptr(stream) : -1;
}
inline error synchronize_device() {
  using function_t = error (*)();
  auto function_ptr = acl_symbol<function_t>("aclrtSynchronizeDevice");
  return function_ptr ? function_ptr() : -1;
}
inline error malloc_device(void** address, std::size_t bytes,
                           malloc_policy policy = malloc_policy::huge_first) {
  using function_t = error (*)(void**, std::size_t, int);
  auto function_ptr = acl_symbol<function_t>("aclrtMalloc");
  return function_ptr ? function_ptr(address, bytes, static_cast<int>(policy)) : -1;
}
inline error free_device(void* address) {
  using function_t = error (*)(void*);
  auto function_ptr = acl_symbol<function_t>("aclrtFree");
  return function_ptr ? function_ptr(address) : -1;
}
inline error malloc_host(void** address, std::size_t bytes) {
  using function_t = error (*)(void**, std::size_t);
  auto function_ptr = acl_symbol<function_t>("aclrtMallocHost");
  return function_ptr ? function_ptr(address, bytes) : -1;
}
inline error free_host(void* address) {
  using function_t = error (*)(void*);
  auto function_ptr = acl_symbol<function_t>("aclrtFreeHost");
  return function_ptr ? function_ptr(address) : -1;
}
inline error memcpy_async(void* destination, std::size_t destination_bytes,
                          const void* source, std::size_t source_bytes,
                          memcpy_kind kind, stream stream) {
  using function_t = error (*)(void*, std::size_t, const void*, std::size_t, int, stream);
  auto function_ptr = acl_symbol<function_t>("aclrtMemcpyAsync");
  return function_ptr ? function_ptr(destination, destination_bytes, source, source_bytes,
                 static_cast<int>(kind), stream)
            : -1;
}
inline error memset_async(void* destination, std::size_t destination_bytes,
                          uint32_t value, std::size_t count, stream stream) {
  using function_t = error (*)(void*, std::size_t, uint32_t, std::size_t, stream);
  auto function_ptr = acl_symbol<function_t>("aclrtMemsetAsync");
  return function_ptr ? function_ptr(destination, destination_bytes, value, count, stream) : -1;
}
inline error create_event(event* event) {
  using function_t = error (*)(event*);
  auto function_ptr = acl_symbol<function_t>("aclrtCreateEvent");
  return function_ptr ? function_ptr(event) : -1;
}
inline error destroy_event(event event) {
  using function_t = error (*)(event);
  auto function_ptr = acl_symbol<function_t>("aclrtDestroyEvent");
  return function_ptr ? function_ptr(event) : -1;
}
inline error record_event(event event, stream stream) {
  using function_t = error (*)(event, stream);
  auto function_ptr = acl_symbol<function_t>("aclrtRecordEvent");
  return function_ptr ? function_ptr(event, stream) : -1;
}
inline error synchronize_event(event event) {
  using function_t = error (*)(event);
  auto function_ptr = acl_symbol<function_t>("aclrtSynchronizeEvent");
  return function_ptr ? function_ptr(event) : -1;
}
inline const char* recent_error() {
  using function_t = const char* (*)();
  auto function_ptr = acl_symbol<function_t>("aclGetRecentErrMsg");
  const char* message = function_ptr ? function_ptr() : nullptr;
  return message ? message : "CANN ACL call failed";
}
}
