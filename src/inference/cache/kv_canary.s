package neurx.inference.cache.kv_canary

func canary_healthy() int { 1 }

func canary_suspect() int { 2 }

func canary_quarantined() int { 3 }

struct kv_canary_config {
    int capacity
    int sample_interval
    int failure_threshold
    int perturbation_seed
}

struct kv_canary_state {
    kv_canary_config config
    []int page_ids
    []int expected_checksums
    []int observed_checksums
    []int statuses
    []int failure_counts
    []int sample_counts
    []int last_sample_steps
    int page_count
    int logical_step
    int checked_pages
    int corruptions
    int quarantined_pages
}

struct kv_canary_result {
    kv_canary_state state
    int page_id
    int status
    bool sampled
    bool checksum_match
}

func canary_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_kv_canary(kv_canary_config config) kv_canary_state {
    if config.capacity <= 0 { config.capacity = 1 }
    if config.capacity > 4096 { config.capacity = 4096 }
    if config.sample_interval <= 0 { config.sample_interval = 1 }
    if config.failure_threshold <= 0 { config.failure_threshold = 1 }
    kv_canary_state {config: config, page_ids: canary_int_array(config.capacity), expected_checksums: canary_int_array(config.capacity), observed_checksums: canary_int_array(config.capacity), statuses: canary_int_array(config.capacity), failure_counts: canary_int_array(config.capacity), sample_counts: canary_int_array(config.capacity), last_sample_steps: canary_int_array(config.capacity), page_count: 0, logical_step: 0, checked_pages: 0, corruptions: 0, quarantined_pages: 0}
}

func canary_find(kv_canary_state state, int page_id) int {
    int i = 0
    while i < state.page_count {
        if state.page_ids[i] == page_id { return i }
        i = i + 1
    }
    0 - 1
}

func canary_register_page(kv_canary_state state, int page_id, int expected_checksum) kv_canary_state {
    if page_id <= 0 || state.page_count >= state.config.capacity || canary_find(state, page_id) >= 0 { return state }
    int slot = state.page_count
    state.page_ids[slot] = page_id
    state.expected_checksums[slot] = expected_checksum
    state.statuses[slot] = canary_healthy()
    state.page_count = state.page_count + 1
    state
}

func canary_should_sample(kv_canary_state state, int slot) bool {
    if slot < 0 || slot >= state.page_count || state.statuses[slot] == canary_quarantined() { return false }
    int spread = state.config.sample_interval
    (state.logical_step + state.page_ids[slot] + state.config.perturbation_seed) % spread == 0 || state.logical_step - state.last_sample_steps[slot] >= spread
}

func canary_observe(kv_canary_state state, int page_id, int observed_checksum) kv_canary_result {
    state.logical_step = state.logical_step + 1
    int slot = canary_find(state, page_id)
    if slot < 0 || !canary_should_sample(state, slot) { return kv_canary_result {state: state, page_id: page_id, status: 0, sampled: false, checksum_match: false} }
    state.observed_checksums[slot] = observed_checksum
    state.sample_counts[slot] = state.sample_counts[slot] + 1
    state.last_sample_steps[slot] = state.logical_step
    state.checked_pages = state.checked_pages + 1
    bool match = observed_checksum == state.expected_checksums[slot]
    if match {
        state.failure_counts[slot] = 0
        state.statuses[slot] = canary_healthy()
    } else {
        state.failure_counts[slot] = state.failure_counts[slot] + 1
        state.corruptions = state.corruptions + 1
        state.statuses[slot] = canary_suspect()
        if state.failure_counts[slot] >= state.config.failure_threshold {
            state.statuses[slot] = canary_quarantined()
            state.quarantined_pages = state.quarantined_pages + 1
        }
    }
    kv_canary_result {state: state, page_id: page_id, status: state.statuses[slot], sampled: true, checksum_match: match}
}

func canary_repair(kv_canary_state state, int page_id, int new_checksum) kv_canary_state {
    int slot = canary_find(state, page_id)
    if slot < 0 { return state }
    if state.statuses[slot] == canary_quarantined() && state.quarantined_pages > 0 { state.quarantined_pages = state.quarantined_pages - 1 }
    state.expected_checksums[slot] = new_checksum
    state.observed_checksums[slot] = new_checksum
    state.failure_counts[slot] = 0
    state.statuses[slot] = canary_healthy()
    state
}

func canary_inject_perturbation(kv_canary_state state, int page_id, int bit_index) int {
    int slot = canary_find(state, page_id)
    if slot < 0 { return 0 }
    int delta = bit_index + 1
    state.expected_checksums[slot] + delta
}
