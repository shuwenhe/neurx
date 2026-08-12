package neurx.runtime
struct runtime_state {
    bool available
    bool ops_backend_enabled
    string artifact_root
    []string ir_files
}
func new_runtime_state(bool available, bool ops_backend_enabled, string artifact_root, []string ir_files) runtime_state {
    runtime_state {
        available: available,
        ops_backend_enabled: ops_backend_enabled,
        artifact_root: artifact_root,
        ir_files: ir_files,
    }
}
func runtime_state_dict(runtime_state state) runtime_state {
    state
}
func runtime_state_load_state_dict(runtime_state state, runtime_state other) runtime_state {
    other
}
func runtime_available(runtime_state state) bool {
    state.available
}
func ops_runtime_enabled(runtime_state state) bool {
    state.ops_backend_enabled
}
func runtime_artifact_root(runtime_state state) string {
    state.artifact_root
}
func runtime_ir_files(runtime_state state) []string {
    state.ir_files
}
func runtime_ir_count(runtime_state state) int {
    len(state.ir_files)
}
func runtime_has_ir_files(runtime_state state) bool {
    len(state.ir_files) > 0
}
func runtime_is_ready(runtime_state state) bool {
    state.available && len(state.ir_files) > 0
}
func runtime_ir_paths(runtime_state state) []string {
    state.ir_files
}
func runtime_status(runtime_state state) runtime_state {
    state
}
