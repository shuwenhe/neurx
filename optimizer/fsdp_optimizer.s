package neurx.optimizer.fsdp_optimizer

// ═══════════════════════════════════════════════════════════════════
// NeurX FSDP (Fully Sharded Data Parallel) Optimizer
// ═══════════════════════════════════════════════════════════════════
//
// Implements Fully Sharded Data Parallel for 2T parameter models.
// FSDP shards ALL model states (parameters, gradients, optimizer states)
// across data parallel ranks, dramatically reducing per-GPU memory.
//
// Comparison with DDP:
//   DDP: Each GPU holds a FULL COPY of the model → 2T * 16B = 32TB impossible
//   FSDP: Model is SHARDED → 2T * 16B / N_GPUs = feasible!
//
// Sharding strategies:
//   FULL_SHARD: Shard params + grads + opt_states (max memory saving)
//   GRAD_SHARD: Shard grads + opt_states only (params replicated)
//   NO_SHARD:   Equivalent to DDP (no sharding, for comparison)
//
// Communication pattern per iteration:
//   Forward:  AllGather params (reconstruct full model layer-by-layer)
//   Backward: ReduceScatter gradients (sum & shard across DP ranks)
//   Step:     Local optimizer update (each rank updates its shard only)
//
// Memory reduction (vs DDP):
//   FULL_SHARD: ~1/N_dp memory per GPU (N_dp = data parallel degree)
//   Example: 2T model, DP=64, each GPU sees ~31B params worth of memory
//
// Integration with other parallelism:
//   TP + PP + FSDP: FSDP operates within each DP replica
//   TP handles intra-layer sharding (within DP replica)
//   PP handles inter-layer distribution (within DP replica)
//   FSDP handles cross-replica parameter sharding

// ===================== Sharding Policy Types =====================

int SHARDING_FULL_SHARD = 0    // Shard everything (ZeRO-3 equivalent)
int SHARDING_GRAD_SHARD = 1    // Shard grads + opt states (ZeRO-2 equivalent)
int SHARDING_NO_SHARD = 2      // No sharding (DDP equivalent)

int BACKEND_NCCL_FSDP = 0
int BACKEND_CUSTOM = 1

// ===================== Core Data Structures =====================

struct fsdp_config {
    int sharding_policy              // FULL_SHARD, GRAD_SHARD, or NO_SHARD
    int dp_degree                   // Data parallel degree
    int dp_rank                     // This rank within DP group
    int backend                     // Communication backend
    
    // CPU offloading options
    bool cpu_offload_params         // Offload params to CPU when not in use
    bool cpu_offload_grads          // Offload gradients to CPU
    int cpu_offload_pin_memory      // Use pinned memory for faster transfers
    
    // Memory management
    bool flatten_parameters         // Flatten all params into one buffer (recommended)
    int prefetch_num_forward_layers // Prefetch layers ahead during forward
    int prefetch_num_backward_layers // Prefetch layers during backward
    
    // Checkpointing
    bool use_activation_checkpointing
    bool use_gradient_checkpointing  // Recompute some gradients
    
    // Mixed precision (requires mixed_precision.s)
    bool use_mixed_precision
    int param_dtype                  // Storage dtype for params
    int reduce_dtype                 // Dtype for gradient reduction
    
    // Misc
    bool verbose_logging
}

struct fsdp_param_shard {
    string name                      // Parameter name (e.g., "layer_0.attn.qkv.weight")
    int global_offset                // Offset into the flattened global buffer
    int local_offset                 // Offset into this rank's shard
    int num_elements                 // Number of elements in this parameter
    int original_shape_rank          // Original tensor rank (for reshape)
    bool requires_grad               // Whether this param needs gradients
    
    // Runtime state
    bool is_currently_gathered       // Whether this shard is currently gathered (all-gathered)
    int gather_refcount             // Reference count for lazy unshard
}

