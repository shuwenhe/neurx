package neurx.scheduler.cyclic_schedulers
struct cyclic_lr_state {
    float base_lr
    float max_lr
    int step_size_up
    int step_size_down
    string mode
    float gamma
    int current_step
    float current_lr
}

func new_cyclic_lr(
    float base_lr,
    float max_lr,
    int step_size_up,
    int step_size_down,
    string mode,
    float gamma
) cyclic_lr_state {
    cyclic_lr_state {
        base_lr: base_lr,
        max_lr: max_lr,
        step_size_up: step_size_up,
        step_size_down: step_size_down,
        mode: mode,
        gamma: gamma,
        current_step: 0,
        current_lr: base_lr,
    }
}

func cyclic_lr_compute(cyclic_lr_state sched, int step) float {
    int total_size = sched.step_size_up + sched.step_size_down
    int cycle = step / total_size
    int step_in_cycle = step - cycle * total_size
    float x = 0.0
    if step_in_cycle <= sched.step_size_up {
        x = float(step_in_cycle) / float(sched.step_size_up)
    } else {
        x = 1.0 - float(step_in_cycle - sched.step_size_up) / float(sched.step_size_down)
    }
    float base_height = (sched.max_lr - sched.base_lr) * cyclic_max(0.0, x)
    float scale = 1.0
    if sched.mode == "triangular2" {
        scale = 1.0 / cyclic_pow_int(2.0, cycle)
    } else {
        if sched.mode == "exp_range" {
            scale = cyclic_pow_int(sched.gamma, step)
        }
    }
    return sched.base_lr + base_height * scale
}

func cyclic_lr_step(cyclic_lr_state sched, int step) cyclic_lr_state {
    sched.current_step = step
    sched.current_lr = cyclic_lr_compute(sched, step)
    return sched
}

struct cosine_warm_restarts_state {
    float base_lr
    float min_lr
    int t_0
    int t_mult
    int current_step
    float current_lr
}

func new_cosine_warm_restarts(float base_lr, float min_lr, int t_0, int t_mult) cosine_warm_restarts_state {
    cosine_warm_restarts_state {
        base_lr: base_lr,
        min_lr: min_lr,
        t_0: t_0,
        t_mult: t_mult,
        current_step: 0,
        current_lr: base_lr,
    }
}

func cosine_warm_restarts_compute(cosine_warm_restarts_state sched, int step) float {
    int t_cur = step
    int t_i = sched.t_0
    if sched.t_mult == 1 {
        t_cur = step - (step / sched.t_0) * sched.t_0
    } else {
        int n = 0
        int accumulated = 0
        int current_len = sched.t_0
        while accumulated + current_len <= step {
            accumulated = accumulated + current_len
            current_len = current_len * sched.t_mult
            n = n + 1
        }
        t_cur = step - accumulated
        t_i = current_len
    }
    float cos_arg = cyclic_pi() * float(t_cur) / float(t_i)
    float coeff = 0.5 * (1.0 + cyclic_cos(cos_arg))
    return sched.min_lr + (sched.base_lr - sched.min_lr) * coeff
}

func cosine_warm_restarts_step(cosine_warm_restarts_state sched, int step) cosine_warm_restarts_state {
    sched.current_step = step
    sched.current_lr = cosine_warm_restarts_compute(sched, step)
    return sched
}

func cyclic_max(float a, float b) float {
    if a > b {
        return a
    }
    return b
}

func cyclic_pi() float {
    return 3.14159265358979323846
}

func cyclic_pow_int(float base, int exponent) float {
    float result = 1.0
    int i = 0
    while i < exponent {
        result = result * base
        i = i + 1
    }
    result
}

func cyclic_cos(float x) float {
    float two_pi = 2.0 * cyclic_pi()
    float t = x
    while t > cyclic_pi() {
        t = t - two_pi
    }
    while t < 0.0 - cyclic_pi() {
        t = t + two_pi
    }
    float result = 1.0
    float term = 1.0
    float t_sq = t * t
    int n = 1
    while n < 12 {
        term = term * (0.0 - t_sq) / float((2 * n - 1) * (2 * n))
        result = result + term
        n = n + 1
    }
    result
}

