// NeurX Gradient Accumulation Module
// Support for gradient accumulation to increase effective batch size
// Package: neurx.training.gradient_accumulation
// Author: NeurX Team
// Date: 2026-06-29

package neurx.training.gradient_accumulation

// ============================================================
// Data Structures
// ============================================================

struct gradient_accumulation_config {
    accumulation_steps: int  // Accumulate over N steps
    normalize_accumulated: bool  // Normalize by accumulation_steps
    reset_on_overflow: bool
    log_accumulated_loss: bool
}

struct accumulated_gradients {
    gradients: [][]float
    accumulation_steps: int
    loss_sum: float
    accumulated_loss: float
    steps_accumulated: int
    is_ready: bool  // True when ready to update
}

struct accumulation_buffer {
    buffer: [][]float
    accumulated_loss: float
    accumulated_steps: int
    accumulated_norm: float
    normalized: bool
}

// ============================================================
// Accumulation Management
// ============================================================

// new_accumulated_gradients: Create gradient accumulator
func new_accumulated_gradients(gradient_size: int) accumulated_gradients {
    var accum: accumulated_gradients
    accum.gradients = [][]float(gradient_size)
    accum.accumulation_steps = 0
    accum.loss_sum = 0.0
    accum.accumulated_loss = 0.0
    accum.steps_accumulated = 0
    accum.is_ready = false
    
    // Initialize to zero
    var i = 0
    while i < gradient_size {
        accum.gradients[i] = 0.0
        i = i + 1
    }
    
    return accum
}

// accumulate_gradients: Add gradients to accumulator
func accumulate_gradients(
    accum: accumulated_gradients,
    step_gradients: [][]float,
    step_loss: float,
    scale: float
) accumulated_gradients {
    
    var i = 0
    while i < len(step_gradients) {
        accum.gradients[i] = accum.gradients[i] + step_gradients[i] * scale
        i = i + 1
    }
    
    accum.loss_sum = accum.loss_sum + step_loss * scale
    accum.accumulated_loss = accum.loss_sum
    accum.steps_accumulated = accum.steps_accumulated + 1
    
    return accum
}

// check_accumulation_complete: Check if ready to update
func check_accumulation_complete(accum: accumulated_gradients, accumulation_steps: int) accumulated_gradients {
    if accum.steps_accumulated >= accumulation_steps {
        accum.is_ready = true
    } else {
        accum.is_ready = false
    }
    return accum
}

// normalize_accumulated_gradients: Scale by accumulation steps
func normalize_accumulated_gradients(
    accum: accumulated_gradients,
    accumulation_steps: int
) accumulated_gradients {
    
    if accumulation_steps > 0 {
        var scale = 1.0 / float(accumulation_steps)
        var i = 0
        while i < len(accum.gradients) {
            accum.gradients[i] = accum.gradients[i] * scale
            i = i + 1
        }
        accum.loss_sum = accum.loss_sum * scale
        accum.accumulated_loss = accum.loss_sum
    }
    
    return accum
}

// reset_accumulation: Clear accumulator for next cycle
func reset_accumulation(accum: accumulated_gradients) accumulated_gradients {
    var i = 0
    while i < len(accum.gradients) {
        accum.gradients[i] = 0.0
        i = i + 1
    }
    
    accum.loss_sum = 0.0
    accum.accumulated_loss = 0.0
    accum.steps_accumulated = 0
    accum.is_ready = false
    
    return accum
}

// get_accumulated_loss: Get average loss
func get_accumulated_loss(accum: accumulated_gradients) float {
    if accum.steps_accumulated == 0 {
        return 0.0
    }
    return accum.loss_sum / float(accum.steps_accumulated)
}

// ============================================================
// Multi-Accumulator Support (for distributed training)
// ============================================================

// new_accumulation_buffer: Create accumulation buffer
func new_accumulation_buffer(gradient_size: int) accumulation_buffer {
    var buffer: accumulation_buffer
    buffer.buffer = [][]float(gradient_size)
    buffer.accumulated_loss = 0.0
    buffer.accumulated_steps = 0
    buffer.accumulated_norm = 0.0
    buffer.normalized = false
    
    // Initialize to zero
    var i = 0
    while i < gradient_size {
        buffer.buffer[i] = 0.0
        i = i + 1
    }
    
    return buffer
}

