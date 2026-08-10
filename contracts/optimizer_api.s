import "serialization_api"
enum optimizer_type {
    SGD
    adam
    adam_w
    LAMB
    rm_sprop
    adagrad
}

struct optimizer_state {
    step: i64
    learning_rate: f64
    weight_decay: f64
    momentum: map[string]tensor
    m: map[string]tensor
    v: map[string]tensor
}
interface i_optimizer {
    get_learning_rate() -> f64
    set_learning_rate(lr: f64) -> void
    get_weight_decay() -> f64
    set_weight_decay(wd: f64) -> void
    zero_grad() -> void
    add_grad(param_name: string, grad: tensor) -> void
    step() -> void
    step_with_closure(closure: func() -> f64) -> void
    state_dict() -> map[string]tensor
    load_state_dict(state: map[string]tensor) -> void
    add_param_group(param_names: []string, lr: f64, weight_decay: f64) -> void
    get_param_groups() -> []map[string]f64
}
interface isgd_optimizer {
    get_momentum() -> f64
    set_momentum(momentum: f64) -> void
    get_nesterov() -> bool
    set_nesterov(nesterov: bool) -> void
}
interface i_adam_optimizer {
    get_betas() -> [2]f64
    set_betas(beta1: f64, beta2: f64) -> void
    get_epsilon() -> f64
    set_epsilon(eps: f64) -> void
}
interface i_adam_w_optimizer {
    get_weight_decay() -> f64
    set_weight_decay(wd: f64) -> void
}
interface ilamb_optimizer {
    get_betas() -> [2]f64
    set_betas(beta1: f64, beta2: f64) -> void
}
interface ilr_scheduler {
    step(epoch: i64) -> void
    step_batch(batch_idx: i64) -> void
    get_last_lr() -> f64
    get_lr(epoch: i64) -> f64
    get_current_lr() -> f64
}
interface ilr_scheduler_types {
    step_lr(optimizer: IOptimizer, step_size: i64, gamma: f64) -> ILRScheduler
    exponential_lr(optimizer: IOptimizer, gamma: f64) -> ILRScheduler
    cosine_annealing_lr(optimizer: IOptimizer, t_max: i64, eta_min: f64) -> ILRScheduler
    warmup_lr(optimizer: IOptimizer, warmup_epochs: i64, base_lr: f64) -> ILRScheduler
}
interface i_optimizer_checkpoint {
    save_checkpoint(path: string, optimizer: IOptimizer) -> void
    load_checkpoint(path: string, optimizer: IOptimizer) -> void
    verify_checkpoint(path: string) -> bool
}
interface i_optimizer_monitoring {
    get_grad_norm() -> f64
    get_param_norm() -> f64
    get_effective_lr() -> f64
    log_state() -> string
}
