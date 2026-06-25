package neurx.serving.serve

use neurx.serving.serve.admission_control
use neurx.serving.serve.continuous_batch
use neurx.serving.vllm.metrics
use neurx.serving.vllm.vllm

struct infer_request_state {
    string request_id
    string model
    int input_tokens
    int max_new_tokens
}

struct infer_response_state {
    string request_id
    int output_tokens
    bool finished
    int status
}

func new_infer_request_state(string request_id, string model, int input_tokens, int max_new_tokens) infer_request_state {
    infer_request_state {
        request_id: request_id,
        model: model,
        input_tokens: input_tokens,
        max_new_tokens: max_new_tokens,
    }
}

func new_infer_response_state(string request_id) infer_response_state {
    infer_response_state {
        request_id: request_id,
        output_tokens: 0,
        finished: false,
        status: 200,
    }
}

func infer_response_update(infer_response_state state, int output_tokens, bool finished, int status) infer_response_state {
    infer_response_state {
        request_id: state.request_id,
        output_tokens: output_tokens,
        finished: finished,
        status: status,
    }
}

func infer_request_state_dict(infer_request_state state) infer_request_state {
    state
}

func infer_request_load_state_dict(infer_request_state state, infer_request_state other) infer_request_state {
    other
}

func infer_response_state_dict(infer_response_state state) infer_response_state {
    state
}

func infer_response_load_state_dict(infer_response_state state, infer_response_state other) infer_response_state {
    other
}

struct serving_runtime_config {
    int max_active_requests
    int max_prefill_tokens
    int batch_capacity
    int layer_count
    int page_size
    int max_pages
    int max_prefix_entries
    int max_prefix_tokens
    string policy
}

struct serving_runtime_state {
    serving_runtime_config config
    admission_control_state admission
    continuous_batch_state batch
    vllm_runtime_state vllm
    int accepted_requests
    int rejected_requests
    int finished_requests
    int last_status
}

func serving_runtime_effective_capacity(int max_active_requests, int batch_capacity) int {
    int effective_capacity = batch_capacity
    if effective_capacity <= 0 {
        effective_capacity = max_active_requests
    }
    if effective_capacity <= 0 {
        effective_capacity = 1
    }
    effective_capacity
}

func new_serving_runtime_config(int max_active_requests, int max_prefill_tokens, int batch_capacity, int layer_count, int page_size, int max_pages, int max_prefix_entries, int max_prefix_tokens, string policy) serving_runtime_config {
    int normalized_active_requests = max_active_requests
    if normalized_active_requests <= 0 {
        normalized_active_requests = 1
    }
    int normalized_prefill_tokens = max_prefill_tokens
    if normalized_prefill_tokens <= 0 {
        normalized_prefill_tokens = 1
    }
    int normalized_layer_count = layer_count
    if normalized_layer_count <= 0 {
        normalized_layer_count = 1
    }
    int normalized_page_size = page_size
    if normalized_page_size <= 0 {
        normalized_page_size = 1
    }
    int normalized_max_pages = max_pages
    if normalized_max_pages <= 0 {
        normalized_max_pages = 1
    }
    int normalized_prefix_entries = max_prefix_entries
    if normalized_prefix_entries <= 0 {
        normalized_prefix_entries = 1
    }
    int normalized_prefix_tokens = max_prefix_tokens
    if normalized_prefix_tokens <= 0 {
        normalized_prefix_tokens = 1
    }
    serving_runtime_config {
        max_active_requests: normalized_active_requests,
        max_prefill_tokens: normalized_prefill_tokens,
        batch_capacity: serving_runtime_effective_capacity(normalized_active_requests, batch_capacity),
        layer_count: normalized_layer_count,
        page_size: normalized_page_size,
        max_pages: normalized_max_pages,
        max_prefix_entries: normalized_prefix_entries,
        max_prefix_tokens: normalized_prefix_tokens,
        policy: policy,
    }
}

func new_serving_runtime_state(int max_active_requests, int max_prefill_tokens, int batch_capacity, int layer_count, int page_size, int max_pages, int max_prefix_entries, int max_prefix_tokens, string policy) serving_runtime_state {
    serving_runtime_config config = new_serving_runtime_config(max_active_requests, max_prefill_tokens, batch_capacity, layer_count, page_size, max_pages, max_prefix_entries, max_prefix_tokens, policy)
    admission_control_state admission = new_admission_control_state_with_policy(config.max_active_requests, config.max_prefill_tokens, config.policy)
    continuous_batch_state batch = new_continuous_batch_state(config.batch_capacity)
    vllm_runtime_state vllm = new_vllm_runtime_state(config.layer_count, config.page_size, config.max_pages, config.max_prefix_entries, config.max_prefix_tokens, admission.policy)

    serving_runtime_state {
        config: config,
        admission: admission,
        batch: batch,
        vllm: vllm,
        accepted_requests: 0,
        rejected_requests: 0,
        finished_requests: 0,
        last_status: 200,
    }
}