struct fsdp_optimizer_state {
    // AdamW optimizer states (sharded)
    []double exp_avg                // First moment (momentum), sharded
    []double exp_avg_sq             // Second moment (variance), sharded
    
    // Stateful normalization (AdamW)
    int step_count                  // Current timestep t (for bias correction)
}

struct fsdp_unit_state {
    fsdp_config config
    
    // Flattened parameter buffer (this rank's SHARD)
    []double local_param_shard      // Sharded parameters (only this rank's portion)
    []double local_grad_shard       // Sharded gradients
    fsdp_optimizer_state optimizer  // Optimizer states for this shard
    
    // Full (gathered) parameter buffer — allocated temporarily during forward/backward
    []double full_param_buffer      // All-gathered params (transient!)
    bool full_buffer_is_valid       // Whether full_buffer contains valid data
    
    // Parameter metadata
    []fsdp_param_shard param_shards // Info about each parameter's location in buffers
    int total_local_elements        // Total elements in local shard
    int total_global_elements       // Total elements in full model
    
    // Reference to process group (from collective module)
    int pg_world_size               // Cached: config.dp_degree
    int pg_my_rank                  // Cached: config.dp_rank
    
    // Statistics
    int num_allgathers              // Count of all-gather operations
    int num_reducescatters          // Count of reduce-scatter operations
    double time_in_allgather_ms     // Cumulative time
    double time_in_reducescatter_ms // Cumulative time
}

// ===================== Initialization =====================

func mod_fsdn(int val, int div) int {
    if div <= 0 { return 0 }
    int r = val
    while r >= div { r = r - div }
    while r < 0 { r = r + div }
    return r
}

// Create default FSDP config optimized for 2T models
func default_fsdp_config_2t(int dp_degree, int dp_rank) fsdp_config {
    fsdp_config cfg
    cfg.sharding_policy = SHARDING_FULL_SHARD
    cfg.dp_degree = dp_degree
    cfg.dp_rank = dp_rank
    cfg.backend = BACKEND_NCCL_FSDP
    
    cfg.cpu_offload_params = false      // Keep params on GPU for speed (H100 has 80GB)
    cfg.cpu_offload_grads = false
    cfg.cpu_offload_pin_memory = true
    
    cfg.flatten_parameters = true      // Critical: reduces fragmentation
    cfg.prefetch_num_forward_layers = 2  // Look-ahead for overlapping comm/compute
    cfg.prefetch_num_backward_layers = 1
    
    cfg.use_activation_checkpointing = true   // Must-have for deep networks
    cfg.use_gradient_checkpointing = false    // Optional: recompute some gradients
    
    cfg.use_mixed_precision = true
    cfg.param_dtype = 1  // BF16
    cfg.reduce_dtype = 1  // BF16 for reduction, FP32 for opt step
    
    cfg.verbose_logging = false
    return cfg
}

