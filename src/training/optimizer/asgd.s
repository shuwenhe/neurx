package neurx.optimizer.asgd
use neurx.tensor.tensor
use neurx.tensor.new

struct asgd_optimizer {
    float lr
    float lambd
    float alpha
    float t0
    float weight_decay
    int step
    float eta
    float mu
    []float ax
}

func new_asgd(float lr, float lambd, float alpha, float t0, float weight_decay) asgd_optimizer {
    asgd_optimizer {
        lr: lr,
        lambd: lambd,
        alpha: alpha,
        t0: t0,
        weight_decay: weight_decay,
        step: 0,
        eta: lr,
        mu: 1.0,
        ax: [],
    }
}

func asgd_step(asgd_optimizer optimizer, tensor params, tensor grads) asgd_optimizer_step_output {
    int n = len(params.data)
    optimizer.step = optimizer.step + 1
    optimizer.ax = ensure_asgd_state(optimizer.ax, n)
    []float out = []float{cap: n}
    int i = 0
    for i < n {
        float grad = grads.data[i]
        if optimizer.weight_decay != 0.0 {
            grad = grad + optimizer.weight_decay * params.data[i]
        }
        float decayed = params.data[i] * (1.0 - optimizer.lambd * optimizer.eta)
        float updated = decayed - optimizer.eta * grad
        out[i] = updated
        if optimizer.mu != 1.0 {
            optimizer.ax[i] = optimizer.ax[i] + (updated - optimizer.ax[i]) * optimizer.mu
        } else {
            optimizer.ax[i] = updated
        }
        i = i + 1
    }
    optimizer.eta = optimizer.lr / asgd_pow(1.0 + optimizer.lambd * optimizer.lr * float(optimizer.step), optimizer.alpha)
    optimizer.mu = 1.0 / asgd_max(1.0, float(optimizer.step) - optimizer.t0)
    asgd_optimizer_step_output {
        optimizer: optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}

struct asgd_optimizer_step_output {
    asgd_optimizer optimizer
    tensor params
}

func ensure_asgd_state([]float values, int n) []float {
    []float out = []float{cap: n}
    int i = 0
    for i < n {
        if i < len(values) {
            out[i] = values[i]
        } else {
            out[i] = 0.0
        }
        i = i + 1
    }
    out
}

func asgd_max(float a, float b) float {
    if a > b {
        return a
    }
    return b
}

func asgd_pow(float base, float exponent) float {
    if base <= 0.0 {
        return 0.0
    }
    return asgd_exp(exponent * asgd_ln(base))
}

func asgd_exp(float x) float {
    float result = 1.0
    float term = 1.0
    int i = 1
    for i < 25 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    result
}

func asgd_ln(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = (x - 1.0) / (x + 1.0)
    float y_sq = y * y
    float result = 0.0
    float term = y
    int i = 0
    for i < 20 {
        result = result + term / float(2 * i + 1)
        term = term * y_sq
        i = i + 1
    }
    2.0 * result
}
