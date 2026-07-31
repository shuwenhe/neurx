#pragma once
#include <cuda_runtime.h>
#include <dlfcn.h>
#include <cstddef>
using ncclResult_t = int;
using ncclComm_t = void*;
using ncclDataType_t = int;
using ncclRedOp_t = int;
struct ncclUniqueId { char internal[128]; };
static constexpr ncclResult_t ncclSuccess = 0;
static constexpr ncclDataType_t ncclFloat = 7;
static constexpr ncclDataType_t ncclDouble = 8;
static constexpr ncclRedOp_t ncclSum = 0;
inline void* neurx_nccl_symbol(const char* name) {
  static void* handle = nullptr;
  if (!handle) {
    handle = dlopen("libnccl.so.2", RTLD_NOW | RTLD_LOCAL);
    if (!handle) handle = dlopen("libnccl.so", RTLD_NOW | RTLD_LOCAL);
  }
  return handle ? dlsym(handle, name) : nullptr;
}
inline const char* ncclGetErrorString(ncclResult_t) { return "NCCL runtime unavailable or call failed"; }
inline ncclResult_t ncclGetUniqueId(ncclUniqueId* id) {
  using Fn = ncclResult_t (*)(ncclUniqueId*);
  auto fn = reinterpret_cast<Fn>(neurx_nccl_symbol("ncclGetUniqueId"));
  return fn ? fn(id) : 1;
}
inline ncclResult_t ncclCommInitRank(ncclComm_t* comm, int nranks, ncclUniqueId id, int rank) {
  using Fn = ncclResult_t (*)(ncclComm_t*, int, ncclUniqueId, int);
  auto fn = reinterpret_cast<Fn>(neurx_nccl_symbol("ncclCommInitRank"));
  return fn ? fn(comm, nranks, id, rank) : 1;
}
inline ncclResult_t ncclAllReduce(const void* send, void* recv, std::size_t count,
                                  ncclDataType_t dtype, ncclRedOp_t op,
                                  ncclComm_t comm, cudaStream_t stream) {
  using Fn = ncclResult_t (*)(const void*, void*, std::size_t, ncclDataType_t,
                              ncclRedOp_t, ncclComm_t, cudaStream_t);
  auto fn = reinterpret_cast<Fn>(neurx_nccl_symbol("ncclAllReduce"));
  return fn ? fn(send, recv, count, dtype, op, comm, stream) : 1;
}
inline ncclResult_t ncclCommDestroy(ncclComm_t comm) {
  using Fn = ncclResult_t (*)(ncclComm_t);
  auto fn = reinterpret_cast<Fn>(neurx_nccl_symbol("ncclCommDestroy"));
  return fn ? fn(comm) : 1;
}
