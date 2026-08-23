#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdint.h>
extern "C" {
    int64_t cuda_malloc(int size) {
        void *ptr = NULL;
        cuda_malloc(&ptr, size);
        return (int64_t)ptr;
    }
    int cuda_free(int64_t ptr) {
        cuda_free((void*)ptr);
        return 0;
    }
    int cuda_memcpy_h2d(int64_t dst, int src_ptr, int size) {
        cuda_memcpy((void*)dst, (void*)src_ptr, size, cuda_memcpy_host_to_device);
        return 0;
    }
    int cuda_memcpy_d2h(int dst_ptr, int64_t src, int size) {
        cuda_memcpy((void*)dst_ptr, (void*)src, size, cuda_memcpy_device_to_host);
        return 0;
    }
    int cuda_device_synchronize() {
        cuda_device_synchronize();
        return 0;
    }
    int64_t cublas_create_wrapper() {
        cublas_handle_t handle;
        cublas_create_v2(&handle);
        return (int64_t)handle;
    }
    int cublas_destroy_wrapper(int64_t handle) {
        cublas_destroy_v2((cublas_handle_t)handle);
        return 0;
    }
    int cublas_set_stream_wrapper(int64_t handle, int64_t stream) {
        cublas_set_stream_v2((cublas_handle_t)handle, (cuda_stream_t)stream);
        return 0;
    }
    int cublas_sgemm_wrapper(
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
        cublas_sgemm_v2(
            (cublas_handle_t)handle,
            op_a, op_b,
            m, n, k,
            &alpha,
            (const float*)A, lda,
            (const float*)B, ldb,
            &beta,
            (float*)C, ldc
        );
        return 0;
    }
    int cublas_sgemv_wrapper(
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
        cublas_sgemv_v2(
            (cublas_handle_t)handle,
            op, m, n,
            &alpha,
            (const float*)A, lda,
            (const float*)x, incx,
            &beta,
            (float*)y, incy
        );
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
        return 0;
    }
    int cuda_relu_backward(int64_t grad_input, int64_t grad_output, int64_t input, int size) {
        int threads_per_block = 256;
        int blocks_per_grid = (size + threads_per_block - 1) / threads_per_block;
        relu_backward_kernel<<<blocks_per_grid, threads_per_block>>>((float*)grad_input, (const float*)grad_output, (const float*)input, size);
        return 0;
    }
    __global__ void softmax_kernel(float *out, const float *in, int seq_len, int batch_size) {
        int b = block_idx.x;
        int i = thread_idx.x;
        if (b < batch_size && i < seq_len) {
            int idx = b * seq_len + i;
            float maxval = in[b * seq_len];
            for (int j = 0; j < seq_len; j++) {
                float v = in[b * seq_len + j];
                maxval = (v > maxval) ? v : maxval;
            }
            float sum = 0.0f;
            for (int j = 0; j < seq_len; j++) {
                sum += __expf(in[b * seq_len + j] - maxval);
            }
            out[idx] = __expf(in[idx] - maxval) / sum;
        }
    }
    int cuda_softmax(int64_t output, int64_t input, int seq_len, int batch_size) {
        softmax_kernel<<<batch_size, seq_len>>>((float*)output, (const float*)input, seq_len, batch_size);
        return 0;
    }
    int cuda_get_device_count() {
        int count = 0;
        cuda_get_device_count(&count);
        return count;
    }
    int cuda_set_device(int device_id) {
        cuda_set_device(device_id);
        return 0;
    }
}