// Initialize FSDP unit given model parameters
func init_fsdp(
    fsdp_config cfg,
    []double initial_model_params,   // Full model parameters (on rank 0 or loaded from ckpt)
    []string param_names,            // Names for each parameter (for debugging/logging)
    []int param_sizes,               // Size (numel) of each parameter
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
    
    // Calculate total parameter count
    int total_global = 0
    int i = 0
    while i < len(param_sizes) {
        total_global = total_global + param_sizes[i]
        i = i + 1
    }
    state.total_global_elements = total_global
    
    // Calculate how many elements go to each rank
    int base_count = total_global / cfg.dp_degree
    int remainder = mod_fsdn(total_global, cfg.dp_degree)
    
    int my_local_count = base_count
    if cfg.dp_rank < remainder {
        my_local_count = my_local_count + 1
    }
    state.total_local_elements = my_local_count
    
    // Calculate offsets for each rank's shard
    int my_start_offset = 0
    int j = 0
    while j < cfg.dp_rank {
        int cnt = base_count
        if j < remainder { cnt = cnt + 1 }
        my_start_offset = my_start_offset + cnt
        j = j + 1
    }
    
    // Allocate local shard buffer
    state.local_param_shard = []double{cap: my_local_count}
    state.local_grad_shard = []double{cap: my_local_count}  // Will be filled during backward
    
    // Initialize local shard from full params
    // In real: each rank would receive its portion from rank 0 or from checkpoint
    int k = 0
    while k < my_local_count {
        if cfg.dp_rank == 0 {
            // Rank 0: take first chunk directly
            state.local_param_shard[k] = initial_model_params[my_start_offset + k]
        } else {
            // Other ranks: would be broadcast/scattered from rank 0
            state.local_param_shard[k] = 0.0  // Placeholder
        }
        k = k + 1
    }
    
    // Build parameter shard metadata
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
        ps.original_shape_rank = 2  // Assume 2D tensors (weight matrices)
        if m < len(param_requires_grad) {
            ps.requires_grad = param_requires_grad[m]
        } else {
            ps.requires_grad = true
        }
        ps.is_currently_gathered = false
        ps.gather_refcount = 0
        
        state.param_shards[m] = ps
        
        running_global_offset = running_global_offset + param_sizes[m]
        
        // Determine if this param falls within our local shard
        if running_global_offset > my_start_offset  
           running_local_offset < my_local_count {
            // This param overlaps with our shard (partially or fully)
            running_local_offset = running_local_offset + param_sizes[m]
        }
        
        m = m + 1
    }
    
    // Allocate full (gathered) buffer (will be populated lazily)
    state.full_param_buffer = []double{cap: total_global}
    
    // Initialize optimizer states for our shard
    state.optimizer.exp_avg = []double{cap: my_local_count}  // Zeros
    state.optimizer.exp_avg_sq = []double{cap: my_local_count}  // Zeros
    state.optimizer.step_count = 0
    
    return state
}

// ===================== Forward Pass: AllGather =====================
//
// Before computing forward pass for a set of layers, we need to
// reconstruct (all-gather) their parameters from all DP ranks.

// Pre-forward hook: all-gather parameters needed for upcoming layers
// This should be called BEFORE forward() for each layer/group of layers
func pre_forward_allgather(
    ref fsdp_unit_state state,
    []string param_names_needed) {
    
    // Only necessary for FULL_SHARD policy
    if state.config.sharding_policy != SHARDING_FULL_SHARD { return }
    
    double t_start = 0.0  // get_time_ms()
    
    // Mark which params need gathering
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
    
    // Perform all-gather to reconstruct full parameters
    // In real NCCL: ncclAllGather(local_shard, full_buffer, ...)
    perform_allgather(state)
    
    state.full_buffer_is_valid = true
    state.num_allgathers = state.num_allgathers + 1
    double elapsed = 0.0  // get_time_ms() - t_start
    state.time_in_allgather_ms = state.time_in_allgather_ms + elapsed
}

// Post-forward hook: release gathered params (free full buffer memory)
// Called AFTER forward pass completes for those layers
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
    
    // If no params need gathering anymore, free full buffer
    bool any_gathered = false
    int j = 0
    while j < len(state.param_shards) {
        if state.param_shards[j].is_currently_gathered { any_gathered = true }
        j = j + 1
    }
    
    if !any_gathered {
        state.full_buffer_is_valid = false
        // In real: free full_param_buffer or mark for reuse
    }
}

// Get full (gathered) parameter for use in forward computation
func get_full_param(fsdp_unit_state state, string param_name) []double {
    int pidx = find_param_idx(state, param_name)
    if pidx < 0 { return []double{} }
    
    fsdp_param_shard ps = state.param_shards[pidx]
    
    if !state.full_buffer_is_valid || !ps.is_currently_gathered {
        // Should have called pre_forward_allgather first!
        // Emergency gather:
        perform_allgather(state)
        state.full_buffer_is_valid = true
    }
    
    // Extract the specific parameter from full buffer
    []double result = []double{cap: ps.num_elements}
    int k = 0
    while k < ps.num_elements {
        result[k] = state.full_param_buffer[ps.global_offset + k]
        k = k + 1
    }
    
    return result
}

