package neurx.distributed.mixed_precision

// ═══════════════════════════════════════════════════════════════════
// NeurX Mixed Precision Training System
// ═══════════════════════════════════════════════════════════════════
//
// Implements mixed-precision training for 2T parameter models:
//   - BF16 (BFloat16): Primary storage format for parameters/gradients
//   - FP32 (Float32): Master weights and optimizer states
//   - FP16 (Float16): Optional, for GPU kernels that prefer FP16 over BF16
//   - FP8 (E4M3/E5M2): Experimental, for next-gen hardware (H100+)
//
// Memory savings with mixed precision:
//   Pure FP32:     P*4 bytes params + P*4 bytes grads + P*8 bytes opt = 16P
//   BF16 + FP32:   P*2 bytes params + P*2 bytes grads + P*8 bytes opt = 12P (25% savings)
//   With ZeRO-3:    12P / N_gpus (linear scaling)
//
// Key techniques:
//   1. Loss Scaling: Prevent underflow in gradient computation
//   2. Dynamic Casting: Auto-cast between precision levels
//   3. Master Weights: FP32 copy of all parameters for stable updates
//   4. Gradient Accumulation: Maintain precision across micro-batches

// ===================== Data Type Definitions =====================

int PRECISION_FP32 = 0
int PRECISION_BF16 = 1
int PRECISION_FP16 = 2
int PRECISION_FP8_E4M3 = 3   // E4M3: good for forward pass
int PRECISION_FP8_E5M2 = 4   // E5M2: good for gradients

struct dtype_info {
    int id
    string name
    int byte_size         // Bytes per element
    double max_value      // Maximum representable value
    double min_positive   // Smallest positive value
    double epsilon        // Machine epsilon (1 + eps != 1)
}

func get_dtype_info(int dtype_id) dtype_info {
    dtype_info info
    if dtype_id == PRECISION_FP32 {
        info.id = PRECISION_FP32
        info.name = "float32"
        info.byte_size = 4
        info.max_value = 340282346638528859811704183484516925440.0  // ~3.4e38
        info.min_positive = 1.175494350822287507968736537222245677e-38
        info.epsilon = 1.1920928955078125e-7
    } else if dtype_id == PRECISION_BF16 {
        info.id = PRECISION_BF16
        info.name = "bfloat16"
        info.byte_size = 2
        info.max_value = 3.38953139e38
        info.min_positive = 9.1835e-41
        info.epsilon = 0.0078125  // 2+-7 (same exponent range as FP32)
    } else if dtype_id == PRECISION_FP16 {
        info.id = PRECISION_FP16
        info.name = "float16"
        info.byte_size = 2
        info.max_value = 65504.0
        info.min_positive = 6.103515625e-5
        info.epsilon = 0.0009765625  // 2+-10
    } else {  // FP8 variants
        info.id = PRECISION_FP8_E4M3
        info.name = "fp8_e4m3"
        info.byte_size = 1
        info.max_value = 448.0
        info.min_positive = 0.001953125
        info.epsilon = 0.0625
    }
    return info
}

// ===================== Tensor with Precision Metadata =====================

struct mp_tensor {
    []double data           // Always stored as float64 in S language
    []int shape             // Tensor shape
    int storage_dtype       // Actual storage precision (BF16/FP16)
    int compute_dtype       // Precision used for computations (FP32)
    int numel               // Number of elements
    bool requires_grad
}

func make_mp_tensor([]double data, []int shape, int storage_dtype) mp_tensor {
    mp_tensor t
    t.data = data
    t.shape = shape
    t.storage_dtype = storage_dtype
    t.compute_dtype = PRECISION_FP32
    
    int n = 1
    int i = 0
    while i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    t.numel = n
    t.requires_grad = false
    return t
}

// ===================== Loss Scaling =====================
//
// Loss scaling prevents gradient underflow when using low-precision
// arithmetic (FP16/BF16). The loss is multiplied by a large scale factor
// before backward pass; gradients are divided by the same factor afterward.
//
// Strategies:
//   Static:   Fixed scale factor (simple but may overflow or underflow)
//   Dynamic:  Automatically adjust scale to avoid overflow (recommended)

int LOSS_SCALE_STATIC = 0
int LOSS_SCALE_DYNAMIC = 1

