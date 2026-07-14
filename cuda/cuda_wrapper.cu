/* ============================================================================
   NeurX CUDA Runtime C Wrapper Implementation
   Provides cuBLAS and custom CUDA kernel bindings
   ============================================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdint.h>

/* ============================================================================
   Memory Management
   ============================================================================ */

int64_t cuda_malloc(int size) {
    void *ptr = NULL;
    cudaError_t err = cudaMalloc(&ptr, size);
    if (err != cudaSuccess) {
        fprintf(stderr, "[CUDA] cudaMalloc failed: %s\n", cudaGetErrorString(err));
        return 0;
    }
    return (int64_t)ptr;
}

int cuda_free(int64_t ptr) {
    cudaError_t err = cudaFree((void*)ptr);
    if (err != cudaSuccess) {
        fprintf(stderr, "[CUDA] cudaFree failed: %s\n", cudaGetErrorString(err));
        return -1;
    }
    return 0;
}

int cuda_memcpy_h2d(int64_t dst, int src_ptr, int size) {
    cudaError_t err = cudaMemcpy(
        (void*)dst, 
        (void*)src_ptr, 
        size, 
        cudaMemcpyHostToDevice
    );
    if (err != cudaSuccess) {
        fprintf(stderr, "[CUDA] cudaMemcpy H2D failed: %s\n", cudaGetErrorString(err));
        return -1;
    }
    return 0;
}

int cuda_memcpy_d2h(int dst_ptr, int64_t src, int size) {
    cudaError_t err = cudaMemcpy(
        (void*)dst_ptr,
        (void*)src,
        size,
        cudaMemcpyDeviceToHost
    );
    if (err != cudaSuccess) {
        fprintf(stderr, "[CUDA] cudaMemcpy D2H failed: %s\n", cudaGetErrorString(err));
        return -1;
    }
    return 0;
}

int cuda_device_synchronize() {
    cudaError_t err = cudaDeviceSynchronize();
    if (err != cudaSuccess) {
        fprintf(stderr, "[CUDA] cudaDeviceSynchronize failed: %s\n", cudaGetErrorString(err));
        return -1;
    }
    return 0;
}

/* ============================================================================
   cuBLAS Wrapper Functions
   ============================================================================ */

int64_t cublasCreate() {
    cublasHandle_t handle = NULL;
    cublasStatus_t status = cublasCreate(&handle);
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuBLAS] cublasCreate failed: %d\n", status);
        return 0;
    }
    return (int64_t)handle;
}

int cublasDestroy(int64_t handle) {
    cublasStatus_t status = cublasDestroy((cublasHandle_t)handle);
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuBLAS] cublasDestroy failed: %d\n", status);
        return -1;
    }
    return 0;
}

int cublasSetStream(int64_t handle, int64_t stream) {
    cublasStatus_t status = cublasSetStream((cublasHandle_t)handle, (cudaStream_t)stream);
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuBLAS] cublasSetStream failed: %d\n", status);
        return -1;
    }
    return 0;
}

// Single Precision General Matrix Multiply: C = alpha*op(A)*op(B) + beta*C
int cublasSgemm(
    int64_t handle,
    int transa,
    int transb,
    int m, int n, int k,
    float alpha,
    int64_t A, int lda,
    int64_t B, int ldb,
    float beta,
    int64_t C, int ldc
) {
    cublasOperation_t opA = (transa == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    cublasOperation_t opB = (transb == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    
    cublasStatus_t status = cublasSgemm(
        (cublasHandle_t)handle,
        opA, opB,
        m, n, k,
        &alpha,
        (const float*)A, lda,
        (const float*)B, ldb,
        &beta,
        (float*)C, ldc
    );
    
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuBLAS] cublasSgemm failed: %d\n", status);
        return -1;
    }
    return 0;
}

// Single Precision General Matrix-Vector Multiply: y = alpha*op(A)*x + beta*y
int cublasSgemv(
    int64_t handle,
    int trans,
    int m, int n,
    float alpha,
    int64_t A, int lda,
    int64_t x, int incx,
    float beta,
    int64_t y, int incy
) {
    cublasOperation_t op = (trans == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    
    cublasStatus_t status = cublasSgemv(
        (cublasHandle_t)handle,
        op,
        m, n,
        &alpha,
        (const float*)A, lda,
        (const float*)x, incx,
        &beta,
        (float*)y, incy
    );
    
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuBLAS] cublasSgemv failed: %d\n", status);
        return -1;
    }
    return 0;
}

// Vector Dot Product: result = x^T * y
int cublasSdot(
    int64_t handle,
    int n,
    int64_t x, int incx,
    int64_t y, int incy,
    float* result
) {
    cublasStatus_t status = cublasSdot(
        (cublasHandle_t)handle,
        n,
        (const float*)x, incx,
        (const float*)y, incy,
        result
    );
    
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuBLAS] cublasSdot failed: %d\n", status);
        return -1;
    }
    return 0;
}

