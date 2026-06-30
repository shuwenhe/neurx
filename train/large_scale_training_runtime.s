package neurx.train.large_scale_runtime

// =====================================================================
// Large Scale Training Runtime
// =====================================================================
// This file binds together the major training-capability axes that a
// production LLM trainer needs:
// - distributed data/model parallel layout
// - all-reduce synchronization policy
// - mixed precision / AMP policy
// - checkpoint and recovery policy
// - streaming data pipeline policy
// - monitoring and memory-budget tracking
//
// The implementation is intentionally state-driven so the runtime can be
// wired into the existing training entrypoints incrementally.

// =====================================================================
// Utility helpers
// =====================================================================

func clamp_positive(int value, int fallback) int {
    if value > 0 {
        return value
    }
    fallback
}

func safe_div_int(int numerator, int denominator) int {
    if denominator == 0 {
        return 0
    }
    numerator / denominator
}

func safe_mod_int(int value, int divisor) int {
    if divisor <= 0 {
        return 0
    }
    value - (value / divisor) * divisor
}

func float_from_int(int value) float {
    0.0 + value
}

func min_int(int a, int b) int {
    if a < b {
        return a
    }
    b
}

func max_int(int a, int b) int {
    if a > b {
        return a
    }
    b
}

func max_float(float a, float b) float {
    if a > b {
        return a
    }
    b
}

// =====================================================================
// Runtime configuration
// =====================================================================

struct large_scale_training_config {
    // Model scale
    int vocab_size
    int hidden_dim
    int num_layers
    int num_heads
    int seq_length

    // Batch and data
    int global_batch_size
    int microbatch_size
    int gradient_accumulation_steps
    int dataloader_workers
    bool streaming_dataset
    bool prefetch_batches
    bool deduplicate_samples
    bool quality_filtering

    // Parallelism
    int world_size
    int data_parallel_size
    int tensor_parallel_size
    int pipeline_parallel_size

    // Precision / memory
    bool mixed_precision
    bool use_bf16
    bool use_fp16
    bool gradient_checkpointing
    bool zero_optimization
    string zero_stage

    // Checkpointing / logging
    int checkpoint_interval
    int log_interval
    bool save_optimizer_state
    bool save_scaler_state
    bool save_runtime_state
    int keep_last_n_checkpoints

    // Recovery
    bool fault_tolerance_enabled
    int max_recovery_attempts
    int recovery_timeout_steps
}

func default_large_scale_training_config() large_scale_training_config {
    large_scale_training_config {
        vocab_size: 50257,
        hidden_dim: 4096,
        num_layers: 32,
        num_heads: 32,
        seq_length: 2048,
        global_batch_size: 1024,
        microbatch_size: 4,
        gradient_accumulation_steps: 256,
        dataloader_workers: 8,
        streaming_dataset: true,
        prefetch_batches: true,
        deduplicate_samples: true,
        quality_filtering: true,
        world_size: 8,
        data_parallel_size: 4,
        tensor_parallel_size: 2,
        pipeline_parallel_size: 1,
        mixed_precision: true,
        use_bf16: true,
        use_fp16: false,
        gradient_checkpointing: true,
        zero_optimization: true,
        zero_stage: "zero-3",
        checkpoint_interval: 100,
        log_interval: 10,
        save_optimizer_state: true,
        save_scaler_state: true,
        save_runtime_state: true,
        keep_last_n_checkpoints: 3,
        fault_tolerance_enabled: true,
        max_recovery_attempts: 5,
        recovery_timeout_steps: 200,
    }
}

// =====================================================================
// Parallel layout
// =====================================================================

struct parallel_layout {
    int world_size
    int data_parallel_size
    int tensor_parallel_size
    int pipeline_parallel_size
    int model_parallel_size
    int local_batch_size
    int microbatch_size
    bool data_parallel_enabled
    bool tensor_parallel_enabled
    bool pipeline_parallel_enabled
    bool allreduce_enabled
    bool allgather_enabled
}

