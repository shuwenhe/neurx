#include "../api/collective_abi.h"

#include <dlfcn.h>
#include <array>
#include <cstring>
#include <map>
#include <mutex>
#include <string>
#include <unordered_map>

namespace {
using nccl_result = int;
using nccl_comm = void*;
using nccl_stream = void*;
struct nccl_unique_id { char bytes[128]; };

struct nccl_api {
  void* library = nullptr;
  void* runtime_library = nullptr;
  int (*set_device)(int) = nullptr;
  int (*stream_synchronize)(void*) = nullptr;
  nccl_result (*get_unique_id)(nccl_unique_id*) = nullptr;
  nccl_result (*init_rank)(nccl_comm*, int, nccl_unique_id, int) = nullptr;
  nccl_result (*destroy)(nccl_comm) = nullptr;
  nccl_result (*all_reduce)(const void*, void*, size_t, int, int, nccl_comm, nccl_stream) = nullptr;
  nccl_result (*all_gather)(const void*, void*, size_t, int, nccl_comm, nccl_stream) = nullptr;
  nccl_result (*reduce_scatter)(const void*, void*, size_t, int, int, nccl_comm, nccl_stream) = nullptr;
  nccl_result (*send)(const void*, size_t, int, int, nccl_comm, nccl_stream) = nullptr;
  nccl_result (*recv)(void*, size_t, int, int, nccl_comm, nccl_stream) = nullptr;
  nccl_result (*async_error)(nccl_comm, nccl_result*) = nullptr;
  const char* (*error_string)(nccl_result) = nullptr;
};

struct communicator_record {
  nccl_api* api = nullptr;
  nccl_comm vendor = nullptr;
  int rank = 0;
  int world_size = 0;
};

std::mutex state_mutex;
std::map<std::string, nccl_api> apis;
std::unordered_map<int, communicator_record> communicators;
int next_communicator = 1;
thread_local std::string last_error;

int fail(const std::string& message) {
  last_error = message;
  return -1;
}

template <typename T>
T symbol(void* library, const char* name) {
  return reinterpret_cast<T>(dlsym(library, name));
}

nccl_api* load_api(const char* backend) {
  if (!backend || (std::strcmp(backend, "nccl") != 0 && std::strcmp(backend, "rccl") != 0)) {
    last_error = backend && std::strcmp(backend, "hccl") == 0
        ? "HCCL adapter is not implemented" : "unsupported collective backend";
    return nullptr;
  }
  auto found = apis.find(backend);
  if (found != apis.end()) return found->second.library ? &found->second : nullptr;
  nccl_api api;
  const char* candidates[3] = {nullptr, nullptr, nullptr};
  if (std::strcmp(backend, "rccl") == 0) {
    candidates[0] = "librccl.so"; candidates[1] = "librccl.so.1"; candidates[2] = "libnccl.so.2";
  } else {
    candidates[0] = "libnccl.so.2"; candidates[1] = "libnccl.so";
  }
  for (const char* candidate : candidates) {
    if (candidate && !api.library) api.library = dlopen(candidate, RTLD_NOW | RTLD_LOCAL);
  }
  if (!api.library) {
    const char* detail = dlerror();
    last_error = std::string("collective library unavailable: ") + (detail ? detail : backend);
    apis.emplace(backend, api);
    return nullptr;
  }
  api.get_unique_id = symbol<decltype(api.get_unique_id)>(api.library, "ncclGetUniqueId");
  api.init_rank = symbol<decltype(api.init_rank)>(api.library, "ncclCommInitRank");
  api.destroy = symbol<decltype(api.destroy)>(api.library, "ncclCommDestroy");
  api.all_reduce = symbol<decltype(api.all_reduce)>(api.library, "ncclAllReduce");
  api.all_gather = symbol<decltype(api.all_gather)>(api.library, "ncclAllGather");
  api.reduce_scatter = symbol<decltype(api.reduce_scatter)>(api.library, "ncclReduceScatter");
  api.send = symbol<decltype(api.send)>(api.library, "ncclSend");
  api.recv = symbol<decltype(api.recv)>(api.library, "ncclRecv");
  api.async_error = symbol<decltype(api.async_error)>(api.library, "ncclCommGetAsyncError");
  api.error_string = symbol<decltype(api.error_string)>(api.library, "ncclGetErrorString");
  const char* runtime_candidates[3] = {nullptr, nullptr, nullptr};
  if (std::strcmp(backend, "rccl") == 0) {
    runtime_candidates[0] = "libamdhip64.so"; runtime_candidates[1] = "libamdhip64.so.6";
  } else {
    runtime_candidates[0] = "libcudart.so"; runtime_candidates[1] = "libcudart.so.12";
    runtime_candidates[2] = "libcudart.so.11.0";
  }
  for (const char* candidate : runtime_candidates) {
    if (candidate && !api.runtime_library) api.runtime_library = dlopen(candidate, RTLD_NOW | RTLD_LOCAL);
  }
  if (api.runtime_library) {
    const char* set_device_name = std::strcmp(backend, "rccl") == 0 ? "hipSetDevice" : "cudaSetDevice";
    const char* synchronize_name = std::strcmp(backend, "rccl") == 0 ? "hipStreamSynchronize" : "cudaStreamSynchronize";
    api.set_device = symbol<decltype(api.set_device)>(api.runtime_library, set_device_name);
    api.stream_synchronize = symbol<decltype(api.stream_synchronize)>(api.runtime_library, synchronize_name);
  }
  if (!api.get_unique_id || !api.init_rank || !api.destroy || !api.all_reduce ||
      !api.all_gather || !api.reduce_scatter || !api.send || !api.recv || !api.async_error ||
      !api.set_device || !api.stream_synchronize) {
    last_error = "collective or device runtime library is missing required ABI symbols";
    dlclose(api.library);
    if (api.runtime_library) dlclose(api.runtime_library);
    api.library = nullptr;
    api.runtime_library = nullptr;
  }
  auto inserted = apis.emplace(backend, api);
  return inserted.first->second.library ? &inserted.first->second : nullptr;
}

std::string vendor_error(nccl_api* api, nccl_result result) {
  const char* detail = api && api->error_string ? api->error_string(result) : nullptr;
  return detail ? detail : "vendor collective call failed with code " + std::to_string(result);
}

int dtype_value(int dtype) {
  switch (dtype) {
    case NEURX_COLLECTIVE_FLOAT16: return 6;
    case NEURX_COLLECTIVE_FLOAT32: return 7;
    case NEURX_COLLECTIVE_INT32: return 2;
    case NEURX_COLLECTIVE_INT64: return 4;
    case NEURX_COLLECTIVE_BFLOAT16: return 9;
    default: return -1;
  }
}

int op_value(int operation) {
  return operation >= NEURX_COLLECTIVE_SUM && operation <= NEURX_COLLECTIVE_AVERAGE
      ? operation : -1;
}

communicator_record* lookup(int handle) {
  auto found = communicators.find(handle);
  return found == communicators.end() ? nullptr : &found->second;
}

bool copy_record(int handle, communicator_record* output) {
  std::lock_guard<std::mutex> lock(state_mutex);
  communicator_record* record = lookup(handle);
  if (!record) return false;
  *output = *record;
  return true;
}

bool decode_hex(const char* input, nccl_unique_id* output) {
  if (!input || std::strlen(input) != sizeof(output->bytes) * 2) return false;
  auto nibble = [](char value) -> int {
    if (value >= '0' && value <= '9') return value - '0';
    if (value >= 'a' && value <= 'f') return value - 'a' + 10;
    if (value >= 'A' && value <= 'F') return value - 'A' + 10;
    return -1;
  };
  for (size_t i = 0; i < sizeof(output->bytes); ++i) {
    int high = nibble(input[i * 2]); int low = nibble(input[i * 2 + 1]);
    if (high < 0 || low < 0) return false;
    output->bytes[i] = static_cast<char>((high << 4) | low);
  }
  return true;
}
}

