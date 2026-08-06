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
template <typename function_t>
inline function_t symbol(const char* name) {
  return library() ? reinterpret_cast<function_t>(dlsym(library(), name)) : nullptr;
}
inline bool available() { return library() != nullptr; }
inline result all_reduce(const void* send, void* receive, uint64_t count,
                         int dtype, int operation, comm comm, stream stream) {
  using function_t = result (*)(const void*, void*, uint64_t, int, int, comm, stream);
  auto function_ptr = symbol<function_t>("HcclAllReduce");
  return function_ptr ? function_ptr(send, receive, count, dtype, operation, comm, stream) : -1;
}
inline result all_gather(const void* send, void* receive, uint64_t count,
                         int dtype, comm comm, stream stream) {
  using function_t = result (*)(const void*, void*, uint64_t, int, comm, stream);
  auto function_ptr = symbol<function_t>("HcclAllGather");
  return function_ptr ? function_ptr(send, receive, count, dtype, comm, stream) : -1;
}
inline result reduce_scatter(const void* send, void* receive, uint64_t count,
                             int dtype, int operation, comm comm, stream stream) {
  using function_t = result (*)(const void*, void*, uint64_t, int, int, comm, stream);
  auto function_ptr = symbol<function_t>("HcclReduceScatter");
  return function_ptr ? function_ptr(send, receive, count, dtype, operation, comm, stream) : -1;
}
inline result destroy(comm comm) {
  using function_t = result (*)(comm);
  auto function_ptr = symbol<function_t>("HcclCommDestroy");
  return function_ptr ? function_ptr(comm) : -1;
}
}