func resolve_parallel_layout(large_scale_training_config cfg) parallel_layout {
    int normalized_world = clamp_positive(cfg.world_size, 1)
    int dp = clamp_positive(cfg.data_parallel_size, 1)
    int tp = clamp_positive(cfg.tensor_parallel_size, 1)
    int pp = clamp_positive(cfg.pipeline_parallel_size, 1)

    int product = dp * tp * pp
    if product <= 0 {
        product = 1
    }

    if safe_mod_int(normalized_world, product) != 0 {
        // Prefer shrinking data parallelism first so tensor/pipeline layout stays intact.
        int max_factor = safe_div_int(normalized_world, tp * pp)
        dp = max_int(1, max_factor)
        product = dp * tp * pp
        if safe_mod_int(normalized_world, product) != 0 {
            dp = 1
            tp = 1
            pp = 1
            product = 1
        }
    }

    int local_batch = safe_div_int(cfg.global_batch_size, dp)
    if local_batch < cfg.microbatch_size {
        local_batch = cfg.microbatch_size
    }

    parallel_layout {
        world_size: normalized_world,
        data_parallel_size: dp,
        tensor_parallel_size: tp,
        pipeline_parallel_size: pp,
        model_parallel_size: tp * pp,
        local_batch_size: local_batch,
        microbatch_size: clamp_positive(cfg.microbatch_size, 1),
        data_parallel_enabled: dp > 1,
        tensor_parallel_enabled: tp > 1,
        pipeline_parallel_enabled: pp > 1,
        allreduce_enabled: dp > 1 || tp > 1,
        allgather_enabled: tp > 1 || pp > 1,
    }
}

// =====================================================================
// Precision policy
// =====================================================================

struct precision_policy {
    bool mixed_precision
    string storage_dtype
    string compute_dtype
    string master_weight_dtype
    float loss_scale
    bool autocast_enabled
    bool dynamic_loss_scaling
}

func resolve_precision_policy(large_scale_training_config cfg) precision_policy {
    string storage_dtype = "fp32"
    string compute_dtype = "fp32"
    float loss_scale = 1.0
    bool autocast_enabled = false
    bool dynamic_loss_scaling = false

    if cfg.mixed_precision {
        autocast_enabled = true
        if cfg.use_bf16 {
            storage_dtype = "bf16"
            compute_dtype = "bf16"
            loss_scale = 1.0
            dynamic_loss_scaling = false
        } else if cfg.use_fp16 {
            storage_dtype = "fp16"
            compute_dtype = "fp16"
            loss_scale = 32768.0
            dynamic_loss_scaling = true
        } else {
            storage_dtype = "fp32"
            compute_dtype = "fp32"
            loss_scale = 1.0
        }
    }

    precision_policy {
        mixed_precision: cfg.mixed_precision,
        storage_dtype: storage_dtype,
        compute_dtype: compute_dtype,
        master_weight_dtype: "fp32",
        loss_scale: loss_scale,
        autocast_enabled: autocast_enabled,
        dynamic_loss_scaling: dynamic_loss_scaling,
    }
}

// =====================================================================
// Data pipeline policy
// =====================================================================

struct data_pipeline_policy {
    bool streaming_dataset
    bool prefetch_batches
    bool deduplicate_samples
    bool quality_filtering
    int dataloader_workers
    int read_ahead_batches
    int shard_count
}

func resolve_data_pipeline_policy(large_scale_training_config cfg, parallel_layout layout) data_pipeline_policy {
    int shards = layout.data_parallel_size
    if shards < 1 {
        shards = 1
    }

    data_pipeline_policy {
        streaming_dataset: cfg.streaming_dataset,
        prefetch_batches: cfg.prefetch_batches,
        deduplicate_samples: cfg.deduplicate_samples,
        quality_filtering: cfg.quality_filtering,
        dataloader_workers: clamp_positive(cfg.dataloader_workers, 1),
        read_ahead_batches: 2,
        shard_count: shards,
    }
}

// =====================================================================
// Checkpoint and recovery policy
// =====================================================================

struct checkpoint_policy {
    int checkpoint_interval
    bool save_optimizer_state
    bool save_scaler_state
    bool save_runtime_state
    int keep_last_n_checkpoints
    bool fault_tolerance_enabled
    int max_recovery_attempts
    int recovery_timeout_steps
}

struct recovery_state {
    bool healthy
    bool recovery_needed
    int recovery_attempts
    int last_good_step
    int last_checkpoint_step
    string last_error
}

