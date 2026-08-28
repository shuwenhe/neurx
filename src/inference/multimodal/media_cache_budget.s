package neurx.inference.multimodal.media_cache_budget
func media_modality_image() int { 1 }
func media_modality_audio() int { 2 }
func media_modality_video() int { 3 }
func media_modality_embedding() int { 4 }
struct media_cache_config {
    int capacity_items
    int encoder_compute_budget
    int encoder_cache_budget
    int max_model_length
    int max_batch_requests
    bool enabled
}
struct media_cache_state {
    media_cache_config config
    int[] hashes
    int[] modalities
    int[] token_counts
    int[] last_access
    int item_count
    int logical_clock
    int hits
    int misses
    int evictions
    int cached_tokens
    bool initialized
}
struct media_cache_result {
    media_cache_state state
    int slot
    bool hit
    bool stored
    int evicted_hash
}
struct media_budget_result {
    int encoder_budget
    int max_items_per_prompt
    int max_items_per_batch
    bool supported
}
func media_zero_array(int capacity) int[] {
    int[] values = int[]{cap: capacity}
    int i = 0
    for i < capacity { values[i] = 0; i = i + 1 }
    values
}
func media_hash_bytes(int[] bytes, int modality, int metadata_hash) int {
    int hash = 216613
    hash = hash * 167 + modality
    hash = hash * 167 + metadata_hash
    int i = 0
    for i < len(bytes) {
        hash = hash * 167 + bytes[i]
        hash = hash - (hash / 1000000007) * 1000000007
        i = i + 1
    }
    if hash < 0 { hash = 0 - hash }
    hash + 1
}
func init_media_cache(media_cache_config config) media_cache_state {
    bool initialized = !config.enabled || (config.capacity_items > 0 && config.encoder_compute_budget >= 0 && config.encoder_cache_budget >= 0 && config.max_model_length > 0 && config.max_batch_requests > 0)
    media_cache_state {config: config, hashes: media_zero_array(config.capacity_items), modalities: media_zero_array(config.capacity_items), token_counts: media_zero_array(config.capacity_items), last_access: media_zero_array(config.capacity_items), item_count: 0, logical_clock: 1, hits: 0, misses: 0, evictions: 0, cached_tokens: 0, initialized: initialized}
}
func media_cache_find(media_cache_state state, int hash) int {
    int i = 0
    for i < state.config.capacity_items {
        if state.hashes[i] == hash { return i }
        i = i + 1
    }
    0 - 1
}
func media_cache_lookup(media_cache_state state, int hash) media_cache_result {
    int slot = media_cache_find(state, hash)
    if slot < 0 { state.misses = state.misses + 1; return media_cache_result {state: state, slot: slot, hit: false, stored: false, evicted_hash: 0} }
    state.logical_clock = state.logical_clock + 1
    state.last_access[slot] = state.logical_clock
    state.hits = state.hits + 1
    media_cache_result {state: state, slot: slot, hit: true, stored: false, evicted_hash: 0}
}
func media_cache_insert(media_cache_state state, int hash, int modality, int token_count) media_cache_result {
    if !state.initialized || !state.config.enabled || hash == 0 || token_count <= 0 { return media_cache_result {state: state, slot: 0 - 1, hit: false, stored: false, evicted_hash: 0} }
    int existing = media_cache_find(state, hash)
    if existing >= 0 { return media_cache_result {state: state, slot: existing, hit: true, stored: false, evicted_hash: 0} }
    int slot = 0 - 1
    int i = 0
    for i < state.config.capacity_items {
        if state.hashes[i] == 0 { slot = i; i = state.config.capacity_items }
        else { i = i + 1 }
    }
    if slot < 0 {
        slot = 0
        i = 1
        for i < state.config.capacity_items {
            if state.last_access[i] < state.last_access[slot] { slot = i }
            i = i + 1
        }
    }
    int evicted_hash = state.hashes[slot]
    if evicted_hash != 0 {
        state.cached_tokens = state.cached_tokens - state.token_counts[slot]
        state.evictions = state.evictions + 1
    } else { state.item_count = state.item_count + 1 }
    state.logical_clock = state.logical_clock + 1
    state.hashes[slot] = hash
    state.modalities[slot] = modality
    state.token_counts[slot] = token_count
    state.last_access[slot] = state.logical_clock
    state.cached_tokens = state.cached_tokens + token_count
    media_cache_result {state: state, slot: slot, hit: false, stored: true, evicted_hash: evicted_hash}
}
func compute_media_budget(media_cache_config config, int max_tokens_per_item, int modality_limit, bool chunked_prefill, int max_batched_tokens) media_budget_result {
    int encoder_budget = config.encoder_compute_budget
    if config.encoder_cache_budget < encoder_budget { encoder_budget = config.encoder_cache_budget }
    if max_tokens_per_item <= 0 || encoder_budget <= 0 || modality_limit <= 0 { return media_budget_result {encoder_budget: encoder_budget, max_items_per_prompt: 0, max_items_per_batch: 0, supported: false} }
    int per_prompt = config.max_model_length / max_tokens_per_item
    if modality_limit < per_prompt { per_prompt = modality_limit }
    if per_prompt < 1 { per_prompt = 1 }
    int request_count = config.max_batch_requests
    if !chunked_prefill {
        int token_limited_requests = max_batched_tokens / max_tokens_per_item
        if token_limited_requests < request_count { request_count = token_limited_requests }
    }
    int encoder_items = encoder_budget / max_tokens_per_item
    int decoder_items = request_count * per_prompt
    int per_batch = encoder_items
    if decoder_items < per_batch { per_batch = decoder_items }
    if per_batch < 1 { per_batch = 1 }
    media_budget_result {encoder_budget: encoder_budget, max_items_per_prompt: per_prompt, max_items_per_batch: per_batch, supported: true}
}
