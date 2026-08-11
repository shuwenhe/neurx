package neurx.scheduler.pytorch_schedulers
struct multistep_lr_state {
    float base_lr
    float gamma
    []int milestones
    int current_step
    float current_lr
}

func new_multistep_lr(float base_lr, float gamma, []int milestones) multistep_lr_state {
    multistep_lr_state {
        base_lr: base_lr,
        gamma: gamma,
        milestones: milestones,
        current_step: 0,
        current_lr: base_lr,
    }
}

func multistep_lr_compute(float base_lr, float gamma, []int milestones, int step) float {
    int num_passed = 0
    int i = 0
    while i < len(milestones) {
        if step >= milestones[i] {
            num_passed = num_passed + 1
        }
        i = i + 1
    }
    return base_lr * sched_pow_int(gamma, num_passed)
}

func multistep_lr_step(multistep_lr_state sched, int step) multistep_lr_state {
    sched.current_step = step
    sched.current_lr = multistep_lr_compute(sched.base_lr, sched.gamma, sched.milestones, step)
    return sched
}

struct polynomial_lr_state {
    float base_lr
    float min_lr
    int total_iters
    float power
    int current_step
    float current_lr
}

func new_polynomial_lr(float base_lr, float min_lr, int total_iters, float power) polynomial_lr_state {
    polynomial_lr_state {
        base_lr: base_lr,
        min_lr: min_lr,
        total_iters: total_iters,
        power: power,
        current_step: 0,
        current_lr: base_lr,
    }
}

func polynomial_lr_compute(polynomial_lr_state sched, int step) float {
    if step >= sched.total_iters {
        return sched.min_lr
    }
    float decay_factor = 1.0 - float(step) / float(sched.total_iters)
    float coeff = sched_pow_float(decay_factor, sched.power)
    return sched.min_lr + (sched.base_lr - sched.min_lr) * coeff
}

func polynomial_lr_step(polynomial_lr_state sched, int step) polynomial_lr_state {
    sched.current_step = step
    sched.current_lr = polynomial_lr_compute(sched, step)
    return sched
}

struct exponential_lr_state {
    float base_lr
    float gamma
    int current_step
    float current_lr
}

func new_exponential_lr(float base_lr, float gamma) exponential_lr_state {
    exponential_lr_state {
        base_lr: base_lr,
        gamma: gamma,
        current_step: 0,
        current_lr: base_lr,
    }
}

func exponential_lr_compute(float base_lr, float gamma, int step) float {
    return base_lr * sched_pow_int(gamma, step)
}

func exponential_lr_step(exponential_lr_state sched, int step) exponential_lr_state {
    sched.current_step = step
    sched.current_lr = exponential_lr_compute(sched.base_lr, sched.gamma, step)
    return sched
}

func sched_pow_int(float base, int exponent) float {
    float result = 1.0
    int i = 0
    while i < exponent {
        result = result * base
        i = i + 1
    }
    result
}

func sched_pow_float(float base, float exponent) float {
    if base <= 0.0 {
        return 0.0
    }
    return sched_exp(exponent * sched_ln(base))
}

func sched_exp(float x) float {
    float result = 1.0
    float term = 1.0
    int i = 1
    while i < 25 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    result
}

func sched_ln(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = (x - 1.0) / (x + 1.0)
    float y_sq = y * y
    float result = 0.0
    float term = y
    int i = 0
    while i < 20 {
        result = result + term / float(2 * i + 1)
        term = term * y_sq
        i = i + 1
    }
    2.0 * result
}
