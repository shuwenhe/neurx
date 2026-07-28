// Optimizer API - Parameter update algorithms
//
// Supports: SGD, Adam, AdamW, LAMB, etc.
// Direct state_dict support for checkpoint/resume
//
// Optimizer → State → Checkpoint

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
    momentum: map[string]Tensor    // For SGD momentum
    m: map[string]Tensor           // First moment (Adam/AdamW)
    v: map[string]Tensor           // Second moment (Adam/AdamW)
}

interface IOptimizer {
    // === Configuration ===
    get_learning_rate() -> f64
    set_learning_rate(lr: f64) -> void
    
    get_weight_decay() -> f64
    set_weight_decay(wd: f64) -> void
    
    // === Gradient Management ===
    zero_grad() -> void
    add_grad(param_name: string, grad: Tensor) -> void
    
    // === Optimization Step ===
    step() -> void
    step_with_closure(closure: func() -> f64) -> void  // For line search
    
    // === State Management (Checkpoint/Resume) ===
    state_dict() -> map[string]Tensor
    load_state_dict(state: map[string]Tensor) -> void
    
    // === Parameter Groups ===
    add_param_group(param_names: []string, lr: f64, weight_decay: f64) -> void
    get_param_groups() -> []map[string]f64
}

interface ISGDOptimizer {
    // SGD-specific
    get_momentum() -> f64
    set_momentum(momentum: f64) -> void
    
    get_nesterov() -> bool
    set_nesterov(nesterov: bool) -> void
}

interface IAdamOptimizer {
    // Adam-specific
    get_betas() -> [2]f64  // [beta1, beta2]
    set_betas(beta1: f64, beta2: f64) -> void
    
    get_epsilon() -> f64
    set_epsilon(eps: f64) -> void
}

interface IAdamWOptimizer {
    // AdamW = Adam + decoupled weight decay
    // (standard L2 regularization, not Adam's weight decay)
    
    get_weight_decay() -> f64
    set_weight_decay(wd: f64) -> void
}

interface ILAMBOptimizer {
    // LAMB = Layer-wise Adaptive Moments Optimizer for Batch training
    // Enables large batch training
    
    get_betas() -> [2]f64
    set_betas(beta1: f64, beta2: f64) -> void
}

interface ILRScheduler {
    // Learning rate scheduling
    
    step(epoch: i64) -> void
    step_batch(batch_idx: i64) -> void
    
    get_last_lr() -> f64
    get_lr(epoch: i64) -> f64
    
    // Get current learning rate
    get_current_lr() -> f64
}

interface ILRSchedulerTypes {
    // Common schedulers
    
    // StepLR: decrease lr by factor every N epochs
    step_lr(optimizer: IOptimizer, step_size: i64, gamma: f64) -> ILRScheduler
    
    // ExponentialLR: lr = lr0 * gamma^epoch
    exponential_lr(optimizer: IOptimizer, gamma: f64) -> ILRScheduler
    
    // CosineAnnealingLR: cosine annealing
    cosine_annealing_lr(optimizer: IOptimizer, T_max: i64, eta_min: f64) -> ILRScheduler
    
    // WarmupLR: warmup then decay
    warmup_lr(optimizer: IOptimizer, warmup_epochs: i64, base_lr: f64) -> ILRScheduler
}

interface IOptimizerCheckpoint {
    // Checkpoint support (for resume)
    
    // Save optimizer state
    save_checkpoint(path: string, optimizer: IOptimizer) -> void
    
    // Load optimizer state
    load_checkpoint(path: string, optimizer: IOptimizer) -> void
    
    // Verify checkpoint validity (before resume)
    verify_checkpoint(path: string) -> bool
}

interface IOptimizerMonitoring {
    // Monitor optimization progress
    
    // Get gradient statistics
    get_grad_norm() -> f64
    get_param_norm() -> f64
    
    // Get effective learning rate
    get_effective_lr() -> f64
    
    // Log optimizer state
    log_state() -> string
}

// === MANDATORY STATE_DICT FORMAT ===
//
// state_dict() must return:
// {
//     "step": step_count,
//     "learning_rate": current_lr,
//     "param_0_m": momentum_tensor,    // if SGD
//     "param_0_v": velocity_tensor,    // if SGD
//     "param_1_m": ...
//     ...
//     "state": {...}  // optimizer-specific state
// }
//
// load_state_dict(dict) must restore EXACTLY:
// - step counter
// - learning rate
// - all momentum/velocity tensors
// - optimizer-specific state
//
// Constraint: Resume must pass Loss continuity test
// (Loss curve must not jump after checkpoint/resume)

// === IMPLEMENTATION PATTERN (Phase 1) ===
//
// AdamW:
// ```s
// func (opt *AdamW) step() {
//     opt.state.step += 1
//     
//     for param_name, param := range opt.params {
//         grad := param.grad()
//         if grad == nil { continue }
//         
//         // Get or create state
//         state := opt.state[param_name]
//         state.m = beta1 * state.m + (1-beta1) * grad
//         state.v = beta2 * state.v + (1-beta2) * (grad*grad)
//         
//         // Bias correction
//         m_hat := state.m / (1 - pow(beta1, opt.state.step))
//         v_hat := state.v / (1 - pow(beta2, opt.state.step))
//         
//         // Update (decoupled weight decay)
//         param -= lr * m_hat / (sqrt(v_hat) + eps)
//         param -= lr * weight_decay * param
//     }
// }
// ```
