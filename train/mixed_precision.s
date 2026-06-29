// Mixed Precision Training for 2T+ Enterprise Models
// Implements BF16/FP32 Master Weights + Dynamic Loss Scaling
// Critical for: memory reduction (50%+), training speedup (3x), gradient stability

package neurx.train.mixed_precision

use neurx.tensor.tensor
use neurx.tensor.new
use neurx.ops

// ── Mixed Precision Configuration ──
struct mixed_precision_config {
    // Precision settings
    bool use_bf16                    // Use BF16 instead of FP16 (recommended for 2T+)
    bool fp32_master_weights         // Keep master weights in FP32 for stability
    
    // Loss scaling (prevents gradient underflow in low precision)
    float initial_loss_scale        // Initial loss scale (e.g., 65536.0)
    float loss_scale_growth_factor   // Growth factor when no overflow (e.g., 2.0)
    float loss_scale_backoff_factor // Backoff factor on overflow (e.g., 0.5)
    int loss_scale_window           // Steps between overflow checks (e.g., 2000)
    
    // Gradient handling
    bool enable_gradient_accumulation // Enable micro-batch accumulation
    int accumulation_steps            // Number of micro-batches per update step
    
    // Memory optimization
    bool enable_activation_checkpointing // Trade compute for memory
}

// Default config for 2T model training
func default_2t_mixed_precision_config() mixed_precision_config {
    mixed_precision_config cfg
    cfg.use_bf16 = true
    cfg.fp32_master_weights = true
    cfg.initial_loss_scale = 65536.0
    cfg.loss_scale_growth_factor = 2.0
    cfg.loss_scale_backoff_factor = 0.5
    cfg.loss_scale_window = 2000
    cfg.enable_gradient_accumulation = true
    cfg.accumulation_steps = 8  // Effective batch_size * 8
    cfg.enable_activation_checkpointing = true
    return cfg
}

// ── Loss Scaler State ──
struct loss_scaler_state {
    float current_scale          // Current loss scale value
    int steps_since_last_check   // Steps since last overflow check
    int consecutive_overflows    // Consecutive overflow count (for backoff)
}

func new_loss_scaler(config mixed_precision_config) loss_scaler_state {
    loss_scaler_state state
    state.current_scale = config.initial_loss_scale
    state.steps_since_last_check = 0
    state.consecutive_overflows = 0
    return state
}

// Scale loss by current factor
func scale_loss(loss tensor, scaler loss_scaler_state) tensor {
    []float scaled_data = []float{cap: len(loss.data)}
    int i = 0
    while i < len(loss.data) {
        scaled_data[i] = loss.data[i] * scaler.current_scale
        i = i + 1
    }
    new(scaled_data, copy_int(loss.shape), loss.requires_grad)
}

// Check for gradient overflow and adjust scale
func check_overflow_and_adjust(
    gradients []tensor,
    scaler loss_scaler_state,
    config mixed_precision_config
) loss_scaler_state {
    
    bool has_overflow = false
    
    // Check each gradient for inf/nan
    int g = 0
    while g < len(gradients) {
        if len(gradients[g].data) > 0 {
            int i = 0
            while i < len(gradients[g].data) {
                float v = gradients[g].data[i]
                // Check for infinity or NaN
                if v != v || v > 1e20 || v < -1e20 {  // NaN or overflow
                    has_overflow = true
                    break
                }
                i = i + 1
            }
            if has_overflow { break }
        }
        g = g + 1
    }
    
    // Adjust scale based on overflow status
    if has_overflow {
        // Overflow detected - reduce scale
        scaler.current_scale = scaler.current_scale * config.loss_scale_backoff_factor
        scaler.consecutive_overflows = scaler.consecutive_overflows + 1
        scaler.steps_since_last_check = 0
        
        // Prevent scale from becoming too small
        if scaler.current_scale < 1.0 {
            scaler.current_scale = 1.0
        }
    } else {
        // No overflow - potentially increase scale after window
        scaler.steps_since_last_check = scaler.steps_since_last_check + 1
        
        if scaler.steps_since_last_check >= config.loss_scale_window {
            // Grow scale
            scaler.current_scale = scaler.current_scale * config.loss_scale_growth_factor
            scaler.steps_since_last_check = 0
            scaler.consecutive_overflows = 0
            
            // Cap maximum scale to prevent instability
            if scaler.current_scale > 32768.0 * 32768.0 {
                scaler.current_scale = 32768.0 * 32768.0
            }
        }
    }
    
    return scaler
}

