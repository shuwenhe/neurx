package neurx.inference.cache.hicache_controller
func hicache_write_back() int { 1 }

func hicache_write_through() int { 2 }

func hicache_action_none() int { 0 }

func hicache_action_device_to_host() int { 1 }

func hicache_action_host_to_storage() int { 2 }

func hicache_action_storage_to_host() int { 3 }

struct hicache_config {
    int write_policy
    int prefetch_threshold_pages
    int prefetch_base_timeout_ms
    int prefetch_per_ki_token_ms
    int prefetch_max_timeout_ms
    bool storage_enabled
}

struct hicache_state {
    hicache_config config
    int[] key_hashes
    int[] pool_ids
    int[] device_present
    int[] host_present
    int[] storage_present
    int[] dirty
    int[] transfer_in_flight
    int[] lock_refs
    int[] last_access
    int page_count
    int logical_clock
    int write_through_threshold
    int load_back_threshold
    int host_writes
    int storage_writes
    int prefetches
    int prefetch_timeouts
}

struct hicache_action_result {
    hicache_state state
    int page_index
    int action
    bool scheduled
}

struct hicache_prefix_result {
    int kv_hit_pages
    int auxiliary_hit_pages
    int usable_pages
}

func hicache_int_array(int capacity) int[] {
    int[] values = int[]{cap: capacity}
    int i = 0
    for i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_hicache(hicache_config config) hicache_state {
    if config.write_policy != hicache_write_back() && config.write_policy != hicache_write_through() { config.write_policy = hicache_write_back() }
    if config.prefetch_threshold_pages < 0 { config.prefetch_threshold_pages = 0 }
    if config.prefetch_base_timeout_ms < 0 { config.prefetch_base_timeout_ms = 0 }
    if config.prefetch_per_ki_token_ms < 0 { config.prefetch_per_ki_token_ms = 0 }
    if config.prefetch_max_timeout_ms < config.prefetch_base_timeout_ms { config.prefetch_max_timeout_ms = config.prefetch_base_timeout_ms }
    int threshold = 2
    if config.write_policy == hicache_write_through() { threshold = 1 }
    hicache_state {
        config: config,
        key_hashes: hicache_int_array(1024), pool_ids: hicache_int_array(1024), device_present: hicache_int_array(1024), host_present: hicache_int_array(1024), storage_present: hicache_int_array(1024), dirty: hicache_int_array(1024), transfer_in_flight: hicache_int_array(1024), lock_refs: hicache_int_array(1024), last_access: hicache_int_array(1024),
        page_count: 0, logical_clock: 1, write_through_threshold: threshold, load_back_threshold: 10, host_writes: 0, storage_writes: 0, prefetches: 0, prefetch_timeouts: 0,
    }
}

func hicache_find_page(hicache_state state, int key_hash, int pool_id) int {
    int i = 0
    for i < state.page_count {
        if state.key_hashes[i] == key_hash && state.pool_ids[i] == pool_id { return i }
        i = i + 1
    }
    0 - 1
}

func hicache_admit_device_page(hicache_state state, int key_hash, int pool_id, int lock_refs) hicache_state {
    if key_hash == 0 { return state }
    int index = hicache_find_page(state, key_hash, pool_id)
    state.logical_clock = state.logical_clock + 1
    if index < 0 {
        if state.page_count >= 1024 { return state }
        index = state.page_count
        state.key_hashes[index] = key_hash
        state.pool_ids[index] = pool_id
        state.page_count = state.page_count + 1
    }
    int refs = lock_refs
    if refs < 0 { refs = 0 }
    state.device_present[index] = 1
    state.dirty[index] = 1
    state.lock_refs[index] = refs
    state.last_access[index] = state.logical_clock
    state
}

func hicache_set_page_residency(hicache_state state, int key_hash, int pool_id, bool device_present, bool host_present) hicache_state {
    int index = hicache_find_page(state, key_hash, pool_id)
    if index < 0 { return state }
    if device_present { state.device_present[index] = 1 } else { state.device_present[index] = 0 }
    if host_present { state.host_present[index] = 1 } else { state.host_present[index] = 0 }
    state
}

func hicache_set_lock_refs(hicache_state state, int key_hash, int pool_id, int lock_refs) hicache_state {
    int index = hicache_find_page(state, key_hash, pool_id)
    if index >= 0 { state.lock_refs[index] = lock_refs }
    state
}

func hicache_no_action(hicache_state state, int index) hicache_action_result { hicache_action_result {state state, index page_index, hicache_action_none action(), false scheduled} }

func hicache_prepare_backup(hicache_state state, int key_hash, int pool_id) hicache_action_result {
    int index = hicache_find_page(state, key_hash, pool_id)
    if index < 0 || state.transfer_in_flight[index] == 1 || state.device_present[index] == 0 || state.lock_refs[index] < state.write_through_threshold { return hicache_no_action(state, index) }
    state.transfer_in_flight[index] = 1
    hicache_action_result {state: state, page_index: index, action: hicache_action_device_to_host(), scheduled: true}
}

func hicache_complete_backup(hicache_state state, int page_index, bool success) hicache_state {
    if page_index < 0 || page_index >= state.page_count || state.transfer_in_flight[page_index] == 0 { return state }
    state.transfer_in_flight[page_index] = 0
    if success {
        state.host_present[page_index] = 1
        state.host_writes = state.host_writes + 1
        if !state.config.storage_enabled { state.dirty[page_index] = 0 }
    }
    state
}

func hicache_prepare_storage_write(hicache_state state, int key_hash, int pool_id, bool evicting) hicache_action_result {
    int index = hicache_find_page(state, key_hash, pool_id)
    if index < 0 || !state.config.storage_enabled || state.host_present[index] == 0 || state.transfer_in_flight[index] == 1 || state.dirty[index] == 0 { return hicache_no_action(state, index) }
    if state.config.write_policy == hicache_write_back() && !evicting { return hicache_no_action(state, index) }
    state.transfer_in_flight[index] = 1
    hicache_action_result {state: state, page_index: index, action: hicache_action_host_to_storage(), scheduled: true}
}

func hicache_complete_storage_write(hicache_state state, int page_index, bool success) hicache_state {
    if page_index < 0 || page_index >= state.page_count || state.transfer_in_flight[page_index] == 0 { return state }
    state.transfer_in_flight[page_index] = 0
    if success { state.storage_present[page_index] = 1; state.dirty[page_index] = 0; state.storage_writes = state.storage_writes + 1 }
    state
}

func hicache_prefetch_timeout_ms(hicache_config config, int token_count) int {
    int tokens = token_count
    if tokens < 0 { tokens = 0 }
    int ki_tokens = (tokens + 1023) / 1024
    int timeout = config.prefetch_base_timeout_ms + ki_tokens * config.prefetch_per_ki_token_ms
    if timeout > config.prefetch_max_timeout_ms { timeout = config.prefetch_max_timeout_ms }
    timeout
}

func hicache_prepare_prefetch(hicache_state state, int key_hash, int pool_id, int prefix_pages) hicache_action_result {
    int index = hicache_find_page(state, key_hash, pool_id)
    if index < 0 || prefix_pages < state.config.prefetch_threshold_pages || state.storage_present[index] == 0 || state.host_present[index] == 1 || state.transfer_in_flight[index] == 1 { return hicache_no_action(state, index) }
    state.transfer_in_flight[index] = 1
    hicache_action_result {state: state, page_index: index, action: hicache_action_storage_to_host(), scheduled: true}
}

func hicache_complete_prefetch(hicache_state state, int page_index, bool success, bool timed_out) hicache_state {
    if page_index < 0 || page_index >= state.page_count || state.transfer_in_flight[page_index] == 0 { return state }
    state.transfer_in_flight[page_index] = 0
    if timed_out { state.prefetch_timeouts = state.prefetch_timeouts + 1; return state }
    if success { state.host_present[page_index] = 1; state.prefetches = state.prefetches + 1 }
    state
}

func hicache_page_available(hicache_state state, int key_hash, int pool_id) bool {
    int index = hicache_find_page(state, key_hash, pool_id)
    index >= 0 && (state.device_present[index] == 1 || state.host_present[index] == 1 || state.storage_present[index] == 1)
}

func hicache_match_prefix(hicache_state state, int[] kv_keys, int kv_pool_id, int[] auxiliary_keys, int auxiliary_pool_id) hicache_prefix_result {
    int kv_hit = 0
    for kv_hit < len(kv_keys) && hicache_page_available(state, kv_keys[kv_hit], kv_pool_id) { kv_hit = kv_hit + 1 }
    int auxiliary_hit = 0
    for auxiliary_hit < len(auxiliary_keys) && hicache_page_available(state, auxiliary_keys[auxiliary_hit], auxiliary_pool_id) { auxiliary_hit = auxiliary_hit + 1 }
    int usable = kv_hit
    if len(auxiliary_keys) > 0 && auxiliary_hit < usable { usable = auxiliary_hit }
    hicache_prefix_result {kv_hit_pages: kv_hit, auxiliary_hit_pages: auxiliary_hit, usable_pages: usable}
}
