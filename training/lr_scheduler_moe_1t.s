package neurx.training.lr_scheduler

// ============================================================================
// 学习率调度器 (Cosine Annealing with Warmup)
//
// 调度策略:
//   Phase 1: Warmup (线性增长)
//     LR = base_lr * (step / warmup_steps)
//   
//   Phase 2: Annealing (余弦衰减)
//     LR = base_lr * 0.5 * (1 + cos(π * (step - warmup) / (total - warmup)))
//   
//   可选 Phase 3: Final Constant (可选最小 LR)
//     LR = min_lr
//
// 参数:
//   base_lr: 基础学习率 (2e-4 for 1T MoE)
//   warmup_steps: 预热步数 (10K for 3T tokens)
//   total_steps: 总步数 (750K for 3T tokens)
//   min_lr: 最小学习率 (2e-5)
//
// ============================================================================

use neurx.strings
use neurx.runtime.io.{io_println}

// ============================================================================
// 1. 调度器配置与状态
// ============================================================================

struct lr_schedule_config {
    string schedule_type         // "cosine", "linear", "exponential", "constant"
    float base_lr
    float min_lr
    int warmup_steps             // 预热步数
    int total_steps              // 总训练步数
    int decay_steps              // 衰减周期 (用于其他调度器)
    float decay_rate             // 衰减率
    int cycle_steps              // 周期 (用于周期调度)
}

struct lr_scheduler_state {
    lr_schedule_config config
    
    // 当前状态
    int current_step
    float current_lr
    float current_base_lr        // 基础 LR (可被外部修改)
    
    // 历史记录
    []float lr_history           // [num_steps]
    []int step_history
    
    // 统计
    int num_schedules
    float avg_lr
    float max_lr
    float min_lr_achieved
}

// 初始化学习率调度器
func lr_scheduler_new(
    float base_lr,
    int warmup_steps,
    int total_steps
) lr_scheduler_state {
    
    lr_schedule_config cfg = lr_schedule_config {
        schedule_type: "cosine",
        base_lr: base_lr,
        min_lr: base_lr / 10.0,     // 默认最小 LR 为基础 LR 的 1/10
        warmup_steps: warmup_steps,
        total_steps: total_steps,
        decay_steps: total_steps,
        decay_rate: 0.1,
        cycle_steps: 0,
    }
    
    lr_scheduler_state state = lr_scheduler_state {
        config: cfg,
        current_step: 0,
        current_lr: 0.0,
        current_base_lr: base_lr,
        lr_history: make([]float, 0),
        step_history: make([]int, 0),
        num_schedules: 0,
        avg_lr: 0.0,
        max_lr: 0.0,
        min_lr_achieved: base_lr,
    }
    
    state
}

// ============================================================================
// 2. Cosine Annealing Warmup 调度器 (默认)
// ============================================================================

// Cosine Annealing with Warmup
func compute_cosine_annealing_lr(
    lr_scheduler_state state
) float {
    
    int step = state.current_step
    float base_lr = state.current_base_lr
    int warmup_steps = state.config.warmup_steps
    int total_steps = state.config.total_steps
    float min_lr = state.config.min_lr
    
    float lr = 0.0
    
    if step < warmup_steps {
        // Warmup: 线性增长
        lr = base_lr * float(step) / float(warmup_steps)
    } else {
        // Annealing: 余弦衰减
        float progress = float(step - warmup_steps) / float(total_steps - warmup_steps)
        
        // 限制进度在 [0, 1]
        if progress > 1.0 {
            progress = 1.0
        }
        
        // cos(π * progress)
        float cos_val = cos(3.14159 * progress)
        lr = min_lr + (base_lr - min_lr) * 0.5 * (1.0 + cos_val)
    }
    
    // 确保 LR 不低于最小值
    if lr < min_lr {
        lr = min_lr
    }
    if lr > base_lr {
        lr = base_lr
    }
    
    state.current_lr = lr
    lr
}

// ============================================================================
// 3. 线性衰减调度器
// ============================================================================

func compute_linear_decay_lr(
    lr_scheduler_state state
) float {
    
    int step = state.current_step
    float base_lr = state.current_base_lr
    int warmup_steps = state.config.warmup_steps
    int total_steps = state.config.total_steps
    float min_lr = state.config.min_lr
    
    float lr = 0.0
    
    if step < warmup_steps {
        // Warmup
        lr = base_lr * float(step) / float(warmup_steps)
    } else {
        // 线性衰减
        float progress = float(step - warmup_steps) / float(total_steps - warmup_steps)
        if progress > 1.0 {
            progress = 1.0
        }
        lr = base_lr - (base_lr - min_lr) * progress
    }
    
    if lr < min_lr {
        lr = min_lr
    }
    
    state.current_lr = lr
    lr
}

// ============================================================================
// 4. 指数衰减调度器
// ============================================================================

func compute_exponential_decay_lr(
    lr_scheduler_state state
) float {
    
    int step = state.current_step
    float base_lr = state.current_base_lr
    int warmup_steps = state.config.warmup_steps
    int total_steps = state.config.total_steps
    float decay_rate = state.config.decay_rate
    float min_lr = state.config.min_lr
    
    float lr = 0.0
    
    if step < warmup_steps {
        // Warmup
        lr = base_lr * float(step) / float(warmup_steps)
    } else {
        // 指数衰减: LR = base_lr * decay_rate^(step / total_steps)
        float exponent = float(step - warmup_steps) / float(total_steps - warmup_steps)
        lr = base_lr * pow(decay_rate, exponent)
    }
    
    if lr < min_lr {
        lr = min_lr
    }
    
    state.current_lr = lr
    lr
}

