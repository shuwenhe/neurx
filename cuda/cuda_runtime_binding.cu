/**
 * NVIDIA CUDA Runtime Implementation
 * Real GPU computation using cuBLAS and custom kernels
 */

#include "cuda_runtime_binding.h"
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

// ============================================================================
// DEVICE MANAGEMENT
// ============================================================================

int neurx_cuda_get_device_count() {
    int count;
    cudaError_t err = cudaGetDeviceCount(&count);
    if (err != cudaSuccess) {
        fprintf(stderr, "CUDA error: %s\n", cudaGetErrorString(err));
        return 0;
    }
    return count;
}

int neurx_cuda_set_device(int device_id) {
    cudaError_t err = cudaSetDevice(device_id);
    return (err == cudaSuccess) ? 0 : -1;
}

const char* neurx_cuda_get_device_name(int device_id) {
    static char name[256];
    cudaDeviceProp prop;
    cudaError_t err = cudaGetDeviceProperties(&prop, device_id);
    if (err != cudaSuccess) {
        snprintf(name, sizeof(name), "ERROR: %s", cudaGetErrorString(err));
        return name;
    }
    snprintf(name, sizeof(name), "%s (Compute %.1f)", prop.name, 
             prop.major + prop.minor / 10.0);
    return name;
}

// ============================================================================
// MEMORY MANAGEMENT
// ============================================================================

void* neurx_cuda_malloc(size_t size) {
    void* ptr;
    cudaError_t err = cudaMalloc(&ptr, size);
    if (err != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed: %s (size=%zu)\n", cudaGetErrorString(err), size);
        return NULL;
    }
    return ptr;
}

int neurx_cuda_free(void* ptr) {
    cudaError_t err = cudaFree(ptr);
    return (err == cudaSuccess) ? 0 : -1;
}

int neurx_cuda_memcpy_htod(void* dst, const void* src, size_t size) {
    cudaError_t err = cudaMemcpy(dst, src, size, cudaMemcpyHostToDevice);
    return (err == cudaSuccess) ? 0 : -1;
}

int neurx_cuda_memcpy_dtoh(void* dst, const void* src, size_t size) {
    cudaError_t err = cudaMemcpy(dst, src, size, cudaMemcpyDeviceToHost);
    return (err == cudaSuccess) ? 0 : -1;
}

int neurx_cuda_memcpy_dtod(void* dst, const void* src, size_t size) {
    cudaError_t err = cudaMemcpy(dst, src, size, cudaMemcpyDeviceToDevice);
    return (err == cudaSuccess) ? 0 : -1;
}

int neurx_cuda_get_memory_info(size_t* free_bytes, size_t* total_bytes) {
    cudaError_t err = cudaMemGetInfo(free_bytes, total_bytes);
    return (err == cudaSuccess) ? 0 : -1;
}

// ============================================================================
// cuBLAS OPERATIONS
// ============================================================================

void* neurx_cublas_create() {
    cublasHandle_t handle;
    cublasStatus_t status = cublasCreate(&handle);
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "cublasCreate failed: %d\n", status);
        return NULL;
    }
    return (void*)handle;
}

int neurx_cublas_destroy(void* handle) {
    cublasHandle_t h = (cublasHandle_t)handle;
    cublasStatus_t status = cublasDestroy(h);
    return (status == CUBLAS_STATUS_SUCCESS) ? 0 : -1;
}

int neurx_cublas_sgemm(void* handle,
                       int m, int n, int k,
                       float alpha,
                       const float* A,
                       const float* B,
                       float beta,
                       float* C) {
    cublasHandle_t h = (cublasHandle_t)handle;
    
    // cuBLAS uses column-major layout by default
    // C = alpha * A * B + beta * C
    cublasStatus_t status = cublasSgemm(h,
                                       CUBLAS_OP_N, CUBLAS_OP_N,
                                       m, n, k,
                                       &alpha,
                                       A, m,
                                       B, k,
                                       &beta,
                                       C, m);
    return (status == CUBLAS_STATUS_SUCCESS) ? 0 : -1;
}

// ============================================================================
// CUDA KERNELS - Forward/Backward
// ============================================================================

// Kernel: Linear forward pass
// y = x @ W^T + b
// x: batch_size x in_features
// W: out_features x in_features
// b: out_features
// y: batch_size x out_features
__global__ void linear_forward_kernel(int batch_size, int in_features, int out_features,
                                      const float* x,
                                      const float* weight,
                                      const float* bias,
                                      float* y) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int batch_idx = idx / out_features;
    int out_idx = idx % out_features;
    
    if (batch_idx >= batch_size || out_idx >= out_features) return;
    
    // Bias initialization
    float sum = bias[out_idx];
    
    // Accumulate weighted sum
    for (int i = 0; i < in_features; i++) {
        sum += x[batch_idx * in_features + i] * weight[out_idx * in_features + i];
    }
    
    y[batch_idx * out_features + out_idx] = sum;
}

float* neurx_linear_forward(int batch_size, int in_features, int out_features,
                            const float* x,
                            const float* weight,
                            const float* bias) {
    // Allocate output
    float* y;
    cudaMalloc(&y, batch_size * out_features * sizeof(float));
    
    // Launch kernel
    int block_size = 256;
    int grid_size = (batch_size * out_features + block_size - 1) / block_size;
    
    linear_forward_kernel<<<grid_size, block_size>>>(
        batch_size, in_features, out_features,
        x, weight, bias, y);
    
    cudaDeviceSynchronize();
    return y;
}

