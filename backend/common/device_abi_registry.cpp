#include "../api/device_abi.h"
#include "../api/device_plugin_abi.h"

#include <dlfcn.h>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <sstream>
#include <unordered_map>

namespace {
struct plugin_record {
  void* library = nullptr;
  const neurx_device_plugin_v1* api = nullptr;
};
struct context_record {
  plugin_record* plugin = nullptr;
  int vendor = 0;
  int resource_count = 0;
};
struct resource_record {
  int context = 0;
  int vendor = 0;
};

std::mutex registry_mutex;
std::unordered_map<std::string, plugin_record> plugins;
std::unordered_map<int, context_record> contexts;
std::unordered_map<int, resource_record> buffers;
std::unordered_map<int, resource_record> streams;
std::unordered_map<int, resource_record> operations;
int next_handle = 1;
thread_local std::string registry_error;

int fail(const std::string& message) {
  registry_error = message;
  return -1;
}

bool valid_backend(const char* backend) {
  if (!backend || !*backend) return false;
  for (const char* p = backend; *p; ++p) {
    if (!((*p >= 'a' && *p <= 'z') || (*p >= '0' && *p <= '9') || *p == '_'))
      return false;
  }
  return true;
}

plugin_record* load_plugin(const char* backend) {
  auto found = plugins.find(backend);
  if (found != plugins.end()) return found->second.api ? &found->second : nullptr;
  plugin_record record;
  const char* directory = std::getenv("NEURX_BACKEND_PLUGIN_DIR");
  std::string path = directory && *directory ? directory : ".";
  path += "/libneurx_backend_" + std::string(backend) + ".so";
  record.library = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
  if (!record.library) {
    registry_error = std::string("cannot load ") + path + ": " + dlerror();
    plugins.emplace(backend, record);
    return nullptr;
  }
  auto entry = reinterpret_cast<neurx_device_plugin_get_v1_fn>(
      dlsym(record.library, NEURX_DEVICE_PLUGIN_ENTRY));
  record.api = entry ? entry() : nullptr;
  if (!record.api || record.api->abi_version != NEURX_DEVICE_PLUGIN_ABI_VERSION ||
      record.api->struct_size < sizeof(neurx_device_plugin_v1) ||
      !record.api->backend_name || std::strcmp(record.api->backend_name, backend) != 0) {
    registry_error = "invalid Device ABI plugin: " + path;
    dlclose(record.library);
    record.library = nullptr;
    record.api = nullptr;
  }
  auto inserted = plugins.emplace(backend, record);
  return inserted.first->second.api ? &inserted.first->second : nullptr;
}

context_record* context_for(int handle) {
  auto found = contexts.find(handle);
  return found == contexts.end() ? nullptr : &found->second;
}

int add_resource(std::unordered_map<int, resource_record>& table, int context,
                 int vendor) {
  if (vendor <= 0) return -1;
  int handle = next_handle++;
  table.emplace(handle, resource_record{context, vendor});
  contexts.at(context).resource_count++;
  return handle;
}

resource_record* resource_for(std::unordered_map<int, resource_record>& table,
                              int context, int handle) {
  auto found = table.find(handle);
  if (found == table.end() || found->second.context != context) return nullptr;
  return &found->second;
}

bool translate_bindings(int context, const char* bindings, std::string* output) {
  std::stringstream input(bindings ? bindings : "");
  std::string item;
  bool first = true;
  output->clear();
  while (std::getline(input, item, ';')) {
    if (item.empty()) continue;
    std::size_t equal = item.find('=');
    if (equal == std::string::npos) return false;
    std::string key = item.substr(0, equal);
    std::string value = item.substr(equal + 1);
    if (key.rfind("buffer.", 0) == 0) {
      char* end = nullptr;
      long public_handle = std::strtol(value.c_str(), &end, 10);
      if (public_handle == 0 && end && *end == '\0') {
        value = "0";
      } else {
      resource_record* resource = end && *end == '\0'
          ? resource_for(buffers, context, static_cast<int>(public_handle)) : nullptr;
      if (!resource) return false;
      value = std::to_string(resource->vendor);
      }
    }
    if (!first) *output += ";";
    *output += key + "=" + value;
    first = false;
  }
  return true;
}
}  // namespace

extern "C" int neurx_device_probe(const char* backend) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  if (!valid_backend(backend)) return fail("invalid backend name");
  plugin_record* plugin = load_plugin(backend);
  return plugin && plugin->api->probe ? plugin->api->probe() : 0;
}

