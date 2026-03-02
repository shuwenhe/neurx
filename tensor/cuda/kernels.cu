#include <cuda_runtime.h>

extern "C" __global__ void add_f32_kernel(const float* a, const float* b, float* out, size_t n) {
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        out[idx] = a[idx] + b[idx];
    }
}

extern "C" __global__ void mul_f32_kernel(const float* a, const float* b, float* out, size_t n) {
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        out[idx] = a[idx] * b[idx];
    }
}

extern "C" __global__ void matmul_f32_kernel(const float* a, const float* b, float* out, int m, int k, int n) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    if (row < m && col < n) {
        float sum = 0.0f;
        const float* a_row = a + row * k;
        for (int i = 0; i < k; ++i) {
            sum += a_row[i] * b[i * n + col];
        }
        out[row * n + col] = sum;
    }
}

extern "C" void cuda_add_device_float(const float* a, const float* b, float* out, size_t n) {
    dim3 block(256);
    dim3 grid((n + block.x - 1) / block.x);
    add_f32_kernel<<<grid, block>>>(a, b, out, n);
}

extern "C" void cuda_mul_device_float(const float* a, const float* b, float* out, size_t n) {
    dim3 block(256);
    dim3 grid((n + block.x - 1) / block.x);
    mul_f32_kernel<<<grid, block>>>(a, b, out, n);
}

extern "C" void cuda_matmul_device_float(const float* a, const float* b, float* out, int m, int k, int n) {
    dim3 block(16, 16);
    dim3 grid((n + block.x - 1) / block.x, (m + block.y - 1) / block.y);
    matmul_f32_kernel<<<grid, block>>>(a, b, out, m, k, n);
}
