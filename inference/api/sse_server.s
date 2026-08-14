package neurx.inference.api.sse_server
use neurx.inference.api.http_server.{http_server, http_request, http_response, create_http_server, parse_http_request, format_http_response, close_http_server, int_to_string, split_string, server_accept_loop, handle_connection, __sys_send, __sys_recv, __sys_close}
use neurx.inference.api.openai_protocol.{openai_request, openai_request_result, parse_openai_request, openai_chat_chunk, openai_done_event, openai_error_body, openai_json_escape, openai_embedding_body}
struct sse_server_config {
    string host
    int port
    string default_model
    int max_concurrent_streams
}

struct sse_session {
    string request_id
    string model
    bool stream
    int max_tokens
    int tokens_sent
    bool closed
}

struct generation_callback_state {
    []string tokens
    int cursor
    bool done
}

func new_sse_server_config(string host, int port, string default_model) sse_server_config {
    int norm_port = port
    if norm_port <= 0 {
        norm_port = 8080
    }
    string norm_model = default_model
    if norm_model == "" {
        norm_model = "neurx-glm"
    }
    sse_server_config{
        host: host,
        port: norm_port,
        default_model: norm_model,
        max_concurrent_streams: 64,
    }
}

func new_sse_session(string request_id, string model, bool stream, int max_tokens) sse_session {
    int norm_max = max_tokens
    if norm_max <= 0 {
        norm_max = 256
    }
    sse_session{
        request_id: request_id,
        model: model,
        stream: stream,
        max_tokens: norm_max,
        tokens_sent: 0,
        closed: false,
    }
}

func new_generation_callback_state([]string tokens) generation_callback_state {
    generation_callback_state{
        tokens: tokens,
        cursor: 0,
        done: false,
    }
}

func sse_header() string {
    "HTTP/1.1 200 OK\r\n" +
    "Content-Type: text/event-stream\r\n" +
    "Cache-Control: no-cache\r\n" +
    "Connection: keep-alive\r\n" +
    "Access-Control-Allow-Origin: *\r\n\r\n"
}

func json_response_header(int body_len) string {
    "HTTP/1.1 200 OK\r\n" +
    "Content-Type: application/json\r\n" +
    "Content-Length: " + int_to_string(body_len) + "\r\n" +
    "Connection: close\r\n\r\n"
}

func error_response(int status_code, string message, string error_type, string code) http_response {
    string body = openai_error_body(message, error_type, code)
    http_response{
        status_code: status_code,
        headers: []string{},
        body: body,
    }
}

func sse_write_chunk(int client_fd, string request_id, string model, string content_delta, string finish_reason) int {
    string chunk = openai_chat_chunk(request_id, model, content_delta, finish_reason)
    __sys_send(client_fd, chunk)
}

func sse_write_done(int client_fd) int {
    __sys_send(client_fd, openai_done_event())
}

func next_token(generation_callback_state gen) generation_callback_state {
    if gen.cursor >= len(gen.tokens) {
        gen.done = true
        return gen
    }
    gen.cursor = gen.cursor + 1
    gen
}

func current_token(generation_callback_state gen) string {
    if gen.cursor == 0 || gen.cursor > len(gen.tokens) {
        return ""
    }
    gen.tokens[gen.cursor - 1]
}

func sse_serve_stream(int client_fd, sse_session session, generation_callback_state gen) sse_session {
    __sys_send(client_fd, sse_header())
    while !gen.done && session.tokens_sent < session.max_tokens {
        gen = next_token(gen)
        if gen.done {
            break
        }
        string tok = current_token(gen)
        sse_write_chunk(client_fd, session.request_id, session.model, tok, "")
        session.tokens_sent = session.tokens_sent + 1
    }
    sse_write_chunk(client_fd, session.request_id, session.model, "", "stop")
    sse_write_done(client_fd)
    session.closed = true
    session
}

