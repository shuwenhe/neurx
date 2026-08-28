package neurx.serving.runtime.production_service
use neurx.serving.protocol.openai_tgi.{openai_chat_sse_chunk, openai_sse_done, openai_error_json}
use neurx.serving.runtime.production_runtime.{
    production_runtime_config,
    production_runtime_state,
    production_schedule_result,
    production_batch,
    new_production_runtime_state,
    production_submit,
    production_schedule,
    production_complete_prefill,
    production_complete_decode,
    production_release_kv,
    production_active_requests,
}

struct production_service_state {
    production_runtime_state runtime
    string default_model
    int64 request_seq
    int total_requests
    int total_errors
    int total_batches
    int total_chunks
}

struct production_service_request {
    string request_id
    string model
    string backend
    string dtype
    int prompt_tokens
    int cached_prefix_tokens
    int max_new_tokens
    bool stream
}

struct production_service_result {
    production_service_state state
    string request_id
    bool accepted
    string status
    string message
    string sse_frame
}

func new_production_service_state(production_runtime_config config, string default_model) production_service_state {
    production_service_state {
        runtime: new_production_runtime_state(config),
        default_model: default_model,
        request_seq: 0,
        total_requests: 0,
        total_errors: 0,
        total_batches: 0,
        total_chunks: 0,
    }
}

func normalize_service_model(string model, string default_model) string {
    if model != "" {
        return model
    }
    if default_model != "" {
        return default_model
    }
    "neurx"
}

func new_production_service_request(
    string request_id,
    string model,
    string backend,
    string dtype,
    int prompt_tokens,
    int cached_prefix_tokens,
    int max_new_tokens,
    bool stream
) production_service_request {
    production_service_request {
        request_id: request_id,
        model: model,
        backend: backend,
        dtype: dtype,
        prompt_tokens: prompt_tokens,
        cached_prefix_tokens: cached_prefix_tokens,
        max_new_tokens: max_new_tokens,
        stream: stream,
    }
}

func production_service_submit_request(
    production_service_state state,
    production_service_request request
) production_service_result {
    string model = normalize_service_model(request.model, state.default_model)
    production_runtime_state runtime_before = state.runtime
    production_runtime_state runtime_after = production_submit(
        runtime_before,
        request.request_id,
        request.backend,
        request.dtype,
        request.prompt_tokens,
        request.cached_prefix_tokens,
        request.max_new_tokens,
    )
    bool accepted = runtime_after.admitted_requests > runtime_before.admitted_requests
    string status = "accepted"
    string message = ""
    string frame = ""
    int next_total_requests = state.total_requests
    int next_total_errors = state.total_errors
    if !accepted {
        status = "rejected"
        message = "request rejected by admission control"
        frame = openai_error_json(message, "too_many_requests", 429)
        next_total_errors = next_total_errors + 1
    } else if request.stream {
        frame = openai_chat_sse_chunk(request.request_id, model, 0, "", "")
    }
    if accepted {
        next_total_requests = next_total_requests + 1
    }
    production_service_result {
        state: production_service_state {
            runtime: runtime_after,
            default_model: state.default_model,
            request_seq: state.request_seq + 1,
            total_requests: next_total_requests,
            total_errors: next_total_errors,
            total_batches: state.total_batches,
            total_chunks: state.total_chunks,
        },
        request_id: request.request_id,
        accepted: accepted,
        status: status,
        message: message,
        sse_frame: frame,
    }
}

func production_service_next_batch(production_service_state state) production_schedule_result {
    production_schedule(state.runtime)
}

func production_service_complete_prefill(
    production_service_state state,
    production_batch batch,
    bool succeeded
) production_service_state {
    production_service_state {
        runtime: production_complete_prefill(state.runtime, batch, succeeded),
        default_model: state.default_model,
        request_seq: state.request_seq,
        total_requests: state.total_requests,
        total_errors: state.total_errors,
        total_batches: state.total_batches + 1,
        total_chunks: state.total_chunks,
    }
}

func production_service_complete_decode(
    production_service_state state,
    production_batch batch,
    bool[] eos,
    bool succeeded
) production_service_state {
    production_service_state {
        runtime: production_complete_decode(state.runtime, batch, eos, succeeded),
        default_model: state.default_model,
        request_seq: state.request_seq,
        total_requests: state.total_requests,
        total_errors: state.total_errors,
        total_batches: state.total_batches + 1,
        total_chunks: state.total_chunks + len(batch.request_ids),
    }
}

func production_service_release_kv(production_service_state state, int tokens) production_service_state {
    production_service_state {
        runtime: production_release_kv(state.runtime, tokens),
        default_model: state.default_model,
        request_seq: state.request_seq,
        total_requests: state.total_requests,
        total_errors: state.total_errors,
        total_batches: state.total_batches,
        total_chunks: state.total_chunks,
    }
}

func production_service_render_done() string {
    openai_sse_done()
}

func production_service_render_error(string message, string error_type, int status) string {
    openai_error_json(message, error_type, status)
}

func production_service_render_chunk(string request_id, string model, int created, string content, string finish_reason) string {
    openai_chat_sse_chunk(request_id, model, created, content, finish_reason)
}

func production_service_active_requests(production_service_state state) int {
    production_active_requests(state.runtime)
}