extern "C" int neurx_collective_probe(const char* backend) {
  std::lock_guard<std::mutex> lock(state_mutex);
  return load_api(backend) ? 1 : 0;
}

extern "C" int neurx_collective_get_unique_id(const char* backend, char* output, int capacity) {
  std::lock_guard<std::mutex> lock(state_mutex);
  nccl_api* api = load_api(backend);
  if (!api || !output || capacity < NEURX_COLLECTIVE_UNIQUE_ID_HEX_CAPACITY) return fail("invalid unique id request or backend unavailable");
  nccl_unique_id id{};
  nccl_result result = api->get_unique_id(&id);
  if (result != 0) return fail(vendor_error(api, result));
  static const char hex[] = "0123456789abcdef";
  for (size_t i = 0; i < sizeof(id.bytes); ++i) {
    unsigned char value = static_cast<unsigned char>(id.bytes[i]);
    output[i * 2] = hex[value >> 4]; output[i * 2 + 1] = hex[value & 15];
  }
  output[sizeof(id.bytes) * 2] = '\0';
  return 0;
}

extern "C" int neurx_collective_init_rank(const char* backend, int rank, int world_size,
                                            int device_id, const char* unique_id_hex) {
  nccl_api* api = nullptr;
  {
    std::lock_guard<std::mutex> lock(state_mutex);
    api = load_api(backend);
  }
  nccl_unique_id id{};
  if (!api || rank < 0 || rank >= world_size || world_size <= 0 || !decode_hex(unique_id_hex, &id))
    return fail("invalid communicator initialization request");
  int device_result = api->set_device(device_id);
  if (device_result != 0) return fail("device selection failed with code " + std::to_string(device_result));
  nccl_comm vendor = nullptr;
  nccl_result result = api->init_rank(&vendor, world_size, id, rank);
  if (result != 0 || !vendor) return fail(vendor_error(api, result));
  std::lock_guard<std::mutex> lock(state_mutex);
  int handle = next_communicator++;
  communicators.emplace(handle, communicator_record{api, vendor, rank, world_size});
  return handle;
}

