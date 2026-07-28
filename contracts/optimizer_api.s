// NeurX Optimizer API Interface
// Phase -1: Architecture Contracts
// Purpose: Parameter update algorithms (SGD, AdamW, etc.)

package contracts

// OptimizerType enum
type OptimType interface {
    name() string
}

type SGD struct {}
type Adam struct {}
type AdamW struct {}
type LAMB struct {}

func (SGD) name() string { return "sgd" }
func (Adam) name() string { return "adam" }
func (AdamW) name() string { return "adamw" }
func (LAMB) name() string { return "lamb" }

// OptimizerState - Maintains optimizer state (momentum, etc.)
struct OptimizerState {
    step: int
    momentum: map[string]Tensor    // For SGD
    m: map[string]Tensor           // First moment for Adam
    v: map[string]Tensor           // Second moment for Adam
    exp_avg_sq: map[string]Tensor
}

// Optimizer Interface - Parameter update rules
interface Optimizer {
    // Configuration
    func get_learning_rate() -> float
    func set_learning_rate(lr: float)
    func get_weight_decay() -> float
    func set_weight_decay(wd: float)
    
    // Optimization step
    func zero_grad()
    func step()                                    // Update parameters given gradients
    func step_with_closure(closure: func() -> Tensor)  // For line search
    
    // State management
    func state_dict() -> map[string]Tensor       // For checkpoint
    func load_state_dict(state: map[string]Tensor)
    
    // Parameter registration
    func add_param_group(params: []Tensor, lr: float, weight_decay: float)
    
    // Gradient accumulation
    func accumulate_gradients(grads: map[string]Tensor)
}

// LRScheduler Interface - Learning rate scheduling
interface LRScheduler {
    func step(epoch: int)
    func get_last_lr() -> float
    func get_lr(epoch: int) -> float
}

// Phase -1 Implementation Pattern for AdamW:
//
// ```s
// func (opt AdamW) step() {
//     opt.state.step += 1
//     lr := opt.learning_rate
//     beta1 := 0.9
//     beta2 := 0.999
//     eps := 1e-8
//     weight_decay := opt.weight_decay
//     
//     for param_id in opt.params {
//         param := opt.params[param_id]
//         grad := param.grad()
//         
//         if grad == nil {
//             continue
//         }
//         
//         // AdamW update
//         state := opt.state[param_id]
//         state.m = beta1 * state.m + (1 - beta1) * grad
//         state.v = beta2 * state.v + (1 - beta2) * (grad ** 2)
//         
//         m_hat := state.m / (1 - (beta1 ** opt.state.step))
//         v_hat := state.v / (1 - (beta2 ** opt.state.step))
//         
//         param -= lr * (m_hat / (sqrt(v_hat) + eps) + weight_decay * param)
//     }
// }
// ```

// Constraint from ARCHITECTURE_PRINCIPLES:
// Rule 7: Checkpoint & Resume
//   "恢复后 Loss 不连续 = 严重 Bug"
//   "Optimizer 状态必须完全保存"
//   "Resume 必须通过一致性验证"

// Phase -1 Verification
// Once implemented, verify:
// [ ] SGD optimizer works
// [ ] AdamW optimizer works
// [ ] Loss decreases over training steps
// [ ] Optimizer state can be saved/loaded
// [ ] After resume, loss curve is continuous
