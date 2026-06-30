// NeurX Mixed Precision Module
// Support for float16 and float32 mixed training
// Package: neurx.training.mixed_precision
// Author: NeurX Team
// Date: 2026-06-29

package neurx.training.mixed_precision

// ============================================================
// Data Structures
// ============================================================

// float16 representation (simplified: stored as int for 16-bit simulation)
struct float16 {
    data: int  // 16-bit value representation
}

struct mixed_precision_config {
    use_mixed_precision: bool
    compute_dtype: string  // "float32" or "float16"
    accumulate_dtype: string  // Always float32 for stability
    loss_scale: float
    loss_scale_window: int
    loss_scale_growth_factor: float
    loss_scale_backoff_factor: float
    loss_scale_min: float
    loss_scale_max: float
}

struct loss_scale_scheduler {
    current_scale: float
    min_scale: float
    max_scale: float
    growth_factor: float
    backoff_factor: float
    overflow_count: int
    scale_window: int
    steps_since_last_overflow: int
}

struct mixed_precision_state {
    master_weights: [][]float  // float32 master copy
    compute_weights: [][]float  // float16 or float32 compute copy
    gradients_fp32: [][]float  // float32 gradients
    optimizer_state_fp32: [][]float  // float32 for optimizer
    loss_scale_scheduler: loss_scale_scheduler
    loss_scale: float
    overflow_count: int
    total_steps: int
}

// ============================================================
// Float16 Conversion Utilities
// ============================================================

// float32_to_float16: Convert float32 to float16 representation
func float32_to_float16(value: float) float16 {
    var f16: float16
    
    // Simplified conversion: take significant bits
    // In real implementation, would use proper IEEE 754 half-precision
    if value < 0.0 {
        value = 0.0 - value
        // Handle negative
    }
    
    // Clamp to float16 range (approximately ±65504)
    if value > 65504.0 {
        value = 65504.0
    }
    if value > 0.0 && value < 5.96e-8 {
        value = 5.96e-8  // Minimum normal float16
    }
    
    // Simplified: convert to 16-bit representation
    var bits = 0
    if value != 0.0 {
        bits = int(value * 1000.0) % 65536
    }
    
    f16.data = bits
    return f16
}

// float16_to_float32: Convert float16 to float32
func float16_to_float32(f16: float16) float {
    // Simplified conversion back
    return float(f16.data) / 1000.0
}

// ============================================================
// Gradient Casting
// ============================================================

// cast_gradients_to_fp32: Cast gradients to float32 for accumulation
func cast_gradients_to_fp32(gradients: [][]float) [][]float {
    var result: [][]float = [][]float(len(gradients))
    var i = 0
    while i < len(gradients) {
        result[i] = gradients[i]  // Already float32
        i = i + 1
    }
    return result
}

// scale_gradients: Scale gradients by loss scale
func scale_gradients(gradients: [][]float, loss_scale: float) [][]float {
    var result: [][]float = [][]float(len(gradients))
    var i = 0
    while i < len(gradients) {
        result[i] = gradients[i] / loss_scale
        i = i + 1
    }
    return result
}

// unscale_gradients: Unscale gradients after optimizer step
func unscale_gradients(gradients: [][]float, loss_scale: float) [][]float {
    var result: [][]float = [][]float(len(gradients))
    var i = 0
    while i < len(gradients) {
        result[i] = gradients[i] * loss_scale
        i = i + 1
    }
    return result
}

// ============================================================
// Loss Scale Scheduling
// ============================================================

// new_loss_scale_scheduler: Create loss scale scheduler
func new_loss_scale_scheduler(initial_scale: float, window: int, growth_factor: float, backoff_factor: float) loss_scale_scheduler {
    var scheduler: loss_scale_scheduler
    scheduler.current_scale = initial_scale
    scheduler.min_scale = 1.0
    scheduler.max_scale = 65536.0
    scheduler.growth_factor = growth_factor
    scheduler.backoff_factor = backoff_factor
    scheduler.overflow_count = 0
    scheduler.scale_window = window
    scheduler.steps_since_last_overflow = 0
    return scheduler
}

