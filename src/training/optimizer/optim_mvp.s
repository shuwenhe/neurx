package neurx.optimizer.optim_mvp
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

struct rmsprop_optimizer {
    float lr
    float alpha
    float eps
    []float avg
}

struct adam_step_output {
    adam_optimizer optimizer
    tensor params
}

struct rmsprop_step_output {
    rmsprop_optimizer optimizer
    tensor params
}

func new_sgd(float lr) sgd_optimizer {
    sgd_optimizer {
        lr: lr,
    }
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

func new_rmsprop(float lr, float alpha, float eps) rmsprop_optimizer {
    rmsprop_optimizer {
        lr: lr,
        alpha: alpha,
        eps: eps,
        avg: [],
    }
}

func inv_sqrt(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = 1.0
    for i in 0..5 {
        y = 0.5 * y * (3.0 - x * y * y)
    }
    y
}

func ensure_size([]float values, int n) []float {
    if len(values) == n {
        return values
    }
    []float out = make([]float, n)
    for i in 0..n {
        out = append(out, 0.0)
    }
    out
}

func step_tensor(sgd_optimizer optimizer, tensor params, tensor grads) tensor {
    int n = len(params.data)
    []float out = make([]float, n)
    for i in 0..n {
        out = append(out, params.data[i] - optimizer.lr * grads.data[i])
    }
    new(out, params.shape, params.requires_grad)
}

func adam_step(adam_optimizer optimizer, tensor params, tensor grads) adam_step_output {
    int n = len(params.data)
    []float m = ensure_size(optimizer.m, n)
    []float v = ensure_size(optimizer.v, n)
    []float out = make([]float, n)
    int step = optimizer.step + 1
    float beta1_pow = optimizer.beta1_pow * optimizer.beta1
    float beta2_pow = optimizer.beta2_pow * optimizer.beta2
    float bias_c1 = 1.0 - beta1_pow
    float bias_c2 = 1.0 - beta2_pow
    float safe_c1 = if bias_c1 > 0.0 { bias_c1 } else { 1.0 }
    float safe_c2 = if bias_c2 > 0.0 { bias_c2 } else { 1.0 }
    for i in 0..n {
        float g = grads.data[i]
        m[i] = optimizer.beta1 * m[i] + (1.0 - optimizer.beta1) * g
        v[i] = optimizer.beta2 * v[i] + (1.0 - optimizer.beta2) * g * g
        float m_hat = m[i] / safe_c1
        float v_hat = v[i] / safe_c2
        float denom = inv_sqrt(v_hat + optimizer.eps)
        out = append(out, params.data[i] - optimizer.lr * m_hat * denom)
    }
    adam_optimizer next_optimizer = adam_optimizer {
        lr: optimizer.lr,
        beta1: optimizer.beta1,
        beta2: optimizer.beta2,
        eps: optimizer.eps,
        step: step,
        beta1_pow: beta1_pow,
        beta2_pow: beta2_pow,
        m: m,
        v: v,
    }
    adam_step_output {
        optimizer: next_optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}

func rmsprop_step(rmsprop_optimizer optimizer, tensor params, tensor grads) rmsprop_step_output {
    int n = len(params.data)
    []float avg = ensure_size(optimizer.avg, n)
    []float out = make([]float, n)
    for i in 0..n {
        float g = grads.data[i]
        avg[i] = optimizer.alpha * avg[i] + (1.0 - optimizer.alpha) * g * g
        float denom = inv_sqrt(avg[i] + optimizer.eps)
        out = append(out, params.data[i] - optimizer.lr * g * denom)
    }
    rmsprop_optimizer next_optimizer = rmsprop_optimizer {
        lr: optimizer.lr,
        alpha: optimizer.alpha,
        eps: optimizer.eps,
        avg: avg,
    }
    rmsprop_step_output {
        optimizer: next_optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}
