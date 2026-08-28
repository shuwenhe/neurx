const (
    WORKER_STATE_IDLE       = 0
    WORKER_STATE_INITIALIZING = 1
    WORKER_STATE_READY      = 2
    WORKER_STATE_BUSY       = 3
    WORKER_STATE_DRAINING   = 4
    WORKER_STATE_ERROR      = 5
    WORKER_STATE_SHUTDOWN   = 6
    WORKER_TYPE_GPU         = 0
    WORKER_TYPE_CPU         = 1
    WORKER_TYPE_HYBRID      = 2
    WORKER_TYPE_CUSTOM      = 3
    REQUEST_STATE_SUBMITTED = 0
    REQUEST_STATE_QUEUED    = 1
    REQUEST_STATE_PROCESSING = 2
    REQUEST_STATE_COMPLETED = 3
    REQUEST_STATE_FAILED    = 4
    REQUEST_STATE_CANCELLED = 5
    BATCH_TYPE_PREFILL      = 0
    BATCH_TYPE_DECODE       = 1
    BATCH_TYPE_MIXED        = 2
    COMM_TYPE_RPC          = 0
    COMM_TYPE_GRPC         = 1
    COMM_TYPE_IPC          = 2
    COMM_TYPE_NCCL         = 3
    ERROR_SUCCESS           = 0
    ERROR_WORKER_NOT_FOUND  = 101
    ERROR_WORKER_BUSY       = 102
    ERROR_WORKER_TIMEOUT    = 103
    ERROR_COMMUNICATION_FAILED = 104
    ERROR_BATCH_FULL        = 105
    ERROR_INVALID_REQUEST   = 106
    ERROR_ALLOCATION_FAILED = 107
    ERROR_SCHEDULER_FAILED  = 108
    ERROR_SYNC_FAILED       = 109
    ERROR_UNKNOWN           = 999
    DEFAULT_WORKER_TIMEOUT  = 30000
    DEFAULT_BATCH_SIZE      = 256
    DEFAULT_MAX_WORKERS     = 64
    DEFAULT_MAX_TOKENS      = 4096
    DEFAULT_RPC_TIMEOUT     = 5000
    MAX_RETRIES             = 3
)
struct RequestMetadata {
    request_id      string
    prompt_tokens   i32
    max_tokens      i32
    priority        i32
    timeout_ms      i32
    timestamp       i64
    worker_id       i32
}

struct WorkerConfig {
    worker_id       i32
    worker_type     i32
    device_id       i32
    gpus            []i32
    max_batch_size  i32
    max_model_len   i32
    gpu_memory_mb   i32
    cpu_memory_mb   i32
    enable_cache    i32
    cache_size_mb   i32
    enable_async    i32
    num_threads     i32
    timeout_ms      i32
    communication_type i32
    custom_config   map[string]string
}

struct WorkerStats {
    total_requests  i64
    completed_requests i64
    failed_requests i64
    total_tokens    i64
    avg_latency_ms  f64
    throughput_req_s f64
    gpu_utilization f64
    memory_used_mb  i32
    cache_hit_rate  f64
    queue_length    i32
    uptime_ms       i64
    last_heartbeat  i64
}

struct WorkerState {
    worker_id       i32
    state           i32
    worker_type     i32
    status          string
    load_percentage i32
    queue_size      i32
    current_batch_id i32
    model_name      string
    device_id       i32
    is_alive        i32
    stats           WorkerStats
    last_update     i64
}

struct BatchRequest {
    request_id      string
    prompt_tokens   []i32
    prompt_len      i32
    max_tokens      i32
    batch_type      i32
    priority        i32
    timestamp       i64
    metadata        RequestMetadata
}

struct Batch {
    batch_id        i32
    requests        []BatchRequest
    request_count   i32
    batch_type      i32
    total_tokens    i32
    max_batch_size  i32
    scheduled_worker i32
    priority        i32
    created_time    i64
    submitted_time  i64
}

struct ExecutionResult {
    request_id      string
    batch_id        i32
    worker_id       i32
    state           i32
    output_tokens   []i32
    output_len      i32
    completion_tokens i32
    total_tokens    i32
    latency_ms      i32
    timestamp       i64
    error_code      i32
    error_message   string
}

struct WorkerMessage {
    message_id      i64
    sender_id       i32
    receiver_id     i32
    message_type    i32
    payload         []u8
    payload_size    i32
    timestamp       i64
    requires_ack    i32
}

struct CommunicationConfig {
    comm_type       i32
    timeout_ms      i32
    max_msg_size    i32
    retry_count     i32
    use_compression i32
    buffer_size     i32
}

struct SchedulingPolicy {
    policy_type     i32
    enable_preemption i32
    enable_backfill i32
    batch_timeout_ms i32
    max_queue_size  i32
    priority_levels i32
}

struct WorkerPool {
    total_workers   i32
    active_workers  i32
    idle_workers    i32
    busy_workers    i32
    error_workers   i32
    total_gpus      i32
    total_memory_gb f64
}

struct SyncState {
    sync_id         i64
    source_worker   i32
    target_workers  []i32
    target_count    i32
    state_data      []u8
    state_size      i32
    timestamp       i64
    is_distributed  i32
}

struct WorkerResult {
    success         i32
    error_code      i32
    error_message   string
    data            []u8
    data_size       i32
    execution_time  i32
}

struct HeartbeatMessage {
    worker_id       i32
    timestamp       i64
    state           i32
    queue_size      i32
    memory_used_mb  i32
    gpu_utilization i32
    request_count   i64
    error_count     i32
    is_responsive   i32
}

struct WorkerPoolStats {
    total_requests  i64
    completed_requests i64
    failed_requests i64
    total_tokens_processed i64
    avg_throughput  f64
    avg_latency_ms  f64
    max_queue_size  i32
    current_queue_size i32
    total_uptime_ms i64
    last_updated    i64
}

struct DistributedConfig {
    rank            i32
    world_size      i32
    master_addr     string
    master_port     i32
    backend         string
    timeout_ms      i32
    enable_collectives i32
}
