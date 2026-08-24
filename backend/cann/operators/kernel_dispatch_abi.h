#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NEURX_CANN_KERNEL_ABI_VERSION 1u

typedef struct neurx_cann_buffer_binding_v1 {
  const char* name;
  void* address;
  int64_t bytes;
} neurx_cann_buffer_binding_v1;

typedef struct neurx_cann_kernel_request_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  const char* descriptor;
  const char* scalar_binding;
  const neurx_cann_buffer_binding_v1* buffer;
  int32_t buffer_count;
  void* stream;
} neurx_cann_kernel_request_v1;

// Implemented by an aclnn/ATB operator library, not by the S control plane.
typedef int (*neurx_cann_kernel_launch_v1_fn)(const neurx_cann_kernel_request_v1* request);

#ifdef __cplusplus
}
#endif
