package neurx.serving.vllm.metrics
struct vllm_metrics_state {
    int admitted
    int rejected
    int completed
    int decode_tokens
    int prefill_tokens
    int queue_depth_sum
    int queue_depth_samples
    int cache_hits
    int cache_misses
}
func new_vllm_metrics_state() vllm_metrics_state {
    vllm_metrics_state {
        admitted: 0,
        rejected: 0,
        completed: 0,
        decode_tokens: 0,
        prefill_tokens: 0,
        queue_depth_sum: 0,
        queue_depth_samples: 0,
        cache_hits: 0,
        cache_misses: 0,
    }
}

func vllm_metrics_record_enqueue(vllm_metrics_state state, bool accepted, int queue_depth, int prefill_tokens) vllm_metrics_state {
    int normalized_depth = queue_depth
    if normalized_depth < 0 {
        normalized_depth = 0
    }
    int normalized_prefill = prefill_tokens
    if normalized_prefill < 0 {
        normalized_prefill = 0
    }
    int next_admitted = state.admitted
    int next_rejected = state.rejected
    int next_prefill = state.prefill_tokens
    if accepted {
        next_admitted = next_admitted + 1
        next_prefill = next_prefill + normalized_prefill
    } else {
        next_rejected = next_rejected + 1
    }
    vllm_metrics_state {
        admitted: next_admitted,
        rejected: next_rejected,
        completed: state.completed,
        decode_tokens: state.decode_tokens,
        prefill_tokens: next_prefill,
        queue_depth_sum: state.queue_depth_sum + normalized_depth,
        queue_depth_samples: state.queue_depth_samples + 1,
        cache_hits: state.cache_hits,
        cache_misses: state.cache_misses,
    }
}

func vllm_metrics_record_decode(vllm_metrics_state state, int tokens) vllm_metrics_state {
    int add_tokens = tokens
    if add_tokens < 0 {
        add_tokens = 0
    }
    vllm_metrics_state {
        admitted: state.admitted,
        rejected: state.rejected,
        completed: state.completed,
        decode_tokens: state.decode_tokens + add_tokens,
        prefill_tokens: state.prefill_tokens,
        queue_depth_sum: state.queue_depth_sum,
        queue_depth_samples: state.queue_depth_samples,
        cache_hits: state.cache_hits,
        cache_misses: state.cache_misses,
    }
}

func vllm_metrics_record_cache(vllm_metrics_state state, bool hit) vllm_metrics_state {
    int next_hits = state.cache_hits
    int next_misses = state.cache_misses
    if hit {
        next_hits = next_hits + 1
    } else {
        next_misses = next_misses + 1
    }
    vllm_metrics_state {
        admitted: state.admitted,
        rejected: state.rejected,
        completed: state.completed,
        decode_tokens: state.decode_tokens,
        prefill_tokens: state.prefill_tokens,
        queue_depth_sum: state.queue_depth_sum,
        queue_depth_samples: state.queue_depth_samples,
        cache_hits: next_hits,
        cache_misses: next_misses,
    }
}

func vllm_metrics_record_finish(vllm_metrics_state state) vllm_metrics_state {
    vllm_metrics_state {
        admitted: state.admitted,
        rejected: state.rejected,
        completed: state.completed + 1,
        decode_tokens: state.decode_tokens,
        prefill_tokens: state.prefill_tokens,
        queue_depth_sum: state.queue_depth_sum,
        queue_depth_samples: state.queue_depth_samples,
        cache_hits: state.cache_hits,
        cache_misses: state.cache_misses,
    }
}

func vllm_metrics_avg_queue_depth(vllm_metrics_state state) float {
    if state.queue_depth_samples <= 0 {
        return 0.0
    }
    state.queue_depth_sum / state.queue_depth_samples
}