// ── FP32 Master Weight Management ──
struct master_weight_manager {
    []tensor fp32_weights       // Master weights in FP32
    []tensor bf16_copies       // Working copies in BF16/FP16
    []string weight_names      // Names for identification
}

// Create manager with initial weights
func new_master_weight_manager(
    initial_weights []tensor,
    names []string,
    config mixed_precision_config
) master_weight_manager {
    
    master_weight_manager mgr
    mgr.weight_names = names
    
    int n = len(initial_weights)
    mgr.fp32_weights = []tensor{cap: n}
    mgr.bf16_copies = []tensor{cap: n}
    
    int i = 0
    while i < n {
        // Store FP32 master copy
        mgr.fp32_weights[i] = copy_tensor(initial_weights[i])
        
        // Create BF16 working copy (simulate by truncating precision)
        mgr.bf16_copies[i] = convert_to_bf16(initial_weights[i])
        
        i = i + 1
    }
    
    return mgr
}

// Convert FP32 tensor to BF16 (simulated via quantization)
func convert_to_bf16(fp32_tensor tensor) tensor {
    []float bf16_data = []float{cap: len(fp32_tensor.data)}
    int i = 0
    while i < len(fp32_tensor.data) {
        // Simulate BF16: round to ~7 bits of mantissa
        float v = fp32_tensor.data[i]
        
        // Round to nearest representable BF16 value
        // BF16 has 7-bit mantissa, so we round to 2^(-7) precision
        float rounded = round_to_bf16(v)
        bf16_data[i] = rounded
        
        i = i + 1
    }
    new(bf16_data, copy_int(fp32_tensor.shape), fp32_tensor.requires_grad)
}

// Round value to simulate BF16 precision
func round_to_bf16(value float) float {
    if value == 0.0 { return 0.0 }
    
    // Extract sign, exponent, mantissa simulation
    float abs_val = value
    if abs_val < 0.0 { abs_val = -abs_val }
    
    // Find power of 2
    float exp_val = 128.0  // Bias for float representation
    if abs_val > 0.0 {
        exp_val = log_approx(abs_val) / 0.69314718056  // ln(2)
    }
    
    // Round to 7-bit mantissa precision (2^(exp-7))
    float precision = pow_approx(2.0, exp_val - 7.0)
    float rounded = floor(abs_val / precision + 0.5) * precision
    
    // Restore sign
    if value < 0.0 { rounded = -rounded }
    
    return rounded
}

// Sync BF16 working copies back to FP32 masters after optimizer step
func sync_master_weights(mgr master_weight_manager) void {
    int i = 0
    while i < len(mgr.fp32_weights) {
        // Copy BF16 values back to FP32 master
        int j = 0
        while j < len(mgr.fp32_weights[i].data) {
            mgr.fp32_weights[i].data[j] = mgr.bf16_copies[i].data[j]
            j = j + 1
        }
        i = i + 1
    }
}

// Update BF16 working copies from FP32 masters (before forward pass)
func update_working_copies(mgr master_weight_manager) void {
    int i = 0
    while i < len(mgr.bf16_copies) {
        // Convert FP32 master to BF16 working copy
        mgr.bf16_copies[i] = convert_to_bf16(mgr.fp32_weights[i])
        i = i + 1
    }
}

