package neurx.serving.serve.admission_control
struct admission_control_state {
    int max_active_requests
    int max_prefill_tokens
    string policy
    int current_prefill_tokens
    int current_decode_tokens
    int admitted
    int rejected
    int last_remaining_tokens
    int last_priority_score
}


func normalize_policy(string policy) string {
    if policy == "srpt" {
        return "srpt"
    }
    "fcfs"
}


func new_admission_control_state_with_policy(int max_active_requests, int max_prefill_tokens, string policy) admission_control_state {
    int normalized_active = max_active_requests
    if normalized_active <= 0 {
        normalized_active = 1
    }
    int normalized_prefill = max_prefill_tokens
    if normalized_prefill <= 0 {
        normalized_prefill = 1
    }
    string normalized_policy = normalize_policy(policy)
    admission_control_state {
        max_active_requests: normalized_active,
        max_prefill_tokens: normalized_prefill,
        policy: normalized_policy,
        current_prefill_tokens: 0,
        current_decode_tokens: 0,
        admitted: 0,
        rejected: 0,
        last_remaining_tokens: 0,
        last_priority_score: 0,
    }
}


func new_admission_control_state(int max_active_requests, int max_prefill_tokens) admission_control_state {
    new_admission_control_state_with_policy(max_active_requests, max_prefill_tokens, "fcfs")
}


func admission_priority_score(admission_control_state state, int remaining_tokens, int queue_depth) int {
    int normalized_remaining = remaining_tokens
    if normalized_remaining < 0 {
        normalized_remaining = 0
    }
    int normalized_queue = queue_depth
    if normalized_queue < 0 {
        normalized_queue = 0
    }
    if state.policy == "srpt" {
        return normalized_remaining
    }
    normalized_queue
}


func admission_should_preempt(admission_control_state state, int running_remaining_tokens, int candidate_remaining_tokens) bool {
    if state.policy != "srpt" {
        return false
    }
    int running_score = admission_priority_score(state, running_remaining_tokens, 0)
    int candidate_score = admission_priority_score(state, candidate_remaining_tokens, 0)
    candidate_score < running_score
}


func admission_can_enqueue_with_remaining(admission_control_state state, int active_requests, int prefill_tokens, int remaining_tokens) bool {
    int add_prefill = prefill_tokens
    if add_prefill < 0 {
        add_prefill = 0
    }
    int normalized_remaining = remaining_tokens
    if normalized_remaining < 0 {
        normalized_remaining = 0
    }
    if active_requests >= state.max_active_requests {
        return false
    }
    if state.current_prefill_tokens + add_prefill > state.max_prefill_tokens {
        return false
    }
    if state.policy == "srpt" && normalized_remaining > state.max_prefill_tokens {
        return false
    }
    true
}


func admission_can_enqueue(admission_control_state state, int active_requests, int prefill_tokens) bool {
    admission_can_enqueue_with_remaining(state, active_requests, prefill_tokens, prefill_tokens)
}


func admission_on_enqueue_with_remaining(admission_control_state state, int prefill_tokens, int remaining_tokens, bool accepted) admission_control_state {
    int add_prefill = prefill_tokens
    if add_prefill < 0 {
        add_prefill = 0
    }
    int normalized_remaining = remaining_tokens
    if normalized_remaining < 0 {
        normalized_remaining = 0
    }
    if !accepted {
        return admission_control_state {
            max_active_requests: state.max_active_requests,
            max_prefill_tokens: state.max_prefill_tokens,
            policy: state.policy,
            current_prefill_tokens: state.current_prefill_tokens,
            current_decode_tokens: state.current_decode_tokens,
            admitted: state.admitted,
            rejected: state.rejected + 1,
            last_remaining_tokens: state.last_remaining_tokens,
            last_priority_score: state.last_priority_score,
        }
    }
    int priority_score = admission_priority_score(state, normalized_remaining, state.admitted + state.rejected)
    admission_control_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        policy: state.policy,
        current_prefill_tokens: state.current_prefill_tokens + add_prefill,
        current_decode_tokens: state.current_decode_tokens,
        admitted: state.admitted + 1,
        rejected: state.rejected,
        last_remaining_tokens: normalized_remaining,
        last_priority_score: priority_score,
    }
}


func admission_on_enqueue(admission_control_state state, int prefill_tokens, bool accepted) admission_control_state {
    admission_on_enqueue_with_remaining(state, prefill_tokens, prefill_tokens, accepted)
}


func admission_on_decode_step(admission_control_state state, int decode_tokens) admission_control_state {
    int add_decode = decode_tokens
    if add_decode < 0 {
        add_decode = 0
    }
    admission_control_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        policy: state.policy,
        current_prefill_tokens: state.current_prefill_tokens,
        current_decode_tokens: state.current_decode_tokens + add_decode,
        admitted: state.admitted,
        rejected: state.rejected,
        last_remaining_tokens: state.last_remaining_tokens,
        last_priority_score: state.last_priority_score,
    }
}


func admission_on_finish(admission_control_state state, int release_prefill_tokens) admission_control_state {
    int release_tokens = release_prefill_tokens
    if release_tokens < 0 {
        release_tokens = 0
    }
    int next_prefill = state.current_prefill_tokens - release_tokens
    if next_prefill < 0 {
        next_prefill = 0
    }
    admission_control_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        policy: state.policy,
        current_prefill_tokens: next_prefill,
        current_decode_tokens: state.current_decode_tokens,
        admitted: state.admitted,
        rejected: state.rejected,
        last_remaining_tokens: state.last_remaining_tokens,
        last_priority_score: state.last_priority_score,
    }
}


func admission_control_state_dict(admission_control_state state) admission_control_state {
    state
}


func admission_control_load_state_dict(admission_control_state state, admission_control_state other) admission_control_state {
    other
}

