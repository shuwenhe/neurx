/**
 * NVIDIA CUDA Runtime Binding for NeurX
 * Provides C API for S language to call CUDA operations
 */

#ifndef NEURX_CUDA_RUNTIME_BINDING_H
#define NEURX_CUDA_RUNTIME_BINDING_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// DEVICE MANAGEMENT
// ============================================================================

int neurx_cuda_get_device_count();
int neurx_cuda_set_device(int device_id);
const char* neurx_cuda_get_device_name(int device_id);

// ============================================================================
// MEMORY MANAGEMENT (GPU)
// ============================================================================

// Allocate GPU memory
void* neurx_cuda_malloc(size_t size);

// Free GPU memory
int neurx_cuda_free(void* ptr);

// Copy data CPU -> GPU
int neurx_cuda_memcpy_htod(void* dst, const void* src, size_t size);

// Copy data GPU -> CPU
int neurx_cuda_memcpy_dtoh(void* dst, const void* src, size_t size);

// Copy data GPU -> GPU
int neurx_cuda_memcpy_dtod(void* dst, const void* src, size_t size);

// Get free/total GPU memory
int neurx_cuda_get_memory_info(size_t* free_bytes, size_t* total_bytes);

// ============================================================================
// cuBLAS OPERATIONS (Matrix multiply, etc.)
// ============================================================================

// Initialize cuBLAS handle
void* neurx_cublas_create();

// Destroy cuBLAS handle
int neurx_cublas_destroy(void* handle);

// Synchronous matrix multiply: C = alpha*A*B + beta*C
// m, n, k: matrix dimensions
// A: m x k, B: k x n, C: m x n (all on GPU)
int neurx_cublas_sgemm(void* handle,
                       int m, int n, int k,
                       float alpha,
                       const float* A,  // GPU pointer
                       const float* B,  // GPU pointer
                       float beta,
                       float* C);       // GPU pointer

// ============================================================================
// KERNEL EXECUTION (Forward/Backward pass)
// ============================================================================

// Forward pass: y = Wx + b
// Returns GPU pointer to output
float* neurx_linear_forward(int batch_size, int in_features, int out_features,
                            const float* x,      // GPU: batch_size x in_features
                            const float* weight, // GPU: out_features x in_features
                            const float* bias);  // GPU: out_features

// Backward pass: compute gradients for weight, bias, input
int neurx_linear_backward(int batch_size, int in_features, int out_features,
                          const float* dy,       // GPU: batch_size x out_features (gradient of output)
                          const float* x,        // GPU: batch_size x in_features (forward input)
                          const float* weight,   // GPU: out_features x in_features
                          float* dx,             // GPU: batch_size x in_features (output gradient)
                          float* dw,             // GPU: out_features x in_features (weight gradient)
                          float* db);            // GPU: out_features (bias gradient)

// ReLU forward: y = max(0, x)
float* neurx_relu_forward(int size, const float* x);

// ReLU backward: dx = dy * (x > 0)
int neurx_relu_backward(int size, const float* dy, const float* x, float* dx);

// Softmax forward: for numerical stability
float* neurx_softmax_forward(int batch_size, int num_classes, const float* logits);

// Cross-entropy loss backward
int neurx_cross_entropy_backward(int batch_size, int num_classes,
                                 const float* probs,  // GPU: softmax output
                                 const int* targets,  // GPU: target class indices
                                 float* dlogits);     // GPU output: gradient

// ============================================================================
// TRAINING UTILITIES
// ============================================================================

// Adam optimizer step: update parameters
// params: current parameters
// grads: computed gradients
// m, v: first/second moment estimates
// lr: learning rate
// beta1, beta2: momentum coefficients
// eps: numerical stability
int neurx_adam_step(int param_count,
                    float* params,      // GPU
                    const float* grads, // GPU
                    float* m,           // GPU: first moment
                    float* v,           // GPU: second moment
                    float lr,
                    float beta1, float beta2, float eps, float weight_decay,
                    int step);

// Synchronize GPU
int neurx_cuda_synchronize();

// ============================================================================
// ERROR HANDLING
// ============================================================================

const char* neurx_cuda_get_error_string(int error_code);

#ifdef __cplusplus
}
#endif

#endif  // NEURX_CUDA_RUNTIME_BINDING_H
