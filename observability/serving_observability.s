package neurx.observability.serving_observability
struct serving_observability_state {
    int requests_total
    int requests_active
    int requests_rejected
    int requests_failed
    int prefill_tokens
    int decode_tokens
    int queue_depth
    int kv_blocks_used
    int kv_blocks_capacity
    int latency_samples
    int latency_sum_ms
    int latency_max_ms
    []string trace_ids
    []string span_names
    []int span_start_ms
    []int span_duration_ms
    []string span_status
    bool queue_alert
    bool error_rate_alert
    bool kv_capacity_alert
}

func new_serving_observability_state(int kv_blocks_capacity) serving_observability_state {
    serving_observability_state {
        requests_total: 0, requests_active: 0, requests_rejected: 0, requests_failed: 0,
        prefill_tokens: 0, decode_tokens: 0, queue_depth: 0,
        kv_blocks_used: 0, kv_blocks_capacity: kv_blocks_capacity,
        latency_samples: 0, latency_sum_ms: 0, latency_max_ms: 0,
        trace_ids: [], span_names: [], span_start_ms: [], span_duration_ms: [], span_status: [],
        queue_alert: false, error_rate_alert: false, kv_capacity_alert: false,
    }
}

func serving_observe_admission(serving_observability_state state, bool accepted) serving_observability_state {
    state.requests_total = state.requests_total + 1
    if accepted { state.requests_active = state.requests_active + 1 } else { state.requests_rejected = state.requests_rejected + 1 }
    state
}

func serving_observe_completion(serving_observability_state state, bool success, int latency_ms) serving_observability_state {
    if state.requests_active > 0 { state.requests_active = state.requests_active - 1 }
    if !success { state.requests_failed = state.requests_failed + 1 }
    if latency_ms < 0 { latency_ms = 0 }
    state.latency_samples = state.latency_samples + 1
    state.latency_sum_ms = state.latency_sum_ms + latency_ms
    if latency_ms > state.latency_max_ms { state.latency_max_ms = latency_ms }
    state
}

func serving_observe_runtime(serving_observability_state state, int queue_depth, int prefill_tokens, int decode_tokens, int kv_blocks_used) serving_observability_state {
    state.queue_depth = queue_depth
    state.prefill_tokens = state.prefill_tokens + prefill_tokens
    state.decode_tokens = state.decode_tokens + decode_tokens
    state.kv_blocks_used = kv_blocks_used
    state.queue_alert = queue_depth > 1000
    state.error_rate_alert = state.requests_total >= 20 && state.requests_failed * 100 > state.requests_total * 5
    state.kv_capacity_alert = state.kv_blocks_capacity > 0 && kv_blocks_used * 100 > state.kv_blocks_capacity * 90
    state
}

func serving_trace_start(serving_observability_state state, string trace_id, string span_name, int now_ms) serving_observability_state {
    state.trace_ids = append(state.trace_ids, trace_id)
    state.span_names = append(state.span_names, span_name)
    state.span_start_ms = append(state.span_start_ms, now_ms)
    state.span_duration_ms = append(state.span_duration_ms, 0)
    state.span_status = append(state.span_status, "running")
    state
}

func serving_trace_finish(serving_observability_state state, string trace_id, int now_ms, bool ok) serving_observability_state {
    int i = len(state.trace_ids) - 1
    while i >= 0 {
        if state.trace_ids[i] == trace_id && state.span_status[i] == "running" {
            state.span_duration_ms[i] = now_ms - state.span_start_ms[i]
            if state.span_duration_ms[i] < 0 { state.span_duration_ms[i] = 0 }
            if ok { state.span_status[i] = "ok" } else { state.span_status[i] = "error" }
            return state
        }
        i = i - 1
    }
    state
}

func serving_prometheus_metrics(serving_observability_state state) string {
    string out = "# TYPE neurx_requests_total counter\nneurx_requests_total " + string(state.requests_total) + "\n"
    out = out + "# TYPE neurx_requests_active gauge\nneurx_requests_active " + string(state.requests_active) + "\n"
    out = out + "neurx_requests_rejected_total " + string(state.requests_rejected) + "\n"
    out = out + "neurx_requests_failed_total " + string(state.requests_failed) + "\n"
    out = out + "neurx_prefill_tokens_total " + string(state.prefill_tokens) + "\n"
    out = out + "neurx_decode_tokens_total " + string(state.decode_tokens) + "\n"
    out = out + "neurx_queue_depth " + string(state.queue_depth) + "\n"
    out = out + "neurx_kv_blocks_used " + string(state.kv_blocks_used) + "\n"
    out = out + "neurx_kv_blocks_capacity " + string(state.kv_blocks_capacity) + "\n"
    out = out + "neurx_request_latency_ms_sum " + string(state.latency_sum_ms) + "\n"
    out = out + "neurx_request_latency_ms_count " + string(state.latency_samples) + "\n"
    out = out + "neurx_request_latency_ms_max " + string(state.latency_max_ms) + "\n"
    out
}

func serving_alert_summary(serving_observability_state state) string {
    string alerts = ""
    if state.queue_alert { alerts = alerts + "queue_depth_high;" }
    if state.error_rate_alert { alerts = alerts + "error_rate_high;" }
    if state.kv_capacity_alert { alerts = alerts + "kv_capacity_high;" }
    alerts
}