func serving_runtime_submit_request(serving_runtime_state state, string request_id, int prefill_tokens, int remaining_tokens) serving_runtime_state {
    int normalized_prefill = prefill_tokens
    if normalized_prefill < 0 {
        normalized_prefill = 0
    }
    int normalized_remaining = remaining_tokens
    if normalized_remaining < 0 {
        normalized_remaining = 0
    }

    bool accepted = admission_can_enqueue_with_remaining(state.admission, state.batch.active_requests, normalized_prefill, normalized_remaining)

    admission_control_state next_admission = admission_on_enqueue_with_remaining(state.admission, normalized_prefill, normalized_remaining, accepted)
    continuous_batch_state next_batch = state.batch
    if accepted {
        next_batch = continuous_batch_enqueue_request(next_batch, normalized_prefill)
    }
    vllm_runtime_state next_vllm = vllm_runtime_enqueue_request(state.vllm, request_id, normalized_prefill, normalized_remaining, accepted)

    int next_accepted = state.accepted_requests
    int next_rejected = state.rejected_requests
    int next_status = 200
    if accepted {
        next_accepted = next_accepted + 1
    } else {
        next_rejected = next_rejected + 1
        next_status = 429
    }

    serving_runtime_state {
        config: state.config,
        admission: next_admission,
        batch: next_batch,
        vllm: next_vllm,
        accepted_requests: next_accepted,
        rejected_requests: next_rejected,
        finished_requests: state.finished_requests,
        last_status: next_status,
    }
}

func serving_runtime_schedule_next(serving_runtime_state state) serving_runtime_state {
    vllm_runtime_step_result scheduled = vllm_runtime_schedule_next(state.vllm)
    int next_status = state.last_status
    if scheduled.selected {
        next_status = 202
    }
    serving_runtime_state {
        config: state.config,
        admission: state.admission,
        batch: state.batch,
        vllm: scheduled.state,
        accepted_requests: state.accepted_requests,
        rejected_requests: state.rejected_requests,
        finished_requests: state.finished_requests,
        last_status: next_status,
    }
}

func serving_runtime_record_decode(serving_runtime_state state, int decode_tokens) serving_runtime_state {
    int normalized_tokens = decode_tokens
    if normalized_tokens < 0 {
        normalized_tokens = 0
    }

    serving_runtime_state {
        config: state.config,
        admission: admission_on_decode_step(state.admission, normalized_tokens),
        batch: continuous_batch_record_decode_step(state.batch, normalized_tokens),
        vllm: vllm_runtime_record_decode(state.vllm, normalized_tokens),
        accepted_requests: state.accepted_requests,
        rejected_requests: state.rejected_requests,
        finished_requests: state.finished_requests,
        last_status: state.last_status,
    }
}

func serving_runtime_finish_request(serving_runtime_state state, int release_tokens) serving_runtime_state {
    int normalized_tokens = release_tokens
    if normalized_tokens < 0 {
        normalized_tokens = 0
    }

    serving_runtime_state {
        config: state.config,
        admission: admission_on_finish(state.admission, normalized_tokens),
        batch: continuous_batch_finish_request(state.batch),
        vllm: vllm_runtime_finish_request(state.vllm, normalized_tokens),
        accepted_requests: state.accepted_requests,
        rejected_requests: state.rejected_requests,
        finished_requests: state.finished_requests + 1,
        last_status: 200,
    }
}

func serving_runtime_active_requests(serving_runtime_state state) int {
    state.batch.active_requests
}

func serving_runtime_queue_depth(serving_runtime_state state) int {
    vllm_runtime_queue_depth(state.vllm)
}

func serving_runtime_last_selected_request(serving_runtime_state state) string {
    state.vllm.scheduler.last_selected_request
}

func serving_runtime_cache_hits(serving_runtime_state state) int {
    state.vllm.metrics.cache_hits
}

func serving_runtime_cache_misses(serving_runtime_state state) int {
    state.vllm.metrics.cache_misses
}

func serving_runtime_avg_queue_depth(serving_runtime_state state) float {
    vllm_metrics_avg_queue_depth(state.vllm.metrics)
}

func serving_runtime_state_dict(serving_runtime_state state) serving_runtime_state {
    state
}

func serving_runtime_load_state_dict(serving_runtime_state state, serving_runtime_state other) serving_runtime_state {
    other
}
