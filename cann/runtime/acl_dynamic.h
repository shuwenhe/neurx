#pragma once
#include <cstddef>
#include <cstdint>
#include <dlfcn.h>
namespace neurx::cann {
using Error = int;
using Context = void*;
using Stream = void*;
using Event = void*;
constexpr Error kSuccess = 0;
enum class MemcpyKind : int {
  host_to_host = 0,
  host_to_device = 1,
  device_to_host = 2,
  device_to_device = 3,
};
enum class MallocPolicy : int {
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
inline Error reset_device(int32_t device) {
  using Fn = Error (*)(int32_t);
  auto fn = acl_symbol<Fn>("aclrtResetDevice");
  return fn ? fn(device) : -1;
}
inline Error create_context(Context* context, int32_t device) {
  using Fn = Error (*)(Context*, int32_t);
  auto fn = acl_symbol<Fn>("aclrtCreateContext");
  return fn ? fn(context, device) : -1;
}
inline Error destroy_context(Context context) {
  using Fn = Error (*)(Context);
  auto fn = acl_symbol<Fn>("aclrtDestroyContext");
  return fn ? fn(context) : -1;
}
inline Error set_current_context(Context context) {
  using Fn = Error (*)(Context);
  auto fn = acl_symbol<Fn>("aclrtSetCurrentContext");
  return fn ? fn(context) : -1;
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
inline Error synchronize_device() {
  using Fn = Error (*)();
  auto fn = acl_symbol<Fn>("aclrtSynchronizeDevice");
  return fn ? fn() : -1;
}
inline Error malloc_device(void** address, std::size_t bytes,
                           MallocPolicy policy = MallocPolicy::huge_first) {
  using Fn = Error (*)(void**, std::size_t, int);
  auto fn = acl_symbol<Fn>("aclrtMalloc");
  return fn ? fn(address, bytes, static_cast<int>(policy)) : -1;
}
inline Error free_device(void* address) {
  using Fn = Error (*)(void*);
  auto fn = acl_symbol<Fn>("aclrtFree");
  return fn ? fn(address) : -1;
}
inline Error malloc_host(void** address, std::size_t bytes) {
  using Fn = Error (*)(void**, std::size_t);
  auto fn = acl_symbol<Fn>("aclrtMallocHost");
  return fn ? fn(address, bytes) : -1;
}
inline Error free_host(void* address) {
  using Fn = Error (*)(void*);
  auto fn = acl_symbol<Fn>("aclrtFreeHost");
  return fn ? fn(address) : -1;
}
inline Error memcpy_async(void* destination, std::size_t destination_bytes,
                          const void* source, std::size_t source_bytes,
                          MemcpyKind kind, Stream stream) {
  using Fn = Error (*)(void*, std::size_t, const void*, std::size_t, int, Stream);
  auto fn = acl_symbol<Fn>("aclrtMemcpyAsync");
  return fn ? fn(destination, destination_bytes, source, source_bytes,
                 static_cast<int>(kind), stream)
            : -1;
}
inline Error memset_async(void* destination, std::size_t destination_bytes,
                          uint32_t value, std::size_t count, Stream stream) {
  using Fn = Error (*)(void*, std::size_t, uint32_t, std::size_t, Stream);
  auto fn = acl_symbol<Fn>("aclrtMemsetAsync");
  return fn ? fn(destination, destination_bytes, value, count, stream) : -1;
}
inline Error create_event(Event* event) {
  using Fn = Error (*)(Event*);
  auto fn = acl_symbol<Fn>("aclrtCreateEvent");
  return fn ? fn(event) : -1;
}
inline Error destroy_event(Event event) {
  using Fn = Error (*)(Event);
  auto fn = acl_symbol<Fn>("aclrtDestroyEvent");
  return fn ? fn(event) : -1;
}
inline Error record_event(Event event, Stream stream) {
  using Fn = Error (*)(Event, Stream);
  auto fn = acl_symbol<Fn>("aclrtRecordEvent");
  return fn ? fn(event, stream) : -1;
}
inline Error synchronize_event(Event event) {
  using Fn = Error (*)(Event);
  auto fn = acl_symbol<Fn>("aclrtSynchronizeEvent");
  return fn ? fn(event) : -1;
}
inline const char* recent_error() {
  using Fn = const char* (*)();
  auto fn = acl_symbol<Fn>("aclGetRecentErrMsg");
  const char* message = fn ? fn() : nullptr;
  return message ? message : "CANN ACL call failed";
}
}
