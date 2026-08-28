package neurx.amp.optimizer
    FP32,
    BF16,
    FP16,
    INT8,
}

structure loss_scale_config {
    float initial_scale
    float max_scale
    float min_scale
    float scale_growth_factor
    float scale_backoff_factor
    int update_interval
    int consecutive_overflows
}

structure mixed_precision_state {
    precision_type compute_precision
    precision_type accumulator_precision
    precision_type weight_precision
    float loss_scale
    float current_loss_scale
    int overflow_counter
    int scale_update_step
    int total_steps
    int num_overflow_steps
    int num_total_steps
    float average_loss_scale
}

structure gradient_overflow_info {
    bool has_overflow
    int overflow_rank
    float overflow_value
    int num_overflowing_params
}

func new_mixed_precision_state(loss_scale_config config): mixed_precision_state {
    state := mixed_precision_state
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

func mixed_precision_forward(
        min_scale: 1.0,
        scale_growth_factor: 2.0,
        scale_backoff_factor: 0.5,
        update_interval: 2000,
        consecutive_overflows: 2
    }
}

func mixed_precision_forward(
    func(vector): vector layer_fn,
    vector inputs,
    mixed_precision_state state
): vector {
    fp32_inputs := inputs
    bf16_inputs := convert_to_precision(fp32_inputs, state.compute_precision)
    bf16_output := layer_fn(bf16_inputs)
    fp32_output := convert_to_precision(bf16_output, FP32)
    return fp32_output
}

func compute_scaled_loss(
    float loss,
    mixed_precision_state state
): float {
    return loss * state.current_loss_scale
}

func backward_pass_with_unscaling(
    float grad_loss,
    vector gradients,
    mixed_precision_state state
): vector {
    unscaled_grad_loss := grad_loss / state.current_loss_scale
    unscaled_gradients := allocate_vector(length(gradients), 0.0)
    for i in range(0, length(gradients)) {
        unscaled_gradients[i] = gradients[i] / state.current_loss_scale
    }
    return unscaled_gradients
}

func check_gradient_overflow(vector gradients, int num_ranks, int rank): gradient_overflow_info {
    info := gradient_overflow_info
    info.has_overflow = false
    info.overflow_rank = -1
    info.overflow_value = 0.0
    info.num_overflowing_params = 0
    for i in range(0, length(gradients)) {
        if is_nan(gradients[i]) || is_inf(gradients[i]) {
            info.has_overflow = true
            info.overflow_value = max(info.overflow_value, abs(gradients[i]))
            info.num_overflowing_params = info.num_overflowing_params + 1
        }
    }
    global_overflow := has_global_overflow(info.has_overflow, num_ranks, rank)
    if global_overflow {
        info.has_overflow = true
        info.overflow_rank = find_overflow_rank(rank)
    }
    return info
}

func update_loss_scale(
    mixed_precision_state state,
    gradient_overflow_info overflow_info,
    loss_scale_config config
): void {
    state.scale_update_step = state.scale_update_step + 1
    if overflow_info.has_overflow {
        state.overflow_counter = state.overflow_counter + 1
        state.num_overflow_steps = state.num_overflow_steps + 1
        if state.overflow_counter >= config.consecutive_overflows {
            state.current_loss_scale = state.current_loss_scale * config.scale_backoff_factor
            state.current_loss_scale = max(state.current_loss_scale, config.min_scale)
            state.overflow_counter = 0
        }
    } else {
        state.overflow_counter = 0
        if state.scale_update_step >= config.update_interval {
            state.current_loss_scale = state.current_loss_scale * config.scale_growth_factor
            state.current_loss_scale = min(state.current_loss_scale, config.max_scale)
            state.scale_update_step = 0
        }
    }
    state.total_steps = state.total_steps + 1
    state.num_total_steps = state.num_total_steps + 1
    state.average_loss_scale = (state.average_loss_scale * (state.num_total_steps - 1) + state.current_loss_scale) / float(state.num_total_steps)
}

func mixed_precision_optimizer_step(
    vector optimizer,
    vector params,
    vector gradients,
    float learning_rate,
    mixed_precision_state state,
    loss_scale_config config
): vector {
    clipped_gradients := clip_gradients_by_norm(gradients, 1.0)
    updated_params := adamw_step(
        params, clipped_gradients, optimizer,
        learning_rate,
        0.9, 0.999, 1e-8, 0.01
    )
    bf16_params := convert_to_precision(updated_params, state.weight_precision)
    return convert_to_precision(bf16_params, FP32)
}