// update_loss_scale: Update loss scale based on gradient overflow
func update_loss_scale(scheduler: loss_scale_scheduler, had_overflow: bool) loss_scale_scheduler {
    if had_overflow {
        scheduler.current_scale = scheduler.current_scale * scheduler.backoff_factor
        if scheduler.current_scale < scheduler.min_scale {
            scheduler.current_scale = scheduler.min_scale
        }
        scheduler.overflow_count = scheduler.overflow_count + 1
        scheduler.steps_since_last_overflow = 0
    } else {
        scheduler.steps_since_last_overflow = scheduler.steps_since_last_overflow + 1
        
        // Grow loss scale after certain number of stable steps
        if scheduler.steps_since_last_overflow >= scheduler.scale_window {
            scheduler.current_scale = scheduler.current_scale * scheduler.growth_factor
            if scheduler.current_scale > scheduler.max_scale {
                scheduler.current_scale = scheduler.max_scale
            }
            scheduler.steps_since_last_overflow = 0
        }
    }
    
    return scheduler
}

// ============================================================
// Overflow Detection
// ============================================================

// detect_overflow: Check if gradients contain NaN or Inf
func detect_overflow(gradients: [][]float) bool {
    var i = 0
    while i < len(gradients) {
        if gradients[i] < 0.0 {
            // NaN or Inf check (simplified)
            if gradients[i] != gradients[i] {
                return true  // NaN
            }
        }
        if gradients[i] > 1.0e10 || gradients[i] < -1.0e10 {
            // Very large values indicate potential overflow
            if gradients[i] > 1.0e20 {
                return true  // Likely Inf
            }
        }
        i = i + 1
    }
    return false
}

// detect_gradient_overflow: Detailed overflow detection
func detect_gradient_overflow(gradients: [][]float, max_grad_norm: float) (bool, float) {
    var has_nan = false
    var grad_norm_sq = 0.0
    var i = 0
    
    while i < len(gradients) {
        var grad = gradients[i]
        
        // Check for NaN (NaN != NaN)
        if grad != grad {
            has_nan = true
            break
        }
        
        // Accumulate norm
        grad_norm_sq = grad_norm_sq + grad * grad
        i = i + 1
    }
    
    // Compute norm
    var norm = 0.0
    if grad_norm_sq > 0.0 {
        // sqrt approximation
        var x = grad_norm_sq
        norm = x
        var iter = 0
        while iter < 5 {
            if x == 0.0 {
                break
            }
            norm = (norm + x / norm) / 2.0
            iter = iter + 1
        }
    }
    
    var overflow = has_nan || norm > max_grad_norm
    return overflow, norm
}

// ============================================================
// Master Weight Management
// ============================================================

// new_mixed_precision_state: Initialize mixed precision state
func new_mixed_precision_state(model_size: int) mixed_precision_state {
    var state: mixed_precision_state
    state.master_weights = [][]float(model_size)
    state.compute_weights = [][]float(model_size)
    state.gradients_fp32 = [][]float(model_size)
    state.optimizer_state_fp32 = [][]float(model_size)
    state.loss_scale_scheduler = new_loss_scale_scheduler(65536.0, 2000, 2.0, 0.5)
    state.loss_scale = state.loss_scale_scheduler.current_scale
    state.overflow_count = 0
    state.total_steps = 0
    return state
}

// cast_weights_to_compute: Cast master weights to compute dtype
func cast_weights_to_compute(master_weights: [][]float, use_fp16: bool) [][]float {
    var result: [][]float = [][]float(len(master_weights))
    var i = 0
    
    if use_fp16 {
        // Convert to float16
        while i < len(master_weights) {
            var f16 = float32_to_float16(master_weights[i])
            result[i] = float16_to_float32(f16)
            i = i + 1
        }
    } else {
        // Keep as float32
        while i < len(master_weights) {
            result[i] = master_weights[i]
            i = i + 1
        }
    }
    
    return result
}

// update_master_weights: Update master weights from gradients
func update_master_weights(master_weights: [][]float, gradients_fp32: [][]float, learning_rate: float) [][]float {
    var result: [][]float = [][]float(len(master_weights))
    var i = 0
    
    while i < len(master_weights) {
        result[i] = master_weights[i] - learning_rate * gradients_fp32[i]
        i = i + 1
    }
    
    return result
}

// synchronize_weights: Sync compute weights with master weights
func synchronize_weights(state: mixed_precision_state, use_fp16: bool) mixed_precision_state {
    state.compute_weights = cast_weights_to_compute(state.master_weights, use_fp16)
    return state
}

// ============================================================
// Mixed Precision Training Step
// ============================================================

