package neurx.inference.api.rest_api

use neurx.inference.api.http_server.{http_request, http_response}

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

func string_to_int(string s) int {
    result := 0
    for i := 0; i < len(s); i++ {
        ch := s[i]
        if ch >= '0' && ch <= '9' {
            result = result * 10 + (int(ch) - int('0'))
        }
    }
    return result
}

func int_to_string(int val) string {
    if val == 0 { return "0" }
    string res = ""
    int cur = val
    if cur < 0 { cur = -cur }
    while cur != 0 {
        int d = cur - (cur / 10) * 10
        res = string_at_index("0123456789", d) + res
        cur = cur / 10
    }
    return res
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

func create_json_response(string response, int tokens, float latency) string {
    json := "{"
    json = json + "\"response\":\"" + response + "\","
    json = json + "\"tokens_generated\":" + int_to_string(tokens) + ","
    json = json + "\"latency_ms\":" + float_to_string(latency)
    json = json + "}"
    return json
}

func float_to_string(float val) string {
    int_part := int(val)
    frac_part := int((val - float(int_part)) * 1000.0)
    
    result := int_to_string(int_part)
    result = result + "."
    result = result + int_to_string(frac_part)
    
    return result
}

func handle_generate(http_request req) http_response {
    if req.method != "POST" {
        return http_response{
            status_code: 405,
            headers: [],
            body: "{\"error\":\"Method not allowed\"}",
        }
    }
    
    inference_req := parse_inference_request(req.body)
    
    response_text := "Medical response to: " + inference_req.prompt
    tokens_generated := 50
    latency := 123.45
    
    response_json := create_json_response(response_text, tokens_generated, latency)
    
    return http_response{
        status_code: 200,
        headers: [],
        body: response_json,
    }
}

func handle_health(http_request req) http_response {
    health_json := "{\"status\":\"healthy\",\"model\":\"qwen2.5-0.5b\",\"backend\":\"cpu\"}"
    
    return http_response{
        status_code: 200,
        headers: [],
        body: health_json,
    }
}

func handle_models(http_request req) http_response {
    models_json := "{\"models\":[\"qwen2.5-0.5b-instruct\"]}"
    
    return http_response{
        status_code: 200,
        headers: [],
        body: models_json,
    }
}

func route_request(http_request req) http_response {
    path := req.path
    
    if path == "/api/generate" {
        return handle_generate(req)
    }
    
    if path == "/api/health" {
        return handle_health(req)
    }
    
    if path == "/api/models" {
        return handle_models(req)
    }
    
    if path == "/api/chat/completions" {
        return handle_generate(req)
    }
    
    return http_response{
        status_code: 404,
        headers: [],
        body: "{\"error\":\"Not found\"}",
    }
}