// add_to_buffer: Add gradients to accumulation buffer
func add_to_buffer(
    buf: accumulation_buffer,
    gradients: [][]float,
    loss: float
) accumulation_buffer {
    
    var i = 0
    while i < len(gradients) {
        buf.buffer[i] = buf.buffer[i] + gradients[i]
        i = i + 1
    }
    
    buf.accumulated_loss = buf.accumulated_loss + loss
    buf.accumulated_steps = buf.accumulated_steps + 1
    
    return buf
}

// compute_accumulated_norm: Compute gradient norm for clipping
func compute_accumulated_norm(buf: accumulation_buffer) float {
    var norm_sq = 0.0
    var i = 0
    
    while i < len(buf.buffer) {
        norm_sq = norm_sq + buf.buffer[i] * buf.buffer[i]
        i = i + 1
    }
    
    // Compute sqrt
    var norm = 0.0
    if norm_sq > 0.0 {
        norm = norm_sq
        var iter = 0
        while iter < 10 {
            if norm_sq == 0.0 {
                break
            }
            norm = (norm + norm_sq / norm) / 2.0
            iter = iter + 1
        }
    }
    
    buf.accumulated_norm = norm
    return norm
}

// normalize_buffer: Normalize accumulated gradients
func normalize_buffer(buf: accumulation_buffer, steps: int) accumulation_buffer {
    if steps > 0 {
        var scale = 1.0 / float(steps)
        var i = 0
        while i < len(buf.buffer) {
            buf.buffer[i] = buf.buffer[i] * scale
            i = i + 1
        }
        buf.accumulated_loss = buf.accumulated_loss / float(steps)
        buf.accumulated_norm = buf.accumulated_norm * scale
    }
    buf.normalized = true
    return buf
}

// clip_accumulated_gradients: Clip by gradient norm
func clip_accumulated_gradients(buf: accumulation_buffer, max_norm: float) accumulation_buffer {
    var norm = compute_accumulated_norm(buf)
    
    if norm > max_norm {
        var clip_scale = max_norm / norm
        var i = 0
        while i < len(buf.buffer) {
            buf.buffer[i] = buf.buffer[i] * clip_scale
            i = i + 1
        }
        buf.accumulated_norm = max_norm
    }
    
    return buf
}

// clear_buffer: Reset accumulation buffer
func clear_buffer(buf: accumulation_buffer) accumulation_buffer {
    var i = 0
    while i < len(buf.buffer) {
        buf.buffer[i] = 0.0
        i = i + 1
    }
    buf.accumulated_loss = 0.0
    buf.accumulated_steps = 0
    buf.accumulated_norm = 0.0
    buf.normalized = false
    return buf
}

// ============================================================
// Gradient Accumulation Strategies
// ============================================================

// effective_batch_size: Compute effective batch size
func effective_batch_size(batch_size: int, accumulation_steps: int) int {
    return batch_size * accumulation_steps
}

// scale_loss_for_accumulation: Scale loss when using accumulation
func scale_loss_for_accumulation(loss: float, accumulation_steps: int) float {
    if accumulation_steps > 0 {
        return loss / float(accumulation_steps)
    }
    return loss
}

// get_accumulation_progress: Get progress string
func get_accumulation_progress(step: int, accumulation_steps: int) string {
    var current_step = step % accumulation_steps
    if current_step == 0 {
        current_step = accumulation_steps
    }
    
    var result = ""
    result = result + "Accumulation Step: " + string(current_step)
    result = result + " / " + string(accumulation_steps)
    
    if current_step == accumulation_steps {
        result = result + " [UPDATE WEIGHTS]"
    }
    
    return result
}

// ============================================================
// Distributed Gradient Accumulation
// ============================================================

