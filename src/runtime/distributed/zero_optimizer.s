package neurx.distributed.zero

struct zero_config {
    int stage
    bool cpu_offload
    bool overlap_comm
    int partition_size
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
}

struct zero_state {
    []float local_momentum
    []float local_variance
    []float params
    []float grads
    int step
    int partition_id
    int world_size
    int total_params
    int local_param_count
}

func create_zero_config(int stage) zero_config {
    zero_config cfg
    cfg.stage = stage
    cfg.cpu_offload = false
    cfg.overlap_comm = true
    cfg.partition_size = 1000000
    cfg.lr = 0.001
    cfg.beta1 = 0.9
    cfg.beta2 = 0.999
    cfg.eps = 1e-8
    cfg.weight_decay = 0.01
    return cfg
}

func create_zero_state(int total_params, int world_size, int rank) zero_state {
    zero_state state
    state.total_params = total_params
    state.world_size = world_size
    state.partition_id = rank
    state.step = 0
    state.local_param_count = total_params / world_size
    int remainder = total_params - (state.local_param_count * world_size)
    if rank < remainder {
        state.local_param_count = state.local_param_count + 1
    }
    state.local_momentum = []
    state.local_variance = []
    state.params = []
    state.grads = []
    int i = 0
    for i < state.local_param_count {
        state.local_momentum = append(state.local_momentum, 0.0)
        state.local_variance = append(state.local_variance, 0.0)
        i = i + 1
    }
    return state
}

func zero_step(zero_state state, zero_config cfg) zero_state {
    state.step = state.step + 1
    println("[ZeRO-" + int_to_string(cfg.stage) + "] Step " + int_to_string(state.step))
    println("  Rank: " + int_to_string(state.partition_id) + "/" + int_to_string(state.world_size))
    println("  Local params: " + int_to_string(state.local_param_count) + "/" + int_to_string(state.total_params))
    if len(state.grads) != len(state.params) {
        println("[ERROR] Gradient size mismatch")
        return state
    }
    int local_start = compute_local_start(state.total_params, state.world_size, state.partition_id)
    int local_end = local_start + state.local_param_count
    float step_float = float_from_int(state.step)
    float bias_correction1 = 1.0 - pow_approx(cfg.beta1, step_float)
    float bias_correction2 = 1.0 - pow_approx(cfg.beta2, step_float)
    int i = 0
    for i < state.local_param_count {
        int global_idx = local_start + i
        if global_idx >= len(state.grads) {
            i = i + 1
            continue
        }
        float grad = state.grads[global_idx]
        state.local_momentum[i] = cfg.beta1 * state.local_momentum[i] + (1.0 - cfg.beta1) * grad
        state.local_variance[i] = cfg.beta2 * state.local_variance[i] + (1.0 - cfg.beta2) * grad * grad
        float m_hat = state.local_momentum[i] / bias_correction1
        float v_hat = state.local_variance[i] / bias_correction2
        float update = cfg.lr * m_hat / (sqrt_approx(v_hat) + cfg.eps)
        if global_idx < len(state.params) {
            float param_before = state.params[global_idx]
            state.params[global_idx] = param_before - update - cfg.weight_decay * cfg.lr * param_before
        }
        i = i + 1
    }
    println("  ✓ Updated " + int_to_string(state.local_param_count) + " local parameters")
    return state
}

func compute_local_start(int total, int world_size, int rank) int {
    int base_size = total / world_size
    int remainder = total - (base_size * world_size)
    if rank < remainder {
        return rank * (base_size + 1)
    }
    return remainder * (base_size + 1) + (rank - remainder) * base_size
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x / 2.0
    int iterations = 0
    for iterations < 10 {
        guess = (guess + x / guess) / 2.0
        iterations = iterations + 1
    }
    return guess
}

func pow_approx(float base, float exp) float {
    if exp == 0.0 {
        return 1.0
    }
    if exp == 1.0 {
        return base
    }
    float result = 1.0
    int exp_int = int_from_float(exp)
    int i = 0
    for i < exp_int {
        result = result * base
        i = i + 1
    }
    return result
}

func float_from_int(int n) float {
    float result = 0.0
    int i = 0
    for i < n {
        result = result + 1.0
        i = i + 1
    }
    return result
}

func int_from_float(float f) int {
    int result = 0
    float remaining = f
    for remaining >= 1.0 {
        result = result + 1
        remaining = remaining - 1.0
    }
    return result
}

func int_to_string(int n) string {
    if n == 0 { return "0" }
    if n == 1 { return "1" }
    if n == 2 { return "2" }
    if n == 3 { return "3" }
    if n == 4 { return "4" }
    if n == 5 { return "5" }
    if n == 6 { return "6" }
    if n == 7 { return "7" }
    if n == 8 { return "8" }
    if n < 0 {
        return "-" + int_to_string(0 - n)
    }
    string result = ""
    int remaining = n
    for remaining >= 10 {
        int digit = remaining - ((remaining / 10) * 10)
        remaining = remaining / 10
        if digit == 0 { result = "0" + result }
        if digit == 1 { result = "1" + result }
        if digit == 2 { result = "2" + result }
        if digit == 3 { result = "3" + result }
        if digit == 4 { result = "4" + result }
        if digit == 5 { result = "5" + result }
        if digit == 6 { result = "6" + result }
        if digit == 7 { result = "7" + result }
        if digit == 8 { result = "8" + result }
        if digit == 9 { result = "9" + result }
    }
    if remaining == 0 { result = "0" + result }
    if remaining == 1 { result = "1" + result }
    if remaining == 2 { result = "2" + result }
    if remaining == 3 { result = "3" + result }
    if remaining == 4 { result = "4" + result }
    if remaining == 5 { result = "5" + result }
    if remaining == 6 { result = "6" + result }
    if remaining == 7 { result = "7" + result }
    if remaining == 8 { result = "8" + result }
    if remaining == 9 { result = "9" + result }
    return result
}

func print_zero_memory_stats(zero_state state) {
    int momentum_bytes = len(state.local_momentum) * 4
    int variance_bytes = len(state.local_variance) * 4
    int total_bytes = momentum_bytes + variance_bytes
    println("\n[ZeRO Memory Statistics]")
    println("  Local momentum: " + int_to_string(len(state.local_momentum)) + " params (" + int_to_string(momentum_bytes) + " bytes)")
    println("  Local variance: " + int_to_string(len(state.local_variance)) + " params (" + int_to_string(variance_bytes) + " bytes)")
    println("  Total optimizer state: " + int_to_string(total_bytes) + " bytes")
    if state.world_size > 1 {
        int full_optimizer_bytes = state.total_params * 4 * 2
        float memory_ratio = float_from_int(total_bytes) / float_from_int(full_optimizer_bytes)
        println("  Memory saving: " + int_to_string(int_from_float(memory_ratio * 100.0)) + "% vs full replication")
    }
}
