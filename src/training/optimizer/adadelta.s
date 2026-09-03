package neurx.optimizer.adadelta
use neurx.tensor.tensor
use neurx.tensor.new
struct adadelta_optimizer {
    float lr
    float rho
    float eps
    float weight_decay
    int step
    []float square_avg
    []float acc_delta
}

func new_adadelta(float lr, float rho, float eps, float weight_decay) adadelta_optimizer {
    adadelta_optimizer {
        lr: lr,
        rho: rho,
        eps: eps,
        weight_decay: weight_decay,
        step: 0,
        square_avg: [],
        acc_delta: [],
    }
}

func adadelta_step(adadelta_optimizer optimizer, tensor params, tensor grads) adadelta_optimizer_step_output {
    int n = len(params.data)
    optimizer.step = optimizer.step + 1
    optimizer.square_avg = ensure_adadelta_state(optimizer.square_avg, n)
    optimizer.acc_delta = ensure_adadelta_state(optimizer.acc_delta, n)
    []float out = make([]float, n)
    int i = 0
    for i < n {
        float grad = grads.data[i]
        if optimizer.weight_decay != 0.0 {
            grad = grad + optimizer.weight_decay * params.data[i]
        }
        optimizer.square_avg[i] = optimizer.rho * optimizer.square_avg[i] + (1.0 - optimizer.rho) * grad * grad
        float std = adadelta_sqrt(optimizer.square_avg[i] + optimizer.eps)
        float delta = adadelta_sqrt(optimizer.acc_delta[i] + optimizer.eps) / std * grad
        out[i] = params.data[i] - optimizer.lr * delta
        optimizer.acc_delta[i] = optimizer.rho * optimizer.acc_delta[i] + (1.0 - optimizer.rho) * delta * delta
        i = i + 1
    }
    adadelta_optimizer_step_output {
        optimizer: optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}

struct adadelta_optimizer_step_output {
    adadelta_optimizer optimizer
    tensor params
}

func ensure_adadelta_state([]float values, int n) []float {
    []float out = make([]float, n)
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

func adadelta_sqrt(float x) float {
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
