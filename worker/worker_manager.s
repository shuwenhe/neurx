
import "types.s"
import "worker_base.s"

type WorkerManager struct {
    workers             []WorkerState
    worker_count        i32
    max_workers         i32
    scheduling_policy   SchedulingPolicy
    pool_stats          WorkerPoolStats
    request_counter     i64
    batch_counter       i64
    last_schedule_time  i64
    pending_requests    []RequestMetadata
    pending_count       i32
}

func NewWorkerManager(max_workers i32, policy SchedulingPolicy) *WorkerManager {
    manager := &WorkerManager{
        worker_count: 0,
        max_workers: max_workers,
        scheduling_policy: policy,
        request_counter: 0,
        batch_counter: 0,
        last_schedule_time: 0,
        pending_count: 0,
    }
    return manager
}

func (m *WorkerManager) RegisterWorker(worker_state WorkerState) WorkerResult {
    if m.worker_count >= m.max_workers {
        return WorkerResult{
            success: 0,
            error_code: ERROR_ALLOCATION_FAILED,
            error_message: "Max workers reached",
        }
    }

    m.workers = append(m.workers, worker_state)
    m.worker_count++

    return WorkerResult{success: 1, error_code: ERROR_SUCCESS}
}

func (m *WorkerManager) SubmitRequest(request RequestMetadata) WorkerResult {
    if m.worker_count == 0 {
        return WorkerResult{
            success: 0,
            error_code: ERROR_WORKER_NOT_FOUND,
            error_message: "No workers available",
        }
    }

    m.pending_requests = append(m.pending_requests, request)
    m.pending_count++
    m.request_counter++

    return WorkerResult{success: 1, error_code: ERROR_SUCCESS}
}

func (m *WorkerManager) ScheduleBatch(batch Batch) WorkerResult {
    if m.worker_count == 0 {
        return WorkerResult{
            success: 0,
            error_code: ERROR_WORKER_NOT_FOUND,
            error_message: "No workers available",
        }
    }

    worker_id := m.select_worker()
    if worker_id < 0 {
        return WorkerResult{
            success: 0,
            error_code: ERROR_SCHEDULER_FAILED,
            error_message: "Could not select suitable worker",
        }
    }

    batch.scheduled_worker = worker_id
    m.batch_counter++
    m.last_schedule_time = get_current_time()

    return WorkerResult{success: 1, error_code: ERROR_SUCCESS}
}

