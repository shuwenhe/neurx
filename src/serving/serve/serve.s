package neurx.serving.serve

func mod(int a, int b) int {
    if b == 0 {
        return 0
    }
    a - (a / b) * b
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    bool neg = n < 0
    if neg {
        n = -n
    }
    string s = ""
    for n > 0 {
        s = string(mod(n, 10) + 48) + s
        n = n / 10
    }
    if neg {
        s = "-" + s
    }
    return s
}

struct admission_control_state {
    int max_active_requests
    int max_prefill_tokens
    string policy
    int current_prefill_tokens
    int current_decode_tokens
    int admitted
    int rejected
    int last_remaining_tokens
    int last_priority_score
}

func normalize_policy(string policy) string {
    if policy == "srpt" {
        return "srpt"
    }
    "fcfs"
}

func new_admission_control_state_with_policy(int max_active_requests, int max_prefill_tokens, string policy) admission_control_state {
    int normalized_active = max_active_requests
    if normalized_active <= 0 {
        normalized_active = 1
    }
    int normalized_prefill = max_prefill_tokens
    if normalized_prefill <= 0 {
        normalized_prefill = 1
    }
    admission_control_state {
        max_active_requests: normalized_active,
        max_prefill_tokens: normalized_prefill,
        policy: normalize_policy(policy),
        current_prefill_tokens: 0,
        current_decode_tokens: 0,
        admitted: 0,
        rejected: 0,
        last_remaining_tokens: 0,
        last_priority_score: 0,
    }
}

func admission_priority_score(admission_control_state state, int remaining_tokens, int queue_depth) int {
    int normalized_remaining = remaining_tokens
    if normalized_remaining < 0 {
        normalized_remaining = 0
    }
    int normalized_queue = queue_depth
    if normalized_queue < 0 {
        normalized_queue = 0
    }
    if state.policy == "srpt" {
        return normalized_remaining
    }
    normalized_queue
}

func admission_can_enqueue_with_remaining(admission_control_state state, int active_requests, int prefill_tokens, int remaining_tokens) bool {
    int add_prefill = prefill_tokens
    if add_prefill < 0 {
        add_prefill = 0
    }
    int normalized_remaining = remaining_tokens
    if normalized_remaining < 0 {
        normalized_remaining = 0
    }
    if active_requests >= state.max_active_requests {
        return false
    }
    if state.current_prefill_tokens + add_prefill > state.max_prefill_tokens {
        return false
    }
    if state.policy == "srpt" && normalized_remaining > state.max_prefill_tokens {
        return false
    }
    true
}

func admission_on_enqueue_with_remaining(admission_control_state state, int prefill_tokens, int remaining_tokens, bool accepted) admission_control_state {
    int add_prefill = prefill_tokens
    if add_prefill < 0 {
        add_prefill = 0
    }
    int normalized_remaining = remaining_tokens
    if normalized_remaining < 0 {
        normalized_remaining = 0
    }
    if !accepted {
        return admission_control_state {
            max_active_requests: state.max_active_requests,
            max_prefill_tokens: state.max_prefill_tokens,
            policy: state.policy,
            current_prefill_tokens: state.current_prefill_tokens,
            current_decode_tokens: state.current_decode_tokens,
            admitted: state.admitted,
            rejected: state.rejected + 1,
            last_remaining_tokens: state.last_remaining_tokens,
            last_priority_score: state.last_priority_score,
        }
    }
    admission_control_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        policy: state.policy,
        current_prefill_tokens: state.current_prefill_tokens + add_prefill,
        current_decode_tokens: state.current_decode_tokens,
        admitted: state.admitted + 1,
        rejected: state.rejected,
        last_remaining_tokens: normalized_remaining,
        last_priority_score: admission_priority_score(state, normalized_remaining, state.admitted + state.rejected),
    }
}

func admission_on_decode_step(admission_control_state state, int decode_tokens) admission_control_state {
    int add_decode = decode_tokens
    if add_decode < 0 {
        add_decode = 0
    }
    admission_control_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        policy: state.policy,
        current_prefill_tokens: state.current_prefill_tokens,
        current_decode_tokens: state.current_decode_tokens + add_decode,
        admitted: state.admitted,
        rejected: state.rejected,
        last_remaining_tokens: state.last_remaining_tokens,
        last_priority_score: state.last_priority_score,
    }
}

