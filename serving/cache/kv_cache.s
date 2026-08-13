package neurx.serving.cache.kv_cache
struct kv_cache_state {
    int layer_count
    int max_seq_len
    int used_tokens
    bool enabled
}
func new_kv_cache_state(int layer_count, int max_seq_len) kv_cache_state {
    kv_cache_state {
        layer_count: layer_count,
        max_seq_len: max_seq_len,
        used_tokens: 0,
        enabled: true,
    }
}
func kv_cache_append(kv_cache_state state, int new_tokens) kv_cache_state {
    int next_used = state.used_tokens + new_tokens
    if next_used > state.max_seq_len {
        next_used = state.max_seq_len
    }
    kv_cache_state {
        layer_count: state.layer_count,
        max_seq_len: state.max_seq_len,
        used_tokens: next_used,
        enabled: state.enabled,
    }
}
func kv_cache_reset(kv_cache_state state) kv_cache_state {
    kv_cache_state {
        layer_count: state.layer_count,
        max_seq_len: state.max_seq_len,
        used_tokens: 0,
        enabled: state.enabled,
    }
}
func kv_cache_state_dict(kv_cache_state state) kv_cache_state {
    state
}
func kv_cache_load_state_dict(kv_cache_state state, kv_cache_state other) kv_cache_state {
    other
}
