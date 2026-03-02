#include <cuda_runtime.h>
#include <cub/cub.cuh>

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

extern "C" __global__ void add_bias_f32_kernel(const float* a, const float* b, float* out, int m, int n) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    if (row < m && col < n) {
        out[row * n + col] = a[row * n + col] + b[col];
    }
}

extern "C" __global__ void add_bias_3d_f32_kernel(const float* a, const float* b, float* out, int bsz, int t, int c) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = bsz * t * c;
    if (idx < total) {
        int col = idx % c;
        out[idx] = a[idx] + b[col];
    }
}

extern "C" __global__ void layernorm_f32_kernel(const float* x, const float* gamma, const float* beta, float* out, int m, int n, float eps) {
    int row = blockIdx.x;
    if (row >= m) {
        return;
    }
    extern __shared__ float sdata[];
    float* smean = sdata;
    float* svar = sdata + blockDim.x;

    float sum = 0.0f;
    float sumsq = 0.0f;
    for (int col = threadIdx.x; col < n; col += blockDim.x) {
        float v = x[row * n + col];
        sum += v;
        sumsq += v * v;
    }
    smean[threadIdx.x] = sum;
    svar[threadIdx.x] = sumsq;
    __syncthreads();

    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (threadIdx.x < stride) {
            smean[threadIdx.x] += smean[threadIdx.x + stride];
            svar[threadIdx.x] += svar[threadIdx.x + stride];
        }
        __syncthreads();
    }

    float mean = smean[0] / n;
    float var = svar[0] / n - mean * mean;
    float inv_std = rsqrtf(var + eps);

    for (int col = threadIdx.x; col < n; col += blockDim.x) {
        float v = x[row * n + col];
        float norm = (v - mean) * inv_std;
        out[row * n + col] = norm * gamma[col] + beta[col];
    }
}

extern "C" __global__ void softmax_f32_kernel(const float* x, float* out, int m, int n) {
    int row = blockIdx.x;
    if (row >= m) {
        return;
    }
    extern __shared__ float sdata[];
    float* smax = sdata;
    float* ssum = sdata + blockDim.x;

    float maxv = -1e20f;
    for (int col = threadIdx.x; col < n; col += blockDim.x) {
        float v = x[row * n + col];
        if (v > maxv) maxv = v;
    }
    smax[threadIdx.x] = maxv;
    __syncthreads();
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (threadIdx.x < stride) {
            float v = smax[threadIdx.x + stride];
            if (v > smax[threadIdx.x]) smax[threadIdx.x] = v;
        }
        __syncthreads();
    }
    float row_max = smax[0];

    float sum = 0.0f;
    for (int col = threadIdx.x; col < n; col += blockDim.x) {
        sum += expf(x[row * n + col] - row_max);
    }
    ssum[threadIdx.x] = sum;
    __syncthreads();
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (threadIdx.x < stride) {
            ssum[threadIdx.x] += ssum[threadIdx.x + stride];
        }
        __syncthreads();
    }
    float denom = ssum[0] + 1e-12f;

    for (int col = threadIdx.x; col < n; col += blockDim.x) {
        out[row * n + col] = expf(x[row * n + col] - row_max) / denom;
    }
}

extern "C" __global__ void reduce_sum_lastdim_f32_kernel(const float* x, float* out, int m, int n) {
    int row = blockIdx.x;
    if (row >= m) return;
    extern __shared__ float sdata[];
    float sum = 0.0f;
    for (int col = threadIdx.x; col < n; col += blockDim.x) {
        sum += x[row * n + col];
    }
    sdata[threadIdx.x] = sum;
    __syncthreads();
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (threadIdx.x < stride) {
            sdata[threadIdx.x] += sdata[threadIdx.x + stride];
        }
        __syncthreads();
    }
    if (threadIdx.x == 0) {
        out[row] = sdata[0];
    }
}