struct loss_scaler_state {
    int scale_strategy          // STATIC or DYNAMIC
    double current_scale        // Current loss scale value
    double max_scale            // Upper bound (e.g., 2+24 for FP16)
    double min_scale            // Lower bound (e.g., 1.0)
    int growth_factor_num       // Numerator for growth: scale *= growth_factor after N consecutive non-overflows
    int growth_factor_interval  // Denominator / interval: consecutive steps without overflow
    int backoff_factor_num      // Numerator for backoff: scale /= backoff on overflow
    int backoff_factor_denom    // Denominator for backoff
    int consecutive_good_steps  // Count of steps since last overflow
    int total_inf_or_nan_grads  // Total number of overflow events
    bool found_overflow         // Whether current step has overflow
}

func new_loss_scaler_static(double init_scale) loss_scaler_state {
    loss_scaler_state s
    s.scale_strategy = LOSS_SCALE_STATIC
    s.current_scale = init_scale
    s.max_scale = init_scale
    s.min_scale = init_scale
    s.growth_factor_num = 2
    s.growth_factor_interval = 2000
    s.backoff_factor_num = 1
    s.backoff_factor_denom = 2
    s.consecutive_good_steps = 0
    s.total_inf_or_nan_grads = 0
    s.found_overflow = false
    return s
}

func new_loss_scaler_dynamic(double init_scale, double max_scale) loss_scaler_state {
    loss_scaler_state s
    s.scale_strategy = LOSS_SCALE_DYNAMIC
    s.current_scale = init_scale
    s.max_scale = max_scale
    s.min_scale = 1.0
    s.growth_factor_num = 2
    s.growth_factor_interval = 2000
    s.backoff_factor_num = 1
    s.backoff_factor_denom = 2
    s.consecutive_good_steps = 0
    s.total_inf_or_nan_grads = 0
    s.found_overflow = false
    return s
}

// Check if any gradient values are Inf or NaN (overflow detection)
func check_gradients_for_overflow(mp_tensor grad_tensor) bool {
    bool has_overflow = false
    int i = 0
    while i < grad_tensor.numel {
        double v = grad_tensor.data[i]
        // Check for Inf
        if v > 1e30 || v < -1e30 {  // Simplified Inf check
            has_overflow = true
        }
        // Check for NaN (NaN != NaN)
        if !(v == v) {
            has_overflow = true
        }
        i = i + 1
    }
    return has_overflow
}

// Scale the loss before backward pass
func scale_loss(loss_scaler_state scaler, double loss) double {
    return loss * scaler.current_scale
}

// Unscale (divide) gradients after backward pass
func unscale_gradients(loss_scaler_state scaler, ref mp_tensor grad_tensor) {
    int i = 0
    while i < grad_tensor.numel {
        grad_tensor.data[i] = grad_tensor.data[i] / scaler.current_scale
        i = i + 1
    }
}

// Update dynamic loss scaler based on whether overflow occurred
func update_loss_scaler(ref loss_scaler_state scaler, bool had_overflow) {
    if scaler.scale_strategy != LOSS_SCALE_DYNAMIC { return }
    
    if had_overflow {
        // Overflow: reduce scale
        double new_scale = scaler.current_scale * 
                          double(scaler.backoff_factor_num) / double(scaler.backoff_factor_denom)
        if new_scale >= scaler.min_scale {
            scaler.current_scale = new_scale
        }
        scaler.consecutive_good_steps = 0
        scaler.total_inf_or_nan_grads = scaler.total_inf_or_nan_grads + 1
    } else {
        // No overflow: potentially increase scale
        scaler.consecutive_good_steps = scaler.consecutive_good_steps + 1
        if scaler.consecutive_good_steps >= scaler.growth_factor_interval {
            double new_scale = scaler.current_scale * double(scaler.growth_factor_num)
            if new_scale <= scaler.max_scale {
                scaler.current_scale = new_scale
            }
            scaler.consecutive_good_steps = 0
        }
    }
}

// ===================== Master Weight Management =====================
//
// For numerical stability, maintain a full FP32 copy ("master weight")
// of all parameters. Updates are computed in FP32, then downcast to
// lower precision for storage.

struct master_weight_state {
    []double fp32_weights       // Full precision master copy
    []double low_precision_params  // Low precision working copy
    int num_elements
    int storage_precision
}

