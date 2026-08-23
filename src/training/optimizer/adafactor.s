package neurx.optimizer.adafactor
use neurx.tensor.tensor
use neurx.tensor.new

struct adafactor_optimizer {
    float lr
    float beta2_decay
    float eps1
    float eps2
    float clip_threshold
    float weight_decay
    int step
    []float row_var
    []float col_var
    []float variance
    int num_rows
    int num_cols
}

func new_adafactor(
    float lr,
    float beta2_decay,
    float eps1,
    float eps2,
    float clip_threshold,
    float weight_decay
) adafactor_optimizer {
    adafactor_optimizer {
        lr: lr,
        beta2_decay: beta2_decay,
        eps1: eps1,
        eps2: eps2,
        clip_threshold: clip_threshold,
        weight_decay: weight_decay,
        step: 0,
        row_var: [],
        col_var: [],
        variance: [],
        num_rows: 0,
        num_cols: 0,
    }
}

func adafactor_step_2d(
    adafactor_optimizer optimizer,
    tensor params,
    tensor grads,
    int num_rows,
    int num_cols
) adafactor_optimizer_step_output {
    optimizer.step = optimizer.step + 1
    optimizer.num_rows = num_rows
    optimizer.num_cols = num_cols
    optimizer.row_var = ensure_adafactor_state(optimizer.row_var, num_rows)
    optimizer.col_var = ensure_adafactor_state(optimizer.col_var, num_cols)
    float beta2_t = 1.0 - adafactor_pow(float(optimizer.step), 0.0 - optimizer.beta2_decay)
    []float row_sums = []float{cap: num_rows}
    []float col_sums = []float{cap: num_cols}
    int r = 0
    while r < num_rows {
        row_sums[r] = 0.0
        r = r + 1
    }
    int c = 0
    while c < num_cols {
        col_sums[c] = 0.0
        c = c + 1
    }
    int idx = 0
    while idx < num_rows * num_cols {
        int row = idx / num_cols
        int col = idx - row * num_cols
        float grad = grads.data[idx]
        float grad_sq = grad * grad + optimizer.eps1
        row_sums[row] = row_sums[row] + grad_sq
        col_sums[col] = col_sums[col] + grad_sq
        idx = idx + 1
    }
    r = 0
    while r < num_rows {
        float row_mean = row_sums[r] / float(num_cols)
        optimizer.row_var[r] = optimizer.row_var[r] * (1.0 - beta2_t) + row_mean * beta2_t
        r = r + 1
    }
    c = 0
    while c < num_cols {
        float col_mean = col_sums[c] / float(num_rows)
        optimizer.col_var[c] = optimizer.col_var[c] * (1.0 - beta2_t) + col_mean * beta2_t
        c = c + 1
    }
    float total_row_var = 0.0
    r = 0
    while r < num_rows {
        total_row_var = total_row_var + optimizer.row_var[r]
        r = r + 1
    }
    int n = num_rows * num_cols
    []float update = []float{cap: n}
    idx = 0
    while idx < n {
        int row = idx / num_cols
        int col = idx - row * num_cols
        float denom = adafactor_sqrt(optimizer.row_var[row] * optimizer.col_var[col] / total_row_var)
        update[idx] = grads.data[idx] / (denom + optimizer.eps1)
        idx = idx + 1
    }
    float rms = adafactor_rms(update, n)
    float clip_denom = adafactor_max(1.0, rms / optimizer.clip_threshold)
    []float out = []float{cap: n}
    idx = 0
    while idx < n {
        float scaled = update[idx] / clip_denom
        float new_param = params.data[idx]
        if optimizer.weight_decay != 0.0 {
            new_param = new_param - optimizer.lr * optimizer.weight_decay * new_param
        }
        out[idx] = new_param - optimizer.lr * scaled
        idx = idx + 1
    }
    adafactor_optimizer_step_output {
        optimizer: optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}

struct adafactor_optimizer_step_output {
    adafactor_optimizer optimizer
    tensor params
}

func ensure_adafactor_state([]float values, int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        if i < len(values) {
            out[i] = values[i]
        } else {
            out[i] = 0.0
        }
        i = i + 1
    }
    out
}

func adafactor_rms([]float values, int n) float {
    if n == 0 {
        return 0.0
    }
    float sum_sq = 0.0
    int i = 0
    while i < n {
        sum_sq = sum_sq + values[i] * values[i]
        i = i + 1
    }
    return adafactor_sqrt(sum_sq / float(n))
}

func adafactor_max(float a, float b) float {
    if a > b {
        return a
    }
    return b
}

func adafactor_sqrt(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = 1.0
    if x > 1.0 {
        y = x
    }
    int i = 0
    while i < 32 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func adafactor_pow(float base, float exponent) float {
    if base <= 0.0 {
        return 0.0
    }
    return adafactor_exp(exponent * adafactor_ln(base))
}

func adafactor_exp(float x) float {
    float result = 1.0
    float term = 1.0
    int i = 1
    while i < 25 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    result
}

func adafactor_ln(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = (x - 1.0) / (x + 1.0)
    float y_sq = y * y
    float result = 0.0
    float term = y
    int i = 0
    while i < 20 {
        result = result + term / float(2 * i + 1)
        term = term * y_sq
        i = i + 1
    }
    2.0 * result
}
