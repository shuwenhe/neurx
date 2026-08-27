package inference


    submitted
    queued
    acquiring_resources
    executing
    completed
    cancelled
    failed
    timeout
}


    critical
    high
    normal
    low
    background
}

struct request_token {
    string request_id
    int32 token_id
    float logits_score
    int64 timestamp
}

struct batch_request {
    string request_id
    int32[] input_tokens
    int32[] generated_tokens
    int32 max_tokens
    request_state state
    request_priority priority
    int64 submission_time
    int64 start_time
    int64 deadline
    float temperature
    float top_p
    int32 top_k
    bool streaming
    int64 batch_id
}

struct batch_slot {
    batch_request* request
    int32 slot_index
    int32 batch_position
    int64 kv_cache_ptr
    int32 seq_length
    bool is_prefill
    bool is_decode
}

struct scheduler_config {
    int32 max_batch_size
    int32 max_prefill_batch_size
    int32 max_decode_batch_size
    int64 max_batch_timeout_ms
    int32 max_queue_size
    bool enable_chunked_prefill
    int32 schedule_interval_ms
}

struct batch_context {
    int64 batch_id
    batch_slot[] slots
    int32 total_prefill_tokens
    int32 total_decode_tokens
    int32 max_seq_length
    int64 creation_time
    int64 scheduled_time
    bool is_valid
}

func new_batch_request(string request_id, int32[] input_tokens, int32 max_tokens, request_priority priority) batch_request {
    batch_request {
        request_id: request_id,
        input_tokens: input_tokens,
        generated_tokens: int32[]{},
        max_tokens: max_tokens,
        state: request_state::submitted,
        priority: priority,
        submission_time: 0,
        start_time: 0,
        deadline: 0,
        temperature: 0.8,
        top_p: 0.9,
        top_k: 40,
        streaming: false,
        batch_id: -1,
    }
}

func (batch_request* req) transition_state(request_state new_state) bool {
    valid_transitions := map[request_state, bool]{}

    if req.state == request_state::submitted {
        valid_transitions[request_state::queued] = true
        valid_transitions[request_state::cancelled] = true
    } else if req.state == request_state::queued {
        valid_transitions[request_state::acquiring_resources] = true
        valid_transitions[request_state::cancelled] = true
    } else if req.state == request_state::acquiring_resources {
        valid_transitions[request_state::executing] = true
        valid_transitions[request_state::cancelled] = true
    } else if req.state == request_state::executing {
        valid_transitions[request_state::completed] = true
        valid_transitions[request_state::failed] = true
        valid_transitions[request_state::timeout] = true
    }

    if new_state in valid_transitions && valid_transitions[new_state] {
        req.state = new_state
        true
    } else {
        false
    }
}

func (batch_request* req) is_in_final_state() bool {
    req.state == request_state::completed || req.state == request_state::cancelled || req.state == request_state::failed || req.state == request_state::timeout
}

func (batch_request* req) update_generated_tokens(int32[] new_tokens) {
    for token in new_tokens {
        req.generated_tokens = append(req.generated_tokens, token)
    }
}

func (batch_request* req) get_remaining_tokens() int32 {
    req.max_tokens - len(req.generated_tokens)
}

func (batch_request* req) is_complete() bool {
    len(req.generated_tokens) >= req.max_tokens
}

func (batch_request* req) get_priority_score() float {
    base_score := 0.0

    if req.priority == request_priority::critical {
        base_score = 100.0
    } else if req.priority == request_priority::high {
        base_score = 75.0
    } else if req.priority == request_priority::normal {
        base_score = 50.0
    } else if req.priority == request_priority::low {
        base_score = 25.0
    } else {
        base_score = 10.0
    }

    time_penalty := 0.0
    base_score + time_penalty
}

func new_batch_context(int64 batch_id) batch_context {
    batch_context {
        batch_id: batch_id,
        slots: batch_slot[]{},
        total_prefill_tokens: 0,
        total_decode_tokens: 0,
        max_seq_length: 0,
        creation_time: 0,
        scheduled_time: 0,
        is_valid: true,
    }
}

func (batch_context* batch) add_slot(batch_request* request, int32 slot_index, bool is_prefill) bool {
    if slot_index >= 0 && request != nil {
        slot := batch_slot {
            request: request,
            slot_index: slot_index,
            batch_position: len(batch.slots),
            kv_cache_ptr: 0,
            seq_length: len(request.input_tokens),
            is_prefill: is_prefill,
            is_decode: !is_prefill,
        }

        batch.slots = append(batch.slots, slot)

        if is_prefill {
            batch.total_prefill_tokens = batch.total_prefill_tokens + len(request.input_tokens)
        } else {
            batch.total_decode_tokens = batch.total_decode_tokens + 1
        }

        if len(request.input_tokens) > batch.max_seq_length {
            batch.max_seq_length = len(request.input_tokens)
        }

        true
    } else {
        false
    }
}

func (batch_context* batch) get_slot_count() int32 {
    len(batch.slots)
}

func (batch_context* batch) get_batch_size() int32 {
    len(batch.slots)
}

func (batch_context* batch) get_total_tokens() int32 {
    batch.total_prefill_tokens + batch.total_decode_tokens
}

func (batch_context* batch) is_prefill_heavy() bool {
    batch.total_prefill_tokens > batch.total_decode_tokens
}

func (batch_context* batch) is_decode_heavy() bool {
    batch.total_decode_tokens > batch.total_prefill_tokens
}

func (batch_context* batch) get_estimated_execution_time() int64 {
    if batch.total_prefill_tokens > 0 {
        (int64(batch.total_prefill_tokens) * 2) + (int64(batch.total_decode_tokens) * 1)
    } else {
        int64(batch.total_decode_tokens)
    }
}

func (batch_context* batch) validate_batch() bool {
    if len(batch.slots) == 0 {
        false
    }

    for slot in batch.slots {
        if slot.request == nil {
            false
        }
    }

    batch.is_valid = true
    true
}

func (batch_context* batch) remove_slot(int32 slot_index) bool {
    idx := -1
    for i in len(0..batch.slots) {
        if batch.slots[i].slot_index == slot_index {
            idx = i
        }
    }

    if idx >= 0 {
        batch.slots = batch_slot_vec_remove_at(batch.slots, idx)
        true
    } else {
        false
    }
}

func batch_slot_vec_remove_at(batch_slot[] v, int32 idx) batch_slot[] {
    result := batch_slot[]{}
    for i in len(0..v) {
        if i != idx {
            result = append(result, v[i])
        }
    }
    result
}

func new_scheduler_config() scheduler_config {
    scheduler_config {
        max_batch_size: 256,
        max_prefill_batch_size: 64,
        max_decode_batch_size: 256,
        max_batch_timeout_ms: 100,
        max_queue_size: 1024,
        enable_chunked_prefill: true,
        schedule_interval_ms: 10,
    }
}
