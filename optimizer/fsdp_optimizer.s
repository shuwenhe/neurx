package neurx.optimizer.fsdp_optimizer
int SHARDING_FULL_SHARD = 0
int SHARDING_GRAD_SHARD = 1
int SHARDING_NO_SHARD = 2
int BACKEND_NCCL_FSDP = 0
int BACKEND_CUSTOM = 1

struct fsdp_config {
    int sharding_policy
    int dp_degree
    int dp_rank
    int backend
    bool cpu_offload_params
    bool cpu_offload_grads
    int cpu_offload_pin_memory
    bool flatten_parameters
    int prefetch_num_forward_layers
    int prefetch_num_backward_layers
    bool use_activation_checkpointing
    bool use_gradient_checkpointing
    bool use_mixed_precision
    int param_dtype
    int reduce_dtype
    bool verbose_logging
}

struct fsdp_param_shard {
    string name
    int global_offset
    int local_offset
    int num_elements
    int original_shape_rank
    bool requires_grad
    bool is_currently_gathered
    int gather_refcount
}

struct fsdp_optimizer_state {
    []double exp_avg
    []double exp_avg_sq
    int step_count
}

struct fsdp_unit_state {
    fsdp_config config
    []double local_param_shard
    []double local_grad_shard
    fsdp_optimizer_state optimizer
    []double full_param_buffer
    bool full_buffer_is_valid
    []fsdp_param_shard param_shards
    int total_local_elements
    int total_global_elements
    int pg_world_size
    int pg_my_rank
    int num_allgathers
    int num_reducescatters
    double time_in_allgather_ms
    double time_in_reducescatter_ms
}

func mod_fsdn(int val, int div) int {
    if div <= 0 { return 0 }
    int r = val
    while r >= div { r = r - div }
    while r < 0 { r = r + div }
    return r
}

func default_fsdp_config_2t(int dp_degree, int dp_rank) fsdp_config {
    fsdp_config cfg
    cfg.sharding_policy = SHARDING_FULL_SHARD
    cfg.dp_degree = dp_degree
    cfg.dp_rank = dp_rank
    cfg.backend = BACKEND_NCCL_FSDP
    cfg.cpu_offload_params = false
    cfg.cpu_offload_grads = false
    cfg.cpu_offload_pin_memory = true
    cfg.flatten_parameters = true
    cfg.prefetch_num_forward_layers = 2
    cfg.prefetch_num_backward_layers = 1
    cfg.use_activation_checkpointing = true
    cfg.use_gradient_checkpointing = false
    cfg.use_mixed_precision = true
    cfg.param_dtype = 1
    cfg.reduce_dtype = 1
    cfg.verbose_logging = false
    return cfg
}

func init_fsdp(
    fsdp_config cfg,
    []double initial_model_params,
    []string param_names,
    []int param_sizes,
    []bool param_requires_grad) fsdp_unit_state {
    fsdp_unit_state state
    state.config = cfg
    state.pg_world_size = cfg.dp_degree
    state.pg_my_rank = cfg.dp_rank
    state.full_buffer_is_valid = false
    state.num_allgathers = 0
    state.num_reducescatters = 0
    state.time_in_allgather_ms = 0.0
    state.time_in_reducescatter_ms = 0.0
    int total_global = 0
    int i = 0
    while i < len(param_sizes) {
        total_global = total_global + param_sizes[i]
        i = i + 1
    }
    state.total_global_elements = total_global
    int base_count = total_global / cfg.dp_degree
    int remainder = mod_fsdn(total_global, cfg.dp_degree)
    int my_local_count = base_count
    if cfg.dp_rank < remainder {
        my_local_count = my_local_count + 1
    }
    state.total_local_elements = my_local_count
    int my_start_offset = 0
    int j = 0
    while j < cfg.dp_rank {
        int cnt = base_count
        if j < remainder { cnt = cnt + 1 }
        my_start_offset = my_start_offset + cnt
        j = j + 1
    }
    state.local_param_shard = []double{cap: my_local_count}
    state.local_grad_shard = []double{cap: my_local_count}
    int k = 0
    while k < my_local_count {
        if cfg.dp_rank == 0 {
            state.local_param_shard[k] = initial_model_params[my_start_offset + k]
        } else {
            state.local_param_shard[k] = 0.0
        }
        k = k + 1
    }
    state.param_shards = []fsdp_param_shard{cap: len(param_sizes)}
    int running_global_offset = 0
    int running_local_offset = 0
    int m = 0
    while m < len(param_sizes) {
        fsdp_param_shard ps
        ps.name = param_names[m]
        ps.global_offset = running_global_offset
        ps.local_offset = running_local_offset
        ps.num_elements = param_sizes[m]
        ps.original_shape_rank = 2
        if m < len(param_requires_grad) {
            ps.requires_grad = param_requires_grad[m]
        } else {
            ps.requires_grad = true
        }
        ps.is_currently_gathered = false
        ps.gather_refcount = 0
        state.param_shards[m] = ps
        running_global_offset = running_global_offset + param_sizes[m]
        if running_global_offset > my_start_offset
           running_local_offset < my_local_count {
            running_local_offset = running_local_offset + param_sizes[m]
        }
        m = m + 1
    }
    state.full_param_buffer = []double{cap: total_global}
    state.optimizer.exp_avg = []double{cap: my_local_count}
    state.optimizer.exp_avg_sq = []double{cap: my_local_count}
    state.optimizer.step_count = 0
    return state
}

