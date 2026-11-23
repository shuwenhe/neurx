#define _POSIX_C_SOURCE 200809L
#include "native_gemm.h"

#include <cnnl.h>
#include <time.h>

/* Retain the first failure, including the original vendor status. */
#define RECORD(domain_value, success, call) do { \
    const int code = (int)(call); \
    if (code != (int)(success) && status.domain == NEURX_GEMM_OK) \
        status = (neurx_gemm_status){domain_value, code, #call}; \
} while (0)
#define RT(call) do { \
    RECORD(NEURX_GEMM_CNRT, cnrtSuccess, call); \
    if (status.domain != NEURX_GEMM_OK) goto cleanup; \
} while (0)
#define NL(call) do { \
    RECORD(NEURX_GEMM_CNNL, CNNL_STATUS_SUCCESS, call); \
    if (status.domain != NEURX_GEMM_OK) goto cleanup; \
} while (0)

static bool matrix_bytes(int rows, int cols, size_t element_bytes, size_t *bytes) {
    if (rows <= 0 || cols <= 0 || (size_t)rows > SIZE_MAX / element_bytes / (size_t)cols)
        return false;
    *bytes = (size_t)rows * (size_t)cols * element_bytes;
    return true;
}

static double elapsed_us(struct timespec start, struct timespec end) {
    return (end.tv_sec - start.tv_sec) * 1e6 + (end.tv_nsec - start.tv_nsec) / 1e3;
}