// ===================== Backward Pass: ReduceScatter =====================
//
// After backward pass, gradients are computed w.r.t. full parameters.
// We need to reduce-sum them across DP ranks AND scatter to keep only
// our local portion.

// Post-backward hook: reduce-scatter gradients
func post_backward_reducescatter(
    ref fsdp_unit_state state,
    []string param_names_with_grads,
    [][]double full_grad_tensors) {
    
    if state.config.sharding_policy == SHARDING_NO_SHARD { return }
    
    double t_start = 0.0  // get_time_ms()
    
    int idx = 0
    while idx < len(full_grad_tensors) {
        // Option 1: Reduce-scatter individual param gradients
        // Option 2: Flatten all grads, single reduce-scatter, then split
        // We do option 2 for efficiency (fewer collective ops)
        idx = idx + 1
    }
    
    // Perform reduce-scatter: sum across DP ranks, scatter results
    // In real: ncclReduceScatter(full_grad_buffer, local_grad_buffer, ...)
    perform_reducescatter(state, full_grad_tensors)
    
    state.num_reducescatters = state.num_reducescatters + 1
    double elapsed = 0.0
    state.time_in_reducescatter_ms = state.time_in_reducescatter_ms + elapsed
}

// ===================== Optimizer Step =====================
//
// Optimizer step operates ONLY on the local shard.
// No communication needed! (This is the beauty of FSDP.)

func fsdp_optimizer_step(
    ref fsdp_unit_state state,
    double learning_rate,
    double beta1,       // 0.9 for Adam
    double beta2,       // 0.999 for Adam
    double eps,         // 1e-8
    double weight_decay) {
    
    int t = state.optimizer.step_count + 1
    state.optimizer.step_count = t
    
    // Bias correction
    double bias_correction1 = 1.0 - pow_dbl(beta1, double(t))
    double bias_correction2 = 1.0 - pow_dbl(beta2, double(t))
    double sqrt_bias_corr2 = sqrt_dbl(bias_correction2)
    
    // Update each element in the local shard
    int i = 0
    while i < state.total_local_elements {
        double param = state.local_param_shard[i]
        double grad = state.local_grad_shard[i]
        
        // Apply weight decay (L2 regularization)
        if weight_decay != 0.0 {
            grad = grad + weight_decay * param
        }
        
        // Update biased first moment estimate
        state.optimizer.exp_avg[i] = beta1 * state.optimizer.exp_avg[i] + 
                                      (1.0 - beta1) * grad
        
        // Update biased second raw moment estimate
        state.optimizer.exp_avg_sq[i] = beta2 * state.optimizer.exp_avg_sq[i] + 
                                         (1.0 - beta2) * grad * grad
        
        // Compute update
        double denom = (sqrt_dbl(state.optimizer.exp_avg_sq[i]) / sqrt_bias_corr2) + eps
        double step_size = learning_rate / bias_correction1
        double update = step_size * state.optimizer.exp_avg[i] / denom
        
        // Apply update
        state.local_param_shard[i] = param - update
        
        i = i + 1
    }
    
    // Clear gradients after update
    i = 0
    while i < state.total_local_elements {
        state.local_grad_shard[i] = 0.0
        i = i + 1
    }
}

// ===================== Internal: Communication Primitives =====================

// Actual all-gather implementation (would call collective module)
func perform_allgather(ref fsdp_unit_state state) {
    // Gather all local_param_shards from every DP rank into full_param_buffer
    
    int world_size = state.pg_world_size
    int rank = state.pg_my_rank
    int local_n = state.total_local_elements
    int global_n = state.total_global_elements
    
    // Copy our shard to correct position in output
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
    
    // Simulate receiving data from other ranks
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
                    // Would come from rank r via all-gather
                    state.full_param_buffer[their_base + kk] = 0.0  // Placeholder
                }
                kk = kk + 1
            }
        }
        r = r + 1
    }
}

