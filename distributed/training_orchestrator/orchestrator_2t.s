package neurx.distributed.training_orchestrator

// ═══════════════════════════════════════════════════════════════════
// NeurX 2T Parameter Model Training Orchestrator
// ═══════════════════════════════════════════════════════════════════
//
// Top-level coordinator that integrates ALL distributed strategies
// for training trillion-parameter models on hundreds/thousands of GPUs.
//
// Architecture: 3D Parallelism + FSDP + Mixed Precision
//
// +-------------------------------------------------------------+
// |                    Training Cluster                         |
|                                                             |
|  DP Replica 0 -+                                            |
|  |- TP Group 0 -|                                           |
|  |  |- PP Stage 0 (GPU 0): embedding + Layers 0-9         |
|  |  |- PP Stage 1 (GPU 1): Layers 10-19                   |
|  |  |- ...                                                   |
|  |  +- PP Stage P-1 (GPU P-1): Output Head                 |
|  |                                                           |
|  |- TP Group 1 -|  (DP Replica 1)                           |
|  |  +- Same structure, different data                       |
|  |                                                           |
|  ...                                                         |
|  +- TP Group D-1 (DP Replica D-1)                            |
|                                                             |
|  Each DP replica uses FSDP to shard parameters internally   |
|  Mixed precision: BF16 storage, FP32 master weights         |
|  Loss scaling: Dynamic (if FP16)                             |
|  Optimizer: AdamW (decoupled weight decay)                   |
|                                                             |
|  Total GPUs = TP × PP × DP                                   |
|  Example: 16 × 16 × 2 = 512 GPUs for 2T model              |
+-------------------------------------------------------------+

// ===================== Unified Configuration =====================

struct training_orchestrator_config {
    // Model configuration
    int vocab_size              // Token vocabulary size
    int hidden_dim              // Model hidden dimension (e.g., 16384 for 2T)
    int num_layers              // Number of Transformer layers (e.g., 160)
    int num_attention_heads     // Query attention heads (e.g., 128)
    int num_kv_heads           // KV attention heads for GQA (e.g., 32)
    int intermediate_dim       // FFN intermediate dimension (e.g., 65536)
    int max_seq_len            // Maximum sequence length (e.g., 8192)
    
    // 3D Parallelism dimensions
    int tp_degree               // Tensor parallel degree
    int pp_degree               // Pipeline parallel degree  
    int dp_degree               // Data parallel degree (FSDP replicas)
    
    // Derived
    int world_size              // Total GPUs = TP * PP * DP
    
    // FSDP configuration
    int fsdp_sharding_policy    // FULL_SHARD / GRAD_SHARD
    bool fsdp_cpu_offload
    bool fsdp_flatten_params
    
    // Mixed precision
    bool use_mixed_precision
    int param_dtype             // BF16=1, FP16=2
    int optimizer_dtype         // Always FP32
    bool use_dynamic_loss_scale
    double init_loss_scale
    
    // Training hyperparameters
    double learning_rate
    double weight_decay
    double beta1                // Adam beta1
    double beta2                // Adam beta2
    double epsilon              // Adam epsilon
    int warmup_steps
    int total_training_steps
    int lr_decay_steps
    double min_lr
    string lr_scheduler         // "cosine", "linear", "constant"
    
    // Batch configuration
    int global_batch_size       // Total batch across all DP replicas
    int micro_batch_size        // Per-GPU microbatch (for PP)
    int gradient_accumulation_steps  // Accumulate gradients over N micro-steps
    
    // Sequence/cursor configuration
    int seq_len                 // Training sequence length
    
    // Checkpointing & saving
    string checkpoint_dir
    int save_every_n_steps
    bool save_optimizer_state
    bool async_checkpoint
    
    // Logging & monitoring
    int log_interval
    bool enable_profiling
    bool enable_tensorboard
    
    // Fault tolerance
    bool enable_elastic_training
    int max_retries_per_step
}

struct gpu_topology_entry {
    int global_rank             // 0 .. world_size-1
    int tp_rank                 // 0 .. tp_degree-1
    int pp_rank                 // 0 .. pp_degree-1
    int dp_rank                 // 0 .. dp_degree-1
    int node_id                 // Physical node ID
    int local_gpu_id            // GPU within node
}

struct orchestrator_state {
    training_orchestrator_config config
    
    // Topology mapping: global_rank -> (tp_rank, pp_rank, dp_rank)
    []gpu_topology_entry topology_map
    
