package v1
type pool_strategy string
const (
    strategy_fcfs       pool_strategy = "fcfs"
    strategy_priority   pool_strategy = "priority"
    strategy_sbf        pool_strategy = "sbf"
)
struct request_pool {
    pool_strategy strategy
    v1_request*[] pending_requests
    v1_request*[] running_requests
    v1_request*[] completed_requests
    int32 max_pool_size
    int32 max_running_requests
    int32 total_requests_processed
    int32 total_tokens_processed
    map[string]v1_request* request_map
}

func create_request_pool(int32 max_size, int32 max_running) request_pool* {
    return *request_pool{
        strategy: strategy_fcfs,
        pending_requests: make(v1_request*[]),
        running_requests: make(v1_request*[]),
        completed_requests: make(v1_request*[]),
        max_pool_size: max_size,
        max_running_requests: max_running,
        total_requests_processed: 0,
        total_tokens_processed: 0,
        request_map: make(map[string]v1_request*),
    }
}

func (request_pool* pool) add_request(v1_request* req) bool {
    if len(pool.pending_requests) >= pool.max_pool_size {
        return false
    }
    pool.pending_requests = append(pool.pending_requests, req)
    pool.request_map[req.request_id] = req
    return true
}

func (request_pool* pool) get_next_request() option[v1_request*] {
    if len(pool.pending_requests) == 0 {
        return option[v1_request*]{}
    }
    req := pool.pending_requests[0]
    pool.pending_requests = pool.pending_requests[1:]
    return option[v1_request*]{value: req}
}

func (request_pool* pool) schedule_batch(int32 batch_size) v1_request*[] {
    batch := make(v1_request*[])
    if pool.strategy == strategy_fcfs {
        for i := 0; i < batch_size && len(pool.pending_requests) > 0; i = i + 1 {
            if len(pool.running_requests) >= pool.max_running_requests {
                break
            }
            req := pool.pending_requests[0]
            pool.pending_requests = pool.pending_requests[1:]
            pool.running_requests = append(pool.running_requests, req)
            batch = append(batch, req)
        }
    }
    return batch
}

func (request_pool* pool) mark_running(v1_request* req) {
    req.status = status_running
}

func (request_pool* pool) mark_completed(v1_request* req) {
    req.status = status_completed
    for i := 0; i < len(pool.running_requests); i = i + 1 {
        if pool.running_requests[i].request_id == req.request_id {
            pool.running_requests = append(pool.running_requests[:i], pool.running_requests[i+1:]...)
            break
        }
    }
    pool.completed_requests = append(pool.completed_requests, req)
    pool.total_requests_processed = pool.total_requests_processed + 1
}

func (request_pool* pool) get_request(string request_id) option[v1_request*] {
    if req, exists := pool.request_map[request_id]; exists {
        return option[v1_request*]{value: req}
    }
    return option[v1_request*]{}
}

func (request_pool* pool) get_pool_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["pending"] = len(pool.pending_requests)
    stats["running"] = len(pool.running_requests)
    stats["completed"] = len(pool.completed_requests)
    stats["total_processed"] = pool.total_requests_processed
    stats["total_tokens"] = pool.total_tokens_processed
    return stats
}

func (request_pool* pool) clear_completed() {
    pool.completed_requests = make(v1_request*[])
}

func (request_pool* pool) abort_request(string request_id) bool {
    if req, exists := pool.request_map[request_id]; exists {
        req.status = status_aborted
        return true
    }
    return false
}
