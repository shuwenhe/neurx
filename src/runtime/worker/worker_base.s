import "types.s"
struct BaseWorker {
    config              WorkerConfig
    state               i32
    stats               WorkerStats
    request_queue       []RequestMetadata
    queue_size          i32
    max_queue_size      i32
    current_batch_id    i32
    initialized         i32
    last_heartbeat      i64
    total_batches       i64
    successful_batches  i64
    failed_batches      i64
    cache_stats         map[string]i64
}
func NewBaseWorker(config WorkerConfig) *BaseWorker {
    worker := *BaseWorker{
        config: config,
        state: WORKER_STATE_IDLE,
        queue_size: 0,
        max_queue_size: config.max_batch_size * 4,
        current_batch_id: 0,
        initialized: 0,
        last_heartbeat: 0,
        total_batches: 0,
        successful_batches: 0,
        failed_batches: 0,
    }
    return worker
}
func (BaseWorker* w) Initialize() WorkerResult {
    if w.initialized == 1 {
        return WorkerResult{success: 1, error_code: ERROR_SUCCESS}
    }
    w.state = WORKER_STATE_INITIALIZING
    w.stats.total_requests = 0
    w.stats.completed_requests = 0
    w.stats.failed_requests = 0
    w.stats.total_tokens = 0
    w.stats.avg_latency_ms = 0.0
    w.stats.throughput_req_s = 0.0
    w.stats.gpu_utilization = 0.0
    w.stats.memory_used_mb = 0
    w.stats.cache_hit_rate = 0.0
    w.stats.queue_length = 0
    w.stats.uptime_ms = 0
    w.initialized = 1
    w.state = WORKER_STATE_READY
    w.last_heartbeat = system_time_ms()
    return WorkerResult{success: 1, error_code: ERROR_SUCCESS}
}
func (BaseWorker* w) SubmitRequest(request RequestMetadata) WorkerResult {
    if w.state != WORKER_STATE_READY && w.state != WORKER_STATE_BUSY {
        return WorkerResult{
            success: 0,
            error_code: ERROR_WORKER_NOT_FOUND,
            error_message: "Worker not in ready state",
        }
    }
    if w.queue_size >= w.max_queue_size {
        return WorkerResult{
            success: 0,
            error_code: ERROR_BATCH_FULL,
            error_message: "Worker queue is full",
        }
    }
    w.request_queue = append(w.request_queue, request)
    w.queue_size++
    w.stats.queue_length = w.queue_size
    if w.state == WORKER_STATE_READY && w.queue_size > 0 {
        w.state = WORKER_STATE_BUSY
    }
    return WorkerResult{success: 1, error_code: ERROR_SUCCESS}
}
func (BaseWorker* w) GetNextBatch(max_size i32) Batch {
    batch_size := max_size
    if w.queue_size < max_size {
        batch_size = w.queue_size
    }
    batch := Batch{
        batch_id: w.current_batch_id,
        request_count: 0,
        batch_type: BATCH_TYPE_PREFILL,
        total_tokens: 0,
        max_batch_size: max_size,
        scheduled_worker: w.config.worker_id,
        created_time: system_time_ms(),
    }
    for i := 0; i < batch_size; i++ {
        if i < w.queue_size {
            request := w.request_queue[i]
            batch_req := BatchRequest{
                request_id: request.request_id,
                prompt_len: request.prompt_tokens,
                max_tokens: request.max_tokens,
                priority: request.priority,
                timestamp: request.timestamp,
            }
            batch.requests = append(batch.requests, batch_req)
            batch.request_count++
            batch.total_tokens += request.prompt_tokens
        }
    }
    w.current_batch_id++
    return batch
}
func (BaseWorker* w) CompleteBatch(batch_id i32, result_count i32,
                                   total_tokens i32, error_code i32) WorkerResult {
    if error_code == ERROR_SUCCESS {
        w.successful_batches++
        w.stats.completed_requests += i64(result_count)
        w.stats.total_tokens += i64(total_tokens)
    } else {
        w.failed_batches++
        w.stats.failed_requests += i64(result_count)
    }
    w.total_batches++
    if w.queue_size > 0 {
        w.queue_size--
        if len(w.request_queue) > 1 {
            w.request_queue = w.request_queue[1:]
        } else {
            w.request_queue = []RequestMetadata{}
        }
    }
    if w.queue_size == 0 {
        w.state = WORKER_STATE_READY
    }
    return WorkerResult{success: 1, error_code: ERROR_SUCCESS}
}
func (BaseWorker* w) ProcessBatch(batch Batch) ExecutionResult {
    return ExecutionResult{
        batch_id: batch.batch_id,
        worker_id: w.config.worker_id,
        state: REQUEST_STATE_FAILED,
        error_code: ERROR_UNKNOWN,
        error_message: "ProcessBatch not implemented in base worker",
    }
}
func (BaseWorker* w) GetWorkerState() WorkerState {
    return WorkerState{
        worker_id: w.config.worker_id,
        state: w.state,
        worker_type: w.config.worker_type,
        status: w.state_to_string(w.state),
        load_percentage: i32((w.queue_size * 100) / w.max_queue_size),
        queue_size: w.queue_size,
        current_batch_id: w.current_batch_id,
        model_name: "model",
        device_id: w.config.device_id,
        is_alive: 1,
        stats: w.stats,
        last_update: system_time_ms(),
    }
}
func (BaseWorker* w) GetStatistics() WorkerStats {
    return w.stats
}
func (BaseWorker* w) ResetStatistics() {
    w.stats.total_requests = 0
    w.stats.completed_requests = 0
    w.stats.failed_requests = 0
    w.stats.total_tokens = 0
    w.stats.queue_length = 0
}
func (BaseWorker* w) IsHealthy() i32 {
    if w.state == WORKER_STATE_ERROR || w.state == WORKER_STATE_SHUTDOWN {
        return 0
    }
    current_time := system_time_ms()
    last_hb := current_time - w.last_heartbeat
    if last_hb > w.config.timeout_ms {
        return 0
    }
    return 1
}
func (BaseWorker* w) SendHeartbeat() {
    w.last_heartbeat = system_time_ms()
}
func (BaseWorker* w) Shutdown() WorkerResult {
    if w.state == WORKER_STATE_SHUTDOWN {
        return WorkerResult{success: 1, error_code: ERROR_SUCCESS}
    }
    w.state = WORKER_STATE_DRAINING
    for w.queue_size > 0 {
    }
    w.state = WORKER_STATE_SHUTDOWN
    w.initialized = 0
    return WorkerResult{success: 1, error_code: ERROR_SUCCESS}
}
func (BaseWorker* w) SetState(new_state i32) {
    w.state = new_state
}
func (BaseWorker* w) GetState() i32 {
    return w.state
}
func (BaseWorker* w) GetQueueSize() i32 {
    return w.queue_size
}
func (BaseWorker* w) state_to_string(state i32) string {
    match state {
    case WORKER_STATE_IDLE:
        return "IDLE"
    case WORKER_STATE_INITIALIZING:
        return "INITIALIZING"
    case WORKER_STATE_READY:
        return "READY"
    case WORKER_STATE_BUSY:
        return "BUSY"
    case WORKER_STATE_DRAINING:
        return "DRAINING"
    case WORKER_STATE_ERROR:
        return "ERROR"
    case WORKER_STATE_SHUTDOWN:
        return "SHUTDOWN"
    default:
        return "UNKNOWN"
    }
}
func system_time_ms() i64 {
    return 0
}
