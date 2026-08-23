package neurx.scheduler.training_scheduler
use neurx.scheduler.schedulers

struct lr_scheduler {
    float lr
    float base_lr
    float min_lr
    int   warmup_steps
    int   max_steps
    int   last_epoch
    string kind
}

func new_lr_scheduler(float lr) lr_scheduler {
    lr_scheduler {
        lr:           lr,
        base_lr:      lr,
        min_lr:       0.0,
        warmup_steps: 0,
        max_steps:    0,
        last_epoch:   -1,
        kind:         "constant",
    }
}

func new_named_lr_scheduler(float base_lr, float min_lr, int warmup_steps, int max_steps, string kind) lr_scheduler {
    lr_scheduler {
        lr:           base_lr,
        base_lr:      base_lr,
        min_lr:       min_lr,
        warmup_steps: warmup_steps,
        max_steps:    max_steps,
        last_epoch:   -1,
        kind:         kind,
    }
}

func scheduler_step(lr_scheduler sched, int epoch) lr_scheduler {
    float new_lr = sched.lr
    if sched.kind == "cosine" {
        new_lr = cosine_scheduler_compute_lr(sched.base_lr, sched.min_lr, sched.warmup_steps, sched.max_steps, epoch)
    } else if sched.kind == "linear" {
        new_lr = linear_scheduler_compute_lr(sched.base_lr, sched.min_lr, sched.warmup_steps, sched.max_steps, epoch)
    }
    lr_scheduler {
        lr:           new_lr,
        base_lr:      sched.base_lr,
        min_lr:       sched.min_lr,
        warmup_steps: sched.warmup_steps,
        max_steps:    sched.max_steps,
        last_epoch:   epoch,
        kind:         sched.kind,
    }
}

func scheduler_current_lr(lr_scheduler sched) float {
    sched.lr
}

func scheduler_state_dict(lr_scheduler sched) lr_scheduler {
    sched
}

func scheduler_load_state_dict(lr_scheduler sched) lr_scheduler {
    sched
}
