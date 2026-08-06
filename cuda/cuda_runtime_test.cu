#include "cuda_runtime_binding.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#define TEST_PASS printf("\033[32m✓\033[0m")
#define TEST_FAIL printf("\033[31m✗\033[0m")
#define CHECK(condition, message) \
    if (condition) { TEST_PASS; } else { TEST_FAIL; printf(" %s\n", message); }
void print_test_header(const char* name) {
    printf("\n[TEST] %s\n", name);
}
float* alloc_host_array(int size, float value) {
    float* arr = (float*)malloc(size * sizeof(float));
    for (int i = 0; i < size; i++) {
        arr[i] = value;
    }
    return arr;
}
int compare_arrays(float* actual, float* expected, int size, float tolerance) {
    for (int i = 0; i < size; i++) {
        float diff = fabsf(actual[i] - expected[i]);
        if (diff > tolerance) {
            printf("  Mismatch at index %d: expected %.4f, got %.4f\n",
                   i, expected[i], actual[i]);
            return 0;
        }
    }
    return 1;
}
void test_device_detection() {
    print_test_header("Device Detection");
    int device_count = neurx_cuda_get_device_count();
    printf("  Device count: %d\n", device_count);
    CHECK(device_count > 0, "No CUDA devices found");
    for (int i = 0; i < device_count && i < 3; i++) {
        const char* name = neurx_cuda_get_device_name(i);
        printf("  Device %d: %s\n", i, name);
    }
}
void test_memory_operations() {
    print_test_header("Memory Allocation & Transfer");
    int size = 1000;
    float* host_data_in = alloc_host_array(size, 3.14159f);
    float* host_data_out = (float*)malloc(size * sizeof(float));
    memset(host_data_out, 0, size * sizeof(float));
    void* gpu_data = neurx_cuda_malloc(size * sizeof(float));
    CHECK(gpu_data != NULL, "GPU allocation failed");
    int status = neurx_cuda_memcpy_htod(gpu_data, host_data_in, size * sizeof(float));
    CHECK(status == 0, "CPU->GPU copy failed");
    status = neurx_cuda_memcpy_dtoh(host_data_out, gpu_data, size * sizeof(float));
    CHECK(status == 0, "GPU->CPU copy failed");
    int match = compare_arrays(host_data_out, host_data_in, size, 1e-5);
    CHECK(match, "Data mismatch after copy");
    status = neurx_cuda_free(gpu_data);
    CHECK(status == 0, "GPU free failed");
    free(host_data_in);
    free(host_data_out);
    printf("  ✓ Memory operations complete\n");
}
void test_cublas_sgemm() {
    print_test_header("cuBLAS SGEMM (Matrix Multiply)");
    int m = 3, n = 3, k = 3;
    int size = m * n;
    float a_host[9] = {
        1.0f, 2.0f, 3.0f,
        4.0f, 5.0f, 6.0f,
        7.0f, 8.0f, 9.0f
    };
    float b_host[9] = {
        1.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 1.0f
    };
    float c_host[9] = {
        0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f
    };
    float c_expected[9] = {
        1.0f, 2.0f, 3.0f,
        4.0f, 5.0f, 6.0f,
        7.0f, 8.0f, 9.0f
    };
    void* a_gpu = neurx_cuda_malloc(size * sizeof(float));
    void* b_gpu = neurx_cuda_malloc(size * sizeof(float));
    void* c_gpu = neurx_cuda_malloc(size * sizeof(float));
    neurx_cuda_memcpy_htod(a_gpu, a_host, size * sizeof(float));
    neurx_cuda_memcpy_htod(b_gpu, b_host, size * sizeof(float));
    neurx_cuda_memcpy_htod(c_gpu, c_host, size * sizeof(float));
    void* handle = neurx_cublas_create();
    CHECK(handle != NULL, "cuBLAS create failed");
    int status = neurx_cublas_sgemm(handle, m, n, k, 1.0f,
                                    (float*)a_gpu, (float*)b_gpu,
                                    0.0f, (float*)c_gpu);
    CHECK(status == 0, "cuBLAS SGEMM failed");
    float c_result[9];
    neurx_cuda_memcpy_dtoh(c_result, c_gpu, size * sizeof(float));
    int match = compare_arrays(c_result, c_expected, size, 1e-4);
    CHECK(match, "Matrix multiply result incorrect");
    printf("  Result (A @ I):\n");
    for (int i = 0; i < 3; i++) {
        printf("    %.1f %.1f %.1f\n", c_result[i*3], c_result[i*3+1], c_result[i*3+2]);
    }
    neurx_cublas_destroy(handle);
    neurx_cuda_free(a_gpu);
    neurx_cuda_free(b_gpu);
    neurx_cuda_free(c_gpu);
}
void test_linear_forward() {
    print_test_header("Linear Layer Forward Pass");
    int batch_size = 2;
    int in_features = 3;
    int out_features = 2;
    float x_host[6] = {1,2,3, 4,5,6};
    float w_host[6] = {1,0,0, 0,1,0};
    float b_host[2] = {0.5, 0.5};
    void* x_gpu = neurx_cuda_malloc(batch_size * in_features * sizeof(float));
    void* w_gpu = neurx_cuda_malloc(out_features * in_features * sizeof(float));
    void* b_gpu = neurx_cuda_malloc(out_features * sizeof(float));
    neurx_cuda_memcpy_htod(x_gpu, x_host, batch_size * in_features * sizeof(float));
    neurx_cuda_memcpy_htod(w_gpu, w_host, out_features * in_features * sizeof(float));
    neurx_cuda_memcpy_htod(b_gpu, b_host, out_features * sizeof(float));
    float* y_gpu = neurx_linear_forward(batch_size, in_features, out_features,
                                        (float*)x_gpu, (float*)w_gpu, (float*)b_gpu);
    CHECK(y_gpu != NULL, "Linear forward returned NULL");
    float y_result[4];
    neurx_cuda_memcpy_dtoh(y_result, (void*)y_gpu, batch_size * out_features * sizeof(float));
    float y_expected[4] = {1.5, 2.5, 4.5, 5.5};
    int match = compare_arrays(y_result, y_expected, batch_size * out_features, 1e-4);
    CHECK(match, "Linear forward result incorrect");
    printf("  Result:\n");
    for (int i = 0; i < batch_size; i++) {
        printf("    %.1f, %.1f\n", y_result[i*out_features], y_result[i*out_features+1]);
    }
    neurx_cuda_free(x_gpu);
    neurx_cuda_free(w_gpu);
    neurx_cuda_free(b_gpu);
    neurx_cuda_free((void*)y_gpu);
}
void test_relu() {
    print_test_header("ReLU Activation");
    int size = 10;
    float x_host[10] = {-2, -1, 0, 1, 2, -3, 0.5, 1.5, -0.5, 3};
    float expected[10] = {0, 0, 0, 1, 2, 0, 0.5, 1.5, 0, 3};
    void* x_gpu = neurx_cuda_malloc(size * sizeof(float));
    neurx_cuda_memcpy_htod(x_gpu, x_host, size * sizeof(float));
    float* y_gpu = neurx_relu_forward(size, (float*)x_gpu);
    CHECK(y_gpu != NULL, "ReLU forward returned NULL");
    float result[10];
    neurx_cuda_memcpy_dtoh(result, (void*)y_gpu, size * sizeof(float));
    int match = compare_arrays(result, expected, size, 1e-6);
    CHECK(match, "ReLU result incorrect");
    printf("  Input:  [");
    for (int i = 0; i < size; i++) printf("%.1f ", x_host[i]);
    printf("]\n");
    printf("  Output: [");
    for (int i = 0; i < size; i++) printf("%.1f ", result[i]);
    printf("]\n");
    neurx_cuda_free(x_gpu);
    neurx_cuda_free((void*)y_gpu);
}
void test_softmax() {
    print_test_header("Softmax Forward Pass");
    int batch_size = 1;
    int num_classes = 3;
    float logits[3] = {1.0, 2.0, 3.0};
    void* logits_gpu = neurx_cuda_malloc(num_classes * sizeof(float));
    neurx_cuda_memcpy_htod(logits_gpu, logits, num_classes * sizeof(float));
    float* probs_gpu = neurx_softmax_forward(batch_size, num_classes, (float*)logits_gpu);
    CHECK(probs_gpu != NULL, "Softmax returned NULL");
    float result[3];
    neurx_cuda_memcpy_dtoh(result, (void*)probs_gpu, num_classes * sizeof(float));
    float sum = result[0] + result[1] + result[2];
    CHECK(fabsf(sum - 1.0f) < 1e-5, "Softmax does not sum to 1");
    CHECK(result[0] < result[1] && result[1] < result[2], "Softmax not monotonic");
    printf("  Logits: [%.2f, %.2f, %.2f]\n", logits[0], logits[1], logits[2]);
    printf("  Probs:  [%.4f, %.4f, %.4f]\n", result[0], result[1], result[2]);
    printf("  Sum: %.6f\n", sum);
    neurx_cuda_free(logits_gpu);
    neurx_cuda_free((void*)probs_gpu);
}
int main() {
    printf("\n");
    printf("╔════════════════════════════════════════════════════╗\n");
    printf("║     NeurX CUDA Runtime Binding Test Suite          ║\n");
    printf("╚════════════════════════════════════════════════════╝\n");
    printf("\nRunning comprehensive GPU operation tests...\n");
    printf("This will verify all CUDA bindings work correctly.\n");
    test_device_detection();
    test_memory_operations();
    test_cublas_sgemm();
    test_linear_forward();
    test_relu();
    test_softmax();
    printf("\n");
    printf("╔════════════════════════════════════════════════════╗\n");
    printf("║     All Tests Complete                             ║\n");
    printf("╚════════════════════════════════════════════════════╝\n");
    printf("\nGPU is ready for training!\n\n");
    return 0;
}
