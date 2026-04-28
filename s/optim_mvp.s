package neurx.optim_mvp

use neurx.tensor.tensor
use neurx.tensor.new

struct sgd_optimizer {
    f32 lr
}

struct adam_optimizer {
    f32 lr
    f32 beta1
    f32 beta2
    f32 eps
    int step
    f32 beta1_pow
    f32 beta2_pow
    []f32 m
    []f32 v
}

struct rmsprop_optimizer {
    f32 lr
    f32 alpha
    f32 eps
    []f32 avg
}

struct adam_step_output {
    adam_optimizer optimizer
    tensor params
}

struct rmsprop_step_output {
    rmsprop_optimizer optimizer
    tensor params
}

func new_sgd(f32 lr) sgd_optimizer {
    sgd_optimizer {
        lr: lr,
    }
}

func new_adam(f32 lr, f32 beta1, f32 beta2, f32 eps) adam_optimizer {
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

func new_rmsprop(f32 lr, f32 alpha, f32 eps) rmsprop_optimizer {
    rmsprop_optimizer {
        lr: lr,
        alpha: alpha,
        eps: eps,
        avg: [],
    }
}

func inv_sqrt(f32 x) f32 {
    if x <= 0.0 {
        return 0.0
    }

    let mut y = 1.0
    for i in 0..5 {
        y = 0.5 * y * (3.0 - x * y * y)
    }
    y
}

func ensure_size([]f32 values, int n) []f32 {
    if len(values) == n {
        return values
    }

    let mut out = []f32{cap: n}
    for i in 0..n {
        out.push(0.0)
    }
    out
}

func step_tensor(sgd_optimizer optimizer, tensor params, tensor grads) tensor {
    let n = len(params.data)
    let mut out = []f32{cap: n}

    for i in 0..n {
        out.push(params.data[i] - optimizer.lr * grads.data[i])
    }

    new(out, params.shape, params.requires_grad)
}

func adam_step(adam_optimizer optimizer, tensor params, tensor grads) adam_step_output {
    let n = len(params.data)
    let mut m = ensure_size(optimizer.m, n)
    let mut v = ensure_size(optimizer.v, n)
    let mut out = []f32{cap: n}

    let mut step = optimizer.step + 1
    let mut beta1_pow = optimizer.beta1_pow * optimizer.beta1
    let mut beta2_pow = optimizer.beta2_pow * optimizer.beta2

    let bias_c1 = 1.0 - beta1_pow
    let bias_c2 = 1.0 - beta2_pow
    let safe_c1 = if bias_c1 > 0.0 { bias_c1 } else { 1.0 }
    let safe_c2 = if bias_c2 > 0.0 { bias_c2 } else { 1.0 }

    for i in 0..n {
        let g = grads.data[i]
        m[i] = optimizer.beta1 * m[i] + (1.0 - optimizer.beta1) * g
        v[i] = optimizer.beta2 * v[i] + (1.0 - optimizer.beta2) * g * g

        let m_hat = m[i] / safe_c1
        let v_hat = v[i] / safe_c2
        let denom = inv_sqrt(v_hat + optimizer.eps)
        out.push(params.data[i] - optimizer.lr * m_hat * denom)
    }

    let next_optimizer = adam_optimizer {
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
    let n = len(params.data)
    let mut avg = ensure_size(optimizer.avg, n)
    let mut out = []f32{cap: n}

    for i in 0..n {
        let g = grads.data[i]
        avg[i] = optimizer.alpha * avg[i] + (1.0 - optimizer.alpha) * g * g
        let denom = inv_sqrt(avg[i] + optimizer.eps)
        out.push(params.data[i] - optimizer.lr * g * denom)
    }

    let next_optimizer = rmsprop_optimizer {
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