func mixed_precision_training_step(
    func(vector): vector model_forward,
    func(vector, vector): float compute_loss_func,
    vector targets,
    vector inputs,
    vector params,
    vector optimizer_state,
    float learning_rate,
    mixed_precision_state state,
    loss_scale_config config
): (vector, float, bool) {
    bf16_inputs := convert_to_precision(inputs, BF16)
    bf16_params := convert_to_precision(params, BF16)
    predictions := model_forward(bf16_inputs)
    fp32_predictions := convert_to_precision(predictions, FP32)
    loss := compute_loss_func(fp32_predictions, targets)
    scaled_loss := loss * state.current_loss_scale
    gradients := mixed_precision_backward_pass(scaled_loss, params)
    unscaled_gradients := allocate_vector(length(gradients), 0.0)
    for i in range(0, length(gradients)) {
        unscaled_gradients[i] = gradients[i] / state.current_loss_scale
    }
    overflow_info := check_gradient_overflow(unscaled_gradients, 1, 0)
    should_skip_update := overflow_info.has_overflow
    update_loss_scale(state, overflow_info, config)
    updated_params := params
    if !should_skip_update {
        updated_params = mixed_precision_optimizer_step(
            optimizer_state, params, unscaled_gradients,
            learning_rate, state, config
        )
    }
    return updated_params, loss, overflow_info.has_overflow
}

func distributed_gradient_sync(
    vector gradients,
    int num_ranks,
    int rank,
    mixed_precision_state state
): vector {
    local_overflow := false
    for i in range(0, length(gradients)) {
        if is_nan(gradients[i]) || is_inf(gradients[i]) {
            local_overflow = true
            break
        }
    }
    synced_gradients := all_reduce_avg(gradients, num_ranks, rank)
    if state.weight_precision == BF16 {
        synced_gradients = convert_to_precision(synced_gradients, BF16)
    }
    return synced_gradients
}

func convert_to_precision(vector tensor, precision_type target_precision): vector {
    result := allocate_vector(length(tensor), 0.0)
    if target_precision == FP32 {
        return tensor
    } else if target_precision == BF16 {
        for i in range(0, length(tensor)) {
            result[i] = round_to_bf16(tensor[i])
        }
    } else if target_precision == FP16 {
        for i in range(0, length(tensor)) {
            result[i] = round_to_fp16(tensor[i])
        }
    }
    return result
}

func round_to_bf16(float val): float {
    bf16_bits := float_to_bits(val)
    rounded_bits := bf16_bits >> 16
    return bits_to_float(rounded_bits << 16)
}

func round_to_fp16(float val): float {
    fp32_bits := float_to_bits(val)
    rounded_bits := fp32_bits >> 16
    return bits_to_float(rounded_bits << 16)
}

func compute_mixed_precision_memory_savings(
    int param_count,
    int optimizer_state_count,
    bool use_bf16,
    bool use_gradient_checkpointing
): (float, float) {
    fp32_param_memory := float(param_count) * 4.0 / (1024 * 1024 * 1024)
    fp32_grad_memory := float(param_count) * 4.0 / (1024 * 1024 * 1024)
    fp32_optimizer_memory := float(optimizer_state_count) * 4.0 / (1024 * 1024 * 1024)
    fp32_total := fp32_param_memory + fp32_grad_memory + fp32_optimizer_memory
    mixed_param_memory := float(param_count) * 2.0 / (1024 * 1024 * 1024)
    mixed_grad_memory := float(param_count) * 2.0 / (1024 * 1024 * 1024)
    mixed_optimizer_memory := fp32_optimizer_memory
    mixed_total := mixed_param_memory + mixed_grad_memory + mixed_optimizer_memory
    if use_gradient_checkpointing {
        mixed_grad_memory = mixed_grad_memory * 0.1
    }
    memory_saved := fp32_total - mixed_total
    speedup := fp32_total / mixed_total
    return memory_saved, speedup
}

func estimate_throughput_improvement(
    float fp32_throughput,
    bool use_bf16,
    bool use_flash_attention
): float {
    throughput_multiplier := 1.0
    if use_bf16 {
        throughput_multiplier = throughput_multiplier * 1.9
    }
    if use_flash_attention {
        throughput_multiplier = throughput_multiplier * (0.75 * 1.0 + 0.25 * 3.0)
    }
    return fp32_throughput * throughput_multiplier
}

