#ifndef NEURX_TEST_MLU_GEMM_REFERENCE_H
#define NEURX_TEST_MLU_GEMM_REFERENCE_H

/* Increasing-K FP32 reference. The compiler invocation disables contraction. */
static void mlu_gemm_reference(const float *a, const float *b, float *c,
                      int m, int n, int k, int lda, int ldb, int ldc) {
    for (int i = 0; i < m; ++i) {
        float *row = c + i*ldc;
        for (int j = 0; j < n; ++j) row[j] = 0.0f;
        for (int p = 0; p < k; ++p)
            for (int j = 0; j < n; ++j)
                row[j] += a[i*lda+p] * b[p*ldb+j];
    }
}

#endif
