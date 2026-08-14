package neurx.serving.router.circuit_breaker
func circuit_closed() int { 0 }

func circuit_open() int { 1 }

func circuit_half_open() int { 2 }

struct circuit_breaker_config {
    int failure_threshold
    int success_threshold
    int open_timeout_ms
    int failure_window_ms
    int half_open_max_requests
}

struct circuit_breaker_state {
    circuit_breaker_config config
    int state
    int consecutive_failures
    int consecutive_successes
    int total_failures
    int total_successes
    int last_failure_ms
    int state_changed_ms
    int half_open_in_flight
}

struct circuit_admission_result {
    circuit_breaker_state state
    bool allowed
}

func new_circuit_breaker(circuit_breaker_config config, int now_ms) circuit_breaker_state {
    if config.failure_threshold <= 0 { config.failure_threshold = 1 }
    if config.success_threshold <= 0 { config.success_threshold = 1 }
    if config.open_timeout_ms < 0 { config.open_timeout_ms = 0 }
    if config.failure_window_ms <= 0 { config.failure_window_ms = 1 }
    if config.half_open_max_requests <= 0 { config.half_open_max_requests = 1 }
    circuit_breaker_state {
        config: config,
        state: circuit_closed(),
        consecutive_failures: 0,
        consecutive_successes: 0,
        total_failures: 0,
        total_successes: 0,
        last_failure_ms: 0,
        state_changed_ms: now_ms,
        half_open_in_flight: 0,
    }
}

func circuit_refresh(circuit_breaker_state state, int now_ms) circuit_breaker_state {
    if state.state == circuit_open() && now_ms - state.state_changed_ms >= state.config.open_timeout_ms {
        state.state = circuit_half_open()
        state.state_changed_ms = now_ms
        state.consecutive_failures = 0
        state.consecutive_successes = 0
        state.half_open_in_flight = 0
    }
    state
}

func circuit_try_acquire(circuit_breaker_state state, int now_ms) circuit_admission_result {
    circuit_breaker_state current = circuit_refresh(state, now_ms)
    if current.state == circuit_open() { return circuit_admission_result {state: current, allowed: false} }
    if current.state == circuit_half_open() {
        if current.half_open_in_flight >= current.config.half_open_max_requests { return circuit_admission_result {state: current, allowed: false} }
        current.half_open_in_flight = current.half_open_in_flight + 1
    }
    circuit_admission_result {state: current, allowed: true}
}

func circuit_record_success(circuit_breaker_state state, int now_ms) circuit_breaker_state {
    state.total_successes = state.total_successes + 1
    state.consecutive_failures = 0
    if state.state == circuit_half_open() {
        if state.half_open_in_flight > 0 { state.half_open_in_flight = state.half_open_in_flight - 1 }
        state.consecutive_successes = state.consecutive_successes + 1
        if state.consecutive_successes >= state.config.success_threshold {
            state.state = circuit_closed()
            state.state_changed_ms = now_ms
            state.consecutive_successes = 0
        }
    }
    state
}

func circuit_record_failure(circuit_breaker_state state, int now_ms) circuit_breaker_state {
    state.total_failures = state.total_failures + 1
    state.consecutive_successes = 0
    if state.state == circuit_half_open() {
        if state.half_open_in_flight > 0 { state.half_open_in_flight = state.half_open_in_flight - 1 }
        state.state = circuit_open()
        state.state_changed_ms = now_ms
        state.last_failure_ms = now_ms
        state.consecutive_failures = 1
        return state
    }
    if state.state == circuit_open() { return state }
    if state.last_failure_ms == 0 || now_ms - state.last_failure_ms > state.config.failure_window_ms { state.consecutive_failures = 0 }
    state.consecutive_failures = state.consecutive_failures + 1
    state.last_failure_ms = now_ms
    if state.consecutive_failures >= state.config.failure_threshold {
        state.state = circuit_open()
        state.state_changed_ms = now_ms
    }
    state
}
