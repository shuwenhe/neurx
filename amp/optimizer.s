package neurx.amp.optimizer
enum precision_type {
    FP32,
    BF16,
    FP16,
    INT8,
}
structure loss_scale_config {
    initial_scale: float
    max_scale: float
    min_scale: float
    scale_growth_factor: float
    scale_backoff_factor: float
    update_interval: int
    consecutive_overflows: int
}
structure mixed_precision_state {
    compute_precision: precision_type
    accumulator_precision: precision_type
    weight_precision: precision_type
    loss_scale: float
    current_loss_scale: float
    overflow_counter: int
    scale_update_step: int
    total_steps: int
    num_overflow_steps: int
    num_total_steps: int
    average_loss_scale: float
}
structure gradient_overflow_info {
    has_overflow: bool
    overflow_rank: int
    overflow_value: float
    num_overflowing_params: int
}

func new_mixed_precision_state(config: loss_scale_config): mixed_precision_state {
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

func mixed_precision_forward(
        min_scale: 1.0,
        scale_growth_factor: 2.0,
        scale_backoff_factor: 0.5,
        update_interval: 2000,
        consecutive_overflows: 2
    }
}

func mixed_precision_forward(
    layer_fn: func(vector): vector,
    inputs: vector,
    state: mixed_precision_state
): vector {
    var fp32_inputs: vector = inputs
    var bf16_inputs: vector = convert_to_precision(fp32_inputs, state.compute_precision)
    var bf16_output: vector = layer_fn(bf16_inputs)
    var fp32_output: vector = convert_to_precision(bf16_output, FP32)
    return fp32_output
}

func compute_scaled_loss(
    loss: float,
    state: mixed_precision_state
): float {
    return loss * state.current_loss_scale
}

func backward_pass_with_unscaling(
    grad_loss: float,
    gradients: vector,
    state: mixed_precision_state
): vector {
    var unscaled_grad_loss: float = grad_loss / state.current_loss_scale
    var unscaled_gradients: vector = allocate_vector(length(gradients), 0.0)
    for i in range(0, length(gradients)) {
        unscaled_gradients[i] = gradients[i] / state.current_loss_scale
    }
    return unscaled_gradients
}

func check_gradient_overflow(gradients: vector, num_ranks: int, rank: int): gradient_overflow_info {
    var info: gradient_overflow_info
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
    var global_overflow: bool = has_global_overflow(info.has_overflow, num_ranks, rank)
    if global_overflow {
        info.has_overflow = true
        info.overflow_rank = find_overflow_rank(rank)
    }
    return info
}

func update_loss_scale(
    state: mixed_precision_state,
    overflow_info: gradient_overflow_info,
    config: loss_scale_config
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
    optimizer: vector,
    params: vector,
    gradients: vector,
    learning_rate: float,
    state: mixed_precision_state,
    config: loss_scale_config
): vector {
    var clipped_gradients: vector = clip_gradients_by_norm(gradients, 1.0)
    var updated_params: vector = adamw_step(
        params, clipped_gradients, optimizer,
        learning_rate,
        0.9, 0.999, 1e-8, 0.01
    )
    var bf16_params: vector = convert_to_precision(updated_params, state.weight_precision)
    return convert_to_precision(bf16_params, FP32)
}

func mixed_precision_training_step(
    model_forward: func(vector): vector,
    compute_loss_func: func(vector, vector): float,
    targets: vector,
    inputs: vector,
    params: vector,
    optimizer_state: vector,
    learning_rate: float,
    state: mixed_precision_state,
    config: loss_scale_config
): (vector, float, bool) {
    var bf16_inputs: vector = convert_to_precision(inputs, BF16)
    var bf16_params: vector = convert_to_precision(params, BF16)
    var predictions: vector = model_forward(bf16_inputs)
    var fp32_predictions: vector = convert_to_precision(predictions, FP32)
    var loss: float = compute_loss_func(fp32_predictions, targets)
    var scaled_loss: float = loss * state.current_loss_scale
    var gradients: vector = mixed_precision_backward_pass(scaled_loss, params)
    var unscaled_gradients: vector = allocate_vector(length(gradients), 0.0)
    for i in range(0, length(gradients)) {
        unscaled_gradients[i] = gradients[i] / state.current_loss_scale
    }
    var overflow_info: gradient_overflow_info = check_gradient_overflow(unscaled_gradients, 1, 0)
    var should_skip_update: bool = overflow_info.has_overflow
    update_loss_scale(state, overflow_info, config)
    var updated_params: vector = params
    if !should_skip_update {
        updated_params = mixed_precision_optimizer_step(
            optimizer_state, params, unscaled_gradients,
            learning_rate, state, config
        )
    }
    return (updated_params, loss, overflow_info.has_overflow)
}

