package v1

struct request_lifecycle {
    string request_id
    request_state current_state
    int64 state_change_time
    
    vec[request_state] state_history
    vec[int64] state_timestamps
}

struct request_priority {
    string request_id
    int32 priority_level
    int64 arrival_time
    int32 timeout_ms
    bool sla_critical
}

func (active_request* req) transition_state(request_state new_state) bool {
    valid_transitions := get_valid_transitions(req.state)
    
    for i := 0; i < len(valid_transitions); i = i + 1 {
        if valid_transitions[i] == new_state {
            req.state = new_state
            return true
        }
    }
    
    return false
}

func get_valid_transitions(request_state from_state) vec[request_state] {
    transitions := make(vec[request_state])
    
    if from_state == req_state_submitted {
        transitions = append(transitions, req_state_waiting)
        transitions = append(transitions, req_state_cancelled)
    } else if from_state == req_state_waiting {
        transitions = append(transitions, req_state_prefilling)
        transitions = append(transitions, req_state_cancelled)
    } else if from_state == req_state_prefilling {
        transitions = append(transitions, req_state_decoding)
        transitions = append(transitions, req_state_error)
        transitions = append(transitions, req_state_cancelled)
    } else if from_state == req_state_decoding {
        transitions = append(transitions, req_state_streaming)
        transitions = append(transitions, req_state_finished)
        transitions = append(transitions, req_state_error)
        transitions = append(transitions, req_state_cancelled)
    } else if from_state == req_state_streaming {
        transitions = append(transitions, req_state_finished)
        transitions = append(transitions, req_state_error)
        transitions = append(transitions, req_state_cancelled)
    }
    
    return transitions
}

func (active_request* req) add_generated_token(int32 token_id) bool {
    if req.num_decode_steps >= req.max_new_tokens {
        return false
    }
    
    req.generated_tokens = append(req.generated_tokens, token_id)
    req.num_decode_steps = req.num_decode_steps + 1
    
    return true
}

func (active_request* req) is_prefill_complete() bool {
    return req.num_prefill_tokens > 0
}

func (active_request* req) is_decode_complete() bool {
    return req.num_decode_steps >= req.max_new_tokens
}

func (active_request* req) is_finished() bool {
    return req.state == req_state_finished || req.state == req_state_cancelled || req.state == req_state_error
}

func (active_request* req) get_progress_percent() int32 {
    if req.max_new_tokens == 0 {
        return 0
    }
    
    return (req.num_decode_steps * 100) / req.max_new_tokens
}

func (active_request* req) get_elapsed_time_ms() int64 {
    if req.started_at == 0 {
        return 0
    }
    
    current := current_time_ns()
    if req.finished_at > 0 {
        current = req.finished_at
    }
    
    elapsed_ns := current - req.started_at
    return elapsed_ns / 1000000
}

func (active_request* req) get_total_tokens() int32 {
    return len(req.prompt_tokens) + len(req.generated_tokens)
}

func create_active_request(
    string request_id,
    vec[int32] prompt_tokens,
    int32 max_new_tokens
) active_request {
    return active_request{
        request_id: request_id,
        prompt_tokens: prompt_tokens,
        generated_tokens: make(vec[int32]),
        num_prefill_tokens: 0,
        num_decode_steps: 0,
        max_new_tokens: max_new_tokens,
        kv_cache_slot: nil,
        state: req_state_submitted,
        is_streaming: false,
        stream: nil,
        created_at: current_time_ns(),
        started_at: 0,
        finished_at: 0,
    }
}

func (request_lifecycle* lc) record_state_change(request_state new_state) bool {
    lc.current_state = new_state
    lc.state_change_time = current_time_ns()
    lc.state_history = append(lc.state_history, new_state)
    lc.state_timestamps = append(lc.state_timestamps, lc.state_change_time)
    return true
}

