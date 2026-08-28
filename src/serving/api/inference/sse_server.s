package neurx.inference.api.sse_server
use std.result.result
use neurx.inference.api.http_server.{http_server, create_http_server, close_http_server, int_to_string, write_client_data}
use neurx.inference.api.openai_protocol.{openai_request, openai_request_result, parse_openai_request, openai_chat_chunk, openai_done_event, openai_error_body, openai_json_escape, openai_embedding_body}
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use neurx.inference.runtime.real_text_engine.{real_text_engine_state, real_generation_result, load_real_text_engine, generate_response_stream}
use src.net.http.{http_request, http_response, parse_http_request, format_http_response}
use neurx.serving.protocol.transport.native_socket.{neurx_net_accept}
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __sys_write_string(int fd, string data) int
extern "intrinsic" func __sys_close(int fd) int
struct sse_server_config {
    string host
    int port
    string default_model
    int max_concurrent_streams
struct sse_session {
    string request_id
    string model
    bool stream
    int max_tokens
    int tokens_sent
    bool closed
struct generation_callback_state {
    string[] tokens
    int cursor
    bool done
    string[] tokens
    int cursor
    bool done
}
g_cached_engine := real_text_engine_state{}
g_cached_engine_path := ""
g_cached_engine_loaded := false
g_stream_client_fd := -1
g_stream_request_id := ""
g_stream_model := ""
g_stream_tokens_sent := 0
g_stream_max_tokens := 0
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
func new_generation_callback_state(string[] tokens) generation_callback_state {
    generation_callback_state{
        tokens: tokens,
        cursor: 0,
        done: false,
    }
func sse_header() string {
    "HTTP/1.1 200 OK\r\n" +
    "Content-Type: text/event-stream\r\n" +
    "Cache-Control: no-cache\r\n" +
    "Connection: keep-alive\r\n" +
    "Access-Control-Allow-Origin: *\r\n\r\n"
func json_response_header(int body_len) string {
    "HTTP/1.1 200 OK\r\n" +
    "Content-Type: application/json\r\n" +
    "Content-Length: " + int_to_string(body_len) + "\r\n" +
    "Connection: close\r\n\r\n"
func error_response(int status_code, string message, string error_type, string code) http_response {
    string body = openai_error_body(message, error_type, code)
    http_response{
        status_code: status_code,
        headers: string[]{},
        body: body,
    }
func sse_write_chunk(int client_fd, string request_id, string model, string content_delta, string finish_reason) int {
    string chunk = openai_chat_chunk(request_id, model, content_delta, finish_reason)
    write_client_data(client_fd, chunk)
func sse_write_done(int client_fd) int {
    write_client_data(client_fd, openai_done_event())
func load_engine() real_text_engine_state {
    string model_path = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain")
    if g_cached_engine_loaded && g_cached_engine_path == model_path {
        return g_cached_engine
    }
    real_text_engine_state state = load_real_text_engine(model_path)
    g_cached_engine = state
    g_cached_engine_path = model_path
    g_cached_engine_loaded = true
    state
func stream_openai_token(string token) bool {
    if len(token) == 0 {
        return true
    }
    if g_stream_client_fd < 0 {
        return false
    }
    if g_stream_tokens_sent >= g_stream_max_tokens {
        return false
    }
    sse_write_chunk(g_stream_client_fd, g_stream_request_id, g_stream_model, token, "")
    g_stream_tokens_sent = g_stream_tokens_sent + 1
    true
func write_http_response(int client_fd, http_response resp) {
    write_client_data(client_fd, format_http_response(resp))
func write_http_error(int client_fd, int status_code, string message, string error_type, string code) {
    write_http_response(client_fd, error_response(status_code, message, error_type, code))
func handle_streaming_chat(int client_fd, openai_request oreq, sse_server_config config) {
    real_text_engine_state state = load_engine()
    if !state.ready {
        write_http_error(client_fd, 500, state.error_message, "server_error", "engine_not_ready")
        return
    }
    string model = oreq.model
    if model == "" {
        model = config.default_model
    }
    g_stream_client_fd = client_fd
    g_stream_request_id = oreq.request_id
    g_stream_model = model
    g_stream_tokens_sent = 0
    g_stream_max_tokens = oreq.max_tokens
    write_client_data(client_fd, sse_header())
    real_generation_result result = generate_response_stream(state, oreq.prompt, oreq.max_tokens, stream_openai_token)
    if !result.ok && len(result.error_message) > 0 {
        sse_write_chunk(client_fd, oreq.request_id, model, "error: " + result.error_message, "stop")
    } else {
        sse_write_chunk(client_fd, oreq.request_id, model, "", "stop")
    }
    sse_write_done(client_fd)
    g_stream_client_fd = -1
func handle_socket_connection(int client_fd, sse_server_config config) {
    string request_data = __sys_read_string(client_fd, 8192)
    if len(request_data) == 0 {
        __sys_close(client_fd)
        return
    }
    http_request req = parse_http_request(request_data)
    if req.method == "POST" && (req.path == "/v1/chat/completions" || req.path == "/chat/completions") {
        openai_request_result parsed = parse_openai_request(req.body, extract_request_id(req.path))
        if !parsed.valid {
            write_http_error(client_fd, parsed.status_code, parsed.error_message, "invalid_request_error", "invalid_request")
            __sys_close(client_fd)
            return
        }
        openai_request oreq = parsed.request
        if oreq.stream {
            handle_streaming_chat(client_fd, oreq, config)
            __sys_close(client_fd)
            return
        }
    }
    http_response resp = route_request(req, config)
    write_http_response(client_fd, resp)
    __sys_close(client_fd)
func next_token(generation_callback_state gen) generation_callback_state {
    generation_callback_state current = gen
    if current.cursor >= len(current.tokens) {
        current.done = true
        return current
    }
    current.cursor = current.cursor + 1
    current
func current_token(generation_callback_state gen) string {
    if gen.cursor == 0 || gen.cursor > len(gen.tokens) {
        return ""
    }
    gen.tokens[gen.cursor - 1]
func sse_serve_stream(int client_fd, sse_session session, generation_callback_state gen) sse_session {
    sse_session current = session
    generation_callback_state current_gen = gen
    write_client_data(client_fd, sse_header())
    for !current_gen.done && current.tokens_sent < current.max_tokens {
        current_gen = next_token(current_gen)
        if current_gen.done {
            break
        }
        string tok = current_token(current_gen)
        sse_write_chunk(client_fd, current.request_id, current.model, tok, "")
        current.tokens_sent = current.tokens_sent + 1
    }
    sse_write_chunk(client_fd, current.request_id, current.model, "", "stop")
    sse_write_done(client_fd)
    current.closed = true
    current
func non_stream_response(sse_session session, generation_callback_state gen) string {
    string full = ""
    generation_callback_state current_gen = gen
    for !current_gen.done {
        current_gen = next_token(current_gen)
        if current_gen.done {
            break
        }
        full = full + current_token(current_gen)
    }
    string body = "{\"id\":\"" + openai_json_escape(session.request_id) + "\","
    body = body + "\"object\":\"chat.completion\","
    body = body + "\"model\":\"" + openai_json_escape(session.model) + "\","
    body = body + "\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"" + openai_json_escape(full) + "\"},\"finish_reason\":\"stop\"}],"
    body = body + "\"usage\":{\"prompt_tokens\":0,\"completion_tokens\":" + int_to_string(session.tokens_sent) + ",\"total_tokens\":" + int_to_string(session.tokens_sent) + "}}"
    body
func sse_serve_non_stream(int client_fd, sse_session session, generation_callback_state gen) sse_session {
    sse_session current = session
    generation_callback_state current_gen = gen
    for !current_gen.done && current.tokens_sent < current.max_tokens {
        current_gen = next_token(current_gen)
        if current_gen.done {
            break
        }
        current.tokens_sent = current.tokens_sent + 1
    }
    string body = non_stream_response(current, current_gen)
    string header = json_response_header(len(body))
    write_client_data(client_fd, header + body)
    current.closed = true
    current
func extract_request_id(string path) string {
    int slash = -1
    int i = 0
    for i < len(path) {
        if path[i] == 47 {
            slash = i
        }
        i = i + 1
    }
    if slash < 0 || slash >= len(path) - 1 {
        return "req-" + int_to_string(current_timestamp_ms() % 100000)
    }
    return __host_slice(path, slash + 1, len(path))
func current_timestamp_ms() int {
    0
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
        string[] dummy_tokens = split_to_tokens(oreq.prompt)
        generation_callback_state gen = new_generation_callback_state(dummy_tokens)
        sse_session session = new_sse_session(oreq.request_id, model, oreq.stream, oreq.max_tokens)
        if oreq.stream {
            sse_session updated = sse_serve_stream(0, session, gen)
            updated.closed = true
            return http_response{status_code: 200, headers: string[]{}, body: "[stream served]"}
        }
        string body = non_stream_response(session, gen)
        return http_response{status_code: 200, headers: string[]{}, body: body}
    }
    if req.method == "GET" && (req.path == "/health" || req.path == "/healthz" || req.path == "/v1/health") {
        return http_response{status_code: 200, headers: string[]{}, body: "{\"status\":\"ok\"}"}
    }
    if req.method == "GET" && req.path == "/v1/models" {
        string body = "{\"object\":\"list\",\"data\":[{\"id\":\"" + config.default_model + "\",\"object\":\"model\",\"created\":0,\"owned_by\":\"neurx\"}]}"
        return http_response{status_code: 200, headers: string[]{}, body: body}
    }
    error_response(404, "path not found: " + req.path, "invalid_request_error", "not_found")
func split_to_tokens(string text) string[] {
    string[] toks = string[]{}
    if len(text) == 0 {
        toks = append(toks, "")
        return toks
    }
    string cur = ""
    int i = 0
    for i < len(text) {
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
func start_sse_server(sse_server_config config) {
    http_server server = create_http_server(config.host, config.port)
    if server.listen_fd < 0 {
        print("error: cannot start sse server\n")
        return
    }
    print("sse server: streaming at http:
    for server.running {
        int client_fd = neurx_net_accept(server.listen_fd)
        if client_fd >= 0 {
            handle_socket_connection(client_fd, config)
        } else {
            print("error: accept failed\n")
        }
    }
    close_http_server(server)
    http_server server = create_http_server(config.host, config.port)
    if server.listen_fd < 0 {
        print("error: cannot start sse server\n")
        return
    }
    print("sse server: streaming at http:
    for server.running {
        int client_fd = neurx_net_accept(server.listen_fd)
        if client_fd >= 0 {
            handle_socket_connection(client_fd, config)
        } else {
            print("error: accept failed\n")
        }
    }
    close_http_server(server)
}
