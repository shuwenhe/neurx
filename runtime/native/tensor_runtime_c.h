#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum nx_dtype {
  NX_BOOL = 0,
  NX_UINT8 = 1,
  NX_INT8 = 2,
  NX_INT16 = 3,
  NX_INT32 = 4,
  NX_INT64 = 5,
  NX_FLOAT16 = 6,
  NX_BFLOAT16 = 7,
  NX_FLOAT32 = 8,
  NX_FLOAT64 = 9,
} nx_dtype;

typedef enum nx_device_type {
  NX_DEVICE_CPU = 0,
  NX_DEVICE_CUDA = 1,
  NX_DEVICE_CANN = 2,
} nx_device_type;

typedef enum nx_copy_kind {
  NX_COPY_HOST_TO_HOST = 0,
  NX_COPY_HOST_TO_DEVICE = 1,
  NX_COPY_DEVICE_TO_HOST = 2,
  NX_COPY_DEVICE_TO_DEVICE = 3,
} nx_copy_kind;

typedef struct nx_tensor nx_tensor;
typedef int (*nx_kernel_fn)(nx_tensor* const* inputs, size_t input_count,
                            nx_tensor** output, void* context);
typedef void (*nx_context_deleter_fn)(void* context);

typedef void* (*nx_allocate_fn)(int device_id, size_t bytes, void* context);
typedef void (*nx_deallocate_fn)(int device_id, void* ptr, void* context);
typedef int (*nx_copy_fn)(int dst_device, void* dst, nx_device_type src_type,
                          int src_device, const void* src, size_t bytes,
                          nx_copy_kind kind, void* context);
typedef int (*nx_memset_fn)(int device_id, void* ptr, int value, size_t bytes,
                            void* context);
typedef int (*nx_synchronize_fn)(int device_id, void* context);

typedef struct nx_memory_ops {
  nx_allocate_fn allocate;
  nx_deallocate_fn deallocate;
  nx_copy_fn copy;
  nx_memset_fn set;
  nx_synchronize_fn synchronize;
  void* context;
} nx_memory_ops;

int nx_register_memory_backend(nx_device_type device, nx_memory_ops ops);
int nx_tensor_empty(const int64_t* shape, size_t rank, nx_dtype dtype,
                    nx_device_type device, int device_id, nx_tensor** output);
int nx_tensor_zeros(const int64_t* shape, size_t rank, nx_dtype dtype,
                    nx_device_type device, int device_id, nx_tensor** output);
void nx_tensor_retain(nx_tensor* tensor);
void nx_tensor_release(nx_tensor* tensor);
int nx_tensor_copy_from_host(nx_tensor* tensor, const void* data, size_t bytes);
int nx_tensor_copy_to_host(const nx_tensor* tensor, void* data, size_t bytes);
int nx_tensor_reshape(const nx_tensor* tensor, const int64_t* shape, size_t rank,
                      nx_tensor** output);
int nx_tensor_to_dtype(const nx_tensor* tensor, nx_dtype dtype, nx_tensor** output);
int nx_dispatch(const char* operation, nx_tensor* const* inputs, size_t input_count,
                int allow_cpu_fallback, nx_tensor** output);
int nx_dispatch_register_kernel(const char* operation, nx_device_type device,
                                nx_dtype dtype, nx_kernel_fn kernel,
                                void* context, nx_context_deleter_fn deleter);
int nx_dispatch_register_builtin_cpu(void);

nx_dtype nx_tensor_dtype(const nx_tensor* tensor);
nx_device_type nx_tensor_device_type(const nx_tensor* tensor);
int nx_tensor_device_id(const nx_tensor* tensor);
size_t nx_tensor_rank(const nx_tensor* tensor);
int64_t nx_tensor_dim(const nx_tensor* tensor, size_t index);
int64_t nx_tensor_stride(const nx_tensor* tensor, size_t index);
int64_t nx_tensor_numel(const nx_tensor* tensor);
size_t nx_tensor_nbytes(const nx_tensor* tensor);
uint64_t nx_tensor_version(const nx_tensor* tensor);
const char* nx_last_error(void);

#ifdef __cplusplus
}
#endif
