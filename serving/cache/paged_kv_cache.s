package neurx.serving.cache.paged_kv_cache
struct paged_kv_cache_state {
    int layer_count
    int block_size
    int max_blocks
    int allocated_blocks
    int used_tokens
    int evictions
    bool enabled
}

func new_paged_kv_cache_state(int layer_count, int block_size, int max_blocks) paged_kv_cache_state {
    int effective_block_size = block_size
    if effective_block_size <= 0 {
        effective_block_size = 16
    }
    int effective_max_blocks = max_blocks
    if effective_max_blocks <= 0 {
        effective_max_blocks = 1
    }
    paged_kv_cache_state {
        layer_count: layer_count,
        block_size: effective_block_size,
        max_blocks: effective_max_blocks,
        allocated_blocks: 0,
        used_tokens: 0,
        evictions: 0,
        enabled: true,
    }
}

func paged_kv_reserve_tokens(paged_kv_cache_state state, int tokens) paged_kv_cache_state {
    int add_tokens = tokens
    if add_tokens < 0 {
        add_tokens = 0
    }
    int next_used_tokens = state.used_tokens + add_tokens
    int needed_blocks = (next_used_tokens + state.block_size - 1) / state.block_size
    int next_blocks = needed_blocks
    int next_evictions = state.evictions
    if next_blocks > state.max_blocks {
        next_evictions = next_evictions + (next_blocks - state.max_blocks)
        next_blocks = state.max_blocks
        next_used_tokens = state.max_blocks * state.block_size
    }
    paged_kv_cache_state {
        layer_count: state.layer_count,
        block_size: state.block_size,
        max_blocks: state.max_blocks,
        allocated_blocks: next_blocks,
        used_tokens: next_used_tokens,
        evictions: next_evictions,
        enabled: state.enabled,
    }
}

func paged_kv_release_tokens(paged_kv_cache_state state, int tokens) paged_kv_cache_state {
    int release_tokens = tokens
    if release_tokens < 0 {
        release_tokens = 0
    }
    int next_used_tokens = state.used_tokens - release_tokens
    if next_used_tokens < 0 {
        next_used_tokens = 0
    }
    int next_blocks = (next_used_tokens + state.block_size - 1) / state.block_size
    paged_kv_cache_state {
        layer_count: state.layer_count,
        block_size: state.block_size,
        max_blocks: state.max_blocks,
        allocated_blocks: next_blocks,
        used_tokens: next_used_tokens,
        evictions: state.evictions,
        enabled: state.enabled,
    }
}

func paged_kv_reset(paged_kv_cache_state state) paged_kv_cache_state {
    paged_kv_cache_state {
        layer_count: state.layer_count,
        block_size: state.block_size,
        max_blocks: state.max_blocks,
        allocated_blocks: 0,
        used_tokens: 0,
        evictions: state.evictions,
        enabled: state.enabled,
    }
}

func paged_kv_cache_state_dict(paged_kv_cache_state state) paged_kv_cache_state {
    state
}

func paged_kv_cache_load_state_dict(paged_kv_cache_state state, paged_kv_cache_state other) paged_kv_cache_state {
    other
}

