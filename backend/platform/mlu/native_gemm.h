#ifndef NEURX_MLU_NATIVE_GEMM_H
#define NEURX_MLU_NATIVE_GEMM_H

#include <stddef.h>
#include <stdint.h>

typedef enum { NEURX_GEMM_FP16, NEURX_GEMM_BF16 } neurx_gemm_dtype;
typedef enum { NEURX_GEMM_OK, NEURX_GEMM_INPUT, NEURX_GEMM_CNRT, NEURX_GEMM_CNNL } neurx_gemm_domain;

typedef struct {
    neurx_gemm_domain domain;
    int code;
    const char *operation;
} neurx_gemm_status;

typedef struct {
    double h2d_us;
    double kernel_us;
    double d2h_us;
    size_t workspace_bytes;
    size_t device_bytes;
} neurx_gemm_metrics;

/* Packed row-major A[M,K], B[K,N] and output[M,N].
 * A and B contain raw 16-bit floats. Kernel time is the mean of repeated launches.
 * A call owns its queue and device allocations. It must run on a dedicated worker
 * thread because CNRT device selection is thread-local and persists after return.
 */
neurx_gemm_status neurx_mlu_gemm(int device, neurx_gemm_dtype dtype,
                                int m, int n, int k, const uint16_t *a,
                                const uint16_t *b, float *output, int repeats,
                                neurx_gemm_metrics *metrics);

#endif
