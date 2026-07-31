import "serialization_api"

enum OptimizerType {
    SGD
    Adam
    AdamW
    LAMB
    RMSprop
    Adagrad
}

struct OptimizerState {
    step: i64
    learning_rate: f64
    weight_decay: f64
    momentum: map[string]Tensor
    m: map[string]Tensor
    v: map[string]Tensor
}

interface IOptimizer {

    get_learning_rate() -> f64
    set_learning_rate(lr: f64) -> void

    get_weight_decay() -> f64
    set_weight_decay(wd: f64) -> void

    zero_grad() -> void
    add_grad(param_name: string, grad: Tensor) -> void

    step() -> void
    step_with_closure(closure: func() -> f64) -> void

    state_dict() -> map[string]Tensor
    load_state_dict(state: map[string]Tensor) -> void

    add_param_group(param_names: []string, lr: f64, weight_decay: f64) -> void
    get_param_groups() -> []map[string]f64
}

interface ISGDOptimizer {

    get_momentum() -> f64
    set_momentum(momentum: f64) -> void

    get_nesterov() -> bool
    set_nesterov(nesterov: bool) -> void
}

interface IAdamOptimizer {

    get_betas() -> [2]f64
    set_betas(beta1: f64, beta2: f64) -> void

    get_epsilon() -> f64
    set_epsilon(eps: f64) -> void
}

interface IAdamWOptimizer {

    get_weight_decay() -> f64
    set_weight_decay(wd: f64) -> void
}

interface ILAMBOptimizer {

    get_betas() -> [2]f64
    set_betas(beta1: f64, beta2: f64) -> void
}

interface ILRScheduler {

    step(epoch: i64) -> void
    step_batch(batch_idx: i64) -> void

    get_last_lr() -> f64
    get_lr(epoch: i64) -> f64

    get_current_lr() -> f64
}

interface ILRSchedulerTypes {

    step_lr(optimizer: IOptimizer, step_size: i64, gamma: f64) -> ILRScheduler

    exponential_lr(optimizer: IOptimizer, gamma: f64) -> ILRScheduler

    cosine_annealing_lr(optimizer: IOptimizer, T_max: i64, eta_min: f64) -> ILRScheduler

    warmup_lr(optimizer: IOptimizer, warmup_epochs: i64, base_lr: f64) -> ILRScheduler
}

interface IOptimizerCheckpoint {

    save_checkpoint(path: string, optimizer: IOptimizer) -> void

    load_checkpoint(path: string, optimizer: IOptimizer) -> void

    verify_checkpoint(path: string) -> bool
}

interface IOptimizerMonitoring {

    get_grad_norm() -> f64
    get_param_norm() -> f64

    get_effective_lr() -> f64

    log_state() -> string
}
