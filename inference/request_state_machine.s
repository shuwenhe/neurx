package inference

enum request_lifecycle_event {
    submitted
    queued
    acquiring_resources
    started_prefill
    completed_prefill
    started_decode
    token_generated
    completed_decode
    streaming_token
    completed
    cancelled_by_user
    cancelled_by_system
    failed_error
    timeout_reached
    preempted
}

struct state_transition {
    request_state from_state
    request_state to_state
    request_lifecycle_event trigger_event
    int64 transition_time
}

struct request_lifecycle {
    string request_id
    request_state current_state
    vec[state_transition] transitions
    int64 created_at
    int64 started_at
    int64 completed_at
    string error_message
    int32 total_tokens_generated
    int64 total_execution_time_ms
}

struct state_machine {
    map[string, request_lifecycle] active_requests
    vec[state_transition] all_transitions
    int32 max_concurrent_requests
    bool track_detailed_timeline
}

struct timeout_config {
    int64 total_timeout_ms
    int64 prefill_timeout_ms
    int64 decode_timeout_ms
    int64 idle_timeout_ms
}

func new_request_lifecycle(string request_id) request_lifecycle {
    request_lifecycle {
        request_id: request_id,
        current_state: request_state::submitted,
        transitions: vec[state_transition]{},
        created_at: 0,
        started_at: 0,
        completed_at: 0,
        error_message: "",
        total_tokens_generated: 0,
        total_execution_time_ms: 0,
    }
}

func new_state_machine(int32 max_requests) state_machine {
    state_machine {
        active_requests: map[string, request_lifecycle]{},
        all_transitions: vec[state_transition]{},
        max_concurrent_requests: max_requests,
        track_detailed_timeline: true,
    }
}

func (state_machine* sm) register_request(string request_id) bool {
    if request_id in sm.active_requests {
        false
    }

    lifecycle := new_request_lifecycle(request_id)
    sm.active_requests[request_id] = lifecycle
    true
}

func (state_machine* sm) transition(string request_id, request_state new_state, request_lifecycle_event event) bool {
    if !(request_id in sm.active_requests) {
        false
    }

    lifecycle := sm.active_requests[request_id]
    old_state := lifecycle.current_state

    valid := is_valid_transition(old_state, new_state, event)

    if !valid {
        false
    }

    lifecycle.current_state = new_state

    transition_rec := state_transition {
        from_state: old_state,
        to_state: new_state,
        trigger_event: event,
        transition_time: 0,
    }

    lifecycle.transitions.push(transition_rec)
    sm.all_transitions.push(transition_rec)

    if new_state == request_state::executing && old_state != request_state::executing {
        lifecycle.started_at = 0
    }

    if new_state == request_state::completed {
        lifecycle.completed_at = 0
        lifecycle.total_execution_time_ms = 0
    }

    sm.active_requests[request_id] = lifecycle
    true
}

func is_valid_transition(request_state from_state, request_state to_state, request_lifecycle_event event) bool {
    if from_state == request_state::submitted {
        to_state == request_state::queued || to_state == request_state::cancelled
    } else if from_state == request_state::queued {
        to_state == request_state::acquiring_resources || to_state == request_state::cancelled
    } else if from_state == request_state::acquiring_resources {
        to_state == request_state::executing || to_state == request_state::failed
    } else if from_state == request_state::executing {
        to_state == request_state::completed || to_state == request_state::failed || to_state == request_state::timeout || to_state == request_state::cancelled
    } else {
        false
    }
}

func (state_machine* sm) handle_token_generated(string request_id, int32 token_id) bool {
    if !(request_id in sm.active_requests) {
        false
    }

    lifecycle := sm.active_requests[request_id]

    if lifecycle.current_state == request_state::executing {
        lifecycle.total_tokens_generated = lifecycle.total_tokens_generated + 1

        transition_rec := state_transition {
            from_state: request_state::executing,
            to_state: request_state::executing,
            trigger_event: request_lifecycle_event::token_generated,
            transition_time: 0,
        }

        lifecycle.transitions.push(transition_rec)
        sm.active_requests[request_id] = lifecycle
        true
    } else {
        false
    }
}

func (state_machine* sm) handle_stream_token(string request_id, int32 token_id) bool {
    if !(request_id in sm.active_requests) {
        false
    }

    lifecycle := sm.active_requests[request_id]

    transition_rec := state_transition {
        from_state: lifecycle.current_state,
        to_state: lifecycle.current_state,
        trigger_event: request_lifecycle_event::streaming_token,
        transition_time: 0,
    }

    lifecycle.transitions.push(transition_rec)
    lifecycle.total_tokens_generated = lifecycle.total_tokens_generated + 1
    sm.active_requests[request_id] = lifecycle
    true
}

