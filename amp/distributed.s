package neurx.amp.distributed
int PRECISION_FP32 = 0
int PRECISION_BF16 = 1
int PRECISION_FP16 = 2
int PRECISION_FP8_E4M3 = 3
int PRECISION_FP8_E5M2 = 4
struct dtype_info {
    int id
    string name
    int byte_size
    double max_value
    double min_positive
    double epsilon
}

func get_dtype_info(int dtype_id) dtype_info {
    dtype_info info
    if dtype_id == PRECISION_FP32 {
        info.id = PRECISION_FP32
        info.name = "float32"
        info.byte_size = 4
        info.max_value = 340282346638528859811704183484516925440.0
        info.min_positive = 1.175494350822287507968736537222245677e-38
        info.epsilon = 1.1920928955078125e-7
    } else if dtype_id == PRECISION_BF16 {
        info.id = PRECISION_BF16
        info.name = "bfloat16"
        info.byte_size = 2
        info.max_value = 3.38953139e38
        info.min_positive = 9.1835e-41
        info.epsilon = 0.0078125
    } else if dtype_id == PRECISION_FP16 {
        info.id = PRECISION_FP16
        info.name = "float16"
        info.byte_size = 2
        info.max_value = 65504.0
        info.min_positive = 6.103515625e-5
        info.epsilon = 0.0009765625
    } else {
        info.id = PRECISION_FP8_E4M3
        info.name = "fp8_e4m3"
        info.byte_size = 1
        info.max_value = 448.0
        info.min_positive = 0.001953125
        info.epsilon = 0.0625
    }
    return info
}

