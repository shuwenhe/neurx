package neurx.ml.math_ops
use neurx.backends.compute_backend
use neurx.tensor.{tensor, zeros}
func matmul_2d(tensor A, tensor B) tensor {
    int m = A.shape[0]
    int n = A.shape[1]
    int p = B.shape[1]
    compute_context ctx = resolve_compute_context("", "")
    []float out_data = backend_matmul_dispatch(ctx, A.data, B.data, m, n, p)
    tensor {
        data: out_data,
        shape: [m, p],
        requires_grad: A.requires_grad || B.requires_grad,
        grad: none,
    }
}
func transpose_2d(tensor A) tensor {
    int m = A.shape[0]
    int n = A.shape[1]
    tensor result = zeros([n, m])
    int i = 0
    while i < m {
        int j = 0
        while j < n {
            result.data[j * m + i] = A.data[i * n + j]
            j = j + 1
        }
        i = i + 1
    }
    result
}
func scale_tensor(tensor A, float scale) tensor {
    tensor result = zeros(A.shape)
    int i = 0
    while i < len(A.data) {
        result.data[i] = A.data[i] * scale
        i = i + 1
    }
    result
}
func add_tensors(tensor A, tensor B) tensor {
    tensor result = zeros(A.shape)
    int i = 0
    while i < len(A.data) {
        result.data[i] = A.data[i] + B.data[i]
        i = i + 1
    }
    result
}
func sub_tensors(tensor A, tensor B) tensor {
    tensor result = zeros(A.shape)
    int i = 0
    while i < len(A.data) {
        result.data[i] = A.data[i] - B.data[i]
        i = i + 1
    }
    result
}
func mul_element_wise(tensor A, tensor B) tensor {
    tensor result = zeros(A.shape)
    int i = 0
    while i < len(A.data) {
        result.data[i] = A.data[i] * B.data[i]
        i = i + 1
    }
    result
}
func relu(tensor X) tensor {
    tensor result = zeros(X.shape)
    int i = 0
    while i < len(X.data) {
        if X.data[i] > 0.0 {
            result.data[i] = X.data[i]
        } else {
            result.data[i] = 0.0
        }
        i = i + 1
    }
    result
}
func relu_backward(tensor dY, tensor X) tensor {
    tensor result = zeros(X.shape)
    int i = 0
    while i < len(dY.data) {
        if X.data[i] > 0.0 {
            result.data[i] = dY.data[i]
        } else {
            result.data[i] = 0.0
        }
        i = i + 1
    }
    result
}
func gelu(tensor X) tensor {
    tensor result = zeros(X.shape)
    float c1 = 0.7978845608
    float c2 = 0.044715
    int i = 0
    while i < len(X.data) {
        float x = X.data[i]
        float x3 = x * x * x
        float tanh_arg = c1 * (x + c2 * x3)
        float tanh_val = tanh_approx(tanh_arg)
        result.data[i] = 0.5 * x * (1.0 + tanh_val)
        i = i + 1
    }
    result
}
func softmax(tensor logits) tensor {
    float max_val = logits.data[0]
    int i = 0
    while i < len(logits.data) {
        if logits.data[i] > max_val {
            max_val = logits.data[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    tensor exp_vals = zeros(logits.shape)
    i = 0
    while i < len(logits.data) {
        exp_vals.data[i] = exp_approx(logits.data[i] - max_val)
        sum_exp = sum_exp + exp_vals.data[i]
        i = i + 1
    }
    tensor result = zeros(logits.shape)
    i = 0
    while i < len(exp_vals.data) {
        result.data[i] = exp_vals.data[i] / sum_exp
        i = i + 1
    }
    result
}
func softmax_backward(tensor grad_output, tensor softmax_output) tensor {
    tensor result = zeros(grad_output.shape)
    float sum_term = 0.0
    int i = 0
    while i < len(softmax_output.data) {
        sum_term = sum_term + softmax_output.data[i] * grad_output.data[i]
        i = i + 1
    }
    i = 0
    while i < len(grad_output.data) {
        result.data[i] = softmax_output.data[i] * (grad_output.data[i] - sum_term)
        i = i + 1
    }
    result
}
func layer_norm(tensor X, float eps) tensor {
    float mean = 0.0
    int i = 0
    while i < len(X.data) {
        mean = mean + X.data[i]
        i = i + 1
    }
    mean = mean / float_from_int(len(X.data))
    float variance = 0.0
    i = 0
    while i < len(X.data) {
        float diff = X.data[i] - mean
        variance = variance + diff * diff
        i = i + 1
    }
    variance = variance / float_from_int(len(X.data))
    tensor result = zeros(X.shape)
    i = 0
    while i < len(X.data) {
        result.data[i] = (X.data[i] - mean) / sqrt_approx(variance + eps)
        i = i + 1
    }
    result
}
func cross_entropy_loss(tensor logits, tensor targets) float {
    float loss = 0.0
    int i = 0
    while i < len(logits.data) {
        if targets.data[i] > 0.0 {
            float prob = logits.data[i]
            if prob < 0.0000001 { prob = 0.0000001 }
            loss = loss - log_approx(prob)
        }
        i = i + 1
    }
    loss / float_from_int(len(logits.data))
}
func mse_loss(tensor predictions, tensor targets) float {
    float loss = 0.0
    int i = 0
    while i < len(predictions.data) {
        float diff = predictions.data[i] - targets.data[i]
        loss = loss + diff * diff
        i = i + 1
    }
    loss / float_from_int(len(predictions.data))
}
func float_from_int(int x) float {
    0.0 + x
}
func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    while i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}
func exp_approx(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 12 {
        term = term * x / float_from_int(i)
        result = result + term
        i = i + 1
    }
    result
}
func log_approx(float x) float {
    float v = x
    if v <= 0.0 { v = 0.000000000001 }
    float y = (v - 1.0) / (v + 1.0)
    float y2 = y * y
    float y3 = y2 * y
    float y5 = y3 * y2
    2.0 * (y + (y3 / 3.0) + (y5 / 5.0))
}
func tanh_approx(float x) float {
    float e2x = exp_approx(2.0 * x)
    (e2x - 1.0) / (e2x + 1.0)
}
func cos_approx(float x) float {
    float pi = 3.141592653589793
    float x_mod = x - float_from_int(int_from_float(x / (2.0 * pi))) * 2.0 * pi
    if x_mod > pi { x_mod = 2.0 * pi - x_mod }
    float x2 = x_mod * x_mod
    float result = 1.0
    result = result - (x2 / 2.0)
    result = result + (x2 * x2 / 24.0)
    result = result - (x2 * x2 * x2 / 720.0)
    result
}
func int_from_float(float x) int {
    int n = 0
    float y = x
    if y < 0.0 {
        while y < 0.0 {
            y = y + 1.0
            n = n - 1
        }
    }
    while y >= 1.0 {
        y = y - 1.0
        n = n + 1
    }
    n
}
func max_float(float a, float b) float {
    if a > b { return a }
    b
}
func min_float(float a, float b) float {
    if a < b { return a }
    b
}
func abs_float(float x) float {
    if x < 0.0 { return -x }
    x
}
