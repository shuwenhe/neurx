package neurx.scheduler.scheduler_base

struct scheduler_base {
    float base_lr
    []float last_lr
    int last_epoch
    bool verbose
}

func new_scheduler_base(float base_lr, int last_epoch, bool verbose) scheduler_base {
    []float lrs = []float{cap: 1}
    lrs[0] = base_lr
    scheduler_base {
        base_lr: base_lr,
        last_lr: lrs,
        last_epoch: last_epoch,
        verbose: verbose,
    }
}

func scheduler_get_last_lr(scheduler_base sched) []float {
    return clone_lr_array(sched.last_lr)
}

func scheduler_set_last_lr(scheduler_base sched, []float lrs) scheduler_base {
    sched.last_lr = clone_lr_array(lrs)
    return sched
}

func scheduler_step_epoch(scheduler_base sched) scheduler_base {
    sched.last_epoch = sched.last_epoch + 1
    return sched
}

func scheduler_print_if_verbose(scheduler_base sched, string msg) {
    if sched.verbose {
        println(msg)
    }
}

func clone_lr_array([]float values) []float {
    []float out = []float{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    return out
}

func println(string msg) {
    msg
}

