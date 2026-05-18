package neurx.serving.serve

struct continuous_batch_state {
    int capacity
    int active_requests
    int decode_tokens
}

func new_continuous_batch_state(int capacity) continuous_batch_state {
    if capacity <= 0 {
        capacity = 1
    }
    continuous_batch_state {
        capacity: capacity,
        active_requests: 0,
        decode_tokens: 0,
    }
}

func continuous_batch_enqueue_request(continuous_batch_state state, int prefill_tokens) continuous_batch_state {
    continuous_batch_state {
        capacity: state.capacity,
        active_requests: state.active_requests + 1,
        decode_tokens: state.decode_tokens + prefill_tokens,
    }
}

func continuous_batch_record_decode_step(continuous_batch_state state, int tokens) continuous_batch_state {
    continuous_batch_state {
        capacity: state.capacity,
        active_requests: state.active_requests,
        decode_tokens: state.decode_tokens + tokens,
    }
}

func continuous_batch_finish_request(continuous_batch_state state) continuous_batch_state {
    int next_active = state.active_requests - 1
    if next_active < 0 {
        next_active = 0
    }
    continuous_batch_state {
        capacity: state.capacity,
        active_requests: next_active,
        decode_tokens: 0,
    }
}

func continuous_batch_state_dict(continuous_batch_state state) continuous_batch_state {
    state
}

func continuous_batch_load_state_dict(continuous_batch_state state, continuous_batch_state other) continuous_batch_state {
    other
}
