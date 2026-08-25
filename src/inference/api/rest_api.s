use std.conv.int_to_string
use std.conv.string_to_int

package neurx.inference.api.rest_api
use neurx.inference.runtime.real_text_engine.{real_text_engine_state, real_generation_result, load_real_text_engine, generate_response, resolve_model_path_from_env, resolve_prompt_from_body, parse_max_tokens, parse_bool, build_health_json, build_models_json, build_generate_json, build_chat_completion_json}
use src.net.http.{http_request, http_response}

struct inference_request {
    string prompt
    int max_tokens
    float temperature
    float top_p
    int top_k
    bool stream
}

struct inference_response {
    string response
    int tokens_generated
    float latency_ms
}

g_cached_engine := real_text_engine_state{}
g_cached_engine_path := ""
g_cached_engine_loaded := false

func parse_json_string(string json_str, string key) string {
    start_key := "\"" + key + "\":"
    start_idx := index_of(json_str, start_key)
    if start_idx < 0 {
        return ""
    }
    start_idx = start_idx + len(start_key)
    if json_str[start_idx] == '"' {
        start_idx = start_idx + 1
        end_idx := index_of_from(json_str, "\"", start_idx)
        if end_idx < 0 {
            return ""
        }
        return json_str[start_idx:end_idx]
    }
    return ""
}

func parse_json_int(string json_str, string key) int {
    start_key := "\"" + key + "\":"
    start_idx := index_of(json_str, start_key)
    if start_idx < 0 {
        return 0
    }
    start_idx = start_idx + len(start_key)
    end_idx := start_idx
    while end_idx < len(json_str) && (json_str[end_idx] >= '0' && json_str[end_idx] <= '9') {
        end_idx = end_idx + 1
    }
    if end_idx > start_idx {
        num_str := json_str[start_idx:end_idx]
        return string_to_int(num_str)
    }
    return 0
}

func index_of(string s, string substr) int {
    for i := 0; i < len(s) - len(substr) + 1; i++ {
        if s[i:i+len(substr)] == substr {
            return i
        }
    }
    return -1
}

func index_of_from(string s, string substr, int start) int {
    for i := start; i < len(s) - len(substr) + 1; i++ {
        if s[i:i+len(substr)] == substr {
            return i
        }
    }
    return -1
}

func string_at_index(string s, int idx) string {
    if idx < 0 || idx >= len(s) { return "" }
    return string(s[idx : idx+1])
}

func parse_inference_request(string body) inference_request {
    prompt := parse_json_string(body, "prompt")
    max_tokens := parse_json_int(body, "max_tokens")
    if max_tokens == 0 {
        max_tokens = 100
    }
    return inference_request{
        prompt: prompt,
        max_tokens: max_tokens,
        temperature: 0.7,
        top_p: 0.9,
        top_k: 40,
        stream: false,
    }
}

func load_engine() real_text_engine_state {
    string model_path = resolve_model_path_from_env()
    if g_cached_engine_loaded && g_cached_engine_path == model_path {
        return g_cached_engine
    }
    g_cached_engine = load_real_text_engine(model_path)
    g_cached_engine_path = model_path
    g_cached_engine_loaded = true
    g_cached_engine
}

func handle_generate(http_request req) http_response {
    if req.method != "POST" {
        return http_response{
            status_code: 405,
            headers: [],
            body: "{\"error\":\"Method not allowed\"}",
        }
    }
    real_text_engine_state state = load_engine()
    if !state.ready {
        return http_response{
            status_code: 503,
            headers: [],
            body: build_health_json(state),
        }
    }
    string prompt = resolve_prompt_from_body(req.body)
    int max_tokens = parse_max_tokens(req.body, 128)
    real_generation_result result = generate_response(state, prompt, max_tokens)
    result.stream = parse_bool(req.body, "\"stream\"", false)
    return http_response{
        status_code: 200,
        headers: [],
        body: build_generate_json(result),
    }
}

func handle_chat_completions(http_request req) http_response {
    if req.method != "POST" {
        return http_response{
            status_code: 405,
            headers: [],
            body: "{\"error\":\"Method not allowed\"}",
        }
    }
    real_text_engine_state state = load_engine()
    if !state.ready {
        return http_response{
            status_code: 503,
            headers: [],
            body: build_health_json(state),
        }
    }
    string prompt = resolve_prompt_from_body(req.body)
    int max_tokens = parse_max_tokens(req.body, 128)
    real_generation_result result = generate_response(state, prompt, max_tokens)
    result.stream = parse_bool(req.body, "\"stream\"", false)
    return http_response{
        status_code: 200,
        headers: [],
        body: build_chat_completion_json(result),
    }
}

func handle_health(http_request req) http_response {
    real_text_engine_state state = load_engine()
    int status_code = 200
    if !state.ready {
        status_code = 503
    }
    return http_response{
        status_code: status_code,
        headers: [],
        body: build_health_json(state),
    }
}

func handle_models(http_request req) http_response {
    real_text_engine_state state = load_engine()
    int status_code = 200
    if !state.ready {
        status_code = 503
    }
    return http_response{
        status_code: status_code,
        headers: [],
        body: build_models_json(state),
    }
}

func route_request(http_request req) http_response {
    path := req.path
    if path == "/api/generate" {
        return handle_generate(req)
    }
    if path == "/v1/completions" {
        return handle_generate(req)
    }
    if path == "/api/health" {
        return handle_health(req)
    }
    if path == "/health" {
        return handle_health(req)
    }
    if path == "/api/models" {
        return handle_models(req)
    }
    if path == "/api/chat/completions" {
        return handle_chat_completions(req)
    }
    if path == "/v1/chat/completions" {
        return handle_chat_completions(req)
    }
    if path == "/models" {
        return handle_models(req)
    }
    return http_response{
        status_code: 404,
        headers: [],
        body: "{\"error\":\"Not found\"}",
    }
}