extern "C" int neurx_collective_destroy(int handle) {
  communicator_record comm;
  if (!copy_record(handle, &comm)) return fail("invalid communicator");
  nccl_result result = comm.api->destroy(comm.vendor);
  if (result != 0) return fail(vendor_error(comm.api, result));
  std::lock_guard<std::mutex> lock(state_mutex);
  communicators.erase(handle);
  return 0;
}

#define NEURX_COMM_CALL(name, expression) \
  communicator_record comm; \
  if (!copy_record(communicator, &comm) || count < 0 || !send_buffer || !receive_buffer) return fail("invalid " name " request"); \
  int vendor_dtype = dtype_value(dtype); \
  if (vendor_dtype < 0) return fail("unsupported collective dtype"); \
  nccl_result result = (expression); \
  return result == 0 ? 0 : fail(vendor_error(comm.api, result))

extern "C" int neurx_collective_all_reduce(int communicator, uint64_t send_buffer, uint64_t receive_buffer,
                                             int64_t count, int dtype, int operation, uint64_t stream) {
  int vendor_op = op_value(operation); if (vendor_op < 0) return fail("unsupported reduction operation");
  NEURX_COMM_CALL("all_reduce", comm.api->all_reduce(reinterpret_cast<void*>(send_buffer), reinterpret_cast<void*>(receive_buffer), static_cast<size_t>(count), vendor_dtype, vendor_op, comm.vendor, reinterpret_cast<void*>(stream)));
}
extern "C" int neurx_collective_all_gather(int communicator, uint64_t send_buffer, uint64_t receive_buffer,
                                             int64_t count, int dtype, uint64_t stream) {
  NEURX_COMM_CALL("all_gather", comm.api->all_gather(reinterpret_cast<void*>(send_buffer), reinterpret_cast<void*>(receive_buffer), static_cast<size_t>(count), vendor_dtype, comm.vendor, reinterpret_cast<void*>(stream)));
}
extern "C" int neurx_collective_reduce_scatter(int communicator, uint64_t send_buffer, uint64_t receive_buffer,
                                                 int64_t count, int dtype, int operation, uint64_t stream) {
  int vendor_op = op_value(operation); if (vendor_op < 0) return fail("unsupported reduction operation");
  NEURX_COMM_CALL("reduce_scatter", comm.api->reduce_scatter(reinterpret_cast<void*>(send_buffer), reinterpret_cast<void*>(receive_buffer), static_cast<size_t>(count), vendor_dtype, vendor_op, comm.vendor, reinterpret_cast<void*>(stream)));
}

extern "C" int neurx_collective_send(int communicator, uint64_t buffer, int64_t count, int dtype, int peer, uint64_t stream) {
  communicator_record comm;
  int vendor_dtype = dtype_value(dtype);
  if (!copy_record(communicator, &comm) || !buffer || count < 0 || peer < 0 || peer >= comm.world_size || vendor_dtype < 0) return fail("invalid send request");
  nccl_result result = comm.api->send(reinterpret_cast<void*>(buffer), static_cast<size_t>(count), vendor_dtype, peer, comm.vendor, reinterpret_cast<void*>(stream));
  return result == 0 ? 0 : fail(vendor_error(comm.api, result));
}
extern "C" int neurx_collective_recv(int communicator, uint64_t buffer, int64_t count, int dtype, int peer, uint64_t stream) {
  communicator_record comm;
  int vendor_dtype = dtype_value(dtype);
  if (!copy_record(communicator, &comm) || !buffer || count < 0 || peer < 0 || peer >= comm.world_size || vendor_dtype < 0) return fail("invalid recv request");
  nccl_result result = comm.api->recv(reinterpret_cast<void*>(buffer), static_cast<size_t>(count), vendor_dtype, peer, comm.vendor, reinterpret_cast<void*>(stream));
  return result == 0 ? 0 : fail(vendor_error(comm.api, result));
}
extern "C" int neurx_collective_synchronize(int communicator, uint64_t stream) {
  communicator_record comm;
  if (!copy_record(communicator, &comm)) return fail("invalid communicator");
  int result = comm.api->stream_synchronize(reinterpret_cast<void*>(stream));
  return result == 0 ? 0 : fail("device stream synchronization failed with code " + std::to_string(result));
}
extern "C" int neurx_collective_async_error(int communicator) {
  communicator_record comm;
  if (!copy_record(communicator, &comm)) return fail("invalid communicator");
  nccl_result async_result = 0; nccl_result result = comm.api->async_error(comm.vendor, &async_result);
  if (result != 0) return fail(vendor_error(comm.api, result));
  return async_result;
}
extern "C" const char* neurx_collective_last_error(int) { return last_error.c_str(); }
