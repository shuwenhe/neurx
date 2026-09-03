package neurx.distributed.inference.prefill_decode
struct prefill_request {
    int request_id
    string prompt_text
    int prompt_tokens
    int max_output_tokens
    float temperature
    int64 arrival_time_ns
}

struct decode_state {
    int request_id
    int current_seq_length
    int output_tokens_generated
    int max_output_tokens
    []int kv_block_ids
    []float logits_buffer
    int top_k
    float top_p
    bool is_finished
}

struct prefill_batch {
    int batch_id
    prefill_request[] requests
    int total_prompt_tokens
    int max_prompt_length
    []float batched_input_ids
    []float batched_attention_mask
    int batch_size
}

struct decode_batch {
    int batch_id
    decode_state[] requests
    int batch_size
    int current_step
    bool has_active_requests
}

struct prefill_decode_scheduler {
    int scheduler_id
    prefill_batch current_prefill_batch
    decode_batch current_decode_batch
    prefill_request[] prefill_queue
    decode_state[] decode_queue
    int max_prefill_batch_size
    int max_decode_batch_size
    int prefill_decode_split_point
    int64 last_prefill_time_ns
    int64 last_decode_time_ns
    int total_prefill_batches
    int total_decode_batches
    float prefill_latency_ms
    float decode_latency_per_token_ms
    float ttft_ms
}

func new_prefill_decode_scheduler(
    int scheduler_id,
    int max_prefill_batch_size,
    int max_decode_batch_size
) prefill_decode_scheduler {
    sched := prefill_decode_scheduler {
        scheduler_id: scheduler_id,
        current_prefill_batch: prefill_batch {
            batch_id: 0,
            requests: make([]prefill_request, max_prefill_batch_size),
            total_prompt_tokens: 0,
            max_prompt_length: 0,
            batched_input_ids: make([]float, max_prefill_batch_size * 4096),
            batched_attention_mask: make([]float, max_prefill_batch_size * 4096),
            batch_size: 0,
        },
        current_decode_batch: decode_batch {
            batch_id: 0,
            requests: make([]decode_state, max_decode_batch_size),
            batch_size: 0,
            current_step: 0,
            has_active_requests: false,
        },
        prefill_queue: make([]prefill_request, 1000),
        decode_queue: make([]decode_state, 10000),
        max_prefill_batch_size: max_prefill_batch_size,
        max_decode_batch_size: max_decode_batch_size,
        prefill_decode_split_point: max_prefill_batch_size / 4,
        last_prefill_time_ns: 0,
        last_decode_time_ns: 0,
        total_prefill_batches: 0,
        total_decode_batches: 0,
        prefill_latency_ms: 0.0,
        decode_latency_per_token_ms: 0.0,
        ttft_ms: 0.0,
    }
    return sched
}

func (prefill_decode_scheduler* sched) enqueue_prefill_request(
    prefill_request req
) {
    if len(sched.prefill_queue) < 1000 {
        sched.prefill_queue = append(sched.prefill_queue, req)
    }
}

func (prefill_decode_scheduler* sched) build_prefill_batch() (prefill_batch, bool) {
    if len(sched.prefill_queue) == 0 {
        return prefill_batch{}, false
    }
    new_batch := prefill_batch {
        batch_id: sched.total_prefill_batches,
        requests: make([]prefill_request, sched.max_prefill_batch_size),
        total_prompt_tokens: 0,
        max_prompt_length: 0,
        batched_input_ids: make([]float, sched.max_prefill_batch_size * 4096),
        batched_attention_mask: make([]float, sched.max_prefill_batch_size * 4096),
        batch_size: 0,
    }
    int batch_tokens = 0
    int req_idx = 0
    for req_idx < len(sched.prefill_queue) && new_batch.batch_size < sched.max_prefill_batch_size {
        prefill_request* req = &sched.prefill_queue[req_idx]
        if batch_tokens + req.prompt_tokens > sched.max_prefill_batch_size * 4096 {
            break
        }
        new_batch.requests = append(new_batch.requests, req)
        batch_tokens = batch_tokens + req.prompt_tokens
        if req.prompt_tokens > new_batch.max_prompt_length {
            new_batch.max_prompt_length = req.prompt_tokens
        }
        new_batch.batch_size = new_batch.batch_size + 1
        new_batch.total_prompt_tokens = new_batch.total_prompt_tokens + req.prompt_tokens
        req_idx = req_idx + 1
    }
    sched.prefill_queue = sched.prefill_queue[req_idx:]
    sched.total_prefill_batches = sched.total_prefill_batches + 1
    return new_batch, true
}

func (prefill_decode_scheduler* sched) execute_prefill_batch(
    prefill_batch* batch
) (decode_state[], bool) {
    decode_states := make([]decode_state, len(batch.requests))
    int req_idx = 0
    for req_idx < len(batch.requests) {
        prefill_request* req = &batch.requests[req_idx]
        decode_state := decode_state {
            request_id: req.request_id,
            current_seq_length: req.prompt_tokens,
            output_tokens_generated: 0,
            max_output_tokens: req.max_output_tokens,
            kv_block_ids: make([]int, (req.prompt_tokens + req.max_output_tokens + 15) / 16),
            logits_buffer: make([]float, 32000),
            top_k: 50,
            top_p: 0.9,
            is_finished: false,
        }
        int block_idx = 0
        blocks_needed := (req.prompt_tokens + 15) / 16
        for block_idx < blocks_needed {
            decode_state.kv_block_ids = append(decode_state.kv_block_ids, block_idx)
            block_idx = block_idx + 1
        }
        decode_states = append(decode_states, decode_state)
        req_idx = req_idx + 1
    }
    return decode_states, true
}

