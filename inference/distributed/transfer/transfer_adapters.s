package neurx.inference.distributed.transfer.transfer_adapters

func transfer_backend_mooncake() int { 1 }

func transfer_backend_nixl() int { 2 }

func transfer_backend_mori() int { 3 }

func transfer_created() int { 1 }

func transfer_registered() int { 2 }

func transfer_metadata_ready() int { 3 }

func transfer_in_flight() int { 4 }

func transfer_complete() int { 5 }

func transfer_failed() int { 6 }

struct transfer_adapter_config {
    int capacity
    int maximum_shards
    int maximum_retries
    int timeout_ms
    bool mooncake_available
    bool nixl_available
    bool mori_available
}

struct transfer_adapter_state {
    transfer_adapter_config config
    []int transfer_ids
    []int room_ids
    []int backend_types
    []int source_ranks
    []int destination_ranks
    []int source_ptr_low
    []int destination_ptr_low
    []int byte_counts
    []int shard_counts
    []int ready_shards
    []int completed_shards
    []int checksums
    []int statuses
    []int retry_counts
    []int created_ms
    []int updated_ms
    []int error_codes
    int transfer_count
    int completed_count
    int failed_count
    int transferred_bytes
}

struct transfer_adapter_result {
    transfer_adapter_state state
    int slot
    int status
    int backend_type
    bool accepted
}

func transfer_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_transfer_adapter_state(transfer_adapter_config config) transfer_adapter_state {
    if config.capacity <= 0 { config.capacity = 1 }
    if config.capacity > 2048 { config.capacity = 2048 }
    if config.maximum_shards <= 0 { config.maximum_shards = 1 }
    if config.maximum_retries < 0 { config.maximum_retries = 0 }
    if config.timeout_ms <= 0 { config.timeout_ms = 1 }
    transfer_adapter_state {config: config, transfer_ids: transfer_int_array(config.capacity), room_ids: transfer_int_array(config.capacity), backend_types: transfer_int_array(config.capacity), source_ranks: transfer_int_array(config.capacity), destination_ranks: transfer_int_array(config.capacity), source_ptr_low: transfer_int_array(config.capacity), destination_ptr_low: transfer_int_array(config.capacity), byte_counts: transfer_int_array(config.capacity), shard_counts: transfer_int_array(config.capacity), ready_shards: transfer_int_array(config.capacity), completed_shards: transfer_int_array(config.capacity), checksums: transfer_int_array(config.capacity), statuses: transfer_int_array(config.capacity), retry_counts: transfer_int_array(config.capacity), created_ms: transfer_int_array(config.capacity), updated_ms: transfer_int_array(config.capacity), error_codes: transfer_int_array(config.capacity), transfer_count: 0, completed_count: 0, failed_count: 0, transferred_bytes: 0}
}

func transfer_find(transfer_adapter_state state, int transfer_id) int {
    int i = 0
    while i < state.transfer_count {
        if state.transfer_ids[i] == transfer_id { return i }
        i = i + 1
    }
    0 - 1
}

func transfer_backend_available(transfer_adapter_state state, int backend_type) bool {
    if backend_type == transfer_backend_mooncake() { return state.config.mooncake_available }
    if backend_type == transfer_backend_nixl() { return state.config.nixl_available }
    if backend_type == transfer_backend_mori() { return state.config.mori_available }
    false
}

func transfer_result_of(transfer_adapter_state state, int slot, bool accepted) transfer_adapter_result {
    if slot < 0 { return transfer_adapter_result {state: state, slot: slot, status: 0, backend_type: 0, accepted: accepted} }
    transfer_adapter_result {state: state, slot: slot, status: state.statuses[slot], backend_type: state.backend_types[slot], accepted: accepted}
}

func transfer_create(transfer_adapter_state state, int transfer_id, int room_id, int backend_type, int source_rank, int destination_rank, int source_ptr_low, int destination_ptr_low, int byte_count, int shard_count, int checksum, int now_ms) transfer_adapter_result {
    if transfer_id <= 0 || room_id <= 0 || byte_count <= 0 || shard_count <= 0 || shard_count > state.config.maximum_shards || source_ptr_low == 0 || destination_ptr_low == 0 || state.transfer_count >= state.config.capacity || transfer_find(state, transfer_id) >= 0 || !transfer_backend_available(state, backend_type) { return transfer_result_of(state, -1, false) }
    int slot = state.transfer_count
    state.transfer_ids[slot] = transfer_id
    state.room_ids[slot] = room_id
    state.backend_types[slot] = backend_type
    state.source_ranks[slot] = source_rank
    state.destination_ranks[slot] = destination_rank
    state.source_ptr_low[slot] = source_ptr_low
    state.destination_ptr_low[slot] = destination_ptr_low
    state.byte_counts[slot] = byte_count
    state.shard_counts[slot] = shard_count
    state.checksums[slot] = checksum
    state.statuses[slot] = transfer_created()
    state.created_ms[slot] = now_ms
    state.updated_ms[slot] = now_ms
    state.transfer_count = state.transfer_count + 1
    transfer_result_of(state, slot, true)
}