func resolve_checkpoint_policy(large_scale_training_config cfg) checkpoint_policy {
    checkpoint_policy {
        checkpoint_interval: clamp_positive(cfg.checkpoint_interval, 1),
        save_optimizer_state: cfg.save_optimizer_state,
        save_scaler_state: cfg.save_scaler_state,
        save_runtime_state: cfg.save_runtime_state,
        keep_last_n_checkpoints: clamp_positive(cfg.keep_last_n_checkpoints, 1),
        fault_tolerance_enabled: cfg.fault_tolerance_enabled,
        max_recovery_attempts: clamp_positive(cfg.max_recovery_attempts, 1),
        recovery_timeout_steps: clamp_positive(cfg.recovery_timeout_steps, 1),
    }
}

func new_recovery_state() recovery_state {
    recovery_state {
        healthy: true,
        recovery_needed: false,
        recovery_attempts: 0,
        last_good_step: 0,
        last_checkpoint_step: 0,
        last_error: "",
    }
}

// =====================================================================
// Memory profile
// =====================================================================

struct memory_profile {
    float parameter_gb
    float optimizer_gb
    float activation_gb
    float checkpoint_gb
    float total_gb
    float estimated_savings_gb
    bool within_budget
}

func estimate_param_count(large_scale_training_config cfg) int {
    int embedding_params = cfg.vocab_size * cfg.hidden_dim
    int block_params = cfg.num_layers * cfg.hidden_dim * cfg.hidden_dim * 12
    int output_params = cfg.hidden_dim * cfg.vocab_size
    embedding_params + block_params + output_params
}

func precision_bytes_per_param(string dtype_name) float {
    if dtype_name == "bf16" || dtype_name == "fp16" {
        return 2.0
    }
    if dtype_name == "fp32" {
        return 4.0
    }
    2.0
}

func estimate_memory_profile(large_scale_training_config cfg, parallel_layout layout, precision_policy policy) memory_profile {
    int total_params = estimate_param_count(cfg)
    float param_bytes = float_from_int(total_params) * precision_bytes_per_param(policy.storage_dtype)

    float optimizer_multiplier = 8.0
    if cfg.zero_optimization && layout.data_parallel_size > 1 {
        optimizer_multiplier = optimizer_multiplier / float_from_int(layout.data_parallel_size)
    }

    float optimizer_bytes = float_from_int(total_params) * optimizer_multiplier

    float activation_multiplier = 2.0
    if cfg.gradient_checkpointing {
        activation_multiplier = 0.5
    }
    float activation_bytes = float_from_int(cfg.global_batch_size * cfg.seq_length * cfg.hidden_dim) * activation_multiplier

    float checkpoint_bytes = 0.0
    if cfg.save_optimizer_state {
        checkpoint_bytes = float_from_int(total_params) * 4.0
    }
    if cfg.save_scaler_state {
        checkpoint_bytes = checkpoint_bytes + 1024.0
    }
    if cfg.save_runtime_state {
        checkpoint_bytes = checkpoint_bytes + 4096.0
    }

    float total_bytes = param_bytes + optimizer_bytes + activation_bytes + checkpoint_bytes
    float fp32_baseline_bytes = float_from_int(total_params) * 16.0
    float savings_bytes = fp32_baseline_bytes - total_bytes
    float total_gb = total_bytes / (1024.0 * 1024.0 * 1024.0)

    memory_profile {
        parameter_gb: param_bytes / (1024.0 * 1024.0 * 1024.0),
        optimizer_gb: optimizer_bytes / (1024.0 * 1024.0 * 1024.0),
        activation_gb: activation_bytes / (1024.0 * 1024.0 * 1024.0),
        checkpoint_gb: checkpoint_bytes / (1024.0 * 1024.0 * 1024.0),
        total_gb: total_gb,
        estimated_savings_gb: savings_bytes / (1024.0 * 1024.0 * 1024.0),
        within_budget: total_gb <= 80.0,
    }
}

// =====================================================================
// Runtime state
// =====================================================================

struct large_scale_training_runtime {
    large_scale_training_config config
    parallel_layout layout
    precision_policy precision
    data_pipeline_policy data
    checkpoint_policy checkpoint
    recovery_state recovery
    memory_profile memory

    // Training counters
    int epoch
    int global_step
    int micro_step
    int samples_seen
    int tokens_seen

    // Health / cadence flags
    bool initialized
    bool healthy
    bool should_allreduce
    bool should_checkpoint
    bool should_log
    bool should_recover

