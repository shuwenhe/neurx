package neurx.scheduler.lr_scheduler_moe_1t
use neurx.strings
use neurx.runtime.io.{io_println}
struct lr_schedule_config {
    string schedule_type
    float base_lr
    float min_lr
    int warmup_steps
    int total_steps
    int decay_steps
    float decay_rate
    int cycle_steps
}

struct lr_scheduler_state {
    lr_schedule_config config
    int current_step
    float current_lr
    float current_base_lr
    []float lr_history
    []int step_history
    int num_schedules
    float avg_lr
    float max_lr
    float min_lr_achieved
}

func lr_scheduler_new(
    float base_lr,
    int warmup_steps,
    int total_steps
) lr_scheduler_state {
    lr_schedule_config cfg = lr_schedule_config {
        schedule_type: "cosine",
        base_lr: base_lr,
        min_lr: base_lr / 10.0,
        warmup_steps: warmup_steps,
        total_steps: total_steps,
        decay_steps: total_steps,
        decay_rate: 0.1,
        cycle_steps: 0,
    }
    lr_scheduler_state state = lr_scheduler_state {
        config: cfg,
        current_step: 0,
        current_lr: 0.0,
        current_base_lr: base_lr,
        lr_history: make([]float, 0),
        step_history: make([]int, 0),
        num_schedules: 0,
        avg_lr: 0.0,
        max_lr: 0.0,
        min_lr_achieved: base_lr,
    }
    state
}

func compute_cosine_annealing_lr(
    lr_scheduler_state state
) float {
    int step = state.current_step
    float base_lr = state.current_base_lr
    int warmup_steps = state.config.warmup_steps
    int total_steps = state.config.total_steps
    float min_lr = state.config.min_lr
    float lr = 0.0
    if step < warmup_steps {
        lr = base_lr * float(step) / float(warmup_steps)
    } else {
        float progress = float(step - warmup_steps) / float(total_steps - warmup_steps)
        if progress > 1.0 {
            progress = 1.0
        }
        float cos_val = cos(3.14159 * progress)
        lr = min_lr + (base_lr - min_lr) * 0.5 * (1.0 + cos_val)
    }
    if lr < min_lr {
        lr = min_lr
    }
    if lr > base_lr {
        lr = base_lr
    }
    state.current_lr = lr
    lr
}

func compute_linear_decay_lr(
    lr_scheduler_state state
) float {
    int step = state.current_step
    float base_lr = state.current_base_lr
    int warmup_steps = state.config.warmup_steps
    int total_steps = state.config.total_steps
    float min_lr = state.config.min_lr
    float lr = 0.0
    if step < warmup_steps {
        lr = base_lr * float(step) / float(warmup_steps)
    } else {
        float progress = float(step - warmup_steps) / float(total_steps - warmup_steps)
        if progress > 1.0 {
            progress = 1.0
        }
        lr = base_lr - (base_lr - min_lr) * progress
    }
    if lr < min_lr {
        lr = min_lr
    }
    state.current_lr = lr
    lr
}

func compute_exponential_decay_lr(
    lr_scheduler_state state
) float {
    int step = state.current_step
    float base_lr = state.current_base_lr
    int warmup_steps = state.config.warmup_steps
    int total_steps = state.config.total_steps
    float decay_rate = state.config.decay_rate
    float min_lr = state.config.min_lr
    float lr = 0.0
    if step < warmup_steps {
        lr = base_lr * float(step) / float(warmup_steps)
    } else {
        float exponent = float(step - warmup_steps) / float(total_steps - warmup_steps)
        lr = base_lr * pow(decay_rate, exponent)
    }
    if lr < min_lr {
        lr = min_lr
    }
    state.current_lr = lr
    lr
}

func compute_one_cycle_lr(
    lr_scheduler_state state
) float {
    int step = state.current_step
    float base_lr = state.current_base_lr
    float max_lr = base_lr * 10.0
    float min_lr = state.config.min_lr
    int total_steps = state.config.total_steps
    float lr = 0.0
    int step1 = total_steps / 30
    int step2 = step1 * 24 / 25
    if step < step1 {
        float progress = float(step) / float(step1)
        lr = min_lr + (max_lr - min_lr) * progress
    } else if step < step1 + step2 {
        float progress = float(step - step1) / float(step2)
        lr = max_lr - (max_lr - min_lr) * progress
    } else {
        lr = min_lr
    }
    state.current_lr = lr
    lr
}

func compute_step_decay_lr(
    lr_scheduler_state state,
    int step_size,
    float gamma
) float {
    int step = state.current_step
    float base_lr = state.current_base_lr
    int warmup_steps = state.config.warmup_steps
    float lr = 0.0
    if step < warmup_steps {
        lr = base_lr * float(step) / float(warmup_steps)
    } else {
        int decay_count = (step - warmup_steps) / step_size
        lr = base_lr * pow(gamma, float(decay_count))
    }
    state.current_lr = lr
    lr
}

func compute_lr(
    lr_scheduler_state state
) float {
    float lr = 0.0
    if state.config.schedule_type == "cosine" {
        lr = compute_cosine_annealing_lr(state)
    } else if state.config.schedule_type == "linear" {
        lr = compute_linear_decay_lr(state)
    } else if state.config.schedule_type == "exponential" {
        lr = compute_exponential_decay_lr(state)
    } else if state.config.schedule_type == "constant" {
        lr = state.current_base_lr
    } else {
        lr = compute_cosine_annealing_lr(state)
    }
    state.num_schedules = state.num_schedules + 1
    state.avg_lr = (state.avg_lr * float(state.num_schedules - 1) + lr) / float(state.num_schedules)
    if lr > state.max_lr {
        state.max_lr = lr
    }
    if lr < state.min_lr_achieved {
        state.min_lr_achieved = lr
    }
    lr
}

func step(
    lr_scheduler_state state
) float {
    state.current_step = state.current_step + 1
    float new_lr = compute_lr(state)
    new_lr
}

func get_warmup_lr(
    lr_scheduler_state state,
    int warmup_step
) float {
    float base_lr = state.current_base_lr
    int warmup_steps = state.config.warmup_steps
    if warmup_step >= warmup_steps {
        return base_lr
    }
    float warmup_lr = base_lr * float(warmup_step) / float(warmup_steps)
    warmup_lr
}

func cos(float x) float {
    if x < 0.0 {
        x = -x
    }
    float pi = 3.14159
    float result = 1.0
    float term = 1.0
    int n = 1
    while n < 10 {
        term = term * (-x * x) / float(2 * n * (2 * n - 1))
        result = result + term
        n = n + 1
    }
    result
}

func pow(float base, float exponent) float {
    if exponent == 0.0 {
        return 1.0
    }
    if base == 0.0 {
        return 0.0
    }
    if exponent == 1.0 {
        return base
    }
    float log_base = 1.0
    float result = exp(exponent * log_base)
    result
}

func exp(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i < 20 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    result
}

func float(int x) float {
    0.0 + x
}
