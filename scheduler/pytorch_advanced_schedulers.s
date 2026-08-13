package neurx.scheduler.pytorch_advanced_schedulers

struct lambda_lr_state {
    float base_lr
    float current_lr
    int current_step
    string lambda_mode
    float lambda_a
    float lambda_b
}

func new_lambda_lr(
    float base_lr,
    string lambda_mode,
    float lambda_a,
    float lambda_b
) lambda_lr_state {
    lambda_lr_state {
        base_lr: base_lr,
        current_lr: base_lr,
        current_step: 0,
        lambda_mode: lambda_mode,
        lambda_a: lambda_a,
        lambda_b: lambda_b,
    }
}

func lambda_lr_factor(lambda_lr_state sched, int step) float {
    if sched.lambda_mode == "linear" {
        return sched.lambda_a + sched.lambda_b * float(step)
    }
    if sched.lambda_mode == "exp" {
        return pow_int(sched.lambda_a, step)
    }
    if sched.lambda_mode == "inverse" {
        return 1.0 / (1.0 + sched.lambda_a * float(step))
    }
    return 1.0
}

func lambda_lr_step(lambda_lr_state sched, int step) lambda_lr_state {
    float factor = lambda_lr_factor(sched, step)
    sched.current_step = step
    sched.current_lr = sched.base_lr * factor
    return sched
}

struct multiplicative_lr_state {
    float base_lr
    float current_lr
    int current_step
    float gamma
}

func new_multiplicative_lr(float base_lr, float gamma) multiplicative_lr_state {
    multiplicative_lr_state {
        base_lr: base_lr,
        current_lr: base_lr,
        current_step: 0,
        gamma: gamma,
    }
}

func multiplicative_lr_step(multiplicative_lr_state sched, int step) multiplicative_lr_state {
    sched.current_step = step
    sched.current_lr = sched.base_lr * pow_int(sched.gamma, step)
    return sched
}

struct constant_lr_state {
    float base_lr
    float factor
    int total_iters
    int current_step
    float current_lr
}

func new_constant_lr(float base_lr, float factor, int total_iters) constant_lr_state {
    constant_lr_state {
        base_lr: base_lr,
        factor: factor,
        total_iters: total_iters,
        current_step: 0,
        current_lr: base_lr * factor,
    }
}

func constant_lr_step(constant_lr_state sched, int step) constant_lr_state {
    sched.current_step = step
    if step < sched.total_iters {
        sched.current_lr = sched.base_lr * sched.factor
    } else {
        sched.current_lr = sched.base_lr
    }
    return sched
}

struct linear_lr_state {
    float base_lr
    float start_factor
    float end_factor
    int total_iters
    int current_step
    float current_lr
}

func new_linear_lr(
    float base_lr,
    float start_factor,
    float end_factor,
    int total_iters
) linear_lr_state {
    linear_lr_state {
        base_lr: base_lr,
        start_factor: start_factor,
        end_factor: end_factor,
        total_iters: total_iters,
        current_step: 0,
        current_lr: base_lr * start_factor,
    }
}

func linear_lr_step(linear_lr_state sched, int step) linear_lr_state {
    sched.current_step = step
    if step >= sched.total_iters {
        sched.current_lr = sched.base_lr * sched.end_factor
        return sched
    }
    float progress = float(step) / float(sched.total_iters)
    float factor = sched.start_factor + progress * (sched.end_factor - sched.start_factor)
    sched.current_lr = sched.base_lr * factor
    return sched
}

struct sequential_lr_state {
    []float base_lrs
    []float current_lrs
    []int milestones
    int active_scheduler_index
    int current_step
}

func new_sequential_lr([]float base_lrs, []int milestones) sequential_lr_state {
    []float current_lrs = clone_float_array(base_lrs)
    sequential_lr_state {
        base_lrs: base_lrs,
        current_lrs: current_lrs,
        milestones: milestones,
        active_scheduler_index: 0,
        current_step: 0,
    }
}

func sequential_lr_step(sequential_lr_state sched, int step) sequential_lr_state {
    int idx = 0
    int i = 0
    while i < len(sched.milestones) {
        if step >= sched.milestones[i] {
            idx = i + 1
        }
        i = i + 1
    }
    if idx >= len(sched.current_lrs) {
        idx = len(sched.current_lrs) - 1
    }
    sched.active_scheduler_index = idx
    sched.current_step = step
    return sched
}