func create_master_weights([]double initial_params, int storage_precision) master_weight_state {
    master_weight_state state
    state.num_elements = len(initial_params)
    state.storage_precision = storage_precision
    
    // Store FP32 master copy
    state.fp32_weights = []double{cap: state.num_elements}
    int i = 0
    while i < state.num_elements {
        state.fp32_weights[i] = initial_params[i]
        i = i + 1
    }
    
    // Create low-precision working copy (simulated via quantization)
    state.low_precision_params = []double{cap: state.num_elements}
    i = 0
    while i < state.num_elements {
        state.low_precision_params[i] = cast_to_low_precision(initial_params[i], storage_precision)
        i = i + 1
    }
    
    return state
}

// Cast from FP32 to target low precision (simulated)
func cast_to_low_precision(double value, int target_dtype) double {
    if target_dtype == PRECISION_BF16 {
        // BF16: truncate mantissa to 7 bits (keep 8-bit exponent)
        // Simulated: round to ~3 decimal significant figures
        return round_to_significant(value, 3)
    } else if target_dtype == PRECISION_FP16 {
        // FP16: 10-bit mantissa, 5-bit exponent
        // Simulated: round to ~4 decimal significant figures  
        return round_to_significant(value, 4)
    } else if target_dtype == PRECISION_FP8_E4M3 {
        // FP8: very aggressive rounding
        return round_to_significant(value, 2)
    }
    return value
}

// Round to specified number of significant digits
func round_to_significant(double value, int sig_digits) double {
    if value == 0.0 { return 0.0 }
    
    double magnitude = 1.0
    double abs_val = value
    if abs_val < 0.0 { abs_val = -abs_val }
    
    // Find order of magnitude
    while abs_val >= 10.0  magnitude < 1000000000.0 {
        abs_val = abs_val / 10.0
        magnitude = magnitude * 10.0
    }
    while abs_val < 1.0  abs_val > 0.0  magnitude > 0.000000001 {
        abs_val = abs_val * 10.0
        magnitude = magnitude / 10.0
    }
    
    // Round to significant digits
    double multiplier = 1.0
    int d = 0
    while d < sig_digits {
        multiplier = multiplier * 10.0
        d = d + 1
    }
    
    double rounded = value * multiplier / magnitude
    rounded = double(int(rounded + 0.5))  // Simple rounding
    rounded = rounded * magnitude / multiplier
    
    return rounded
}

// Sync master weights from low-precision params (after optimizer step)
func sync_master_from_lp(ref master_weight_state state) {
    int i = 0
    while i < state.num_elements {
        state.fp32_weights[i] = state.low_precision_params[i]  // Upcast is exact for BF16->FP32
        i = i + 1
    }
}

// Get FP32 master weights for optimizer update
func get_fp32_master(master_weight_state state) []double {
    return state.fp32_weights
}

// Update low-precision params from updated master weights
func update_lp_from_master(ref master_weight_state state) {
    int i = 0
    while i < state.num_elements {
        state.low_precision_params[i] = cast_to_low_precision(
            state.fp32_weights[i], state.storage_precision)
        i = i + 1
    }
}

// ===================== Mixed Precision Training State =====================

struct mixed_precision_config {
    int param_storage_dtype       // BF16 recommended
    int gradient_dtype            // BF16 or FP16
    int optimizer_compute_dtype   // Always FP32
    int activation_compute_dtype  // BF16 (forward) / FP32 (loss)
    bool use_loss_scaling
    int loss_scale_init           // Initial static scale (if not dynamic)
    bool use_dynamic_loss_scaling
    bool use_master_weights
    bool enable_autocast
}

struct mixed_precision_training_state {
    mixed_precision_config config
    loss_scaler_state scaler
    []master_weight_state param_master_weights  // Per-parameter-group master weights
    int num_parameter_groups
    double effective_loss_scale
    bool autocast_enabled
}

func new_mixed_precision_state(mixed_precision_config cfg, int total_param_count) mixed_precision_training_state {
    mixed_precision_training_state state
    state.config = cfg
    state.num_parameter_groups = 1  // Simplified
    state.effective_loss_scale = 1.0
    state.autocast_enabled = cfg.enable_autocast
    
    // Initialize loss scaler
    if cfg.use_dynamic_loss_scaling {
        state.scaler = new_loss_scaler_dynamic(65536.0, 2+24)  // Start at 2+16, max 2+24
    } else if cfg.use_loss_scaling {
        state.scaler = new_loss_scaler_static(double(cfg.loss_scale_init))
    }
    
    return state
}

