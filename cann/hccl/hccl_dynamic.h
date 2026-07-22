#pragma once

#include <cstddef>
#include <cstdint>
#include <dlfcn.h>

namespace neurx::hccl {

using Result = int;
using Comm = void*;
using Stream = void*;
constexpr Result kSuccess = 0;
constexpr int kFloat32 = 0;
constexpr int kFloat16 = 1;
constexpr int kBfloat16 = 9;
constexpr int kSum = 0;

inline void* library() {
  static void* handle = [] {
    void* loaded = dlopen("libhccl.so", RTLD_NOW | RTLD_LOCAL);
    if (!loaded) loaded = dlopen("libhccl.dylib", RTLD_NOW | RTLD_LOCAL);
    return loaded;
  }();
  return handle;
}

template <typename Function>
inline Function symbol(const char* name) {
  return library() ? reinterpret_cast<Function>(dlsym(library(), name)) : nullptr;
}

inline bool available() { return library() != nullptr; }
inline Result all_reduce(const void* send, void* receive, uint64_t count,
                         int dtype, int operation, Comm comm, Stream stream) {
  using Fn = Result (*)(const void*, void*, uint64_t, int, int, Comm, Stream);
  auto fn = symbol<Fn>("HcclAllReduce");
  return fn ? fn(send, receive, count, dtype, operation, comm, stream) : -1;
}
inline Result all_gather(const void* send, void* receive, uint64_t count,
                         int dtype, Comm comm, Stream stream) {
  using Fn = Result (*)(const void*, void*, uint64_t, int, Comm, Stream);
  auto fn = symbol<Fn>("HcclAllGather");
  return fn ? fn(send, receive, count, dtype, comm, stream) : -1;
}
inline Result reduce_scatter(const void* send, void* receive, uint64_t count,
                             int dtype, int operation, Comm comm, Stream stream) {
  using Fn = Result (*)(const void*, void*, uint64_t, int, int, Comm, Stream);
  auto fn = symbol<Fn>("HcclReduceScatter");
  return fn ? fn(send, receive, count, dtype, operation, comm, stream) : -1;
}
inline Result destroy(Comm comm) {
  using Fn = Result (*)(Comm);
  auto fn = symbol<Fn>("HcclCommDestroy");
  return fn ? fn(comm) : -1;
}

}
