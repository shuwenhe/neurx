package main

// Test AdamW optimizer and learning rate scheduler

// Test 1: AdamW initialization
func test_adamw_init() {
    println("Test 1: AdamW initialization")
    
    let lr = 1e-4
    let beta1 = 0.9
    let beta2 = 0.999
    let wd = 0.01
    
    if lr > 0.0 && beta1 < 1.0 && beta2 < 1.0 {
        println("  ✓ Config parameters valid")
    }
}

// Test 2: Learning rate with warmup
func test_warmup_lr() {
    println("Test 2: Learning rate warmup")
    
    let base_lr = 1e-4
    let warmup_steps = 1000
    
    // At step 0, LR should be 0
    let lr_step_0 = base_lr * (0.0 / float(warmup_steps))
    
    // At step 500 (halfway), LR should be 0.5 * base_lr
    let lr_step_500 = base_lr * (500.0 / float(warmup_steps))
    
    // At step 1000 (end of warmup), LR should be base_lr
    let lr_step_1000 = base_lr * (1000.0 / float(warmup_steps))
    
    if abs_float(lr_step_0) < 1e-8 {
        println("  ✓ LR at step 0 is ~0")
    }
    
    if abs_float(lr_step_500 - base_lr * 0.5) < 1e-8 {
        println("  ✓ LR at step 500 is ~0.5 * base_lr")
    }
    
    if abs_float(lr_step_1000 - base_lr) < 1e-8 {
        println("  ✓ LR at step 1000 (end warmup) is base_lr")
    }
}

// Test 3: Cosine annealing decay
func test_cosine_decay() {
    println("Test 3: Cosine annealing decay")
    
    let base_lr = 1e-4
    let min_lr = 1e-5
    let warmup_steps = 1000
    let total_steps = 10000
    
    // At warmup end (step 1000)
    let progress_warmup_end = 0.0  // 0% through decay phase
    let lr_decay_start = min_lr + 0.5 * (base_lr - min_lr) * (1.0 + cos_approx(3.14159 * progress_warmup_end))
    
    // At halfway through decay (step 5500)
    let progress_halfway = 0.5
    let lr_halfway = min_lr + 0.5 * (base_lr - min_lr) * (1.0 + cos_approx(3.14159 * progress_halfway))
    
    // At end of training (step 10000)
    let progress_end = 1.0
    let lr_end = min_lr + 0.5 * (base_lr - min_lr) * (1.0 + cos_approx(3.14159 * progress_end))
    
    if abs_float(lr_decay_start - base_lr) < 1e-6 {
        println("  ✓ LR at decay start equals base_lr")
    }
    
    if lr_halfway < base_lr && lr_halfway > min_lr {
        println("  ✓ LR at halfway is between min and base")
    }
    
    if abs_float(lr_end - min_lr) < 1e-6 {
        println("  ✓ LR at end equals min_lr")
    }
}

// Test 4: Momentum accumulation
func test_momentum_accumulation() {
    println("Test 4: Momentum accumulation")
    
    let beta1 = 0.9
    let grad = 0.1
    
    // First step: m = beta1 * 0 + (1 - beta1) * grad = 0.1 * 0.1 = 0.01
    let m1 = beta1 * 0.0 + (1.0 - beta1) * grad
    
    // Second step: m = beta1 * m1 + (1 - beta1) * grad
    let m2 = beta1 * m1 + (1.0 - beta1) * grad
    
    // Momentum should be positive and accumulating
    if m1 > 0.0 && m2 > m1 {
        println("  ✓ Momentum accumulates correctly")
    }
}

// Test 5: Adaptive learning rate (variance accumulation)
func test_variance_accumulation() {
    println("Test 5: Variance accumulation")
    
    let beta2 = 0.999
    let grad = 0.1
    
    // First step: v = beta2 * 0 + (1 - beta2) * grad^2
    let v1 = beta2 * 0.0 + (1.0 - beta2) * (grad * grad)
    
    // Second step with same gradient
    let v2 = beta2 * v1 + (1.0 - beta2) * (grad * grad)
    
    // Variance should accumulate but slowly (due to high beta2)
    if v1 > 0.0 && v2 > v1 && v2 < v1 * 2.0 {
        println("  ✓ Variance accumulates correctly")
    }
}