    // My identity
    int my_global_rank
    int my_tp_rank
    int my_pp_rank
    int my_dp_rank
    int my_node_id
    int my_local_gpu
    
    // Sub-system states (would be actual module instances)
    object tp_state              // tensor_parallel_v2.tp_v2_state
    object pp_state              // pipeline_parallel_v2.pipeline_state
    object fsdp_state            // fsdp.fsdp_unit_state
    object mp_state              // mixed_precision.mixed_precision_training_state
    object collective_state      // collective.process_group (per group)
    
    // Training progress
    int current_step
    int current_epoch
    double accumulated_loss
    int samples_processed
    double best_validation_loss
    int best_step
    
    // Timing
    double training_start_time_ms
    double last_log_time_ms
    double avg_step_time_ms
    
    // Metrics
    double current_throughput_tokens_sec
    double current_tflops
}

func orch_mod(int v, int d) int {
    if d <= 0 { return 0 }
    int r = v
    while r >= d { r = r - d }
    while r < 0 { r = r + d }
    return r
}

// ===================== Factory: Recommended Configurations =====================

// Production-grade configuration for 2T model on 256 GPUs
func config_2t_256gpus() training_orchestrator_config {
    training_orchestrator_config c
    
    // 2T GPT Architecture
    c.vocab_size = 128000          // Modern LLM vocabularies are large
    c.hidden_dim = 16384
    c.num_layers = 160
    c.num_attention_heads = 128
    c.num_kv_heads = 32            // GQA ratio 4:1
    c.intermediate_dim = 65536     // SwiGLU: 4H for gate+up, H for down
    c.max_seq_len = 8192
    
    // 3D Parallel: 256 GPUs
    c.tp_degree = 16               // Each GPU handles H/TP=1024 dims per head group
    c.pp_degree = 8                // Each stage has 20 layers (160/8)
    c.dp_degree = 2                // 2 FSDP replicas
    c.world_size = 256
    
    // FSDP
    c.fsdp_sharding_policy = 0     // FULL_SHARD (ZeRO-3 equivalent)
    c.fsdp_cpu_offload = false      // H100 80GB should be sufficient per GPU
    c.fsdp_flatten_params = true
    
    // Mixed Precision
    c.use_mixed_precision = true
    c.param_dtype = 1              // BF16
    c.optimizer_dtype = 0          // FP32
    c.use_dynamic_loss_scale = false  // BF16 doesn't need it typically
    c.init_loss_scale = 1.0
    
    // Optimizer: AdamW
    c.learning_rate = 1e-4         // Scaled by sqrt(dp_degree) in some implementations
    c.weight_decay = 0.1           // Standard for LLMs
    c.beta1 = 0.9
    c.beta2 = 0.95                 // Slightly higher than default for stability
    c.epsilon = 1e-8
    c.warmup_steps = 2000
    c.total_training_steps = 500000  // ~1T tokens at GB=2048, SL=8K
    c.lr_decay_steps = c.total_training_steps
    c.min_lr = 1e-5
    c.lr_scheduler = "cosine"
    
    // Batching: 256 GPUs × 2 tokens/GPU/microstep × 4 accum steps = 2048 effective GB
    c.global_batch_size = 2048
    c.micro_batch_size = 1          // Very small due to memory constraints
    c.gradient_accumulation_steps = 4
    c.seq_len = 8192
    
    // Saving
    c.checkpoint_dir = "/checkpoints/neurx_2t"
    c.save_every_n_steps = 1000
    c.save_optimizer_state = true
    c.async_checkpoint = true
    
    // Logging
    c.log_interval = 20
    c.enable_profiling = false
    c.enable_tensorboard = true
    
    // Fault tolerance
    c.enable_elastic_training = true
    c.max_retries_per_step = 3
    
    return c
}

// Ultra-large scale: 512 GPUs
func config_2t_512gpus() training_orchestrator_config {
    training_orchestrator_config c = config_2t_256gpus()
    
    c.world_size = 512
    c.tp_degree = 32               // More aggressive TP
    c.pp_degree = 16               // More pipeline stages
    c.dp_degree = 1                // Single replica (no DP overhead)
    
    c.micro_batch_size = 1
    c.gradient_accumulation_steps = 2
    
    c.save_every_n_steps = 500
    
    return c
}

