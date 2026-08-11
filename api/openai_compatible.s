package neurx.api.openai_compatible

use neurx.inference.api.openai_protocol

func api_route_unknown() int { 0 }

func api_route_health() int { 1 }

func api_route_models() int { 2 }

func api_route_chat() int { 3 }

func api_route_completion() int { 4 }

func api_route_embeddings() int { 5 }

func api_route_metrics() int { 6 }

struct production_api_config {
    string served_model
    string api_key
    int max_body_bytes
    int max_tokens
    int max_inflight_requests
    int max_queued_requests
    bool allow_health_without_auth
}

struct production_api_request {
    string method
    string path
    string authorization
    string body
    string request_id
}

struct production_api_response {
    int status_code
    string content_type
    string body
    bool streaming
}

struct api_admission_state {
    int inflight_requests
    int queued_requests
    int accepted_total
    int rejected_total
}

struct production_api_result {
    api_admission_state admission
    openai_request request
    production_api_response response
    bool accepted
}

func default_production_api_config(string served_model) production_api_config {
    production_api_config config
    config.served_model = served_model
    config.api_key = ""
    config.max_body_bytes = 1048576
    config.max_tokens = 4096
    config.max_inflight_requests = 256
    config.max_queued_requests = 2048
    config.allow_health_without_auth = true
    config
}

func new_api_admission_state() api_admission_state {
    api_admission_state state
    state.inflight_requests = 0
    state.queued_requests = 0
    state.accepted_total = 0
    state.rejected_total = 0
    state
}

func api_empty_openai_request() openai_request {
    openai_request request
    request.request_id = ""
    request.model = ""
    request.prompt = ""
    request.max_tokens = 0
    request.temperature_milli = 0
    request.top_p_milli = 0
    request.stream = false
    request.response_format = "text"
    request.tool_choice = ""
    request.tool_parser = ""
    request.adapter_id = ""
    request.user = ""
    request
}

func api_response(int status_code, string content_type, string body, bool streaming) production_api_response {
    production_api_response response
    response.status_code = status_code
    response.content_type = content_type
    response.body = body
    response.streaming = streaming
    response
}

func api_error(int status_code, string message, string code) production_api_response {
    api_response(status_code, "application/json", neurx.inference.api.openai_protocol.openai_error_body(message, "invalid_request_error", code), false)
}

func api_new_result(api_admission_state admission, openai_request request, production_api_response response, bool accepted) production_api_result {
    production_api_result result
    result.admission = admission
    result.request = request
    result.response = response
    result.accepted = accepted
    result
}

func production_api_config_valid(production_api_config config) bool {
    config.served_model != "" && config.max_body_bytes > 0 && config.max_tokens > 0 && config.max_inflight_requests > 0 && config.max_queued_requests >= 0
}

func api_route_kind(string path) int {
    if path == "/health" || path == "/healthz" { return api_route_health() }
    if path == "/v1/models" { return api_route_models() }
    if path == "/v1/chat/completions" { return api_route_chat() }
    if path == "/v1/completions" { return api_route_completion() }
    if path == "/v1/embeddings" { return api_route_embeddings() }
    if path == "/metrics" { return api_route_metrics() }
    api_route_unknown()
}

func api_authorized(production_api_config config, production_api_request request, int route) bool {
    if route == api_route_health() && config.allow_health_without_auth { return true }
    if config.api_key == "" { return true }
    request.authorization == "Bearer " + config.api_key
}

func api_models_body(production_api_config config) string {
    "{\"object\":\"list\",\"data\":[{\"id\":\"" + neurx.inference.api.openai_protocol.openai_json_escape(config.served_model) + "\",\"object\":\"model\",\"owned_by\":\"neurx\"}]}"
}

func api_health_body(production_api_config config) string {
    "{\"status\":\"ok\",\"model\":\"" + neurx.inference.api.openai_protocol.openai_json_escape(config.served_model) + "\"}"
}

func api_reject(api_admission_state state, int status_code, string message, string code) production_api_result {
    state.rejected_total = state.rejected_total + 1
    api_new_result(state, api_empty_openai_request(), api_error(status_code, message, code), false)
}

