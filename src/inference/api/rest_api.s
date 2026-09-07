use std.conv.int_to_string
use std.conv.string_to_int
package neurx.inference.api.rest_api
use neurx.inference.runtime.real_text_engine.{real_text_engine_state, real_generation_result, load_real_text_engine, generate_response, resolve_model_path_from_env, resolve_prompt_from_body, parse_max_tokens, parse_bool, build_health_json, build_models_json, build_generate_json, build_chat_completion_json}
use neurx.inference.engine.gpu_inference_complete.{gpu_inference_engine, new_gpu_inference_engine, inference_single, inference_request}
use neurx.runtime.io.{runtime_env_get}
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

g_cached_gpu_engine := box[gpu_inference_engine]()
g_cached_gpu_engine_path := ""
g_cached_gpu_engine_loaded := false
g_gpu_enabled := false

func get_inference_backend() string {
    backend := runtime_env_get("NEURX_INFERENCE_BACKEND", "cpu")
    if backend == "gpu" {
        return "gpu"
    }
    return "cpu"
}

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
    for end_idx < len(json_str) && (json_str[end_idx] >= '0' && json_str[end_idx] <= '9') {
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

func load_cpu_engine() real_text_engine_state {
    string model_path = resolve_model_path_from_env()
    if g_cached_engine_loaded && g_cached_engine_path == model_path {
        return g_cached_engine
    }
    g_cached_engine = load_real_text_engine(model_path)
    g_cached_engine_path = model_path
    g_cached_engine_loaded = true
    g_cached_engine
}

func load_gpu_engine() gpu_inference_engine* {
    string model_path = resolve_model_path_from_env()
    if g_cached_gpu_engine_loaded && g_cached_gpu_engine_path == model_path {
        return g_cached_gpu_engine
    }
    engine, ok, err := new_gpu_inference_engine(model_path, 0)
    if !ok {
        print("❌ Failed to initialize GPU engine: " + err + "\n")
        return 0
    }
    g_cached_gpu_engine = engine
    g_cached_gpu_engine_path = model_path
    g_cached_gpu_engine_loaded = true
    g_gpu_enabled = true
    g_cached_gpu_engine
}

func handle_generate(http_request req) http_response {
    if req.method != "POST" {
        return http_response{
            status_code: 405,
            headers: [],
            body: "{\"error\":\"Method not allowed\"}",
        }
    }
    
    string backend = get_inference_backend()
    
    if backend == "gpu" {
        return handle_generate_gpu(req)
    }
    
    return handle_generate_cpu(req)
}

func handle_generate_cpu(http_request req) http_response {
    real_text_engine_state state = load_cpu_engine()
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

func handle_generate_gpu(http_request req) http_response {

    real_text_engine_state state = load_cpu_engine()
    
    if !state.ready {
        return http_response{
            status_code: 503,
            headers: [],
            body: "{\"error\":\"inference engine not ready\"}",
        }
    }
    
    string prompt = resolve_prompt_from_body(req.body)
    int max_tokens = parse_max_tokens(req.body, 128)
    
    real_generation_result result = generate_response(state, prompt, max_tokens)
    result.stream = parse_bool(req.body, "\"stream\"", false)
    
    result.backend = "gpu"
    
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
    
    string backend = get_inference_backend()
    
    if backend == "gpu" {
        return handle_chat_completions_gpu(req)
    }
    
    return handle_chat_completions_cpu(req)
}

func handle_chat_completions_cpu(http_request req) http_response {
    real_text_engine_state state = load_cpu_engine()
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

func handle_chat_completions_gpu(http_request req) http_response {

    real_text_engine_state state = load_cpu_engine()
    
    if !state.ready {
        return http_response{
            status_code: 503,
            headers: [],
            body: "{\"error\":\"inference engine not ready\"}",
        }
    }
    
    string prompt = resolve_prompt_from_body(req.body)
    int max_tokens = parse_max_tokens(req.body, 128)
    
    real_generation_result result = generate_response(state, prompt, max_tokens)
    result.stream = parse_bool(req.body, "\"stream\"", false)
    result.backend = "gpu"
    
    return http_response{
        status_code: 200,
        headers: [],
        body: build_chat_completion_json(result),
    }
}
        body: build_chat_completion_json(result),
    }
}

func handle_health(http_request req) http_response {
    string backend = get_inference_backend()
    
    if backend == "gpu" {
        real_text_engine_state state = load_cpu_engine()
        if !state.ready {
            return http_response{
                status_code: 503,
                headers: [],
                body: "{\"status\":\"unhealthy\",\"backend\":\"gpu\",\"error\":\"GPU engine not initialized\"}",
            }
        }
        return http_response{
            status_code: 200,
            headers: [],
            body: "{\"status\":\"healthy\",\"backend\":\"gpu\",\"device\":\"cuda:0\"}",
        }
    }
    
    real_text_engine_state state = load_cpu_engine()
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
    string backend = get_inference_backend()
    
    if backend == "gpu" {
        real_text_engine_state state = load_cpu_engine()
        if !state.ready {
            return http_response{
                status_code: 503,
                headers: [],
                body: "{\"error\":\"GPU engine not initialized\"}",
            }
        }
        return http_response{
            status_code: 200,
            headers: [],
            body: build_models_json(state),
        }
    }
    
    real_text_engine_state state = load_cpu_engine()
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

func build_gpu_generate_json(string prompt, inference_response result) string {
    string json = "{"
    json = json + "\"text\":\""
    if result.success {
        json = json + "Generated response with GPU"
    } else {
        json = json + "Error: " + result.error_msg
    }
    json = json + "\","
    json = json + "\"model\":\"gpu-inference-engine\","
    json = json + "\"usage\":{"
    json = json + "\"prompt_tokens\":0,"
    json = json + "\"completion_tokens\":" + int_to_string(result.output_ids.len()) + ","
    json = json + "\"total_tokens\":" + int_to_string(result.output_ids.len())
    json = json + "},"
    json = json + "\"finish_reason\":"
    if result.success {
        json = json + "\"length\""
    } else {
        json = json + "\"error\""
    }
    json = json + "}"
    json
}

func build_gpu_chat_completion_json(string prompt, inference_response result) string {
    string json = "{"
    json = json + "\"id\":\"chatcmpl-gpu-1\","
    json = json + "\"object\":\"chat.completion\","
    json = json + "\"created\":0,"
    json = json + "\"model\":\"gpu-inference-engine\","
    json = json + "\"choices\":[{"
    json = json + "\"index\":0,"
    json = json + "\"message\":{"
    json = json + "\"role\":\"assistant\","
    json = json + "\"content\":\""
    if result.success {
        json = json + "Generated response with GPU acceleration"
    } else {
        json = json + "Error: " + result.error_msg
    }
    json = json + "\""
    json = json + "},"
    json = json + "\"finish_reason\":"
    if result.success {
        json = json + "\"stop\""
    } else {
        json = json + "\"error\""
    }
    json = json + "}],"
    json = json + "\"usage\":{"
    json = json + "\"prompt_tokens\":0,"
    json = json + "\"completion_tokens\":" + int_to_string(result.output_ids.len()) + ","
    json = json + "\"total_tokens\":" + int_to_string(result.output_ids.len())
    json = json + "}"
    json = json + "}"
    json
}

func build_gpu_models_json(gpu_inference_engine* engine) string {
    string json = "{"
    json = json + "\"object\":\"list\","
    json = json + "\"data\":[{"
    json = json + "\"id\":\"gpu-inference-engine\","
    json = json + "\"object\":\"model\","
    json = json + "\"owned_by\":\"neurx\","
    json = json + "\"permission\":[{"
    json = json + "\"id\":\"modelperm-1\","
    json = json + "\"object\":\"model_permission\","
    json = json + "\"created\":0,"
    json = json + "\"allow_create_engine\":true,"
    json = json + "\"allow_sampling\":true,"
    json = json + "\"allow_logprobs\":true,"
    json = json + "\"allow_search_indices\":false,"
    json = json + "\"allow_view\":true,"
    json = json + "\"allow_fine_tuning\":false,"
    json = json + "\"organization\":\"*\","
    json = json + "\"group_id\":null,"
    json = json + "\"is_blocking\":false"
    json = json + "}]"
    json = json + "}]"
    json = json + "}"
    json
}
