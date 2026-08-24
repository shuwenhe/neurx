#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NEURX_DEVICE_PLUGIN_ABI_VERSION 1u
#define NEURX_DEVICE_PLUGIN_ENTRY "neurx_device_plugin_get_v1"

// Vendor SDK types never cross this table. Handles are local to one plugin
// context and the common registry translates them to process-wide handles.
typedef struct neurx_device_plugin_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  const char* backend_name;
  int (*probe)(void);
  int (*create)(int device_id, const char* options);
  int (*destroy)(int context);
  int (*alloc)(int context, int bytes, const char* memory_kind);
  int (*free)(int context, int buffer);
  int (*copy)(int context, int destination, int source, int bytes,
              int direction);
  int (*stream_create)(int context, int priority);
  int (*stream_destroy)(int context, int stream);
  int (*op_create)(int context, const char* descriptor);
  int (*op_destroy)(int context, int operation);
  int (*op_launch)(int context, int operation, int stream,
                   const char* bindings);
  int (*synchronize)(int context, int stream);
  const char* (*last_error)(int context);
} neurx_device_plugin_v1;

typedef const neurx_device_plugin_v1* (*neurx_device_plugin_get_v1_fn)(void);

#ifdef __cplusplus
}
#endif
