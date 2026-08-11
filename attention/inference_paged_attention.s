package neurx.attention.inference_paged
use neurx.inference.cache.paged_kv_cache
struct vllm_paged_attention_state {
    paged_kv_cache_state kv
    int page_size
    int decode_steps
}

func new_vllm_paged_attention_state(int layer_count, int page_size, int max_pages) vllm_paged_attention_state {
    int normalized_page = page_size
    if normalized_page <= 0 {
        normalized_page = 16
    }
    vllm_paged_attention_state {
        kv: new_paged_kv_cache_state(layer_count, normalized_page, max_pages),
        page_size: normalized_page,
        decode_steps: 0,
    }
}

func vllm_paged_attention_prefill(vllm_paged_attention_state state, int tokens) vllm_paged_attention_state {
    vllm_paged_attention_state {
        kv: paged_kv_reserve_tokens(state.kv, tokens),
        page_size: state.page_size,
        decode_steps: state.decode_steps,
    }
}

func vllm_paged_attention_decode_step(vllm_paged_attention_state state, int tokens) vllm_paged_attention_state {
    int add_tokens = tokens
    if add_tokens < 0 {
        add_tokens = 0
    }
    vllm_paged_attention_state {
        kv: paged_kv_reserve_tokens(state.kv, add_tokens),
        page_size: state.page_size,
        decode_steps: state.decode_steps + 1,
    }
}

func vllm_paged_attention_release(vllm_paged_attention_state state, int tokens) vllm_paged_attention_state {
    vllm_paged_attention_state {
        kv: paged_kv_release_tokens(state.kv, tokens),
        page_size: state.page_size,
        decode_steps: state.decode_steps,
    }
}

func vllm_paged_attention_state_dict(vllm_paged_attention_state state) vllm_paged_attention_state {
    state
}

func vllm_paged_attention_load_state_dict(vllm_paged_attention_state state, vllm_paged_attention_state other) vllm_paged_attention_state {
    other
}
