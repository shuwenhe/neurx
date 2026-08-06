package neurx.optimizer.muon
struct muon_config {
    float learning_rate
    float beta
    float c
    float weight_decay
    int   warmup_steps
}

struct muon_param_state {
    []float param
    []float momentum
    []float whitened_grad
    [][]float grad_cov
    int    step
}

struct muon_optimizer {
    muon_config config
    []muon_param_state param_states
    int global_step
    float current_lr
}

func new_muon(muon_config cfg) muon_optimizer {
    muon_optimizer {
        config: cfg,
        param_states: []muon_param_state{cap: 0},
        global_step: 0,
        current_lr: cfg.learning_rate,
    }
}

func muon_register_param(
    muon_optimizer opt,
    []float param,
    int param_size
) muon_optimizer {
    muon_param_state state
    state.param = param
    state.momentum = allocate_float_vector(param_size, 0.0)
    state.whitened_grad = allocate_float_vector(param_size, 0.0)
    state.grad_cov = allocate_2d_float_vector(param_size, param_size, 0.0)
    state.step = 0
    opt.param_states.push(state)
    return opt
}

func muon_compute_lr(muon_optimizer opt) float {
    float warmup_steps = float(opt.config.warmup_steps)
    float global_step = float(opt.global_step)
    if global_step < warmup_steps {
        return opt.config.learning_rate * (global_step / warmup_steps)
    } else {
        return opt.config.learning_rate
    }
}

func muon_set_learning_rate(muon_optimizer opt, float new_lr) muon_optimizer {
    opt.config.learning_rate = new_lr
    opt.current_lr = muon_compute_lr(opt)
    return opt
}

func compute_vector_norm([]float v, int size) float {
    float sum_sq = 0.0
    var i = 0
    while i < size {
        let val = v[i]
        sum_sq = sum_sq + (val * val)
        i = i + 1
    }
    return sqrt_approx(sum_sq)
}

func whiten_gradient(
    []float grad,
    [][]float grad_cov,
    []float whitened,
    int param_size,
    float epsilon
) {
    var i = 0
    while i < param_size {
        var j = 0
        let cov_sum = 0.0
        while j < param_size {
            cov_sum = cov_sum + grad_cov[i][j] * grad[j]
            j = j + 1
        }
        whitened[i] = cov_sum / (epsilon + compute_vector_norm(grad, param_size))
        i = i + 1
    }
}

func muon_update_param(
    muon_param_state state,
    []float gradients,
    float learning_rate,
    float beta,
    float c,
    float weight_decay,
    int param_size
) muon_param_state {
    state.step = state.step + 1
    let step = float(state.step)
    let grad_norm = compute_vector_norm(gradients, param_size)
    let epsilon = 1e-8
    var i = 0
    while i < param_size {
        var j = 0
        while j < param_size {
            let grad_outer = gradients[i] * gradients[j]
            state.grad_cov[i][j] = beta * state.grad_cov[i][j] + (1.0 - beta) * grad_outer
            j = j + 1
        }
        i = i + 1
    }
    whiten_gradient(gradients, state.grad_cov, state.whitened_grad, param_size, epsilon)
    i = 0
    while i < param_size {
        let g = state.whitened_grad[i]
        state.momentum[i] = beta * state.momentum[i] + (1.0 - beta) * g
        let param_update = state.momentum[i] + c * weight_decay * state.param[i]
        state.param[i] = state.param[i] - learning_rate * param_update
        i = i + 1
    }
    return state
}

func muon_step(
    muon_optimizer opt,
    [][]float all_gradients,
    int num_params,
    int param_size
) muon_optimizer {
    opt.current_lr = muon_compute_lr(opt)
    opt.global_step = opt.global_step + 1
    var p = 0
    while p < num_params {
        opt.param_states[p] = muon_update_param(
            opt.param_states[p],
            all_gradients[p],
            opt.current_lr,
            opt.config.beta,
            opt.config.c,
            opt.config.weight_decay,
            param_size
        )
        p = p + 1
    }
    return opt
}

func muon_get_state(muon_optimizer opt) {
}

func muon_load_state(muon_optimizer opt) {
}
