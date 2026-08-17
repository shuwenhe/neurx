package neurx.inference.runtime.engine_sentinel

func engine_status_healthy() int { 1 }

func engine_status_unhealthy() int { 2 }

func engine_status_recovering() int { 3 }

func engine_status_dead() int { 4 }

struct engine_sentinel_config {
    int engine_index
    int recovery_timeout_ms
    int maximum_retries
    bool enabled
}

struct engine_sentinel_state {
    engine_sentinel_config config
    int status
    int fault_code
    int fault_time_ms
    int recovery_deadline_ms
    int retry_count
    int data_parallel_epoch
    int aborted_requests
    int cleared_batches
    bool resumed
    bool initialized
}

struct engine_recovery_result {
    engine_sentinel_state state
    bool accepted
    bool recovered
    int error_code
}

func init_engine_sentinel(engine_sentinel_config config) engine_sentinel_state {
    bool initialized = !config.enabled || (config.engine_index >= 0 && config.recovery_timeout_ms > 0 && config.maximum_retries >= 0)
    engine_sentinel_state {config: config, status: engine_status_healthy(), fault_code: 0, fault_time_ms: 0, recovery_deadline_ms: 0, retry_count: 0, data_parallel_epoch: 0, aborted_requests: 0, cleared_batches: 0, resumed: true, initialized: initialized}
}

func engine_sentinel_on_fault(engine_sentinel_state state, int fault_code, int now_ms, int aborted_requests, int queued_batches, bool executor_dead) engine_sentinel_state {
    if !state.initialized || !state.config.enabled { return state }
    state.status = engine_status_unhealthy()
    if executor_dead { state.status = engine_status_dead() }
    state.fault_code = fault_code
    state.fault_time_ms = now_ms
    state.recovery_deadline_ms = now_ms + state.config.recovery_timeout_ms
    state.aborted_requests = state.aborted_requests + aborted_requests
    state.cleared_batches = state.cleared_batches + queued_batches
    state.resumed = false
    state
}

func retry_engine_recovery(engine_sentinel_state state, int now_ms, bool worker_reinitialized) engine_recovery_result {
    if state.status != engine_status_unhealthy() { return engine_recovery_result {state: state, accepted: false, recovered: false, error_code: 1} }
    if now_ms > state.recovery_deadline_ms { state.status = engine_status_dead(); return engine_recovery_result {state: state, accepted: false, recovered: false, error_code: 2} }
    if state.retry_count >= state.config.maximum_retries { state.status = engine_status_dead(); return engine_recovery_result {state: state, accepted: false, recovered: false, error_code: 3} }
    state.status = engine_status_recovering()
    state.retry_count = state.retry_count + 1
    state.data_parallel_epoch = state.data_parallel_epoch + 1
    if worker_reinitialized {
        state.status = engine_status_healthy()
        state.fault_code = 0
        state.resumed = true
        return engine_recovery_result {state: state, accepted: true, recovered: true, error_code: 0}
    }
    state.status = engine_status_unhealthy()
    engine_recovery_result {state: state, accepted: true, recovered: false, error_code: 4}
}

func engine_sentinel_tick(engine_sentinel_state state, int now_ms) engine_sentinel_state {
    if state.status == engine_status_unhealthy() && now_ms > state.recovery_deadline_ms { state.status = engine_status_dead(); state.resumed = false }
    state
}
