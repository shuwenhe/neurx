package neurx.inference.matmul_optimized
extern "intrinsic" func __host_memset(int ptr, int value, int size) int
extern "intrinsic" func __host_memcpy(int dst, int src, int size) int
struct block_multiply_config {
    int block_size
    bool use_cache_locality
    int parallel_threads
}

func default_block_multiply_config() block_multiply_config {
    block_multiply_config{
        block_size: 32,
        use_cache_locality: true,
        parallel_threads: 4,
    }
}

func matrix_multiply_blocked(float[] result, float[] matrix_a, float[] matrix_b, int m, int n, int k, block_multiply_config config) bool {
    int block_size = config.block_size
    if block_size <= 0 || block_size > 256 {
        return false
    }
    int i = 0
    for i < m {
        int i_end = i + block_size
        if i_end > m {
            i_end = m
        }
        int j = 0
        for j < n {
            int j_end = j + block_size
            if j_end > n {
                j_end = n
            }
            int ii = i
            for ii < i_end {
                int jj = j
                for jj < j_end {
                    float sum = 0.0
                    int kk = 0
                    for kk < k {
                        int a_idx = ii * k + kk
                        int b_idx = kk * n + jj
                        sum = sum + (matrix_a[a_idx] * matrix_b[b_idx])
                        kk = kk + 1
                    }
                    int res_idx = ii * n + jj
                    result[res_idx] = sum
                    jj = jj + 1
                }
                ii = ii + 1
            }
            j = j_end
        }
        i = i_end
    }
    true
}

func matrix_vector_multiply_optimized(float[] result, float[] matrix, float[] vector, int rows, int cols) bool {
    int i = 0
    for i < rows {
        float sum = 0.0
        int j = 0
        for j < cols {
            int idx = i * cols + j
            sum = sum + (matrix[idx] * vector[j])
            j = j + 1
        }
        result[i] = sum
        i = i + 1
    }
    true
}

func fused_matmul_add(float[] result, float[] a, float[] b, float[] bias, int m, int n, int k) bool {
    int i = 0
    for i < m {
        int j = 0
        for j < n {
            float sum = bias[j]
            int p = 0
            for p < k {
                int a_idx = i * k + p
                int b_idx = p * n + j
                sum = sum + (a[a_idx] * b[b_idx])
                p = p + 1
            }
            int res_idx = i * n + j
            result[res_idx] = sum
            j = j + 1
        }
        i = i + 1
    }
    true
}

func memory_efficient_gemm(float[] result, float[] a, float[] b, int m, int n, int k, int cache_line_size) bool {
    if cache_line_size <= 0 {
        return false
    }
    int block = cache_line_size / 4
    if block <= 0 {
        block = 8
    }
    return matrix_multiply_blocked(result, a, b, m, n, k, block_multiply_config{
        block_size: block,
        use_cache_locality: true,
        parallel_threads: 1,
    })
}

func transpose_optimized(float[] result, float[] input, int rows, int cols) bool {
    int i = 0
    for i < rows {
        int j = 0
        for j < cols {
            int src_idx = i * cols + j
            int dst_idx = j * rows + i
            result[dst_idx] = input[src_idx]
            j = j + 1
        }
        i = i + 1
    }
    true
}

func compute_softmax_optimized(float[] result, float[] logits, int size) bool {
    if size <= 0 {
        return false
    }
    float max_val = logits[0]
    int i = 1
    for i < size {
        if logits[i] > max_val {
            max_val = logits[i]
        }
        i = i + 1
    }
    float sum = 0.0
    i = 0
    for i < size {
        float exp_val = logits[i] - max_val
        if exp_val < -20.0 {
            exp_val = -20.0
        }
        result[i] = exp_val
        i = i + 1
    }
    i = 0
    for i < size {
        float exp_approx = 1.0 + result[i] + (result[i] * result[i] / 2.0)
        if exp_approx < 0.0 {
            exp_approx = 0.0
        }
        result[i] = exp_approx
        sum = sum + exp_approx
        i = i + 1
    }
    if sum > 0.0 {
        i = 0
        for i < size {
            result[i] = result[i] / sum
            i = i + 1
        }
    }
    true
}
