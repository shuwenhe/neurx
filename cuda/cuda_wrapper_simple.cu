




#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdint.h>





extern "C" {
    int64_t cuda_malloc(int size) {
        void *ptr = NULL;
        cudaMalloc(&ptr, size);
        return (int64_t)ptr;
    }

    int cuda_free(int64_t ptr) {
        cudaFree((void*)ptr);
        return 0;
    }

    int cuda_memcpy_h2d(int64_t dst, int src_ptr, int size) {
        cudaMemcpy((void*)dst, (void*)src_ptr, size, cudaMemcpyHostToDevice);
        return 0;
    }

    int cuda_memcpy_d2h(int dst_ptr, int64_t src, int size) {
        cudaMemcpy((void*)dst_ptr, (void*)src, size, cudaMemcpyDeviceToHost);
        return 0;
    }

    int cuda_device_synchronize() {
        cudaDeviceSynchronize();
        return 0;
    }





    int64_t cublasCreate_wrapper() {
        cublasHandle_t handle;
        cublasCreate_v2(&handle);
        return (int64_t)handle;
    }

    int cublasDestroy_wrapper(int64_t handle) {
        cublasDestroy_v2((cublasHandle_t)handle);
        return 0;
    }

    int cublasSetStream_wrapper(int64_t handle, int64_t stream) {
        cublasSetStream_v2((cublasHandle_t)handle, (cudaStream_t)stream);
        return 0;
    }





    int cublasSgemm_wrapper(
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

        cublasSgemm_v2(
            (cublasHandle_t)handle,
            opA, opB,
            m, n, k,
            &alpha,
            (const float*)A, lda,
            (const float*)B, ldb,
            &beta,
            (float*)C, ldc
        );
        return 0;
    }





    int cublasSgemv_wrapper(
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

        cublasSgemv_v2(
            (cublasHandle_t)handle,
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
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx < n) {
            out[idx] = (in[idx] > 0.0f) ? in[idx] : 0.0f;
        }
    }

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
        return 0;
    }

    int cuda_relu_backward(int64_t grad_input, int64_t grad_output, int64_t input, int size) {
        int threadsPerBlock = 256;
        int blocksPerGrid = (size + threadsPerBlock - 1) / threadsPerBlock;
        relu_backward_kernel<<<blocksPerGrid, threadsPerBlock>>>((float*)grad_input, (const float*)grad_output, (const float*)input, size);
        return 0;
    }





    __global__ void softmax_kernel(float *out, const float *in, int seq_len, int batch_size) {
        int b = blockIdx.x;
        int i = threadIdx.x;

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
        cudaGetDeviceCount(&count);
        return count;
    }

    int cuda_set_device(int device_id) {
        cudaSetDevice(device_id);
        return 0;
    }

}
