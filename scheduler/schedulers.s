package neurx.scheduler.schedulers





func sched_cos_approx(float x) float {
    float x2 = x * x
    float x4 = x2 * x2
    float x6 = x4 * x2
    float x8 = x6 * x2
    float x10 = x8 * x2
    1.0 - (x2 / 2.0) + (x4 / 24.0) - (x6 / 720.0) + (x8 / 40320.0) - (x10 / 3628800.0)
}

func sched_clamp(float v, float lo, float hi) float {
    if v < lo {
        return lo
    }
    if v > hi {
        return hi
    }
    v
}



struct cosine_scheduler_state {
    float base_lr
    float min_lr
    int   warmup_steps
    int   max_steps
    int   current_step
    float current_lr
}

func new_cosine_scheduler(float base_lr, float min_lr, int warmup_steps, int max_steps) cosine_scheduler_state {
    cosine_scheduler_state {
        base_lr:      base_lr,
        min_lr:       min_lr,
        warmup_steps: warmup_steps,
        max_steps:    max_steps,
        current_step: 0,
        current_lr:   base_lr,
    }
}

func cosine_scheduler_compute_lr(float base_lr, float min_lr, int warmup_steps, int max_steps, int step) float {
    if max_steps <= 0 {
        return base_lr
    }
    if step <= 0 {
        if warmup_steps > 0 {
            return 0.0
        }
        return base_lr
    }
    if warmup_steps > 0 && step < warmup_steps {
        return base_lr * float(step) / float(warmup_steps)
    }
    if step >= max_steps {
        return min_lr
    }
    int decay_steps = max_steps - warmup_steps
    if decay_steps <= 0 {
        return min_lr
    }
    int pos = step - warmup_steps
    float progress = float(pos) / float(decay_steps)
    float pi = 3.14159265358979
    float cos_val = sched_cos_approx(pi * progress)
    float lr = min_lr + 0.5 * (base_lr - min_lr) * (1.0 + cos_val)
    sched_clamp(lr, min_lr, base_lr)
}

func cosine_scheduler_step(cosine_scheduler_state sched, int step) cosine_scheduler_state {
    float lr = cosine_scheduler_compute_lr(sched.base_lr, sched.min_lr, sched.warmup_steps, sched.max_steps, step)
    cosine_scheduler_state {
        base_lr:      sched.base_lr,
        min_lr:       sched.min_lr,
        warmup_steps: sched.warmup_steps,
        max_steps:    sched.max_steps,
        current_step: step,
        current_lr:   lr,
    }
}

func cosine_scheduler_lr(cosine_scheduler_state sched) float {
    sched.current_lr
}



struct linear_scheduler_state {
    float base_lr
    float min_lr
    int   warmup_steps
    int   max_steps
    int   current_step
    float current_lr
}

func new_linear_scheduler(float base_lr, float min_lr, int warmup_steps, int max_steps) linear_scheduler_state {
    linear_scheduler_state {
        base_lr:      base_lr,
        min_lr:       min_lr,
        warmup_steps: warmup_steps,
        max_steps:    max_steps,
        current_step: 0,
        current_lr:   base_lr,
    }
}

func linear_scheduler_compute_lr(float base_lr, float min_lr, int warmup_steps, int max_steps, int step) float {
    if max_steps <= 0 {
        return base_lr
    }
    if step <= 0 {
        if warmup_steps > 0 {
            return 0.0
        }
        return base_lr
    }
    if warmup_steps > 0 && step < warmup_steps {
        return base_lr * float(step) / float(warmup_steps)
    }
    if step >= max_steps {
        return min_lr
    }
    int decay_steps = max_steps - warmup_steps
    if decay_steps <= 0 {
        return min_lr
    }
    int pos = step - warmup_steps
    float progress = float(pos) / float(decay_steps)
    float lr = base_lr - progress * (base_lr - min_lr)
    sched_clamp(lr, min_lr, base_lr)
}

func linear_scheduler_step(linear_scheduler_state sched, int step) linear_scheduler_state {
    float lr = linear_scheduler_compute_lr(sched.base_lr, sched.min_lr, sched.warmup_steps, sched.max_steps, step)
    linear_scheduler_state {
        base_lr:      sched.base_lr,
        min_lr:       sched.min_lr,
        warmup_steps: sched.warmup_steps,
        max_steps:    sched.max_steps,
        current_step: step,
        current_lr:   lr,
    }
}

func linear_scheduler_lr(linear_scheduler_state sched) float {
    sched.current_lr
}



struct step_lr_state {
    float base_lr
    float gamma
    int   step_size
    int   current_step
    float current_lr
}

func new_step_lr(float base_lr, float gamma, int step_size) step_lr_state {
    step_lr_state {
        base_lr:      base_lr,
        gamma:        gamma,
        step_size:    step_size,
        current_step: 0,
        current_lr:   base_lr,
    }
}

func step_lr_compute(float base_lr, float gamma, int step_size, int step) float {
    if step_size <= 0 {
        return base_lr
    }
    int n_decays = step / step_size
    float lr = base_lr
    int i = 0
    while i < n_decays {
        lr = lr * gamma
        i = i + 1
    }
    if lr < 0.0 {
        return 0.0
    }
    lr
}

func step_lr_step(step_lr_state sched, int step) step_lr_state {
    float lr = step_lr_compute(sched.base_lr, sched.gamma, sched.step_size, step)
    step_lr_state {
        base_lr:      sched.base_lr,
        gamma:        sched.gamma,
        step_size:    sched.step_size,
        current_step: step,
        current_lr:   lr,
    }
}

func step_lr_lr(step_lr_state sched) float {
    sched.current_lr
}



func constant_scheduler_step(float lr, int step) float {
    lr
}