func distributed_gradient_sync(
    gradients: vector,
    num_ranks: int,
    rank: int,
    state: mixed_precision_state
): vector {
    var local_overflow: bool = false
    for i in range(0, length(gradients)) {
        if is_nan(gradients[i]) || is_inf(gradients[i]) {
            local_overflow = true
            break
        }
    }
    var synced_gradients: vector = all_reduce_avg(gradients, num_ranks, rank)
    if state.weight_precision == BF16 {
        synced_gradients = convert_to_precision(synced_gradients, BF16)
    }
    return synced_gradients
}

func convert_to_precision(tensor: vector, target_precision: precision_type): vector {
    var result: vector = allocate_vector(length(tensor), 0.0)
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

func round_to_bf16(val: float): float {
    var bf16_bits: int = float_to_bits(val)
    var rounded_bits: int = bf16_bits >> 16
    return bits_to_float(rounded_bits << 16)
}

func round_to_fp16(val: float): float {
    var fp32_bits: int = float_to_bits(val)
    var rounded_bits: int = fp32_bits >> 16
    return bits_to_float(rounded_bits << 16)
}

func compute_mixed_precision_memory_savings(
    param_count: int,
    optimizer_state_count: int,
    use_bf16: bool,
    use_gradient_checkpointing: bool
): (float, float) {
    var fp32_param_memory: float = float(param_count) * 4.0 / (1024 * 1024 * 1024)
    var fp32_grad_memory: float = float(param_count) * 4.0 / (1024 * 1024 * 1024)
    var fp32_optimizer_memory: float = float(optimizer_state_count) * 4.0 / (1024 * 1024 * 1024)
    var fp32_total: float = fp32_param_memory + fp32_grad_memory + fp32_optimizer_memory
    var mixed_param_memory: float = float(param_count) * 2.0 / (1024 * 1024 * 1024)
    var mixed_grad_memory: float = float(param_count) * 2.0 / (1024 * 1024 * 1024)
    var mixed_optimizer_memory: float = fp32_optimizer_memory
    var mixed_total: float = mixed_param_memory + mixed_grad_memory + mixed_optimizer_memory
    if use_gradient_checkpointing {
        mixed_grad_memory = mixed_grad_memory * 0.1
    }
    var memory_saved: float = fp32_total - mixed_total
    var speedup: float = fp32_total / mixed_total
    return (memory_saved, speedup)
}

func estimate_throughput_improvement(
    fp32_throughput: float,
    use_bf16: bool,
    use_flash_attention: bool
): float {
    var throughput_multiplier: float = 1.0
    if use_bf16 {
        throughput_multiplier = throughput_multiplier * 1.9
    }
    if use_flash_attention {
        throughput_multiplier = throughput_multiplier * (0.75 * 1.0 + 0.25 * 3.0)
    }
    return fp32_throughput * throughput_multiplier
}

func clip_gradients_by_norm(gradients: vector, max_norm: float): vector {
    var norm_sq: float = 0.0
    for i in range(0, length(gradients)) {
        norm_sq = norm_sq + gradients[i] * gradients[i]
    }
    var norm: float = sqrt(norm_sq)
    var clip_factor: float = 1.0
    if norm > max_norm {
        clip_factor = max_norm / norm
    }
    var clipped: vector = allocate_vector(length(gradients), 0.0)
    for i in range(0, length(gradients)) {
        clipped[i] = gradients[i] * clip_factor
    }
    return clipped
}

func adamw_step(
    params: vector, gradients: vector, optimizer_state: vector,
    learning_rate: float,
    beta1: float, beta2: float, eps: float, weight_decay: float
): vector {
    var updated_params: vector = allocate_vector(length(params), 0.0)
    var m: vector = get_first_half(optimizer_state)
    var v: vector = get_second_half(optimizer_state)
    var step: int = 1
    var bias_correction1: float = 1.0 - pow(beta1, float(step))
    var bias_correction2: float = 1.0 - pow(beta2, float(step))
    for i in range(0, length(params)) {
        m[i] = beta1 * m[i] + (1.0 - beta1) * gradients[i]
        v[i] = beta2 * v[i] + (1.0 - beta2) * gradients[i] * gradients[i]
        var m_hat: float = m[i] / bias_correction1
        var v_hat: float = v[i] / bias_correction2
        var delta: float = learning_rate * (m_hat / (sqrt(v_hat) + eps))
        updated_params[i] = (params[i] - delta) * (1.0 - learning_rate * weight_decay)
    }
    return updated_params
}

func has_global_overflow(local_overflow: bool, num_ranks: int, rank: int): bool {
    return local_overflow
}

func find_overflow_rank(rank: int): int {
    return rank
}

func all_reduce_avg(gradients: vector, num_ranks: int, rank: int): vector {
    return gradients
}

func is_nan(val: float): bool {
    return val != val
}

func is_inf(val: float): bool {
    return abs(val) > 1e10
}

func mixed_precision_backward_pass(loss: float, params: vector): vector {
    var gradients: vector = allocate_vector(length(params), 0.0)
    if length(params) == 0 {
        return gradients
    }
    var base_scale: float = loss
    if base_scale < 0.0 {
        base_scale = -base_scale
    }
    base_scale = base_scale + 1e-6
    for i in range(0, length(params)) {
        var sign: float = 1.0
        if (i % 2) == 1 {
            sign = -1.0
        }
        gradients[i] = sign * base_scale / float(i + 1)
    }
    gradients
}

func get_first_half(v: vector): vector {
    var mid: int = length(v) / 2
    var result: vector = allocate_vector(mid, 0.0)
    for i in range(0, mid) {
        result[i] = v[i]
    }
    return result
}

func get_second_half(v: vector): vector {
    var mid: int = length(v) / 2
    var result: vector = allocate_vector(length(v) - mid, 0.0)
    for i in range(mid, length(v)) {
        result[i - mid] = v[i]
    }
    return result
}

func float_to_bits(val: float): int {
    var scaled: float = val * 1000000.0
    if scaled < 0.0 {
        scaled = -scaled
    }
    return int(scaled)
}

func bits_to_float(bits: int): float {
    return float(bits) / 1000000.0
}

func int_to_string(n: int): string {
    if n == 0 {
        return "0"
    }
    var value: int = n
    var negative: bool = false
    if value < 0 {
        negative = true
        value = 0 - value
    }
    var result: string = ""
    while value > 0 {
        var digit: int = value - (value / 10) * 10
        result = string(digit + 48) + result
        value = value / 10
    }
    if negative {
        result = "-" + result
    }
    return result
}

func float_to_string(value: float): string {
    var whole: int = int(value)
    var frac: float = value - float(whole)
    if frac < 0.0 {
        frac = -frac
    }
    var frac_digits: int = int(frac * 1000.0)
    var frac_str: string = int_to_string(frac_digits)
    while len(frac_str) < 3 {
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

func print_mixed_precision_status(state: mixed_precision_state): void {
    println("Mixed precision state:")
    println("  loss_scale=" + float_to_string(state.current_loss_scale))
    println("  overflow_counter=" + int_to_string(state.overflow_counter))
    println("  total_steps=" + int_to_string(state.total_steps))
    println("  overflow_steps=" + int_to_string(state.num_overflow_steps))
}
