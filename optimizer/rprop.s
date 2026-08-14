package neurx.optimizer.rprop
use neurx.tensor.tensor
use neurx.tensor.new
struct rprop_optimizer {
    float lr
    float etaminus
    float etaplus
    float step_size_min
    float step_size_max
    int step
    []float prev_grad
    []float step_size
}

func new_rprop(
    float lr,
    float etaminus,
    float etaplus,
    float step_size_min,
    float step_size_max
) rprop_optimizer {
    rprop_optimizer {
        lr: lr,
        etaminus: etaminus,
        etaplus: etaplus,
        step_size_min: step_size_min,
        step_size_max: step_size_max,
        step: 0,
        prev_grad: [],
        step_size: [],
    }
}

func rprop_step(rprop_optimizer optimizer, tensor params, tensor grads) rprop_optimizer_step_output {
    int n = len(params.data)
    optimizer.step = optimizer.step + 1
    optimizer.prev_grad = ensure_rprop_state(optimizer.prev_grad, n, 0.0)
    optimizer.step_size = ensure_rprop_state(optimizer.step_size, n, optimizer.lr)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float grad = grads.data[i]
        float sign_product = grad * optimizer.prev_grad[i]
        float effective_grad = grad
        if sign_product > 0.0 {
            optimizer.step_size[i] = rprop_min(optimizer.step_size[i] * optimizer.etaplus, optimizer.step_size_max)
        } else {
            if sign_product < 0.0 {
                optimizer.step_size[i] = rprop_max(optimizer.step_size[i] * optimizer.etaminus, optimizer.step_size_min)
                effective_grad = 0.0
            }
        }
        out[i] = params.data[i] - rprop_sign(effective_grad) * optimizer.step_size[i]
        optimizer.prev_grad[i] = effective_grad
        i = i + 1
    }
    rprop_optimizer_step_output {
        optimizer: optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}

struct rprop_optimizer_step_output {
    rprop_optimizer optimizer
    tensor params
}

func ensure_rprop_state([]float values, int n, float default_value) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        if i < len(values) {
            out[i] = values[i]
        } else {
            out[i] = default_value
        }
        i = i + 1
    }
    out
}

func rprop_sign(float x) float {
    if x > 0.0 {
        return 1.0
    }
    if x < 0.0 {
        return -1.0
    }
    return 0.0
}

func rprop_min(float a, float b) float {
    if a < b {
        return a
    }
    return b
}

func rprop_max(float a, float b) float {
    if a > b {
        return a
    }
    return b
}
