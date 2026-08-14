package neurx.distributed.ec_transfer
struct ec_transfer_config {
    string engine_id
    int rank
    int world_size
    int tensor_parallel_size
    int timeout_ms
    bool enabled
}

struct ec_transfer_state {
    ec_transfer_config config
    int next_request_id
    int active_requests
    int completed_requests
    int failed_requests
    int tensors_transferred
    int bytes_transferred
    bool initialized
    bool shutdown
    string error_message
}

struct ec_transfer_request {
    ec_transfer_state state
    int request_id
    int peer_rank
    int tensor_count
    int byte_count
    bool sending
    bool accepted
    string error_message
}

func ec_transfer_config_valid(ec_transfer_config config) bool {
    if !config.enabled { return true }
    if config.engine_id == "" || config.rank < 0 || config.world_size <= 1 || config.rank >= config.world_size { return false }
    if config.tensor_parallel_size <= 0 || config.timeout_ms <= 0 { return false }
    true
}

func init_ec_transfer(ec_transfer_config config) ec_transfer_state {
    bool initialized = config.enabled && ec_transfer_config_valid(config)
    string error_message = ""
    if config.enabled && !initialized { error_message = "invalid EC transfer configuration" }
    ec_transfer_state {config: config, next_request_id: 1, active_requests: 0, completed_requests: 0, failed_requests: 0, tensors_transferred: 0, bytes_transferred: 0, initialized: initialized, shutdown: false, error_message: error_message}
}

func begin_ec_transfer(ec_transfer_state state, int peer_rank, int tensor_count, int byte_count, bool sending) ec_transfer_request {
    if !state.initialized || state.shutdown || peer_rank < 0 || peer_rank >= state.config.world_size || peer_rank == state.config.rank || tensor_count <= 0 || byte_count <= 0 {
        return ec_transfer_request {state: state, request_id: 0, peer_rank: peer_rank, tensor_count: tensor_count, byte_count: byte_count, sending: sending, accepted: false, error_message: "invalid EC transfer request"}
    }
    int request_id = state.next_request_id
    state.next_request_id = state.next_request_id + 1
    state.active_requests = state.active_requests + 1
    ec_transfer_request {state: state, request_id: request_id, peer_rank: peer_rank, tensor_count: tensor_count, byte_count: byte_count, sending: sending, accepted: true, error_message: ""}
}

func finish_ec_transfer(ec_transfer_state state, int tensor_count, int byte_count, bool success, string error_message) ec_transfer_state {
    if state.active_requests > 0 { state.active_requests = state.active_requests - 1 }
    if success {
        state.completed_requests = state.completed_requests + 1
        state.tensors_transferred = state.tensors_transferred + tensor_count
        state.bytes_transferred = state.bytes_transferred + byte_count
    } else {
        state.failed_requests = state.failed_requests + 1
        state.error_message = error_message
    }
    state
}

func shutdown_ec_transfer(ec_transfer_state state) ec_transfer_state {
    state.failed_requests = state.failed_requests + state.active_requests
    state.active_requests = 0
    state.initialized = false
    state.shutdown = true
    state
}
