package neurx.optimizer.adagrad
use neurx.tensor.tensor
use neurx.tensor.new
struct adagrad_optimizer {
    float lr
    float lr_decay
    float weight_decay
    float initial_accumulator_value
    float eps
    int step
    float[] state_sum
}

func new_adagrad(
    float lr,
    float lr_decay,
    float weight_decay,
    float initial_accumulator_value,
    float eps
) adagrad_optimizer {
    adagrad_optimizer {
        lr: lr,
        lr_decay: lr_decay,
        weight_decay: weight_decay,
        initial_accumulator_value: initial_accumulator_value,
        eps: eps,
        step: 0,
        state_sum: [],
    }
}

func adagrad_step(adagrad_optimizer optimizer, tensor params, tensor grads) adagrad_optimizer_step_output {
    int n = len(params.data)
    optimizer.step = optimizer.step + 1
    optimizer.state_sum = ensure_adagrad_state(optimizer.state_sum, n, optimizer.initial_accumulator_value)
    float clr = optimizer.lr / (1.0 + float(optimizer.step - 1) * optimizer.lr_decay)
    float[] out = float[]{cap: n}
    int i = 0
    for i < n {
        float grad = grads.data[i]
        if optimizer.weight_decay != 0.0 {
            grad = grad + optimizer.weight_decay * params.data[i]
        }
        optimizer.state_sum[i] = optimizer.state_sum[i] + grad * grad
        float std = adagrad_sqrt(optimizer.state_sum[i]) + optimizer.eps
        out[i] = params.data[i] - clr * grad / std
        i = i + 1
    }
    adagrad_optimizer_step_output {
        optimizer: optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}

struct adagrad_optimizer_step_output {
    adagrad_optimizer optimizer
    tensor params
}

func ensure_adagrad_state(float[] values, int n, float initial_value) float[] {
    float[] out = float[]{cap: n}
    int i = 0
    for i < n {
        if i < len(values) {
            out[i] = values[i]
        } else {
            out[i] = initial_value
        }
        i = i + 1
    }
    out
}

func adagrad_sqrt(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = 1.0
    if x > 1.0 {
        y = x
    }
    int i = 0
    for i < 32 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}