extern "C" int neurx_device_create(const char* backend, int device_id,
                                    const char* options) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  if (!valid_backend(backend)) return fail("invalid backend name");
  plugin_record* plugin = load_plugin(backend);
  if (!plugin || !plugin->api->create) return fail("backend unavailable");
  int vendor = plugin->api->create(device_id, options ? options : "");
  if (vendor <= 0) return fail(plugin->api->last_error ? plugin->api->last_error(0) : "create failed");
  int handle = next_handle++;
  contexts.emplace(handle, context_record{plugin, vendor, 0});
  return handle;
}

extern "C" int neurx_device_destroy(int context) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  context_record* record = context_for(context);
  if (!record) return fail("invalid context");
  if (record->resource_count != 0) return fail("context still owns resources");
  int result = record->plugin->api->destroy(record->vendor);
  if (result == 0) contexts.erase(context);
  return result;
}

extern "C" int neurx_device_alloc(int context, int bytes, const char* kind) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  context_record* record = context_for(context);
  if (!record || bytes <= 0) return fail("invalid allocation request");
  return add_resource(buffers, context,
      record->plugin->api->alloc(record->vendor, bytes, kind ? kind : "device"));
}

extern "C" int neurx_device_free(int context, int buffer) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  context_record* record = context_for(context);
  resource_record* resource = resource_for(buffers, context, buffer);
  if (!record || !resource) return fail("invalid buffer");
  int result = record->plugin->api->free(record->vendor, resource->vendor);
  if (result == 0) { buffers.erase(buffer); record->resource_count--; }
  return result;
}

extern "C" int neurx_device_copy(int context, int destination, int source,
                                  int bytes, int direction) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  context_record* record = context_for(context);
  resource_record* destination_record = resource_for(buffers, context, destination);
  resource_record* source_record = resource_for(buffers, context, source);
  if (!record || !destination_record || !source_record || bytes < 0)
    return fail("invalid copy request");
  return record->plugin->api->copy(record->vendor, destination_record->vendor,
      source_record->vendor, bytes, direction);
}

extern "C" int neurx_device_stream_create(int context, int priority) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  context_record* record = context_for(context);
  if (!record) return fail("invalid context");
  return add_resource(streams, context,
      record->plugin->api->stream_create(record->vendor, priority));
}

extern "C" int neurx_device_stream_destroy(int context, int stream) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  context_record* record = context_for(context);
  resource_record* resource = resource_for(streams, context, stream);
  if (!record || !resource) return fail("invalid stream");
  int result = record->plugin->api->stream_destroy(record->vendor, resource->vendor);
  if (result == 0) { streams.erase(stream); record->resource_count--; }
  return result;
}

extern "C" int neurx_device_op_create(int context, const char* descriptor) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  context_record* record = context_for(context);
  if (!record) return fail("invalid context");
  return add_resource(operations, context,
      record->plugin->api->op_create(record->vendor, descriptor ? descriptor : ""));
}

extern "C" int neurx_device_op_destroy(int context, int operation) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  context_record* record = context_for(context);
  resource_record* resource = resource_for(operations, context, operation);
  if (!record || !resource) return fail("invalid operation");
  int result = record->plugin->api->op_destroy(record->vendor, resource->vendor);
  if (result == 0) { operations.erase(operation); record->resource_count--; }
  return result;
}

extern "C" int neurx_device_op_launch(int context, int operation, int stream,
                                       const char* bindings) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  context_record* record = context_for(context);
  resource_record* op = resource_for(operations, context, operation);
  resource_record* queue = stream == 0 ? nullptr : resource_for(streams, context, stream);
  if (!record || !op || (stream != 0 && !queue)) return fail("invalid launch request");
  std::string vendor_bindings;
  if (!translate_bindings(context, bindings, &vendor_bindings))
    return fail("invalid operation bindings");
  return record->plugin->api->op_launch(record->vendor, op->vendor,
      queue ? queue->vendor : 0, vendor_bindings.c_str());
}

extern "C" int neurx_device_synchronize(int context, int stream) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  context_record* record = context_for(context);
  resource_record* queue = stream == 0 ? nullptr : resource_for(streams, context, stream);
  if (!record || (stream != 0 && !queue)) return fail("invalid synchronize request");
  return record->plugin->api->synchronize(record->vendor, queue ? queue->vendor : 0);
}

extern "C" const char* neurx_device_last_error(int context) {
  std::lock_guard<std::mutex> lock(registry_mutex);
  context_record* record = context_for(context);
  if (record && record->plugin->api->last_error) {
    const char* message = record->plugin->api->last_error(record->vendor);
    if (message && *message) registry_error = message;
  }
  return registry_error.c_str();
}