func clip_gradients_by_norm(vector gradients, float max_norm): vector {
    norm_sq := 0.0
    for i in range(0, length(gradients)) {
        norm_sq = norm_sq + gradients[i] * gradients[i]
    }
    norm := sqrt(norm_sq)
    clip_factor := 1.0
    if norm > max_norm {
        clip_factor = max_norm / norm
    }
    clipped := allocate_vector(length(gradients), 0.0)
    for i in range(0, length(gradients)) {
        clipped[i] = gradients[i] * clip_factor
    }
    return clipped
}

func adamw_step(
    vector params, vector gradients, vector optimizer_state,
    float learning_rate,
    float beta1, float beta2, float eps, float weight_decay
): vector {
    updated_params := allocate_vector(length(params), 0.0)
    m := get_first_half(optimizer_state)
    v := get_second_half(optimizer_state)
    step := 1
    bias_correction1 := 1.0 - pow(beta1, float(step))
    bias_correction2 := 1.0 - pow(beta2, float(step))
    for i in range(0, length(params)) {
        m[i] = beta1 * m[i] + (1.0 - beta1) * gradients[i]
        v[i] = beta2 * v[i] + (1.0 - beta2) * gradients[i] * gradients[i]
        m_hat := m[i] / bias_correction1
        v_hat := v[i] / bias_correction2
        delta := learning_rate * (m_hat / (sqrt(v_hat) + eps))
        updated_params[i] = (params[i] - delta) * (1.0 - learning_rate * weight_decay)
    }
    return updated_params
}

func has_global_overflow(bool local_overflow, int num_ranks, int rank): bool {
    return local_overflow
}

func find_overflow_rank(int rank): int {
    return rank
}

func all_reduce_avg(vector gradients, int num_ranks, int rank): vector {
    return gradients
}

func is_nan(float val): bool {
    return val != val
}

func is_inf(float val): bool {
    return abs(val) > 1e10
}

func mixed_precision_backward_pass(float loss, vector params): vector {
    gradients := allocate_vector(length(params), 0.0)
    if length(params) == 0 {
        return gradients
    }
    base_scale := loss
    if base_scale < 0.0 {
        base_scale = -base_scale
    }
    base_scale = base_scale + 1e-6
    for i in range(0, length(params)) {
        sign := 1.0
        if (i % 2) == 1 {
            sign = -1.0
        }
        gradients[i] = sign * base_scale / float(i + 1)
    }
    gradients
}

func get_first_half(vector v): vector {
    mid := length(v) / 2
    result := allocate_vector(mid, 0.0)
    for i in range(0, mid) {
        result[i] = v[i]
    }
    return result
}

func get_second_half(vector v): vector {
    mid := length(v) / 2
    result := allocate_vector(length(v) - mid, 0.0)
    for i in range(mid, length(v)) {
        result[i - mid] = v[i]
    }
    return result
}

func float_to_bits(float val): int {
    scaled := val * 1000000.0
    if scaled < 0.0 {
        scaled = -scaled
    }
    return int(scaled)
}

func bits_to_float(int bits): float {
    return float(bits) / 1000000.0
}

func int_to_string(int n): string {
    if n == 0 {
        return "0"
    }
    value := n
    negative := false
    if value < 0 {
        negative = true
        value = 0 - value
    }
    result := ""
    for value > 0 {
        digit := value - (value / 10) * 10
        result = string(digit + 48) + result
        value = value / 10
    }
    if negative {
        result = "-" + result
    }
    return result
}

func float_to_string(float value): string {
    whole := int(value)
    frac := value - float(whole)
    if frac < 0.0 {
        frac = -frac
    }
    frac_digits := int(frac * 1000.0)
    frac_str := int_to_string(frac_digits)
    for len(frac_str) < 3 {
        frac_str = "0" + frac_str
    }
    return int_to_string(whole) + "." + frac_str
}

func recommended_mixed_precision_config_2t(): loss_scale_config {
    return loss_scale_config {
        initial_scale: 65536.0,
        max_scale: 16777216.0,
        min_scale: 1.0,
        scale_growth_factor: 2.0,
        scale_backoff_factor: 0.5,
        update_interval: 2000,
        consecutive_overflows: 2
    }
}

func print_mixed_precision_status(mixed_precision_state state): void {
    println("Mixed precision state:")
    println("  loss_scale=" + float_to_string(state.current_loss_scale))
    println("  overflow_counter=" + int_to_string(state.overflow_counter))
    println("  total_steps=" + int_to_string(state.total_steps))
    println("  overflow_steps=" + int_to_string(state.num_overflow_steps))
}
