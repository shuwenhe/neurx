package neurx.util.math

func exp_approx(float x) float {
    if x >= 20.0 {
        return 485165195.4097903
    }
    if x <= -20.0 {
        return 0.0000000020611536
    }
    float reduced = x
    int power_of_two = 0
    for reduced > 0.34657359027997265 {
        reduced = reduced - 0.6931471805599453
        power_of_two = power_of_two + 1
    }
    for reduced < -0.34657359027997265 {
        reduced = reduced + 0.6931471805599453
        power_of_two = power_of_two - 1
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    for i <= 12 {
        term = term * reduced / i
        result = result + term
        i = i + 1
    }
    for power_of_two > 0 {
        result = result * 2.0
        power_of_two = power_of_two - 1
    }
    for power_of_two < 0 {
        result = result * 0.5
        power_of_two = power_of_two + 1
    }
    result
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x
    int i = 0
    for i < 8 {
        guess = 0.5 * (guess + x / guess)
        i = i + 1
    }
    guess
}

func log_approx(float x) float {
    if x <= 0.0 {
        return -100.0
    }
    float z = (x - 1.0) / (x + 1.0)
    float z2 = z * z
    float result = z
    float term = z
    int k = 1
    for k < 20 {
        term = term * z2
        result = result + term / (2 * k + 1)
        k = k + 1
    }
    2.0 * result
}

func tanh_approx(float x) float {
    float ep = exp_approx(x)
    float en = exp_approx(-x)
    float denom = ep + en
    if denom == 0.0 {
        return 0.0
    }
    (ep - en) / denom
}

func cos_approx(float x) float {
    float x2 = x * x
    float result = 1.0
    float term = 1.0
    int n = 0
    for n <= 25 {
        if n > 0 {
            term = term * (-x2) / float((2*n-1)*2*n)
        }
        result = result + term
        n = n + 1
    }
    result
}

func sin_approx(float x) float {
    float x2 = x * x
    float result = x
    float term = x
    int n = 1
    for n <= 25 {
        term = term * (-x2) / float((2*n)*(2*n+1))
        result = result + term
        n = n + 1
    }
    result
}

func softmax_1d([]float values) []float {
    int n = len(values)
    []float out = []float{cap: n}
    float max_v = values[0]
    int i = 1
    for i < n {
        if values[i] > max_v {
            max_v = values[i]
        }
        i = i + 1
    }
    float denom = 0.0
    i = 0
    for i < n {
        float v = exp_approx(values[i] - max_v)
        out[i] = v
        denom = denom + v
        i = i + 1
    }
    if denom == 0.0 {
        denom = 1.0
    }
    i = 0
    for i < n {
        out[i] = out[i] / denom
        i = i + 1
    }
    out
}

func gelu_approx(float x) float {
    float x3 = x * x * x
    float inner = 0.7978845608 * (x + 0.044715 * x3)
    0.5 * x * (1.0 + tanh_approx(inner))
}

func allocate_float(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    for i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func allocate_int(int size, int init_val) []int {
    []int v = []int{cap: size}
    int i = 0
    for i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func allocate_bool(int size, bool init_val) []bool {
    []bool v = []bool{cap: size}
    int i = 0
    for i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    for i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    for i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func min_int(int a, int b) int {
    if a < b {
        return a
    }
    b
}

func max_int(int a, int b) int {
    if a > b {
        return a
    }
    b
}

func min_float(float a, float b) float {
    if a < b {
        return a
    }
    b
}

func max_float(float a, float b) float {
    if a > b {
        return a
    }
    b
}

func clamp_float(float x, float min_val, float max_val) float {
    float v = x
    if v < min_val {
        v = min_val
    }
    if v > max_val {
        v = max_val
    }
    v
}

func sum_float([]float data) float {
    float acc = 0.0
    int i = 0
    for i < len(data) {
        acc = acc + data[i]
        i = i + 1
    }
    acc
}

func mean_float([]float data) float {
    int n = len(data)
    if n == 0 {
        return 0.0
    }
    sum_float(data) / float(n)
}

func matmul_flat([]float a, []float b, int m, int n, int p) []float {
    []float result = allocate_float(m * p, 0.0)
    int i = 0
    for i < m {
        int j = 0
        for j < p {
            int k = 0
            for k < n {
                result[i * p + j] = result[i * p + j] + a[i * n + k] * b[k * p + j]
                k = k + 1
            }
            j = j + 1
        }
        i = i + 1
    }
    result
}

func apply_bias([]float input, []float bias, int batch_size, int dim) []float {
    int i = 0
    for i < batch_size {
        int j = 0
        for j < dim {
            input[i * dim + j] = input[i * dim + j] + bias[j]
            j = j + 1
        }
        i = i + 1
    }
    input
}

func matmul_bias([]float a, []float w, []float b, int m, int n, int p) []float {
    []float result = allocate_float(m * p, 0.0)
    int i = 0
    for i < m {
        int j = 0
        for j < p {
            result[i * p + j] = b[j]
            int k = 0
            for k < n {
                result[i * p + j] = result[i * p + j] + a[i * n + k] * w[k * p + j]
                k = k + 1
            }
            j = j + 1
        }
        i = i + 1
    }
    result
}

func top_k_select([]float probs, int size, int k) ([]int, []float) {
    []int indices = allocate_int(k, -1)
    []float values = allocate_float(k, 0.0)
    []bool selected = allocate_bool(size, false)
    int idx = 0
    for idx < k {
        float max_val = -1.0
        int max_idx = -1
        int i = 0
        for i < size {
            if !selected[i] && probs[i] > max_val {
                max_val = probs[i]
                max_idx = i
            }
            i = i + 1
        }
        if max_idx >= 0 {
            selected[max_idx] = true
            indices[idx] = max_idx
            values[idx] = max_val
        }
        idx = idx + 1
    }
    (indices, values)
}

func compute_entropy([]float probs, int size) float {
    float entropy = 0.0
    int i = 0
    for i < size {
        if probs[i] > 0.0 {
            entropy = entropy - probs[i] * log_approx(probs[i])
        }
        i = i + 1
    }
    entropy
}

func compute_variance([]float data, int size) float {
    float mean = mean_float(data)
    float variance = 0.0
    int i = 0
    for i < size {
        variance = variance + (data[i] - mean) * (data[i] - mean)
        i = i + 1
    }
    variance / float(size)
}
