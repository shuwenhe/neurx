#include <cuda_runtime.h>

extern "C" __global__ void add_f32_kernel(const float* a, const float* b, float* out, size_t n) {
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        out[idx] = a[idx] + b[idx];
    }
}

extern "C" __global__ void add_f64_kernel(const double* a, const double* b, double* out, size_t n) {
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

extern "C" __global__ void mul_f64_kernel(const double* a, const double* b, double* out, size_t n) {
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        out[idx] = a[idx] * b[idx];
    }
}

extern "C" void cuda_add_float(const float* a, const float* b, float* out, size_t n) {
    float *d_a = nullptr, *d_b = nullptr, *d_out = nullptr;
    size_t bytes = n * sizeof(float);
    cudaMalloc(&d_a, bytes);
    cudaMalloc(&d_b, bytes);
    cudaMalloc(&d_out, bytes);
    cudaMemcpy(d_a, a, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, b, bytes, cudaMemcpyHostToDevice);
    dim3 block(256);
    dim3 grid((n + block.x - 1) / block.x);
    add_f32_kernel<<<grid, block>>>(d_a, d_b, d_out, n);
    cudaMemcpy(out, d_out, bytes, cudaMemcpyDeviceToHost);
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_out);
}

extern "C" void cuda_add_double(const double* a, const double* b, double* out, size_t n) {
    double *d_a = nullptr, *d_b = nullptr, *d_out = nullptr;
    size_t bytes = n * sizeof(double);
    cudaMalloc(&d_a, bytes);
    cudaMalloc(&d_b, bytes);
    cudaMalloc(&d_out, bytes);
    cudaMemcpy(d_a, a, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, b, bytes, cudaMemcpyHostToDevice);
    dim3 block(256);
    dim3 grid((n + block.x - 1) / block.x);
    add_f64_kernel<<<grid, block>>>(d_a, d_b, d_out, n);
    cudaMemcpy(out, d_out, bytes, cudaMemcpyDeviceToHost);
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_out);
}

extern "C" void cuda_mul_float(const float* a, const float* b, float* out, size_t n) {
    float *d_a = nullptr, *d_b = nullptr, *d_out = nullptr;
    size_t bytes = n * sizeof(float);
    cudaMalloc(&d_a, bytes);
    cudaMalloc(&d_b, bytes);
    cudaMalloc(&d_out, bytes);
    cudaMemcpy(d_a, a, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, b, bytes, cudaMemcpyHostToDevice);
    dim3 block(256);
    dim3 grid((n + block.x - 1) / block.x);
    mul_f32_kernel<<<grid, block>>>(d_a, d_b, d_out, n);
    cudaMemcpy(out, d_out, bytes, cudaMemcpyDeviceToHost);
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_out);
}

extern "C" void cuda_mul_double(const double* a, const double* b, double* out, size_t n) {
    double *d_a = nullptr, *d_b = nullptr, *d_out = nullptr;
    size_t bytes = n * sizeof(double);
    cudaMalloc(&d_a, bytes);
    cudaMalloc(&d_b, bytes);
    cudaMalloc(&d_out, bytes);
    cudaMemcpy(d_a, a, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, b, bytes, cudaMemcpyHostToDevice);
    dim3 block(256);
    dim3 grid((n + block.x - 1) / block.x);
    mul_f64_kernel<<<grid, block>>>(d_a, d_b, d_out, n);
    cudaMemcpy(out, d_out, bytes, cudaMemcpyDeviceToHost);
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_out);
}
