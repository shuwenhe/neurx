package neurx.pretrain.llm.real_training
use neurx.tensor.tensor
use neurx.tensor.new
use neurx.ops
use neurx.strings

func relu(tensor x) tensor {
    int n = len(x.data)
    float[] out = float[]{cap: n}
    int i = 0
    for i < n {
        float val = x.data[i]
        if val > 0.0 {
            out[i] = val
        } else {
            out[i] = 0.0
        }
        i = i + 1
    }
    new(out, x.shape, true)
}

func relu_backward(tensor x, tensor grad_output) tensor {
    int n = len(x.data)
    float[] grad_input = float[]{cap: n}
    int i = 0
    for i < n {
        if x.data[i] > 0.0 {
            grad_input[i] = grad_output.data[i]
        } else {
            grad_input[i] = 0.0
        }
        i = i + 1
    }
    new(grad_input, grad_output.shape, true)
}

func softmax_last_dim(tensor logits) tensor {
    int n = len(logits.data)
    float[] out = float[]{cap: n}
    float max_val = logits.data[0]
    int i = 0
    for i < n {
        if logits.data[i] > max_val {
            max_val = logits.data[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    for i < n {
        float exp_val = exp_approx(logits.data[i] - max_val)
        out[i] = exp_val
        sum_exp = sum_exp + exp_val
        i = i + 1
    }
    i = 0
    for i < n {
        out[i] = out[i] / sum_exp
        i = i + 1
    }
    new(out, logits.shape, true)
}

func cross_entropy_loss(tensor logits, tensor targets) float {
    int n = len(logits.data)
    tensor probs = softmax_last_dim(logits)
    float loss = 0.0
    int i = 0
    for i < n {
        float prob = probs.data[i]
        float target = targets.data[i]
        if prob < 0.0000001 {
            prob = 0.0000001
        }
        float log_prob = log_approx(prob)
        loss = loss - target * log_prob
        i = i + 1
    }
    loss
}

func matmul(tensor A, tensor B) tensor {
    int m = A.shape[0]
    int k = A.shape[1]
    int n = B.shape[1]
    float[] c_data = float[]{cap: m * n}
    int i = 0
    for i < m {
        int j = 0
        for j < n {
            float sum = 0.0
            int p = 0
            for p < k {
                int a_idx = i * k + p
                int b_idx = p * n + j
                sum = sum + A.data[a_idx] * B.data[b_idx]
                p = p + 1
            }
            c_data[i * n + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    int[] shape = int[]{cap: 2}
    shape[0] = m
    shape[1] = n
    new(c_data, shape, true)
}

func transpose(tensor A, int dim1, int dim2) tensor {
    if dim1 != 0 || dim2 != 1 {
        return A
    }
    int rows = A.shape[0]
    int cols = A.shape[1]
    float[] trans_data = float[]{cap: rows * cols}
    int i = 0
    for i < rows {
        int j = 0
        for j < cols {
            trans_data[j * rows + i] = A.data[i * cols + j]
            j = j + 1
        }
        i = i + 1
    }
    int[] shape = int[]{cap: 2}
    shape[0] = cols
    shape[1] = rows
    new(trans_data, shape, true)
}

func sum_first_dim(tensor x, bool keepdim) tensor {
    int rows = x.shape[0]
    int cols = x.shape[1]
    float[] out = float[]{cap: cols}
    int j = 0
    for j < cols {
        float sum = 0.0
        int i = 0
        for i < rows {
            sum = sum + x.data[i * cols + j]
            i = i + 1
        }
        out[j] = sum
        j = j + 1
    }
    int[] shape = int[]{cap: 1}
    shape[0] = cols
    new(out, shape, true)
}

struct adamw_state {
    tensor params
    tensor grad
    tensor m
    tensor v
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
    int step
}

func adamw_update(adamw_state state) tensor {
    float beta1 = state.beta1
    float beta2 = state.beta2
    float lr = state.lr
    float eps = state.eps
    float wd = state.weight_decay
    int n = len(state.params.data)
    float[] new_params = float[]{cap: n}
    int i = 0
    for i < n {
        float g = state.grad.data[i]
        float m = state.m.data[i] * beta1 + g * (1.0 - beta1)
        float v = state.v.data[i] * beta2 + g * g * (1.0 - beta2)
        float m_hat = m / (1.0 - pow_approx(beta1, state.step as float))
        float v_hat = v / (1.0 - pow_approx(beta2, state.step as float))
        float p = state.params.data[i]
        p = p - lr * m_hat / (sqrt_approx(v_hat) + eps)
        p = p * (1.0 - lr * wd)
        new_params[i] = p
        i = i + 1
    }
    new(new_params, state.params.shape, true)
}

func grad_logits(tensor logits, tensor targets) tensor {
    tensor probs = softmax_last_dim(logits)
    int n = len(probs.data)
    float[] grad = float[]{cap: n}
    int i = 0
    for i < n {
        grad[i] = probs.data[i] - targets.data[i]
        i = i + 1
    }
    new(grad, logits.shape, true)
}

func exp_approx(float x) float {
    if x < -20.0 {
        return 0.0
    }
    if x > 20.0 {
        return 10000000.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    for i <= 10 {
        term = term * x / (i as float)
        result = result + term
        i = i + 1
    }
    result
}

func log_approx(float x) float {
    if x <= 0.0 {
        return -20.0
    }
    float result = 0.0
    float xx = (x - 1.0) / (x + 1.0)
    float xx2 = xx * xx
    float xx_power = xx
    int i = 0
    for i < 10 {
        result = result + xx_power / ((2 * i + 1) as float)
        xx_power = xx_power * xx2
        i = i + 1
    }
    result * 2.0
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x
    int i = 0
    for i < 5 {
        guess = (guess + x / guess) * 0.5
        i = i + 1
    }
    guess
}

func pow_approx(float x, float y) float {
    exp_approx(y * log_approx(x))
}

func print_training_progress(int step, float loss, float lr, int tokens_seen) () {
    println("[Step " + int_to_str(step, 0) + "] Loss: " + fmt_float(loss, 4) + " | LR: " + fmt_float(lr, 6) + " | Tokens: " + int_to_str(tokens_seen, 0))
}

func int_to_str(int n, int fallback) string {
    if n == 0 {
        return "0"
    }
    string result = ""
    int num = n
    if num < 0 {
        result = "-"
        num = 0 - num
    }
    for num > 0 {
        int digit = num % 10
        result = string_char(48 + digit) + result
        num = num / 10
    }
    result
}

func string_char(int code) string {
    string(code)
}

func fmt_float(float f, int precision) string {
    int int_part = f as int
    string result = int_to_str(int_part, 0)
    result = result + "."
    float frac = f - (int_part as float)
    if frac < 0.0 {
        frac = 0.0 - frac
    }
    int i = 0
    for i < precision {
        frac = frac * 10.0
        int digit = frac as int
        result = result + string_char(48 + digit)
        frac = frac - (digit as float)
        i = i + 1
    }
    result
}
