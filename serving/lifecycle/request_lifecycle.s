package neurx.serving.lifecycle.request_lifecycle
struct lifecycle_state {
    []string request_ids
    []string statuses
    []int deadlines_ms
    []int attempts
    []int max_retries
    []int next_retry_ms
    bool accepting_requests
    bool draining
    int active_requests
    int completed
    int cancelled
    int timed_out
    int retries
    int failed
}

func new_lifecycle_state() lifecycle_state {
    lifecycle_state {
        request_ids: [], statuses: [], deadlines_ms: [], attempts: [], max_retries: [], next_retry_ms: [],
        accepting_requests: true, draining: false, active_requests: 0,
        completed: 0, cancelled: 0, timed_out: 0, retries: 0, failed: 0,
    }
}

func lifecycle_find(lifecycle_state state, string request_id) int {
    int i = 0
    while i < len(state.request_ids) {
        if state.request_ids[i] == request_id { return i }
        i = i + 1
    }
    -1
}

func lifecycle_register(lifecycle_state state, string request_id, int now_ms, int timeout_ms, int max_retries) lifecycle_state {
    if !state.accepting_requests || request_id == "" || lifecycle_find(state, request_id) >= 0 { return state }
    if timeout_ms <= 0 { timeout_ms = 30000 }
    if max_retries < 0 { max_retries = 0 }
    state.request_ids = append(state.request_ids, request_id)
    state.statuses = append(state.statuses, "running")
    state.deadlines_ms = append(state.deadlines_ms, now_ms + timeout_ms)
    state.attempts = append(state.attempts, 1)
    state.max_retries = append(state.max_retries, max_retries)
    state.next_retry_ms = append(state.next_retry_ms, 0)
    state.active_requests = state.active_requests + 1
    state
}

func lifecycle_backoff_ms(int attempt) int {
    int delay = 100
    int i = 1
    while i < attempt && delay < 5000 {
        delay = delay * 2
        i = i + 1
    }
    if delay > 5000 { delay = 5000 }
    delay
}

func lifecycle_fail_attempt(lifecycle_state state, string request_id, int now_ms, bool retryable) lifecycle_state {
    int index = lifecycle_find(state, request_id)
    if index < 0 || state.statuses[index] != "running" { return state }
    if retryable && state.attempts[index] <= state.max_retries[index] && now_ms < state.deadlines_ms[index] {
        state.statuses[index] = "retry_wait"
        state.next_retry_ms[index] = now_ms + lifecycle_backoff_ms(state.attempts[index])
        state.retries = state.retries + 1
        return state
    }
    state.statuses[index] = "failed"
    state.active_requests = state.active_requests - 1
    if state.active_requests < 0 { state.active_requests = 0 }
    state.failed = state.failed + 1
    state
}

func lifecycle_tick(lifecycle_state state, int now_ms) lifecycle_state {
    int i = 0
    while i < len(state.request_ids) {
        if (state.statuses[i] == "running" || state.statuses[i] == "retry_wait") && now_ms >= state.deadlines_ms[i] {
            state.statuses[i] = "timed_out"
            state.active_requests = state.active_requests - 1
            state.timed_out = state.timed_out + 1
        } else if state.statuses[i] == "retry_wait" && now_ms >= state.next_retry_ms[i] {
            state.statuses[i] = "running"
            state.attempts[i] = state.attempts[i] + 1
        }
        i = i + 1
    }
    if state.active_requests < 0 { state.active_requests = 0 }
    state
}

func lifecycle_cancel(lifecycle_state state, string request_id) lifecycle_state {
    int index = lifecycle_find(state, request_id)
    if index < 0 || (state.statuses[index] != "running" && state.statuses[index] != "retry_wait") { return state }
    state.statuses[index] = "cancelled"
    state.active_requests = state.active_requests - 1
    if state.active_requests < 0 { state.active_requests = 0 }
    state.cancelled = state.cancelled + 1
    state
}

func lifecycle_complete(lifecycle_state state, string request_id) lifecycle_state {
    int index = lifecycle_find(state, request_id)
    if index < 0 || state.statuses[index] != "running" { return state }
    state.statuses[index] = "completed"
    state.active_requests = state.active_requests - 1
    if state.active_requests < 0 { state.active_requests = 0 }
    state.completed = state.completed + 1
    state
}

func lifecycle_begin_shutdown(lifecycle_state state) lifecycle_state {
    state.accepting_requests = false
    state.draining = true
    state
}

func lifecycle_shutdown_complete(lifecycle_state state) bool {
    state.draining && state.active_requests == 0
}

