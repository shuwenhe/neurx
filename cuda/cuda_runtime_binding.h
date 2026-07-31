#ifndef NEURX_CUDA_RUNTIME_BINDING_H
#define NEURX_CUDA_RUNTIME_BINDING_H
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
int neurx_cuda_get_device_count();
int neurx_cuda_set_device(int device_id);
const char* neurx_cuda_get_device_name(int device_id);
void* neurx_cuda_malloc(size_t size);
int neurx_cuda_free(void* ptr);
int neurx_cuda_memcpy_htod(void* dst, const void* src, size_t size);
int neurx_cuda_memcpy_dtoh(void* dst, const void* src, size_t size);
int neurx_cuda_memcpy_dtod(void* dst, const void* src, size_t size);
int neurx_cuda_get_memory_info(size_t* free_bytes, size_t* total_bytes);
void* neurx_cublas_create();
int neurx_cublas_destroy(void* handle);
int neurx_cublas_sgemm(void* handle,
                       int m, int n, int k,
                       float alpha,
                       const float* A,
                       const float* B,
                       float beta,
                       float* C);
float* neurx_linear_forward(int batch_size, int in_features, int out_features,
                            const float* x,
                            const float* weight,
                            const float* bias);
int neurx_linear_backward(int batch_size, int in_features, int out_features,
                          const float* dy,
                          const float* x,
                          const float* weight,
                          float* dx,
                          float* dw,
                          float* db);
float* neurx_relu_forward(int size, const float* x);
int neurx_relu_backward(int size, const float* dy, const float* x, float* dx);
float* neurx_softmax_forward(int batch_size, int num_classes, const float* logits);
int neurx_cross_entropy_backward(int batch_size, int num_classes,
                                 const float* probs,
                                 const int* targets,
                                 float* dlogits);
int neurx_adam_step(int param_count,
                    float* params,
                    const float* grads,
                    float* m,
                    float* v,
                    float lr,
                    float beta1, float beta2, float eps, float weight_decay,
                    int step);
int neurx_cuda_synchronize();
const char* neurx_cuda_get_error_string(int error_code);
#ifdef __cplusplus
}
#endif
#endif
