package neurx.inference.metrics.inference_metrics

struct neurx_metrics_state {
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

func new_neurx_metrics_state() neurx_metrics_state {
    neurx_metrics_state {
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

func neurx_metrics_record_enqueue(neurx_metrics_state state, bool accepted, int queue_depth, int prefill_tokens) neurx_metrics_state {
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
    neurx_metrics_state {
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

func neurx_metrics_record_decode(neurx_metrics_state state, int tokens) neurx_metrics_state {
    int add_tokens = tokens
    if add_tokens < 0 {
        add_tokens = 0
    }
    neurx_metrics_state {
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

func neurx_metrics_record_cache(neurx_metrics_state state, bool hit) neurx_metrics_state {
    int next_hits = state.cache_hits
    int next_misses = state.cache_misses
    if hit {
        next_hits = next_hits + 1
    } else {
        next_misses = next_misses + 1
    }
    neurx_metrics_state {
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

func neurx_metrics_record_finish(neurx_metrics_state state) neurx_metrics_state {
    neurx_metrics_state {
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

func neurx_metrics_avg_queue_depth(neurx_metrics_state state) float {
    if state.queue_depth_samples <= 0 {
        return 0.0
    }
    state.queue_depth_sum / state.queue_depth_samples
}

func neurx_metrics_hit_rate(neurx_metrics_state state) float {
    int total = state.cache_hits + state.cache_misses
    if total <= 0 {
        return 0.0
    }
    state.cache_hits / total
}

func neurx_metrics_state_dict(neurx_metrics_state state) neurx_metrics_state {
    state
}

func neurx_metrics_load_state_dict(neurx_metrics_state state, neurx_metrics_state other) neurx_metrics_state {
    other
}
