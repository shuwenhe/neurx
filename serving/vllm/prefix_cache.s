package neurx.serving.vllm.prefix_cache
use neurx.serving.cache.prefix_cache
struct vllm_prefix_cache_state {
    prefix_cache_state cache
    int key_space
}


struct vllm_prefix_lookup_result {
    vllm_prefix_cache_state state
    bool hit
}


func new_vllm_prefix_cache_state(int max_entries, int max_tokens, int key_space) vllm_prefix_cache_state {
    int normalized_key_space = key_space
    if normalized_key_space <= 0 {
        normalized_key_space = 1
    }
    vllm_prefix_cache_state {
        cache: new_prefix_cache_state(max_entries, max_tokens),
        key_space: normalized_key_space,
    }
}


func vllm_prefix_lookup(vllm_prefix_cache_state state, string key, int tokens) vllm_prefix_lookup_result {
    int before_hits = state.cache.hits
    prefix_cache_state cache = prefix_cache_lookup_with_key(state.cache, key, tokens)
    bool hit = cache.hits > before_hits
    vllm_prefix_lookup_result {
        state: vllm_prefix_cache_state {
            cache: cache,
            key_space: state.key_space,
        },
        hit: hit,
    }
}


func vllm_prefix_insert(vllm_prefix_cache_state state, string key, int tokens) vllm_prefix_cache_state {
    vllm_prefix_cache_state {
        cache: prefix_cache_insert_with_key(state.cache, key, tokens),
        key_space: state.key_space,
    }
}


func vllm_prefix_cache_state_dict(vllm_prefix_cache_state state) vllm_prefix_cache_state {
    state
}


func vllm_prefix_cache_load_state_dict(vllm_prefix_cache_state state, vllm_prefix_cache_state other) vllm_prefix_cache_state {
    other
}

