#include "cuda_runtime_binding.h"
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
int neurx_cuda_get_device_count() {
    int count;
    cuda_error_t err = cuda_get_device_count(&count);
    if (err != cuda_success) {
        fprintf(stderr, "CUDA error: %s\n", cuda_get_error_string(err));
        return 0;
    }
    return count;
}
int neurx_cuda_set_device(int device_id) {
    cuda_error_t err = cuda_set_device(device_id);
    return (err == cuda_success) ? 0 : -1;
}
const char* neurx_cuda_get_device_name(int device_id) {
    static char name[256];
    cuda_device_prop prop;
    cuda_error_t err = cuda_get_device_properties(&prop, device_id);
    if (err != cuda_success) {
        snprintf(name, sizeof(name), "ERROR: %s", cuda_get_error_string(err));
        return name;
    }
    snprintf(name, sizeof(name), "%s (Compute %.1f)", prop.name,
             prop.major + prop.minor / 10.0);
    return name;
}
void* neurx_cuda_malloc(size_t size) {
    void* ptr;
    cuda_error_t err = cuda_malloc(&ptr, size);
    if (err != cuda_success) {
        fprintf(stderr, "cudaMalloc failed: %s (size=%zu)\n", cuda_get_error_string(err), size);
        return NULL;
    }
    return ptr;
}
int neurx_cuda_free(void* ptr) {
    cuda_error_t err = cuda_free(ptr);
    return (err == cuda_success) ? 0 : -1;
}
int neurx_cuda_memcpy_htod(void* dst, const void* src, size_t size) {
    cuda_error_t err = cuda_memcpy(dst, src, size, cuda_memcpy_host_to_device);
    return (err == cuda_success) ? 0 : -1;
}
int neurx_cuda_memcpy_dtoh(void* dst, const void* src, size_t size) {
    cuda_error_t err = cuda_memcpy(dst, src, size, cuda_memcpy_device_to_host);
    return (err == cuda_success) ? 0 : -1;
}
int neurx_cuda_memcpy_dtod(void* dst, const void* src, size_t size) {
    cuda_error_t err = cuda_memcpy(dst, src, size, cuda_memcpy_device_to_device);
    return (err == cuda_success) ? 0 : -1;
}
int neurx_cuda_get_memory_info(size_t* free_bytes, size_t* total_bytes) {
    cuda_error_t err = cuda_mem_get_info(free_bytes, total_bytes);
    return (err == cuda_success) ? 0 : -1;
}
void* neurx_cublas_create() {
    cublas_handle_t handle;
    cublas_status_t status = cublas_create(&handle);
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "cublasCreate failed: %d\n", status);
        return NULL;
    }
    return (void*)handle;
}
int neurx_cublas_destroy(void* handle) {
    cublas_handle_t h = (cublas_handle_t)handle;
    cublas_status_t status = cublas_destroy(h);
    return (status == CUBLAS_STATUS_SUCCESS) ? 0 : -1;
}
int neurx_cublas_sgemm(void* handle,
                       int m, int n, int k,
                       float alpha,
                       const float* A,
                       const float* B,
                       float beta,
                       float* C) {
    cublas_handle_t h = (cublas_handle_t)handle;
    cublas_status_t status = cublas_sgemm(h,
                                       CUBLAS_OP_N, CUBLAS_OP_N,
                                       m, n, k,
                                       &alpha,
                                       A, m,
                                       B, k,
                                       &beta,
                                       C, m);
    return (status == CUBLAS_STATUS_SUCCESS) ? 0 : -1;
}
__global__ void linear_forward_kernel(int batch_size, int in_features, int out_features,
                                      const float* x,
                                      const float* weight,
                                      const float* bias,
                                      float* y) {
    int idx = block_idx.x * block_dim.x + thread_idx.x;
    int batch_idx = idx / out_features;
    int out_idx = idx % out_features;
    if (batch_idx >= batch_size || out_idx >= out_features) return;
    float sum = bias[out_idx];
    for (int i = 0; i < in_features; i++) {
        sum += x[batch_idx * in_features + i] * weight[out_idx * in_features + i];
    }
    y[batch_idx * out_features + out_idx] = sum;
}
float* neurx_linear_forward(int batch_size, int in_features, int out_features,
                            const float* x,
                            const float* weight,
                            const float* bias) {
    float* y;
    cuda_malloc(&y, batch_size * out_features * sizeof(float));
    int block_size = 256;
    int grid_size = (batch_size * out_features + block_size - 1) / block_size;
    linear_forward_kernel<<<grid_size, block_size>>>(
        batch_size, in_features, out_features,
        x, weight, bias, y);
    cuda_device_synchronize();
    return y;
}
__global__ void linear_backward_kernel(int batch_size, int in_features, int out_features,
                                       const float* dy,
                                       const float* x,
                                       const float* weight,
                                       float* dx,
                                       float* dw_partial,
                                       float* db) {
    int idx = block_idx.x * block_dim.x + thread_idx.x;
    if (idx < batch_size * out_features) {
        int batch_idx = idx / out_features;
        int out_idx = idx % out_features;
        float grad = dy[idx];
        atomic_add(&db[out_idx], grad);
        for (int i = 0; i < in_features; i++) {
            float x_val = x[batch_idx * in_features + i];
            atomic_add(&dw_partial[out_idx * in_features + i], grad * x_val);
        }
        for (int i = 0; i < in_features; i++) {
            atomic_add(&dx[batch_idx * in_features + i],
                     grad * weight[out_idx * in_features + i]);
        }
    }
}
int neurx_linear_backward(int batch_size, int in_features, int out_features,
                          const float* dy,
                          const float* x,
                          const float* weight,
                          float* dx,
                          float* dw,
                          float* db) {
    cuda_memset(dx, 0, batch_size * in_features * sizeof(float));
    cuda_memset(dw, 0, out_features * in_features * sizeof(float));
    cuda_memset(db, 0, out_features * sizeof(float));
    int block_size = 256;
    int grid_size = (batch_size * out_features + block_size - 1) / block_size;
    linear_backward_kernel<<<grid_size, block_size>>>(
        batch_size, in_features, out_features,
        dy, x, weight, dx, dw, db);
    cuda_device_synchronize();
    return 0;
}
__global__ void relu_forward_kernel(int size, const float* x, float* y) {
    int idx = block_idx.x * block_dim.x + thread_idx.x;
    if (idx < size) {
        y[idx] = fmaxf(0.0f, x[idx]);
    }
}
float* neurx_relu_forward(int size, const float* x) {
    float* y;
    cuda_malloc(&y, size * sizeof(float));
    int block_size = 256;
    int grid_size = (size + block_size - 1) / block_size;
    relu_forward_kernel<<<grid_size, block_size>>>(size, x, y);
    cuda_device_synchronize();
    return y;
}
__global__ void relu_backward_kernel(int size, const float* dy, const float* x, float* dx) {
    int idx = block_idx.x * block_dim.x + thread_idx.x;
    if (idx < size) {
        dx[idx] = (x[idx] > 0.0f) ? dy[idx] : 0.0f;
    }
}
int neurx_relu_backward(int size, const float* dy, const float* x, float* dx) {
    int block_size = 256;
    int grid_size = (size + block_size - 1) / block_size;
    relu_backward_kernel<<<grid_size, block_size>>>(size, dy, x, dx);
    cuda_device_synchronize();
    return 0;
}
__global__ void softmax_forward_kernel(int batch_size, int num_classes,
                                      const float* logits, float* output) {
    int batch_idx = block_idx.x;
    int class_idx = thread_idx.x;
    if (batch_idx >= batch_size || class_idx >= num_classes) return;
    const float* batch_logits = logits + batch_idx * num_classes;
    float* batch_output = output + batch_idx * num_classes;
    float max_logit = batch_logits[0];
    for (int i = 1; i < num_classes; i++) {
        max_logit = fmaxf(max_logit, batch_logits[i]);
    }
    float sum = 0.0f;
    for (int i = class_idx; i < num_classes; i += block_dim.x) {
        float exp_val = expf(batch_logits[i] - max_logit);
        batch_output[i] = exp_val;
        sum += exp_val;
    }
    for (int i = class_idx; i < num_classes; i += block_dim.x) {
        batch_output[i] /= sum;
    }
}
float* neurx_softmax_forward(int batch_size, int num_classes, const float* logits) {
    float* output;
    cuda_malloc(&output, batch_size * num_classes * sizeof(float));
    softmax_forward_kernel<<<batch_size, 256>>>(batch_size, num_classes, logits, output);
    cuda_device_synchronize();
    return output;
}
__global__ void cross_entropy_backward_kernel(int batch_size, int num_classes,
                                             const float* probs,
                                             const int* targets,
                                             float* dlogits) {
    int idx = block_idx.x * block_dim.x + thread_idx.x;
    if (idx < batch_size * num_classes) {
        int batch_idx = idx / num_classes;
        int class_idx = idx % num_classes;
        float prob = probs[idx];
        int target = targets[batch_idx];
        if (class_idx == target) {
            dlogits[idx] = (prob - 1.0f) / batch_size;
        } else {
            dlogits[idx] = prob / batch_size;
        }
    }
}
int neurx_cross_entropy_backward(int batch_size, int num_classes,
                                 const float* probs,
                                 const int* targets,
                                 float* dlogits) {
    int block_size = 256;
    int grid_size = (batch_size * num_classes + block_size - 1) / block_size;
    cross_entropy_backward_kernel<<<grid_size, block_size>>>(
        batch_size, num_classes, probs, targets, dlogits);
    cuda_device_synchronize();
    return 0;
}
__global__ void adam_step_kernel(int param_count,
                                 float* params,
                                 const float* grads,
                                 float* m, float* v,
                                 float lr, float beta1, float beta2, float eps,
                                 float weight_decay, int step) {
    int idx = block_idx.x * block_dim.x + thread_idx.x;
    if (idx >= param_count) return;
    float grad = grads[idx];
    float param = params[idx];
    grad += weight_decay * param;
    m[idx] = beta1 * m[idx] + (1.0f - beta1) * grad;
    v[idx] = beta2 * v[idx] + (1.0f - beta2) * grad * grad;
    float m_hat = m[idx] / (1.0f - powf(beta1, step));
    float v_hat = v[idx] / (1.0f - powf(beta2, step));
    params[idx] = param - lr * m_hat / (sqrtf(v_hat) + eps);
}
int neurx_adam_step(int param_count,
                    float* params,
                    const float* grads,
                    float* m, float* v,
                    float lr, float beta1, float beta2, float eps,
                    float weight_decay, int step) {
    int block_size = 256;
    int grid_size = (param_count + block_size - 1) / block_size;
    adam_step_kernel<<<grid_size, block_size>>>(
        param_count, params, grads, m, v,
        lr, beta1, beta2, eps, weight_decay, step);
    cuda_device_synchronize();
    return 0;
}
int neurx_cuda_synchronize() {
    cuda_error_t err = cuda_device_synchronize();
    return (err == cuda_success) ? 0 : -1;
}
const char* neurx_cuda_get_error_string(int error_code) {
    return cuda_get_error_string((cuda_error_t)error_code);
}