// Recommended configuration for 2T model training
func recommended_2t_mp_config() mixed_precision_config {
    mixed_precision_config cfg
    cfg.param_storage_dtype = PRECISION_BF16       // 2T params: 4TB -> 2TB
    cfg.gradient_dtype = PRECISION_BF16            // Same as storage
    cfg.optimizer_compute_dtype = PRECISION_FP32   // Adam needs FP32
    cfg.activation_compute_dtype = PRECISION_BF16  // Forward activations in BF16
    cfg.use_loss_scaling = false                   // BF16 has enough range (usually)
    cfg.loss_scale_init = 1                        // Not used
    cfg.use_dynamic_loss_scaling = false           // BF16 typically doesn't need it
    cfg.use_master_weights = true                  // Critical for training stability!
    cfg.enable_autocast = true                     // Auto-cast ops between precisions
    return cfg
}

// Configuration for FP16 training (for older GPUs without BF16)
func recommended_2t_fp16_config() mixed_precision_config {
    mixed_precision_config cfg
    cfg.param_storage_dtype = PRECISION_FP16
    cfg.gradient_dtype = PRECISION_FP16
    cfg.optimizer_compute_dtype = PRECISION_FP32
    cfg.activation_compute_dtype = PRECISION_FP16
    cfg.use_loss_scaling = true                    // FP16 NEEDS loss scaling!
    cfg.loss_scale_init = 65536                    // 2+16
    cfg.use_dynamic_loss_scaling = true            // Dynamic is strongly recommended
    cfg.use_master_weights = true
    cfg.enable_autocast = true
    return cfg
}

// ===================== Memory Estimation =====================

struct memory_breakdown {
    double params_memory_gb        // Parameters only
    double gradients_memory_gb     // Gradients only
    double optimizer_memory_gb     // Optimizer states (AdamW: m + v)
    double activations_memory_gb   // Activations (per microbatch)
    double master_weights_gb       // FP32 master copies
    double total_per_gpu_gb        // Total memory per GPU
    double savings_vs_fp32_pct     // Percentage savings vs pure FP32
}

func estimate_mp_memory_usage(
    int total_param_count,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int num_layers,
    mixed_precision_config config,
    int world_size) memory_breakdown {
    
    memory_breakdown mb
    
    dtype_info param_dt = get_dtype_info(config.param_storage_dtype)
    dtype_info grad_dt = get_dtype_info(config.gradient_dtype)
    dtype_info opt_dt = get_dtype_info(config.optimizer_compute_dtype)
    
    double p = double(total_param_count)
    
    // Parameter memory (sharded by world_size for distributed)
    mb.params_memory_gb = p * double(param_dt.byte_size) / double(world_size) / (1024+3)
    
    // Gradient memory (same precision as params usually)
    mb.gradients_memory_gb = p * double(grad_dt.byte_size) / double(world_size) / (1024+3)
    
    // Optimizer state: AdamW needs m (FP32) + v (FP32) = 2x param size in FP32
    // With master weights enabled: additional FP32 copy
    if config.use_master_weights {
        mb.optimizer_memory_gb = p * double(opt_dt.byte_size) * 2.0 / double(world_size) / (1024+3)
        mb.master_weights_gb = p * double(opt_dt.byte_size) / double(world_size) / (1024+3)
    } else {
        mb.optimizer_memory_gb = p * double(opt_dt.byte_size) * 2.0 / double(world_size) / (1024+3)
        mb.master_weights_gb = 0.0
    }
    
    // Activation memory: rough estimation
    // Per layer: batch * seq_len * hidden * 2 bytes (forward + backward)
    // Times num_layers for full checkpointing
    double per_layer_act = double(batch_size) * double(seq_len) * double(hidden_dim) *
                           double(param_dt.byte_size) / (1024+3)
    mb.activations_memory_gb = per_layer_act * double(num_layers)
    
    // Total
    mb.total_per_gpu_gb = mb.params_memory_gb + mb.gradients_memory_gb + 
                         mb.optimizer_memory_gb + mb.activations_memory_gb +
                         mb.master_weights_gb
    
    // Savings vs pure FP32 (which would be 16P bytes total: 4P params + 4P grads + 8P opt)
    double fp32_total = p * 16.0 / double(world_size) / (1024+3)
    mb.savings_vs_fp32_pct = (1.0 - mb.total_per_gpu_gb / fp32_total) * 100.0
    
    return mb
}
