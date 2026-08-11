package main
import (
    "encoding/json"
    "fmt"
    "math"
)
type mixed_precision_config struct {
    enabled: bool
    loss_scale: float
    loss_scale_growth_factor: float
    loss_scale_backoff_factor: float
    max_loss_scale: float
    min_loss_scale: float
    dynamics_loss_scale: bool
    overflow_patience: int
}
type mixed_precision_trainer struct {
    config: mixed_precision_config
    current_loss_scale: float
    overflow_counter: int
    steps_since_overflow: int
}
func (mpt *mixed_precision_trainer) init(config: mixed_precision_config) {
    mpt.config = config
    mpt.current_loss_scale = config.loss_scale
    mpt.overflow_counter = 0
    mpt.steps_since_overflow = 0
}

func create_default_amp_config(): mixed_precision_config {
    return mixed_precision_config{
        enabled: true,
        loss_scale: 65536.0,
        loss_scale_growth_factor: 2.0,
        loss_scale_backoff_factor: 0.5,
        max_loss_scale: 16777216.0,
        min_loss_scale: 1.0,
        dynamics_loss_scale: true,
        overflow_patience: 2000,
    }
}

func (mpt *mixed_precision_trainer) scale_loss(loss: float): float {
    if !mpt.config.enabled {
        return loss
    }
    return loss * mpt.current_loss_scale
}

func (mpt *mixed_precision_trainer) unscale_gradients(grad_norm: float): float {
    if !mpt.config.enabled {
        return grad_norm
    }
    return grad_norm / mpt.current_loss_scale
}

func (mpt *mixed_precision_trainer) check_overflow(grad_norm: float): bool {
    if !(grad_norm == grad_norm) {
        return true
    }
    if grad_norm > 1e10 {
        return true
    }
    return false
}

func (mpt *mixed_precision_trainer) handle_overflow() {
    mpt.overflow_counter++
    mpt.steps_since_overflow = 0
    new_scale := mpt.current_loss_scale * mpt.config.loss_scale_backoff_factor
    if new_scale < mpt.config.min_loss_scale {
        new_scale = mpt.config.min_loss_scale
    }
    mpt.current_loss_scale = new_scale
}

func (mpt *mixed_precision_trainer) step_success() {
    mpt.steps_since_overflow++
    if mpt.config.dynamics_loss_scale && mpt.steps_since_overflow > mpt.config.overflow_patience {
        new_scale := mpt.current_loss_scale * mpt.config.loss_scale_growth_factor
        if new_scale > mpt.config.max_loss_scale {
            new_scale = mpt.config.max_loss_scale
        }
        mpt.current_loss_scale = new_scale
        mpt.steps_since_overflow = 0
    }
}

func cast_to_fp16(value: float): float {
    if value > 65504.0 {
        return 65504.0
    }
    if value < -65504.0 {
        return -65504.0
    }
    if value > 0 && value < 0.000061 {
        return 0.000061
    }
    if value < 0 && value > -0.000061 {
        return -0.000061
    }
    return value
}

func cast_to_fp32(value: float): float {
    return value
}
type amp_step_result struct {
    scaled_loss: float
    overflow: bool
    loss_scale: float
    skipped: bool
}

func (mpt *mixed_precision_trainer) amp_step(
    loss: float,
    grad_norm: float): amp_step_result {
    result := amp_step_result{
        skipped: false,
        loss_scale: mpt.current_loss_scale,
    }
    if !mpt.config.enabled {
        result.scaled_loss = loss
        return result
    }
    result.scaled_loss = mpt.scale_loss(loss)
    unscaled_grad := mpt.unscale_gradients(grad_norm)
    if mpt.check_overflow(unscaled_grad) {
        mpt.handle_overflow()
        result.overflow = true
        result.skipped = true
        return result
    }
    mpt.step_success()
    return result
}

func (mpt *mixed_precision_trainer) get_stats(): map[string]interface{} {
    return map[string]interface{}{
        "enabled": mpt.config.enabled,
        "current_loss_scale": mpt.current_loss_scale,
        "overflow_count": mpt.overflow_counter,
        "steps_since_overflow": mpt.steps_since_overflow,
        "loss_scale_range": map[string]float{
            "min": mpt.config.min_loss_scale,
            "current": mpt.current_loss_scale,
            "max": mpt.config.max_loss_scale,
        },
        "dynamics_enabled": mpt.config.dynamics_loss_scale,
    }
}
type lr_schedule_type int
const (
    LINEAR_WARMUP = iota
    COSINE_ANNEALING
    EXPONENTIAL_DECAY
    STEP_DECAY
    POLYNOMIAL_DECAY
)
type learning_rate_scheduler struct {
    schedule_type: LRScheduleType
    base_lr: float
    current_lr: float
    total_steps: int
    warmup_steps: int
    min_lr_ratio: float
    step_size: int
    gamma: float
    power: float
}

func (lrs *learning_rate_scheduler) cosine_annealing_warmup(step: int): float {
    if step < lrs.warmup_steps {
        return lrs.base_lr * float(step) / float(lrs.warmup_steps)
    }
    progress := float(step - lrs.warmup_steps) / float(lrs.total_steps - lrs.warmup_steps)
    if progress > 1.0 {
        progress = 1.0
    }
    min_lr := lrs.base_lr * lrs.min_lr_ratio
    return min_lr + (lrs.base_lr - min_lr) * (1.0 + math.Cos(progress*math.Pi)) / 2.0
}

