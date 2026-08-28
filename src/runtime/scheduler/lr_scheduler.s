package neurx.scheduler.lr_scheduler
struct lr_schedule_config {
    float base_lr
    float min_lr
    int warmup_steps
    int total_steps
    string schedule_type
}

struct lr_scheduler {
    lr_schedule_config config
    int current_step
    float current_lr
}

func new_lr_scheduler(lr_schedule_config cfg) lr_scheduler {
    lr_scheduler {
        config: cfg,
        current_step: 0,
        current_lr: cfg.base_lr,
    }
}

func compute_warmup_lr(float base_lr, int warmup_steps, int current_step) float {
    if current_step >= warmup_steps {
        return base_lr
    }
    if warmup_steps == 0 {
        return base_lr
    }
    return base_lr * (float(current_step) / float(warmup_steps))
}

func compute_cosine_lr(
    float base_lr,
    float min_lr,
    int warmup_steps,
    int total_steps,
    int current_step
) float {
    if current_step < warmup_steps {
        return compute_warmup_lr(base_lr, warmup_steps, current_step)
    }
    steps_after_warmup := float(current_step - warmup_steps)
    total_decay_steps := float(total_steps - warmup_steps)
    if total_decay_steps <= 0.0 {
        return base_lr
    }
    progress := steps_after_warmup / total_decay_steps
    if progress >= 1.0 {
        return min_lr
    }
    cos_val := cosine_approx(3.14159 * progress)
    lr := min_lr + 0.5 * (base_lr - min_lr) * (1.0 + cos_val)
    return max_approx(lr, min_lr)
}

func compute_linear_lr(
    float base_lr,
    float min_lr,
    int warmup_steps,
    int total_steps,
    int current_step
) float {
    if current_step < warmup_steps {
        return compute_warmup_lr(base_lr, warmup_steps, current_step)
    }
    steps_after_warmup := float(current_step - warmup_steps)
    total_decay_steps := float(total_steps - warmup_steps)
    if total_decay_steps <= 0.0 {
        return base_lr
    }
    progress := steps_after_warmup / total_decay_steps
    if progress >= 1.0 {
        return min_lr
    }
    lr := base_lr + (min_lr - base_lr) * progress
    return max_approx(lr, min_lr)
}

func compute_constant_lr(float base_lr, int warmup_steps, int current_step) float {
    if current_step < warmup_steps {
        return compute_warmup_lr(base_lr, warmup_steps, current_step)
    }
    return base_lr
}

func lr_scheduler_step(lr_scheduler sched) lr_scheduler {
    current_step := sched.current_step
    cfg := sched.config
    new_lr := cfg.base_lr
    if cfg.schedule_type == "cosine" {
        new_lr = compute_cosine_lr(
            cfg.base_lr,
            cfg.min_lr,
            cfg.warmup_steps,
            cfg.total_steps,
            current_step
        )
    } else if cfg.schedule_type == "linear" {
        new_lr = compute_linear_lr(
            cfg.base_lr,
            cfg.min_lr,
            cfg.warmup_steps,
            cfg.total_steps,
            current_step
        )
    } else if cfg.schedule_type == "constant" {
        new_lr = compute_constant_lr(cfg.base_lr, cfg.warmup_steps, current_step)
    }
    lr_scheduler {
        config: cfg,
        current_step: current_step + 1,
        current_lr: new_lr,
    }
}

func get_current_lr(lr_scheduler sched) float {
    return sched.current_lr
}

func get_current_step(lr_scheduler sched) int {
    return sched.current_step
}

func new_llm_scheduler(
    float base_lr,
    int total_steps
) lr_scheduler {
    warmup_steps := total_steps / 40
    min_lr := base_lr / 10.0
    cfg := lr_schedule_config {
        base_lr: base_lr,
        min_lr: min_lr,
        warmup_steps: warmup_steps,
        total_steps: total_steps,
        schedule_type: "cosine",
    }
    return new_lr_scheduler(cfg)
}

func new_finetune_scheduler(
    float base_lr,
    int total_steps
) lr_scheduler {
    warmup_steps := total_steps / 10
    cfg := lr_schedule_config {
        base_lr: base_lr,
        min_lr: 0.0,
        warmup_steps: warmup_steps,
        total_steps: total_steps,
        schedule_type: "cosine",
    }
    return new_lr_scheduler(cfg)
}

func cosine_approx(float x) float {
    x_reduced := x
    for x_reduced > 3.14159 {
        x_reduced = x_reduced - 6.28318
    }
    for x_reduced < -3.14159 {
        x_reduced = x_reduced + 6.28318
    }
    x2 := x_reduced * x_reduced
    result := 1.0
            - x2 / 2.0
            + (x2 * x2) / 24.0
            - (x2 * x2 * x2) / 720.0
            + (x2 * x2 * x2 * x2) / 40320.0
    return result
}

func max_approx(float a, float b) float {
    if a > b {
        return a
    }
    return b
}

func abs_approx(float x) float {
    if x < 0.0 {
        return -x
    }
    return x
}
