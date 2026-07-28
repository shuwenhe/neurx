package neurx.inference.eval

struct infer_eval_state {
    int samples
    float avg_latency_ms
    float tokens_per_second
    float exact_match
    bool has_result
}

func new_infer_eval_state() infer_eval_state {
    infer_eval_state {
        samples: 0,
        avg_latency_ms: 0.0,
        tokens_per_second: 0.0,
        exact_match: 0.0,
        has_result: false,
    }
}

func update_infer_eval(infer_eval_state state, int samples, float avg_latency_ms, float tokens_per_second, float exact_match) infer_eval_state {
    infer_eval_state {
        samples: samples,
        avg_latency_ms: avg_latency_ms,
        tokens_per_second: tokens_per_second,
        exact_match: exact_match,
        has_result: true,
    }
}

func infer_eval_state_dict(infer_eval_state state) infer_eval_state {
    state
}

func infer_eval_load_state_dict(infer_eval_state state, infer_eval_state other) infer_eval_state {
    other
}