func transfer_register_memory(transfer_adapter_state state, int transfer_id, bool registration_success, int now_ms) transfer_adapter_result {
    int slot = transfer_find(state, transfer_id)
    if slot < 0 || state.statuses[slot] != transfer_created() { return transfer_result_of(state, slot, false) }
    if registration_success {
        state.statuses[slot] = transfer_registered()
    } else {
        state.statuses[slot] = transfer_failed()
        state.error_codes[slot] = 501
        state.failed_count = state.failed_count + 1
    }
    state.updated_ms[slot] = now_ms
    transfer_result_of(state, slot, true)
}

func transfer_mark_shard_ready(transfer_adapter_state state, int transfer_id, int now_ms) transfer_adapter_result {
    int slot = transfer_find(state, transfer_id)
    if slot < 0 || (state.statuses[slot] != transfer_registered() && state.statuses[slot] != transfer_metadata_ready()) { return transfer_result_of(state, slot, false) }
    if state.ready_shards[slot] < state.shard_counts[slot] { state.ready_shards[slot] = state.ready_shards[slot] + 1 }
    if state.ready_shards[slot] == state.shard_counts[slot] { state.statuses[slot] = transfer_metadata_ready() }
    state.updated_ms[slot] = now_ms
    transfer_result_of(state, slot, true)
}

func transfer_start(transfer_adapter_state state, int transfer_id, int now_ms) transfer_adapter_result {
    int slot = transfer_find(state, transfer_id)
    if slot < 0 || state.statuses[slot] != transfer_metadata_ready() { return transfer_result_of(state, slot, false) }
    state.statuses[slot] = transfer_in_flight()
    state.updated_ms[slot] = now_ms
    transfer_result_of(state, slot, true)
}

func transfer_complete_shard(transfer_adapter_state state, int transfer_id, bool success, int received_checksum, int now_ms) transfer_adapter_result {
    int slot = transfer_find(state, transfer_id)
    if slot < 0 || state.statuses[slot] != transfer_in_flight() { return transfer_result_of(state, slot, false) }
    bool valid = success
    if state.checksums[slot] != 0 && received_checksum != state.checksums[slot] {
        valid = false
        state.error_codes[slot] = 422
    }
    if !valid {
        if state.retry_counts[slot] < state.config.maximum_retries {
            state.retry_counts[slot] = state.retry_counts[slot] + 1
            state.completed_shards[slot] = 0
            state.statuses[slot] = transfer_metadata_ready()
        } else {
            state.statuses[slot] = transfer_failed()
            if state.error_codes[slot] == 0 { state.error_codes[slot] = 502 }
            state.failed_count = state.failed_count + 1
        }
        state.updated_ms[slot] = now_ms
        return transfer_result_of(state, slot, true)
    }
    state.completed_shards[slot] = state.completed_shards[slot] + 1
    if state.completed_shards[slot] >= state.shard_counts[slot] {
        state.statuses[slot] = transfer_complete()
        state.completed_count = state.completed_count + 1
        state.transferred_bytes = state.transferred_bytes + state.byte_counts[slot]
    }
    state.updated_ms[slot] = now_ms
    transfer_result_of(state, slot, true)
}

func transfer_poll_timeout(transfer_adapter_state state, int transfer_id, int now_ms) transfer_adapter_result {
    int slot = transfer_find(state, transfer_id)
    if slot < 0 { return transfer_result_of(state, slot, false) }
    if state.statuses[slot] != transfer_complete() && state.statuses[slot] != transfer_failed() && now_ms - state.updated_ms[slot] > state.config.timeout_ms {
        state.statuses[slot] = transfer_failed()
        state.error_codes[slot] = 408
        state.failed_count = state.failed_count + 1
    }
    transfer_result_of(state, slot, true)
}
