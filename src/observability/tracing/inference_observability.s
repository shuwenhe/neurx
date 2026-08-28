package neurx.observability.tracing.inference_observability
struct inference_trace_span {
    string trace_id
    string request_id
    string operation
    int start_ms
    int end_ms
    int status_code
    string error_message
}
struct inference_observability_state {
    int requests_total
    int requests_active
    int requests_failed
    int prompt_tokens_total
    int generated_tokens_total
    int cache_hits_total
    int cache_misses_total
    int kv_handoffs_total
    int tool_calls_total
    int structured_output_failures_total
    int latency_le_10_ms
    int latency_le_50_ms
    int latency_le_100_ms
    int latency_le_500_ms
    int latency_over_500_ms
    int latency_sum_ms
    []inference_trace_span spans
}
func new_inference_observability() inference_observability_state {
    inference_observability_state state
    state.requests_total = 0
    state.requests_active = 0
    state.requests_failed = 0
    state.prompt_tokens_total = 0
    state.generated_tokens_total = 0
    state.cache_hits_total = 0
    state.cache_misses_total = 0
    state.kv_handoffs_total = 0
    state.tool_calls_total = 0
    state.structured_output_failures_total = 0
    state.latency_le_10_ms = 0
    state.latency_le_50_ms = 0
    state.latency_le_100_ms = 0
    state.latency_le_500_ms = 0
    state.latency_over_500_ms = 0
    state.latency_sum_ms = 0
    state.spans = []inference_trace_span{cap: 4096}
    state
}
func observability_start_request(inference_observability_state state, int prompt_tokens) inference_observability_state {
    state.requests_total = state.requests_total + 1
    state.requests_active = state.requests_active + 1
    if prompt_tokens > 0 {
        state.prompt_tokens_total = state.prompt_tokens_total + prompt_tokens
    }
    state
}
func observability_finish_request(inference_observability_state state, int generated_tokens, int latency_ms, bool failed) inference_observability_state {
    if state.requests_active > 0 {
        state.requests_active = state.requests_active - 1
    }
    if generated_tokens > 0 {
        state.generated_tokens_total = state.generated_tokens_total + generated_tokens
    }
    if failed {
        state.requests_failed = state.requests_failed + 1
    }
    int latency = latency_ms
    if latency < 0 {
        latency = 0
    }
    state.latency_sum_ms = state.latency_sum_ms + latency
    if latency <= 10 {
        state.latency_le_10_ms = state.latency_le_10_ms + 1
    } else if latency <= 50 {
        state.latency_le_50_ms = state.latency_le_50_ms + 1
    } else if latency <= 100 {
        state.latency_le_100_ms = state.latency_le_100_ms + 1
    } else if latency <= 500 {
        state.latency_le_500_ms = state.latency_le_500_ms + 1
    } else {
        state.latency_over_500_ms = state.latency_over_500_ms + 1
    }
    state
}
func observability_record_cache(inference_observability_state state, bool hit) inference_observability_state {
    if hit {
        state.cache_hits_total = state.cache_hits_total + 1
    } else {
        state.cache_misses_total = state.cache_misses_total + 1
    }
    state
}
func observability_record_kv_handoff(inference_observability_state state) inference_observability_state {
    state.kv_handoffs_total = state.kv_handoffs_total + 1
    state
}
func observability_record_tool_call(inference_observability_state state, bool valid) inference_observability_state {
    state.tool_calls_total = state.tool_calls_total + 1
    if !valid {
        state.requests_failed = state.requests_failed + 1
    }
    state
}
func observability_record_structured_failure(inference_observability_state state) inference_observability_state {
    state.structured_output_failures_total = state.structured_output_failures_total + 1
    state
}
func observability_add_span(inference_observability_state state, string trace_id, string request_id, string operation, int start_ms, int end_ms, int status_code, string error_message) inference_observability_state {
    inference_trace_span span
    span.trace_id = trace_id
    span.request_id = request_id
    span.operation = operation
    span.start_ms = start_ms
    span.end_ms = end_ms
    span.status_code = status_code
    span.error_message = error_message
    state.spans = append(state.spans, span)
    state
}
func observability_prometheus(inference_observability_state state) string {
    int completed = state.requests_total - state.requests_active
    int bucket_50 = state.latency_le_10_ms + state.latency_le_50_ms
    int bucket_100 = bucket_50 + state.latency_le_100_ms
    int bucket_500 = bucket_100 + state.latency_le_500_ms
    string output = "neurx_inference_requests_total " + int_to_str(state.requests_total) + "\n"
    output = output + "neurx_inference_requests_active " + int_to_str(state.requests_active) + "\n"
    output = output + "neurx_inference_requests_failed_total " + int_to_str(state.requests_failed) + "\n"
    output = output + "neurx_inference_prompt_tokens_total " + int_to_str(state.prompt_tokens_total) + "\n"
    output = output + "neurx_inference_generated_tokens_total " + int_to_str(state.generated_tokens_total) + "\n"
    output = output + "neurx_inference_prefix_cache_hits_total " + int_to_str(state.cache_hits_total) + "\n"
    output = output + "neurx_inference_prefix_cache_misses_total " + int_to_str(state.cache_misses_total) + "\n"
    output = output + "neurx_inference_kv_handoffs_total " + int_to_str(state.kv_handoffs_total) + "\n"
    output = output + "neurx_inference_tool_calls_total " + int_to_str(state.tool_calls_total) + "\n"
    output = output + "neurx_inference_structured_output_failures_total " + int_to_str(state.structured_output_failures_total) + "\n"
    output = output + "neurx_inference_latency_ms_bucket{le=\"10\"} " + int_to_str(state.latency_le_10_ms) + "\n"
    output = output + "neurx_inference_latency_ms_bucket{le=\"50\"} " + int_to_str(bucket_50) + "\n"
    output = output + "neurx_inference_latency_ms_bucket{le=\"100\"} " + int_to_str(bucket_100) + "\n"
    output = output + "neurx_inference_latency_ms_bucket{le=\"500\"} " + int_to_str(bucket_500) + "\n"
    output = output + "neurx_inference_latency_ms_bucket{le=\"+Inf\"} " + int_to_str(completed) + "\n"
    output = output + "neurx_inference_latency_ms_sum " + int_to_str(state.latency_sum_ms) + "\n"
    output = output + "neurx_inference_latency_ms_count " + int_to_str(completed) + "\n"
    output
}