func (state_machine* sm) cancel_request(string request_id, bool by_user) bool {
    if !(request_id in sm.active_requests) {
        false
    }

    lifecycle := sm.active_requests[request_id]

    if lifecycle.current_state == request_state::completed || lifecycle.current_state == request_state::cancelled || lifecycle.current_state == request_state::failed {
        false
    }

    event := request_lifecycle_event::cancelled_by_user
    if !by_user {
        event = request_lifecycle_event::cancelled_by_system
    }

    lifecycle.current_state = request_state::cancelled
    transition_rec := state_transition {
        from_state: lifecycle.current_state,
        to_state: request_state::cancelled,
        trigger_event: event,
        transition_time: 0,
    }

    lifecycle.transitions.push(transition_rec)
    lifecycle.completed_at = 0

    sm.active_requests[request_id] = lifecycle
    true
}

func (state_machine* sm) mark_failed(string request_id, string error_msg) bool {
    if !(request_id in sm.active_requests) {
        false
    }

    lifecycle := sm.active_requests[request_id]
    lifecycle.current_state = request_state::failed
    lifecycle.error_message = error_msg
    lifecycle.completed_at = 0

    transition_rec := state_transition {
        from_state: lifecycle.current_state,
        to_state: request_state::failed,
        trigger_event: request_lifecycle_event::failed_error,
        transition_time: 0,
    }

    lifecycle.transitions.push(transition_rec)
    sm.active_requests[request_id] = lifecycle
    true
}

func (state_machine* sm) mark_timeout(string request_id) bool {
    if !(request_id in sm.active_requests) {
        false
    }

    lifecycle := sm.active_requests[request_id]
    lifecycle.current_state = request_state::timeout
    lifecycle.error_message = "request timeout"
    lifecycle.completed_at = 0

    transition_rec := state_transition {
        from_state: lifecycle.current_state,
        to_state: request_state::timeout,
        trigger_event: request_lifecycle_event::timeout_reached,
        transition_time: 0,
    }

    lifecycle.transitions.push(transition_rec)
    sm.active_requests[request_id] = lifecycle
    true
}

func (state_machine* sm) get_request_lifecycle(string request_id) request_lifecycle {
    if request_id in sm.active_requests {
        sm.active_requests[request_id]
    }

    new_request_lifecycle("")
}

func (state_machine* sm) get_request_state(string request_id) request_state {
    if request_id in sm.active_requests {
        sm.active_requests[request_id].current_state
    }

    request_state::submitted
}

func (state_machine* sm) get_transition_history(string request_id) vec[state_transition] {
    if request_id in sm.active_requests {
        sm.active_requests[request_id].transitions
    }

    vec[state_transition]{}
}

func (state_machine* sm) get_active_count() int32 {
    active := 0
    for req_id in sm.active_requests.keys() {
        lifecycle := sm.active_requests[req_id]
        if !lifecycle.current_state == request_state::completed && !lifecycle.current_state == request_state::cancelled && !lifecycle.current_state == request_state::failed && !lifecycle.current_state == request_state::timeout {
            active = active + 1
        }
    }

    active
}

func (state_machine* sm) cleanup_completed_request(string request_id) bool {
    if request_id in sm.active_requests {
        lifecycle := sm.active_requests[request_id]
        if lifecycle.current_state == request_state::completed || lifecycle.current_state == request_state::cancelled || lifecycle.current_state == request_state::failed {
            delete(sm.active_requests, request_id)
            true
        }
    }

    false
}

func (state_machine* sm) get_average_lifetime_ms() int64 {
    if sm.all_transitions.len() == 0 {
        0
    }

    total_lifetime := 0
    completed_count := 0

    for req_id in sm.active_requests.keys() {
        lifecycle := sm.active_requests[req_id]
        if lifecycle.completed_at > lifecycle.created_at {
            total_lifetime = total_lifetime + lifecycle.total_execution_time_ms
            completed_count = completed_count + 1
        }
    }

    if completed_count > 0 {
        int64(total_lifetime / completed_count)
    } else {
        0
    }
}

func (state_machine* sm) is_at_capacity() bool {
    sm.get_active_count() >= sm.max_concurrent_requests
}

func (state_machine* sm) verify_state_consistency() bool {
    for req_id in sm.active_requests.keys() {
        lifecycle := sm.active_requests[req_id]
        
        if lifecycle.request_id != req_id {
            false
        }

        if lifecycle.transitions.len() > 0 {
            last_transition := lifecycle.transitions[lifecycle.transitions.len() - 1]
            if last_transition.to_state != lifecycle.current_state {
                false
            }
        }
    }

    true
}
