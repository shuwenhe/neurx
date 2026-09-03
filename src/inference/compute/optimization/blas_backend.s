package neurx.inference.blas_backend
func blas_provider_available(string provider) bool {
    if provider == "native_s" { return true }
    false
}

func blas_sgemm(
    []float A, int M, int K,
    []float B, int K2, int N,
    []float C, int M2, int N2,
    float alpha,
    float beta
) []float {
    return blas_sgemm_native_s(A, M, K, B, K2, N, C, M2, N2, alpha, beta)
}

func blas_sgemm_native_s(
    []float A, int M, int K,
    []float B, int K2, int N,
    []float C, int M2, int N2,
    float alpha, float beta
) []float {
    if K != K2 || M != M2 || N != N2 { return C }
    []float out = make([]float, M * N)
    int i = 0
    for i < M * N {
        out[i] = C[i] * beta
        i = i + 1
    }
    int m = 0
    for m < M {
        int n = 0
        for n < N {
            float sum = 0.0
            int k = 0
            for k < K {
                float a_val = A[m * K + k]
                float b_val = B[k * N + n]
                sum = sum + a_val * b_val
                k = k + 1
            }
            out[m * N + n] = out[m * N + n] + alpha * sum
            n = n + 1
        }
        m = m + 1
    }
    out
}

func blas_sgemv([]float A, int M, int N, []float x, float alpha, float beta) []float {
    []float y = make([]float, M)
    int i = 0
    for i < M {
        float sum = 0.0
        int j = 0
        for j < N {
            sum = sum + A[i * N + j] * x[j]
            j = j + 1
        }
        y[i] = alpha * sum + beta * y[i]
        i = i + 1
    }
    y
}

func blas_sdot([]float x, []float y) float {
    float result = 0.0
    int i = 0
    for i < len(x) {
        result = result + x[i] * y[i]
        i = i + 1
    }
    result
}

func blas_saxpy([]float x, []float y, float alpha) []float {
    []float out = make([]float, len(y))
    int i = 0
    for i < len(y) {
        out[i] = alpha * x[i] + y[i]
        i = i + 1
    }
    out
}

struct blas_config {
    string provider
    int gemm_threshold_ops
    bool use_omp
    bool use_simd
    int cache_line_size
}

func get_default_blas_config() blas_config {
    return blas_config{
        provider: "native_s",
        gemm_threshold_ops: 100000,
        use_omp: false,
        use_simd: false,
        cache_line_size: 64,
    }
}

func benchmark_blas_gemm(int M, int K, int N) float {
    0.0
}