func (prefill_decode_scheduler* sched) build_decode_batch(
    decode_state[] prefilled_states
) (decode_batch, bool) {
    new_batch := decode_batch {
        batch_id: sched.total_decode_batches,
        requests: make([]decode_state, sched.max_decode_batch_size),
        batch_size: 0,
        current_step: 0,
        has_active_requests: true,
    }
    int state_idx = 0
    for state_idx < len(prefilled_states) && new_batch.batch_size < sched.max_decode_batch_size {
        new_batch.requests = append(new_batch.requests, prefilled_states[state_idx])
        new_batch.batch_size = new_batch.batch_size + 1
        state_idx = state_idx + 1
    }
    int queue_idx = 0
    for queue_idx < len(sched.decode_queue) && new_batch.batch_size < sched.max_decode_batch_size {
        new_batch.requests = append(new_batch.requests, sched.decode_queue[queue_idx])
        new_batch.batch_size = new_batch.batch_size + 1
        queue_idx = queue_idx + 1
    }
    if new_batch.batch_size > 0 {
        sched.total_decode_batches = sched.total_decode_batches + 1
        return new_batch, true
    }
    return new_batch, false
}

func (prefill_decode_scheduler* sched) decode_one_token_step(
    decode_batch* batch
) ([]float, bool) {
    logits := make([]float, batch.batch_size * 32000)
    int req_idx = 0
    active_count := 0
    for req_idx < len(batch.requests) {
        decode_state* state = &batch.requests[req_idx]
        if !state.is_finished {
            active_count = active_count + 1
            int logit_idx = 0
            for logit_idx < 32000 {
                logits[req_idx * 32000 + logit_idx] = 0.1
                logit_idx = logit_idx + 1
            }
            state.output_tokens_generated = state.output_tokens_generated + 1
            state.current_seq_length = state.current_seq_length + 1
            if state.output_tokens_generated >= state.max_output_tokens {
                state.is_finished = true
            }
        }
        req_idx = req_idx + 1
    }
    batch.current_step = batch.current_step + 1
    if active_count == 0 {
        batch.has_active_requests = false
        return logits, false
    }
    return logits, true
}

func (prefill_decode_scheduler* sched) get_decode_completion_status(
    decode_batch* batch
) (int, int, float) {
    total_finished := 0
    total_generated := 0
    int req_idx = 0
    for req_idx < len(batch.requests) {
        decode_state* state = &batch.requests[req_idx]
        if state.is_finished {
            total_finished = total_finished + 1
        }
        total_generated = total_generated + state.output_tokens_generated
        req_idx = req_idx + 1
    }
    completion_rate := float(total_finished) / float(len(batch.requests))
    return total_finished, total_generated, completion_rate
}

func (prefill_decode_scheduler* sched) can_prefill_and_decode_overlap() bool {
    if sched.current_prefill_batch.batch_size > 0 && sched.current_decode_batch.batch_size > 0 {
        return true
    }
    return false
}

func (prefill_decode_scheduler* sched) get_scheduler_stats() (int, int, int, float, float) {
    prefill_queue_len := len(sched.prefill_queue)
    decode_queue_len := len(sched.decode_queue)
    return prefill_queue_len,
           decode_queue_len,
           sched.total_prefill_batches + sched.total_decode_batches,
           sched.prefill_latency_ms,
           sched.decode_latency_per_token_ms
}

func (prefill_decode_scheduler* sched) update_latency_metrics(
    float prefill_ms,
    float decode_per_token_ms,
    float ttft_ms
) {
    sched.prefill_latency_ms = (sched.prefill_latency_ms * 0.9) + (prefill_ms * 0.1)
    sched.decode_latency_per_token_ms = (sched.decode_latency_per_token_ms * 0.9) + (decode_per_token_ms * 0.1)
    sched.ttft_ms = (sched.ttft_ms * 0.9) + (ttft_ms * 0.1)
}

func (prefill_decode_scheduler* sched) move_finished_to_completion(
    decode_batch* batch
) int {
    completed_count := 0
    int req_idx = 0
    remaining := make([]decode_state, len(batch.requests))
    for req_idx < len(batch.requests) {
        decode_state* state = &batch.requests[req_idx]
        if state.is_finished {
            completed_count = completed_count + 1
        } else {
            remaining = append(remaining, state)
        }
        req_idx = req_idx + 1
    }
    batch.requests = remaining
    batch.batch_size = len(remaining)
    if batch.batch_size == 0 {
        batch.has_active_requests = false
    }
    return completed_count
}

func (prefill_decode_scheduler* sched) should_pause_prefill_for_decode() bool {
    decode_utilization := float(len(sched.decode_queue)) / float(sched.max_decode_batch_size)
    if decode_utilization > 0.8 {
        return true
    }
    return false
}
