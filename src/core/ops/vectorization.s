package neurx.ops.vectorization
import (
    "neurx/model"
    "neurx/nn"
)

struct matmul_config {
    int batch_size
    bool use_blocked
    int block_size
    int parallel_threads
}

struct batch_matmul_result {
    output: [][]float
    shape: [3]int
}

struct vectorization_stats {
    int ops_count
    float throughput
    float memory_bandwidth
    float compute_efficiency
}

func batch_matmul([][]float A, [][]float B, int batch_size, int M, int K, int N) batch_matmul_result {
    result := batch_matmul_result
    output := [][]float(batch_size * M * N)
    idx := 0
    b := 0
    for b < batch_size {
        i := 0
        for i < M {
            j := 0
            for j < N {
                sum := 0.0
                k := 0
                for k < K {
                    a_idx := b * M * K + i * K + k
                    b_idx := b * K * N + k * N + j
                    sum = sum + A[a_idx] * B[b_idx]
                    k = k + 1
                }
                output[idx] = sum
                idx = idx + 1
                j = j + 1
            }
            i = i + 1
        }
        b = b + 1
    }
    result.output = output
    result.shape[0] = batch_size
    result.shape[1] = M
    result.shape[2] = N
    return result
}

func batch_matmul_blocked([][]float A, [][]float B, int batch_size, int M, int K, int N, int block_size) batch_matmul_result {
    result := batch_matmul_result
    output := [][]float(batch_size * M * N)
    idx := 0
    for idx < batch_size * M * N {
        output[idx] = 0.0
        idx = idx + 1
    }
    b := 0
    for b < batch_size {
        k_block := 0
        for k_block < K {
            k_end := k_block + block_size
            if k_end > K {
                k_end = K
            }
            i_block := 0
            for i_block < M {
                i_end := i_block + block_size
                if i_end > M {
                    i_end = M
                }
                j_block := 0
                for j_block < N {
                    j_end := j_block + block_size
                    if j_end > N {
                        j_end = N
                    }
                    i := i_block
                    for i < i_end {
                        j := j_block
                        for j < j_end {
                            sum := output[b * M * N + i * N + j]
                            k := k_block
                            for k < k_end {
                                a_idx := b * M * K + i * K + k
                                b_idx := b * K * N + k * N + j
                                sum = sum + A[a_idx] * B[b_idx]
                                k = k + 1
                            }
                            output[b * M * N + i * N + j] = sum
                            j = j + 1
                        }
                        i = i + 1
                    }
                    j_block = j_end
                }
                i_block = i_end
            }
            k_block = k_end
        }
        b = b + 1
    }
    result.output = output
    result.shape[0] = batch_size
    result.shape[1] = M
    result.shape[2] = N
    return result
}

func element_wise_add([]float A, []float B) []float {
    var []float result = []float(len(A))
    i := 0
    for i < len(A) {
        result[i] = A[i] + B[i]
        i = i + 1
    }
    return result
}

func element_wise_mul([]float A, []float B) []float {
    var []float result = []float(len(A))
    i := 0
    for i < len(A) {
        result[i] = A[i] * B[i]
        i = i + 1
    }
    return result
}

func element_wise_div([]float A, []float B, float epsilon) []float {
    var []float result = []float(len(A))
    i := 0
    for i < len(A) {
        if B[i] < 0.0 {
            if B[i] > -epsilon {
                B[i] = -epsilon
            }
        } else {
            if B[i] < epsilon {
                B[i] = epsilon
            }
        }
        result[i] = A[i] / B[i]
        i = i + 1
    }
    return result
}

func element_wise_apply([]float A, func(float) float func_ptr) []float {
    var []float result = []float(len(A))
    i := 0
    for i < len(A) {
        result[i] = func_ptr(A[i])
        i = i + 1
    }
    return result
}

func batch_element_wise_add([][]float A, [][]float B, int batch_size, int size_per_batch) [][]float {
    result := [][]float(len(A))
    idx := 0
    b := 0
    for b < batch_size {
        i := 0
        for i < size_per_batch {
            result[idx] = A[idx] + B[idx]
            i = i + 1
            idx = idx + 1
        }
        b = b + 1
    }
    return result
}

func batch_element_wise_mul([][]float A, [][]float B, int batch_size, int size_per_batch) [][]float {
    result := [][]float(len(A))
    idx := 0
    b := 0
    for b < batch_size {
        i := 0
        for i < size_per_batch {
            result[idx] = A[idx] * B[idx]
            i = i + 1
            idx = idx + 1
        }
        b = b + 1
    }
    return result
}

func reduce_sum([]float A) float {
    sum := 0.0
    i := 0
    for i < len(A) {
        sum = sum + A[i]
        i = i + 1
    }
    return sum
}