// sync_accumulated_gradients: Synchronize gradients across workers
// In practice, this would use AllReduce in distributed setting
func sync_accumulated_gradients(local_gradients: [][]float, num_workers: int) [][]float {
    var result: [][]float = [][]float(len(local_gradients))
    
    // In distributed case: AllReduce(local_gradients)
    // For now, just copy (simulating single-worker)
    var i = 0
    while i < len(local_gradients) {
        result[i] = local_gradients[i]
        i = i + 1
    }
    
    // In multi-worker, would average: result[i] / num_workers
    return result
}

// average_accumulated_gradients: Average across workers
func average_accumulated_gradients(gradients: [][]float, num_workers: int) [][]float {
    if num_workers <= 1 {
        return gradients
    }
    
    var result: [][]float = [][]float(len(gradients))
    var scale = 1.0 / float(num_workers)
    
    var i = 0
    while i < len(gradients) {
        result[i] = gradients[i] * scale
        i = i + 1
    }
    
    return result
}

// ============================================================
// Training Loop Integration
// ============================================================

// should_update_weights: Check if should apply weight update
func should_update_weights(step: int, accumulation_steps: int) bool {
    if accumulation_steps <= 1 {
        return true
    }
    return (step % accumulation_steps) == 0
}

// get_effective_learning_rate: Adjust LR for accumulation
func get_effective_learning_rate(base_lr: float, accumulation_steps: int) float {
    // Learning rate scaling depends on strategy
    // Option 1: Keep same (compensate by scaling loss)
    // Option 2: Scale by accumulation_steps
    // Option 3: Scale by sqrt(accumulation_steps)
    
    // Most common: scale by sqrt for stability
    var scale = 1.0
    if accumulation_steps > 1 {
        var tmp = float(accumulation_steps)
        var x = tmp
        var iter = 0
        while iter < 5 {
            x = (x + tmp / x) / 2.0
            iter = iter + 1
        }
        scale = x
    }
    
    return base_lr / scale
}

// ============================================================
// Monitoring and Diagnostics
// ============================================================

// compute_gradient_statistics: Get gradient statistics
func compute_gradient_statistics(gradients: [][]float) (float, float, float) {
    if len(gradients) == 0 {
        return 0.0, 0.0, 0.0
    }
    
    var sum = 0.0
    var sum_sq = 0.0
    var max_abs = 0.0
    
    var i = 0
    while i < len(gradients) {
        var g = gradients[i]
        if g < 0.0 {
            g = 0.0 - g
        }
        
        sum = sum + g
        sum_sq = sum_sq + g * g
        
        if g > max_abs {
            max_abs = g
        }
        
        i = i + 1
    }
    
    var mean = sum / float(len(gradients))
    var variance = sum_sq / float(len(gradients)) - mean * mean
    
    return mean, variance, max_abs
}

// get_accumulation_stats: Get accumulation statistics
func get_accumulation_stats(buf: accumulation_buffer) string {
    var mean, variance, max_abs = compute_gradient_statistics(buf.buffer)
    
    var result = "Accumulation Stats:\n"
    result = result + "  Steps Accumulated: " + string(buf.accumulated_steps) + "\n"
    result = result + "  Accumulated Loss: " + string(buf.accumulated_loss) + "\n"
    result = result + "  Gradient Norm: " + string(buf.accumulated_norm) + "\n"
    result = result + "  Mean Gradient: " + string(mean) + "\n"
    result = result + "  Max Gradient: " + string(max_abs) + "\n"
    
    return result
}

// ============================================================
// Configuration
// ============================================================

// new_gradient_accumulation_config: Create config
func new_gradient_accumulation_config() gradient_accumulation_config {
    var config: gradient_accumulation_config
    config.accumulation_steps = 1
    config.normalize_accumulated = true
    config.reset_on_overflow = true
    config.log_accumulated_loss = true
    return config
}

// validate_accumulation_config: Validate configuration
func validate_accumulation_config(config: gradient_accumulation_config) bool {
    if config.accumulation_steps < 1 {
        return false
    }
    if config.accumulation_steps > 1000 {
        return false  // Unreasonably large
    }
    return true
}