func pre_forward_allgather(
    ref fsdp_unit_state state,
    []string param_names_needed) {
    if state.config.sharding_policy != SHARDING_FULL_SHARD { return }
    double t_start = 0.0
    int idx = 0
    while idx < len(param_names_needed) {
        int pidx = find_param_idx(state, param_names_needed[idx])
        if pidx >= 0 {
            state.param_shards[pidx].is_currently_gathered = true
            state.param_shards[pidx].gather_refcount =
                state.param_shards[pidx].gather_refcount + 1
        }
        idx = idx + 1
    }
    perform_allgather(state)
    state.full_buffer_is_valid = true
    state.num_allgathers = state.num_allgathers + 1
    double elapsed = 0.0
    state.time_in_allgather_ms = state.time_in_allgather_ms + elapsed
}

func post_forward_unshard(
    ref fsdp_unit_state state,
    []string param_names_released) {
    if state.config.sharding_policy != SHARDING_FULL_SHARD { return }
    int idx = 0
    while idx < len(param_names_released) {
        int pidx = find_param_idx(state, param_names_released[idx])
        if pidx >= 0 {
            state.param_shards[pidx].gather_refcount =
                state.param_shards[pidx].gather_refcount - 1
            if state.param_shards[pidx].gather_refcount <= 0 {
                state.param_shards[pidx].is_currently_gathered = false
            }
        }
        idx = idx + 1
    }
    bool any_gathered = false
    int j = 0
    while j < len(state.param_shards) {
        if state.param_shards[j].is_currently_gathered { any_gathered = true }
        j = j + 1
    }
    if !any_gathered {
        state.full_buffer_is_valid = false
    }
}

func get_full_param(fsdp_unit_state state, string param_name) []double {
    int pidx = find_param_idx(state, param_name)
    if pidx < 0 { return []double{} }
    fsdp_param_shard ps = state.param_shards[pidx]
    if !state.full_buffer_is_valid || !ps.is_currently_gathered {
        perform_allgather(state)
        state.full_buffer_is_valid = true
    }
    []double result = []double{cap: ps.num_elements}
    int k = 0
    while k < ps.num_elements {
        result[k] = state.full_param_buffer[ps.global_offset + k]
        k = k + 1
    }
    return result
}

func post_backward_reducescatter(
    ref fsdp_unit_state state,
    []string param_names_with_grads,
    [][]double full_grad_tensors) {
    if state.config.sharding_policy == SHARDING_NO_SHARD { return }
    double t_start = 0.0
    int idx = 0
    while idx < len(full_grad_tensors) {
        idx = idx + 1
    }
    perform_reducescatter(state, full_grad_tensors)
    state.num_reducescatters = state.num_reducescatters + 1
    double elapsed = 0.0
    state.time_in_reducescatter_ms = state.time_in_reducescatter_ms + elapsed
}

func fsdp_optimizer_step(
    ref fsdp_unit_state state,
    double learning_rate,
    double beta1,
    double beta2,
    double eps,
    double weight_decay) {
    int t = state.optimizer.step_count + 1
    state.optimizer.step_count = t
    double bias_correction1 = 1.0 - pow_dbl(beta1, double(t))
    double bias_correction2 = 1.0 - pow_dbl(beta2, double(t))
    double sqrt_bias_corr2 = sqrt_dbl(bias_correction2)
    int i = 0
    while i < state.total_local_elements {
        double param = state.local_param_shard[i]
        double grad = state.local_grad_shard[i]
        if weight_decay != 0.0 {
            grad = grad + weight_decay * param
        }
        state.optimizer.exp_avg[i] = beta1 * state.optimizer.exp_avg[i] +
                                      (1.0 - beta1) * grad
        state.optimizer.exp_avg_sq[i] = beta2 * state.optimizer.exp_avg_sq[i] +
                                         (1.0 - beta2) * grad * grad
        double denom = (sqrt_dbl(state.optimizer.exp_avg_sq[i]) / sqrt_bias_corr2) + eps
        double step_size = learning_rate / bias_correction1
        double update = step_size * state.optimizer.exp_avg[i] / denom
        state.local_param_shard[i] = param - update
        i = i + 1
    }
    i = 0
    while i < state.total_local_elements {
        state.local_grad_shard[i] = 0.0
        i = i + 1
    }
}

