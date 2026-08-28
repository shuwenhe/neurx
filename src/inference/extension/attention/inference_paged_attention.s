package neurx.attention.inference_paged
use neurx.inference.cache.paged_kv_cache
struct paged_attention_state {
    paged_kv_cache_state kv
    int page_size
    int decode_steps
}

func new_paged_attention_state(int layer_count, int page_size, int max_pages) paged_attention_state {
    int normalized_page = page_size
    if normalized_page <= 0 {
        normalized_page = 16
    }
    paged_attention_state {
        kv: new_paged_kv_cache_state(layer_count, normalized_page, max_pages),
        page_size: normalized_page,
        decode_steps: 0,
    }
}

func paged_attention_prefill(paged_attention_state state, int tokens) paged_attention_state {
    paged_attention_state {
        kv: paged_kv_reserve_tokens(state.kv, tokens),
        page_size: state.page_size,
        decode_steps: state.decode_steps,
    }
}

func paged_attention_decode_step(paged_attention_state state, int tokens) paged_attention_state {
    int add_tokens = tokens
    if add_tokens < 0 {
        add_tokens = 0
    }
    paged_attention_state {
        kv: paged_kv_reserve_tokens(state.kv, add_tokens),
        page_size: state.page_size,
        decode_steps: state.decode_steps + 1,
    }
}

func paged_attention_release(paged_attention_state state, int tokens) paged_attention_state {
    paged_attention_state {
        kv: paged_kv_release_tokens(state.kv, tokens),
        page_size: state.page_size,
        decode_steps: state.decode_steps,
    }
}

func paged_attention_state_dict(paged_attention_state state) paged_attention_state {
    state
}

func paged_attention_load_state_dict(paged_attention_state state, paged_attention_state other) paged_attention_state {
    other
}
