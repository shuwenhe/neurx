#pragma once
#include <cuda_runtime.h>
#include <dlfcn.h>
#include <cstddef>
using nccl_result_t = int;
using nccl_comm_t = void*;
using nccl_data_type_t = int;
using nccl_red_op_t = int;
struct nccl_unique_id { char internal[128]; };
static constexpr nccl_result_t nccl_success = 0;
static constexpr nccl_data_type_t nccl_float = 7;
static constexpr nccl_data_type_t nccl_double = 8;
static constexpr nccl_red_op_t nccl_sum = 0;
inline void* neurx_nccl_symbol(const char* name) {
  static void* handle = nullptr;
  if (!handle) {
    handle = dlopen("libnccl.so.2", RTLD_NOW | RTLD_LOCAL);
    if (!handle) handle = dlopen("libnccl.so", RTLD_NOW | RTLD_LOCAL);
  }
  return handle ? dlsym(handle, name) : nullptr;
}
inline const char* nccl_get_error_string(nccl_result_t) { return "NCCL runtime unavailable or call failed"; }
inline nccl_result_t nccl_get_unique_id(nccl_unique_id* id) {
  using fn = nccl_result_t (*)(nccl_unique_id*);
  auto fn = reinterpret_cast<fn>(neurx_nccl_symbol("ncclGetUniqueId"));
  return fn ? fn(id) : 1;
}
inline nccl_result_t nccl_comm_init_rank(nccl_comm_t* comm, int nranks, nccl_unique_id id, int rank) {
  using fn = nccl_result_t (*)(nccl_comm_t*, int, nccl_unique_id, int);
  auto fn = reinterpret_cast<fn>(neurx_nccl_symbol("ncclCommInitRank"));
  return fn ? fn(comm, nranks, id, rank) : 1;
}
inline nccl_result_t nccl_all_reduce(const void* send, void* recv, std::size_t count,
                                  nccl_data_type_t dtype, nccl_red_op_t op,
                                  nccl_comm_t comm, cuda_stream_t stream) {
  using fn = nccl_result_t (*)(const void*, void*, std::size_t, nccl_data_type_t,
                              nccl_red_op_t, nccl_comm_t, cuda_stream_t);
  auto fn = reinterpret_cast<fn>(neurx_nccl_symbol("ncclAllReduce"));
  return fn ? fn(send, recv, count, dtype, op, comm, stream) : 1;
}
inline nccl_result_t nccl_comm_destroy(nccl_comm_t comm) {
  using fn = nccl_result_t (*)(nccl_comm_t);
  auto fn = reinterpret_cast<fn>(neurx_nccl_symbol("ncclCommDestroy"));
  return fn ? fn(comm) : 1;
}
