package neurx.optimizer.optim
use neurx.tensor.tensor
use neurx.tensor.new
struct sgd_optimizer {
    float lr
}

struct adam_optimizer {
    float lr
    float beta1
    float beta2
    float eps
    int step
    float beta1_pow
    float beta2_pow
    []float m
    []float v
}

struct adamw_optimizer {
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
    int step
    float beta1_pow
    float beta2_pow
    []float m
    []float v
}

struct adamw_step_output {
    adamw_optimizer optimizer
    tensor params
    float grad_norm
}

struct adam_step_output {
    adam_optimizer optimizer
    tensor params
    float grad_norm
}

struct rmsprop_optimizer {
    float lr
    float alpha
    float eps
    []float avg
}

func ensure_size([]float values, int n) []float {
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

func inv_sqrt(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    return 1.0 / sqrt_approx(x)
}

func sqrt_approx(float x) float {
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

func new_sgd(float lr) sgd_optimizer {
    sgd_optimizer { lr: lr }
}

func new_adam(float lr, float beta1, float beta2, float eps) adam_optimizer {
    adam_optimizer {
        lr: lr,
        beta1: beta1,
        beta2: beta2,
        eps: eps,
        step: 0,
        beta1_pow: 1.0,
        beta2_pow: 1.0,
        m: [],
        v: [],
    }
}

func new_adamw(float lr, float beta1, float beta2, float eps, float weight_decay) adamw_optimizer {
    adamw_optimizer {
        lr: lr,
        beta1: beta1,
        beta2: beta2,
        eps: eps,
        weight_decay: weight_decay,
        step: 0,
        beta1_pow: 1.0,
        beta2_pow: 1.0,
        m: [],
        v: [],
    }
}

func new_rmsprop(float lr, float alpha, float eps) rmsprop_optimizer {
    rmsprop_optimizer {
        lr: lr,
        alpha: alpha,
        eps: eps,
        avg: [],
    }
}

func step_tensor(sgd_optimizer optimizer, tensor params, tensor grads) tensor {
    int n = len(params.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = params.data[i] - optimizer.lr * grads.data[i]
        i = i + 1
    }
    new(out, params.shape, params.requires_grad)
}

func adam_step_state(adam_optimizer optimizer, tensor params, tensor grads) adam_step_output {
    int n = len(params.data)
    []float m = ensure_size(optimizer.m, n)
    []float v = ensure_size(optimizer.v, n)
    []float out = []float{cap: n}
    int step = optimizer.step + 1
    float beta1_pow = optimizer.beta1_pow * optimizer.beta1
    float beta2_pow = optimizer.beta2_pow * optimizer.beta2
    float bias_c1 = 1.0 - beta1_pow
    float bias_c2 = 1.0 - beta2_pow
    if bias_c1 <= 0.0 {
        bias_c1 = 1.0
    }
    if bias_c2 <= 0.0 {
        bias_c2 = 1.0
    }
    int i = 0
    while i < n {
        float g = grads.data[i]
        m[i] = optimizer.beta1 * m[i] + (1.0 - optimizer.beta1) * g
        v[i] = optimizer.beta2 * v[i] + (1.0 - optimizer.beta2) * g * g
        float m_hat = m[i] / bias_c1
        float v_hat = v[i] / bias_c2
        float denom = sqrt_approx(v_hat) + optimizer.eps
        out[i] = params.data[i] - optimizer.lr * m_hat / denom
        i = i + 1
    }
    adam_step_output {
        optimizer: adam_optimizer {
            lr: optimizer.lr,
            beta1: optimizer.beta1,
            beta2: optimizer.beta2,
            eps: optimizer.eps,
            step: step,
            beta1_pow: beta1_pow,
            beta2_pow: beta2_pow,
            m: m,
            v: v,
        },
        params: new(out, params.shape, params.requires_grad),
        grad_norm: tensor_l2_norm(grads),
    }
}

func adam_step(adam_optimizer optimizer, tensor params, tensor grads) tensor {
    adam_step_output step_out = adam_step_state(optimizer, params, grads)
    step_out.params
}

func adamw_step(adamw_optimizer optimizer, tensor params, tensor grads) tensor {
    adamw_step_output step_out = adamw_step_state(optimizer, params, grads)
    step_out.params
}

func rmsprop_step(rmsprop_optimizer optimizer, tensor params, tensor grads) tensor {
    int n = len(params.data)
    []float avg = ensure_size(optimizer.avg, n)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float g = grads.data[i]
        avg[i] = optimizer.alpha * avg[i] + (1.0 - optimizer.alpha) * g * g
        float denom = sqrt_approx(avg[i]) + optimizer.eps
        out[i] = params.data[i] - optimizer.lr * g / denom
        i = i + 1
    }
    new(out, params.shape, params.requires_grad)
}

func tensor_l2_norm(tensor value) float {
    float total_sq = 0.0
    int i = 0
    while i < len(value.data) {
        float v = value.data[i]
        total_sq = total_sq + v * v
        i = i + 1
    }
    if total_sq <= 0.0 {
        return 0.0
    }
    sqrt_approx(total_sq)
}

func scale_tensor(tensor value, float scale) tensor {
    int n = len(value.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = value.data[i] * scale
        i = i + 1
    }
    new(out, value.shape, value.requires_grad)
}

func clip_grad_tensor(tensor grads, float max_norm, float eps) tensor {
    if max_norm <= 0.0 {
        return grads
    }
    float norm = tensor_l2_norm(grads)
    if norm <= max_norm || norm <= 0.0 {
        return grads
    }
    float scale = max_norm / (norm + eps)
    scale_tensor(grads, scale)
}

func adamw_step_state(adamw_optimizer optimizer, tensor params, tensor grads) adamw_step_output {
    int n = len(params.data)
    []float m = ensure_size(optimizer.m, n)
    []float v = ensure_size(optimizer.v, n)
    []float out = []float{cap: n}
    int step = optimizer.step + 1
    float beta1_pow = optimizer.beta1_pow * optimizer.beta1
    float beta2_pow = optimizer.beta2_pow * optimizer.beta2
    float bias_c1 = 1.0 - beta1_pow
    float bias_c2 = 1.0 - beta2_pow
    if bias_c1 <= 0.0 {
        bias_c1 = 1.0
    }
    if bias_c2 <= 0.0 {
        bias_c2 = 1.0
    }
    int i = 0
    while i < n {
        float g = grads.data[i]
        m[i] = optimizer.beta1 * m[i] + (1.0 - optimizer.beta1) * g
        v[i] = optimizer.beta2 * v[i] + (1.0 - optimizer.beta2) * g * g
        float m_hat = m[i] / bias_c1
        float v_hat = v[i] / bias_c2
        float denom = sqrt_approx(v_hat) + optimizer.eps
        float decayed_param = params.data[i] * (1.0 - optimizer.lr * optimizer.weight_decay)
        out[i] = decayed_param - optimizer.lr * m_hat / denom
        i = i + 1
    }
    adamw_step_output {
        optimizer: adamw_optimizer {
            lr: optimizer.lr,
            beta1: optimizer.beta1,
            beta2: optimizer.beta2,
            eps: optimizer.eps,
            weight_decay: optimizer.weight_decay,
            step: step,
            beta1_pow: beta1_pow,
            beta2_pow: beta2_pow,
            m: m,
            v: v,
        },
        params: new(out, params.shape, params.requires_grad),
        grad_norm: tensor_l2_norm(grads),
    }
}

func clip_grad_norm([]tensor params, float max_norm, float eps) float {
    float total_sq = 0.0
    int p = 0
    while p < len(params) {
        int i = 0
        while i < len(params[p].data) {
            float g = params[p].data[i]
            total_sq = total_sq + g * g
            i = i + 1
        }
        p = p + 1
    }
    sqrt_approx(total_sq)
}