// Minimal test configuration: simulate 2T on fewer GPUs (for debugging)
func config_2t_debug_8gpus() training_orchestrator_config {
    training_orchestrator_config c = config_2t_256gpus()
    
    c.world_size = 8
    c.tp_degree = 2
    c.pp_degree = 2
    c.dp_degree = 2
    
    c.hidden_dim = 256             // Tiny model for debug (NOT actually 2T!)
    c.num_layers = 4
    c.num_attention_heads = 4
    c.num_kv_heads = 2
    c.intermediate_dim = 1024
    c.vocab_size = 1000
    
    c.micro_batch_size = 2
    c.global_batch_size = 16
    c.seq_len = 256
    
    c.warmup_steps = 10
    c.total_training_steps = 100
    
    c.log_interval = 1
    
    return c
}

// ===================== Initialization =====================

// Initialize the full distributed training system
func init_orchestrator(training_orchestrator_config cfg, int global_rank) orchestrator_state {
    orchestrator_state state
    state.config = cfg
    state.my_global_rank = global_rank
    state.current_step = 0
    state.current_epoch = 0
    state.accumulated_loss = 0.0
    state.samples_processed = 0
    state.best_validation_loss = 1e30
    state.best_step = 0
    state.training_start_time_ms = 0.0  // get_time()
    state.last_log_time_ms = state.training_start_time_ms
    state.avg_step_time_ms = 0.0
    state.current_throughput_tokens_sec = 0.0
    state.current_tflops = 0.0
    
    // Compute topology mapping
    state.topology_map = build_topology(cfg.world_size, cfg.tp_degree, cfg.pp_degree, cfg.dp_degree)
    
    // Extract my position in topology
    gpu_topology_entry my_entry = state.topology_map[global_rank]
    state.my_tp_rank = my_entry.tp_rank
    state.my_pp_rank = my_entry.pp_rank
    state.my_dp_rank = my_entry.dp_rank
    state.my_node_id = my_entry.node_id
    state.my_local_gpu = my_entry.local_gpu_id
    
    // Initialize sub-systems (in order of dependency):
    
    // 1. Process groups for collective communication
    //    - TP group: same dp_rank, same pp_rank, varying tp_rank
    //    - PP group: same dp_rank, same tp_rank, varying pp_rank  
    //    - DP group: same tp_rank, same pp_rank, varying dp_rank
    state.collective_state = init_process_groups(state)
    
    // 2. Tensor Parallel (within DP replica)
    state.tp_state = init_tp_system(state)
    
    // 3. Pipeline Parallel (within DP replica)
    state.pp_state = init_pp_system(state)
    
    // 4. FSDP (across DP replicas)
    state.fsdp_state = init_fsdp_system(state)
    
    // 5. Mixed Precision
    state.mp_state = init_mixed_precision(state)
    
    return state
}

// Build topology map: assign each global_rank to (tp, pp, dp) coordinates
func build_topology(int world_size, int tp, int pp, int dp) []gpu_topology_entry {
    []gpu_topology_entry map = []gpu_topology_entry{cap: world_size}
    
    int gpus_per_node = 8  // Assuming 8 GPUs per node (standard)
    
    int rank = 0
    while rank < world_size {
        // Canonical ordering: TP innermost, then PP, then DP outermost
        // This matches Megatron-LM / DeepSpeed conventions
        int d = rank / (tp * pp)
        int remainder = orch_mod(rank, tp * pp)
        int p = remainder / tp
        int t = orch_mod(remainder, tp)
        
        gpu_topology_entry entry
        entry.global_rank = rank
        entry.tp_rank = t
        entry.pp_rank = p
        entry.dp_rank = d
        entry.node_id = rank / gpus_per_node
        entry.local_gpu_id = orch_mod(rank, gpus_per_node)
        
        map[rank] = entry
        rank = rank + 1
    }
    
    return map
}

// Initialize process groups for collective operations
func init_process_groups(orchestrator_state state) object {
    // Create three separate process groups:
    //
    // TP Group example (TP=4, PP=2, DP=2, rank ordering):
    //   TP group 0 (pp=0,d=0): ranks {0,1,2,3}
    //   TP group 1 (pp=0,d=1): ranks {8,9,10,11}
    //   TP group 2 (pp=1,d=0): ranks {4,5,6,7}
    //   TP group 3 (pp=1,d=1): ranks {12,13,14,15}
    
    // Return placeholder for process groups
    return {}  // Would be actual process group handles
}

// Initialize tensor parallel system
func init_tp_system(orchestrator_state state) object {
    // Create tp_v2_state with proper dimensions
    // This would call into tensor_parallel_v2.s
    return {}
}

