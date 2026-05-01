package neurx.opt.optim

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

struct rmsprop_optimizer {
    float lr
    float alpha
    float eps
    []float avg
}

func _ensure_size([]float values, int n) []float {
    if len(values) == n {
        return values
    }
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = 0.0
        i = i + 1
    }
    out
}

func _inv_sqrt(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = 1.0
    int i = 0
    while i < 6 {
        y = 0.5 * y * (3.0 - x * y * y)
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

func adam_step(adam_optimizer optimizer, tensor params, tensor grads) tensor {
    int n = len(params.data)
    []float m = _ensure_size(optimizer.m, n)
    []float v = _ensure_size(optimizer.v, n)
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
        out[i] = params.data[i] - optimizer.lr * m_hat * _inv_sqrt(v_hat + optimizer.eps)
        i = i + 1
    }

    new(out, params.shape, params.requires_grad)
}

func adamw_step(adamw_optimizer optimizer, tensor params, tensor grads) tensor {
    int n = len(params.data)
    []float m = _ensure_size(optimizer.m, n)
    []float v = _ensure_size(optimizer.v, n)
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
        float g = grads.data[i] + optimizer.weight_decay * params.data[i]
        m[i] = optimizer.beta1 * m[i] + (1.0 - optimizer.beta1) * g
        v[i] = optimizer.beta2 * v[i] + (1.0 - optimizer.beta2) * g * g
        float m_hat = m[i] / bias_c1
        float v_hat = v[i] / bias_c2
        out[i] = params.data[i] - optimizer.lr * m_hat * _inv_sqrt(v_hat + optimizer.eps)
        i = i + 1
    }

    new(out, params.shape, params.requires_grad)
}

func rmsprop_step(rmsprop_optimizer optimizer, tensor params, tensor grads) tensor {
    int n = len(params.data)
    []float avg = _ensure_size(optimizer.avg, n)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float g = grads.data[i]
        avg[i] = optimizer.alpha * avg[i] + (1.0 - optimizer.alpha) * g * g
        out[i] = params.data[i] - optimizer.lr * g * _inv_sqrt(avg[i] + optimizer.eps)
        i = i + 1
    }
    new(out, params.shape, params.requires_grad)
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
    float norm = _inv_sqrt(total_sq + eps)
    if norm > max_norm {
        norm = max_norm
    }
    norm
}
