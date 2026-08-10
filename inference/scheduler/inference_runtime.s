package neurx.inference.scheduler.inference_runtime

use neurx.inference.queue.request_queue
use neurx.scheduler.inference_scheduler
use neurx.inference.metrics.inference_metrics
use neurx.inference.cache.prefix_cache
use neurx.attention.inference_paged

struct neurx_inference_runtime_state {
    neurx_request_queue_state queue
    neurx_scheduler_state scheduler
    neurx_metrics_state metrics
    neurx_prefix_cache_state prefix_cache
    neurx_paged_attention_state paged_attention
}

struct neurx_inference_runtime_step_result {
    neurx_inference_runtime_state state
    string request_id
    int prefill_tokens
    int remaining_tokens
    bool selected
}

func new_neurx_inference_runtime_state(int layer_count, int page_size, int max_pages, int max_prefix_entries, int max_prefix_tokens, string strategy) neurx_inference_runtime_state {
    neurx_inference_runtime_state {
        queue: new_neurx_request_queue_state(),
        scheduler: new_neurx_scheduler_state(strategy),
        metrics: new_neurx_metrics_state(),
        prefix_cache: new_neurx_prefix_cache_state(max_prefix_entries, max_prefix_tokens, 1024),
        paged_attention: new_neurx_paged_attention_state(layer_count, page_size, max_pages),
    }
}

func neurx_runtime_enqueue_request(neurx_inference_runtime_state state, string request_id, int prefill_tokens, int remaining_tokens, bool accepted) neurx_inference_runtime_state {
    neurx_request_queue_state queue = state.queue
    neurx_prefix_cache_state prefix_state = state.prefix_cache
    neurx_prefix_lookup_result lookup = neurx_prefix_lookup(prefix_state, request_id, prefill_tokens)
    prefix_state = lookup.state
    if accepted {
        prefix_state = neurx_prefix_insert(prefix_state, request_id, prefill_tokens)
        queue = neurx_queue_enqueue(queue, request_id, prefill_tokens, remaining_tokens)
    }
    neurx_metrics_state metrics = neurx_metrics_record_cache(state.metrics, lookup.hit)
    metrics = neurx_metrics_record_enqueue(metrics, accepted, neurx_queue_size(queue), prefill_tokens)
    neurx_inference_runtime_state {
        queue: queue,
        scheduler: state.scheduler,
        metrics: metrics,
        prefix_cache: prefix_state,
        paged_attention: state.paged_attention,
    }
}

func neurx_runtime_schedule_next(neurx_inference_runtime_state state) neurx_inference_runtime_step_result {
    neurx_schedule_result scheduled = neurx_scheduler_next(state.scheduler, state.queue)
    neurx_paged_attention_state paged = state.paged_attention
    if scheduled.selected {
        paged = neurx_paged_attention_prefill(paged, scheduled.prefill_tokens)
    }
    neurx_inference_runtime_step_result {
        state: neurx_inference_runtime_state {
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

func neurx_runtime_record_decode(neurx_inference_runtime_state state, int decode_tokens) neurx_inference_runtime_state {
    neurx_inference_runtime_state {
        queue: state.queue,
        scheduler: state.scheduler,
        metrics: neurx_metrics_record_decode(state.metrics, decode_tokens),
        prefix_cache: state.prefix_cache,
        paged_attention: neurx_paged_attention_decode_step(state.paged_attention, decode_tokens),
    }
}

func neurx_runtime_finish_request(neurx_inference_runtime_state state, int release_tokens) neurx_inference_runtime_state {
    neurx_inference_runtime_state {
        queue: state.queue,
        scheduler: neurx_scheduler_on_finish(state.scheduler),
        metrics: neurx_metrics_record_finish(state.metrics),
        prefix_cache: state.prefix_cache,
        paged_attention: neurx_paged_attention_release(state.paged_attention, release_tokens),
    }
}

func neurx_runtime_queue_depth(neurx_inference_runtime_state state) int {
    neurx_queue_size(state.queue)
}

func neurx_inference_runtime_state_dict(neurx_inference_runtime_state state) neurx_inference_runtime_state {
    state
}

func neurx_runtime_load_state_dict(neurx_inference_runtime_state state, neurx_inference_runtime_state other) neurx_inference_runtime_state {
    other
}