func (request_lifecycle* lc) get_state_duration(int32 state_index) int64 {
    if state_index < 0 || state_index >= len(lc.state_history) {
        return 0
    }
    
    start_time := lc.state_timestamps[state_index]
    
    end_time := current_time_ns()
    if state_index + 1 < len(lc.state_timestamps) {
        end_time = lc.state_timestamps[state_index + 1]
    }
    
    return end_time - start_time
}

func (request_priority* p) is_overdue() bool {
    current := current_time_ns()
    arrival_ns := p.arrival_time
    timeout_ns := int64(p.timeout_ms) * 1000000
    
    return (current - arrival_ns) > timeout_ns
}

func (request_priority* p) get_priority_score() int32 {
    base := p.priority_level
    
    if p.sla_critical {
        base = base + 100
    }
    
    current := current_time_ns()
    age_ms := (current - p.arrival_time) / 1000000
    
    if age_ms > 5000 {
        base = base + 50
    } else if age_ms > 2000 {
        base = base + 25
    }
    
    return base
}

func create_request_priority(string request_id, int32 priority_level) request_priority {
    return request_priority{
        request_id: request_id,
        priority_level: priority_level,
        arrival_time: current_time_ns(),
        timeout_ms: 30000,
        sla_critical: priority_level > 3,
    }
}

struct request_batch {
    vec[active_request*] requests
    int32 batch_id
    int64 created_at
    int32 total_tokens
}

func (request_batch* batch) add_request(active_request* req) bool {
    batch.requests = append(batch.requests, req)
    batch.total_tokens = batch.total_tokens + len(req.prompt_tokens)
    return true
}

func (request_batch* batch) remove_request(string request_id) bool {
    for i := 0; i < len(batch.requests); i = i + 1 {
        if batch.requests[i].request_id == request_id {
            batch.requests = append(batch.requests[:i], batch.requests[i+1:]...)
            return true
        }
    }
    return false
}

func (request_batch* batch) get_batch_size() int32 {
    return int32(len(batch.requests))
}

func (request_batch* batch) is_empty() bool {
    return len(batch.requests) == 0
}

struct request_pool {
    map[string, active_request] all_requests
    vec[string] pending_ids
    vec[string] running_ids
    vec[string] completed_ids
    int32 max_pool_size
}

func create_request_pool(int32 max_size) request_pool* {
    return &request_pool{
        all_requests: make(map[string, active_request]),
        pending_ids: make(vec[string]),
        running_ids: make(vec[string]),
        completed_ids: make(vec[string]),
        max_pool_size: max_size,
    }
}

func (request_pool* pool) submit_request(active_request* req) bool {
    if len(pool.all_requests) >= pool.max_pool_size {
        return false
    }
    
    pool.all_requests[req.request_id] = *req
    pool.pending_ids = append(pool.pending_ids, req.request_id)
    
    return true
}

func (request_pool* pool) mark_running(string request_id) bool {
    for i := 0; i < len(pool.pending_ids); i = i + 1 {
        if pool.pending_ids[i] == request_id {
            pool.pending_ids = append(pool.pending_ids[:i], pool.pending_ids[i+1:]...)
            pool.running_ids = append(pool.running_ids, request_id)
            return true
        }
    }
    return false
}

func (request_pool* pool) mark_completed(string request_id) bool {
    for i := 0; i < len(pool.running_ids); i = i + 1 {
        if pool.running_ids[i] == request_id {
            pool.running_ids = append(pool.running_ids[:i], pool.running_ids[i+1:]...)
            pool.completed_ids = append(pool.completed_ids, request_id)
            return true
        }
    }
    return false
}

func (request_pool* pool) get_request(string request_id) active_request* {
    req, exists := pool.all_requests[request_id]
    if exists {
        return &req
    }
    return nil
}

func (request_pool* pool) get_pending_count() int32 {
    return int32(len(pool.pending_ids))
}

func (request_pool* pool) get_running_count() int32 {
    return int32(len(pool.running_ids))
}

func (request_pool* pool) cleanup_request(string request_id) bool {
    _, exists := pool.all_requests[request_id]
    if !exists {
        return false
    }
    
    delete(pool.all_requests, request_id)
    return true
}
