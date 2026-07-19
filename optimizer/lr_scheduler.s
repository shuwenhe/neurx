package neurx.optimizer.lr_scheduler

// =====================================================================
// Learning Rate Scheduler
// =====================================================================
// Implements:
// - Linear warmup
// - Cosine annealing decay
// - Constant learning rate
// - Support for minimum learning rate floor

struct lr_schedule_config {
    float base_lr              // Initial learning rate
    float min_lr               // Minimum learning rate floor
    int warmup_steps           // Number of warmup steps
    int total_steps            // Total training steps
    string schedule_type       // "cosine", "linear", "constant"
}

struct lr_scheduler {
    lr_schedule_config config
    int current_step
    float current_lr
}

// =====================================================================
// Initialization
// =====================================================================

func new_lr_scheduler(lr_schedule_config cfg) lr_scheduler {
    lr_scheduler {
        config: cfg,
        current_step: 0,
        current_lr: cfg.base_lr,
    }
}

// =====================================================================
// Learning Rate Computation
// =====================================================================

// Linear warmup: gradually increase LR from 0 to base_lr over warmup_steps
func compute_warmup_lr(float base_lr, int warmup_steps, int current_step) float {
    if current_step >= warmup_steps {
        return base_lr
    }
    
    if warmup_steps == 0 {
        return base_lr
    }
    
    // Linear interpolation: lr = base_lr * (current_step / warmup_steps)
    return base_lr * (float(current_step) / float(warmup_steps))
}

// Cosine annealing: decay learning rate following cosine curve
// After warmup, decay from base_lr to min_lr over remaining steps
func compute_cosine_lr(
    float base_lr,
    float min_lr,
    int warmup_steps,
    int total_steps,
    int current_step
) float {
    // Phase 1: Warmup
    if current_step < warmup_steps {
        return compute_warmup_lr(base_lr, warmup_steps, current_step)
    }
    
    // Phase 2: Cosine decay
    let steps_after_warmup = float(current_step - warmup_steps)
    let total_decay_steps = float(total_steps - warmup_steps)
    
    if total_decay_steps <= 0.0 {
        return base_lr
    }
    
    // Cosine annealing: min_lr + 0.5 * (base_lr - min_lr) * (1 + cos(π * progress))
    // where progress = steps_after_warmup / total_decay_steps
    
    let progress = steps_after_warmup / total_decay_steps
    if progress >= 1.0 {
        return min_lr
    }
    
    let cos_val = cosine_approx(3.14159 * progress)
    let lr = min_lr + 0.5 * (base_lr - min_lr) * (1.0 + cos_val)
    
    return max_approx(lr, min_lr)
}

// Linear decay: linearly decrease from base_lr to min_lr
func compute_linear_lr(
    float base_lr,
    float min_lr,
    int warmup_steps,
    int total_steps,
    int current_step
) float {
    // Phase 1: Warmup
    if current_step < warmup_steps {
        return compute_warmup_lr(base_lr, warmup_steps, current_step)
    }
    
    // Phase 2: Linear decay
    let steps_after_warmup = float(current_step - warmup_steps)
    let total_decay_steps = float(total_steps - warmup_steps)
    
    if total_decay_steps <= 0.0 {
        return base_lr
    }
    
    let progress = steps_after_warmup / total_decay_steps
    if progress >= 1.0 {
        return min_lr
    }
    
    // Linear interpolation
    let lr = base_lr + (min_lr - base_lr) * progress
    return max_approx(lr, min_lr)
}

// Constant learning rate (no decay)
func compute_constant_lr(float base_lr, int warmup_steps, int current_step) float {
    if current_step < warmup_steps {
        return compute_warmup_lr(base_lr, warmup_steps, current_step)
    }
    return base_lr
}

// =====================================================================
// Scheduler Step
// =====================================================================

// Advance scheduler to next step and compute learning rate
func lr_scheduler_step(lr_scheduler sched) lr_scheduler {
    let current_step = sched.current_step
    let cfg = sched.config
    
    var new_lr = cfg.base_lr
    
    if cfg.schedule_type == "cosine" {
        new_lr = compute_cosine_lr(
            cfg.base_lr,
            cfg.min_lr,
            cfg.warmup_steps,
            cfg.total_steps,
            current_step
        )
    } else if cfg.schedule_type == "linear" {
        new_lr = compute_linear_lr(
            cfg.base_lr,
            cfg.min_lr,
            cfg.warmup_steps,
            cfg.total_steps,
            current_step
        )
    } else if cfg.schedule_type == "constant" {
        new_lr = compute_constant_lr(cfg.base_lr, cfg.warmup_steps, current_step)
    }
    
    lr_scheduler {
        config: cfg,
        current_step: current_step + 1,
        current_lr: new_lr,
    }
}

// Get current learning rate without advancing step
func get_current_lr(lr_scheduler sched) float {
    return sched.current_lr
}

// Get current step
func get_current_step(lr_scheduler sched) int {
    return sched.current_step
}

// =====================================================================
// Common Configurations
// =====================================================================

// Create scheduler for LLM pretraining
// Typical: 10k steps warmup, 400k total, base_lr=1e-4, min_lr=1e-5
func new_llm_scheduler(
    float base_lr,
    int total_steps
) lr_scheduler {
    let warmup_steps = total_steps / 40  // 2.5% warmup
    let min_lr = base_lr / 10.0           // min_lr = base_lr / 10
    
    let cfg = lr_schedule_config {
        base_lr: base_lr,
        min_lr: min_lr,
        warmup_steps: warmup_steps,
        total_steps: total_steps,
        schedule_type: "cosine",
    }
    
    return new_lr_scheduler(cfg)
}

// Create scheduler for fine-tuning
// Typical: 100 steps warmup, 1000 total, base_lr=5e-5, min_lr=0
func new_finetune_scheduler(
    float base_lr,
    int total_steps
) lr_scheduler {
    let warmup_steps = total_steps / 10  // 10% warmup
    
    let cfg = lr_schedule_config {
        base_lr: base_lr,
        min_lr: 0.0,
        warmup_steps: warmup_steps,
        total_steps: total_steps,
        schedule_type: "cosine",
    }
    
    return new_lr_scheduler(cfg)
}

// =====================================================================
// Helper Functions
// =====================================================================

// Cosine function approximation
func cosine_approx(float x) float {
    // Reduce x to [-π, π] range for better accuracy
    var x_reduced = x
    while x_reduced > 3.14159 {
        x_reduced = x_reduced - 6.28318  // 2π
    }
    while x_reduced < -3.14159 {
        x_reduced = x_reduced + 6.28318
    }
    
    // Taylor series for cos(x): 1 - x^2/2! + x^4/4! - x^6/6! + ...
    let x2 = x_reduced * x_reduced
    let result = 1.0
            - x2 / 2.0
            + (x2 * x2) / 24.0
            - (x2 * x2 * x2) / 720.0
            + (x2 * x2 * x2 * x2) / 40320.0
    
    return result
}

// Maximum of two floats
func max_approx(float a, float b) float {
    if a > b {
        return a
    }
    return b
}

// Absolute value
func abs_approx(float x) float {
    if x < 0.0 {
        return -x
    }
    return x
}
