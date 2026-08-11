package neurx.inference.serve.request_lifecycle
func request_queued_status() int { 1 }
func request_prefilling_status() int { 2 }
func request_decoding_status() int { 3 }
func request_paused_status() int { 4 }
func request_finished_status() int { 5 }
func request_cancelled_status() int { 6 }
func request_failed_status() int { 7 }
struct request_lifecycle_state {
    string request_id
    int status
    int status_before_pause
    int prompt_tokens
    int generated_tokens
    int max_new_tokens
    int created_at_ms
    int updated_at_ms
    int deadline_ms
    string pause_reason
    string finish_reason
    string error_message
}

struct request_transition_result {
    request_lifecycle_state state
    bool changed
    string error_message
}

func new_request_transition_result(request_lifecycle_state state, bool changed, string error_message) request_transition_result {
    request_transition_result result
    result.state = state
    result.changed = changed
    result.error_message = error_message
    result
}

func new_request_lifecycle(string request_id, int prompt_tokens, int max_new_tokens, int now_ms, int timeout_ms) request_lifecycle_state {
    int normalized_prompt = prompt_tokens
    if normalized_prompt < 0 {
        normalized_prompt = 0
    }
    int normalized_max = max_new_tokens
    if normalized_max <= 0 {
        normalized_max = 1
    }
    int deadline = 0
    if timeout_ms > 0 {
        deadline = now_ms + timeout_ms
    }
    request_lifecycle_state {
        request_id: request_id,
        status: request_queued_status(),
        status_before_pause: request_queued_status(),
        prompt_tokens: normalized_prompt,
        generated_tokens: 0,
        max_new_tokens: normalized_max,
        created_at_ms: now_ms,
        updated_at_ms: now_ms,
        deadline_ms: deadline,
        pause_reason: "",
        finish_reason: "",
        error_message: "",
    }
}

func request_is_terminal(request_lifecycle_state state) bool {
    state.status == request_finished_status() || state.status == request_cancelled_status() || state.status == request_failed_status()
}

func request_remaining_tokens(request_lifecycle_state state) int {
    int remaining = state.max_new_tokens - state.generated_tokens
    if remaining < 0 {
        return 0
    }
    remaining
}

func request_transition(request_lifecycle_state state, int next_status, int now_ms) request_transition_result {
    if request_is_terminal(state) {
        return new_request_transition_result(state, false, "request is terminal")
    }
    bool allowed = false
    if state.status == request_queued_status() {
        allowed = next_status == request_prefilling_status() || next_status == request_paused_status() || next_status == request_cancelled_status() || next_status == request_failed_status()
    } else if state.status == request_prefilling_status() {
        allowed = next_status == request_decoding_status() || next_status == request_paused_status() || next_status == request_cancelled_status() || next_status == request_failed_status()
    } else if state.status == request_decoding_status() {
        allowed = next_status == request_finished_status() || next_status == request_paused_status() || next_status == request_cancelled_status() || next_status == request_failed_status()
    } else if state.status == request_paused_status() {
        allowed = next_status == state.status_before_pause || next_status == request_cancelled_status() || next_status == request_failed_status()
    }
    if !allowed {
        return new_request_transition_result(state, false, "invalid request state transition")
    }
    state.status = next_status
    state.updated_at_ms = now_ms
    new_request_transition_result(state, true, "")
}

func request_start_prefill(request_lifecycle_state state, int now_ms) request_transition_result {
    request_transition(state, request_prefilling_status(), now_ms)
}

func request_start_decode(request_lifecycle_state state, int now_ms) request_transition_result {
    request_transition(state, request_decoding_status(), now_ms)
}

func request_pause(request_lifecycle_state state, string reason, int now_ms) request_transition_result {
    if request_is_terminal(state) || state.status == request_paused_status() {
        return new_request_transition_result(state, false, "request cannot be paused")
    }
    int previous = state.status
    request_transition_result result = request_transition(state, request_paused_status(), now_ms)
    if result.changed {
        result.state.status_before_pause = previous
        result.state.pause_reason = reason
    }
    result
}

func request_resume(request_lifecycle_state state, int now_ms) request_transition_result {
    if state.status != request_paused_status() {
        return new_request_transition_result(state, false, "request is not paused")
    }
    request_transition_result result = request_transition(state, state.status_before_pause, now_ms)
    if result.changed {
        result.state.pause_reason = ""
    }
    result
}

func request_cancel(request_lifecycle_state state, int now_ms) request_transition_result {
    request_transition_result result = request_transition(state, request_cancelled_status(), now_ms)
    if result.changed {
        result.state.finish_reason = "cancelled"
    }
    result
}

func request_fail(request_lifecycle_state state, string message, int now_ms) request_transition_result {
    request_transition_result result = request_transition(state, request_failed_status(), now_ms)
    if result.changed {
        result.state.finish_reason = "error"
        result.state.error_message = message
    }
    result
}

func request_append_tokens(request_lifecycle_state state, int token_count, bool eos, int now_ms) request_transition_result {
    if state.status != request_decoding_status() {
        return new_request_transition_result(state, false, "request is not decoding")
    }
    int add_tokens = token_count
    if add_tokens < 0 {
        add_tokens = 0
    }
    state.generated_tokens = state.generated_tokens + add_tokens
    if state.generated_tokens > state.max_new_tokens {
        state.generated_tokens = state.max_new_tokens
    }
    state.updated_at_ms = now_ms
    if eos || state.generated_tokens >= state.max_new_tokens {
        state.status = request_finished_status()
        if eos {
            state.finish_reason = "stop"
        } else {
            state.finish_reason = "length"
        }
    }
    new_request_transition_result(state, add_tokens > 0 || eos, "")
}

func request_expire(request_lifecycle_state state, int now_ms) request_transition_result {
    if state.deadline_ms <= 0 || now_ms < state.deadline_ms || request_is_terminal(state) {
        return new_request_transition_result(state, false, "")
    }
    request_fail(state, "request deadline exceeded", now_ms)
}

func request_status_name(int status) string {
    if status == request_queued_status() { return "queued" }
    if status == request_prefilling_status() { return "prefilling" }
    if status == request_decoding_status() { return "decoding" }
    if status == request_paused_status() { return "paused" }
    if status == request_finished_status() { return "finished" }
    if status == request_cancelled_status() { return "cancelled" }
    if status == request_failed_status() { return "failed" }
    "unknown"
}
