package neurx.scheduler.reduce_on_plateau
struct reduce_lr_on_plateau_state {
    float lr
    string mode
    float factor
    int patience
    float threshold
    string threshold_mode
    int cooldown
    float min_lr
    float eps
    float best
    int num_bad_epochs
    int cooldown_counter
    int last_epoch
}

func new_reduce_lr_on_plateau(
    float lr,
    string mode,
    float factor,
    int patience,
    float threshold,
    string threshold_mode,
    int cooldown,
    float min_lr,
    float eps
) reduce_lr_on_plateau_state {
    float initial_best = plateau_worst_value(mode)
    reduce_lr_on_plateau_state {
        lr: lr,
        mode: mode,
        factor: factor,
        patience: patience,
        threshold: threshold,
        threshold_mode: threshold_mode,
        cooldown: cooldown,
        min_lr: min_lr,
        eps: eps,
        best: initial_best,
        num_bad_epochs: 0,
        cooldown_counter: 0,
        last_epoch: 0,
    }
}

func plateau_worst_value(string mode) float {
    if mode == "min" {
        return 1000000000.0
    }
    return -1000000000.0
}

func is_better(reduce_lr_on_plateau_state sched, float current, float best) bool {
    if sched.mode == "min" {
        if sched.threshold_mode == "rel" {
            float rel_epsilon = 1.0 - sched.threshold
            return current < best * rel_epsilon
        }
        return current < best - sched.threshold
    }
    if sched.threshold_mode == "rel" {
        float rel_epsilon = 1.0 + sched.threshold
        return current > best * rel_epsilon
    }
    return current > best + sched.threshold
}

func reduce_lr_on_plateau_step(reduce_lr_on_plateau_state sched, float metric) reduce_lr_on_plateau_state {
    sched.last_epoch = sched.last_epoch + 1
    if is_better(sched, metric, sched.best) {
        sched.best = metric
        sched.num_bad_epochs = 0
    } else {
        sched.num_bad_epochs = sched.num_bad_epochs + 1
    }
    if sched.cooldown_counter > 0 {
        sched.cooldown_counter = sched.cooldown_counter - 1
        sched.num_bad_epochs = 0
    }
    if sched.num_bad_epochs > sched.patience {
        float old_lr = sched.lr
        float new_lr = plateau_max(sched.lr * sched.factor, sched.min_lr)
        if old_lr - new_lr > sched.eps {
            sched.lr = new_lr
        }
        sched.cooldown_counter = sched.cooldown
        sched.num_bad_epochs = 0
    }
    return sched
}

func reduce_lr_on_plateau_get_lr(reduce_lr_on_plateau_state sched) float {
    return sched.lr
}

func plateau_max(float a, float b) float {
    if a > b {
        return a
    }
    return b
}
