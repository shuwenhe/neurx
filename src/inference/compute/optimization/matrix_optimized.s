package neurx.inference.matrix_optimized
use std.conv.int_to_string
struct matrix {
    float[] data
    int rows
    int cols
}
func matrix_new(int rows, int cols) matrix {
    matrix m
    m.data = float[]{cap: rows * cols}
    m.rows = rows
    m.cols = cols
    m
}
func matrix_at(matrix m, int i, int j) float {
    m.data[i * m.cols + j]
}
func matrix_set(matrix m, int i, int j, float value) {
    m.data[i * m.cols + j] = value
}
func matrix_mult_naive(matrix A, matrix B) matrix {
    matrix result = matrix_new(A.rows, B.cols)
    int i = 0
    for i < A.rows {
        int j = 0
        for j < B.cols {
            float sum = 0.0
            int k = 0
            for k < A.cols {
                sum = sum + matrix_at(A, i, k) * matrix_at(B, k, j)
                k = k + 1
            }
            matrix_set(result, i, j, sum)
            j = j + 1
        }
        i = i + 1
    }
    result
}
func matrix_mult_blocked(matrix A, matrix B) matrix {
    int BLOCK_SIZE = 64
    matrix result = matrix_new(A.rows, B.cols)
    int idx = 0
    for idx < len(result.data) {
        result.data[idx] = 0.0
        idx = idx + 1
    }
    int i_block = 0
    for i_block < A.rows {
        int i_end = min_int(i_block + BLOCK_SIZE, A.rows)
        int k_block = 0
        for k_block < A.cols {
            int k_end = min_int(k_block + BLOCK_SIZE, A.cols)
            int j_block = 0
            for j_block < B.cols {
                int j_end = min_int(j_block + BLOCK_SIZE, B.cols)
                int i = i_block
                for i < i_end {
                    int j = j_block
                    for j < j_end {
                        float sum = matrix_at(result, i, j)
                        int k = k_block
                        for k < k_end {
                            sum = sum + matrix_at(A, i, k) * matrix_at(B, k, j)
                            k = k + 1
                        }
                        matrix_set(result, i, j, sum)
                        j = j + 1
                    }
                    i = i + 1
                }
                j_block = j_end
            }
            k_block = k_end
        }
        i_block = i_end
    }
    result
}
func matvec_optimized(float[] v, matrix W) float[] {
    float[] result = float[]{cap: W.cols}
    int j = 0
    for j < W.cols {
        float sum = 0.0
        int i = 0
        for i < len(v) {
            sum = sum + v[i] * matrix_at(W, i, j)
            i = i + 1
        }
        result[j] = sum
        j = j + 1
    }
    result
}
func matvec_row_major(float[] v, float[] W_data, int W_rows, int W_cols) float[] {
    float[] result = float[]{cap: W_cols}
    int i = 0
    for i < W_rows {
        float sum = 0.0
        int j = 0
        for j < len(v) {
            sum = sum + v[j] * W_data[i * W_cols + j]
            j = j + 1
        }
        result[i] = sum
        i = i + 1
    }
    result
}
func matmul_with_activation(matrix A, matrix B, string activation) matrix {
    matrix result = matrix_mult_blocked(A, B)
    int i = 0
    for i < len(result.data) {
        float val = result.data[i]
        if activation == "relu" {
            if val < 0.0 {
                val = 0.0
            }
        }
        else if activation == "gelu" {
            float sig = sigmoid_approx(1.702 * val)
            val = val * sig
        }
        else if activation == "silu" {
            val = val * sigmoid_approx(val)
        }
        result.data[i] = val
        i = i + 1
    }
    result
}
func sigmoid_approx(float x) float {
    if x > 0.0 {
        return 1.0 / (1.0 + exp_approx(-x))
    }
    float exp_x = exp_approx(x)
    exp_x / (1.0 + exp_x)
}
func exp_approx(float x) float {
    float result = 1.0
    float term = 1.0
    int i = 1
    for i < 10 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    result
}
func min_int(int a, int b) int {
    if a < b { return a }
    b
}
func float(int x) float {
    x * 1.0
}