// ============================================================================
// 5. 单周期学习率调度器
// ============================================================================

func compute_one_cycle_lr(
    lr_scheduler_state state
) float {
    
    int step = state.current_step
    float base_lr = state.current_base_lr
    float max_lr = base_lr * 10.0  // 通常最大 LR 是基础 LR 的 10 倍
    float min_lr = state.config.min_lr
    int total_steps = state.config.total_steps
    
    float lr = 0.0
    
    // 分成三个阶段
    int step1 = total_steps / 30      // 第一阶段占 1/30
    int step2 = step1 * 24 / 25        // 第二阶段占 24/30
    
    if step < step1 {
        // 阶段 1: min_lr → max_lr
        float progress = float(step) / float(step1)
        lr = min_lr + (max_lr - min_lr) * progress
    } else if step < step1 + step2 {
        // 阶段 2: max_lr → min_lr
        float progress = float(step - step1) / float(step2)
        lr = max_lr - (max_lr - min_lr) * progress
    } else {
        // 阶段 3: 常数 min_lr
        lr = min_lr
    }
    
    state.current_lr = lr
    lr
}

// ============================================================================
// 6. 步长调度器 (Step Decay)
// ============================================================================

func compute_step_decay_lr(
    lr_scheduler_state state,
    int step_size,
    float gamma
) float {
    
    int step = state.current_step
    float base_lr = state.current_base_lr
    int warmup_steps = state.config.warmup_steps
    
    float lr = 0.0
    
    if step < warmup_steps {
        // Warmup
        lr = base_lr * float(step) / float(warmup_steps)
    } else {
        // Step decay
        int decay_count = (step - warmup_steps) / step_size
        lr = base_lr * pow(gamma, float(decay_count))
    }
    
    state.current_lr = lr
    lr
}

// ============================================================================
// 7. 主接口函数
// ============================================================================

// 计算当前学习率
func compute_lr(
    lr_scheduler_state state
) float {
    
    float lr = 0.0
    
    if state.config.schedule_type == "cosine" {
        lr = compute_cosine_annealing_lr(state)
    } else if state.config.schedule_type == "linear" {
        lr = compute_linear_decay_lr(state)
    } else if state.config.schedule_type == "exponential" {
        lr = compute_exponential_decay_lr(state)
    } else if state.config.schedule_type == "constant" {
        lr = state.current_base_lr
    } else {
        // 默认使用 cosine
        lr = compute_cosine_annealing_lr(state)
    }
    
    // 记录历史
    // state.lr_history.append(lr)
    // state.step_history.append(state.current_step)
    
    // 更新统计
    state.num_schedules = state.num_schedules + 1
    state.avg_lr = (state.avg_lr * float(state.num_schedules - 1) + lr) / float(state.num_schedules)
    
    if lr > state.max_lr {
        state.max_lr = lr
    }
    if lr < state.min_lr_achieved {
        state.min_lr_achieved = lr
    }
    
    lr
}

// 向前推进一步 (通常在 optimizer.step() 后调用)
func step(
    lr_scheduler_state state
) float {
    
    state.current_step = state.current_step + 1
    
    float new_lr = compute_lr(state)
    new_lr
}

// ============================================================================
// 8. LR 预热工具
// ============================================================================

// 获取预热阶段的预期 LR
func get_warmup_lr(
    lr_scheduler_state state,
    int warmup_step
) float {
    
    float base_lr = state.current_base_lr
    int warmup_steps = state.config.warmup_steps
    
    if warmup_step >= warmup_steps {
        return base_lr
    }
    
    float warmup_lr = base_lr * float(warmup_step) / float(warmup_steps)
    warmup_lr
}

// ============================================================================
// 9. 工具函数
// ============================================================================

func cos(float x) float {
    // cos(π * progress) 的简单近似
    // 在 [0, π] 范围内
    if x < 0.0 {
        x = -x
    }
    
    // cos(π) = -1, cos(π/2) = 0, cos(0) = 1
    float pi = 3.14159
    
    float result = 1.0
    
    // 简单的泰勒级数近似
    float term = 1.0
    int n = 1
    while n < 10 {
        term = term * (-x * x) / float(2 * n * (2 * n - 1))
        result = result + term
        n = n + 1
    }
    
    result
}

func pow(float base, float exponent) float {
    // base^exponent
    // 简化实现
    if exponent == 0.0 {
        return 1.0
    }
    if base == 0.0 {
        return 0.0
    }
    if exponent == 1.0 {
        return base
    }
    
    // 使用对数: base^exp = exp(exp * log(base))
    float log_base = 1.0  // 占位符
    float result = exp(exponent * log_base)
    result
}

func exp(float x) float {
    // e^x
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    
    // 泰勒级数
    float result = 1.0
    float term = 1.0
    int i = 1
    while i < 20 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    
    result
}

func float(int x) float {
    0.0 + x
}
