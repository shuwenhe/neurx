#pragma once
#include <cstddef>
#include <cstdint>
#include <dlfcn.h>
namespace neurx::hccl {
using result = int;
using comm = void*;
using stream = void*;
constexpr result k_success = 0;
constexpr int k_float32 = 0;
constexpr int k_float16 = 1;
constexpr int k_bfloat16 = 9;
constexpr int k_sum = 0;
inline void* library() {
  static void* handle = [] {
    void* loaded = dlopen("libhccl.so", RTLD_NOW | RTLD_LOCAL);
    if (!loaded) loaded = dlopen("libhccl.dylib", RTLD_NOW | RTLD_LOCAL);
    return loaded;
  }();
  return handle;
}
template <typename function>
inline function symbol(const char* name) {
  return library() ? reinterpret_cast<function>(dlsym(library(), name)) : nullptr;
}
inline bool available() { return library() != nullptr; }
inline result all_reduce(const void* send, void* receive, uint64_t count,
                         int dtype, int operation, comm comm, stream stream) {
  using fn = result (*)(const void*, void*, uint64_t, int, int, comm, stream);
  auto fn = symbol<fn>("HcclAllReduce");
  return fn ? fn(send, receive, count, dtype, operation, comm, stream) : -1;
}
inline result all_gather(const void* send, void* receive, uint64_t count,
                         int dtype, comm comm, stream stream) {
  using fn = result (*)(const void*, void*, uint64_t, int, comm, stream);
  auto fn = symbol<fn>("HcclAllGather");
  return fn ? fn(send, receive, count, dtype, comm, stream) : -1;
}
inline result reduce_scatter(const void* send, void* receive, uint64_t count,
                             int dtype, int operation, comm comm, stream stream) {
  using fn = result (*)(const void*, void*, uint64_t, int, int, comm, stream);
  auto fn = symbol<fn>("HcclReduceScatter");
  return fn ? fn(send, receive, count, dtype, operation, comm, stream) : -1;
}
inline result destroy(comm comm) {
  using fn = result (*)(comm);
  auto fn = symbol<fn>("HcclCommDestroy");
  return fn ? fn(comm) : -1;
}
}
