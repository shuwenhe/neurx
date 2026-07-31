package neurx.optimizer.radam

use neurx.tensor.tensor
use neurx.tensor.new

struct radam_optimizer {
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
    int step
    []float exp_avg
    []float exp_avg_sq
}

func new_radam(float lr, float beta1, float beta2, float eps, float weight_decay) radam_optimizer {
    radam_optimizer {
        lr: lr,
        beta1: beta1,
        beta2: beta2,
        eps: eps,
        weight_decay: weight_decay,
        step: 0,
        exp_avg: [],
        exp_avg_sq: [],
    }
}

func radam_step(radam_optimizer optimizer, tensor params, tensor grads) radam_optimizer_step_output {
    int n = len(params.data)
    optimizer.step = optimizer.step + 1
    optimizer.exp_avg = ensure_radam_state(optimizer.exp_avg, n)
    optimizer.exp_avg_sq = ensure_radam_state(optimizer.exp_avg_sq, n)

    float beta1_t = radam_pow(optimizer.beta1, optimizer.step)
    float beta2_t = radam_pow(optimizer.beta2, optimizer.step)
    float bias_correction1 = 1.0 - beta1_t
    float bias_correction2 = 1.0 - beta2_t

    float rho_inf = 2.0 / (1.0 - optimizer.beta2) - 1.0
    float rho_t = rho_inf - 2.0 * float(optimizer.step) * beta2_t / bias_correction2

    bool use_rectification = rho_t > 5.0
    float rect_term = 0.0
    if use_rectification {
        float numerator = (rho_t - 4.0) * (rho_t - 2.0) * rho_inf
        float denominator = (rho_inf - 4.0) * (rho_inf - 2.0) * rho_t
        rect_term = radam_sqrt(numerator / denominator)
    }

    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float grad = grads.data[i]
        if optimizer.weight_decay != 0.0 {
            grad = grad + optimizer.weight_decay * params.data[i]
        }

        optimizer.exp_avg[i] = optimizer.beta1 * optimizer.exp_avg[i] + (1.0 - optimizer.beta1) * grad
        optimizer.exp_avg_sq[i] = optimizer.beta2 * optimizer.exp_avg_sq[i] + (1.0 - optimizer.beta2) * grad * grad

        float bias_corrected_exp_avg = optimizer.exp_avg[i] / bias_correction1

        if use_rectification {
            float adaptive_lr = radam_sqrt(bias_correction2) / (radam_sqrt(optimizer.exp_avg_sq[i]) + optimizer.eps)
            out[i] = params.data[i] - optimizer.lr * bias_corrected_exp_avg * rect_term * adaptive_lr
        } else {
            out[i] = params.data[i] - optimizer.lr * bias_corrected_exp_avg
        }
        i = i + 1
    }

    radam_optimizer_step_output {
        optimizer: optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}

struct radam_optimizer_step_output {
    radam_optimizer optimizer
    tensor params
}

func ensure_radam_state([]float values, int n) []float {
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

func radam_sqrt(float x) float {
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

func radam_pow(float base, int exponent) float {
    float result = 1.0
    int i = 0
    while i < exponent {
        result = result * base
        i = i + 1
    }
    result
}