// Kernel: Linear backward pass (gradient computation)
__global__ void linear_backward_kernel(int batch_size, int in_features, int out_features,
                                       const float* dy,
                                       const float* x,
                                       const float* weight,
                                       float* dx,
                                       float* dw_partial,
                                       float* db) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    
    if (idx < batch_size * out_features) {
        int batch_idx = idx / out_features;
        int out_idx = idx % out_features;
        float grad = dy[idx];
        
        // Accumulate bias gradient
        atomicAdd(&db[out_idx], grad);
        
        // Compute weight gradient contribution
        for (int i = 0; i < in_features; i++) {
            float x_val = x[batch_idx * in_features + i];
            atomicAdd(&dw_partial[out_idx * in_features + i], grad * x_val);
        }
        
        // Compute input gradient
        for (int i = 0; i < in_features; i++) {
            atomicAdd(&dx[batch_idx * in_features + i], 
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
    // Zero initialize outputs
    cudaMemset(dx, 0, batch_size * in_features * sizeof(float));
    cudaMemset(dw, 0, out_features * in_features * sizeof(float));
    cudaMemset(db, 0, out_features * sizeof(float));
    
    // Launch kernel
    int block_size = 256;
    int grid_size = (batch_size * out_features + block_size - 1) / block_size;
    
    linear_backward_kernel<<<grid_size, block_size>>>(
        batch_size, in_features, out_features,
        dy, x, weight, dx, dw, db);
    
    cudaDeviceSynchronize();
    return 0;
}

// Kernel: ReLU forward
__global__ void relu_forward_kernel(int size, const float* x, float* y) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < size) {
        y[idx] = fmaxf(0.0f, x[idx]);
    }
}

float* neurx_relu_forward(int size, const float* x) {
    float* y;
    cudaMalloc(&y, size * sizeof(float));
    
    int block_size = 256;
    int grid_size = (size + block_size - 1) / block_size;
    relu_forward_kernel<<<grid_size, block_size>>>(size, x, y);
    
    cudaDeviceSynchronize();
    return y;
}

// Kernel: ReLU backward
__global__ void relu_backward_kernel(int size, const float* dy, const float* x, float* dx) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < size) {
        dx[idx] = (x[idx] > 0.0f) ? dy[idx] : 0.0f;
    }
}

int neurx_relu_backward(int size, const float* dy, const float* x, float* dx) {
    int block_size = 256;
    int grid_size = (size + block_size - 1) / block_size;
    relu_backward_kernel<<<grid_size, block_size>>>(size, dy, x, dx);
    
    cudaDeviceSynchronize();
    return 0;
}

// Kernel: Softmax forward
__global__ void softmax_forward_kernel(int batch_size, int num_classes, 
                                      const float* logits, float* output) {
    int batch_idx = blockIdx.x;
    int class_idx = threadIdx.x;
    
    if (batch_idx >= batch_size || class_idx >= num_classes) return;
    
    const float* batch_logits = logits + batch_idx * num_classes;
    float* batch_output = output + batch_idx * num_classes;
    
    // Find max for numerical stability
    float max_logit = batch_logits[0];
    for (int i = 1; i < num_classes; i++) {
        max_logit = fmaxf(max_logit, batch_logits[i]);
    }
    
    // Compute exp and sum
    float sum = 0.0f;
    for (int i = class_idx; i < num_classes; i += blockDim.x) {
        float exp_val = expf(batch_logits[i] - max_logit);
        batch_output[i] = exp_val;
        sum += exp_val;
    }
    
    // Normalize
    for (int i = class_idx; i < num_classes; i += blockDim.x) {
        batch_output[i] /= sum;
    }
}

float* neurx_softmax_forward(int batch_size, int num_classes, const float* logits) {
    float* output;
    cudaMalloc(&output, batch_size * num_classes * sizeof(float));
    
    softmax_forward_kernel<<<batch_size, 256>>>(batch_size, num_classes, logits, output);
    
    cudaDeviceSynchronize();
    return output;
}

// Kernel: Cross-entropy backward
__global__ void cross_entropy_backward_kernel(int batch_size, int num_classes,
                                             const float* probs,
                                             const int* targets,
                                             float* dlogits) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
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
    
    cudaDeviceSynchronize();
    return 0;
}

// ============================================================================
// ADAM OPTIMIZER
// ============================================================================

__global__ void adam_step_kernel(int param_count,
                                 float* params,
                                 const float* grads,
                                 float* m, float* v,
                                 float lr, float beta1, float beta2, float eps,
                                 float weight_decay, int step) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= param_count) return;
    
    float grad = grads[idx];
    float param = params[idx];
    
    // Decay by weight decay
    grad += weight_decay * param;
    
    // Update biased first moment estimate
    m[idx] = beta1 * m[idx] + (1.0f - beta1) * grad;
    
    // Update biased second raw moment estimate
    v[idx] = beta2 * v[idx] + (1.0f - beta2) * grad * grad;
    
    // Compute bias-corrected first moment estimate
    float m_hat = m[idx] / (1.0f - powf(beta1, step));
    
    // Compute bias-corrected second raw moment estimate
    float v_hat = v[idx] / (1.0f - powf(beta2, step));
    
    // Update parameters
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
    
    cudaDeviceSynchronize();
    return 0;
}

// ============================================================================
// UTILITIES
// ============================================================================

int neurx_cuda_synchronize() {
    cudaError_t err = cudaDeviceSynchronize();
    return (err == cudaSuccess) ? 0 : -1;
}

const char* neurx_cuda_get_error_string(int error_code) {
    return cudaGetErrorString((cudaError_t)error_code);
}