extern "C" __global__ void reduce_max_lastdim_f32_kernel(const float* x, float* out, int m, int n) {
    int row = blockIdx.x;
    if (row >= m) return;
    extern __shared__ float sdata[];
    float maxv = -1e20f;
    for (int col = threadIdx.x; col < n; col += blockDim.x) {
        float v = x[row * n + col];
        if (v > maxv) maxv = v;
    }
    sdata[threadIdx.x] = maxv;
    __syncthreads();
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (threadIdx.x < stride) {
            float v = sdata[threadIdx.x + stride];
            if (v > sdata[threadIdx.x]) sdata[threadIdx.x] = v;
        }
        __syncthreads();
    }
    if (threadIdx.x == 0) {
        out[row] = sdata[0];
    }
}

extern "C" __global__ void reduce_min_lastdim_f32_kernel(const float* x, float* out, int m, int n) {
    int row = blockIdx.x;
    if (row >= m) return;
    extern __shared__ float sdata[];
    float minv = 1e20f;
    for (int col = threadIdx.x; col < n; col += blockDim.x) {
        float v = x[row * n + col];
        if (v < minv) minv = v;
    }
    sdata[threadIdx.x] = minv;
    __syncthreads();
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (threadIdx.x < stride) {
            float v = sdata[threadIdx.x + stride];
            if (v < sdata[threadIdx.x]) sdata[threadIdx.x] = v;
        }
        __syncthreads();
    }
    if (threadIdx.x == 0) {
        out[row] = sdata[0];
    }
}

extern "C" __global__ void reduce_mean_lastdim_f32_kernel(const float* x, float* out, int m, int n) {
    int row = blockIdx.x;
    if (row >= m) return;
    extern __shared__ float sdata[];
    float sum = 0.0f;
    for (int col = threadIdx.x; col < n; col += blockDim.x) {
        sum += x[row * n + col];
    }
    sdata[threadIdx.x] = sum;
    __syncthreads();
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (threadIdx.x < stride) {
            sdata[threadIdx.x] += sdata[threadIdx.x + stride];
        }
        __syncthreads();
    }
    if (threadIdx.x == 0) {
        out[row] = sdata[0] / n;
    }
}

extern "C" __global__ void transpose_2d_f32_kernel(const float* x, float* out, int m, int n) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    if (row < m && col < n) {
        out[col * m + row] = x[row * n + col];
    }
}

extern "C" __global__ void permute_3d_0_2_1_f32_kernel(const float* x, float* out, int b, int t, int c) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = b * t * c;
    if (idx < total) {
        int bi = idx / (t * c);
        int rem = idx % (t * c);
        int ti = rem / c;
        int ci = rem % c;
        int out_idx = bi * (c * t) + ci * t + ti;
        out[out_idx] = x[idx];
    }
}

extern "C" __global__ void permute_3d_1_2_0_f32_kernel(const float* x, float* out, int b, int t, int c) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = b * t * c;
    if (idx < total) {
        int bi = idx / (t * c);
        int rem = idx % (t * c);
        int ti = rem / c;
        int ci = rem % c;
        int out_idx = ti * (c * b) + ci * b + bi;
        out[out_idx] = x[idx];
    }
}

extern "C" __global__ void argmax_lastdim_f32_kernel(const float* x, int* out, int m, int n) {
    int row = blockIdx.x;
    if (row >= m) return;
    extern __shared__ float smax[];
    __shared__ int sidx[256];

    float maxv = -1e20f;
    int maxidx = 0;
    for (int col = threadIdx.x; col < n; col += blockDim.x) {
        float v = x[row * n + col];
        if (v > maxv) {
            maxv = v;
            maxidx = col;
        }
    }
    smax[threadIdx.x] = maxv;
    sidx[threadIdx.x] = maxidx;
    __syncthreads();
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (threadIdx.x < stride) {
            float v = smax[threadIdx.x + stride];
            int idx = sidx[threadIdx.x + stride];
            if (v > smax[threadIdx.x]) {
                smax[threadIdx.x] = v;
                sidx[threadIdx.x] = idx;
            }
        }
        __syncthreads();
    }
    if (threadIdx.x == 0) {
        out[row] = sidx[0];
    }
}

