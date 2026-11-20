#include "../../backend/api/device_abi.h"
#include "../../backend/api/device_plugin_abi.h"

#include <dlfcn.h>
#include <cstdlib>
#include <cstring>
#include <climits>
#include <cstddef>
#include <iostream>

// Linux LP64 ABI v1 layout, including all 13 callback slots.
static_assert(sizeof(void*) == 8 && sizeof(int) == 4);
static_assert(sizeof(neurx_device_plugin_v1) == 120);
static_assert(alignof(neurx_device_plugin_v1) == 8);
static_assert(offsetof(neurx_device_plugin_v1, abi_version) == 0);
static_assert(offsetof(neurx_device_plugin_v1, struct_size) == 4);
static_assert(offsetof(neurx_device_plugin_v1, backend_name) == 8);
static_assert(offsetof(neurx_device_plugin_v1, probe) == 16);
static_assert(offsetof(neurx_device_plugin_v1, create) == 24);
static_assert(offsetof(neurx_device_plugin_v1, destroy) == 32);
static_assert(offsetof(neurx_device_plugin_v1, alloc) == 40);
static_assert(offsetof(neurx_device_plugin_v1, free) == 48);
static_assert(offsetof(neurx_device_plugin_v1, copy) == 56);
static_assert(offsetof(neurx_device_plugin_v1, stream_create) == 64);
static_assert(offsetof(neurx_device_plugin_v1, stream_destroy) == 72);
static_assert(offsetof(neurx_device_plugin_v1, op_create) == 80);
static_assert(offsetof(neurx_device_plugin_v1, op_destroy) == 88);
static_assert(offsetof(neurx_device_plugin_v1, op_launch) == 96);
static_assert(offsetof(neurx_device_plugin_v1, synchronize) == 104);
static_assert(offsetof(neurx_device_plugin_v1, last_error) == 112);

static void require(bool condition, const char* message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << '\n';
    std::exit(1);
  }
}

int main(int argc, char** argv) {
  require(argc == 2 || argc == 3, "expected plugin path and optional diagnostic");
  void* library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!library) {
    std::cerr << dlerror() << '\n';
    return 1;
  }

  auto entry = reinterpret_cast<neurx_device_plugin_get_v1_fn>(
      dlsym(library, NEURX_DEVICE_PLUGIN_ENTRY));
  require(entry != nullptr, "missing v1 entry point");
  const auto* api = entry();
  require(api && api->abi_version == 1 && api->struct_size == sizeof(*api) &&
              api->backend_name && std::strcmp(api->backend_name, "mlu") == 0,
          "invalid v1 plugin metadata");
  require(api->probe && api->create && api->destroy && api->alloc &&
              api->free && api->copy && api->stream_create &&
              api->stream_destroy && api->op_create && api->op_destroy &&
              api->op_launch && api->synchronize && api->last_error,
          "incomplete v1 callback table");
  require(api->probe() == 0, "foundation must report zero available devices");
  require(api->create(0, "{}") < 0 && api->destroy(1) < 0 &&
              api->alloc(1, 64, "device") < 0 && api->free(1, 1) < 0 &&
              api->copy(1, 1, 2, 64, 1) < 0 &&
              api->stream_create(1, 0) < 0 && api->stream_destroy(1, 1) < 0 &&
              api->op_create(1, "v1;op=vector_add") < 0 &&
              api->op_destroy(1, 1) < 0 && api->op_launch(1, 1, 0, "") < 0 &&
              api->synchronize(1, 0) < 0,
          "unavailable backend accepted a device operation");

  require(api->create(INT_MIN, nullptr) == -1 &&
              api->destroy(INT_MIN) == -1 &&
              api->alloc(INT_MAX, INT_MIN, nullptr) == -1 &&
              api->free(INT_MIN, INT_MAX) == -1 &&
              api->copy(INT_MAX, INT_MIN, INT_MAX, INT_MIN, INT_MAX) == -1 &&
              api->stream_create(0, INT_MIN) == -1 &&
              api->stream_destroy(INT_MIN, INT_MAX) == -1 &&
              api->op_create(0, nullptr) == -1 &&
              api->op_destroy(INT_MAX, INT_MIN) == -1 &&
              api->op_launch(0, INT_MIN, INT_MAX, nullptr) == -1 &&
              api->synchronize(INT_MIN, INT_MAX) == -1,
          "null text or invalid handle did not fail with -1");

  auto status = reinterpret_cast<int64_t (*)(int64_t)>(
      dlsym(library, "neurx_mlu_classify_loader"));
  require(status && status(0) == 0 && status(1) == 1 &&
              status(2) == 2 && status(INT64_MAX) == -1,
          "S runtime classification lost an input or accepted an invalid value");
  const char* diagnostic = api->last_error(0);
  require(diagnostic && std::strstr(diagnostic, "CNRT"), "missing CNRT diagnostic");
  if (argc == 3)
    require(std::strstr(diagnostic, argv[2]), "unexpected runtime diagnostic");
  require(api->last_error(INT_MIN) == diagnostic, "diagnostic storage is unstable");
  require(neurx_device_probe(nullptr) == -1, "registry accepted a null backend");
  require(neurx_device_probe("mlu") == 0, "registry reported an available MLU");
  require(neurx_device_create("mlu", 0, "{}") < 0, "registry created an MLU context");
  require(std::strcmp(neurx_device_last_error(0), diagnostic) == 0,
          "registry did not propagate the plugin diagnostic");
  if (argc == 3 && std::strcmp(argv[2], "CNRT library is loadable") == 0)
    require(dlopen("libcnrt.so", RTLD_NOLOAD | RTLD_NOW) == nullptr,
            "loader probe retained a library reference");
  require(dlclose(library) == 0, "could not release direct plugin reference");
  std::cout << "PASS: MLU Device ABI v1 unavailable contract\n";
}