    // Monitoring counters
    float last_loss
    float best_loss
    int best_step
    float running_loss
    int running_steps

    // Memory optimization toggles
    bool gradient_checkpointing_enabled
    bool zero_sharding_enabled
    bool tensor_parallel_enabled
    bool pipeline_parallel_enabled
}

func init_large_scale_training_runtime(large_scale_training_config cfg) large_scale_training_runtime {
    parallel_layout layout = resolve_parallel_layout(cfg)
    precision_policy precision = resolve_precision_policy(cfg)
    data_pipeline_policy data = resolve_data_pipeline_policy(cfg, layout)
    checkpoint_policy checkpoint = resolve_checkpoint_policy(cfg)
    recovery_state recovery = new_recovery_state()
    memory_profile memory = estimate_memory_profile(cfg, layout, precision)

    large_scale_training_runtime {
        config: cfg,
        layout: layout,
        precision: precision,
        data: data,
        checkpoint: checkpoint,
        recovery: recovery,
        memory: memory,
        epoch: 0,
        global_step: 0,
        micro_step: 0,
        samples_seen: 0,
        tokens_seen: 0,
        initialized: true,
        healthy: true,
        should_allreduce: layout.allreduce_enabled,
        should_checkpoint: false,
        should_log: false,
        should_recover: false,
        last_loss: 0.0,
        best_loss: 999999.0,
        best_step: 0,
        running_loss: 0.0,
        running_steps: 0,
        gradient_checkpointing_enabled: cfg.gradient_checkpointing,
        zero_sharding_enabled: cfg.zero_optimization,
        tensor_parallel_enabled: layout.tensor_parallel_enabled,
        pipeline_parallel_enabled: layout.pipeline_parallel_enabled,
    }
}

// =====================================================================
// Runtime decisions
// =====================================================================

func runtime_should_sync_gradients(large_scale_training_runtime rt) bool {
    rt.should_allreduce
}

func runtime_requires_allreduce(large_scale_training_runtime rt) bool {
    rt.layout.data_parallel_enabled || rt.layout.tensor_parallel_enabled
}

func runtime_requires_reduce_scatter(large_scale_training_runtime rt) bool {
    rt.zero_sharding_enabled && rt.layout.data_parallel_size > 1
}

func runtime_requires_all_gather(large_scale_training_runtime rt) bool {
    rt.tensor_parallel_enabled || (rt.zero_sharding_enabled && rt.layout.data_parallel_size > 1)
}

func runtime_should_checkpoint_step(large_scale_training_runtime rt, int step) bool {
    if rt.checkpoint.checkpoint_interval <= 0 {
        return false
    }
    step > 0 && safe_mod_int(step, rt.checkpoint.checkpoint_interval) == 0
}

func runtime_should_log_step(large_scale_training_runtime rt, int step) bool {
    if rt.config.log_interval <= 0 {
        return false
    }
    step == 0 || safe_mod_int(step, rt.config.log_interval) == 0
}

func runtime_expected_microbatches(large_scale_training_runtime rt) int {
    if rt.config.microbatch_size <= 0 {
        return 1
    }
    int ratio = safe_div_int(rt.config.global_batch_size, rt.config.microbatch_size)
    if ratio < 1 {
        ratio = 1
    }
    ratio
}

func runtime_gradient_accumulation_steps(large_scale_training_runtime rt) int {
    if rt.config.gradient_accumulation_steps > 0 {
        return rt.config.gradient_accumulation_steps
    }
    runtime_expected_microbatches(rt)
}

func runtime_prefetch_window(large_scale_training_runtime rt) int {
    if rt.data.prefetch_batches {
        return rt.data.read_ahead_batches
    }
    0
}

func runtime_worker_count(large_scale_training_runtime rt) int {
    rt.data.dataloader_workers
}

func runtime_effective_dtype(large_scale_training_runtime rt) string {
    rt.precision.storage_dtype
}

func runtime_loss_scale(large_scale_training_runtime rt) float {
    rt.precision.loss_scale
}

func runtime_is_mixed_precision(large_scale_training_runtime rt) bool {
    rt.precision.mixed_precision
}

func runtime_data_parallel_size(large_scale_training_runtime rt) int {
    rt.layout.data_parallel_size
}

func runtime_tensor_parallel_size(large_scale_training_runtime rt) int {
    rt.layout.tensor_parallel_size
}

