package neurx.inference.continuous_batching_v2
struct inference_request {
    int request_id
    []int prompt_tokens
    int max_new_tokens
    int generated_tokens
    int priority
    int arrival_time_ms
    float temperature
    float top_p
    int top_k
    bool is_finished
}

struct running_request {
    inference_request req
    []int generated_token_ids
    int kv_cache_blocks_used
    int current_position
    int start_time_ms
}

struct scheduler_policy {
    string algorithm
    bool enable_preemption
    int max_batch_size
    int max_total_tokens
    float preemption_threshold
}

struct scheduler_state {
    []inference_request pending_queue
    []running_request running_batch
    []inference_request preempted_queue
    scheduler_policy policy
    int current_time_ms
    int total_kv_blocks
    int used_kv_blocks
}

func new_scheduler_state(
    scheduler_policy policy,
    int total_kv_blocks) scheduler_state {
    scheduler_state {
        pending_queue: []inference_request{cap: 1024},
        running_batch: []running_request{cap: policy.max_batch_size},
        preempted_queue: []inference_request{cap: 256},
        policy: policy,
        current_time_ms: 0,
        total_kv_blocks: total_kv_blocks,
        used_kv_blocks: 0,
    }
}

func scheduler_enqueue_request(
    scheduler_state state,
    inference_request req) scheduler_state {
    req.arrival_time_ms = state.current_time_ms
    state.pending_queue.push(req)
    return state
}

func scheduler_schedule_batch(
    scheduler_state state) scheduler_state {
    if state.policy.algorithm == "fcfs" {
        return scheduler_fcfs(state)
    } else if state.policy.algorithm == "sjf" {
        return scheduler_sjf(state)
    } else if state.policy.algorithm == "priority" {
        return scheduler_priority(state)
    }
    return state
}

func scheduler_fcfs(scheduler_state state) scheduler_state {
    int req_idx = 0
    while req_idx < len(state.pending_queue) &&
          len(state.running_batch) < state.policy.max_batch_size {
        inference_request req = state.pending_queue[req_idx]
        int required_blocks = estimate_kv_blocks(req)
        if state.used_kv_blocks + required_blocks <= state.total_kv_blocks {
            running_request run_req = running_request {
                req: req,
                generated_token_ids: []int{cap: req.max_new_tokens},
                kv_cache_blocks_used: required_blocks,
                current_position: len(req.prompt_tokens),
                start_time_ms: state.current_time_ms,
            }
            state.running_batch.push(run_req)
            state.used_kv_blocks = state.used_kv_blocks + required_blocks
            state.pending_queue = remove_at_index(state.pending_queue, req_idx)
        } else {
            req_idx = req_idx + 1
        }
    }
    return state
}

func scheduler_sjf(scheduler_state state) scheduler_state {
    state.pending_queue = sort_by_estimated_time(state.pending_queue)
    return scheduler_fcfs(state)
}

func scheduler_priority(scheduler_state state) scheduler_state {
    state.pending_queue = sort_by_priority(state.pending_queue)
    return scheduler_fcfs(state)
}

func scheduler_preempt_requests(
    scheduler_state state,
    int required_blocks) scheduler_state {
    if !state.policy.enable_preemption {
        return state
    }
    int freed_blocks = 0
    int victim_idx = len(state.running_batch) - 1
    while victim_idx >= 0 && freed_blocks < required_blocks {
        running_request victim = state.running_batch[victim_idx]
        if is_preemptible(victim, state.policy.preemption_threshold) {
            freed_blocks = freed_blocks + victim.kv_cache_blocks_used
            state.used_kv_blocks = state.used_kv_blocks - victim.kv_cache_blocks_used
            victim.req.generated_tokens = len(victim.generated_token_ids)
            state.preempted_queue.push(victim.req)
            state.running_batch = remove_running_at_index(state.running_batch, victim_idx)
        }
        victim_idx = victim_idx - 1
    }
    return state
}

func is_preemptible(
    running_request req,
    float threshold) bool {
    int total_tokens = len(req.req.prompt_tokens) + req.req.max_new_tokens
    int progress = len(req.req.prompt_tokens) + len(req.generated_token_ids)
    float completion_ratio = float(progress) / float(total_tokens)
    return completion_ratio < threshold
}

