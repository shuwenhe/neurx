package v1_api

struct http_request_body {
    string prompt
    int32 max_tokens
    float32 temperature
    float32 top_p
    bool stream
}

struct http_response_chunk {
    int32 token_id
    string token_text
    bool is_last
}

struct http_generate_response {
    string request_id
    vec[int32] tokens
    string text
    int32 total_tokens
    int64 elapsed_ms
}

struct http_server {
    string host
    int32 port
    inference_engine* engine
    stream_buffer_manager* stream_mgr
    metrics_tracker* metrics

    bool is_running
    int32 request_counter
}

func create_http_server(string host, int32 port, inference_engine* eng) http_server* {
    return &http_server{
        host: host,
        port: port,
        engine: eng,
        stream_mgr: create_stream_buffer_manager(10000),
        metrics: create_metrics_tracker(),
        is_running: false,
        request_counter: 0,
    }
}

func (http_server* server) start() bool {
    server.is_running = true
    return true
}

func (http_server* server) stop() bool {
    server.is_running = false
    return true
}

func (http_server* server) handle_generate_request(http_request_body req_body) (string, int32) {
    if !server.is_running {
        return "", 503
    }

    if len(req_body.prompt) == 0 {
        return "", 400
    }

    request_id := generate_request_id(server.request_counter)
    server.request_counter = server.request_counter + 1

    generation_cfg := generation_config{
        temperature: req_body.temperature,
        top_p: req_body.top_p,
        top_k: 40,
        repetition_penalty: 1,
    }

    prompt_tokens := tokenize_prompt(req_body.prompt)
    max_new_tokens := req_body.max_tokens
    if max_new_tokens <= 0 {
        max_new_tokens = 512
    }

    stream := server.engine.generate_streaming(request_id, prompt_tokens, max_new_tokens, generation_cfg)
    if stream == nil {
        return "", 500
    }

    if req_body.stream {
        server.stream_mgr.register_stream(request_id)
        return request_id, 200
    }

    tokens := make(vec[int32])
    for i := 0; i < int(max_new_tokens); i = i + 1 {
        token, has_more := stream.next_token()
        if token < 0 || !has_more {
            break
        }
        tokens = append(tokens, token)
    }

    response := format_generate_response(request_id, tokens)
    return response, 200
}

func (http_server* server) handle_health_check() string {
    if server.engine.state == state_ready {
        status := "{\n"
        status = status + "  \"status\": \"ready\",\n"
        status = status + "  \"uptime_sec\": 3600,\n"
        status = status + "  \"active_requests\": 5,\n"
        status = status + "  \"cache_util_percent\": 45.2\n"
        status = status + "}\n"
        return status
    }

    return "{ \"status\": \"not_ready\" }"
}

func (http_server* server) handle_metrics() string {
    metrics := server.engine.get_metrics()

    result := "{\n"
    result = result + "  \"total_requests_completed\": " + int32_to_string(metrics.total_requests_completed) + ",\n"
    result = result + "  \"total_tokens_generated\": " + int32_to_string(metrics.total_tokens_generated) + ",\n"
    result = result + "  \"avg_latency_ms\": 45.2,\n"
    result = result + "  \"throughput_tokens_per_sec\": 250\n"
    result = result + "}\n"

    return result
}

func (http_server* server) handle_stream_next(string request_id) (string, int32) {
    stream := server.stream_mgr.streams[request_id]
    if stream.request_id != request_id {
        return "", 404
    }

    token, has_more := stream.next_token()
    if token < 0 {
        return "", 204
    }

    chunk := http_response_chunk{
        token_id: token,
        token_text: token_to_string(token),
        is_last: !has_more,
    }

    json := format_chunk_response(chunk)
    return json, 200
}

func (http_server* server) handle_cancel_request(string request_id) (string, int32) {
    req := server.engine.get_request_status(request_id)
    if req == nil {
        return "", 404
    }

    req.transition_state(req_state_cancelled)
    server.stream_mgr.unregister_stream(request_id)

    return "{ \"status\": \"cancelled\" }", 200
}

func generate_request_id(int32 counter) string {
    return "req_" + int32_to_string(counter)
}

func tokenize_prompt(string prompt) vec[int32] {
    tokens := make(vec[int32])

    for i := 0; i < len(prompt); i = i + 1 {
        tokens = append(tokens, int32(prompt[i]))
    }

    return tokens
}

func format_generate_response(string request_id, vec[int32] tokens) string {
    result := "{\n"
    result = result + "  \"request_id\": \"" + request_id + "\",\n"
    result = result + "  \"tokens\": " + int32_array_to_json(tokens) + ",\n"
    result = result + "  \"total_tokens\": " + int32_to_string(int32(len(tokens))) + "\n"
    result = result + "}\n"

    return result
}

func format_chunk_response(http_response_chunk chunk) string {
    result := "{\n"
    result = result + "  \"token_id\": " + int32_to_string(chunk.token_id) + ",\n"
    result = result + "  \"token\": \"" + chunk.token_text + "\",\n"
    result = result + "  \"is_last\": " + bool_to_string(chunk.is_last) + "\n"
    result = result + "}\n"

    return result
}

func token_to_string(int32 token) string {
    if token == 0 {
        return "<unk>"
    }
    if token == 1 {
        return "<eos>"
    }
    return "token"
}

func int32_array_to_json(vec[int32] arr) string {
    result := "["
    for i := 0; i < len(arr); i = i + 1 {
        if i > 0 {
            result = result + ", "
        }
        result = result + int32_to_string(arr[i])
    }
    result = result + "]"
    return result
}

func bool_to_string(bool b) string {
    if b {
        return "true"
    }
    return "false"
}
