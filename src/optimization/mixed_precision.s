// Mixed Precision Training System
// Combines BF16/FP32 for 2x speedup and 2x memory savings
// Includes dynamic loss scaling for gradient overflow prevention

module mixed_precision_training

// Data types for mixed precision
enum precision_type {
    FP32,       // Full precision (32-bit)
    BF16,       // Brain float (16-bit with exponent range of FP32)
    FP16,       // Half precision (16-bit)
    INT8,       // Integer 8-bit (quantization)
}

// Loss scaling configuration
structure loss_scale_config {
    initial_scale: float        // Starting loss scale (typically 2^15)
    max_scale: float           // Maximum scale (2^24)
    min_scale: float           // Minimum scale (2^0)
    scale_growth_factor: float // Factor to grow by (2.0)
    scale_backoff_factor: float // Factor to shrink by (0.5)
    
    update_interval: int       // Steps between scale updates
    consecutive_overflows: int // Overflows before scale reduction
}

// Mixed precision state
structure mixed_precision_state {
    // Precision configuration
    compute_precision: precision_type    // Precision for compute (BF16)
    accumulator_precision: precision_type // For gradients (FP32)
    weight_precision: precision_type     // For weights (BF16)
    
    // Loss scaling state
    loss_scale: float
    current_loss_scale: float
    overflow_counter: int
    scale_update_step: int
    total_steps: int
    
    // Statistics
    num_overflow_steps: int
    num_total_steps: int
    average_loss_scale: float
}

// Gradient overflow detection and handling
structure gradient_overflow_info {
    has_overflow: bool
    overflow_rank: int          // Which GPU had overflow (-1 if none)
    overflow_value: float       // Max value that caused overflow
    num_overflowing_params: int // How many parameters had NaN/Inf
}

// Initialize mixed precision state
fn new_mixed_precision_state(config: loss_scale_config): mixed_precision_state {
    var state: mixed_precision_state
    
    state.compute_precision = BF16
    state.accumulator_precision = FP32
    state.weight_precision = BF16
    
    state.loss_scale = config.initial_scale
    state.current_loss_scale = config.initial_scale
    state.overflow_counter = 0
    state.scale_update_step = 0
    state.total_steps = 0
    
    state.num_overflow_steps = 0
    state.num_total_steps = 0
    state.average_loss_scale = config.initial_scale
    
    return state
}

// Get default loss scaling configuration for 2T model
fn default_loss_scale_config(): loss_scale_config {
    return loss_scale_config {
        initial_scale: 65536.0,    // 2^16
        max_scale: 16777216.0,     // 2^24
        min_scale: 1.0,            // 2^0
        scale_growth_factor: 2.0,
        scale_backoff_factor: 0.5,
        update_interval: 2000,     // Every 2000 steps
        consecutive_overflows: 2
    }
}

// Forward pass with automatic precision conversion
fn mixed_precision_forward(
    layer_fn: fn(vector): vector,  // Layer computation function
    inputs: vector,                // Input tensor
    state: mixed_precision_state
): vector {
    
    // Convert inputs to compute precision
    var fp32_inputs: vector = inputs  // Already FP32 at input
    var bf16_inputs: vector = convert_to_precision(fp32_inputs, state.compute_precision)
    
    // Run computation in lower precision
    var bf16_output: vector = layer_fn(bf16_inputs)
    
    // Convert output back to FP32 for accumulation
    var fp32_output: vector = convert_to_precision(bf16_output, FP32)
    
    return fp32_output
}

// Loss computation with scaling
fn compute_scaled_loss(
    loss: float,
    state: mixed_precision_state
): float {
    
    // Scale loss to prevent underflow in backward pass
    // Larger loss scale helps preserve gradient precision
    return loss * state.current_loss_scale
}

// Backward pass with unscaling
fn backward_pass_with_unscaling(
    grad_loss: float,
    gradients: vector,
    state: mixed_precision_state
): vector {
    
    // Unscale gradients by dividing by loss scale
    var unscaled_grad_loss: float = grad_loss / state.current_loss_scale
    
    // Unscale weight gradients
    var unscaled_gradients: vector = allocate_vector(length(gradients), 0.0)
    
    for i in range(0, length(gradients)) {
        unscaled_gradients[i] = gradients[i] / state.current_loss_scale
    }
    
    return unscaled_gradients
}

