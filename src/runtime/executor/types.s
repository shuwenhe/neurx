const (

    EXECUTOR_STATE_IDLE         = 0
    EXECUTOR_STATE_INITIALIZING = 1
    EXECUTOR_STATE_RUNNING      = 2
    EXECUTOR_STATE_PAUSED       = 3
    EXECUTOR_STATE_DRAINING     = 4
    EXECUTOR_STATE_ERROR        = 5
    EXECUTOR_STATE_SHUTDOWN     = 6

    PHASE_PREFILL               = 0
    PHASE_DECODE                = 1
    PHASE_MIXED                 = 2

    EVICTION_LRU                = 0
    EVICTION_LFU                = 1
    EVICTION_FIFO               = 2
    EVICTION_ADAPTIVE           = 3

    SCHEDULE_FCFS               = 0
    SCHEDULE_PRIORITY           = 1
    SCHEDULE_SJF                = 2
    SCHEDULE_DYNAMIC            = 3

    ITERATION_TYPE_PREFILL      = 0
    ITERATION_TYPE_DECODE_STEP  = 1
    ITERATION_TYPE_ENCODE       = 2
    ITERATION_TYPE_SPECULATIVE  = 3

    ERROR_SUCCESS               = 0
    ERROR_EXECUTION_FAILED      = 201
    ERROR_INSUFFICIENT_CACHE    = 202
    ERROR_INVALID_SEQUENCE      = 203
    ERROR_MODEL_LOAD_FAILED     = 204
    ERROR_GPU_OUT_OF_MEMORY     = 205
    ERROR_SCHEDULING_FAILED     = 206
    ERROR_CACHE_EVICTION_FAILED = 207
    ERROR_DISTRIBUTED_SYNC_FAILED = 208
    ERROR_STEP_TIMEOUT          = 209
    ERROR_UNKNOWN               = 999

    DEFAULT_CACHE_SIZE_GB       = 20
    DEFAULT_MAX_ITERATIONS      = 1000
    DEFAULT_MAX_SEQ_LENGTH      = 8192
    DEFAULT_MAX_BATCH_SIZE      = 256
    DEFAULT_ITERATION_TIMEOUT   = 30000
    DEFAULT_PREFILL_BATCH_SIZE  = 256
    DEFAULT_DECODE_BATCH_SIZE   = 512
)

struct ExecutorConfig {
    executor_id         i32
    model_name          string
    device_id           i32
    max_batch_size      i32
    max_seq_length      i32
    cache_size_gb       f64
    eviction_policy     i32
    scheduling_policy   i32
    enable_speculative  i32
    enable_prefix_cache i32
    tensor_parallel     i32
    pipeline_parallel   i32
    timeout_ms          i32
}

struct ExecutionIteration {
    iteration_id    i64
    phase           i32
    start_time      i64
    end_time        i64
    duration_ms     i32
    sequence_ids    string[]
    sequence_count  i32
    total_tokens    i32
    output_tokens   i32
    error_code      i32
}

struct SequenceStatus {
    sequence_id     string
    phase           i32
    token_pos       i32
    kv_cache_size   i32
    is_complete     i32
    error_code      i32
    priority        i32
    arrival_time    i64
    estimated_finish i64
}

struct KVCacheBlock {
    block_id        i32
    sequence_id     string
    token_start     i32
    token_end       i32
    size_bytes      i32
    is_allocated    i32
    last_access     i64
    access_count    i64
}

struct KVCacheManager {
    total_size_gb   f64
    allocated_mb    i32
    free_mb         i32
    blocks          []KVCacheBlock
    block_count     i32
    eviction_policy i32
    max_blocks      i32
}

struct ExecutionResult {
    iteration_id    i64
    success         i32
    error_code      i32
    error_message   string
    phase           i32
    tokens_processed i32
    latency_ms      i32
    throughput      f64
    cache_hit_rate  f64
}

struct ExecutorStatistics {
    total_iterations    i64
    completed_iterations i64
    failed_iterations   i64
    total_tokens        i64
    total_latency       i64
    avg_latency         f64
    max_latency         i32
    min_latency         i32
    cache_hit_rate      f64
    cache_miss_rate     f64
    throughput          f64
    memory_peak         i32
}

struct PrefillConfig {
    max_batch_size  i32
    max_tokens      i32
    enable_paging   i32
    enable_swap     i32
    block_size      i32
}

struct DecodeConfig {
    max_batch_size  i32
    beam_width      i32
    enable_batching i32
    enable_swap     i32
    num_beams       i32
}

struct DistributedConfig {
    rank            i32
    world_size      i32
    tensor_parallel i32
    pipeline_parallel i32
    sync_timeout_ms i32
}

struct IterationSchedule {
    iteration_id    i64
    prefill_batch   string[]
    prefill_count   i32
    decode_batch    string[]
    decode_count    i32
    mixed_batch     string[]
    mixed_count     i32
    priority_order  []i32
}

struct ExecutorMetrics {
    current_state   i32
    active_sequences i32
    queued_sequences i32
    cache_usage_mb  i32
    throughput_rps  f64
    latency_p50     i32
    latency_p95     i32
    latency_p99     i32
    gpu_memory_mb   i32
    gpu_util        f64
}

struct AttentionMask {
    sequence_id     string
    mask_data       []u8
    mask_size       i32
    is_causal       i32
    enable_prefix   i32
}

struct CacheEvictionPolicy {
    policy_type     i32
    max_block_age   i64
    max_block_freq  i64
    evict_threshold f64
}