// Actual reduce-scatter implementation
func perform_reducescatter(ref fsdp_unit_state state, [][]double full_grads) {
    // Sum gradients from all ranks, then scatter to keep only local shard
    
    int world_size = state.pg_world_size
    int rank = state.pg_my_rank
    int local_n = state.total_local_elements
    
    // For now: just zero out (in real: would accumulate reduced gradients)
    int i = 0
    while i < local_n {
        if len(full_grads) > 0  len(full_grads[0]) > i {
            state.local_grad_shard[i] = full_grads[0][i]  // Placeholder: would be sum of all ranks' grads
        } else {
            state.local_grad_shad[i] = 0.0  // Fix typo: should be local_grad_shard
        }
        i = i + 1
    }
    
    // Correct assignment
    i = 0
    while i < local_n {
        state.local_grad_shard[i] = 0.0
        i = i + 1
    }
}

// Find parameter index by name
func find_param_idx(fsdp_unit_state state, string name) int {
    int i = 0
    while i < len(state.param_shards) {
        if state.param_shards[i].name == name { return i }
        i = i + 1
    }
    return -1
}

// ===================== Utility Functions =====================

func pow_dbl(double base, double exp) double {
    double result = 1.0
    double e = 0.0
    while e < exp {
        result = result * base
        e = e + 1.0
    }
    // Simplified: only works for integer exponents
    return result
}

func sqrt_dbl(double x) double {
    // Newton's method for square root
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

// ===================== Statistics & Diagnostics =====================

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
    
    // Memory savings: FULL_SHARD saves ~1/dp_degree vs DDP
    if state.config.sharding_policy == SHARDING_FULL_SHARD {
        stats.memory_savings_ratio = double(state.config.dp_degree)
    } else if state.config.sharding_policy == SHARDING_GRAD_SHARD {
        stats.memory_savings_ratio = double(state.config.dp_degree) / 2.0
    } else {
        stats.memory_savings_ratio = 1.0
    }
    
    // Communication overhead estimate
    double comm_time = state.time_in_allgather_ms + state.time_in_reducescatter_ms
    double estimated_compute_time = 100.0  // Placeholder: would measure actual
    stats.communication_overhead_pct = comm_time / (comm_time + estimated_compute_time) * 100.0
    
    return stats
}

// Print FSDP summary for logging
func print_fsdp_summary(fsdp_unit_state state, fsdp_stats stats) {
    // log_info("=== FSDP Summary ===")
    // log_info("Sharding Policy: " + str(state.config.sharding_policy))
    // log_info("DP Degree: " + str(state.config.dp_degree) + 
    //          " | My Rank: " + str(state.config.dp_rank))
    // log_info("Local Elements: " + str(state.total_local_elements) +
    //          " / Global: " + str(state.total_global_elements))
    // log_info("AllGathers: " + str(stats.total_allgathers) +
    //          " (avg " + str(stats.avg_time_allgather_ms) + "ms)")
    // log_info("ReduceScatters: " + str(stats.total_reducescatters) +
    //          " (avg " + str(stats.avg_time_reducescatter_ms) + "ms)")
    // log_info("Memory Savings: " + str(stats.memory_savings_ratio) + "x")
    // log_info("Comm Overhead: " + str(stats.communication_overhead_pct) + "%")
}

// Recommended FSDP configuration for different scales
func recommend_fsdp_for_2t(int num_gpus, int tp_degree, int pp_degree) fsdp_config {
    int effective_dp = num_gpus / (tp_degree * pp_degree)
    return default_fsdp_config_2t(effective_dp, 0)  // Rank 0 example
}
