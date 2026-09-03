package neurx.distributed.kv_transfer
struct kv_transfer_config {
    string connector
    string engine_id
    string role
    int rank
    int world_size
    bool enabled
}

struct kv_transfer_state {
    kv_transfer_config config
    bool initialized
    bool shutdown
    int next_request_id
    int active_transfers
    int completed_transfers
    int failed_transfers
    int bytes_sent
    int bytes_received
    string error_message
}

struct kv_transfer_request {
    int request_id
    []int block_ids
    int source_rank
    int destination_rank
    int token_count
    int byte_count
    bool is_sender
    bool completed
    bool success
    string error_message
}

struct kv_transfer_begin_result {
    kv_transfer_state state
    kv_transfer_request request
    bool success
    string error_message
}

func copy_kv_block_ids([]int block_ids) []int {
    []int copied = make([]int, len(block_ids))
    int i = 0
    for i < len(block_ids) {
        copied[i] = block_ids[i]
        i = i + 1
    }
    copied
}

func kv_transfer_config_valid(kv_transfer_config config) bool {
    if !config.enabled {
        return true
    }
    if config.connector == "" || config.engine_id == "" {
        return false
    }
    if config.role != "producer" && config.role != "consumer" && config.role != "worker" {
        return false
    }
    config.world_size > 0 && config.rank >= 0 && config.rank < config.world_size
}

func ensure_kv_transfer_initialized(kv_transfer_config config) kv_transfer_state {
    bool initialized = config.enabled && kv_transfer_config_valid(config)
    string error_message = ""
    if config.enabled && !initialized {
        error_message = "invalid KV transfer configuration"
    }
    kv_transfer_state {
        config: config,
        initialized: initialized,
        shutdown: false,
        next_request_id: 1,
        active_transfers: 0,
        completed_transfers: 0,
        failed_transfers: 0,
        bytes_sent: 0,
        bytes_received: 0,
        error_message: error_message,
    }
}

func has_kv_transfer_group(kv_transfer_state state) bool {
    state.initialized && !state.shutdown
}

func kv_transfer_state_after_begin(kv_transfer_state state) kv_transfer_state {
    kv_transfer_state {
        config: state.config,
        initialized: state.initialized,
        shutdown: state.shutdown,
        next_request_id: state.next_request_id + 1,
        active_transfers: state.active_transfers + 1,
        completed_transfers: state.completed_transfers,
        failed_transfers: state.failed_transfers,
        bytes_sent: state.bytes_sent,
        bytes_received: state.bytes_received,
        error_message: state.error_message,
    }
}

func empty_kv_transfer_request() kv_transfer_request {
    kv_transfer_request {
        request_id: 0,
        block_ids: [],
        source_rank: 0,
        destination_rank: 0,
        token_count: 0,
        byte_count: 0,
        is_sender: false,
        completed: false,
        success: false,
        error_message: "",
    }
}

func new_kv_transfer_request(int request_id, []int block_ids, int source_rank, int destination_rank, int token_count, int byte_count, bool is_sender) kv_transfer_request {
    kv_transfer_request {
        request_id: request_id,
        block_ids: copy_kv_block_ids(block_ids),
        source_rank: source_rank,
        destination_rank: destination_rank,
        token_count: token_count,
        byte_count: byte_count,
        is_sender: is_sender,
        completed: false,
        success: false,
        error_message: "",
    }
}

func begin_kv_transfer(kv_transfer_state state, []int block_ids, int peer_rank, int token_count, int byte_count) kv_transfer_begin_result {
    bool is_sender = state.config.role == "producer"
    if !has_kv_transfer_group(state) {
        return kv_transfer_begin_result {
            state: state,
            request: empty_kv_transfer_request(),
            success: false,
            error_message: "KV transfer group is not initialized",
        }
    }
    if len(block_ids) == 0 || peer_rank < 0 || peer_rank >= state.config.world_size || peer_rank == state.config.rank || token_count < 0 {
        return kv_transfer_begin_result {
            state: state,
            request: empty_kv_transfer_request(),
            success: false,
            error_message: "invalid KV transfer request",
        }
    }
    int source_rank = peer_rank
    int destination_rank = state.config.rank
    if is_sender {
        source_rank = state.config.rank
        destination_rank = peer_rank
    }
    kv_transfer_begin_result {
        state: kv_transfer_state_after_begin(state),
        request: new_kv_transfer_request(state.next_request_id, block_ids, source_rank, destination_rank, token_count, byte_count, is_sender),
        success: true,
        error_message: "",
    }
}

func finish_kv_transfer(kv_transfer_state state, kv_transfer_request request, bool success, string error_message) kv_transfer_state {
    int active = state.active_transfers
    if active > 0 {
        active = active - 1
    }
    int completed = state.completed_transfers
    int failed = state.failed_transfers
    int sent = state.bytes_sent
    int received = state.bytes_received
    if success {
        completed = completed + 1
        if request.is_sender {
            sent = sent + request.byte_count
        } else {
            received = received + request.byte_count
        }
    } else {
        failed = failed + 1
    }
    kv_transfer_state {
        config: state.config,
        initialized: state.initialized,
        shutdown: state.shutdown,
        next_request_id: state.next_request_id,
        active_transfers: active,
        completed_transfers: completed,
        failed_transfers: failed,
        bytes_sent: sent,
        bytes_received: received,
        error_message: error_message,
    }
}

func ensure_kv_transfer_shutdown(kv_transfer_state state) kv_transfer_state {
    kv_transfer_state {
        config: state.config,
        initialized: false,
        shutdown: true,
        next_request_id: state.next_request_id,
        active_transfers: 0,
        completed_transfers: state.completed_transfers,
        failed_transfers: state.failed_transfers + state.active_transfers,
        bytes_sent: state.bytes_sent,
        bytes_received: state.bytes_received,
        error_message: state.error_message,
    }
}