func api_admit(production_api_config config, api_admission_state state, production_api_request incoming) production_api_result {
    if !production_api_config_valid(config) {
        return api_reject(state, 503, "API configuration is invalid", "service_unavailable")
    }
    int route = api_route_kind(incoming.path)
    if route == api_route_unknown() {
        return api_reject(state, 404, "route not found", "not_found")
    }
    if !api_authorized(config, incoming, route) {
        return api_reject(state, 401, "invalid API key", "invalid_api_key")
    }
    if route == api_route_health() {
        return api_new_result(state, api_empty_openai_request(), api_response(200, "application/json", api_health_body(config), false), false)
    }
    if route == api_route_models() {
        if incoming.method != "GET" { return api_reject(state, 405, "method not allowed", "method_not_allowed") }
        return api_new_result(state, api_empty_openai_request(), api_response(200, "application/json", api_models_body(config), false), false)
    }
    if route == api_route_metrics() {
        return api_new_result(state, api_empty_openai_request(), api_response(200, "text/plain; version=0.0.4", "", false), false)
    }
    if incoming.method != "POST" {
        return api_reject(state, 405, "method not allowed", "method_not_allowed")
    }
    if len(incoming.body) == 0 {
        return api_reject(state, 400, "request body is empty", "invalid_json")
    }
    if len(incoming.body) > config.max_body_bytes {
        return api_reject(state, 413, "request body is too large", "request_too_large")
    }
    if state.inflight_requests >= config.max_inflight_requests && state.queued_requests >= config.max_queued_requests {
        return api_reject(state, 429, "request capacity exhausted", "rate_limit_exceeded")
    }
    openai_request_result parsed = neurx.inference.api.openai_protocol.parse_openai_request(incoming.body, incoming.request_id)
    if !parsed.valid {
        return api_reject(state, parsed.status_code, parsed.error_message, "invalid_request")
    }
    if parsed.request.model != config.served_model {
        return api_reject(state, 404, "model is not served", "model_not_found")
    }
    if parsed.request.max_tokens > config.max_tokens {
        return api_reject(state, 400, "max_tokens exceeds server limit", "max_tokens_exceeded")
    }
    if state.inflight_requests < config.max_inflight_requests {
        state.inflight_requests = state.inflight_requests + 1
    } else {
        state.queued_requests = state.queued_requests + 1
    }
    state.accepted_total = state.accepted_total + 1
    api_new_result(state, parsed.request, api_response(202, "application/json", "", parsed.request.stream), true)
}

func api_finish(api_admission_state state) api_admission_state {
    if state.inflight_requests > 0 {
        state.inflight_requests = state.inflight_requests - 1
        if state.queued_requests > 0 {
            state.queued_requests = state.queued_requests - 1
            state.inflight_requests = state.inflight_requests + 1
        }
    }
    state
}

func api_chat_completion_body(openai_request request, string generated_text, string finish_reason, int prompt_tokens, int completion_tokens) string {
    string escaped_id = neurx.inference.api.openai_protocol.openai_json_escape(request.request_id)
    string escaped_model = neurx.inference.api.openai_protocol.openai_json_escape(request.model)
    string escaped_text = neurx.inference.api.openai_protocol.openai_json_escape(generated_text)
    string escaped_finish = neurx.inference.api.openai_protocol.openai_json_escape(finish_reason)
    "{\"id\":\"" + escaped_id + "\",\"object\":\"chat.completion\",\"model\":\"" + escaped_model + "\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"" + escaped_text + "\"},\"finish_reason\":\"" + escaped_finish + "\"}],\"usage\":{\"prompt_tokens\":" + neurx.inference.api.openai_protocol.int_to_str(prompt_tokens) + ",\"completion_tokens\":" + neurx.inference.api.openai_protocol.int_to_str(completion_tokens) + ",\"total_tokens\":" + neurx.inference.api.openai_protocol.int_to_str(prompt_tokens + completion_tokens) + "}}"
}

func api_complete(openai_request request, string generated_text, string finish_reason, int prompt_tokens, int completion_tokens) production_api_response {
    if request.stream {
        string body = neurx.inference.api.openai_protocol.openai_chat_chunk(request.request_id, request.model, generated_text, finish_reason)
        body = body + "data: [DONE]\n\n"
        return api_response(200, "text/event-stream", body, true)
    }
    string completion_body = api_chat_completion_body(request, generated_text, finish_reason, prompt_tokens, completion_tokens)
    api_response(200, "application/json", completion_body, false)
}

func api_contract_valid() bool {
    api_route_kind("/v1/chat/completions") == api_route_chat() && api_route_kind("/v1/models") == api_route_models() && api_route_kind("/missing") == api_route_unknown()
}
