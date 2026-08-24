#pragma once

// NeurX Device ABI v1. The S control plane uses only opaque integer handles,
// strings and scalar integers so CUDA, CANN and future vendor plugins share
// one stable boundary.
#ifdef __cplusplus
extern "C" {
#endif

#define NEURX_DEVICE_ABI_VERSION 1

int neurx_device_probe(const char* backend);
int neurx_device_create(const char* backend, int device_id, const char* options);
int neurx_device_destroy(int context);
int neurx_device_alloc(int context, int bytes, const char* memory_kind);
int neurx_device_free(int context, int buffer);
int neurx_device_copy(int context, int destination, int source, int bytes,
                      int direction);
int neurx_device_stream_create(int context, int priority);
int neurx_device_stream_destroy(int context, int stream);
int neurx_device_op_create(int context, const char* op_descriptor);
int neurx_device_op_launch(int context, int operation, int stream,
                           const char* bindings);
int neurx_device_synchronize(int context, int stream);
const char* neurx_device_last_error(int context);

#ifdef __cplusplus
}
#endif
