#include "../api/device_plugin_abi.h"
#include "runtime/acl_dynamic.h"
#include "operators/kernel_dispatch_abi.h"

#include <mutex>
#include <string>
#include <unordered_map>
#include <sstream>
#include <vector>
#include <cstdlib>

namespace {
using namespace neurx::cann;
struct buffer_record { void* address; int bytes; bool host; };
struct context_record {
  int device = 0; context native = nullptr; int next = 1;
  std::unordered_map<int, buffer_record> buffer;
  std::unordered_map<int, stream> stream_map;
  struct operation_record { std::string kind; std::string descriptor; };
  std::unordered_map<int, operation_record> operation;
  std::string error;
};
std::mutex state_mutex;
std::unordered_map<int, context_record> state;
int next_context = 1;
thread_local std::string global_error;
context_record* get_context(int handle) {
  auto found = state.find(handle); return found == state.end() ? nullptr : &found->second;
}
std::unordered_map<std::string, std::string> parse_fields(const char* text) {
  std::unordered_map<std::string, std::string> result; std::stringstream stream(text ? text : ""); std::string item;
  while (std::getline(stream, item, ';')) { std::size_t equal = item.find('='); if (equal != std::string::npos) result[item.substr(0, equal)] = item.substr(equal + 1); }
  return result;
}
neurx_cann_kernel_launch_v1_fn kernel_dispatch() {
  static neurx_cann_kernel_launch_v1_fn function = [] {
    const char* configured = std::getenv("NEURX_CANN_KERNEL_LIB");
    const char* path = configured && *configured ? configured : "libneurx_cann_kernel.so";
    void* library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    return library ? reinterpret_cast<neurx_cann_kernel_launch_v1_fn>(dlsym(library, "neurx_cann_kernel_launch_v1")) : nullptr;
  }();
  return function;
}
int fail(context_record* current, const char* action) {
  std::string message = std::string(action) + ": " + recent_error();
  if (current) current->error = message; else global_error = message;
  return -1;
}
int probe() { return available() ? 1 : 0; }
int create(int device, const char*) {
  std::lock_guard<std::mutex> lock(state_mutex);
  if (!available() || init() != k_success || set_device(device) != k_success) return fail(nullptr, "aclInit");
  context native = nullptr;
  if (create_context(&native, device) != k_success) return fail(nullptr, "aclrtCreateContext");
  int handle = next_context++;
  context_record record; record.device = device; record.native = native;
  state.emplace(handle, std::move(record));
  return handle;
}
int destroy(int handle) {
  std::lock_guard<std::mutex> lock(state_mutex);
  auto found = state.find(handle);
  if (found == state.end() || !found->second.buffer.empty() ||
      !found->second.stream_map.empty() || !found->second.operation.empty()) return -1;
  if (destroy_context(found->second.native) != k_success) return fail(&found->second, "aclrtDestroyContext");
  reset_device(found->second.device); state.erase(found); return 0;
}
int alloc(int handle, int bytes, const char* kind) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* current = get_context(handle); if (!current || bytes <= 0) return -1;
  set_current_context(current->native);
  bool host = kind && std::string(kind) == "host"; void* address = nullptr;
  error result = host ? malloc_host(&address, bytes) : malloc_device(&address, bytes);
  if (result != k_success) return fail(current, host ? "aclrtMallocHost" : "aclrtMalloc");
  int resource = current->next++; current->buffer.emplace(resource, buffer_record{address, bytes, host}); return resource;
}
int free_buffer(int handle, int resource) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* current = get_context(handle); if (!current) return -1;
  auto found = current->buffer.find(resource); if (found == current->buffer.end()) return -1;
  error result = found->second.host ? free_host(found->second.address) : free_device(found->second.address);
  if (result != k_success) return fail(current, "aclrtFree"); current->buffer.erase(found); return 0;
}
int copy_buffer(int handle, int destination, int source, int bytes, int direction) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* current = get_context(handle); if (!current) return -1;
  auto destination_record = current->buffer.find(destination), source_record = current->buffer.find(source);
  if (destination_record == current->buffer.end() || source_record == current->buffer.end() || bytes < 0 ||
      bytes > destination_record->second.bytes || bytes > source_record->second.bytes) return -1;
  memcpy_kind kind = direction == 1 ? memcpy_kind::host_to_device : direction == 2 ?
      memcpy_kind::device_to_host : memcpy_kind::device_to_device;
  error result = memcpy_async(destination_record->second.address, destination_record->second.bytes,
      source_record->second.address, bytes, kind, nullptr);
  return result == k_success ? 0 : fail(current, "aclrtMemcpyAsync");
}
int stream_create_plugin(int handle, int) {
  std::lock_guard<std::mutex> lock(state_mutex); context_record* current = get_context(handle); if (!current) return -1;
  stream native = nullptr; if (create_stream(&native) != k_success) return fail(current, "aclrtCreateStream");
  int resource = current->next++; current->stream_map.emplace(resource, native); return resource;
}
int stream_destroy_plugin(int handle, int resource) {
  std::lock_guard<std::mutex> lock(state_mutex); context_record* current = get_context(handle); if (!current) return -1;
  auto found = current->stream_map.find(resource); if (found == current->stream_map.end()) return -1;
  if (destroy_stream(found->second) != k_success) return fail(current, "aclrtDestroyStream");
  current->stream_map.erase(found); return 0;
}
int op_create(int handle, const char* descriptor) {
  std::lock_guard<std::mutex> lock(state_mutex); context_record* current = get_context(handle);
  if (!current || !descriptor || !*descriptor) return -1;
  auto attribute = parse_fields(descriptor); auto op = attribute.find("op");
  if (std::string(descriptor).rfind("v1;", 0) != 0 || op == attribute.end()) { current->error = "invalid v1 operator descriptor"; return -1; }
  const std::string& kind = op->second;
  if (kind != "embedding" && kind != "rms_norm" && kind != "linear" && kind != "rope" &&
      kind != "paged_attention" && kind != "swiglu" && kind != "residual_add") {
    current->error = "unsupported CANN operator: " + kind; return -1;
  }
  int resource = current->next++;
  current->operation.emplace(resource, context_record::operation_record{kind, descriptor}); return resource;
}
int op_destroy(int handle, int resource) {
  std::lock_guard<std::mutex> lock(state_mutex); context_record* current = get_context(handle);
  return current && current->operation.erase(resource) == 1 ? 0 : -1;
}
int op_launch(int handle, int operation, int stream_resource, const char* binding_text) {
  std::lock_guard<std::mutex> lock(state_mutex); context_record* current = get_context(handle);
  if (!current) return -1; auto operation_found = current->operation.find(operation);
  if (operation_found == current->operation.end()) return -1;
  stream native_stream = nullptr;
  if (stream_resource != 0) { auto found = current->stream_map.find(stream_resource); if (found == current->stream_map.end()) return -1; native_stream = found->second; }
  auto dispatch = kernel_dispatch();
  if (!dispatch) { current->error = "CANN Kernel library unavailable; set NEURX_CANN_KERNEL_LIB"; return -2; }
  auto field = parse_fields(binding_text); std::vector<std::string> name; std::vector<neurx_cann_buffer_binding_v1> buffer;
  std::string scalar;
  for (const auto& item : field) {
    if (item.first.rfind("buffer.", 0) == 0) {
      int resource = 0; try { resource = std::stoi(item.second); } catch (...) { return -1; }
      if (resource == 0) continue; auto found = current->buffer.find(resource); if (found == current->buffer.end()) return -1;
      name.push_back(item.first.substr(7));
      buffer.push_back(neurx_cann_buffer_binding_v1{name.back().c_str(), found->second.address, found->second.bytes});
    } else { if (!scalar.empty()) scalar += ";"; scalar += item.first + "=" + item.second; }
  }
  // name storage may move while growing; repair pointers after construction.
  for (std::size_t index = 0; index < buffer.size(); ++index) buffer[index].name = name[index].c_str();
  neurx_cann_kernel_request_v1 request{NEURX_CANN_KERNEL_ABI_VERSION, sizeof(neurx_cann_kernel_request_v1),
      operation_found->second.descriptor.c_str(), scalar.c_str(), buffer.data(), static_cast<int32_t>(buffer.size()), native_stream};
  int result = dispatch(&request); if (result != 0) current->error = "CANN Kernel launch failed for " + operation_found->second.kind;
  return result;
}
int synchronize_plugin(int handle, int stream_resource) {
  std::lock_guard<std::mutex> lock(state_mutex); context_record* current = get_context(handle); if (!current) return -1;
  if (stream_resource == 0) return synchronize_device() == k_success ? 0 : fail(current, "aclrtSynchronizeDevice");
  auto found = current->stream_map.find(stream_resource); return found != current->stream_map.end() &&
      synchronize_stream(found->second) == k_success ? 0 : fail(current, "aclrtSynchronizeStream");
}
const char* last_error(int handle) { context_record* current = get_context(handle); return current ? current->error.c_str() : global_error.c_str(); }
const neurx_device_plugin_v1 plugin = {
  NEURX_DEVICE_PLUGIN_ABI_VERSION, sizeof(neurx_device_plugin_v1), "cann", probe,
  create, destroy, alloc, free_buffer, copy_buffer, stream_create_plugin,
  stream_destroy_plugin, op_create, op_destroy, op_launch, synchronize_plugin, last_error
};
}
extern "C" const neurx_device_plugin_v1* neurx_device_plugin_get_v1(void) { return &plugin; }