// Initialize pipeline parallel system
func init_pp_system(orchestrator_state state) object {
    // Create pipeline_state with proper layer distribution
    // This would call into pipeline_parallel_v2.s
    return {}
}

// Initialize FSDP sharded optimizer
func init_fsdp_system(orchestrator_state state) object {
    // Create fsdp_unit_state with parameter sharding
    // This would call into fsdp_optimizer.s
    return {}
}

// Initialize mixed precision training state
func init_mixed_precision(orchestrator_state state) object {
    // Create mixed_precision_training_state
    // This would call into mixed_precision.s
    return {}
}

// ===================== Main Training Loop =====================

// Execute the complete distributed training loop
func run_training_loop(ref orchestrator_state state) {
    
    training_orchestrator_config cfg = state.config
    int total_steps = cfg.total_training_steps
    int save_interval = cfg.save_every_n_steps
    int log_interval = cfg.log_interval
    
    // Main loop
    int step = 0
    while step < total_steps {
        
        double step_start = 0.0  // get_time()
        
        // === GRADIENT ACCUMULATION LOOP ===
        int accum_step = 0
        double step_loss = 0.0
        while accum_step < cfg.gradient_accumulation_steps {
            
            // 1. Load microbatch data (data loader)
            // microbatch_data = dataloader.get_microbatch(step * grad_accum + accum_step)
            
            // 2. Forward pass through pipeline (handles TP internally)
            // loss_mb = forward_pipeline(pp_state, microbatch_data, tp_state)
            double mb_loss = 0.0  // Placeholder
            
            // 3. Backward pass through pipeline
            // backward_pipeline(pp_state, loss_mb)
            
            // 4. Accumulate loss
            step_loss = step_loss + mb_loss
            
            accum_step = accum_step + 1
        }
        
        // Average loss over accumulation steps
        step_loss = step_loss / double(cfg.gradient_accumulation_steps)
        state.accumulated_loss = state.accumulated_loss + step_loss
        
        // === GRADIENT SYNCHRONIZATION (FSDP) ===
        // Reduce-scatter gradients across DP replicas (if using ZeRO-2/3)
        // Or all-reduce gradients (if using DDP-style)
        // fsdp_reducescatter_gradients(fsdp_state)
        
        // === OPTIMIZER STEP ===
        // Apply updates to sharded parameters
        // Each DP rank updates ONLY its shard
        // adamw_step(fsdp_state, current_lr)
        
        // === LEARNING RATE SCHEDULING ===
        double current_lr = compute_learning_rate(state, step)
        
        // Zero gradients for next step
        // zero_gradients(fsdp_state)
        
        // === LOGGING ===
        double step_end = 0.0  // get_time()
        double step_time = step_end - step_start
        state.avg_step_time_ms = (state.avg_step_time_ms * double(step) + step_time) / double(step + 1)
        
        int tokens_this_step = cfg.global_batch_size * cfg.seq_len
        state.samples_processed = state.samples_processed + cfg.global_batch_size
        state.current_throughput_tokens_sec = double(tokens_this_step) / (step_time / 1000.0)
        
        // TFLOPS estimation: ~8 FLOPs per parameter per token (forward+backward)
        double flops_per_token = 8.0 * 2000000000000.0  // 2T params
        double total_flops = state.current_throughput_tokens_sec * flops_per_token
        state.current_tflops = total_flops / 1e12 / double(cfg.world_size)
        
        if orch_mod(step, log_interval) == 0  state.my_global_rank == 0 {
            log_training_status(state, step, step_loss, current_lr, step_time)
        }
        
        // === CHECKPOINTING ===
        if (save_interval > 0)  (orch_mod(step, save_interval) == 0) {
            save_distributed_checkpoint(state, step)
        }
        
        state.current_step = step + 1
        step = step + 1
    }
    
    // Final checkpoint
    save_distributed_checkpoint(state, total_steps)
    
    // Print final summary
    print_training_summary(state)
}

// ===================== Learning Rate Scheduler =====================