func admission_on_finish(admission_control_state state, int release_prefill_tokens) admission_control_state {
    int release_tokens = release_prefill_tokens
    if release_tokens < 0 {
        release_tokens = 0
    }
    int next_prefill = state.current_prefill_tokens - release_tokens
    if next_prefill < 0 {
        next_prefill = 0
    }
    admission_control_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        policy: state.policy,
        current_prefill_tokens: next_prefill,
        current_decode_tokens: state.current_decode_tokens,
        admitted: state.admitted,
        rejected: state.rejected,
        last_remaining_tokens: state.last_remaining_tokens,
        last_priority_score: state.last_priority_score,
    }
}

struct continuous_batch_state {
    int capacity
    int active_requests
    int queued_requests
    int total_served
    int scheduling_round
    int prefill_tokens
    int decode_tokens
}

func new_continuous_batch_state(int capacity) continuous_batch_state {
    int effective_capacity = capacity
    if effective_capacity <= 0 {
        effective_capacity = 1
    }
    continuous_batch_state {
        capacity: effective_capacity,
        active_requests: 0,
        queued_requests: 0,
        total_served: 0,
        scheduling_round: 0,
        prefill_tokens: 0,
        decode_tokens: 0,
    }
}

func continuous_batch_enqueue_request(continuous_batch_state state, int prefill_tokens) continuous_batch_state {
    int next_active = state.active_requests
    int next_queued = state.queued_requests
    if next_active < state.capacity {
        next_active = next_active + 1
    } else {
        next_queued = next_queued + 1
    }
    int add_prefill = prefill_tokens
    if add_prefill < 0 {
        add_prefill = 0
    }
    continuous_batch_state {
        capacity: state.capacity,
        active_requests: next_active,
        queued_requests: next_queued,
        total_served: state.total_served,
        scheduling_round: state.scheduling_round + 1,
        prefill_tokens: state.prefill_tokens + add_prefill,
        decode_tokens: state.decode_tokens,
    }
}

func continuous_batch_record_decode_step(continuous_batch_state state, int tokens) continuous_batch_state {
    int add_tokens = tokens
    if add_tokens < 0 {
        add_tokens = 0
    }
    continuous_batch_state {
        capacity: state.capacity,
        active_requests: state.active_requests,
        queued_requests: state.queued_requests,
        total_served: state.total_served,
        scheduling_round: state.scheduling_round + 1,
        prefill_tokens: state.prefill_tokens,
        decode_tokens: state.decode_tokens + add_tokens,
    }
}

func continuous_batch_finish_request(continuous_batch_state state) continuous_batch_state {
    int next_active = state.active_requests
    if next_active > 0 {
        next_active = next_active - 1
    }
    int next_queued = state.queued_requests
    if next_queued > 0 {
        next_queued = next_queued - 1
        if next_active < state.capacity {
            next_active = next_active + 1
        }
    }
    continuous_batch_state {
        capacity: state.capacity,
        active_requests: next_active,
        queued_requests: next_queued,
        total_served: state.total_served + 1,
        scheduling_round: state.scheduling_round + 1,
        prefill_tokens: state.prefill_tokens,
        decode_tokens: state.decode_tokens,
    }
}

struct runtime_state {
    int queue_depth
    string pending_request_id
    string last_selected_request
    int cache_hits
    int cache_misses
    int last_prefill_tokens
    int last_remaining_tokens
}

func new_runtime_state(int layer_count, int page_size, int max_pages, int max_prefix_entries, int max_prefix_tokens, string strategy) runtime_state {
    runtime_state {
        queue_depth: 0,
        pending_request_id: "",
        last_selected_request: "",
        cache_hits: 0,
        cache_misses: 0,
        last_prefill_tokens: 0,
        last_remaining_tokens: 0,
    }
}

func runtime_enqueue_request(runtime_state state, string request_id, int prefill_tokens, int remaining_tokens, bool accepted) runtime_state {
    int next_queue_depth = state.queue_depth
    int next_hits = state.cache_hits
    int next_misses = state.cache_misses
    string pending_request_id = state.pending_request_id
    int normalized_prefill = prefill_tokens
    if normalized_prefill < 0 {
        normalized_prefill = 0
    }
    int normalized_remaining = remaining_tokens
    if normalized_remaining < 0 {
        normalized_remaining = 0
    }
    if accepted {
        next_queue_depth = next_queue_depth + 1
        pending_request_id = request_id
        if normalized_prefill == 0 {
            next_hits = next_hits + 1
        } else {
            next_misses = next_misses + 1
        }
    }
    runtime_state {
        queue_depth: next_queue_depth,
        pending_request_id: pending_request_id,
        last_selected_request: state.last_selected_request,
        cache_hits: next_hits,
        cache_misses: next_misses,
        last_prefill_tokens: normalized_prefill,
        last_remaining_tokens: normalized_remaining,
    }
}

