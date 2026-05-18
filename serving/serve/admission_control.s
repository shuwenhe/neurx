package neurx.serving.serve

struct admission_control_state {
    int capacity
    int max_tokens
    string policy
    int admitted
    int rejected
    float last_priority_score
}

func new_admission_control_state_with_policy(int capacity, int max_tokens, string policy) admission_control_state {
    if capacity <= 0 {
        capacity = 1
    }
    if max_tokens <= 0 {
        max_tokens = 1
    }
    admission_control_state {
        capacity: capacity,
        max_tokens: max_tokens,
        policy: policy,
        admitted: 0,
        rejected: 0,
        last_priority_score: 0.0,
    }
}

func admission_can_enqueue(admission_control_state state, int prefill_tokens, int remaining_tokens) bool {
    int total = prefill_tokens + remaining_tokens
    if state.admitted >= state.capacity {
        return false
    }
    if total > state.max_tokens {
        return false
    }
    true
}

func admission_can_enqueue_with_remaining(admission_control_state state, int active_requests, int prefill_tokens, int remaining_tokens) bool {
    // simple policy: respect capacity and max_tokens
    admission_can_enqueue(state, prefill_tokens, remaining_tokens)
}

func admission_on_enqueue(admission_control_state state, int prefill_tokens, bool accepted) admission_control_state {
    float priority = float(prefill_tokens)
    if accepted {
        admission_control_state {
            capacity: state.capacity,
            max_tokens: state.max_tokens,
            policy: state.policy,
            admitted: state.admitted + 1,
            rejected: state.rejected,
            last_priority_score: priority,
        }
    }
    admission_control_state {
        capacity: state.capacity,
        max_tokens: state.max_tokens,
        policy: state.policy,
        admitted: state.admitted,
        rejected: state.rejected + 1,
        last_priority_score: priority,
    }
}

func admission_on_enqueue_with_remaining(admission_control_state state, int prefill_tokens, int remaining_tokens, bool accepted) admission_control_state {
    admission_on_enqueue(state, prefill_tokens, accepted)
}

func admission_should_preempt(admission_control_state state, int incoming_priority, int running_priority) bool {
    // higher priority value should preempt lower
    incoming_priority > running_priority
}

func admission_state_dict(admission_control_state state) admission_control_state {
    state
}

func admission_load_state_dict(admission_control_state state, admission_control_state other) admission_control_state {
    other
}
