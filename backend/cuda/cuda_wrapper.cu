#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdint.h>
int64_t cuda_malloc(int size) {
    void *ptr = NULL;
    cuda_error_t err = cuda_malloc(&ptr, size);
    if (err != cuda_success) {
        fprintf(stderr, "[CUDA] cudaMalloc failed: %s\n", cuda_get_error_string(err));
        return 0;
    }
    return (int64_t)ptr;
}
int cuda_free(int64_t ptr) {
    cuda_error_t err = cuda_free((void*)ptr);
    if (err != cuda_success) {
        fprintf(stderr, "[CUDA] cudaFree failed: %s\n", cuda_get_error_string(err));
        return -1;
    }
    return 0;
}
int cuda_memcpy_h2d(int64_t dst, int src_ptr, int size) {
    cuda_error_t err = cuda_memcpy(
        (void*)dst,
        (void*)src_ptr,
        size,
        cuda_memcpy_host_to_device
    );
    if (err != cuda_success) {
        fprintf(stderr, "[CUDA] cudaMemcpy H2D failed: %s\n", cuda_get_error_string(err));
        return -1;
    }
    return 0;
}
int cuda_memcpy_d2h(int dst_ptr, int64_t src, int size) {
    cuda_error_t err = cuda_memcpy(
        (void*)dst_ptr,
        (void*)src,
        size,
        cuda_memcpy_device_to_host
    );
    if (err != cuda_success) {
        fprintf(stderr, "[CUDA] cudaMemcpy D2H failed: %s\n", cuda_get_error_string(err));
        return -1;
    }
    return 0;
}
int cuda_device_synchronize() {
    cuda_error_t err = cuda_device_synchronize();
    if (err != cuda_success) {
        fprintf(stderr, "[CUDA] cudaDeviceSynchronize failed: %s\n", cuda_get_error_string(err));
        return -1;
    }
    return 0;
}
int64_t cublas_create() {
    cublas_handle_t handle = NULL;
    cublas_status_t status = cublas_create(&handle);
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuBLAS] cublasCreate failed: %d\n", status);
        return 0;
    }
    return (int64_t)handle;
}
int cublas_destroy(int64_t handle) {
    cublas_status_t status = cublas_destroy((cublas_handle_t)handle);
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuBLAS] cublasDestroy failed: %d\n", status);
        return -1;
    }
    return 0;
}
int cublas_set_stream(int64_t handle, int64_t stream) {
    cublas_status_t status = cublas_set_stream((cublas_handle_t)handle, (cuda_stream_t)stream);
    if (status != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[cuBLAS] cublasSetStream failed: %d\n", status);
        return -1;
    }
    return 0;
}
int cublas_sgemm(
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
    cublas_operation_t op_a = (transa == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    cublas_operation_t op_b = (transb == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    cublas_status_t status = cublas_sgemm(
        (cublas_handle_t)handle,
        op_a, op_b,
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
int cublas_sgemv(
    int64_t handle,
    int trans,
    int m, int n,
    float alpha,
    int64_t A, int lda,
    int64_t x, int incx,
    float beta,
    int64_t y, int incy
) {
    cublas_operation_t op = (trans == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    cublas_status_t status = cublas_sgemv(
        (cublas_handle_t)handle,
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
int cublas_sdot(
    int64_t handle,
    int n,
    int64_t x, int incx,
    int64_t y, int incy,
    float* result
) {
    cublas_status_t status = cublas_sdot(
        (cublas_handle_t)handle,
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
int cublas_strmm_wrapper(
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
    cublas_side_mode_t side_mode = (side == 0) ? CUBLAS_SIDE_LEFT : CUBLAS_SIDE_RIGHT;
    cublas_fill_mode_t fill_mode = (uplo == 0) ? CUBLAS_FILL_MODE_LOWER : CUBLAS_FILL_MODE_UPPER;
    cublas_operation_t op_a = (transa == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    cublas_diag_type_t diag_type = (diag == 0) ? CUBLAS_DIAG_NON_UNIT : CUBLAS_DIAG_UNIT;
    cublas_status_t status = cublas_strmm_v2(
        (cublas_handle_t)handle,
        side_mode,
        fill_mode,
        op_a,
        diag_type,
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
__global__ void relu_kernel(float *out, const float *in, int n) {
    int idx = block_idx.x * block_dim.x + thread_idx.x;
    if (idx < n) {
        out[idx] = (in[idx] > 0.0f) ? in[idx] : 0.0f;
    }
}
__global__ void relu_backward_kernel(float *grad_in, const float *grad_out, const float *in, int n) {
    int idx = block_idx.x * block_dim.x + thread_idx.x;
    if (idx < n) {
        grad_in[idx] = (in[idx] > 0.0f) ? grad_out[idx] : 0.0f;
    }
}
int cuda_relu_forward(int64_t output, int64_t input, int size) {
    int threads_per_block = 256;
    int blocks_per_grid = (size + threads_per_block - 1) / threads_per_block;
    relu_kernel<<<blocks_per_grid, threads_per_block>>>((float*)output, (const float*)input, size);
    cuda_error_t err = cuda_get_last_error();
    if (err != cuda_success) {
        fprintf(stderr, "[CUDA] relu_kernel failed: %s\n", cuda_get_error_string(err));
        return -1;
    }
    return 0;
}
int cuda_relu_backward(int64_t grad_input, int64_t grad_output, int64_t input, int size) {
    int threads_per_block = 256;
    int blocks_per_grid = (size + threads_per_block - 1) / threads_per_block;
    relu_backward_kernel<<<blocks_per_grid, threads_per_block>>>((float*)grad_input, (const float*)grad_output, (const float*)input, size);
    cuda_error_t err = cuda_get_last_error();
    if (err != cuda_success) {
        fprintf(stderr, "[CUDA] relu_backward_kernel failed: %s\n", cuda_get_error_string(err));
        return -1;
    }
    return 0;
}
__global__ void softmax_kernel(float *out, const float *in, int seq_len, int batch_size) {
    int b = block_idx.x;
    int i = thread_idx.x;
    if (b < batch_size && i < seq_len) {
        int idx = b * seq_len + i;
        float maxval = in[b * seq_len];
        for (int j = 0; j < seq_len; j++) {
            maxval = fmaxf(maxval, in[b * seq_len + j]);
        }
        float sum = 0.0f;
        for (int j = 0; j < seq_len; j++) {
            sum += expf(in[b * seq_len + j] - maxval);
        }
        out[idx] = expf(in[idx] - maxval) / sum;
    }
}
int cuda_softmax(int64_t output, int64_t input, int seq_len, int batch_size) {
    softmax_kernel<<<batch_size, seq_len>>>((float*)output, (const float*)input, seq_len, batch_size);
    cuda_error_t err = cuda_get_last_error();
    if (err != cuda_success) {
        fprintf(stderr, "[CUDA] softmax_kernel failed: %s\n", cuda_get_error_string(err));
        return -1;
    }
    return 0;
}
int cuda_get_device_count() {
    int count = 0;
    cuda_error_t err = cuda_get_device_count(&count);
    if (err != cuda_success) {
        fprintf(stderr, "[CUDA] cudaGetDeviceCount failed: %s\n", cuda_get_error_string(err));
        return 0;
    }
    return count;
}
int cuda_set_device(int device_id) {
    cuda_error_t err = cuda_set_device(device_id);
    if (err != cuda_success) {
        fprintf(stderr, "[CUDA] cudaSetDevice failed: %s\n", cuda_get_error_string(err));
        return -1;
    }
    return 0;
}
