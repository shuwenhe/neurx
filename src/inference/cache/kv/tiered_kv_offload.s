package neurx.inference.cache.kv.tiered_kv_offload

func offload_medium_cpu() int { 1 }

func offload_medium_storage() int { 2 }

func offload_status_empty() int { 0 }

func offload_status_storing() int { 1 }

func offload_status_ready() int { 2 }

func offload_status_loading() int { 3 }

func offload_lookup_miss() int { 0 }

func offload_lookup_hit() int { 1 }

func offload_lookup_pending() int { 2 }

func offload_lookup_retry() int { 3 }

struct tiered_kv_offload_config {
    int capacity_blocks
    int bytes_per_block
    int medium
    int locality
    bool enabled
}

struct tiered_kv_offload_state {
    tiered_kv_offload_config config
    []int block_hashes
    []int group_indices
    []int statuses
    []int pinned
    []int last_access
    int logical_clock
    int used_blocks
    int stored_blocks
    int loaded_blocks
    int evicted_blocks
    int hit_count
    int miss_count
    bool initialized
}

struct offload_prepare_result {
    tiered_kv_offload_state state
    int slot
    int evicted_hash
    bool prepared
}

struct offload_lookup_result {
    tiered_kv_offload_state state
    int status
    int slot
}

func offload_zero_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    for i < capacity { values[i] = 0; i = i + 1 }
    values
}

func init_tiered_kv_offload(tiered_kv_offload_config config) tiered_kv_offload_state {
    bool initialized = !config.enabled || (config.capacity_blocks > 0 && config.bytes_per_block > 0 && (config.medium == offload_medium_cpu() || config.medium == offload_medium_storage()))
    tiered_kv_offload_state {
        config: config,
        block_hashes: offload_zero_array(config.capacity_blocks),
        group_indices: offload_zero_array(config.capacity_blocks),
        statuses: offload_zero_array(config.capacity_blocks),
        pinned: offload_zero_array(config.capacity_blocks),
        last_access: offload_zero_array(config.capacity_blocks),
        logical_clock: 1,
        used_blocks: 0,
        stored_blocks: 0,
        loaded_blocks: 0,
        evicted_blocks: 0,
        hit_count: 0,
        miss_count: 0,
        initialized: initialized,
    }
}

func offload_find_slot(tiered_kv_offload_state state, int block_hash, int group_index) int {
    int i = 0
    for i < state.config.capacity_blocks {
        if state.statuses[i] != offload_status_empty() && state.block_hashes[i] == block_hash && state.group_indices[i] == group_index { return i }
        i = i + 1
    }
    0 - 1
}

func offload_find_insert_slot(tiered_kv_offload_state state) int {
    int i = 0
    for i < state.config.capacity_blocks {
        if state.statuses[i] == offload_status_empty() { return i }
        i = i + 1
    }
    int candidate = 0 - 1
    i = 0
    for i < state.config.capacity_blocks {
        if state.pinned[i] == 0 && state.statuses[i] == offload_status_ready() && (candidate < 0 || state.last_access[i] < state.last_access[candidate]) { candidate = i }
        i = i + 1
    }
    candidate
}

func lookup_offloaded_block(tiered_kv_offload_state state, int block_hash, int group_index) offload_lookup_result {
    int slot = offload_find_slot(state, block_hash, group_index)
    if slot < 0 {
        state.miss_count = state.miss_count + 1
        return offload_lookup_result {state: state, status: offload_lookup_miss(), slot: slot}
    }
    state.logical_clock = state.logical_clock + 1
    state.last_access[slot] = state.logical_clock
    if state.statuses[slot] == offload_status_ready() {
        state.hit_count = state.hit_count + 1
        return offload_lookup_result {state: state, status: offload_lookup_hit(), slot: slot}
    }
    if state.statuses[slot] == offload_status_storing() { return offload_lookup_result {state: state, status: offload_lookup_pending(), slot: slot} }
    offload_lookup_result {state: state, status: offload_lookup_retry(), slot: slot}
}

func prepare_offload_store(tiered_kv_offload_state state, int block_hash, int group_index) offload_prepare_result {
    if !state.initialized || !state.config.enabled || block_hash == 0 { return offload_prepare_result {state: state, slot: 0 - 1, evicted_hash: 0, prepared: false} }
    int existing = offload_find_slot(state, block_hash, group_index)
    if existing >= 0 { return offload_prepare_result {state: state, slot: existing, evicted_hash: 0, prepared: state.statuses[existing] == offload_status_ready()} }
    int slot = offload_find_insert_slot(state)
    if slot < 0 { return offload_prepare_result {state: state, slot: slot, evicted_hash: 0, prepared: false} }
    int evicted_hash = 0
    if state.statuses[slot] != offload_status_empty() {
        evicted_hash = state.block_hashes[slot]
        state.evicted_blocks = state.evicted_blocks + 1
    } else {
        state.used_blocks = state.used_blocks + 1
    }
    state.logical_clock = state.logical_clock + 1
    state.block_hashes[slot] = block_hash
    state.group_indices[slot] = group_index
    state.statuses[slot] = offload_status_storing()
    state.pinned[slot] = 1
    state.last_access[slot] = state.logical_clock
    offload_prepare_result {state: state, slot: slot, evicted_hash: evicted_hash, prepared: true}
}

func complete_offload_store(tiered_kv_offload_state state, int slot, bool success) tiered_kv_offload_state {
    if slot < 0 || slot >= state.config.capacity_blocks || state.statuses[slot] != offload_status_storing() { return state }
    if success {
        state.statuses[slot] = offload_status_ready()
        state.pinned[slot] = 0
        state.stored_blocks = state.stored_blocks + 1
    } else {
        state.statuses[slot] = offload_status_empty()
        state.pinned[slot] = 0
        state.used_blocks = state.used_blocks - 1
    }
    state
}

func prepare_offload_load(tiered_kv_offload_state state, int block_hash, int group_index) offload_prepare_result {
    int slot = offload_find_slot(state, block_hash, group_index)
    if slot < 0 || state.statuses[slot] != offload_status_ready() { return offload_prepare_result {state: state, slot: slot, evicted_hash: 0, prepared: false} }
    state.statuses[slot] = offload_status_loading()
    state.pinned[slot] = 1
    offload_prepare_result {state: state, slot: slot, evicted_hash: 0, prepared: true}
}

func complete_offload_load(tiered_kv_offload_state state, int slot, bool success) tiered_kv_offload_state {
    if slot < 0 || slot >= state.config.capacity_blocks || state.statuses[slot] != offload_status_loading() { return state }
    state.statuses[slot] = offload_status_ready()
    state.pinned[slot] = 0
    if success { state.loaded_blocks = state.loaded_blocks + 1 }
    state
}

func tiered_offload_bytes(tiered_kv_offload_state state) int {
    state.used_blocks * state.config.bytes_per_block
}
