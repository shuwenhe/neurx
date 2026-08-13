package neurx.nn.activations
use neurx.tensor.tensor

func exp_approx(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 10 {
        term = term * x / i
        result = result + term
        i = i + 1
    }
    result
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x
    int i = 0
    while i < 8 {
        guess = 0.5 * (guess + x / guess)
        i = i + 1
    }
    guess
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

func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func get_tensor_data(tensor t, int index) float {
    t.data[index]
}

func relu(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float v = input.data[i]
        if v > 0.0 {
            out[i] = v
        } else {
            out[i] = 0.0
        }
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func leaky_relu(tensor input, float negative_slope) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float v = input.data[i]
        if v > 0.0 {
            out[i] = v
        } else {
            out[i] = negative_slope * v
        }
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func elu(tensor input, float alpha) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float v = input.data[i]
        if v > 0.0 {
            out[i] = v
        } else {
            out[i] = alpha * (exp_approx(v) - 1.0)
        }
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func sigmoid(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = 1.0 / (1.0 + exp_approx(-input.data[i]))
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func tanh(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = tanh_approx(input.data[i])
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func gelu(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float x = input.data[i]
        float x3 = x * x * x
        float inner = 0.7978845608 * (x + 0.044715 * x3)
        out[i] = 0.5 * x * (1.0 + tanh_approx(inner))
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func silu(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float x = input.data[i]
        out[i] = x / (1.0 + exp_approx(-x))
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func softplus(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float x = input.data[i]
        out[i] = log_approx(1.0 + exp_approx(x))
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func mish(tensor input) tensor {
    tensor sp = softplus(input)
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = input.data[i] * tanh_approx(sp.data[i])
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func clamp_value(float x, float min_value, float max_value) float {
    float v = x
    if v < min_value {
        v = min_value
    }
    if v > max_value {
        v = max_value
    }
    v
}

func abs_value(float x) float {
    if x < 0.0 {
        return 0.0 - x
    }
    x
}

func relu6(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = clamp_value(input.data[i], 0.0, 6.0)
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func hardtanh(tensor input, float min_value, float max_value) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = clamp_value(input.data[i], min_value, max_value)
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func hardsigmoid(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = clamp_value((input.data[i] + 3.0) / 6.0, 0.0, 1.0)
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func hardswish(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float gate = clamp_value((input.data[i] + 3.0) / 6.0, 0.0, 1.0)
        out[i] = input.data[i] * gate
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func threshold(tensor input, float threshold_value, float value) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        if input.data[i] > threshold_value {
            out[i] = input.data[i]
        } else {
            out[i] = value
        }
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func softsign(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = input.data[i] / (1.0 + abs_value(input.data[i]))
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func softmax_1d([]float values) []float {
    int n = len(values)
    []float out = []float{cap: n}
    float max_v = values[0]
    int i = 1
    while i < n {
        if values[i] > max_v {
            max_v = values[i]
        }
        i = i + 1
    }
    float denom = 0.0
    i = 0
    while i < n {
        float v = exp_approx(values[i] - max_v)
        out[i] = v
        denom = denom + v
        i = i + 1
    }
    if denom == 0.0 {
        denom = 1.0
    }
    i = 0
    while i < n {
        out[i] = out[i] / denom
        i = i + 1
    }
    out
}

func softmax(tensor input) tensor {
    int rows = input.shape[0]
    int cols = input.shape[1]
    []float out = []float{cap: rows * cols}
    int r = 0
    while r < rows {
        int base = r * cols
        float max_v = get_tensor_data(input, base)
        int c = 1
        while c < cols {
            if get_tensor_data(input, base + c) > max_v {
                max_v = get_tensor_data(input, base + c)
            }
            c = c + 1
        }
        float denom = 0.0
        c = 0
        while c < cols {
            float v = exp_approx(get_tensor_data(input, base + c) - max_v)
            out[base + c] = v
            denom = denom + v
            c = c + 1
        }
        if denom == 0.0 {
            denom = 1.0
        }
        c = 0
        while c < cols {
            out[base + c] = out[base + c] / denom
            c = c + 1
        }
        r = r + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func log_softmax(tensor input) tensor {
    tensor sm = softmax(input)
    int n = len(sm.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float v = sm.data[i]
        if v < 0.000000000001 {
            v = 0.000000000001
        }
        out[i] = log_approx(v)
        i = i + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
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
    while k < 20 {
        term = term * z2
        result = result + term / (2 * k + 1)
        k = k + 1
    }
    2.0 * result
}