neurx_gemm_status neurx_mlu_gemm(int device, neurx_gemm_dtype dtype,
                                int m, int n, int k, const uint16_t *a,
                                const uint16_t *b, float *output, int repeats,
                                neurx_gemm_metrics *metrics) {
    size_t a_bytes, b_bytes, out_bytes;
    if (metrics)
        *metrics = (neurx_gemm_metrics){0};
    if (device < 0 || (dtype != NEURX_GEMM_FP16 && dtype != NEURX_GEMM_BF16) ||
        !a || !b || !output || !metrics || repeats <= 0 ||
        !matrix_bytes(m, k, sizeof(*a), &a_bytes) ||
        !matrix_bytes(k, n, sizeof(*b), &b_bytes) ||
        !matrix_bytes(m, n, sizeof(*output), &out_bytes) ||
        a_bytes > SIZE_MAX - b_bytes || out_bytes > (SIZE_MAX - a_bytes - b_bytes) / 2)
        return (neurx_gemm_status){NEURX_GEMM_INPUT, 0, "validate GEMM arguments"};

    neurx_gemm_status status = {NEURX_GEMM_OK, 0, NULL};
    cnrtQueue_t queue = NULL;
    cnrtNotifier_t begin = NULL, end = NULL;
    cnnlHandle_t handle = NULL;
    cnnlTensorDescriptor_t ad = NULL, bd = NULL, cd = NULL;
    cnnlMatMulDescriptor_t desc = NULL;
    cnnlMatMulAlgo_t algo = NULL;
    cnnlMatMulHeuristicResult_t heuristic = NULL;
    void *da = NULL, *db = NULL, *dc = NULL, *dd = NULL, *workspace = NULL;
    size_t workspace_bytes = 0;
    int algorithms = 0;
    const int dims_a[] = {m, k}, dims_b[] = {k, n}, dims_c[] = {m, n};
    const cnnlDataType_t input_type = dtype == NEURX_GEMM_BF16 ? CNNL_DTYPE_BFLOAT16 : CNNL_DTYPE_HALF;
    const cnnlDataType_t compute_type = CNNL_DTYPE_FLOAT;
    const bool use_beta = false;
    const float alpha = 1.0f, beta = 0.0f;
    struct timespec started, finished;
    float kernel_total_us = 0;
    neurx_gemm_metrics measured = {0};

    RT(cnrtSetDevice(device));
    RT(cnrtQueueCreate(&queue));
    NL(cnnlCreate(&handle));
    NL(cnnlSetQueue(handle, queue));
    NL(cnnlCreateTensorDescriptor(&ad));
    NL(cnnlCreateTensorDescriptor(&bd));
    NL(cnnlCreateTensorDescriptor(&cd));
    NL(cnnlSetTensorDescriptor(ad, CNNL_LAYOUT_ARRAY, input_type, 2, dims_a));
    NL(cnnlSetTensorDescriptor(bd, CNNL_LAYOUT_ARRAY, input_type, 2, dims_b));
    NL(cnnlSetTensorDescriptor(cd, CNNL_LAYOUT_ARRAY, compute_type, 2, dims_c));
    NL(cnnlCreateMatMulDescriptor(&desc));
    NL(cnnlSetMatMulDescAttr(desc, CNNL_MATMUL_DESC_COMPUTE_TYPE, &compute_type, sizeof(compute_type)));
    NL(cnnlSetMatMulDescAttr(desc, CNNL_MATMUL_USE_BETA, &use_beta, sizeof(use_beta)));
    NL(cnnlCreateMatMulAlgo(&algo));
    NL(cnnlCreateMatMulHeuristicResult(&heuristic));
    NL(cnnlGetMatMulAlgoHeuristic(handle, desc, ad, bd, cd, cd, NULL, 1, &heuristic, &algorithms));
    if (algorithms != 1) {
        status = (neurx_gemm_status){NEURX_GEMM_CNNL, 0, "CNNL returned no GEMM algorithm"};
        goto cleanup;
    }
    NL(cnnlGetMatMulHeuristicResult(heuristic, algo, &workspace_bytes));
    measured.device_bytes = a_bytes + b_bytes + 2 * out_bytes;
    if (workspace_bytes > SIZE_MAX - measured.device_bytes) {
        status = (neurx_gemm_status){NEURX_GEMM_INPUT, 0, "device byte count overflow"};
        goto cleanup;
    }
    measured.workspace_bytes = workspace_bytes;
    measured.device_bytes += workspace_bytes;
    RT(cnrtMalloc(&da, a_bytes));
    RT(cnrtMalloc(&db, b_bytes));
    RT(cnrtMalloc(&dc, out_bytes));
    RT(cnrtMalloc(&dd, out_bytes));
    if (workspace_bytes)
        RT(cnrtMalloc(&workspace, workspace_bytes));

    if (clock_gettime(CLOCK_MONOTONIC, &started) != 0) {
        status = (neurx_gemm_status){NEURX_GEMM_INPUT, 0, "start H2D clock"};
        goto cleanup;
    }
    RT(cnrtMemcpy(da, (void *)a, a_bytes, cnrtMemcpyHostToDev));
    RT(cnrtMemcpy(db, (void *)b, b_bytes, cnrtMemcpyHostToDev));
    if (clock_gettime(CLOCK_MONOTONIC, &finished) != 0) {
        status = (neurx_gemm_status){NEURX_GEMM_INPUT, 0, "finish H2D clock"};
        goto cleanup;
    }
    measured.h2d_us = elapsed_us(started, finished);

    RT(cnrtNotifierCreate(&begin));
    RT(cnrtNotifierCreate(&end));
    /* Warm up once, then bracket just the repeated GEMM launches. */
    NL(cnnlMatMul_v2(handle, desc, algo, &alpha, ad, da, bd, db, &beta, cd, dc,
                     workspace, workspace_bytes, cd, dd));
    RT(cnrtPlaceNotifier(begin, queue));
    for (int i = 0; i < repeats; ++i) {
        NL(cnnlMatMul_v2(handle, desc, algo, &alpha, ad, da, bd, db, &beta, cd, dc,
                         workspace, workspace_bytes, cd, dd));
    }
    RT(cnrtPlaceNotifier(end, queue));
    RT(cnrtQueueSync(queue));
    RT(cnrtNotifierDuration(begin, end, &kernel_total_us));
    measured.kernel_us = (double)kernel_total_us / repeats;

    if (clock_gettime(CLOCK_MONOTONIC, &started) != 0) {
        status = (neurx_gemm_status){NEURX_GEMM_INPUT, 0, "start D2H clock"};
        goto cleanup;
    }
    RT(cnrtMemcpy(output, dd, out_bytes, cnrtMemcpyDevToHost));
    if (clock_gettime(CLOCK_MONOTONIC, &finished) != 0) {
        status = (neurx_gemm_status){NEURX_GEMM_INPUT, 0, "finish D2H clock"};
        goto cleanup;
    }
    measured.d2h_us = elapsed_us(started, finished);

cleanup:
    if (queue) RECORD(NEURX_GEMM_CNRT, cnrtSuccess, cnrtQueueSync(queue));
    if (end) RECORD(NEURX_GEMM_CNRT, cnrtSuccess, cnrtNotifierDestroy(end));
    if (begin) RECORD(NEURX_GEMM_CNRT, cnrtSuccess, cnrtNotifierDestroy(begin));
    if (workspace) RECORD(NEURX_GEMM_CNRT, cnrtSuccess, cnrtFree(workspace));
    if (dd) RECORD(NEURX_GEMM_CNRT, cnrtSuccess, cnrtFree(dd));
    if (dc) RECORD(NEURX_GEMM_CNRT, cnrtSuccess, cnrtFree(dc));
    if (db) RECORD(NEURX_GEMM_CNRT, cnrtSuccess, cnrtFree(db));
    if (da) RECORD(NEURX_GEMM_CNRT, cnrtSuccess, cnrtFree(da));
    if (heuristic) RECORD(NEURX_GEMM_CNNL, CNNL_STATUS_SUCCESS, cnnlDestroyMatMulHeuristicResult(heuristic));
    if (algo) RECORD(NEURX_GEMM_CNNL, CNNL_STATUS_SUCCESS, cnnlDestroyMatMulAlgo(algo));
    if (desc) RECORD(NEURX_GEMM_CNNL, CNNL_STATUS_SUCCESS, cnnlDestroyMatMulDescriptor(desc));
    if (cd) RECORD(NEURX_GEMM_CNNL, CNNL_STATUS_SUCCESS, cnnlDestroyTensorDescriptor(cd));
    if (bd) RECORD(NEURX_GEMM_CNNL, CNNL_STATUS_SUCCESS, cnnlDestroyTensorDescriptor(bd));
    if (ad) RECORD(NEURX_GEMM_CNNL, CNNL_STATUS_SUCCESS, cnnlDestroyTensorDescriptor(ad));
    if (handle) RECORD(NEURX_GEMM_CNNL, CNNL_STATUS_SUCCESS, cnnlDestroy(handle));
    if (queue) RECORD(NEURX_GEMM_CNRT, cnrtSuccess, cnrtQueueDestroy(queue));
    if (status.domain == NEURX_GEMM_OK)
        *metrics = measured;
    return status;
}