func runtime_pipeline_parallel_size(large_scale_training_runtime rt) int {
    rt.layout.pipeline_parallel_size
}

func runtime_data_parallel_enabled(large_scale_training_runtime rt) bool {
    rt.layout.data_parallel_enabled
}

func runtime_recovery_budget(large_scale_training_runtime rt) int {
    rt.checkpoint.recovery_timeout_steps
}

// =====================================================================
// Step updates
// =====================================================================

func runtime_record_step(
    large_scale_training_runtime rt,
    float loss,
    int batch_tokens,
    bool overflow_detected
) large_scale_training_runtime {
    rt.global_step = rt.global_step + 1
    rt.micro_step = safe_mod_int(rt.micro_step + 1, runtime_expected_microbatches(rt))
    rt.samples_seen = rt.samples_seen + 1
    rt.tokens_seen = rt.tokens_seen + batch_tokens
    rt.last_loss = loss
    rt.running_loss = rt.running_loss + loss
    rt.running_steps = rt.running_steps + 1

    if loss < rt.best_loss {
        rt.best_loss = loss
        rt.best_step = rt.global_step
    }

    rt.should_checkpoint = runtime_should_checkpoint_step(rt, rt.global_step)
    rt.should_log = runtime_should_log_step(rt, rt.global_step)
    rt.should_allreduce = rt.layout.allreduce_enabled

    if overflow_detected {
        rt.recovery.healthy = false
        rt.recovery.recovery_needed = true
        rt.recovery.last_error = "gradient_overflow"
        rt.should_recover = true
    } else {
        rt.healthy = true
        rt.recovery.healthy = true
        rt.recovery.recovery_needed = false
        rt.recovery.last_good_step = rt.global_step
        rt.should_recover = false
    }

    if rt.should_checkpoint {
        rt.recovery.last_checkpoint_step = rt.global_step
    }

    rt
}

func runtime_begin_epoch(large_scale_training_runtime rt, int epoch) large_scale_training_runtime {
    rt.epoch = epoch
    rt
}

func runtime_mark_recovery(large_scale_training_runtime rt, string error_code) large_scale_training_runtime {
    rt.healthy = false
    rt.should_recover = true
    rt.recovery.healthy = false
    rt.recovery.recovery_needed = true
    rt.recovery.recovery_attempts = rt.recovery.recovery_attempts + 1
    rt.recovery.last_error = error_code
    rt
}

func runtime_finalize_recovery(large_scale_training_runtime rt) large_scale_training_runtime {
    rt.healthy = true
    rt.should_recover = false
    rt.recovery.healthy = true
    rt.recovery.recovery_needed = false
    rt.recovery.last_error = ""
    rt
}

// =====================================================================
// Reporting helpers
// =====================================================================

struct runtime_summary {
    int total_params
    string precision
    int data_parallel_size
    int tensor_parallel_size
    int pipeline_parallel_size
    bool allreduce_enabled
    bool gradient_checkpointing
    bool zero_optimization
    float estimated_memory_gb
    bool within_memory_budget
}

func summarize_runtime(large_scale_training_runtime rt) runtime_summary {
    runtime_summary {
        total_params: estimate_param_count(rt.config),
        precision: rt.precision.storage_dtype,
        data_parallel_size: rt.layout.data_parallel_size,
        tensor_parallel_size: rt.layout.tensor_parallel_size,
        pipeline_parallel_size: rt.layout.pipeline_parallel_size,
        allreduce_enabled: rt.layout.allreduce_enabled,
        gradient_checkpointing: rt.gradient_checkpointing_enabled,
        zero_optimization: rt.zero_sharding_enabled,
        estimated_memory_gb: rt.memory.total_gb,
        within_memory_budget: rt.memory.within_budget,
    }
}

func runtime_is_ready_for_large_scale_training(large_scale_training_runtime rt) bool {
    if !rt.initialized {
        return false
    }
    if rt.layout.world_size <= 1 {
        return false
    }
    if rt.config.global_batch_size < rt.config.microbatch_size {
        return false
    }
    if rt.config.tensor_parallel_size <= 0 || rt.config.data_parallel_size <= 0 {
        return false
    }
    if rt.memory.total_gb > 80.0 && !rt.gradient_checkpointing_enabled {
        return false
    }
    true
}