func compute_learning_rate(orchestrator_state state, int step) double {
    training_orchestrator_config cfg = state.config
    
    if step < cfg.warmup_steps {
        // Linear warmup
        return cfg.learning_rate * double(step) / double(cfg.warmup_steps)
    }
    
    if cfg.lr_scheduler == "cosine" {
        // Cosine decay from LR to min_lr
        int decay_steps = step - cfg.warmup_steps
        int total_decay = cfg.lr_decay_steps - cfg.warmup_steps
        double progress = double(decay_steps) / double(total_decay)
        double cosine = (1.0 + cos_double(3.14159265358979 * progress)) / 2.0
        return cfg.min_lr + (cfg.learning_rate - cfg.min_lr) * cosine
    }
    
    if cfg.lr_scheduler == "linear" {
        // Linear decay
        int decay_steps = step - cfg.warmup_steps
        int total_decay = cfg.lr_decay_steps - cfg.warmup_steps
        double progress = double(decay_steps) / double(total_decay)
        return cfg.learning_rate * (1.0 - progress) + cfg.min_lr * progress
    }
    
    // Default: constant
    return cfg.learning_rate
}

func cos_double(double x) double {
    // Taylor series approximation
    double result = 1.0
    double term = 1.0
    double xx = x * x
    int n = 1
    while n <= 12 {
        term = -term * xx / double((2*n-2) * (2*n-1))
        result = result + term
        n = n + 1
    }
    return result
}

// ===================== Logging & Monitoring =====================

func log_training_status(
    orchestrator_state state,
    int step,
    double loss,
    double lr,
    double step_time_ms) {
    
    // Format: [Step XXXXX/XXXXX] Loss=X.XXXX | LR=X.XXXXX | Tok/s=XXXX | TFLOPS=X.X | Mem=XGB | Time=XXXms
    // Also log: GPU util%, network BW, disk I/O if available
    
    double elapsed_s = (0.0 - state.training_start_time_ms) / 1000.0  // Would be real elapsed
    double eta_hours = (elapsed_s / double(step + 1)) * double(state.config.total_training_steps - step - 1) / 3600.0
    
    // log_info("[Step " + pad_int(step, 6) + "/" + pad_int(state.config.total_training_steps, 6) + "] " +
    //          "Loss=" + format_float(loss, 4) + " | " +
    //          "LR=" + format_scientific(lr) + " | " +
    //          "Tok/s=" + format_int(int(state.current_throughput_tokens_sec)) + " | " +
    //          "TFLOPS=" + format_float(state.current_tflops, 1) + " | " +
    //          "Time=" + format_float(step_time_ms, 1) + "ms | " +
    //          "ETA=" + format_float(eta_hours, 1) + "h")
}

func pad_int(int value, int width) string {
    string s = str(value)
    while len(s) < width {
        s = "0" + s
    }
    return s
}

func format_float(double value, int decimals) string {
    // Simplified formatting
    return str(int(value * pow_dbl_o(10.0, decimals)))  // Very simplified
}

func format_scientific(double value) string {
    return str(value)  // Simplified
}

func format_int(int value) string {
    return str(value)
}

// ===================== checkpoint Management =====================

func save_distributed_checkpoint(orchestrator_state state, int step) {
    // Distributed checkpoint saving strategy:
    //
    // Option A (sharded checkpoint): each rank saves its own shard
    //   - Pros: No single point of failure, fast save
    //   - Cons: Complex restore logic, many files
    //
    // Option B (consolidated checkpoint): rank 0 gathers all and saves
    //   - Pros: Simple file structure, easy to load
    //   - Cons: Slow, requires extra memory on rank 0
    //
    // We implement Option A (sharded) for production 2T training:
    
    string ckpt_dir = state.config.checkpoint_dir + "/step_" + str(step)
    
    // Each rank saves:
    //   1. Its FSDP parameter shard (or full params if not using FSDP)
    //   2. Its optimizer state shard
    //   3. Its TP weight partition
    //   4. Its PP layer weights
    //   5. Metadata: step, rng state, config hash
    
    if state.config.async_checkpoint {
        // Spawn background thread for non-blocking save
        // save_async(ckpt_dir, state)
    } else {
        // Blocking save (simpler but stalls training)
        // save_sync(ckpt_dir, state)
    }
    
    // Barrier: ensure all ranks have saved their shards before continuing
    // barrier(state.collective_state.dp_group)
}

// ===================== Summary & Reporting =====================

