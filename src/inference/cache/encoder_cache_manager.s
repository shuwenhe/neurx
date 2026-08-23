package neurx.inference.cache.encoder_cache_manager

struct encoder_cache_config {
    int maximum_entries
    int capacity_embeddings
}

struct encoder_cache_state {
    encoder_cache_config config
    []int media_hashes
    []int embedding_counts
    []int reference_counts
    []int last_used_steps
    []int active
    int entry_count
    int free_embeddings
    int logical_step
    int hits
    int misses
    int evictions
}

struct encoder_cache_result {
    encoder_cache_state state
    int slot
    int evicted_hash
    bool hit
    bool accepted
}

func encoder_cache_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_encoder_cache(encoder_cache_config config) encoder_cache_state {
    if config.maximum_entries <= 0 { config.maximum_entries = 1 }
    if config.maximum_entries > 4096 { config.maximum_entries = 4096 }
    if config.capacity_embeddings <= 0 { config.capacity_embeddings = 1 }
    encoder_cache_state {config: config, media_hashes: encoder_cache_int_array(config.maximum_entries), embedding_counts: encoder_cache_int_array(config.maximum_entries), reference_counts: encoder_cache_int_array(config.maximum_entries), last_used_steps: encoder_cache_int_array(config.maximum_entries), active: encoder_cache_int_array(config.maximum_entries), entry_count: 0, free_embeddings: config.capacity_embeddings, logical_step: 0, hits: 0, misses: 0, evictions: 0}
}

func encoder_cache_find(encoder_cache_state state, int media_hash) int {
    int i = 0
    while i < state.config.maximum_entries {
        if state.active[i] == 1 && state.media_hashes[i] == media_hash { return i }
        i = i + 1
    }
    0 - 1
}

func encoder_cache_free_slot(encoder_cache_state state) int {
    int i = 0
    while i < state.config.maximum_entries {
        if state.active[i] == 0 { return i }
        i = i + 1
    }
    0 - 1
}

func encoder_cache_oldest_freeable(encoder_cache_state state) int {
    int selected = 0 - 1
    int i = 0
    while i < state.config.maximum_entries {
        if state.active[i] == 1 && state.reference_counts[i] == 0 {
            if selected < 0 || state.last_used_steps[i] < state.last_used_steps[selected] { selected = i }
        }
        i = i + 1
    }
    selected
}

func encoder_cache_reclaimable_embeddings(encoder_cache_state state) int {
    int total = state.free_embeddings
    int i = 0
    while i < state.config.maximum_entries {
        if state.active[i] == 1 && state.reference_counts[i] == 0 { total = total + state.embedding_counts[i] }
        i = i + 1
    }
    total
}

func encoder_cache_acquire(encoder_cache_state state, int media_hash, int embedding_count, int compute_budget) encoder_cache_result {
    state.logical_step = state.logical_step + 1
    if media_hash == 0 || embedding_count <= 0 || embedding_count > compute_budget || embedding_count > state.config.capacity_embeddings {
        state.misses = state.misses + 1
        return encoder_cache_result {state: state, slot: 0 - 1, evicted_hash: 0, hit: false, accepted: false}
    }
    int slot = encoder_cache_find(state, media_hash)
    if slot >= 0 {
        state.reference_counts[slot] = state.reference_counts[slot] + 1
        state.last_used_steps[slot] = state.logical_step
        state.hits = state.hits + 1
        return encoder_cache_result {state: state, slot: slot, evicted_hash: 0, hit: true, accepted: true}
    }
    state.misses = state.misses + 1
    if embedding_count > encoder_cache_reclaimable_embeddings(state) { return encoder_cache_result {state: state, slot: 0 - 1, evicted_hash: 0, hit: false, accepted: false} }
    int evicted_hash = 0
    while embedding_count > state.free_embeddings || encoder_cache_free_slot(state) < 0 {
        int victim = encoder_cache_oldest_freeable(state)
        if victim < 0 { return encoder_cache_result {state: state, slot: 0 - 1, evicted_hash: evicted_hash, hit: false, accepted: false} }
        evicted_hash = state.media_hashes[victim]
        state.free_embeddings = state.free_embeddings + state.embedding_counts[victim]
        state.active[victim] = 0
        state.embedding_counts[victim] = 0
        state.reference_counts[victim] = 0
        state.entry_count = state.entry_count - 1
        state.evictions = state.evictions + 1
    }
    slot = encoder_cache_free_slot(state)
    state.active[slot] = 1
    state.media_hashes[slot] = media_hash
    state.embedding_counts[slot] = embedding_count
    state.reference_counts[slot] = 1
    state.last_used_steps[slot] = state.logical_step
    state.entry_count = state.entry_count + 1
    state.free_embeddings = state.free_embeddings - embedding_count
    encoder_cache_result {state: state, slot: slot, evicted_hash: evicted_hash, hit: false, accepted: true}
}

func encoder_cache_release(encoder_cache_state state, int media_hash) encoder_cache_state {
    int slot = encoder_cache_find(state, media_hash)
    if slot < 0 { return state }
    if state.reference_counts[slot] > 0 { state.reference_counts[slot] = state.reference_counts[slot] - 1 }
    state.logical_step = state.logical_step + 1
    state.last_used_steps[slot] = state.logical_step
    state
}

func encoder_cache_reset(encoder_cache_state state) encoder_cache_state {
    new_encoder_cache(state.config)
}