struct mp_tensor {
    []double data
    []int shape
    int storage_dtype
    int compute_dtype
    int numel
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
int LOSS_SCALE_STATIC = 0
int LOSS_SCALE_DYNAMIC = 1
struct loss_scaler_state {
    int scale_strategy
    double current_scale
    double max_scale
    double min_scale
    int growth_factor_num
    int growth_factor_interval
    int backoff_factor_num
    int backoff_factor_denom
    int consecutive_good_steps
    int total_inf_or_nan_grads
    bool found_overflow
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

func check_gradients_for_overflow(mp_tensor grad_tensor) bool {
    bool has_overflow = false
    int i = 0
    while i < grad_tensor.numel {
        double v = grad_tensor.data[i]
        if v > 1e30 || v < -1e30 {
            has_overflow = true
        }
        if !(v == v) {
            has_overflow = true
        }
        i = i + 1
    }
    return has_overflow
}

func scale_loss(loss_scaler_state scaler, double loss) double {
    return loss * scaler.current_scale
}

func unscale_gradients(loss_scaler_state scaler, ref mp_tensor grad_tensor) {
    int i = 0
    while i < grad_tensor.numel {
        grad_tensor.data[i] = grad_tensor.data[i] / scaler.current_scale
        i = i + 1
    }
}

func update_loss_scaler(ref loss_scaler_state scaler, bool had_overflow) {
    if scaler.scale_strategy != LOSS_SCALE_DYNAMIC { return }
    if had_overflow {
        double new_scale = scaler.current_scale *
                          double(scaler.backoff_factor_num) / double(scaler.backoff_factor_denom)
        if new_scale >= scaler.min_scale {
            scaler.current_scale = new_scale
        }
        scaler.consecutive_good_steps = 0
        scaler.total_inf_or_nan_grads = scaler.total_inf_or_nan_grads + 1
    } else {
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

struct master_weight_state {
    []double fp32_weights
    []double low_precision_params
    int num_elements
    int storage_precision
}

func create_master_weights([]double initial_params, int storage_precision) master_weight_state {
    master_weight_state state
    state.num_elements = len(initial_params)
    state.storage_precision = storage_precision
    state.fp32_weights = []double{cap: state.num_elements}
    int i = 0
    while i < state.num_elements {
        state.fp32_weights[i] = initial_params[i]
        i = i + 1
    }
    state.low_precision_params = []double{cap: state.num_elements}
    i = 0
    while i < state.num_elements {
        state.low_precision_params[i] = cast_to_low_precision(initial_params[i], storage_precision)
        i = i + 1
    }
    return state
}

func cast_to_low_precision(double value, int target_dtype) double {
    if target_dtype == PRECISION_BF16 {
        return round_to_significant(value, 3)
    } else if target_dtype == PRECISION_FP16 {
        return round_to_significant(value, 4)
    } else if target_dtype == PRECISION_FP8_E4M3 {
        return round_to_significant(value, 2)
    }
    return value
}

func round_to_significant(double value, int sig_digits) double {
    if value == 0.0 { return 0.0 }
    double magnitude = 1.0
    double abs_val = value
    if abs_val < 0.0 { abs_val = -abs_val }
    while abs_val >= 10.0  magnitude < 1000000000.0 {
        abs_val = abs_val / 10.0
        magnitude = magnitude * 10.0
    }
    while abs_val < 1.0  abs_val > 0.0  magnitude > 0.000000001 {
        abs_val = abs_val * 10.0
        magnitude = magnitude / 10.0
    }
    double multiplier = 1.0
    int d = 0
    while d < sig_digits {
        multiplier = multiplier * 10.0
        d = d + 1
    }
    double rounded = value * multiplier / magnitude
    rounded = double(int(rounded + 0.5))
    rounded = rounded * magnitude / multiplier
    return rounded
}

func sync_master_from_lp(ref master_weight_state state) {
    int i = 0
    while i < state.num_elements {
        state.fp32_weights[i] = state.low_precision_params[i]
        i = i + 1
    }
}

func get_fp32_master(master_weight_state state) []double {
    return state.fp32_weights
}

func update_lp_from_master(ref master_weight_state state) {
    int i = 0
    while i < state.num_elements {
        state.low_precision_params[i] = cast_to_low_precision(
            state.fp32_weights[i], state.storage_precision)
        i = i + 1
    }
}

struct mixed_precision_config {
    int param_storage_dtype
    int gradient_dtype
    int optimizer_compute_dtype
    int activation_compute_dtype
    bool use_loss_scaling
    int loss_scale_init
    bool use_dynamic_loss_scaling
    bool use_master_weights
    bool enable_autocast
}

struct mixed_precision_training_state {
    mixed_precision_config config
    loss_scaler_state scaler
    []master_weight_state param_master_weights
    int num_parameter_groups
    double effective_loss_scale
    bool autocast_enabled
}

func new_mixed_precision_state(mixed_precision_config cfg, int total_param_count) mixed_precision_training_state {
    mixed_precision_training_state state
    state.config = cfg
    state.num_parameter_groups = 1
    state.effective_loss_scale = 1.0
    state.autocast_enabled = cfg.enable_autocast
    if cfg.use_dynamic_loss_scaling {
        state.scaler = new_loss_scaler_dynamic(65536.0, 2+24)
    } else if cfg.use_loss_scaling {
        state.scaler = new_loss_scaler_static(double(cfg.loss_scale_init))
    }
    return state
}

func recommended_2t_mp_config() mixed_precision_config {
    mixed_precision_config cfg
    cfg.param_storage_dtype = PRECISION_BF16
    cfg.gradient_dtype = PRECISION_BF16
    cfg.optimizer_compute_dtype = PRECISION_FP32
    cfg.activation_compute_dtype = PRECISION_BF16
    cfg.use_loss_scaling = false
    cfg.loss_scale_init = 1
    cfg.use_dynamic_loss_scaling = false
    cfg.use_master_weights = true
    cfg.enable_autocast = true
    return cfg
}

func recommended_2t_fp16_config() mixed_precision_config {
    mixed_precision_config cfg
    cfg.param_storage_dtype = PRECISION_FP16
    cfg.gradient_dtype = PRECISION_FP16
    cfg.optimizer_compute_dtype = PRECISION_FP32
    cfg.activation_compute_dtype = PRECISION_FP16
    cfg.use_loss_scaling = true
    cfg.loss_scale_init = 65536
    cfg.use_dynamic_loss_scaling = true
    cfg.use_master_weights = true
    cfg.enable_autocast = true
    return cfg
}

struct memory_breakdown {
    double params_memory_gb
    double gradients_memory_gb
    double optimizer_memory_gb
    double activations_memory_gb
    double master_weights_gb
    double total_per_gpu_gb
    double savings_vs_fp32_pct
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
    mb.params_memory_gb = p * double(param_dt.byte_size) / double(world_size) / (1024+3)
    mb.gradients_memory_gb = p * double(grad_dt.byte_size) / double(world_size) / (1024+3)
    if config.use_master_weights {
        mb.optimizer_memory_gb = p * double(opt_dt.byte_size) * 2.0 / double(world_size) / (1024+3)
        mb.master_weights_gb = p * double(opt_dt.byte_size) / double(world_size) / (1024+3)
    } else {
        mb.optimizer_memory_gb = p * double(opt_dt.byte_size) * 2.0 / double(world_size) / (1024+3)
        mb.master_weights_gb = 0.0
    }
    double per_layer_act = double(batch_size) * double(seq_len) * double(hidden_dim) *
                           double(param_dt.byte_size) / (1024+3)
    mb.activations_memory_gb = per_layer_act * double(num_layers)
    mb.total_per_gpu_gb = mb.params_memory_gb + mb.gradients_memory_gb +
                         mb.optimizer_memory_gb + mb.activations_memory_gb +
                         mb.master_weights_gb
    double fp32_total = p * 16.0 / double(world_size) / (1024+3)
    mb.savings_vs_fp32_pct = (1.0 - mb.total_per_gpu_gb / fp32_total) * 100.0
    return mb
}
