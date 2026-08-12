package neurx.optimizer.nadam
use neurx.tensor.tensor
use neurx.tensor.new
struct nadam_optimizer {
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
    float momentum_decay
    int step
    float mu_product
    []float exp_avg
    []float exp_avg_sq
}

func new_nadam(
    float lr,
    float beta1,
    float beta2,
    float eps,
    float weight_decay,
    float momentum_decay
) nadam_optimizer {
    nadam_optimizer {
        lr: lr,
        beta1: beta1,
        beta2: beta2,
        eps: eps,
        weight_decay: weight_decay,
        momentum_decay: momentum_decay,
        step: 0,
        mu_product: 1.0,
        exp_avg: [],
        exp_avg_sq: [],
    }
}

func nadam_step(nadam_optimizer optimizer, tensor params, tensor grads) nadam_optimizer_step_output {
    int n = len(params.data)
    optimizer.step = optimizer.step + 1
    optimizer.exp_avg = ensure_nadam_state(optimizer.exp_avg, n)
    optimizer.exp_avg_sq = ensure_nadam_state(optimizer.exp_avg_sq, n)
    float bias_correction2 = 1.0 - nadam_pow_int(optimizer.beta2, optimizer.step)
    float mu = optimizer.beta1 * (1.0 - 0.5 * nadam_pow_float(0.96, float(optimizer.step) * optimizer.momentum_decay))
    float mu_next = optimizer.beta1 * (1.0 - 0.5 * nadam_pow_float(0.96, float(optimizer.step + 1) * optimizer.momentum_decay))
    optimizer.mu_product = optimizer.mu_product * mu
    float mu_product_next = optimizer.mu_product * mu_next
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float grad = grads.data[i]
        if optimizer.weight_decay != 0.0 {
            grad = grad + optimizer.weight_decay * params.data[i]
        }
        optimizer.exp_avg[i] = optimizer.beta1 * optimizer.exp_avg[i] + (1.0 - optimizer.beta1) * grad
        optimizer.exp_avg_sq[i] = optimizer.beta2 * optimizer.exp_avg_sq[i] + (1.0 - optimizer.beta2) * grad * grad
        float denom = nadam_sqrt(optimizer.exp_avg_sq[i] / bias_correction2) + optimizer.eps
        float term_grad = optimizer.lr * (1.0 - mu) / (1.0 - optimizer.mu_product) * grad / denom
        float term_avg = optimizer.lr * mu_next / (1.0 - mu_product_next) * optimizer.exp_avg[i] / denom
        out[i] = params.data[i] - term_grad - term_avg
        i = i + 1
    }
    nadam_optimizer_step_output {
        optimizer: optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}

struct nadam_optimizer_step_output {
    nadam_optimizer optimizer
    tensor params
}

func ensure_nadam_state([]float values, int n) []float {
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

func nadam_sqrt(float x) float {
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

func nadam_pow_int(float base, int exponent) float {
    float result = 1.0
    int i = 0
    while i < exponent {
        result = result * base
        i = i + 1
    }
    result
}

func nadam_pow_float(float base, float exponent) float {
    if base <= 0.0 {
        return 0.0
    }
    return nadam_exp(exponent * nadam_ln(base))
}

func nadam_exp(float x) float {
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

func nadam_ln(float x) float {
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

