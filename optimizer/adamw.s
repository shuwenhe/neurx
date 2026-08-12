package neurx.optimizer.adamw
struct adamw_config {
    float learning_rate
    float beta1
    float beta2
    float weight_decay
    float epsilon
    int   warmup_steps
}


struct adamw_param_state {
    []float momentum
    []float variance
    []float param
    int    step
}


struct adamw_optimizer {
    adamw_config config
    []adamw_param_state param_states
    int global_step
    float current_lr
}


func new_adamw(adamw_config cfg) adamw_optimizer {
    adamw_optimizer {
        config: cfg,
        param_states: []adamw_param_state{cap: 0},
        global_step: 0,
        current_lr: cfg.learning_rate,
    }
}


func adamw_register_param(
    adamw_optimizer opt,
    []float param,
    int param_size
) adamw_optimizer {
    adamw_param_state state
    state.param = param
    state.momentum = allocate_float_vector(param_size, 0.0)
    state.variance = allocate_float_vector(param_size, 0.0)
    state.step = 0
    opt.param_states.push(state)
    return opt
}


func adamw_compute_lr(adamw_optimizer opt) float {
    float warmup_steps = float(opt.config.warmup_steps)
    float global_step = float(opt.global_step)
    if global_step < warmup_steps {
        return opt.config.learning_rate * (global_step / warmup_steps)
    } else {
        return opt.config.learning_rate
    }
}


func adamw_set_learning_rate(adamw_optimizer opt, float new_lr) adamw_optimizer {
    opt.config.learning_rate = new_lr
    opt.current_lr = adamw_compute_lr(opt)
    return opt
}


func adamw_update_param(
    adamw_param_state state,
    []float gradients,
    float learning_rate,
    float beta1,
    float beta2,
    float weight_decay,
    float epsilon,
    int param_size
) adamw_param_state {
    state.step = state.step + 1
    let step = float(state.step)
    let bias_correction1 = 1.0 - pow_approx(beta1, step)
    let bias_correction2 = 1.0 - pow_approx(beta2, step)
    let corrected_lr = learning_rate * sqrt_approx(bias_correction2) / bias_correction1
    var i = 0
    while i < param_size {
        let grad = gradients[i]
        state.momentum[i] = beta1 * state.momentum[i] + (1.0 - beta1) * grad
        let grad_sq = grad * grad
        state.variance[i] = beta2 * state.variance[i] + (1.0 - beta2) * grad_sq
        let m_hat = state.momentum[i]
        let v_hat = state.variance[i]
        let denom = sqrt_approx(v_hat) + epsilon
        let step_size = corrected_lr / denom
        state.param[i] = state.param[i] - step_size * m_hat
        state.param[i] = state.param[i] * (1.0 - weight_decay * learning_rate)
        i = i + 1
    }
    return state
}


func adamw_step(
    adamw_optimizer opt,
    [][]float gradients,
    []int param_sizes
) adamw_optimizer {
    opt.current_lr = adamw_compute_lr(opt)
    opt.global_step = opt.global_step + 1
    var param_idx = 0
    while param_idx < len(opt.param_states) {
        let param_size = param_sizes[param_idx]
        let grad = gradients[param_idx]
        opt.param_states[param_idx] = adamw_update_param(
            opt.param_states[param_idx],
            grad,
            opt.current_lr,
            opt.config.beta1,
            opt.config.beta2,
            opt.config.weight_decay,
            opt.config.epsilon,
            param_size
        )
        param_idx = param_idx + 1
    }
    return opt
}


func adamw_zero_grad(adamw_optimizer opt) adamw_optimizer {
    return opt
}


func adamw_get_learning_rate(adamw_optimizer opt) float {
    return opt.current_lr
}


func adamw_get_step(adamw_optimizer opt) int {
    return opt.global_step
}


struct adamw_state_dict {
    int global_step
    float current_lr
    []adamw_param_state param_states
}


func adamw_state_dict(adamw_optimizer opt) adamw_state_dict {
    adamw_state_dict {
        global_step: opt.global_step,
        current_lr: opt.current_lr,
        param_states: opt.param_states,
    }
}


func adamw_load_state_dict(
    adamw_optimizer opt,
    adamw_state_dict state_dict
) adamw_optimizer {
    opt.global_step = state_dict.global_step
    opt.current_lr = state_dict.current_lr
    opt.param_states = state_dict.param_states
    return opt
}


func allocate_float_vector(int size, float init_val) []float {
    []float v = []float{cap: size}
    var i = 0
    while i < size {
        v.push(init_val)
        i = i + 1
    }
    return v
}


func pow_approx(float x, float y) float {
    if y == 1.0 {
        return x
    }
    if y == 2.0 {
        return x * x
    }
    let ln_x = log_approx(x)
    return exp_approx(y * ln_x)
}


func log_approx(float x) float {
    if x <= 0.0 {
        return -100.0
    }
    if x == 1.0 {
        return 0.0
    }
    let t = (x - 1.0) / (x + 1.0)
    let t2 = t * t
    let result = 2.0 * (t + t2 * t / 3.0 + t2 * t2 * t / 5.0 + t2 * t2 * t2 * t / 7.0)
    return result
}


func exp_approx(float x) float {
    if x > 20.0 {
        return 2147483647.0
    }
    if x < -20.0 {
        return 0.0000001
    }
    let result = 1.0
    let term = 1.0
    var i = 1
    while i <= 15 {
        let term_new = term * x / float(i)
        let result_new = result + term_new
        if abs_approx(term_new) < 1e-10 {
            return result_new
        }
        result = result_new
        term = term_new
        i = i + 1
    }
    return result
}


func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    let guess = x / 2.0
    var result = guess
    var i = 0
    while i < 10 {
        let new_guess = (result + x / result) / 2.0
        if abs_approx(new_guess - result) < 1e-10 {
            return new_guess
        }
        result = new_guess
        i = i + 1
    }
    return result
}


func abs_approx(float x) float {
    if x < 0.0 {
        return -x
    }
    return x
}

