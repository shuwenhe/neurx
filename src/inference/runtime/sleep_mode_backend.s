package neurx.inference.runtime.sleep_mode_backend
func sleep_backend_cumem() int { 1 }
func sleep_backend_cuda_checkpoint() int { 2 }
func sleep_backend_criu() int { 3 }
func sleep_backend_durable_snapshot() int { 4 }
func sleep_state_running() int { 1 }
func sleep_state_suspended() int { 2 }
func sleep_state_resuming() int { 3 }
func sleep_state_failed() int { 4 }
struct sleep_backend_capability {
    int backend
    bool supported
    bool preserves_communicators
    bool preserves_compiled_artifacts
    bool preserves_graphs_with_communicators
    bool supports_durable_storage
}
struct sleep_mode_state {
    sleep_backend_capability capability
    int state
    int suspend_level
    int released_weight_bytes
    int released_kv_bytes
    int suspend_count
    int resume_count
    bool communicator_reinit_required
    bool initialized
}
struct sleep_transition_result {
    sleep_mode_state state
    bool success
    int error_code
}
func sleep_capability_for(int backend, bool backend_available) sleep_backend_capability {
    if backend == sleep_backend_cumem() { return sleep_backend_capability {backend: backend, supported: backend_available, preserves_communicators: true, preserves_compiled_artifacts: true, preserves_graphs_with_communicators: true, supports_durable_storage: false} }
    if backend == sleep_backend_cuda_checkpoint() { return sleep_backend_capability {backend: backend, supported: backend_available, preserves_communicators: false, preserves_compiled_artifacts: true, preserves_graphs_with_communicators: false, supports_durable_storage: false} }
    if backend == sleep_backend_criu() { return sleep_backend_capability {backend: backend, supported: backend_available, preserves_communicators: false, preserves_compiled_artifacts: false, preserves_graphs_with_communicators: false, supports_durable_storage: true} }
    if backend == sleep_backend_durable_snapshot() { return sleep_backend_capability {backend: backend, supported: backend_available, preserves_communicators: false, preserves_compiled_artifacts: false, preserves_graphs_with_communicators: false, supports_durable_storage: true} }
    sleep_backend_capability {backend: backend, supported: false, preserves_communicators: false, preserves_compiled_artifacts: false, preserves_graphs_with_communicators: false, supports_durable_storage: false}
}
func init_sleep_mode(int backend, bool backend_available) sleep_mode_state {
    sleep_backend_capability capability = sleep_capability_for(backend, backend_available)
    sleep_mode_state {capability: capability, state: sleep_state_running(), suspend_level: 0, released_weight_bytes: 0, released_kv_bytes: 0, suspend_count: 0, resume_count: 0, communicator_reinit_required: false, initialized: capability.supported}
}
func suspend_sleep_mode(sleep_mode_state state, int level, int weight_bytes, int kv_bytes) sleep_transition_result {
    if !state.initialized || state.state != sleep_state_running() || (level != 1 && level != 2) { return sleep_transition_result {state: state, success: false, error_code: 1} }
    state.state = sleep_state_suspended()
    state.suspend_level = level
    state.released_weight_bytes = weight_bytes
    if level == 2 { state.released_kv_bytes = kv_bytes }
    state.suspend_count = state.suspend_count + 1
    state.communicator_reinit_required = !state.capability.preserves_communicators
    sleep_transition_result {state: state, success: true, error_code: 0}
}
func resume_sleep_mode(sleep_mode_state state, bool communicator_reinitialized, bool artifacts_restored) sleep_transition_result {
    if !state.initialized || state.state != sleep_state_suspended() { return sleep_transition_result {state: state, success: false, error_code: 1} }
    state.state = sleep_state_resuming()
    if state.communicator_reinit_required && !communicator_reinitialized { state.state = sleep_state_failed(); return sleep_transition_result {state: state, success: false, error_code: 2} }
    if !state.capability.preserves_compiled_artifacts && !artifacts_restored { state.state = sleep_state_failed(); return sleep_transition_result {state: state, success: false, error_code: 3} }
    state.state = sleep_state_running()
    state.released_weight_bytes = 0
    state.released_kv_bytes = 0
    state.communicator_reinit_required = false
    state.resume_count = state.resume_count + 1
    sleep_transition_result {state: state, success: true, error_code: 0}
}