func reduce_mean([]float A) float {
    if len(A) == 0 {
        return 0.0
    }
    return reduce_sum(A) / float(len(A))
}

func reduce_max([]float A) float {
    if len(A) == 0 {
        return 0.0
    }
    max_val := A[0]
    i := 1
    for i < len(A) {
        if A[i] > max_val {
            max_val = A[i]
        }
        i = i + 1
    }
    return max_val
}

func reduce_sum_batch([][]float A, int batch_size, int size_per_batch) []float {
    var []float result = []float(batch_size)
    b := 0
    for b < batch_size {
        sum := 0.0
        i := 0
        for i < size_per_batch {
            sum = sum + A[b * size_per_batch + i]
            i = i + 1
        }
        result[b] = sum
        b = b + 1
    }
    return result
}

func broadcast_add([][]float A, []float b, int rows, int cols) [][]float {
    result := [][]float(len(A))
    idx := 0
    r := 0
    for r < rows {
        c := 0
        for c < cols {
            result[idx] = A[idx] + b[c]
            idx = idx + 1
            c = c + 1
        }
        r = r + 1
    }
    return result
}

func broadcast_mul([][]float A, []float b, int rows, int cols) [][]float {
    result := [][]float(len(A))
    idx := 0
    r := 0
    for r < rows {
        c := 0
        for c < cols {
            result[idx] = A[idx] * b[c]
            idx = idx + 1
            c = c + 1
        }
        r = r + 1
    }
    return result
}

func measure_ops_throughput(int ops_count, float time_ms) float {
    if time_ms <= 0.0 {
        return 0.0
    }
    return float(ops_count) / (time_ms / 1000.0)
}

func estimate_memory_bandwidth(int bytes_transferred, float time_ms) float {
    if time_ms <= 0.0 {
        return 0.0
    }
    bytes_per_sec := float(bytes_transferred) / (time_ms / 1000.0)
    return bytes_per_sec / (1024.0 * 1024.0 * 1024.0)
}

func compute_efficiency(int flops, int bytes) float {
    if bytes == 0 {
        return 0.0
    }
    return float(flops) / float(bytes)
}

func new_vectorization_stats() vectorization_stats {
    stats := vectorization_stats
    stats.ops_count = 0
    stats.throughput = 0.0
    stats.memory_bandwidth = 0.0
    stats.compute_efficiency = 0.0
    return stats
}

func gemm_blocked([][]float A, [][]float B, int M, int K, int N, int block_size) [][]float {
    C := [][]float(M * N)
    i := 0
    for i < M * N {
        C[i] = 0.0
        i = i + 1
    }
    k_block := 0
    for k_block < K {
        k_end := k_block + block_size
        if k_end > K {
            k_end = K
        }
        i_block := 0
        for i_block < M {
            i_end := i_block + block_size
            if i_end > M {
                i_end = M
            }
            j_block := 0
            for j_block < N {
                j_end := j_block + block_size
                if j_end > N {
                    j_end = N
                }
                i = i_block
                for i < i_end {
                    j := j_block
                    for j < j_end {
                        sum := C[i * N + j]
                        k := k_block
                        for k < k_end {
                            sum = sum + A[i * K + k] * B[k * N + j]
                            k = k + 1
                        }
                        C[i * N + j] = sum
                        j = j + 1
                    }
                    i = i + 1
                }
                j_block = j_end
            }
            i_block = i_end
        }
        k_block = k_end
    }
    return C
}

func transpose_in_place([][]float A, int N) [][]float {
    i := 0
    for i < N {
        j := i + 1
        for j < N {
            temp := A[i * N + j]
            A[i * N + j] = A[j * N + i]
            A[j * N + i] = temp
            j = j + 1
        }
        i = i + 1
    }
    return A
}

func scale_vector([]float A, float scalar) []float {
    var []float result = []float(len(A))
    i := 0
    for i < len(A) {
        result[i] = A[i] * scalar
        i = i + 1
    }
    return result
}

func dot_product([]float A, []float B) float {
    result := 0.0
    i := 0
    for i < len(A) {
        result = result + A[i] * B[i]
        i = i + 1
    }
    return result
}

func vector_norm([]float A) float {
    sum := 0.0
    i := 0
    for i < len(A) {
        sum = sum + A[i] * A[i]
        i = i + 1
    }
    if sum < 0.0 {
        sum = 0.0 - sum
    }
    result := 0.0
    x := sum
    i_iter := 0
    for i_iter < 10 {
        if x == 0.0 {
            break
        }
        result = (result + x / result) / 2.0
        i_iter = i_iter + 1
    }
    return result
}
