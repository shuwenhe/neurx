

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cmath>

__global__ void error_loss_kernel(
    float *pred, const float *target, float *loss,
    int n
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    float diff = pred[idx] - target[idx];
    pred[idx] = diff;
    atomicAdd(loss, diff * diff);
}

extern "C" float cuda_error_loss_kernel(
    int64_t pred_ptr, int64_t target_ptr, int size
) {
    float *d_pred = (float*)pred_ptr;
    float *d_target = (float*)target_ptr;
    float *d_loss;

    cudaMalloc(&d_loss, sizeof(float));
    cudaMemset(d_loss, 0, sizeof(float));

    int threads = 256;
    int blocks = (size + threads - 1) / threads;

    error_loss_kernel<<<blocks, threads>>>(d_pred, d_target, d_loss, size);

    float h_loss = 0.0f;
    cudaMemcpy(&h_loss, d_loss, sizeof(float), cudaMemcpyDeviceToHost);
    cudaDeviceSynchronize();

    cudaFree(d_loss);

    return h_loss / static_cast<float>(size);
}

__global__ void sgd_update_kernel(
    float *weights, const float *gradients,
    float lr, float inv_batch, int n
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    weights[idx] -= lr * gradients[idx] * inv_batch;
}

extern "C" int cuda_sgd_update_kernel(
    int64_t weights_ptr, int64_t grads_ptr,
    float lr, int size
) {
    float *d_weights = (float*)weights_ptr;
    float *d_grads = (float*)grads_ptr;

    float inv_batch = 1.0f / 32.0f;

    int threads = 256;
    int blocks = (size + threads - 1) / threads;

    sgd_update_kernel<<<blocks, threads>>>(d_weights, d_grads, lr, inv_batch, size);

    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        return -1;
    }

    cudaDeviceSynchronize();
    return 0;
}

__global__ void relu_forward_kernel(float *out, const float *in, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    out[idx] = (in[idx] > 0.0f) ? in[idx] : 0.0f;
}

__global__ void relu_backward_kernel(
    float *grad_in, const float *grad_out,
    const float *in, int n
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    grad_in[idx] = (in[idx] > 0.0f) ? grad_out[idx] : 0.0f;
}

extern "C" int cuda_relu_forward(
    int64_t output_ptr, int64_t input_ptr, int size
) {
    float *d_output = (float*)output_ptr;
    float *d_input = (float*)input_ptr;

    int threads = 256;
    int blocks = (size + threads - 1) / threads;

    relu_forward_kernel<<<blocks, threads>>>(d_output, d_input, size);

    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) return -1;

    cudaDeviceSynchronize();
    return 0;
}

extern "C" int cuda_relu_backward(
    int64_t grad_input_ptr, int64_t grad_output_ptr,
    int64_t input_ptr, int size
) {
    float *d_grad_input = (float*)grad_input_ptr;
    float *d_grad_output = (float*)grad_output_ptr;
    float *d_input = (float*)input_ptr;

    int threads = 256;
    int blocks = (size + threads - 1) / threads;

    relu_backward_kernel<<<blocks, threads>>>(
        d_grad_input, d_grad_output, d_input, size
    );

    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) return -1;

    cudaDeviceSynchronize();
    return 0;
}

__global__ void softmax_kernel(
    float *out, const float *in,
    int seq_len, int batch_size
) {
    int b = blockIdx.x;
    if (b >= batch_size) return;

    for (int i = threadIdx.x; i < seq_len; i += blockDim.x) {
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

extern "C" int cuda_softmax(
    int64_t output_ptr, int64_t input_ptr,
    int seq_len, int batch_size
) {
    float *d_output = (float*)output_ptr;
    float *d_input = (float*)input_ptr;

    softmax_kernel<<<batch_size, 256>>>(d_output, d_input, seq_len, batch_size);

    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) return -1;

    cudaDeviceSynchronize();
    return 0;
}

__global__ void layer_norm_kernel(
    float *out, const float *in, const float *weight, const float *bias,
    int n, float eps
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    float normalized = in[idx];

    if (weight != nullptr) {
        normalized = normalized * weight[idx];
    }
    if (bias != nullptr) {
        normalized = normalized + bias[idx];
    }

    out[idx] = normalized;
}

extern "C" int cuda_layer_norm(
    int64_t output_ptr, int64_t input_ptr,
    int64_t weight_ptr, int64_t bias_ptr,
    int size, float eps
) {
    float *d_output = (float*)output_ptr;
    float *d_input = (float*)input_ptr;
    float *d_weight = (float*)weight_ptr;
    float *d_bias = (float*)bias_ptr;

    int threads = 256;
    int blocks = (size + threads - 1) / threads;

    layer_norm_kernel<<<blocks, threads>>>(
        d_output, d_input, d_weight, d_bias, size, eps
    );

    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) return -1;

    cudaDeviceSynchronize();
    return 0;
}

extern "C" int cuda_get_device_count() {
    int count = 0;
    cudaGetDeviceCount(&count);
    return count;
}

extern "C" int cuda_get_device_memory(int device_id, int64_t *free_bytes, int64_t *total_bytes) {
    cudaSetDevice(device_id);

    size_t free, total;
    cudaMemGetInfo(&free, &total);

    *free_bytes = static_cast<int64_t>(free);
    *total_bytes = static_cast<int64_t>(total);

    return 0;
}

extern "C" const char* cuda_get_error_string() {
    return cudaGetErrorString(cudaGetLastError());
}