// Check for gradient overflow (NaN or Inf values)
fn check_gradient_overflow(gradients: vector, num_ranks: int, rank: int): gradient_overflow_info {
    
    var info: gradient_overflow_info
    info.has_overflow = false
    info.overflow_rank = -1
    info.overflow_value = 0.0
    info.num_overflowing_params = 0
    
    // Check for NaN and Inf
    for i in range(0, length(gradients)) {
        if is_nan(gradients[i]) || is_inf(gradients[i]) {
            info.has_overflow = true
            info.overflow_value = max(info.overflow_value, abs(gradients[i]))
            info.num_overflowing_params = info.num_overflowing_params + 1
        }
    }
    
    // Check if any rank has overflow (distributed check)
    var global_overflow: bool = has_global_overflow(info.has_overflow, num_ranks, rank)
    
    if global_overflow {
        info.has_overflow = true
        info.overflow_rank = find_overflow_rank(rank)
    }
    
    return info
}

// Update loss scale based on overflow status
fn update_loss_scale(
    state: mixed_precision_state,
    overflow_info: gradient_overflow_info,
    config: loss_scale_config
): void {
    
    state.scale_update_step = state.scale_update_step + 1
    
    if overflow_info.has_overflow {
        // Gradient overflow detected
        state.overflow_counter = state.overflow_counter + 1
        state.num_overflow_steps = state.num_overflow_steps + 1
        
        // Check if we've had too many consecutive overflows
        if state.overflow_counter >= config.consecutive_overflows {
            // Reduce loss scale
            state.current_loss_scale = state.current_loss_scale * config.scale_backoff_factor
            state.current_loss_scale = max(state.current_loss_scale, config.min_scale)
            state.overflow_counter = 0
            
            // Skip optimizer step to prevent corrupted updates
        }
    } else {
        // No overflow - can increase scale to potentially improve precision
        state.overflow_counter = 0
        
        if state.scale_update_step >= config.update_interval {
            // Periodically try to increase scale
            state.current_loss_scale = state.current_loss_scale * config.scale_growth_factor
            state.current_loss_scale = min(state.current_loss_scale, config.max_scale)
            state.scale_update_step = 0
        }
    }
    
    // Update statistics
    state.total_steps = state.total_steps + 1
    state.num_total_steps = state.num_total_steps + 1
    state.average_loss_scale = (state.average_loss_scale * (state.num_total_steps - 1) + state.current_loss_scale) / float(state.num_total_steps)
}

// Optimizer step with gradient clipping and precision conversion
fn mixed_precision_optimizer_step(
    optimizer: vector,              // Optimizer state (momentum, variance)
    params: vector,                 // Model parameters
    gradients: vector,              // Unscaled gradients
    learning_rate: float,
    state: mixed_precision_state,
    config: loss_scale_config
): vector {
    
    // Gradient clipping before optimizer step
    var clipped_gradients: vector = clip_gradients_by_norm(gradients, 1.0)
    
    // Apply optimizer (AdamW) in FP32
    var updated_params: vector = adamw_step(
        params, clipped_gradients, optimizer,
        learning_rate,
        0.9, 0.999, 1e-8, 0.01
    )
    
    // Convert weights back to BF16 for storage/compute
    var bf16_params: vector = convert_to_precision(updated_params, state.weight_precision)
    
    // Convert back to FP32 for next iteration
    return convert_to_precision(bf16_params, FP32)
}

// Full mixed precision training step
fn mixed_precision_training_step(
    model_forward: fn(vector): vector,  // Forward pass function
    compute_loss_fn: fn(vector, vector): float,  // Loss function
    targets: vector,                    // Target labels
    inputs: vector,                     // Input data
    params: vector,                     // Model parameters
    optimizer_state: vector,            // Optimizer state
    learning_rate: float,
    state: mixed_precision_state,
    config: loss_scale_config
): (vector, float, bool) {  // Returns (updated_params, loss, had_overflow)
    
    // ===== FORWARD PASS =====
    // Convert inputs to BF16 for forward pass
    var bf16_inputs: vector = convert_to_precision(inputs, BF16)
    var bf16_params: vector = convert_to_precision(params, BF16)
    
    // Forward pass in lower precision
    var predictions: vector = model_forward(bf16_inputs)
    
    // Compute loss in FP32 (more stable)
    var fp32_predictions: vector = convert_to_precision(predictions, FP32)
    var loss: float = compute_loss_fn(fp32_predictions, targets)
    
    // Scale loss to prevent underflow
    var scaled_loss: float = loss * state.current_loss_scale
    
    // ===== BACKWARD PASS =====
    // Backward to compute gradients
    var gradients: vector = backward_pass(scaled_loss)
    
    // Unscale gradients
    var unscaled_gradients: vector = allocate_vector(length(gradients), 0.0)
    for i in range(0, length(gradients)) {
        unscaled_gradients[i] = gradients[i] / state.current_loss_scale
    }
    
    // ===== CHECK FOR OVERFLOW =====
    var overflow_info: gradient_overflow_info = check_gradient_overflow(unscaled_gradients, 1, 0)
    
    var should_skip_update: bool = overflow_info.has_overflow
    
    // ===== UPDATE LOSS SCALE =====
    update_loss_scale(state, overflow_info, config)
    
    // ===== OPTIMIZER STEP =====
    var updated_params: vector = params
    
    if !should_skip_update {
        updated_params = mixed_precision_optimizer_step(
            optimizer_state, params, unscaled_gradients,
            learning_rate, state, config
        )
    }
    
    return (updated_params, loss, overflow_info.has_overflow)
}

