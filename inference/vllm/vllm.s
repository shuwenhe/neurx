package neurx.inference.vllm.vllm
use neurx.inference.vllm.request_queue
use neurx.scheduler.inference_vllm_scheduler
use neurx.inference.vllm.metrics
use neurx.inference.vllm.prefix_cache
use neurx.attention.inference_paged

struct vllm_runtime_state {
    vllm_request_queue_state queue
    vllm_scheduler_state scheduler
    vllm_metrics_state metrics
    vllm_prefix_cache_state prefix_cache
    vllm_paged_attention_state paged_attention
}

struct vllm_runtime_step_result {
    vllm_runtime_state state
    string request_id
    int prefill_tokens
    int remaining_tokens
    bool selected
}

func new_vllm_runtime_state(int layer_count, int page_size, int max_pages, int max_prefix_entries, int max_prefix_tokens, string strategy) vllm_runtime_state {
    vllm_runtime_state {
        queue: new_vllm_request_queue_state(),
        scheduler: new_vllm_scheduler_state(strategy),
        metrics: new_vllm_metrics_state(),
        prefix_cache: new_vllm_prefix_cache_state(max_prefix_entries, max_prefix_tokens, 1024),
        paged_attention: new_vllm_paged_attention_state(layer_count, page_size, max_pages),
    }
}

func vllm_runtime_enqueue_request(vllm_runtime_state state, string request_id, int prefill_tokens, int remaining_tokens, bool accepted) vllm_runtime_state {
    vllm_request_queue_state queue = state.queue
    vllm_prefix_cache_state prefix_state = state.prefix_cache
    vllm_prefix_lookup_result lookup = vllm_prefix_lookup(prefix_state, request_id, prefill_tokens)
    prefix_state = lookup.state
    if accepted {
        prefix_state = vllm_prefix_insert(prefix_state, request_id, prefill_tokens)
        queue = vllm_queue_enqueue(queue, request_id, prefill_tokens, remaining_tokens)
    }
    vllm_metrics_state metrics = vllm_metrics_record_cache(state.metrics, lookup.hit)
    metrics = vllm_metrics_record_enqueue(metrics, accepted, vllm_queue_size(queue), prefill_tokens)
    vllm_runtime_state {
        queue: queue,
        scheduler: state.scheduler,
        metrics: metrics,
        prefix_cache: prefix_state,
        paged_attention: state.paged_attention,
    }
}

func vllm_runtime_schedule_next(vllm_runtime_state state) vllm_runtime_step_result {
    vllm_schedule_result scheduled = vllm_scheduler_next(state.scheduler, state.queue)
    vllm_paged_attention_state paged = state.paged_attention
    if scheduled.selected {
        paged = vllm_paged_attention_prefill(paged, scheduled.prefill_tokens)
    }
    vllm_runtime_step_result {
        state: vllm_runtime_state {
            queue: scheduled.queue,
            scheduler: scheduled.scheduler,
            metrics: state.metrics,
            prefix_cache: state.prefix_cache,
            paged_attention: paged,
        },
        request_id: scheduled.request_id,
        prefill_tokens: scheduled.prefill_tokens,
        remaining_tokens: scheduled.remaining_tokens,
        selected: scheduled.selected,
    }
}

func vllm_runtime_record_decode(vllm_runtime_state state, int decode_tokens) vllm_runtime_state {
    vllm_runtime_state {
        queue: state.queue,
        scheduler: state.scheduler,
        metrics: vllm_metrics_record_decode(state.metrics, decode_tokens),
        prefix_cache: state.prefix_cache,
        paged_attention: vllm_paged_attention_decode_step(state.paged_attention, decode_tokens),
    }
}

func vllm_runtime_finish_request(vllm_runtime_state state, int release_tokens) vllm_runtime_state {
    vllm_runtime_state {
        queue: state.queue,
        scheduler: vllm_scheduler_on_finish(state.scheduler),
        metrics: vllm_metrics_record_finish(state.metrics),
        prefix_cache: state.prefix_cache,
        paged_attention: vllm_paged_attention_release(state.paged_attention, release_tokens),
    }
}

func vllm_runtime_queue_depth(vllm_runtime_state state) int {
    vllm_queue_size(state.queue)
}

func vllm_runtime_state_dict(vllm_runtime_state state) vllm_runtime_state {
    state
}

func vllm_runtime_load_state_dict(vllm_runtime_state state, vllm_runtime_state other) vllm_runtime_state {
    other
}