// Triangular Matrix-Matrix Multiply
int cublasStrmm_wrapper(
    int64_t handle,
    int side,
    int uplo,
    int transa,
    int diag,
    int m, int n,
    float alpha,
    int64_t A, int lda,
    int64_t B, int ldb
) {
    cublasSideMode_t sideMode = (side == 0) ? CUBLAS_SIDE_LEFT : CUBLAS_SIDE_RIGHT;
    cublasFillMode_t fillMode = (uplo == 0) ? CUBLAS_FILL_MODE_LOWER : CUBLAS_FILL_MODE_UPPER;
    cublasOperation_t opA = (transa == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    cublasDiagType_t diagType = (diag == 0) ? CUBLAS_DIAG_NON_UNIT : CUBLAS_DIAG_UNIT;
    
    cublasStatus_t status = cublasStrmm_v2(
        (cublasHandle_t)handle,
        sideMode,
        fillMode,
        opA,
        diagType,
        m, n,
        &alpha,
        (const float*)A, lda,
        (float*)B, ldb
    );
    
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuBLAS] cublasStrmm_v2 failed: %d\n", status);
        return -1;
    }
    return 0;
}

/* ============================================================================
   Custom CUDA Kernels - Activation Functions
   ============================================================================ */

// ReLU activation kernel
__global__ void relu_kernel(float *out, const float *in, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        out[idx] = (in[idx] > 0.0f) ? in[idx] : 0.0f;
    }
}

// ReLU backward kernel
__global__ void relu_backward_kernel(float *grad_in, const float *grad_out, const float *in, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        grad_in[idx] = (in[idx] > 0.0f) ? grad_out[idx] : 0.0f;
    }
}

int cuda_relu_forward(int64_t output, int64_t input, int size) {
    int threadsPerBlock = 256;
    int blocksPerGrid = (size + threadsPerBlock - 1) / threadsPerBlock;
    
    relu_kernel<<<blocksPerGrid, threadsPerBlock>>>((float*)output, (const float*)input, size);
    
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "[CUDA] relu_kernel failed: %s\n", cudaGetErrorString(err));
        return -1;
    }
    return 0;
}

int cuda_relu_backward(int64_t grad_input, int64_t grad_output, int64_t input, int size) {
    int threadsPerBlock = 256;
    int blocksPerGrid = (size + threadsPerBlock - 1) / threadsPerBlock;
    
    relu_backward_kernel<<<blocksPerGrid, threadsPerBlock>>>((float*)grad_input, (const float*)grad_output, (const float*)input, size);
    
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "[CUDA] relu_backward_kernel failed: %s\n", cudaGetErrorString(err));
        return -1;
    }
    return 0;
}

/* ============================================================================
   Softmax Kernel for Attention
   ============================================================================ */

__global__ void softmax_kernel(float *out, const float *in, int seq_len, int batch_size) {
    int b = blockIdx.x;
    int i = threadIdx.x;
    
    if (b < batch_size && i < seq_len) {
        int idx = b * seq_len + i;
        
        // Find max for numerical stability
        float maxval = in[b * seq_len];
        for (int j = 0; j < seq_len; j++) {
            maxval = fmaxf(maxval, in[b * seq_len + j]);
        }
        
        // Compute exp and sum
        float sum = 0.0f;
        for (int j = 0; j < seq_len; j++) {
            sum += expf(in[b * seq_len + j] - maxval);
        }
        
        // Compute softmax
        out[idx] = expf(in[idx] - maxval) / sum;
    }
}

int cuda_softmax(int64_t output, int64_t input, int seq_len, int batch_size) {
    softmax_kernel<<<batch_size, seq_len>>>((float*)output, (const float*)input, seq_len, batch_size);
    
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "[CUDA] softmax_kernel failed: %s\n", cudaGetErrorString(err));
        return -1;
    }
    return 0;
}

/* ============================================================================
   Debug & Utility Functions
   ============================================================================ */

int cuda_get_device_count() {
    int count = 0;
    cudaError_t err = cudaGetDeviceCount(&count);
    if (err != cudaSuccess) {
        fprintf(stderr, "[CUDA] cudaGetDeviceCount failed: %s\n", cudaGetErrorString(err));
        return 0;
    }
    return count;
}

int cuda_set_device(int device_id) {
    cudaError_t err = cudaSetDevice(device_id);
    if (err != cudaSuccess) {
        fprintf(stderr, "[CUDA] cudaSetDevice failed: %s\n", cudaGetErrorString(err));
        return -1;
    }
    return 0;
}