func runtime_schedule_next(runtime_state state) runtime_state {
    if state.queue_depth <= 0 {
        return state
    }
    int next_queue_depth = state.queue_depth - 1
    if next_queue_depth < 0 {
        next_queue_depth = 0
    }
    runtime_state {
        queue_depth: next_queue_depth,
        pending_request_id: "",
        last_selected_request: state.pending_request_id,
        cache_hits: state.cache_hits,
        cache_misses: state.cache_misses,
        last_prefill_tokens: state.last_prefill_tokens,
        last_remaining_tokens: state.last_remaining_tokens,
    }
}

func runtime_record_decode(runtime_state state, int decode_tokens) runtime_state {
    runtime_state {
        queue_depth: state.queue_depth,
        pending_request_id: state.pending_request_id,
        last_selected_request: state.last_selected_request,
        cache_hits: state.cache_hits,
        cache_misses: state.cache_misses,
        last_prefill_tokens: state.last_prefill_tokens,
        last_remaining_tokens: state.last_remaining_tokens,
    }
}

func runtime_finish_request(runtime_state state, int release_tokens) runtime_state {
    runtime_state {
        queue_depth: state.queue_depth,
        pending_request_id: state.pending_request_id,
        last_selected_request: state.last_selected_request,
        cache_hits: state.cache_hits,
        cache_misses: state.cache_misses,
        last_prefill_tokens: state.last_prefill_tokens,
        last_remaining_tokens: state.last_remaining_tokens,
    }
}

