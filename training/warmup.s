package neurx.training.warmup
struct warmup_scheduler {
    float base_lr
    int warmup_steps
    string warmup_mode
    int current_step
    float current_lr
}

func new_warmup_scheduler(float base_lr, int warmup_steps, string warmup_mode) warmup_scheduler {
    warmup_scheduler {
        base_lr: base_lr,
        warmup_steps: warmup_steps,
        warmup_mode: warmup_mode,
        current_step: 0,
        current_lr: 0.0,
    }
}

func warmup_compute_lr(warmup_scheduler sched, int step) float {
    if step >= sched.warmup_steps {
        return sched.base_lr
    }
    if sched.warmup_steps <= 0 {
        return sched.base_lr
    }
    float progress = float(step) / float(sched.warmup_steps)
    if sched.warmup_mode == "linear" {
        return sched.base_lr * progress
    }
    if sched.warmup_mode == "constant" {
        return sched.base_lr
    }
    float cos_out = 0.5 * (1.0 - cos_approx(3.14159265358979323846 * progress))
    return sched.base_lr * cos_out
}

func warmup_step(warmup_scheduler sched, int step) warmup_scheduler {
    sched.current_step = step
    sched.current_lr = warmup_compute_lr(sched, step)
    return sched
}

func warmup_get_lr(warmup_scheduler sched) float {
    return sched.current_lr
}

func cos_approx(float x) float {
    float x2 = x * x
    float x4 = x2 * x2
    float x6 = x4 * x2
    float x8 = x6 * x2
    float x10 = x8 * x2
    return 1.0 - (x2 / 2.0) + (x4 / 24.0) - (x6 / 720.0) + (x8 / 40320.0) - (x10 / 3628800.0)
}