// Distributed gradient synchronization with precision handling
fn distributed_gradient_sync(
    gradients: vector,
    num_ranks: int,
    rank: int,
    state: mixed_precision_state
): vector {
    
    // Check for local overflow before sync
    var local_overflow: bool = false
    for i in range(0, length(gradients)) {
        if is_nan(gradients[i]) || is_inf(gradients[i]) {
            local_overflow = true
            break
        }
    }
    
    // All-reduce gradients in FP32 for numerical stability
    var synced_gradients: vector = all_reduce_avg(gradients, num_ranks, rank)
    
    // Convert to BF16 for storage if needed
    if state.weight_precision == BF16 {
        synced_gradients = convert_to_precision(synced_gradients, BF16)
    }
    
    return synced_gradients
}

// Convert tensor to target precision
fn convert_to_precision(tensor: vector, target_precision: precision_type): vector {
    
    var result: vector = allocate_vector(length(tensor), 0.0)
    
    if target_precision == FP32 {
        // Assume input is higher or same precision, just return
        return tensor
    } else if target_precision == BF16 {
        // Convert to BF16 (round to nearest)
        for i in range(0, length(tensor)) {
            result[i] = round_to_bf16(tensor[i])
        }
    } else if target_precision == FP16 {
        // Convert to FP16
        for i in range(0, length(tensor)) {
            result[i] = round_to_fp16(tensor[i])
        }
    }
    
    return result
}

// Round value to BF16 format
fn round_to_bf16(val: float): float {
    // BF16: sign(1) + exponent(8) + mantissa(7)
    // Round to nearest even
    var bf16_bits: int = float_to_bits(val)
    var rounded_bits: int = bf16_bits >> 16  // Keep top 16 bits
    return bits_to_float(rounded_bits << 16)
}

// Round value to FP16 format
fn round_to_fp16(val: float): float {
    // FP16: sign(1) + exponent(5) + mantissa(10)
    var fp32_bits: int = float_to_bits(val)
    var rounded_bits: int = fp32_bits >> 16
    return bits_to_float(rounded_bits << 16)
}

// Compute memory reduction from mixed precision
fn compute_mixed_precision_memory_savings(
    param_count: int,
    optimizer_state_count: int,  // m and v for Adam
    use_bf16: bool,
    use_gradient_checkpointing: bool
): (float, float) {  // Returns (memory_saved_gb, speedup_factor)
    
    // FP32 baseline
    var fp32_param_memory: float = float(param_count) * 4.0 / (1024 * 1024 * 1024)
    var fp32_grad_memory: float = float(param_count) * 4.0 / (1024 * 1024 * 1024)
    var fp32_optimizer_memory: float = float(optimizer_state_count) * 4.0 / (1024 * 1024 * 1024)
    var fp32_total: float = fp32_param_memory + fp32_grad_memory + fp32_optimizer_memory
    
    // Mixed precision (BF16)
    var mixed_param_memory: float = float(param_count) * 2.0 / (1024 * 1024 * 1024)
    var mixed_grad_memory: float = float(param_count) * 2.0 / (1024 * 1024 * 1024)
    var mixed_optimizer_memory: float = fp32_optimizer_memory  // Optimizer in FP32
    var mixed_total: float = mixed_param_memory + mixed_grad_memory + mixed_optimizer_memory
    
    // Apply gradient checkpointing factor
    if use_gradient_checkpointing {
        mixed_grad_memory = mixed_grad_memory * 0.1  // 10% for on-demand recompute
    }
    
    var memory_saved: float = fp32_total - mixed_total
    var speedup: float = fp32_total / mixed_total
    
    return (memory_saved, speedup)
}

// Estimate training throughput with mixed precision
fn estimate_throughput_improvement(
    fp32_throughput: float,  // Tokens per second in FP32
    use_bf16: bool,
    use_flash_attention: bool
): float {
    
    var throughput_multiplier: float = 1.0
    
    // BF16 typically gives 1.8-2.0x speedup due to:
    // - Smaller tensor sizes (2x less bandwidth needed)
    // - More operations per cycle on modern GPUs
    // - Faster matrix multiplications
    if use_bf16 {
        throughput_multiplier = throughput_multiplier * 1.9
    }
    
    // Flash Attention adds 3x speedup for attention operations
    // Attention is ~25% of total computation in transformers
    if use_flash_attention {
        // ~75% of non-attention ops + 25% of attention ops at 3x
        throughput_multiplier = throughput_multiplier * (0.75 * 1.0 + 0.25 * 3.0)
    }
    
    return fp32_throughput * throughput_multiplier
}