func perform_allgather(ref fsdp_unit_state state) {
    int world_size = state.pg_world_size
    int rank = state.pg_my_rank
    int local_n = state.total_local_elements
    int global_n = state.total_global_elements
    int my_base_offset = 0
    int j = 0
    while j < rank {
        int sz = global_n / world_size
        if j < mod_fsdn(global_n, world_size) { sz = sz + 1 }
        my_base_offset = my_base_offset + sz
        j = j + 1
    }
    int k = 0
    while k < local_n {
        if (my_base_offset + k) < global_n {
            state.full_param_buffer[my_base_offset + k] = state.local_param_shard[k]
        }
        k = k + 1
    }
    int r = 0
    while r < world_size {
        if r != rank {
            int their_base = 0
            int jj = 0
            while jj < r {
                int sz = global_n / world_size
                if jj < mod_fsdn(global_n, world_size) { sz = sz + 1 }
                their_base = their_base + sz
                jj = jj + 1
            }
            int their_n = global_n / world_size
            if r < mod_fsdn(global_n, world_size) { their_n = their_n + 1 }
            int kk = 0
            while kk < their_n {
                if (their_base + kk) < global_n {
                    state.full_param_buffer[their_base + kk] = 0.0
                }
                kk = kk + 1
            }
        }
        r = r + 1
    }
}

func perform_reducescatter(ref fsdp_unit_state state, [][]double full_grads) {
    int world_size = state.pg_world_size
    int rank = state.pg_my_rank
    int local_n = state.total_local_elements
    int i = 0
    while i < local_n {
        if len(full_grads) > 0  len(full_grads[0]) > i {
            state.local_grad_shard[i] = full_grads[0][i]
        } else {
            state.local_grad_shad[i] = 0.0
        }
        i = i + 1
    }
    i = 0
    while i < local_n {
        state.local_grad_shard[i] = 0.0
        i = i + 1
    }
}

func find_param_idx(fsdp_unit_state state, string name) int {
    int i = 0
    while i < len(state.param_shards) {
        if state.param_shards[i].name == name { return i }
        i = i + 1
    }
    return -1
}

func pow_dbl(double base, double exp) double {
    double result = 1.0
    double e = 0.0
    while e < exp {
        result = result * base
        e = e + 1.0
    }
    return result
}

func sqrt_dbl(double x) double {
    if x <= 0.0 { return 0.0 }
    double guess = x / 2.0
    int iter = 0
    while iter < 20 {
        double new_guess = (guess + x / guess) / 2.0
        if new_guess == guess { break }
        guess = new_guess
        iter = iter + 1
    }
    return guess
}

struct fsdp_stats {
    double avg_time_allgather_ms
    double avg_time_reducescatter_ms
    int total_allgathers
    int total_reducescatters
    double peak_memory_gb
    double memory_savings_ratio
    double communication_overhead_pct
}

func compute_fsdp_stats(fsdp_unit_state state) fsdp_stats {
    fsdp_stats stats
    stats.total_allgathers = state.num_allgathers
    stats.total_reducescatters = state.num_reducescatters
    if state.num_allgathers > 0 {
        stats.avg_time_allgather_ms = state.time_in_allgather_ms / double(state.num_allgathers)
    }
    if state.num_reducescatters > 0 {
        stats.avg_time_reducescatter_ms = state.time_in_reducescatter_ms / double(state.num_reducescatters)
    }
    if state.config.sharding_policy == SHARDING_FULL_SHARD {
        stats.memory_savings_ratio = double(state.config.dp_degree)
    } else if state.config.sharding_policy == SHARDING_GRAD_SHARD {
        stats.memory_savings_ratio = double(state.config.dp_degree) / 2.0
    } else {
        stats.memory_savings_ratio = 1.0
    }
    double comm_time = state.time_in_allgather_ms + state.time_in_reducescatter_ms
    double estimated_compute_time = 100.0
    stats.communication_overhead_pct = comm_time / (comm_time + estimated_compute_time) * 100.0
    return stats
}

func print_fsdp_summary(fsdp_unit_state state, fsdp_stats stats) {

}

func recommend_fsdp_for_2t(int num_gpus, int tp_degree, int pp_degree) fsdp_config {
    int effective_dp = num_gpus / (tp_degree * pp_degree)
    return default_fsdp_config_2t(effective_dp, 0)
}