func (lrs *learning_rate_scheduler) exponential_decay_warmup(step: int): float {
    if step < lrs.warmup_steps {
        return lrs.base_lr * float(step) / float(lrs.warmup_steps)
    }
    decay_steps := step - lrs.warmup_steps
    decay_rate := math.Pow(lrs.min_lr_ratio, float(decay_steps)/float(lrs.total_steps-lrs.warmup_steps))
    return lrs.base_lr * decay_rate
}

func (lrs *learning_rate_scheduler) step_decay(step: int): float {
    if step < lrs.warmup_steps {
        return lrs.base_lr * float(step) / float(lrs.warmup_steps)
    }
    decayed_steps := step - lrs.warmup_steps
    num_decay := decayed_steps / lrs.step_size
    return lrs.base_lr * math.Pow(lrs.gamma, float(num_decay))
}

func (lrs *learning_rate_scheduler) polynomial_decay(step: int): float {
    if step < lrs.warmup_steps {
        return lrs.base_lr * float(step) / float(lrs.warmup_steps)
    }
    progress := float(step - lrs.warmup_steps) / float(lrs.total_steps - lrs.warmup_steps)
    if progress > 1.0 {
        progress = 1.0
    }
    min_lr := lrs.base_lr * lrs.min_lr_ratio
    decay := math.Pow(1.0 - progress, lrs.power)
    return min_lr + (lrs.base_lr - min_lr) * decay
}

func (lrs *learning_rate_scheduler) get_lr(step: int): float {
    switch lrs.schedule_type {
    case LINEAR_WARMUP:
        if step < lrs.warmup_steps {
            return lrs.base_lr * float(step) / float(lrs.warmup_steps)
        }
        return lrs.base_lr
    case COSINE_ANNEALING:
        return lrs.cosine_annealing_warmup(step)
    case EXPONENTIAL_DECAY:
        return lrs.exponential_decay_warmup(step)
    case STEP_DECAY:
        return lrs.step_decay(step)
    case POLYNOMIAL_DECAY:
        return lrs.polynomial_decay(step)
    default:
        return lrs.base_lr
    }
}
type gradient_clipper struct {
    max_grad_norm: float
    clip_type: string
}

func (gc *gradient_clipper) clip_by_norm(grad_norm: float): float {
    if grad_norm <= gc.max_grad_norm {
        return 1.0
    }
    return gc.max_grad_norm / grad_norm
}

func (gc *gradient_clipper) clip_by_value(gradient: float): float {
    if gradient > gc.max_grad_norm {
        return gc.max_grad_norm
    }
    if gradient < -gc.max_grad_norm {
        return -gc.max_grad_norm
    }
    return gradient
}
type training_optimization_config struct {
    use_amp: bool
    amp_config: mixed_precision_config
    use_lr_schedule: bool
    lr_schedule_type: LRScheduleType
    base_lr: float
    warmup_steps: int
    total_steps: int
    min_lr_ratio: float
    use_grad_clip: bool
    max_grad_norm: float
}

func create_default_optimization_config(): training_optimization_config {
    return training_optimization_config{
        use_amp: true,
        amp_config: create_default_amp_config(),
        use_lr_schedule: true,
        lr_schedule_type: COSINE_ANNEALING,
        base_lr: 5e-4,
        warmup_steps: 1000,
        total_steps: 100000,
        min_lr_ratio: 0.1,
        use_grad_clip: true,
        max_grad_norm: 1.0,
    }
}

func main() {
    amp_trainer := &mixed_precision_trainer{}
    amp_trainer.init(create_default_amp_config())
    lr_scheduler := &learning_rate_scheduler{
        schedule_type: COSINE_ANNEALING,
        base_lr: 5e-4,
        total_steps: 100000,
        warmup_steps: 1000,
        min_lr_ratio: 0.1,
    }
    grad_clipper := &gradient_clipper{
        max_grad_norm: 1.0,
        clip_type: "norm",
    }
    println("🎯 AMP + LR Schedule + Gradient Clipping Simulation:\n")
    for step := 0; step < 100000; step += 1000 {
        lr := lr_scheduler.get_lr(step)
        loss := 5.0 - float(step/1000)*0.04 + 0.1
        grad_norm := 1.2
        amp_result := amp_trainer.amp_step(loss, grad_norm)
        grad_scale := grad_clipper.clip_by_norm(grad_norm)
        if step % 10000 == 0 {
            fmt.Printf("Step %d | LR: %.2e | Loss: %.4f | Scaled Loss: %.4f | Loss Scale: %.0f | Grad Scale: %.4f | Overflow: %v\n",
                step, lr, loss, amp_result.scaled_loss, amp_result.loss_scale, grad_scale, amp_result.overflow)
        }
    }
    println("\n📊 AMP Final Statistics:")
    stats := amp_trainer.get_stats()
    stats_json, _ := json.Marshal(stats)
    println(string(stats_json))
}