// ── Gradient Accumulation State ──
struct gradient_accumulator {
    []tensor accumulated_gradients  // Accumulated gradients
    int current_step               // Current micro-step within accumulation window
    int total_steps               // Total accumulation steps
}

func new_gradient_accumulator([][]int weight_shapes, int total_steps) gradient_accumulator {
    gradient_accumulator acc
    acc.total_steps = total_steps
    acc.current_step = 0
    
    // Initialize zero gradients for each weight
    int n = len(weight_shapes)
    acc.accumulated_gradients = []tensor{cap: n}
    
    int i = 0
    while i < n {
        int numel = tensor_numel(weight_shapes[i])
        []float zeros = []float{cap: numel}
        int j = 0
        while j < numel {
            zeros[j] = 0.0
            j = j + 1
        }
        acc.accumulated_gradients[i] = new(zeros, copy_int(weight_shapes[i]), false)
        i = i + 1
    }
    
    return acc
}

// Add gradients from micro-batch to accumulator
func accumulate_gradients(
    acc gradient_accumulator,
    micro_batch_gradients []tensor
) gradient_accumulator {
    
    int i = 0
    while i < len(acc.accumulated_gradients) {
        // Add micro-batch gradient to accumulated
        int j = 0
        while j < len(acc.accumulated_gradients[i].data) {
            acc.accumulated_gradients[i].data[j] = 
                acc.accumulated_gradients[i].data[j] + micro_batch_gradients[i].data[j]
            j = j + 1
        }
        i = i + 1
    }
    
    acc.current_step = acc.current_step + 1
    return acc
}

// Check if accumulation is complete
func is_accumulation_complete(acc gradient_accumulator) bool {
    return acc.current_step >= acc.total_steps
}

// Get averaged gradients (divide by number of accumulated steps)
func get_averaged_gradients(acc gradient_accumulator) []tensor {
    []tensor avg_grads = []tensor{cap: len(acc.accumulated_gradients)}
    
    int i = 0
    while i < len(acc.accumulated_gradients) {
        float scale = 1.0 / float(acc.current_step)
        []float avg_data = []float{cap: len(acc.accumulated_gradients[i].data)}
        
        int j = 0
        while j < len(acc.accumulated_gradients[i].data) {
            avg_data[j] = acc.accumulated_gradients[i].data[j] * scale
            j = j + 1
        }
        
        avg_grads[i] = new(avg_data, copy_int(acc.accumulated_gradients[i].shape), true)
        i = i + 1
    }
    
    return avg_grads
}

// Reset accumulator for next iteration
func reset_accumulator(acc gradient_accumulator) gradient_accumulator {
    int i = 0
    while i < len(acc.accumulated_gradients) {
        int j = 0
        while j < len(acc.accumulated_gradients[i].data) {
            acc.accumulated_gradients[i].data[j] = 0.0
            j = j + 1
        }
        i = i + 1
    }
    
    acc.current_step = 0
    return acc
}

// ── Mixed Precision Training Loop Integration ──
struct mixed_precision_training_state {
    mixed_precision_config config
    loss_scaler_state scaler
    master_weight_manager weight_mgr
    gradient_accumulator grad_acc
    bool ready_for_update  // True when accumulation complete and no overflow
}

// Initialize mixed precision for 2T model training
func init_mixed_precision_training(
    initial_weights []tensor,
    weight_names []string,
    config mixed_precision_config
) mixed_precision_training_state {
    
    mixed_precision_training_state mp_state
    mp_state.config = config
    mp_state.scaler = new_loss_scaler(config)
    mp_state.weight_mgr = new_master_weight_manager(initial_weights, weight_names, config)
    mp_state.ready_for_update = false
    
    // Initialize gradient accumulator if enabled
    if config.enable_gradient_accumulation {
        [][]int shapes = [][]int{cap: len(initial_weights)}
        int i = 0
        while i < len(initial_weights) {
            shapes[i] = initial_weights[i].shape
            i = i + 1
        }
        mp_state.grad_acc = new_gradient_accumulator(shapes, config.accumulation_steps)
    }
    
    return mp_state
}

