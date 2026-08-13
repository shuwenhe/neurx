package neurx.optimizer.zero_optimizer
struct zero_optimizer_config {
    int zero_stage
    int dp_degree
    int dp_rank
    []int dp_group
    bool use_cpu_offload
    int memory_limit_mb
    bool use_gradient_accumulation
}
struct zero_stage_1_state {
    int local_param_count
    []float local_params
    []float local_m
    []float local_v
    []float local_param_grads
    int step
}
struct zero_stage_2_state {
    zero_stage_1_state stage_1
    []float gradient_buffer
    int gradient_buffer_size
}
struct zero_stage_3_state {
    zero_stage_2_state stage_2
}
func zero_mod_nonneg(int value, int divisor) int {
    if divisor <= 0 {
        return 0
    }
    int current = value
    while current >= divisor {
        current = current - divisor
    }
    while current < 0 {
        current = current + divisor
    }
    current
}
func new_zero_stage_1_optimizer(
    int total_params,
    int dp_degree,
    int dp_rank) zero_stage_1_state {
    zero_stage_1_state state
    int remainder = zero_mod_nonneg(total_params, dp_degree)
    if dp_rank < remainder {
        state.local_param_count = (total_params / dp_degree) + 1
    } else {
        state.local_param_count = total_params / dp_degree
    }
    state.local_params = []float{cap: state.local_param_count}
    state.local_m = []float{cap: state.local_param_count}
    state.local_v = []float{cap: state.local_param_count}
    state.local_param_grads = []float{cap: state.local_param_count}
    int i = 0
    while i < state.local_param_count {
        state.local_params[i] = 0.0
        state.local_m[i] = 0.0
        state.local_v[i] = 0.0
        state.local_param_grads[i] = 0.0
        i = i + 1
    }
    state.step = 0
    return state
}
func zero_stage_1_all_reduce_grads(
    []float local_grads,
    int local_param_count,
    int dp_degree,
    []int dp_group) []float {
    []float full_grads = []float{cap: len(local_grads)}
    int i = 0
    while i < len(local_grads) {
        full_grads[i] = local_grads[i]
        if dp_degree > 1 {
            full_grads[i] = full_grads[i] / dp_degree
        }
        i = i + 1
    }
    return full_grads
}
func zero_pow(float base, int exp) float {
    float out = 1.0
    int i = 0
    while i < exp {
        out = out * base
        i = i + 1
    }
    return out
}
func zero_sqrt(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x
    int i = 0
    while i < 8 {
        guess = 0.5 * (guess + x / guess)
        i = i + 1
    }
    return guess
}
func zero_stage_1_optimizer_step(
    zero_stage_1_state state,
    []float full_grads,
    float learning_rate,
    float beta1,
    float beta2,
    float epsilon) {
    state.step = state.step + 1
    int param_idx = 0
    while param_idx < state.local_param_count {
        float grad = full_grads[param_idx]
        state.local_m[param_idx] = beta1 * state.local_m[param_idx] + (1.0 - beta1) * grad
        state.local_v[param_idx] = beta2 * state.local_v[param_idx] + (1.0 - beta2) * grad * grad
        float bc1 = 1.0 - zero_pow(beta1, state.step)
        float bc2 = 1.0 - zero_pow(beta2, state.step)
        if bc1 <= 0.0 {
            bc1 = 1.0
        }
        if bc2 <= 0.0 {
            bc2 = 1.0
        }
        float m_hat = state.local_m[param_idx] / bc1
        float v_hat = state.local_v[param_idx] / bc2
        state.local_params[param_idx] = state.local_params[param_idx] - learning_rate * m_hat / (zero_sqrt(v_hat) + epsilon)
        param_idx = param_idx + 1
    }
}
func new_zero_stage_2_optimizer(
    int total_params,
    int dp_degree,
    int dp_rank) zero_stage_2_state {
    zero_stage_2_state state
    state.stage_1 = new_zero_stage_1_optimizer(total_params, dp_degree, dp_rank)
    state.gradient_buffer_size = total_params
    return state
}
func zero_stage_2_reduce_scatter_grads(
    []float full_grads,
    int dp_degree,
    int dp_rank,
    []int dp_group) []float {
    int total_size = len(full_grads)
    int chunk_size = (total_size + dp_degree - 1) / dp_degree
    int start = dp_rank * chunk_size
    int end = start + chunk_size
    if end > total_size {
        end = total_size
    }
    int count = end - start
    if count < 0 {
        count = 0
    }
    []float local_grads = []float{cap: count}
    int i = 0
    while i < count {
        local_grads[i] = full_grads[start + i]
        if dp_degree > 1 {
            local_grads[i] = local_grads[i] / dp_degree
        }
        i = i + 1
    }
    return local_grads
}
func zero_stage_2_optimizer_step(
    zero_stage_2_state state,
    []float local_grads,
    float learning_rate,
    float beta1,
    float beta2,
    float epsilon) {
    state.stage_1.step = state.stage_1.step + 1
    int param_idx = 0
    while param_idx < state.stage_1.local_param_count {
        float grad = local_grads[param_idx]
        state.stage_1.local_m[param_idx] = beta1 * state.stage_1.local_m[param_idx] + (1.0 - beta1) * grad
        state.stage_1.local_v[param_idx] = beta2 * state.stage_1.local_v[param_idx] + (1.0 - beta2) * grad * grad
        float bc1 = 1.0 - zero_pow(beta1, state.stage_1.step)
        float bc2 = 1.0 - zero_pow(beta2, state.stage_1.step)
        if bc1 <= 0.0 {
            bc1 = 1.0
        }
        if bc2 <= 0.0 {
            bc2 = 1.0
        }
        float m_hat = state.stage_1.local_m[param_idx] / bc1
        float v_hat = state.stage_1.local_v[param_idx] / bc2
        state.stage_1.local_params[param_idx] = state.stage_1.local_params[param_idx] - learning_rate * m_hat / (zero_sqrt(v_hat) + epsilon)
        param_idx = param_idx + 1
    }
}
func new_zero_stage_3_optimizer(
    int total_params,
    int dp_degree,
    int dp_rank) zero_stage_3_state {
    zero_stage_3_state state
    state.stage_2 = new_zero_stage_2_optimizer(total_params, dp_degree, dp_rank)
    return state
}
func zero_stage_3_all_gather_params(
    [][]float local_params,
    int dp_degree,
    int dp_rank,
    []int dp_group) []float {
    []float full_params = []float{cap: 0}
    int r = 0
    while r < dp_degree {
        int row = 0
        while row < len(local_params) {
            int i = 0
            while i < len(local_params[row]) {
                full_params.push(local_params[row][i])
                i = i + 1
            }
            row = row + 1
        }
        r = r + 1
    }
    return full_params
}
func zero_stage_3_forward(
    []float input,
    [][]float local_params,
    int dp_degree,
    int dp_rank,
    []int dp_group) []float {
    []float full_params = zero_stage_3_all_gather_params(local_params, dp_degree, dp_rank, dp_group)
    []float output = []float{cap: len(input)}
    int i = 0
    while i < len(input) {
        output[i] = input[i]
        i = i + 1
    }
    return output
}
func zero_stage_3_backward(
    []float output_grad,
    [][]float local_params,
    int dp_degree,
    int dp_rank,
    []int dp_group,
    []float input) []float {
    []float full_params = zero_stage_3_all_gather_params(local_params, dp_degree, dp_rank, dp_group)
    []float input_grad = []float{cap: len(output_grad)}
    int i = 0
    while i < len(output_grad) {
        input_grad[i] = output_grad[i]
        i = i + 1
    }
    []float local_grads = input_grad
    return local_grads
}
func calculate_zero_memory_savings(
    int total_params,
    int dp_degree,
    int zero_stage) float {
    float reduction_factor
    if zero_stage == 1 {
        reduction_factor = 2.0
    } else if zero_stage == 2 {
        reduction_factor = 4.0
    } else {
        reduction_factor = dp_degree
    }
    return reduction_factor
}
func recommended_2t_zero_optimizer() zero_optimizer_config {
    zero_optimizer_config cfg
    cfg.zero_stage = 3
    cfg.dp_degree = 4
    cfg.use_cpu_offload = false
    cfg.memory_limit_mb = 80000
    return cfg
}
func recommended_2t_ultra_zero_optimizer() zero_optimizer_config {
    zero_optimizer_config cfg
    cfg.zero_stage = 3
    cfg.dp_degree = 2
    cfg.use_cpu_offload = true
    cfg.memory_limit_mb = 40000
    return cfg
}
struct zero_memory_stats {
    float param_memory
    float grad_memory
    float optimizer_memory
    float activation_memory
    float total_memory
    float memory_reduction_factor
}
func calculate_zero_memory_usage(
    int total_params,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int zero_stage,
    int dp_degree) zero_memory_stats {
    zero_memory_stats stats
    stats.param_memory = total_params * 2.0 / dp_degree / 1024.0
    if zero_stage >= 2 {
        stats.grad_memory = stats.param_memory / dp_degree
    } else {
        stats.grad_memory = stats.param_memory
    }
    if zero_stage >= 1 {
        stats.optimizer_memory = stats.param_memory * 2.0 / dp_degree
    } else {
        stats.optimizer_memory = stats.param_memory * 2.0
    }
    stats.activation_memory = batch_size * seq_len * hidden_dim * 2.0 / 1024.0
    stats.total_memory = stats.param_memory + stats.grad_memory + stats.optimizer_memory + stats.activation_memory
    stats.memory_reduction_factor = calculate_zero_memory_savings(total_params, dp_degree, zero_stage)
    return stats
}
