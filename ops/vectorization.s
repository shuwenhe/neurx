package neurx.ops.vectorization
import (
    "neurx/model"
    "neurx/nn"
)

struct matmul_config {
    batch_size: int
    use_blocked: bool
    block_size: int
    parallel_threads: int
}

struct batch_matmul_result {
    output: [][]float
    shape: [3]int
}

struct vectorization_stats {
    ops_count: int
    throughput: float
    memory_bandwidth: float
    compute_efficiency: float
}

func batch_matmul(A: [][]float, B: [][]float, int batch_size, int M, int K, int N) batch_matmul_result {
    var result: batch_matmul_result
    var output: [][]float = [][]float(batch_size * M * N)
    var idx = 0
    var b = 0
    while b < batch_size {
        var i = 0
        while i < M {
            var j = 0
            while j < N {
                var sum = 0.0
                var k = 0
                while k < K {
                    var a_idx = b * M * K + i * K + k
                    var b_idx = b * K * N + k * N + j
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

func batch_matmul_blocked(A: [][]float, B: [][]float, int batch_size, int M, int K, int N, int block_size) batch_matmul_result {
    var result: batch_matmul_result
    var output: [][]float = [][]float(batch_size * M * N)
    var idx = 0
    while idx < batch_size * M * N {
        output[idx] = 0.0
        idx = idx + 1
    }
    var b = 0
    while b < batch_size {
        var k_block = 0
        while k_block < K {
            var k_end = k_block + block_size
            if k_end > K {
                k_end = K
            }
            var i_block = 0
            while i_block < M {
                var i_end = i_block + block_size
                if i_end > M {
                    i_end = M
                }
                var j_block = 0
                while j_block < N {
                    var j_end = j_block + block_size
                    if j_end > N {
                        j_end = N
                    }
                    var i = i_block
                    while i < i_end {
                        var j = j_block
                        while j < j_end {
                            var sum = output[b * M * N + i * N + j]
                            var k = k_block
                            while k < k_end {
                                var a_idx = b * M * K + i * K + k
                                var b_idx = b * K * N + k * N + j
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
    var i = 0
    while i < len(A) {
        result[i] = A[i] + B[i]
        i = i + 1
    }
    return result
}

func element_wise_mul([]float A, []float B) []float {
    var []float result = []float(len(A))
    var i = 0
    while i < len(A) {
        result[i] = A[i] * B[i]
        i = i + 1
    }
    return result
}

func element_wise_div([]float A, []float B, float epsilon) []float {
    var []float result = []float(len(A))
    var i = 0
    while i < len(A) {
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

func element_wise_apply([]float A, float func_ptr: func(float)) []float {
    var []float result = []float(len(A))
    var i = 0
    while i < len(A) {
        result[i] = func_ptr(A[i])
        i = i + 1
    }
    return result
}

func batch_element_wise_add(A: [][]float, B: [][]float, int batch_size, int size_per_batch) [][]float {
    var result: [][]float = [][]float(len(A))
    var idx = 0
    var b = 0
    while b < batch_size {
        var i = 0
        while i < size_per_batch {
            result[idx] = A[idx] + B[idx]
            i = i + 1
            idx = idx + 1
        }
        b = b + 1
    }
    return result
}

func batch_element_wise_mul(A: [][]float, B: [][]float, int batch_size, int size_per_batch) [][]float {
    var result: [][]float = [][]float(len(A))
    var idx = 0
    var b = 0
    while b < batch_size {
        var i = 0
        while i < size_per_batch {
            result[idx] = A[idx] * B[idx]
            i = i + 1
            idx = idx + 1
        }
        b = b + 1
    }
    return result
}

func reduce_sum([]float A) float {
    var sum = 0.0
    var i = 0
    while i < len(A) {
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
    var max_val = A[0]
    var i = 1
    while i < len(A) {
        if A[i] > max_val {
            max_val = A[i]
        }
        i = i + 1
    }
    return max_val
}

func reduce_sum_batch(A: [][]float, int batch_size, int size_per_batch) []float {
    var []float result = []float(batch_size)
    var b = 0
    while b < batch_size {
        var sum = 0.0
        var i = 0
        while i < size_per_batch {
            sum = sum + A[b * size_per_batch + i]
            i = i + 1
        }
        result[b] = sum
        b = b + 1
    }
    return result
}

func broadcast_add(A: [][]float, []float b, int rows, int cols) [][]float {
    var result: [][]float = [][]float(len(A))
    var idx = 0
    var r = 0
    while r < rows {
        var c = 0
        while c < cols {
            result[idx] = A[idx] + b[c]
            idx = idx + 1
            c = c + 1
        }
        r = r + 1
    }
    return result
}

func broadcast_mul(A: [][]float, []float b, int rows, int cols) [][]float {
    var result: [][]float = [][]float(len(A))
    var idx = 0
    var r = 0
    while r < rows {
        var c = 0
        while c < cols {
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
    var bytes_per_sec = float(bytes_transferred) / (time_ms / 1000.0)
    return bytes_per_sec / (1024.0 * 1024.0 * 1024.0)
}

func compute_efficiency(int flops, int bytes) float {
    if bytes == 0 {
        return 0.0
    }
    return float(flops) / float(bytes)
}

func new_vectorization_stats() vectorization_stats {
    var stats: vectorization_stats
    stats.ops_count = 0
    stats.throughput = 0.0
    stats.memory_bandwidth = 0.0
    stats.compute_efficiency = 0.0
    return stats
}

func gemm_blocked(A: [][]float, B: [][]float, int M, int K, int N, int block_size) [][]float {
    var C: [][]float = [][]float(M * N)
    var i = 0
    while i < M * N {
        C[i] = 0.0
        i = i + 1
    }
    var k_block = 0
    while k_block < K {
        var k_end = k_block + block_size
        if k_end > K {
            k_end = K
        }
        var i_block = 0
        while i_block < M {
            var i_end = i_block + block_size
            if i_end > M {
                i_end = M
            }
            var j_block = 0
            while j_block < N {
                var j_end = j_block + block_size
                if j_end > N {
                    j_end = N
                }
                i = i_block
                while i < i_end {
                    var j = j_block
                    while j < j_end {
                        var sum = C[i * N + j]
                        var k = k_block
                        while k < k_end {
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

func transpose_in_place(A: [][]float, int N) [][]float {
    var i = 0
    while i < N {
        var j = i + 1
        while j < N {
            var temp = A[i * N + j]
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
    var i = 0
    while i < len(A) {
        result[i] = A[i] * scalar
        i = i + 1
    }
    return result
}

func dot_product([]float A, []float B) float {
    var result = 0.0
    var i = 0
    while i < len(A) {
        result = result + A[i] * B[i]
        i = i + 1
    }
    return result
}

func vector_norm([]float A) float {
    var sum = 0.0
    var i = 0
    while i < len(A) {
        sum = sum + A[i] * A[i]
        i = i + 1
    }
    if sum < 0.0 {
        sum = 0.0 - sum
    }
    var result = 0.0
    var x = sum
    var i_iter = 0
    while i_iter < 10 {
        if x == 0.0 {
            break
        }
        result = (result + x / result) / 2.0
        i_iter = i_iter + 1
    }
    return result
}