func runtime_queue_depth(runtime_state state) int {
    state.queue_depth
}

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
    int max_active_requests
    int max_prefill_tokens
    int batch_capacity
    int layer_count
    int page_size
    int max_pages
    int max_prefix_entries
    int max_prefix_tokens
    string policy
    int current_prefill_tokens
    int current_decode_tokens
    int admitted
    int rejected
    int last_remaining_tokens
    int last_priority_score
    int active_requests
    int queued_requests
    int total_served
    int scheduling_round
    int batch_prefill_tokens
    int batch_decode_tokens
    int queue_depth
    string pending_request_id
    string last_selected_request
    int cache_hits
    int cache_misses
    int last_prefill_tokens
    int last_remaining_tokens_runtime
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
    runtime_state runtime_engine = new_runtime_state(config.layer_count, config.page_size, config.max_pages, config.max_prefix_entries, config.max_prefix_tokens, admission.policy)
    serving_runtime_state {
        max_active_requests: config.max_active_requests,
        max_prefill_tokens: config.max_prefill_tokens,
        batch_capacity: config.batch_capacity,
        layer_count: config.layer_count,
        page_size: config.page_size,
        max_pages: config.max_pages,
        max_prefix_entries: config.max_prefix_entries,
        max_prefix_tokens: config.max_prefix_tokens,
        policy: config.policy,
        current_prefill_tokens: admission.current_prefill_tokens,
        current_decode_tokens: admission.current_decode_tokens,
        admitted: admission.admitted,
        rejected: admission.rejected,
        last_remaining_tokens: admission.last_remaining_tokens,
        last_priority_score: admission.last_priority_score,
        active_requests: batch.active_requests,
        queued_requests: batch.queued_requests,
        total_served: batch.total_served,
        scheduling_round: batch.scheduling_round,
        batch_prefill_tokens: batch.prefill_tokens,
        batch_decode_tokens: batch.decode_tokens,
        queue_depth: runtime_engine.queue_depth,
        pending_request_id: runtime_engine.pending_request_id,
        last_selected_request: runtime_engine.last_selected_request,
        cache_hits: runtime_engine.cache_hits,
        cache_misses: runtime_engine.cache_misses,
        last_prefill_tokens: runtime_engine.last_prefill_tokens,
        last_remaining_tokens_runtime: runtime_engine.last_remaining_tokens,
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
    admission_control_state admission = admission_control_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        policy: state.policy,
        current_prefill_tokens: state.current_prefill_tokens,
        current_decode_tokens: state.current_decode_tokens,
        admitted: state.admitted,
        rejected: state.rejected,
        last_remaining_tokens: state.last_remaining_tokens,
        last_priority_score: state.last_priority_score,
    }
    continuous_batch_state batch = continuous_batch_state {
        capacity: state.batch_capacity,
        active_requests: state.active_requests,
        queued_requests: state.queued_requests,
        total_served: state.total_served,
        scheduling_round: state.scheduling_round,
        prefill_tokens: state.batch_prefill_tokens,
        decode_tokens: state.batch_decode_tokens,
    }
    runtime_state runtime_engine = runtime_state {
        queue_depth: state.queue_depth,
        pending_request_id: state.pending_request_id,
        last_selected_request: state.last_selected_request,
        cache_hits: state.cache_hits,
        cache_misses: state.cache_misses,
        last_prefill_tokens: state.last_prefill_tokens,
        last_remaining_tokens: state.last_remaining_tokens_runtime,
    }
    bool accepted = admission_can_enqueue_with_remaining(admission, batch.active_requests, normalized_prefill, normalized_remaining)
    admission_control_state next_admission = admission_on_enqueue_with_remaining(admission, normalized_prefill, normalized_remaining, accepted)
    continuous_batch_state next_batch = batch
    if accepted {
        next_batch = continuous_batch_enqueue_request(next_batch, normalized_prefill)
    }
    runtime_state next_engine = runtime_enqueue_request(runtime_engine, request_id, normalized_prefill, normalized_remaining, accepted)
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
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        batch_capacity: state.batch_capacity,
        layer_count: state.layer_count,
        page_size: state.page_size,
        max_pages: state.max_pages,
        max_prefix_entries: state.max_prefix_entries,
        max_prefix_tokens: state.max_prefix_tokens,
        policy: state.policy,
        current_prefill_tokens: next_admission.current_prefill_tokens,
        current_decode_tokens: next_admission.current_decode_tokens,
        admitted: next_admission.admitted,
        rejected: next_admission.rejected,
        last_remaining_tokens: next_admission.last_remaining_tokens,
        last_priority_score: next_admission.last_priority_score,
        active_requests: next_batch.active_requests,
        queued_requests: next_batch.queued_requests,
        total_served: next_batch.total_served,
        scheduling_round: next_batch.scheduling_round,
        batch_prefill_tokens: next_batch.prefill_tokens,
        batch_decode_tokens: next_batch.decode_tokens,
        queue_depth: next_runtime_engine.queue_depth,
        pending_request_id: next_runtime_engine.pending_request_id,
        last_selected_request: next_runtime_engine.last_selected_request,
        cache_hits: next_runtime_engine.cache_hits,
        cache_misses: next_runtime_engine.cache_misses,
        last_prefill_tokens: next_runtime_engine.last_prefill_tokens,
        last_remaining_tokens_runtime: next_runtime_engine.last_remaining_tokens,
        accepted_requests: next_accepted,
        rejected_requests: next_rejected,
        finished_requests: state.finished_requests,
        last_status: next_status,
    }
}

