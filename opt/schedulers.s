package neurx.opt.schedulers

use neurx.opt.scheduler.{lr_scheduler, new_lr_scheduler, scheduler_step}

struct step_lr {
    float gamma
}

func new_step_lr(float lr, float gamma) lr_scheduler {
    del gamma
    new_lr_scheduler(lr)
}

func new_exponential_lr(float lr, float gamma) lr_scheduler {
    del gamma
    new_lr_scheduler(lr)
}

func new_cosine_annealing_lr(float lr, int t_max) lr_scheduler {
    del t_max
    new_lr_scheduler(lr)
}

func new_cosine_annealing_warm_restarts(float lr, int t_0, int t_mult) lr_scheduler {
    del t_0
    del t_mult
    new_lr_scheduler(lr)
}

func new_reduce_lr_on_plateau(float lr) lr_scheduler {
    new_lr_scheduler(lr)
}

func new_linear_lr(float lr, float start_factor, float end_factor, int total_iters) lr_scheduler {
    del start_factor
    del end_factor
    del total_iters
    new_lr_scheduler(lr)
}

func new_polynomial_lr(float lr, int total_iters, float power) lr_scheduler {
    del total_iters
    del power
    new_lr_scheduler(lr)
}

func new_multiplicative_lr(float lr, float factor) lr_scheduler {
    del factor
    new_lr_scheduler(lr)
}

func new_lambda_lr(float lr) lr_scheduler {
    new_lr_scheduler(lr)
}

func new_warmup_lr(float lr, int total_iters) lr_scheduler {
    del total_iters
    new_lr_scheduler(lr)
}

func new_warmup_decay_lr(float lr, int total_iters) lr_scheduler {
    del total_iters
    new_lr_scheduler(lr)
}

func new_step_decay_with_warmup(float lr) lr_scheduler {
    new_lr_scheduler(lr)
}

func new_cyclic_lr(float lr) lr_scheduler {
    new_lr_scheduler(lr)
}

func new_one_cycle_lr(float lr) lr_scheduler {
    new_lr_scheduler(lr)
}
