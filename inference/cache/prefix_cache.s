package neurx.inference.cache.prefix_cache
struct neurx_prefix_cache_state {
    prefix_cache_state cache
    int key_space
}


struct neurx_prefix_lookup_result {
    neurx_prefix_cache_state state
    bool hit
}


func new_neurx_prefix_cache_state(int max_entries, int max_tokens, int key_space) neurx_prefix_cache_state {
    int normalized_key_space = key_space
    if normalized_key_space <= 0 {
        normalized_key_space = 1
    }
    neurx_prefix_cache_state {
        cache: new_prefix_cache_state(max_entries, max_tokens),
        key_space: normalized_key_space,
    }
}


func neurx_prefix_lookup(neurx_prefix_cache_state state, string key, int tokens) neurx_prefix_lookup_result {
    int before_hits = state.cache.hits
    prefix_cache_state cache = prefix_cache_lookup_with_key(state.cache, key, tokens)
    bool hit = cache.hits > before_hits
    neurx_prefix_lookup_result {
        state: neurx_prefix_cache_state {
            cache: cache,
            key_space: state.key_space,
        },
        hit: hit,
    }
}


func neurx_prefix_insert(neurx_prefix_cache_state state, string key, int tokens) neurx_prefix_cache_state {
    neurx_prefix_cache_state {
        cache: prefix_cache_insert_with_key(state.cache, key, tokens),
        key_space: state.key_space,
    }
}


func neurx_prefix_cache_state_dict(neurx_prefix_cache_state state) neurx_prefix_cache_state {
    state
}


func neurx_prefix_cache_load_state_dict(neurx_prefix_cache_state state, neurx_prefix_cache_state other) neurx_prefix_cache_state {
    other
}

