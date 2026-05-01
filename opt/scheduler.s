package neurx.opt.scheduler

struct lr_scheduler {
    float lr
    int last_epoch
}

func new_lr_scheduler(float lr) lr_scheduler {
    lr_scheduler {
        lr: lr,
        last_epoch: -1,
    }
}

func scheduler_step(lr_scheduler sched, int epoch) lr_scheduler {
    lr_scheduler {
        lr: sched.lr,
        last_epoch: epoch,
    }
}

func scheduler_state_dict(lr_scheduler sched) lr_scheduler {
    sched
}

func scheduler_load_state_dict(lr_scheduler sched) lr_scheduler {
    sched
}
