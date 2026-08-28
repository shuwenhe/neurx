package neurx.inference.cache.serving.prefix_cache
struct prefix_cache_state {
    int max_entries
    int max_tokens
    int entries
    int resident_tokens
    string last_key
    int last_key_tokens
    string prev_key
    int prev_key_tokens
    int hits
    int misses
    int evictions
}
func new_prefix_cache_state(int max_entries, int max_tokens) prefix_cache_state {
    int normalized_entries = max_entries
    if normalized_entries <= 0 {
        normalized_entries = 1
    }
    int normalized_tokens = max_tokens
    if normalized_tokens <= 0 {
        normalized_tokens = 1
    }
    prefix_cache_state {
        max_entries: normalized_entries,
        max_tokens: normalized_tokens,
        entries: 0,
        resident_tokens: 0,
        last_key: "",
        last_key_tokens: 0,
        prev_key: "",
        prev_key_tokens: 0,
        hits: 0,
        misses: 0,
        evictions: 0,
    }
}
func prefix_cache_lookup_with_key(prefix_cache_state state, string key, int prefix_tokens) prefix_cache_state {
    bool hit = false
    if key == state.last_key && prefix_tokens > 0 && prefix_tokens == state.last_key_tokens && state.entries > 0 {
        hit = true
    }
    if key == state.prev_key && prefix_tokens > 0 && prefix_tokens == state.prev_key_tokens && state.entries > 1 {
        hit = true
    }
    prefix_cache_state result = prefix_cache_state {
        max_entries: state.max_entries,
        max_tokens: state.max_tokens,
        entries: state.entries,
        resident_tokens: state.resident_tokens,
        last_key: state.last_key,
        last_key_tokens: state.last_key_tokens,
        prev_key: state.prev_key,
        prev_key_tokens: state.prev_key_tokens,
        hits: state.hits,
        misses: state.misses,
        evictions: state.evictions,
    }
    if hit {
        return prefix_cache_state {
            max_entries: state.max_entries,
            max_tokens: state.max_tokens,
            entries: state.entries,
            resident_tokens: state.resident_tokens,
            last_key: state.last_key,
            last_key_tokens: state.last_key_tokens,
            prev_key: state.prev_key,
            prev_key_tokens: state.prev_key_tokens,
            hits: state.hits + 1,
            misses: state.misses,
            evictions: state.evictions,
        }
    }
    prefix_cache_state {
        max_entries: state.max_entries,
        max_tokens: state.max_tokens,
        entries: state.entries,
        resident_tokens: state.resident_tokens,
        last_key: state.last_key,
        last_key_tokens: state.last_key_tokens,
        prev_key: state.prev_key,
        prev_key_tokens: state.prev_key_tokens,
        hits: state.hits,
        misses: state.misses + 1,
        evictions: state.evictions,
    }
}
func prefix_cache_lookup(prefix_cache_state state, int prefix_tokens) prefix_cache_state {
    prefix_cache_lookup_with_key(state, "", prefix_tokens)
}
func prefix_cache_insert_with_key(prefix_cache_state state, string key, int prefix_tokens) prefix_cache_state {
    int tokens = prefix_tokens
    if tokens < 0 {
        tokens = 0
    }
    int next_entries = state.entries
    int next_tokens = state.resident_tokens
    int next_evictions = state.evictions
    string next_last_key = state.last_key
    int next_last_key_tokens = state.last_key_tokens
    string next_prev_key = state.prev_key
    int next_prev_key_tokens = state.prev_key_tokens
    if next_entries >= state.max_entries {
        if next_entries > 0 {
            next_entries = next_entries - 1
            next_evictions = next_evictions + 1
        }
    }
    next_entries = next_entries + 1
    next_tokens = next_tokens + tokens
    if next_tokens > state.max_tokens {
        next_tokens = state.max_tokens
        next_evictions = next_evictions + 1
    }
    if key == state.last_key {
        next_last_key = key
        next_last_key_tokens = tokens
    } else if key == state.prev_key {
        next_last_key = key
        next_last_key_tokens = tokens
        next_prev_key = state.last_key
        next_prev_key_tokens = state.last_key_tokens
    } else {
        next_prev_key = state.last_key
        next_prev_key_tokens = state.last_key_tokens
        next_last_key = key
        next_last_key_tokens = tokens
    }
    prefix_cache_state {
        max_entries: state.max_entries,
        max_tokens: state.max_tokens,
        entries: next_entries,
        resident_tokens: next_tokens,
        last_key: next_last_key,
        last_key_tokens: next_last_key_tokens,
        prev_key: next_prev_key,
        prev_key_tokens: next_prev_key_tokens,
        hits: state.hits,
        misses: state.misses,
        evictions: next_evictions,
    }
}
func prefix_cache_insert(prefix_cache_state state, int prefix_tokens) prefix_cache_state {
    prefix_cache_insert_with_key(state, "", prefix_tokens)
}
func prefix_cache_state_dict(prefix_cache_state state) prefix_cache_state {
    state
}
func prefix_cache_load_state_dict(prefix_cache_state state, prefix_cache_state other) prefix_cache_state {
    other
}