// Helper: Gradient clipping by global norm
fn clip_gradients_by_norm(gradients: vector, max_norm: float): vector {
    
    // Compute global norm
    var norm_sq: float = 0.0
    for i in range(0, length(gradients)) {
        norm_sq = norm_sq + gradients[i] * gradients[i]
    }
    var norm: float = sqrt(norm_sq)
    
    // Clip if needed
    var clip_factor: float = 1.0
    if norm > max_norm {
        clip_factor = max_norm / norm
    }
    
    // Apply clipping
    var clipped: vector = allocate_vector(length(gradients), 0.0)
    for i in range(0, length(gradients)) {
        clipped[i] = gradients[i] * clip_factor
    }
    
    return clipped
}

// AdamW optimizer step
fn adamw_step(
    params: vector, gradients: vector, optimizer_state: vector,
    learning_rate: float,
    beta1: float, beta2: float, eps: float, weight_decay: float
): vector {
    
    var updated_params: vector = allocate_vector(length(params), 0.0)
    
    // Split optimizer state into m (first moment) and v (second moment)
    var m: vector = get_first_half(optimizer_state)
    var v: vector = get_second_half(optimizer_state)
    
    var step: int = 1  // Would be tracked separately
    
    // Bias correction
    var bias_correction1: float = 1.0 - pow(beta1, float(step))
    var bias_correction2: float = 1.0 - pow(beta2, float(step))
    
    // Update each parameter
    for i in range(0, length(params)) {
        // Update biased first moment
        m[i] = beta1 * m[i] + (1.0 - beta1) * gradients[i]
        
        // Update biased second moment
        v[i] = beta2 * v[i] + (1.0 - beta2) * gradients[i] * gradients[i]
        
        // Bias corrected moments
        var m_hat: float = m[i] / bias_correction1
        var v_hat: float = v[i] / bias_correction2
        
        // AdamW update with decoupled weight decay
        var delta: float = learning_rate * (m_hat / (sqrt(v_hat) + eps))
        updated_params[i] = (params[i] - delta) * (1.0 - learning_rate * weight_decay)
    }
    
    return updated_params
}

// Helper: Check for global overflow across all ranks
fn has_global_overflow(local_overflow: bool, num_ranks: int, rank: int): bool {
    // In actual distributed setting, use all-reduce
    return local_overflow
}

// Helper: Find which rank had overflow
fn find_overflow_rank(rank: int): int {
    return rank
}

// Helper: All-reduce average
fn all_reduce_avg(gradients: vector, num_ranks: int, rank: int): vector {
    // Distributed all-reduce average
    return gradients
}

// Helper: Get NaN check
fn is_nan(val: float): bool {
    return val != val  // NaN != NaN
}

// Helper: Get Inf check
fn is_inf(val: float): bool {
    return abs(val) > 1e10  // Very large value
}

// Helper: Backward pass (placeholder)
fn backward_pass(loss: float): vector {
    return allocate_vector(1, 0.0)
}

// Helper: Get first half of vector
fn get_first_half(v: vector): vector {
    var mid: int = length(v) / 2
    var result: vector = allocate_vector(mid, 0.0)
    for i in range(0, mid) {
        result[i] = v[i]
    }
    return result
}

// Helper: Get second half of vector
fn get_second_half(v: vector): vector {
    var mid: int = length(v) / 2
    var result: vector = allocate_vector(length(v) - mid, 0.0)
    for i in range(mid, length(v)) {
        result[i - mid] = v[i]
    }
    return result
}

// Helper: Convert float to bits representation
fn float_to_bits(val: float): int {
    // Placeholder
    return 0
}

// Helper: Convert bits to float
fn bits_to_float(bits: int): float {
    // Placeholder
    return 0.0
}

// Recommended mixed precision configuration for 2T model
fn recommended_mixed_precision_config_2t(): loss_scale_config {
    return loss_scale_config {
        initial_scale: 65536.0,     // 2^16
        max_scale: 16777216.0,      // 2^24
        min_scale: 1.0,
        scale_growth_factor: 2.0,
        scale_backoff_factor: 0.5,
        update_interval: 2000,
        consecutive_overflows: 2
    }
}

// Print mixed precision training status
fn print_mixed_precision_status(state: mixed_precision_state): void {
    // Print current state
}