func sequential_lr_get_lr(sequential_lr_state sched) float {
    if len(sched.current_lrs) == 0 {
        return 0.0
    }
    int idx = sched.active_scheduler_index
    if idx < 0 {
        idx = 0
    }
    if idx >= len(sched.current_lrs) {
        idx = len(sched.current_lrs) - 1
    }
    return sched.current_lrs[idx]
}

struct chained_scheduler_state {
    []float multipliers
    float base_lr
    float current_lr
    int current_step
}

func new_chained_scheduler(float base_lr, []float multipliers) chained_scheduler_state {
    chained_scheduler_state {
        multipliers: multipliers,
        base_lr: base_lr,
        current_lr: base_lr,
        current_step: 0,
    }
}

func chained_scheduler_step(chained_scheduler_state sched, int step) chained_scheduler_state {
    sched.current_step = step
    float lr = sched.base_lr
    int i = 0
    while i < len(sched.multipliers) {
        lr = lr * sched.multipliers[i]
        i = i + 1
    }
    sched.current_lr = lr
    return sched
}

struct one_cycle_lr_state {
    float max_lr
    float min_lr
    float initial_lr
    int total_steps
    float pct_start
    string anneal_strategy
    bool three_phase
    int current_step
    float current_lr
}

func new_one_cycle_lr(
    float max_lr,
    float min_lr,
    int total_steps,
    float pct_start,
    string anneal_strategy,
    bool three_phase
) one_cycle_lr_state {
    float initial_lr = min_lr
    one_cycle_lr_state {
        max_lr: max_lr,
        min_lr: min_lr,
        initial_lr: initial_lr,
        total_steps: total_steps,
        pct_start: pct_start,
        anneal_strategy: anneal_strategy,
        three_phase: three_phase,
        current_step: 0,
        current_lr: initial_lr,
    }
}

func one_cycle_anneal(float start_lr, float end_lr, float pct, string strategy) float {
    if strategy == "linear" {
        return start_lr + pct * (end_lr - start_lr)
    }
    float cos_out = 0.5 * (1.0 - cos_approx(3.14159265358979323846 * pct))
    return start_lr + cos_out * (end_lr - start_lr)
}

func one_cycle_lr_step(one_cycle_lr_state sched, int step) one_cycle_lr_state {
    sched.current_step = step
    if step >= sched.total_steps {
        sched.current_lr = sched.min_lr
        return sched
    }
    int phase1_steps = int(float(sched.total_steps) * sched.pct_start)
    if phase1_steps < 1 {
        phase1_steps = 1
    }
    if !sched.three_phase {
        if step <= phase1_steps {
            float pct = float(step) / float(phase1_steps)
            sched.current_lr = one_cycle_anneal(sched.initial_lr, sched.max_lr, pct, sched.anneal_strategy)
        } else {
            int phase2_steps = sched.total_steps - phase1_steps
            if phase2_steps < 1 {
                phase2_steps = 1
            }
            float pct = float(step - phase1_steps) / float(phase2_steps)
            sched.current_lr = one_cycle_anneal(sched.max_lr, sched.min_lr, pct, sched.anneal_strategy)
        }
        return sched
    }
    int phase2_steps = phase1_steps
    int phase3_steps = sched.total_steps - phase1_steps - phase2_steps
    if phase3_steps < 1 {
        phase3_steps = 1
    }
    if step <= phase1_steps {
        float pct = float(step) / float(phase1_steps)
        sched.current_lr = one_cycle_anneal(sched.initial_lr, sched.max_lr, pct, sched.anneal_strategy)
    } else {
        if step <= phase1_steps + phase2_steps {
            float pct = float(step - phase1_steps) / float(phase2_steps)
            sched.current_lr = one_cycle_anneal(sched.max_lr, sched.initial_lr, pct, sched.anneal_strategy)
        } else {
            float pct = float(step - phase1_steps - phase2_steps) / float(phase3_steps)
            sched.current_lr = one_cycle_anneal(sched.initial_lr, sched.min_lr, pct, sched.anneal_strategy)
        }
    }
    return sched
}

func cos_approx(float x) float {
    float x2 = x * x
    float x4 = x2 * x2
    float x6 = x4 * x2
    float x8 = x6 * x2
    float x10 = x8 * x2
    return 1.0 - (x2 / 2.0) + (x4 / 24.0) - (x6 / 720.0) + (x8 / 40320.0) - (x10 / 3628800.0)
}

func pow_int(float base, int exponent) float {
    float result = 1.0
    int i = 0
    while i < exponent {
        result = result * base
        i = i + 1
    }
    return result
}

func clone_float_array([]float values) []float {
    []float out = []float{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    return out
}
