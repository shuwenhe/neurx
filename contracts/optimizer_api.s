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
    set_learning_rate(f64 lr) -> void
    get_weight_decay() -> f64
    set_weight_decay(f64 wd) -> void
    zero_grad() -> void
    add_grad(string param_name, grad: tensor) -> void
    step() -> void
    step_with_closure(closure: func() -> f64) -> void
    state_dict() -> map[string]tensor
    load_state_dict(map state[string]tensor) -> void
    add_param_group([]string param_names, f64 lr, f64 weight_decay) -> void
    get_param_groups() -> []map[string]f64
}
interface isgd_optimizer {
    get_momentum() -> f64
    set_momentum(f64 momentum) -> void
    get_nesterov() -> bool
    set_nesterov(bool nesterov) -> void
}
interface i_adam_optimizer {
    get_betas() -> [2]f64
    set_betas(f64 beta1, f64 beta2) -> void
    get_epsilon() -> f64
    set_epsilon(f64 eps) -> void
}
interface i_adam_w_optimizer {
    get_weight_decay() -> f64
    set_weight_decay(f64 wd) -> void
}
interface ilamb_optimizer {
    get_betas() -> [2]f64
    set_betas(f64 beta1, f64 beta2) -> void
}
interface ilr_scheduler {
    step(i64 epoch) -> void
    step_batch(i64 batch_idx) -> void
    get_last_lr() -> f64
    get_lr(i64 epoch) -> f64
    get_current_lr() -> f64
}
interface ilr_scheduler_types {
    step_lr(optimizer: IOptimizer, i64 step_size, f64 gamma) -> ILRScheduler
    exponential_lr(optimizer: IOptimizer, f64 gamma) -> ILRScheduler
    cosine_annealing_lr(optimizer: IOptimizer, i64 t_max, f64 eta_min) -> ILRScheduler
    warmup_lr(optimizer: IOptimizer, i64 warmup_epochs, f64 base_lr) -> ILRScheduler
}
interface i_optimizer_checkpoint {
    save_checkpoint(string path, optimizer: IOptimizer) -> void
    load_checkpoint(string path, optimizer: IOptimizer) -> void
    verify_checkpoint(string path) -> bool
}
interface i_optimizer_monitoring {
    get_grad_norm() -> f64
    get_param_norm() -> f64
    get_effective_lr() -> f64
    log_state() -> string
}
