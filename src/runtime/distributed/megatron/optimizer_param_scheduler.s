package neurx.distributed.megatron.param_scheduler
struct optimizer_param_scheduler {
    float init_lr
    float max_lr
    float min_lr
    int lr_warmup_steps
    int lr_decay_steps
    string lr_decay_style
    int wsd_decay_steps
    string lr_wsd_decay_style
    float start_wd
    float end_wd
    int wd_incr_steps
    string wd_incr_style
    int num_steps
}
func new_optimizer_param_scheduler(
    float init_lr,
    float max_lr,
    float min_lr,
    int lr_warmup_steps,
    int lr_decay_steps,
    string lr_decay_style,
    int wsd_decay_steps,
    string lr_wsd_decay_style,
    float start_wd,
    float end_wd,
    int wd_incr_steps,
    string wd_incr_style
) optimizer_param_scheduler {
    optimizer_param_scheduler {
        init_lr: init_lr,
        max_lr: max_lr,
        min_lr: min_lr,
        lr_warmup_steps: lr_warmup_steps,
        lr_decay_steps: lr_decay_steps,
        lr_decay_style: lr_decay_style,
        wsd_decay_steps: wsd_decay_steps,
        lr_wsd_decay_style: lr_wsd_decay_style,
        start_wd: start_wd,
        end_wd: end_wd,
        wd_incr_steps: wd_incr_steps,
        wd_incr_style: wd_incr_style,
        num_steps: 0,
    }
}
func get_wd(optimizer_param_scheduler sched) float {
    if sched.num_steps > sched.wd_incr_steps {
        return sched.end_wd
    }
    if sched.wd_incr_style == "constant" {
        return sched.end_wd
    }
    float incr_ratio = float(sched.num_steps) / float(sched.wd_incr_steps)
    float delta_wd = sched.end_wd - sched.start_wd
    float coeff = 0.0
    if sched.wd_incr_style == "linear" {
        coeff = incr_ratio
    } else {
        if sched.wd_incr_style == "cosine" {
            coeff = 0.5 * (cos_approx(pi_value() * (1.0 - incr_ratio)) + 1.0)
        }
    }
    return sched.start_wd + coeff * delta_wd
}
func get_lr(optimizer_param_scheduler sched) float {
    if sched.lr_warmup_steps > 0 {
        if sched.num_steps <= sched.lr_warmup_steps {
            float warmup_ratio = float(sched.num_steps) / float(sched.lr_warmup_steps)
            return sched.init_lr + (sched.max_lr - sched.init_lr) * warmup_ratio
        }
    }
    if sched.lr_decay_style == "constant" {
        return sched.max_lr
    }
    if sched.num_steps > sched.lr_decay_steps {
        return sched.min_lr
    }
    if sched.lr_decay_style == "inverse-square-root" {
        int warmup_steps = max_int(sched.lr_warmup_steps, 1)
        int num_steps = max_int(sched.num_steps, 1)
        float lr = sched.max_lr * sqrt_approx(float(warmup_steps)) / sqrt_approx(float(num_steps))
        return max_float(sched.min_lr, lr)
    }
    int num_steps_ = sched.num_steps - sched.lr_warmup_steps
    int decay_steps_ = sched.lr_decay_steps - sched.lr_warmup_steps
    float decay_ratio = float(num_steps_) / float(decay_steps_)
    float delta_lr = sched.max_lr - sched.min_lr
    float coeff = 0.0
    if sched.lr_decay_style == "linear" {
        coeff = 1.0 - decay_ratio
    } else {
        if sched.lr_decay_style == "cosine" {
            coeff = 0.5 * (cos_approx(pi_value() * decay_ratio) + 1.0)
        } else {
            if sched.lr_decay_style == "WSD" {
                coeff = compute_wsd_coeff(sched)
            }
        }
    }
    return sched.min_lr + coeff * delta_lr
}
func compute_wsd_coeff(optimizer_param_scheduler sched) float {
    int wsd_anneal_start = sched.lr_decay_steps - sched.wsd_decay_steps
    if sched.num_steps <= wsd_anneal_start {
        return 1.0
    }
    int wsd_steps = sched.num_steps - wsd_anneal_start
    float wsd_decay_ratio = float(wsd_steps) / float(sched.wsd_decay_steps)
    if sched.lr_wsd_decay_style == "linear" {
        return 1.0 - wsd_decay_ratio
    }
    if sched.lr_wsd_decay_style == "cosine" {
        return 0.5 * (cos_approx(pi_value() * wsd_decay_ratio) + 1.0)
    }
    if sched.lr_wsd_decay_style == "exponential" {
        return 2.0 * pow_approx(0.5, wsd_decay_ratio) - 1.0
    }
    if sched.lr_wsd_decay_style == "minus_sqrt" {
        return 1.0 - sqrt_approx(wsd_decay_ratio)
    }
    return 1.0
}
func step_scheduler(optimizer_param_scheduler sched, int increment) optimizer_param_scheduler {
    sched.num_steps = sched.num_steps + increment
    return sched
}
func pi_value() float {
    return 3.14159265358979323846
}
func max_int(int a, int b) int {
    if a > b {
        return a
    }
    return b
}
func max_float(float a, float b) float {
    if a > b {
        return a
    }
    return b
}
func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x / 2.0
    if guess <= 0.0 {
        guess = 1.0
    }
    for int i = 0; i < 20; i = i + 1 {
        guess = (guess + x / guess) / 2.0
    }
    return guess
}
func cos_approx(float x) float {
    float two_pi = 2.0 * pi_value()
    float t = x
    for t > pi_value() {
        t = t - two_pi
    }
    for t < 0.0 - pi_value() {
        t = t + two_pi
    }
    float result = 1.0
    float term = 1.0
    float t_sq = t * t
    for int n = 1; n < 12; n = n + 1 {
        term = term * (0.0 - t_sq) / float((2 * n - 1) * (2 * n))
        result = result + term
    }
    return result
}
func pow_approx(float base, float exponent) float {
    if base <= 0.0 {
        return 0.0
    }
    return exp_approx(exponent * ln_approx(base))
}
func exp_approx(float x) float {
    if x > 20.0 {
        x = 20.0
    }
    if x < -20.0 {
        x = -20.0
    }
    float result = 1.0
    float term = 1.0
    for int i = 1; i < 25; i = i + 1 {
        term = term * x / float(i)
        result = result + term
    }
    return result
}
func ln_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = (x - 1.0) / (x + 1.0)
    float y_sq = y * y
    float result = 0.0
    float term = y
    for int i = 0; i < 20; i = i + 1 {
        result = result + term / float(2 * i + 1)
        term = term * y_sq
    }
    return 2.0 * result
}
