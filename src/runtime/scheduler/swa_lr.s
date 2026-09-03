package neurx.scheduler.swa_lr
struct swa_lr_state {
    []float current_lrs
    []float swa_lrs
    int anneal_epochs
    string anneal_strategy
    int step_count
}

func new_swa_lr([]float initial_lrs, []float swa_lrs, int anneal_epochs, string anneal_strategy) swa_lr_state {
    swa_lr_state {
        current_lrs: clone_float_array(initial_lrs),
        swa_lrs: clone_float_array(swa_lrs),
        anneal_epochs: anneal_epochs,
        anneal_strategy: anneal_strategy,
        step_count: 0,
    }
}

func swa_linear_anneal(float t) float {
    return t
}

func swa_cosine_anneal(float t) float {
    return (1.0 - cos_approx(3.14159265358979323846 * t)) / 2.0
}

func swa_anneal_func(string strategy, float t) float {
    if strategy == "linear" {
        return swa_linear_anneal(t)
    }
    return swa_cosine_anneal(t)
}

func swa_clamp_01(float t) float {
    if t < 0.0 {
        return 0.0
    }
    if t > 1.0 {
        return 1.0
    }
    return t
}

func swa_get_initial_lr(float lr, float swa_lr, float alpha) float {
    if alpha == 1.0 {
        return swa_lr
    }
    return (lr - alpha * swa_lr) / (1.0 - alpha)
}

func swa_lr_step(swa_lr_state sched) swa_lr_state {
    sched.step_count = sched.step_count + 1
    int step = sched.step_count - 1
    if sched.anneal_epochs == 0 {
        if step < 1 {
            step = 1
        }
    }
    int denom_i = sched.anneal_epochs
    if denom_i < 1 {
        denom_i = 1
    }
    float denom = float(denom_i)
    float prev_t = swa_clamp_01(float(step - 1) / denom)
    float prev_alpha = swa_anneal_func(sched.anneal_strategy, prev_t)
    float t = swa_clamp_01(float(step) / denom)
    float alpha = swa_anneal_func(sched.anneal_strategy, t)
    int i = 0
    for i < len(sched.current_lrs) {
        float prev_initial = swa_get_initial_lr(sched.current_lrs[i], sched.swa_lrs[i], prev_alpha)
        sched.current_lrs[i] = sched.swa_lrs[i] * alpha + prev_initial * (1.0 - alpha)
        i = i + 1
    }
    return sched
}

func swa_lr_get_lr(swa_lr_state sched, int group_index) float {
    if group_index < 0 {
        return 0.0
    }
    if group_index >= len(sched.current_lrs) {
        return 0.0
    }
    return sched.current_lrs[group_index]
}

func clone_float_array([]float values) []float {
    []float out = make([]float, len(values))
    int i = 0
    for i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    return out
}

func cos_approx(float x) float {
    float x2 = x * x
    float x4 = x2 * x2
    float x6 = x4 * x2
    float x8 = x6 * x2
    float x10 = x8 * x2
    return 1.0 - (x2 / 2.0) + (x4 / 24.0) - (x6 / 720.0) + (x8 / 40320.0) - (x10 / 3628800.0)
}
