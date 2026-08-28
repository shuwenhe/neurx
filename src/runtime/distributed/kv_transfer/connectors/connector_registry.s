package neurx.distributed.kv_transfer.connectors
func kv_connector_nixl() int { 1 }

func kv_connector_mooncake() int { 2 }

func kv_connector_mooncake_store() int { 3 }

func kv_connector_lmcache() int { 4 }

func kv_connector_hf3fs() int { 5 }

func kv_connector_moriio() int { 6 }

func kv_connector_flexkv() int { 7 }

func kv_connector_cpu_offload() int { 8 }

func kv_connector_multi() int { 9 }

struct kv_connector_capability {
    int backend
    string name
    bool supports_send
    bool supports_receive
    bool supports_lookup
    bool supports_remote_store
    bool supports_layerwise
    bool supports_multi_process
}

struct kv_connector_config {
    int backend
    string endpoint
    string role
    int rank
    int world_size
    int timeout_ms
    bool layerwise
    bool enabled
}

struct kv_connector_state {
    kv_connector_config config
    kv_connector_capability capability
    int next_operation_id
    int active_operations
    int completed_operations
    int failed_operations
    int bytes_transferred
    bool connected
    bool shutdown
    string error_message
}

struct kv_connector_operation {
    kv_connector_state state
    int operation_id
    bool accepted
    string error_message
}

func kv_connector_capability_for(int backend) kv_connector_capability {
    if backend == kv_connector_nixl() { return kv_connector_capability {backend: backend, name: "nixl", supports_send: true, supports_receive: true, supports_lookup: false, supports_remote_store: false, supports_layerwise: true, supports_multi_process: true} }
    if backend == kv_connector_mooncake() { return kv_connector_capability {backend: backend, name: "mooncake", supports_send: true, supports_receive: true, supports_lookup: true, supports_remote_store: false, supports_layerwise: true, supports_multi_process: true} }
    if backend == kv_connector_mooncake_store() { return kv_connector_capability {backend: backend, name: "mooncake_store", supports_send: true, supports_receive: true, supports_lookup: true, supports_remote_store: true, supports_layerwise: true, supports_multi_process: true} }
    if backend == kv_connector_lmcache() { return kv_connector_capability {backend: backend, name: "lmcache", supports_send: true, supports_receive: true, supports_lookup: true, supports_remote_store: true, supports_layerwise: true, supports_multi_process: true} }
    if backend == kv_connector_hf3fs() { return kv_connector_capability {backend: backend, name: "hf3fs", supports_send: true, supports_receive: true, supports_lookup: true, supports_remote_store: true, supports_layerwise: false, supports_multi_process: true} }
    if backend == kv_connector_moriio() { return kv_connector_capability {backend: backend, name: "moriio", supports_send: true, supports_receive: true, supports_lookup: false, supports_remote_store: false, supports_layerwise: true, supports_multi_process: true} }
    if backend == kv_connector_flexkv() { return kv_connector_capability {backend: backend, name: "flexkv", supports_send: true, supports_receive: true, supports_lookup: true, supports_remote_store: true, supports_layerwise: true, supports_multi_process: true} }
    if backend == kv_connector_cpu_offload() { return kv_connector_capability {backend: backend, name: "cpu_offload", supports_send: true, supports_receive: true, supports_lookup: true, supports_remote_store: false, supports_layerwise: false, supports_multi_process: false} }
    kv_connector_capability {backend: kv_connector_multi(), name: "multi", supports_send: true, supports_receive: true, supports_lookup: true, supports_remote_store: true, supports_layerwise: true, supports_multi_process: true}
}

func kv_connector_config_valid(kv_connector_config config) bool {
    if !config.enabled { return true }
    if config.backend < kv_connector_nixl() || config.backend > kv_connector_multi() { return false }
    if config.role != "producer" && config.role != "consumer" && config.role != "worker" { return false }
    if config.rank < 0 || config.world_size <= 0 || config.rank >= config.world_size || config.timeout_ms <= 0 { return false }
    kv_connector_capability capability = kv_connector_capability_for(config.backend)
    if config.layerwise && !capability.supports_layerwise { return false }
    true
}

func init_kv_connector(kv_connector_config config) kv_connector_state {
    bool connected = config.enabled && kv_connector_config_valid(config)
    string error_message = ""
    if config.enabled && !connected { error_message = "invalid KV connector configuration" }
    kv_connector_state {config: config, capability: kv_connector_capability_for(config.backend), next_operation_id: 1, active_operations: 0, completed_operations: 0, failed_operations: 0, bytes_transferred: 0, connected: connected, shutdown: false, error_message: error_message}
}

func begin_kv_connector_operation(kv_connector_state state, int byte_count, bool sending) kv_connector_operation {
    bool role_allowed = state.config.role == "worker" || (sending && state.config.role == "producer") || (!sending && state.config.role == "consumer")
    bool capability_allowed = (sending && state.capability.supports_send) || (!sending && state.capability.supports_receive)
    if !state.connected || state.shutdown || byte_count <= 0 || !role_allowed || !capability_allowed {
        return kv_connector_operation {state: state, operation_id: 0, accepted: false, error_message: "KV connector operation is not permitted"}
    }
    int operation_id = state.next_operation_id
    state.next_operation_id = state.next_operation_id + 1
    state.active_operations = state.active_operations + 1
    kv_connector_operation {state: state, operation_id: operation_id, accepted: true, error_message: ""}
}

func finish_kv_connector_operation(kv_connector_state state, int byte_count, bool success, string error_message) kv_connector_state {
    if state.active_operations > 0 { state.active_operations = state.active_operations - 1 }
    if success {
        state.completed_operations = state.completed_operations + 1
        state.bytes_transferred = state.bytes_transferred + byte_count
    } else {
        state.failed_operations = state.failed_operations + 1
        state.error_message = error_message
    }
    state
}

func shutdown_kv_connector(kv_connector_state state) kv_connector_state {
    state.failed_operations = state.failed_operations + state.active_operations
    state.active_operations = 0
    state.connected = false
    state.shutdown = true
    state
}
