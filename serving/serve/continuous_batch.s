package neurx.serving.serve.continuous_batch
struct continuous_batch_state {
    int capacity
    int active_requests
    int queued_requests
    int total_served
    int scheduling_round
    int prefill_tokens
    int decode_tokens
}

func new_continuous_batch_state(int capacity) continuous_batch_state {
    int effective_capacity = capacity
    if effective_capacity <= 0 {
        effective_capacity = 1
    }
    continuous_batch_state {
        capacity: effective_capacity,
        active_requests: 0,
        queued_requests: 0,
        total_served: 0,
        scheduling_round: 0,
        prefill_tokens: 0,
        decode_tokens: 0,
    }
}

func continuous_batch_enqueue_request(continuous_batch_state state, int prefill_tokens) continuous_batch_state {
    int next_active = state.active_requests
    int next_queued = state.queued_requests
    if next_active < state.capacity {
        next_active = next_active + 1
    } else {
        next_queued = next_queued + 1
    }
    int add_prefill = prefill_tokens
    if add_prefill < 0 {
        add_prefill = 0
    }
    continuous_batch_state {
        capacity: state.capacity,
        active_requests: next_active,
        queued_requests: next_queued,
        total_served: state.total_served,
        scheduling_round: state.scheduling_round + 1,
        prefill_tokens: state.prefill_tokens + add_prefill,
        decode_tokens: state.decode_tokens,
    }
}

func continuous_batch_record_decode_step(continuous_batch_state state, int tokens) continuous_batch_state {
    int add_tokens = tokens
    if add_tokens < 0 {
        add_tokens = 0
    }
    continuous_batch_state {
        capacity: state.capacity,
        active_requests: state.active_requests,
        queued_requests: state.queued_requests,
        total_served: state.total_served,
        scheduling_round: state.scheduling_round + 1,
        prefill_tokens: state.prefill_tokens,
        decode_tokens: state.decode_tokens + add_tokens,
    }
}

func continuous_batch_finish_request(continuous_batch_state state) continuous_batch_state {
    int next_active = state.active_requests
    if next_active > 0 {
        next_active = next_active - 1
    }
    int next_queued = state.queued_requests
    if next_queued > 0 {
        next_queued = next_queued - 1
        if next_active < state.capacity {
            next_active = next_active + 1
        }
    }
    continuous_batch_state {
        capacity: state.capacity,
        active_requests: next_active,
        queued_requests: next_queued,
        total_served: state.total_served + 1,
        scheduling_round: state.scheduling_round + 1,
        prefill_tokens: state.prefill_tokens,
        decode_tokens: state.decode_tokens,
    }
}

func continuous_batch_state_dict(continuous_batch_state state) continuous_batch_state {
    state
}

func continuous_batch_load_state_dict(continuous_batch_state state, continuous_batch_state other) continuous_batch_state {
    other
}