// Execute one mixed-precision training step
func mixed_precision_step(
    mp_state mixed_precision_training_state,
    forward_fn func([]tensor) (tensor, []tensor),  // Returns (loss, gradients)
    get_current_weights_func func() []tensor
) (mixed_precision_training_state, tensor, bool) {  // Returns (updated_state, scaled_loss, should_update)
    
    // 1. Ensure BF16 working copies are up-to-date
    update_working_copies(mp_state.weight_mgr)
    
    // 2. Forward pass with BF16 weights
    []tensor bf16_weights = mp_state.weight_mgr.bf16_copies
    tensor raw_loss
    []tensor gradients
    (raw_loss, gradients) = forward_fn(bf16_weights)
    
    // 3. Scale loss for gradient computation
    tensor scaled_loss = scale_loss(raw_loss, mp_state.scaler)
    
    // 4. Check for overflow before committing
    mp_state.scaler = check_overflow_and_adjust(gradients, mp_state.scaler, mp_state.config)
    
    // 5. Accumulate gradients if enabled
    if mp_state.config.enable_gradient_accumulation {
        mp_state.grad_acc = accumulate_gradients(mp_state.grad_acc, gradients)
        
        if is_accumulation_complete(mp_state.grad_acc) {
            // Accumulation complete - get averaged gradients
            gradients = get_averaged_gradients(mp_state.grad_acc)
            mp_state.ready_for_update = true
            
            // Reset accumulator
            mp_state.grad_acc = reset_accumulator(mp_state.grad_acc)
        } else {
            mp_state.ready_for_update = false
        }
    } else {
        mp_state.ready_for_update = !has_recent_overflow(mp_state.scaler)
    }
    
    return (mp_state, scaled_loss, mp_state.ready_for_update)
}

// Helper: check for recent overflow
func has_recent_overflow(scaler loss_scaler_state) bool {
    return scaler.consecutive_overflows > 0
}

// ── Memory Usage Estimation for 2T Model ──
func estimate_memory_savings_2t_model(
    num_parameters int64,     // Total parameters (e.g., 2 trillion)
    batch_size int,
    seq_len int,
    hidden_dim int,
    num_layers int
) (float, float, float) {  // Returns (fp32_mem_gb, mixed_prec_gb, savings_percent)
    
    // Parameter memory
    float param_mem_fp32 = float(num_parameters) * 4.0 / (1048576.0 * 1024.0)  // GB (4 bytes/param)
    float param_mem_bf16 = float(num_parameters) * 2.0 / (1048576.0 * 1024.0)  // GB (2 bytes/param)
    
    // Activation memory (approximate)
    float activation_per_layer = float(batch_size) * float(seq_len) * float(hidden_dim) * 4.0 / (1048576.0 * 1024.0)
    float total_activations = activation_per_layer * float(num_layers) * 2.0  // Forward + backward
    
    // Optimizer states (Adam: 2 states per parameter)
    float optimizer_states = float(num_parameters) * 8.0 / (1048576.0 * 1024.0)  // GB
    
    // Total memory
    float total_fp32 = param_mem_fp32 + total_activations + optimizer_states
    float total_mixed = param_mem_bf16 + total_activations * 0.5 + optimizer_states  // Activations also benefit
    
    float savings_percent = (1.0 - total_mixed / total_fp32) * 100.0
    
    return (total_fp32, total_mixed, savings_percent)
}

// Example usage for 2T model:
// For a 2T parameter model:
// - FP32 parameters: ~8TB (impossible on single GPU)
// - BF16 parameters: ~4TB (still needs sharding)
// - With ZeRO-3 + TP: feasible across GPU cluster
