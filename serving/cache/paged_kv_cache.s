package neurx.serving.cache

struct paged_kv_cache_state {
    int layer_count
    int block_size
    int max_blocks
    int allocated_blocks
}

func new_paged_kv_cache_state(int layer_count, int block_size, int max_blocks) paged_kv_cache_state {
    if block_size <= 0 {
        block_size = 1
    }
    if max_blocks < 0 {
        max_blocks = 0
    }
    paged_kv_cache_state {
        layer_count: layer_count,
        block_size: block_size,
        max_blocks: max_blocks,
        allocated_blocks: 0,
    }
}

func paged_kv_reserve_tokens(paged_kv_cache_state state, int tokens) paged_kv_cache_state {
    int need = (tokens + state.block_size - 1) / state.block_size
    if state.allocated_blocks + need > state.max_blocks {
        // cannot reserve, return unchanged
        state
    }
    paged_kv_cache_state {
        layer_count: state.layer_count,
        block_size: state.block_size,
        max_blocks: state.max_blocks,
        allocated_blocks: state.allocated_blocks + need,
    }
}

func paged_kv_release_tokens(paged_kv_cache_state state, int tokens) paged_kv_cache_state {
    int need = (tokens + state.block_size - 1) / state.block_size
    int next = state.allocated_blocks - need
    if next < 0 {
        next = 0
    }
    paged_kv_cache_state {
        layer_count: state.layer_count,
        block_size: state.block_size,
        max_blocks: state.max_blocks,
        allocated_blocks: next,
    }
}

func paged_kv_state_dict(paged_kv_cache_state state) paged_kv_cache_state {
    state
}

func paged_kv_load_state_dict(paged_kv_cache_state state, paged_kv_cache_state other) paged_kv_cache_state {
    other
}