func scheduler_finish_request(
    scheduler_state state,
    int request_id) scheduler_state {
    int req_idx = 0
    while req_idx < len(state.running_batch) {
        if state.running_batch[req_idx].req.request_id == request_id {
            int freed_blocks = state.running_batch[req_idx].kv_cache_blocks_used
            state.used_kv_blocks = state.used_kv_blocks - freed_blocks
            state.running_batch = remove_running_at_index(state.running_batch, req_idx)
            break
        }
        req_idx = req_idx + 1
    }
    return state
}

func scheduler_step(scheduler_state state) scheduler_state {
    state.current_time_ms = state.current_time_ms + 1
    int req_idx = 0
    while req_idx < len(state.running_batch) {
        state.running_batch[req_idx].generated_token_ids.push(0)
        if len(state.running_batch[req_idx].generated_token_ids) >=
           state.running_batch[req_idx].req.max_new_tokens {
            state.running_batch[req_idx].req.is_finished = true
        }
        req_idx = req_idx + 1
    }
    return state
}

func estimate_kv_blocks(inference_request req) int {
    int total_tokens = len(req.prompt_tokens) + req.max_new_tokens
    int block_size = 16
    return (total_tokens + block_size - 1) / block_size
}

func sort_by_estimated_time([]inference_request queue) []inference_request {
    int n = len(queue)
    int i = 0
    while i < n - 1 {
        int j = 0
        while j < n - i - 1 {
            int time_j = estimate_completion_time(queue[j])
            int time_j1 = estimate_completion_time(queue[j+1])
            if time_j > time_j1 {
                inference_request temp = queue[j]
                queue[j] = queue[j+1]
                queue[j+1] = temp
            }
            j = j + 1
        }
        i = i + 1
    }
    return queue
}

func sort_by_priority([]inference_request queue) []inference_request {
    int n = len(queue)
    int i = 0
    while i < n - 1 {
        int j = 0
        while j < n - i - 1 {
            if queue[j].priority < queue[j+1].priority {
                inference_request temp = queue[j]
                queue[j] = queue[j+1]
                queue[j+1] = temp
            }
            j = j + 1
        }
        i = i + 1
    }
    return queue
}

func estimate_completion_time(inference_request req) int {
    return len(req.prompt_tokens) + req.max_new_tokens
}

func remove_at_index([]inference_request arr, int idx) []inference_request {
    []inference_request result = []inference_request{cap: len(arr)}
    int i = 0
    while i < len(arr) {
        if i != idx {
            result.push(arr[i])
        }
        i = i + 1
    }
    return result
}

func remove_running_at_index([]running_request arr, int idx) []running_request {
    []running_request result = []running_request{cap: len(arr)}
    int i = 0
    while i < len(arr) {
        if i != idx {
            result.push(arr[i])
        }
        i = i + 1
    }
    return result
}

func scheduler_get_stats(scheduler_state state) scheduler_stats {
    int total_requests = len(state.pending_queue) +
                        len(state.running_batch) +
                        len(state.preempted_queue)
    int avg_wait_time = 0
    if len(state.pending_queue) > 0 {
        int total_wait = 0
        int i = 0
        while i < len(state.pending_queue) {
            total_wait = total_wait + (state.current_time_ms - state.pending_queue[i].arrival_time_ms)
            i = i + 1
        }
        avg_wait_time = total_wait / len(state.pending_queue)
    }
    float kv_utilization = float(state.used_kv_blocks) / float(state.total_kv_blocks)
    scheduler_stats {
        pending_count: len(state.pending_queue),
        running_count: len(state.running_batch),
        preempted_count: len(state.preempted_queue),
        total_requests: total_requests,
        avg_wait_time_ms: avg_wait_time,
        kv_cache_utilization: kv_utilization,
    }
}

struct scheduler_stats {
    int pending_count
    int running_count
    int preempted_count
    int total_requests
    int avg_wait_time_ms
    float kv_cache_utilization
}

