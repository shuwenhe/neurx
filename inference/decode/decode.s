package neurx.inference.decode
use neurx.inference.cache
use neurx.inference.sampling
struct decode_state {
    int step
    int max_new_tokens
    int last_token_id
    bool finished
    kv_cache_state cache
    sampling_state sampling
}

func new_decode_state(int max_new_tokens, kv_cache_state cache, sampling_state sampling) decode_state {
    decode_state {
        step: 0,
        max_new_tokens: max_new_tokens,
        last_token_id: -1,
        finished: false,
        cache: cache,
        sampling: sampling,
    }
}

func decode_step(decode_state state, int next_token_id) decode_state {
    int next_step = state.step + 1
    bool finished = next_step >= state.max_new_tokens
    decode_state {
        step: next_step,
        max_new_tokens: state.max_new_tokens,
        last_token_id: next_token_id,
        finished: finished,
        cache: kv_cache_append(state.cache, 1),
        sampling: state.sampling,
    }
}

func decode_state_dict(decode_state state) decode_state {
    state
}

func decode_load_state_dict(decode_state state, decode_state other) decode_state {
    other
}

