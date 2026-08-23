package neurx.inference.sampling.serving_sampling

struct sampling_state {
    float temperature
    int top_k
    float top_p
    float repetition_penalty
}

func new_sampling_state() sampling_state {
    sampling_state {
        temperature: 1.0,
        top_k: 50,
        top_p: 0.95,
        repetition_penalty: 1.0,
    }
}

func with_temperature(sampling_state state, float temperature) sampling_state {
    sampling_state {
        temperature: temperature,
        top_k: state.top_k,
        top_p: state.top_p,
        repetition_penalty: state.repetition_penalty,
    }
}

func with_top_k(sampling_state state, int top_k) sampling_state {
    sampling_state {
        temperature: state.temperature,
        top_k: top_k,
        top_p: state.top_p,
        repetition_penalty: state.repetition_penalty,
    }
}

func with_top_p(sampling_state state, float top_p) sampling_state {
    sampling_state {
        temperature: state.temperature,
        top_k: state.top_k,
        top_p: top_p,
        repetition_penalty: state.repetition_penalty,
    }
}

func sampling_state_dict(sampling_state state) sampling_state {
    state
}

func sampling_load_state_dict(sampling_state state, sampling_state other) sampling_state {
    other
}