extern "C" __global__ void argmin_lastdim_f32_kernel(const float* x, int* out, int m, int n) {
    int row = blockIdx.x;
    if (row >= m) return;
    extern __shared__ float smin[];
    __shared__ int sidx[256];

    float minv = 1e20f;
    int minidx = 0;
    for (int col = threadIdx.x; col < n; col += blockDim.x) {
        float v = x[row * n + col];
        if (v < minv) {
            minv = v;
            minidx = col;
        }
    }
    smin[threadIdx.x] = minv;
    sidx[threadIdx.x] = minidx;
    __syncthreads();
    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (threadIdx.x < stride) {
            float v = smin[threadIdx.x + stride];
            int idx = sidx[threadIdx.x + stride];
            if (v < smin[threadIdx.x]) {
                smin[threadIdx.x] = v;
                sidx[threadIdx.x] = idx;
            }
        }
        __syncthreads();
    }
    if (threadIdx.x == 0) {
        out[row] = sidx[0];
    }
}

extern "C" __global__ void matmul_f32_kernel(const float* a, const float* b, float* out, int m, int k, int n) {
    const int TILE = 16;
    __shared__ float As[TILE][TILE];
    __shared__ float Bs[TILE][TILE];

    int row = blockIdx.y * TILE + threadIdx.y;
    int col = blockIdx.x * TILE + threadIdx.x;

    float sum = 0.0f;
    for (int t = 0; t < (k + TILE - 1) / TILE; ++t) {
        int a_col = t * TILE + threadIdx.x;
        int b_row = t * TILE + threadIdx.y;

        As[threadIdx.y][threadIdx.x] = (row < m && a_col < k) ? a[row * k + a_col] : 0.0f;
        Bs[threadIdx.y][threadIdx.x] = (b_row < k && col < n) ? b[b_row * n + col] : 0.0f;
        __syncthreads();

        for (int i = 0; i < TILE; ++i) {
            sum += As[threadIdx.y][i] * Bs[i][threadIdx.x];
        }
        __syncthreads();
    }

    if (row < m && col < n) {
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

extern "C" void cuda_add_bias_device_float(const float* a, const float* b, float* out, int m, int n) {
    dim3 block(16, 16);
    dim3 grid((n + block.x - 1) / block.x, (m + block.y - 1) / block.y);
    add_bias_f32_kernel<<<grid, block>>>(a, b, out, m, n);
}

extern "C" void cuda_add_bias_3d_device_float(const float* a, const float* b, float* out, int bsz, int t, int c) {
    int total = bsz * t * c;
    dim3 block(256);
    dim3 grid((total + block.x - 1) / block.x);
    add_bias_3d_f32_kernel<<<grid, block>>>(a, b, out, bsz, t, c);
}

extern "C" void cuda_layernorm_device_float(const float* a, const float* gamma, const float* beta, float* out, int m, int n, float eps) {
    int threads = 256;
    dim3 block(threads);
    dim3 grid(m);
    size_t shmem = sizeof(float) * threads * 2;
    layernorm_f32_kernel<<<grid, block, shmem>>>(a, gamma, beta, out, m, n, eps);
}

extern "C" void cuda_softmax_device_float(const float* a, float* out, int m, int n) {
    int threads = 256;
    dim3 block(threads);
    dim3 grid(m);
    size_t shmem = sizeof(float) * threads * 2;
    softmax_f32_kernel<<<grid, block, shmem>>>(a, out, m, n);
}

extern "C" void cuda_matmul_device_float(const float* a, const float* b, float* out, int m, int k, int n) {
    dim3 block(16, 16);
    dim3 grid((n + block.x - 1) / block.x, (m + block.y - 1) / block.y);
    matmul_f32_kernel<<<grid, block>>>(a, b, out, m, k, n);
}

extern "C" void cuda_reduce_sum_lastdim_device_float(const float* a, float* out, int m, int n) {
    int threads = 256;
    dim3 block(threads);
    dim3 grid(m);
    size_t shmem = sizeof(float) * threads;
    reduce_sum_lastdim_f32_kernel<<<grid, block, shmem>>>(a, out, m, n);
}

extern "C" void cuda_reduce_max_lastdim_device_float(const float* a, float* out, int m, int n) {
    int threads = 256;
    dim3 block(threads);
    dim3 grid(m);
    size_t shmem = sizeof(float) * threads;
    reduce_max_lastdim_f32_kernel<<<grid, block, shmem>>>(a, out, m, n);
}

extern "C" void cuda_reduce_min_lastdim_device_float(const float* a, float* out, int m, int n) {
    int threads = 256;
    dim3 block(threads);
    dim3 grid(m);
    size_t shmem = sizeof(float) * threads;
    reduce_min_lastdim_f32_kernel<<<grid, block, shmem>>>(a, out, m, n);
}

extern "C" void cuda_reduce_mean_lastdim_device_float(const float* a, float* out, int m, int n) {
    int threads = 256;
    dim3 block(threads);
    dim3 grid(m);
    size_t shmem = sizeof(float) * threads;
    reduce_mean_lastdim_f32_kernel<<<grid, block, shmem>>>(a, out, m, n);
}

extern "C" void cuda_transpose_2d_device_float(const float* a, float* out, int m, int n) {
    dim3 block(16, 16);
    dim3 grid((n + block.x - 1) / block.x, (m + block.y - 1) / block.y);
    transpose_2d_f32_kernel<<<grid, block>>>(a, out, m, n);
}

extern "C" void cuda_permute_3d_0_2_1_device_float(const float* a, float* out, int b, int t, int c) {
    int total = b * t * c;
    dim3 block(256);
    dim3 grid((total + block.x - 1) / block.x);
    permute_3d_0_2_1_f32_kernel<<<grid, block>>>(a, out, b, t, c);
}

extern "C" void cuda_permute_3d_1_2_0_device_float(const float* a, float* out, int b, int t, int c) {
    int total = b * t * c;
    dim3 block(256);
    dim3 grid((total + block.x - 1) / block.x);
    permute_3d_1_2_0_f32_kernel<<<grid, block>>>(a, out, b, t, c);
}

extern "C" void cuda_argmax_lastdim_device_int(const float* a, int* out, int m, int n) {
    int threads = 256;
    dim3 block(threads);
    dim3 grid(m);
    size_t shmem = sizeof(float) * threads;
    argmax_lastdim_f32_kernel<<<grid, block, shmem>>>(a, out, m, n);
}

extern "C" void cuda_argmin_lastdim_device_int(const float* a, int* out, int m, int n) {
    int threads = 256;
    dim3 block(threads);
    dim3 grid(m);
    size_t shmem = sizeof(float) * threads;
    argmin_lastdim_f32_kernel<<<grid, block, shmem>>>(a, out, m, n);
}

extern "C" void cuda_reduce_sum_device_float(const float* a, float* out, size_t n) {
    void* d_temp = nullptr;
    size_t temp_bytes = 0;
    cub::DeviceReduce::Sum(d_temp, temp_bytes, a, out, n);
    cudaMalloc(&d_temp, temp_bytes);
    cub::DeviceReduce::Sum(d_temp, temp_bytes, a, out, n);
    cudaFree(d_temp);
}

extern "C" void cuda_reduce_max_device_float(const float* a, float* out, size_t n) {
    void* d_temp = nullptr;
    size_t temp_bytes = 0;
    cub::DeviceReduce::Max(d_temp, temp_bytes, a, out, n);
    cudaMalloc(&d_temp, temp_bytes);
    cub::DeviceReduce::Max(d_temp, temp_bytes, a, out, n);
    cudaFree(d_temp);
}

extern "C" void cuda_reduce_min_device_float(const float* a, float* out, size_t n) {
    void* d_temp = nullptr;
    size_t temp_bytes = 0;
    cub::DeviceReduce::Min(d_temp, temp_bytes, a, out, n);
    cudaMalloc(&d_temp, temp_bytes);
    cub::DeviceReduce::Min(d_temp, temp_bytes, a, out, n);
    cudaFree(d_temp);
}

extern "C" __global__ void scale_f32_kernel(float* a, float scale) {
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx == 0) {
        a[0] *= scale;
    }
}

extern "C" void cuda_reduce_mean_device_float(const float* a, float* out, size_t n) {
    cuda_reduce_sum_device_float(a, out, n);
    float scale = 1.0f / static_cast<float>(n);
    dim3 block(1);
    dim3 grid(1);
    scale_f32_kernel<<<grid, block>>>(out, scale);
}