func serving_runtime_schedule_next(serving_runtime_state state) serving_runtime_state {
    runtime_state runtime_engine = runtime_state {
        queue_depth: state.queue_depth,
        pending_request_id: state.pending_request_id,
        last_selected_request: state.last_selected_request,
        cache_hits: state.cache_hits,
        cache_misses: state.cache_misses,
        last_prefill_tokens: state.last_prefill_tokens,
        last_remaining_tokens: state.last_remaining_tokens_runtime,
    }
    bool selected = state.queue_depth > 0
    runtime_state next_engine = runtime_schedule_next(runtime_engine)
    int next_status = state.last_status
    if selected {
        next_status = 202
    }
    serving_runtime_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        batch_capacity: state.batch_capacity,
        layer_count: state.layer_count,
        page_size: state.page_size,
        max_pages: state.max_pages,
        max_prefix_entries: state.max_prefix_entries,
        max_prefix_tokens: state.max_prefix_tokens,
        policy: state.policy,
        current_prefill_tokens: state.current_prefill_tokens,
        current_decode_tokens: state.current_decode_tokens,
        admitted: state.admitted,
        rejected: state.rejected,
        last_remaining_tokens: state.last_remaining_tokens,
        last_priority_score: state.last_priority_score,
        active_requests: state.active_requests,
        queued_requests: state.queued_requests,
        total_served: state.total_served,
        scheduling_round: state.scheduling_round,
        batch_prefill_tokens: state.batch_prefill_tokens,
        batch_decode_tokens: state.batch_decode_tokens,
        queue_depth: next_runtime_engine.queue_depth,
        pending_request_id: next_runtime_engine.pending_request_id,
        last_selected_request: next_runtime_engine.last_selected_request,
        cache_hits: next_runtime_engine.cache_hits,
        cache_misses: next_runtime_engine.cache_misses,
        last_prefill_tokens: next_runtime_engine.last_prefill_tokens,
        last_remaining_tokens_runtime: next_runtime_engine.last_remaining_tokens,
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
    admission_control_state admission = admission_control_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        policy: state.policy,
        current_prefill_tokens: state.current_prefill_tokens,
        current_decode_tokens: state.current_decode_tokens,
        admitted: state.admitted,
        rejected: state.rejected,
        last_remaining_tokens: state.last_remaining_tokens,
        last_priority_score: state.last_priority_score,
    }
    continuous_batch_state batch = continuous_batch_state {
        capacity: state.batch_capacity,
        active_requests: state.active_requests,
        queued_requests: state.queued_requests,
        total_served: state.total_served,
        scheduling_round: state.scheduling_round,
        prefill_tokens: state.batch_prefill_tokens,
        decode_tokens: state.batch_decode_tokens,
    }
    runtime_state runtime_engine = runtime_state {
        queue_depth: state.queue_depth,
        pending_request_id: state.pending_request_id,
        last_selected_request: state.last_selected_request,
        cache_hits: state.cache_hits,
        cache_misses: state.cache_misses,
        last_prefill_tokens: state.last_prefill_tokens,
        last_remaining_tokens: state.last_remaining_tokens_runtime,
    }
    admission_control_state next_admission = admission_on_decode_step(admission, normalized_tokens)
    continuous_batch_state next_batch = continuous_batch_record_decode_step(batch, normalized_tokens)
    runtime_state next_engine = runtime_record_decode(runtime_engine, normalized_tokens)
    serving_runtime_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        batch_capacity: state.batch_capacity,
        layer_count: state.layer_count,
        page_size: state.page_size,
        max_pages: state.max_pages,
        max_prefix_entries: state.max_prefix_entries,
        max_prefix_tokens: state.max_prefix_tokens,
        policy: state.policy,
        current_prefill_tokens: next_admission.current_prefill_tokens,
        current_decode_tokens: next_admission.current_decode_tokens,
        admitted: next_admission.admitted,
        rejected: next_admission.rejected,
        last_remaining_tokens: next_admission.last_remaining_tokens,
        last_priority_score: next_admission.last_priority_score,
        active_requests: next_batch.active_requests,
        queued_requests: next_batch.queued_requests,
        total_served: next_batch.total_served,
        scheduling_round: next_batch.scheduling_round,
        batch_prefill_tokens: next_batch.prefill_tokens,
        batch_decode_tokens: next_batch.decode_tokens,
        queue_depth: next_runtime_engine.queue_depth,
        pending_request_id: next_runtime_engine.pending_request_id,
        last_selected_request: next_runtime_engine.last_selected_request,
        cache_hits: next_runtime_engine.cache_hits,
        cache_misses: next_runtime_engine.cache_misses,
        last_prefill_tokens: next_runtime_engine.last_prefill_tokens,
        last_remaining_tokens_runtime: next_runtime_engine.last_remaining_tokens,
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
    admission_control_state admission = admission_control_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        policy: state.policy,
        current_prefill_tokens: state.current_prefill_tokens,
        current_decode_tokens: state.current_decode_tokens,
        admitted: state.admitted,
        rejected: state.rejected,
        last_remaining_tokens: state.last_remaining_tokens,
        last_priority_score: state.last_priority_score,
    }
    continuous_batch_state batch = continuous_batch_state {
        capacity: state.batch_capacity,
        active_requests: state.active_requests,
        queued_requests: state.queued_requests,
        total_served: state.total_served,
        scheduling_round: state.scheduling_round,
        prefill_tokens: state.batch_prefill_tokens,
        decode_tokens: state.batch_decode_tokens,
    }
    runtime_state runtime_engine = runtime_state {
        queue_depth: state.queue_depth,
        pending_request_id: state.pending_request_id,
        last_selected_request: state.last_selected_request,
        cache_hits: state.cache_hits,
        cache_misses: state.cache_misses,
        last_prefill_tokens: state.last_prefill_tokens,
        last_remaining_tokens: state.last_remaining_tokens_runtime,
    }
    admission_control_state next_admission = admission_on_finish(admission, normalized_tokens)
    continuous_batch_state next_batch = continuous_batch_finish_request(batch)
    runtime_state next_engine = runtime_finish_request(runtime_engine, normalized_tokens)
    serving_runtime_state {
        max_active_requests: state.max_active_requests,
        max_prefill_tokens: state.max_prefill_tokens,
        batch_capacity: state.batch_capacity,
        layer_count: state.layer_count,
        page_size: state.page_size,
        max_pages: state.max_pages,
        max_prefix_entries: state.max_prefix_entries,
        max_prefix_tokens: state.max_prefix_tokens,
        policy: state.policy,
        current_prefill_tokens: next_admission.current_prefill_tokens,
        current_decode_tokens: next_admission.current_decode_tokens,
        admitted: next_admission.admitted,
        rejected: next_admission.rejected,
        last_remaining_tokens: next_admission.last_remaining_tokens,
        last_priority_score: next_admission.last_priority_score,
        active_requests: next_batch.active_requests,
        queued_requests: next_batch.queued_requests,
        total_served: next_batch.total_served,
        scheduling_round: next_batch.scheduling_round,
        batch_prefill_tokens: next_batch.prefill_tokens,
        batch_decode_tokens: next_batch.decode_tokens,
        queue_depth: next_runtime_engine.queue_depth,
        pending_request_id: next_runtime_engine.pending_request_id,
        last_selected_request: next_runtime_engine.last_selected_request,
        cache_hits: next_runtime_engine.cache_hits,
        cache_misses: next_runtime_engine.cache_misses,
        last_prefill_tokens: next_runtime_engine.last_prefill_tokens,
        last_remaining_tokens_runtime: next_runtime_engine.last_remaining_tokens,
        accepted_requests: state.accepted_requests,
        rejected_requests: state.rejected_requests,
        finished_requests: state.finished_requests + 1,
        last_status: 200,
    }
}

