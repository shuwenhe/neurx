package neurx.inference.verify_numeric
use neurx.inference.cpu_backend.{fast_matmul_flat_opt, fast_gelu, pow_f, fast_softmax}
use std.conv.int_to_string
use std.conv.float_to_string_precision
extern "intrinsic" func __host_slice(string text, int start, int end) string

struct matrix_stats {
    float mean
    float sample
}

func float_to_string(float val) string {
    return float_to_string_precision(val, 5)

func compute_matrix_stats([][]float mat) matrix_stats {
    if len(mat) == 0 { return matrix_stats{mean: 0.0, sample: 0.0} }
    int R = len(mat)
    int C = 0
    if R > 0 { C = len(mat[0]) }
    if C == 0 { return matrix_stats{mean: 0.0, sample: 0.0} }
    int tot = R * C
    float sum = 0.0
    int r = 0
    while r < R {
        int c = 0
        while c < C {
            sum = sum + mat[r][c]
            c = c + 1
        }
        r = r + 1
    }
    float mean = sum / float(tot)
    float sample = 0.0
    int count = 0
    r = 0
    while r < R && count < 8 {
        int c = 0
        while c < C && count < 8 {
            sample = sample + mat[r][c]
            c = c + 1
            count = count + 1
        }
        r = r + 1
    }
    return matrix_stats{mean: mean, sample: sample}
}

func create_test_matrix(int rows, int cols, float scale) [][]float {
    [][]float mat = [][]float{cap: rows}
    int r = 0
    while r < rows {
        []float row = []float{cap: cols}
        int c = 0
        while c < cols {
            float val = scale * float(r * cols + c) / 1000.0
            row.push(val)
            c = c + 1
        }
        mat.push(row)
        r = r + 1
    }
    mat
}

func test_matmul_numeric() {
    print("\n=== MATMUL TEST ===\n")
    int M = 4
    int N = 8
    int P = 4
    [][]float A_mat = create_test_matrix(M, N, 1.0)
    [][]float B_mat = create_test_matrix(N, P, 0.5)
    []float A = []float{cap: M * N}
    int i = 0
    while i < M {
        int j = 0
        while j < N {
            A[i * N + j] = A_mat[i][j]
            j = j + 1
        }
        i = i + 1
    }
    []float B = []float{cap: N * P}
    i = 0
    while i < N {
        int j = 0
        while j < P {
            B[i * P + j] = B_mat[i][j]
            j = j + 1
        }
        i = i + 1
    }
    []float C = fast_matmul_flat_opt(A, B, M, N, P)
    print("A (" + int_to_string(M) + "x" + int_to_string(N) + "): ")
    matrix_stats stats_a = compute_matrix_stats(A_mat)
    print("mean=" + float_to_string(stats_a.mean) + ", sample=" + float_to_string(stats_a.sample) + "\n")
    print("B (" + int_to_string(N) + "x" + int_to_string(P) + "): ")
    matrix_stats stats_b = compute_matrix_stats(B_mat)
    print("mean=" + float_to_string(stats_b.mean) + ", sample=" + float_to_string(stats_b.sample) + "\n")
    print("C = A @ B (" + int_to_string(M) + "x" + int_to_string(P) + "): ")
    print("[")
    int k = 0
    while k < M * P && k < 8 {
        print(float_to_string(C[k]))
        if k < 7 { print(", ") }
        k = k + 1
    }
    print("...]\n")
}

func test_softmax_numeric() {
    print("\n=== SOFTMAX TEST ===\n")
    int len_x = 8
    []float logits = []float{cap: len_x}
    logits[0] = 1.0
    logits[1] = 2.0
    logits[2] = 0.5
    logits[3] = 3.0
    logits[4] = 1.5
    logits[5] = -1.0
    logits[6] = 0.0
    logits[7] = 2.5
    []float probs = []float{cap: len_x}
    fast_softmax(logits, probs, len_x)
    print("logits: [")
    int i = 0
    while i < len_x {
        print(float_to_string(logits[i]))
        if i < len_x - 1 { print(", ") }
        i = i + 1
    }
    print("]\n")
    print("probs:  [")
    i = 0
    float sum_probs = 0.0
    while i < len_x {
        print(float_to_string(probs[i]))
        sum_probs = sum_probs + probs[i]
        if i < len_x - 1 { print(", ") }
        i = i + 1
    }
    print("]\n")
    print("sum(probs) = " + float_to_string(sum_probs) + " (should be ~1.0)\n")
}

func test_gelu_numeric() {
    print("\n=== GELU TEST ===\n")
    []float test_vals = []float{cap: 5}
    test_vals[0] = -2.0
    test_vals[1] = -0.5
    test_vals[2] = 0.0
    test_vals[3] = 0.5
    test_vals[4] = 2.0
    print("GELU outputs:\n")
    int i = 0
    while i < 5 {
        float out = fast_gelu(test_vals[i])
        print("  gelu(" + float_to_string(test_vals[i]) + ") = " + float_to_string(out) + "\n")
        i = i + 1
    }
}

func test_attention_numeric() {
    print("\n=== SCALED DOT-PRODUCT ATTENTION TEST ===\n")
    int seq_len = 4
    int head_dim = 8
    [][]float Q_mat = create_test_matrix(seq_len, head_dim, 0.1)
    [][]float K_mat = create_test_matrix(seq_len, head_dim, 0.1)
    []float Q = []float{cap: seq_len * head_dim}
    []float K = []float{cap: seq_len * head_dim}
    int i = 0
    while i < seq_len {
        int j = 0
        while j < head_dim {
            Q[i * head_dim + j] = Q_mat[i][j]
            K[i * head_dim + j] = K_mat[i][j]
            j = j + 1
        }
        i = i + 1
    }
    float scale = 1.0 / pow_f(float(head_dim), 0.5)
    print("scale = 1/sqrt(" + int_to_string(head_dim) + ") = " + float_to_string(scale) + "\n")
    print("\nAttention scores (with causal mask):\n")
    int qi = 0
    while qi < seq_len {
        int kj = 0
        while kj < seq_len {
            float dot = 0.0
            int d = 0
            while d < head_dim {
                dot = dot + Q[qi * head_dim + d] * K[kj * head_dim + d]
                d = d + 1
            }
            float s = dot * scale
            if kj > qi { s = s - 1e9 }
            print("  scores[" + int_to_string(qi) + "," + int_to_string(kj) + "] = " + float_to_string(s) + "\n")
            kj = kj + 1
        }
        qi = qi + 1
    }
}

func main() {
    print("\n╔════════════════════════════════════════════════════════════════╗\n")
    print("║  NeurX Numeric Path Verification                             ║\n")
    print("║  Testing: matmul, softmax, GELU, attention                   ║\n")
    print("╚════════════════════════════════════════════════════════════════╝\n")
    test_matmul_numeric()
    test_softmax_numeric()
    test_gelu_numeric()
    test_attention_numeric()
    print("\n=== VERIFICATION COMPLETE ===\n")
}
