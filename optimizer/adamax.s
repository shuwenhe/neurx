package neurx.optimizer.adamax

use neurx.tensor.tensor
use neurx.tensor.new

struct adamax_optimizer {
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
    int step
    []float exp_avg
    []float exp_inf
}

func new_adamax(float lr, float beta1, float beta2, float eps, float weight_decay) adamax_optimizer {
    adamax_optimizer {
        lr: lr,
        beta1: beta1,
        beta2: beta2,
        eps: eps,
        weight_decay: weight_decay,
        step: 0,
        exp_avg: [],
        exp_inf: [],
    }
}

func adamax_step(adamax_optimizer optimizer, tensor params, tensor grads) adamax_optimizer_step_output {
    int n = len(params.data)
    optimizer.step = optimizer.step + 1
    optimizer.exp_avg = ensure_adamax_state(optimizer.exp_avg, n)
    optimizer.exp_inf = ensure_adamax_state(optimizer.exp_inf, n)

    float bias_correction = 1.0 - adamax_pow(optimizer.beta1, optimizer.step)
    float clr = optimizer.lr / bias_correction

    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float grad = grads.data[i]
        if optimizer.weight_decay != 0.0 {
            grad = grad + optimizer.weight_decay * params.data[i]
        }

        optimizer.exp_avg[i] = optimizer.beta1 * optimizer.exp_avg[i] + (1.0 - optimizer.beta1) * grad

        float norm_candidate = adamax_abs(grad) + optimizer.eps
        float scaled_inf = optimizer.beta2 * optimizer.exp_inf[i]
        optimizer.exp_inf[i] = adamax_max(scaled_inf, norm_candidate)

        out[i] = params.data[i] - clr * optimizer.exp_avg[i] / optimizer.exp_inf[i]
        i = i + 1
    }

    adamax_optimizer_step_output {
        optimizer: optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}

struct adamax_optimizer_step_output {
    adamax_optimizer optimizer
    tensor params
}

func ensure_adamax_state([]float values, int n) []float {
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

func adamax_abs(float x) float {
    if x < 0.0 {
        return 0.0 - x
    }
    return x
}

func adamax_max(float a, float b) float {
    if a > b {
        return a
    }
    return b
}

func adamax_pow(float base, int exponent) float {
    float result = 1.0
    int i = 0
    while i < exponent {
        result = result * base
        i = i + 1
    }
    result
}