func print_training_summary(orchestrator_state state) {
    double total_time_h = (0.0 - state.training_start_time_ms) / (1000.0 * 3600.0)
    double avg_loss = state.accumulated_loss / double(state.current_step)
    
    // log_info("")
    // log_info("=" * 60)
    // log_info("TRAINING COMPLETE")
    // log_info("=" * 60)
    // log_info("Total Steps: " + str(state.current_step))
    // log_info("Total Wall Time: " + str(total_time_h) + " hours")
    // log_info("Final Average Loss: " + str(avg_loss))
    // log_info("Best Loss: " + str(state.best_validation_loss) + " @ Step " + str(state.best_step))
    // log_info("Total Samples: " + str(state.samples_processed))
    // log_info("Avg Throughput: " + str(state.current_throughput_tokens_sec) + " tok/s")
    // log_info("Avg TFLOPS/GPU: " + str(state.current_tflops))
    // log_info("checkpoint Dir: " + state.config.checkpoint_dir)
    // log_info("=" * 60)
}

// ===================== Memory Estimator =====================

struct memory_estimate_result {
    double params_per_gpu_gb
    double grads_per_gpu_gb
    double opt_states_per_gpu_gb
    double activations_per_gpu_gb
    double total_per_gpu_gb
    bool fits_in_memory
    string recommendation
}

// Estimate per-GPU memory usage for given configuration
func estimate_memory_usage(training_orchestrator_config cfg) memory_estimate_result {
    memory_estimate_result result
    
    // Parameter count calculation (approximate)
    long_params = (
        cfg.vocab_size * cfg.hidden_dim +                    // embedding
        cfg.num_layers * (
            3 * cfg.hidden_dim * cfg.hidden_dim +            // QKV + O projections
            (2 * cfg.hidden_dim * cfg.intermediate_dim +      // SwiGLU gate+up
             cfg.intermediate_dim * cfg.hidden_dim) +         // Down projection
            3 * cfg.hidden_dim                                // RMSNorm x3
        ) +
        cfg.vocab_size * cfg.hidden_dim                       // LM Head
    )
    
    double p = double(long_params)
    int param_bytes = 2  // BF16
    int grad_bytes = 2   // BF16
    int opt_bytes = 4    // FP32 for Adam states
    int act_bytes = 2    // BF16 activations
    
    // Per-GPU memory (accounting for all parallelism)
    int tp = cfg.tp_degree
    int pp = cfg.pp_degree
    int dp = cfg.dp_degree
    
    // Parameters sharded by TP (column/row parallel) and FSDP (by DP)
    result.params_per_gpu_gb = p * double(param_bytes) / double(tp * dp) / (1048576.0 * 1024.0)
    
    // Gradients sharded similarly (with FSDP)
    result.grads_per_gpu_gb = p * double(grad_bytes) / double(tp * dp) / (1048576.0 * 1024.0)
    
    // Optimizer states: FP32, sharded by DP (not TP—each TP rank needs its own copy)
    result.opt_states_per_gpu_gb = p * double(opt_bytes) * 2.0 / double(dp) / (1048576.0 * 1024.0)
    
    // Activations: depend on sequence length, batch, layers per stage
    // With activation checkpointing: ~2 layers' worth of activations
    int layers_per_stage = cfg.num_layers / pp
    int active_layers = 2  // With checkpointing
    if !true {  // Without checkpointing
        active_layers = layers_per_stage
    }
    double bytes_per_act = double(cfg.micro_batch_size) * double(cfg.seq_len) * 
                          double(cfg.hidden_dim) * double(act_bytes)
    result.activations_per_gpu_gb = bytes_per_act * double(active_layers) / (1048576.0 * 1024.0)
    
    // Total
    result.total_per_gpu_gb = result.params_per_gpu_gb + result.grads_per_gpu_gb +
                              result.opt_states_per_gpu_gb + result.activations_per_gpu_gb
    
    // Check against typical GPU memory (80GB for H100)
    double gpu_memory_gb = 80.0
    result.fits_in_memory = result.total_per_gpu_gb < (gpu_memory_gb * 0.9)  // (10 - (10 / headroom) * headroom)
    
    // Recommendation
    if result.fits_in_memory {
        result.recommendation = "Configuration fits in " + str(gpu_memory_gb) + "GB GPU memory"
    } else {
        double excess = result.total_per_gpu_gb - gpu_memory_gb * 0.9
        result.recommendation = "OVERFLOW by " + str(excess) + " GB. Suggestions: " +
                               "increase TP/PP degrees, enable CPU offload, " +
                               "reduce micro_batch_size, or increase gradient accumulation."
    }
    
    return result
}

func pow_dbl_o(double base, double exp) double {
    double result = 1.0
    int e = 0
    while e < int(exp) {
        result = result * base
        e = e + 1
    }
    return result
}