// mixed_precision_forward: Forward pass with selected dtype
func mixed_precision_forward(inputs: [][]float, weights: [][]float, use_fp16: bool) [][]float {
    // In practice, this would dispatch to float16 or float32 kernels
    // For now, we keep float32 for numerical stability
    
    var result: [][]float = [][]float(len(inputs) * len(weights))
    var idx = 0
    
    var i = 0
    while i < len(inputs) {
        var j = 0
        while j < len(weights) {
            var sum = 0.0
            var k = 0
            while k < len(inputs[i]) {
                sum = sum + inputs[i][k] * weights[k][j]
                k = k + 1
            }
            result[idx] = sum
            idx = idx + 1
            j = j + 1
        }
        i = i + 1
    }
    
    return result
}

// mixed_precision_backward: Backward pass with loss scaling
func mixed_precision_backward(gradients: [][]float, loss_scale: float) [][]float {
    // Scale gradients up for backward pass
    var scaled_gradients: [][]float = [][]float(len(gradients))
    var i = 0
    
    while i < len(gradients) {
        scaled_gradients[i] = gradients[i] * loss_scale
        i = i + 1
    }
    
    return scaled_gradients
}

// mixed_precision_optimizer_step: Single training step with mixed precision
func mixed_precision_optimizer_step(
    state: mixed_precision_state,
    loss: float,
    gradients: [][]float,
    learning_rate: float,
    config: mixed_precision_config
) (mixed_precision_state, bool) {
    
    // 1. Detect overflow
    var overflow = detect_overflow(gradients)
    
    if overflow {
        // Skip weight update if overflow detected
        state.loss_scale_scheduler = update_loss_scale(state.loss_scale_scheduler, true)
        state.overflow_count = state.overflow_count + 1
        return state, true  // true = overflow occurred
    }
    
    // 2. Scale gradients by loss scale
    var scaled_gradients = scale_gradients(gradients, state.loss_scale_scheduler.current_scale)
    
    // 3. Cast to FP32 for accumulation
    state.gradients_fp32 = cast_gradients_to_fp32(scaled_gradients)
    
    // 4. Update master weights
    state.master_weights = update_master_weights(
        state.master_weights,
        state.gradients_fp32,
        learning_rate
    )
    
    // 5. Synchronize compute weights
    var use_fp16 = config.compute_dtype == "float16"
    state = synchronize_weights(state, use_fp16)
    
    // 6. Update loss scale scheduler
    state.loss_scale_scheduler = update_loss_scale(state.loss_scale_scheduler, false)
    state.total_steps = state.total_steps + 1
    
    return state, false  // false = no overflow
}

// ============================================================
// Configuration and Utilities
// ============================================================

// new_mixed_precision_config: Create default config
func new_mixed_precision_config() mixed_precision_config {
    var config: mixed_precision_config
    config.use_mixed_precision = true
    config.compute_dtype = "float32"  // Keep float32 by default for stability
    config.accumulate_dtype = "float32"
    config.loss_scale = 65536.0
    config.loss_scale_window = 2000
    config.loss_scale_growth_factor = 2.0
    config.loss_scale_backoff_factor = 0.5
    config.loss_scale_min = 1.0
    config.loss_scale_max = 65536.0
    return config
}

// get_mixed_precision_stats: Get training statistics
func get_mixed_precision_stats(state: mixed_precision_state) string {
    var result = "Mixed Precision Stats:\n"
    result = result + "  Current Loss Scale: " + string(state.loss_scale_scheduler.current_scale) + "\n"
    result = result + "  Overflow Count: " + string(state.overflow_count) + "\n"
    result = result + "  Total Steps: " + string(state.total_steps) + "\n"
    result = result + "  Stable Steps Since Last Overflow: " + string(state.loss_scale_scheduler.steps_since_last_overflow) + "\n"
    return result
}

// validate_mixed_precision_state: Sanity check state
func validate_mixed_precision_state(state: mixed_precision_state) bool {
    // Check loss scale is in valid range
    if state.loss_scale_scheduler.current_scale < state.loss_scale_scheduler.min_scale {
        return false
    }
    if state.loss_scale_scheduler.current_scale > state.loss_scale_scheduler.max_scale {
        return false
    }
    
    // Check weights match size
    if len(state.master_weights) != len(state.compute_weights) {
        return false
    }
    
    return true
}