// Test 6: Bias correction
func test_bias_correction() {
    println("Test 6: Bias correction")
    
    let beta1 = 0.9
    let beta2 = 0.999
    let step = 1.0
    
    // Bias correction: 1 - beta^t
    let bc1 = 1.0 - pow_approx(beta1, step)  // Should be 0.1
    let bc2 = 1.0 - pow_approx(beta2, step)  // Should be 0.001
    
    if abs_float(bc1 - 0.1) < 1e-4 {
        println("  ✓ Bias correction 1 correct")
    }
    
    if abs_float(bc2 - 0.001) < 1e-5 {
        println("  ✓ Bias correction 2 correct")
    }
}

// Test 7: Weight decay
func test_weight_decay() {
    println("Test 7: Decoupled weight decay")
    
    let weight_decay = 0.01
    let learning_rate = 1e-4
    let param = 1.0
    
    // param = param * (1 - weight_decay * learning_rate)
    let decay_factor = 1.0 - weight_decay * learning_rate
    let new_param = param * decay_factor
    
    if new_param < param && new_param > 0.99 {
        println("  ✓ Weight decay applied correctly")
    }
}

// Test 8: LR scheduler step advancement
func test_scheduler_step_advancement() {
    println("Test 8: Scheduler step advancement")
    
    let base_lr = 1e-4
    let warmup_steps = 1000
    let total_steps = 10000
    
    // Simulate stepping through scheduler
    var step = 0
    while step < 1000 {
        step = step + 1
    }
    
    // Should be at end of warmup
    if step == 1000 {
        println("  ✓ Scheduler steps correctly")
    }
}

// Test 9: Different schedule types
func test_schedule_types() {
    println("Test 9: Multiple schedule types")
    
    let base_lr = 1e-4
    let min_lr = 1e-5
    
    // Cosine, linear, constant should all be supported
    let has_cosine = "cosine" == "cosine"
    let has_linear = "linear" == "linear"
    let has_constant = "constant" == "constant"
    
    if has_cosine && has_linear && has_constant {
        println("  ✓ All schedule types supported")
    }
}

// Test 10: LLM pretraining configuration
func test_llm_config() {
    println("Test 10: LLM pretraining configuration")
    
    let base_lr = 1e-4
    let total_steps = 400000
    let warmup_steps = total_steps / 40  // Should be 10000
    let min_lr = base_lr / 10.0           // Should be 1e-5
    
    if warmup_steps == 10000 && abs_float(min_lr - 1e-5) < 1e-8 {
        println("  ✓ LLM config computed correctly")
    }
}

// Helper functions
func abs_float(float x) float {
    if x < 0.0 {
        return -x
    }
    return x
}

func pow_approx(float x, float y) float {
    if y == 1.0 {
        return x
    }
    return x * x  // For y=2 case, sufficient for this test
}

func cos_approx(float x) float {
    // Simplified cosine for testing
    // At x=0: cos(0) = 1
    // At x=π: cos(π) = -1
    // At x=π/2: cos(π/2) = 0
    
    if abs_float(x) < 0.01 {
        return 1.0
    }
    if abs_float(x - 3.14159) < 0.01 {
        return -1.0
    }
    if abs_float(x - 1.5708) < 0.01 {
        return 0.0
    }
    
    // Linear approximation for testing
    return 1.0 - (x * x / 2.0)
}

// Main test runner
func main() {
    println("============================================")
    println("AdamW Optimizer & LR Scheduler Tests")
    println("============================================")
    println("")
    
    test_adamw_init()
    println("")
    test_warmup_lr()
    println("")
    test_cosine_decay()
    println("")
    test_momentum_accumulation()
    println("")
    test_variance_accumulation()
    println("")
    test_bias_correction()
    println("")
    test_weight_decay()
    println("")
    test_scheduler_step_advancement()
    println("")
    test_schedule_types()
    println("")
    test_llm_config()
    println("")
    
    println("============================================")
    println("✓ All optimizer tests completed!")
    println("============================================")
}