func non_stream_response(sse_session session, generation_callback_state gen) string {
    string full = ""
    while !gen.done {
        gen = next_token(gen)
        if gen.done {
            break
        }
        full = full + current_token(gen)
    }
    string body = "{\"id\":\"" + openai_json_escape(session.request_id) + "\","
    body = body + "\"object\":\"chat.completion\","
    body = body + "\"model\":\"" + openai_json_escape(session.model) + "\","
    body = body + "\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"" + openai_json_escape(full) + "\"},\"finish_reason\":\"stop\"}],"
    body = body + "\"usage\":{\"prompt_tokens\":0,\"completion_tokens\":" + int_to_string(session.tokens_sent) + ",\"total_tokens\":" + int_to_string(session.tokens_sent) + "}}"
    body
}

func sse_serve_non_stream(int client_fd, sse_session session, generation_callback_state gen) sse_session {
    while !gen.done && session.tokens_sent < session.max_tokens {
        gen = next_token(gen)
        if gen.done {
            break
        }
        session.tokens_sent = session.tokens_sent + 1
    }
    string body = non_stream_response(session, gen)
    string header = json_response_header(len(body))
    __sys_send(client_fd, header + body)
    session.closed = true
    session
}

func extract_request_id(string path) string {
    int slash = -1
    int i = 0
    while i < len(path) {
        if path[i] == 47 {
            slash = i
        }
        i = i + 1
    }
    if slash < 0 || slash >= len(path) - 1 {
        return "req-" + int_to_string(current_timestamp_ms() % 100000)
    }
    path[slash+1:]
}

func current_timestamp_ms() int64 {
    0
}

func route_request(http_request req, sse_server_config config) http_response {
    if req.method == "POST" && (req.path == "/v1/chat/completions" || req.path == "/chat/completions") {
        openai_request_result parsed = parse_openai_request(req.body, extract_request_id(req.path))
        if !parsed.valid {
            return error_response(parsed.status_code, parsed.error_message, "invalid_request_error", "invalid_request")
        }
        openai_request oreq = parsed.request
        string model = oreq.model
        if model == "" {
            model = config.default_model
        }
        []string dummy_tokens = split_to_tokens(oreq.prompt)
        generation_callback_state gen = new_generation_callback_state(dummy_tokens)
        sse_session session = new_sse_session(oreq.request_id, model, oreq.stream, oreq.max_tokens)
        if oreq.stream {
            sse_session updated = sse_serve_stream(0, session, gen)
            updated.closed = true
            return http_response{status_code: 200, headers: []string{}, body: "[stream served]"}
        }
        string body = non_stream_response(session, gen)
        return http_response{status_code: 200, headers: []string{}, body: body}
    }
    if req.method == "GET" && (req.path == "/health" || req.path == "/healthz" || req.path == "/v1/health") {
        return http_response{status_code: 200, headers: []string{}, body: "{\"status\":\"ok\"}"}
    }
    if req.method == "GET" && req.path == "/v1/models" {
        string body = "{\"object\":\"list\",\"data\":[{\"id\":\"" + config.default_model + "\",\"object\":\"model\",\"created\":0,\"owned_by\":\"neurx\"}]}"
        return http_response{status_code: 200, headers: []string{}, body: body}
    }
    error_response(404, "path not found: " + req.path, "invalid_request_error", "not_found")
}

func split_to_tokens(string text) []string {
    []string toks = []string{}
    if len(text) == 0 {
        toks = append(toks, "")
        return toks
    }
    string cur = ""
    int i = 0
    while i < len(text) {
        int ch = int(text[i])
        if ch == 32 {
            if len(cur) > 0 {
                toks = append(toks, cur)
                cur = ""
            }
            toks = append(toks, " ")
        } else {
            cur = cur + string(text[i])
        }
        i = i + 1
    }
    if len(cur) > 0 {
        toks = append(toks, cur)
    }
    toks
}

func start_sse_server(sse_server_config config) {
    http_server server = create_http_server(config.host, config.port)
    if server.listen_fd < 0 {
        print("error: cannot start sse server\n")
        return
    }
    print("sse server: streaming at http://" + config.host + ":" + int_to_string(config.port) + "/v1/chat/completions\n")
    server_accept_loop(server, func(http_request req) http_response {
        return route_request(req, config)
    })
    close_http_server(server)
}