func serving_runtime_active_requests(serving_runtime_state state) int {
    int active_requests = state.active_requests
    active_requests
}

func serving_runtime_queue_depth(serving_runtime_state state) int {
    int queue_depth = state.queue_depth
    queue_depth
}

func serving_runtime_last_selected_request(serving_runtime_state state) string {
    string request_id = state.last_selected_request
    request_id
}

func serving_runtime_cache_hits(serving_runtime_state state) int {
    int cache_hits = state.cache_hits
    cache_hits
}

func serving_runtime_cache_misses(serving_runtime_state state) int {
    int cache_misses = state.cache_misses
    cache_misses
}

func serving_runtime_avg_queue_depth(serving_runtime_state state) float {
    float queue_depth = float(state.queue_depth)
    queue_depth
}

func serving_runtime_state_dict(serving_runtime_state state) serving_runtime_state {
    state
}

func serving_runtime_load_state_dict(serving_runtime_state state, serving_runtime_state other) serving_runtime_state {
    other
}

func serving_runtime_smoke_test() int {
    serving_runtime_state state = new_serving_runtime_state(4, 128, 4, 8, 16, 16, 64, 1024, "srpt")
    println("serving smoke test")
    println("active_requests=" + int_to_str(serving_runtime_active_requests(state)))
    println("queue_depth=" + int_to_str(serving_runtime_queue_depth(state)))
    state = serving_runtime_submit_request(state, "req-1", 32, 16)
    state = serving_runtime_submit_request(state, "req-2", 24, 12)
    println("accepted_after_submit=" + int_to_str(state.accepted_requests))
    println("rejected_after_submit=" + int_to_str(state.rejected_requests))
    println("active_after_submit=" + int_to_str(serving_runtime_active_requests(state)))
    println("queue_after_submit=" + int_to_str(serving_runtime_queue_depth(state)))
    state = serving_runtime_schedule_next(state)
    println("last_status=" + int_to_str(state.last_status))
    println("selected_request=" + serving_runtime_last_selected_request(state))
    state = serving_runtime_record_decode(state, 8)
    state = serving_runtime_finish_request(state, 32)
    println("finished_requests=" + int_to_str(state.finished_requests))
    println("active_after_finish=" + int_to_str(serving_runtime_active_requests(state)))
    println("queue_after_finish=" + int_to_str(serving_runtime_queue_depth(state)))
    println("cache_hits=" + int_to_str(serving_runtime_cache_hits(state)))
    println("cache_misses=" + int_to_str(serving_runtime_cache_misses(state)))
    0
}