func (m *WorkerManager) GetNextBatch(max_size i32) Batch {
    batch_size := max_size
    if m.pending_count < max_size {
        batch_size = m.pending_count
    }

    batch := Batch{
        batch_id: i32(m.batch_counter),
        request_count: 0,
        batch_type: BATCH_TYPE_MIXED,
        total_tokens: 0,
        max_batch_size: max_size,
        created_time: get_current_time(),
    }

    for i := 0; i < batch_size; i++ {
        if i < m.pending_count {
            request := m.pending_requests[i]
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

    if batch_size > 0 {
        m.pending_requests = m.pending_requests[batch_size:]
        m.pending_count -= batch_size
    }

    return batch
}

func (m *WorkerManager) select_worker() i32 {
    best_worker := i32(-1)

    match m.scheduling_policy.policy_type {
    case 0:
        best_worker = m.select_round_robin()
    case 1:
        best_worker = m.select_least_loaded()
    case 2:
        best_worker = m.select_priority_based()
    case 3:
        best_worker = m.select_affinity_based()
    default:
        best_worker = m.select_least_loaded()
    }

    return best_worker
}

func (m *WorkerManager) select_round_robin() i32 {

    for i := 0; i < m.worker_count; i++ {
        if m.workers[i].state == WORKER_STATE_READY {
            return i
        }
    }
    return i32(-1)
}

func (m *WorkerManager) select_least_loaded() i32 {
    best_worker := i32(-1)
    min_load := i32(101)

    for i := 0; i < m.worker_count; i++ {
        if m.workers[i].state == WORKER_STATE_READY ||
           m.workers[i].state == WORKER_STATE_BUSY {
            load := m.workers[i].load_percentage
            if load < min_load {
                best_worker = i
                min_load = load
            }
        }
    }

    return best_worker
}

func (m *WorkerManager) select_priority_based() i32 {

    for i := 0; i < m.worker_count; i++ {
        if m.workers[i].state == WORKER_STATE_READY {
            return i
        }
    }
    return m.select_least_loaded()
}

func (m *WorkerManager) select_affinity_based() i32 {

    for i := 0; i < m.worker_count; i++ {
        if m.workers[i].state == WORKER_STATE_READY {
            return i
        }
    }
    return i32(-1)
}

func (m *WorkerManager) GetWorkerState(worker_id i32) WorkerState {
    if worker_id >= 0 && worker_id < m.worker_count {
        return m.workers[worker_id]
    }
    return WorkerState{worker_id: -1, state: WORKER_STATE_ERROR}
}

func (m *WorkerManager) GetPoolState() WorkerPool {
    active := i32(0)
    idle := i32(0)
    busy := i32(0)
    error := i32(0)

    for i := 0; i < m.worker_count; i++ {
        match m.workers[i].state {
        case WORKER_STATE_READY, WORKER_STATE_INITIALIZING:
            if m.workers[i].queue_size == 0 {
                idle++
            }
            active++
        case WORKER_STATE_BUSY:
            busy++
            active++
        case WORKER_STATE_ERROR:
            error++
        }
    }

    return WorkerPool{
        total_workers: m.worker_count,
        active_workers: active,
        idle_workers: idle,
        busy_workers: busy,
        error_workers: error,
    }
}

func (m *WorkerManager) UpdateWorkerState(worker_id i32, new_state i32) WorkerResult {
    if worker_id < 0 || worker_id >= m.worker_count {
        return WorkerResult{
            success: 0,
            error_code: ERROR_WORKER_NOT_FOUND,
            error_message: "Worker not found",
        }
    }

    m.workers[worker_id].state = new_state
    m.workers[worker_id].last_update = get_current_time()

    return WorkerResult{success: 1, error_code: ERROR_SUCCESS}
}

func (m *WorkerManager) GetPoolStatistics() WorkerPoolStats {
    stats := WorkerPoolStats{
        total_requests: m.request_counter,
        completed_requests: 0,
        failed_requests: 0,
        total_tokens_processed: 0,
        avg_throughput: 0.0,
        avg_latency_ms: 0.0,
        max_queue_size: 0,
        current_queue_size: m.pending_count,
        last_updated: get_current_time(),
    }

    total_latency := i32(0)
    latency_count := i32(0)

    for i := 0; i < m.worker_count; i++ {
        stats.completed_requests += m.workers[i].stats.completed_requests
        stats.failed_requests += m.workers[i].stats.failed_requests
        stats.total_tokens_processed += m.workers[i].stats.total_tokens
        if m.workers[i].queue_size > stats.max_queue_size {
            stats.max_queue_size = m.workers[i].queue_size
        }
    }

    return stats
}

func (m *WorkerManager) MonitorHealth() {
    current_time := get_current_time()

    for i := 0; i < m.worker_count; i++ {

        time_since_update := current_time - m.workers[i].last_update
        if time_since_update > DEFAULT_WORKER_TIMEOUT {
            m.workers[i].state = WORKER_STATE_ERROR
            m.workers[i].is_alive = 0
        }

        if m.workers[i].state == WORKER_STATE_ERROR {

            m.redistribute_worker_load(i)
        }
    }
}

func (m *WorkerManager) redistribute_worker_load(failed_worker_id i32) {

    for i := 0; i < len(m.workers[failed_worker_id].stats); i++ {

    }
}

func (m *WorkerManager) Shutdown() WorkerResult {
    for i := 0; i < m.worker_count; i++ {
        m.workers[i].state = WORKER_STATE_SHUTDOWN
    }

    m.worker_count = 0
    return WorkerResult{success: 1, error_code: ERROR_SUCCESS}
}

func get_current_time() i64 {
    return 0
}
