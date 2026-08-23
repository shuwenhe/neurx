package neurx.inference.api.rest_server

use std.conv.int_to_string
use neurx.inference.api.http_server.{http_server, create_http_server, close_http_server, write_client_data}
use neurx.inference.api.openai_protocol.{openai_request, openai_request_result, parse_openai_request, openai_chat_chunk, openai_done_event, openai_error_body}
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use neurx.inference.runtime.real_text_engine.{real_text_engine_state, real_generation_result, load_real_text_engine, generate_response, generate_response_stream}
use neurx.serving.protocol.transport.native_socket.{neurx_net_accept}
use src.net.http.{http_request, http_response, format_http_response}
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __sys_close(int fd) int

struct chat_message {
    string role
    string content
}

struct inference_request {
    string model
    []chat_message messages
    int max_tokens
    float temperature
}

struct inference_response {
    string text
    int prompt_tokens
    int completion_tokens
    bool success
    string error
}

var g_cached_engine real_text_engine_state = real_text_engine_state{}
var g_cached_engine_path string = ""
var g_cached_engine_loaded bool = false
var g_stream_client_fd int = -1
var g_stream_request_id string = ""
var g_stream_model string = ""
var g_stream_tokens_sent int = 0
var g_stream_max_tokens int = 0

func json_escape(string s) string {
    string result = ""
    int i = 0
    while i < len(s) {
        int c = s[i]
        if c == 34 {
            result = result + "\\\""
        } else if c == 92 {
            result = result + "\\\\"
        } else if c == 10 {
            result = result + "\\n"
        } else if c == 13 {
            result = result + "\\r"
        } else if c == 9 {
            result = result + "\\t"
        } else {
            result = result + string(c)
        }
        i = i + 1
    }
    return result
}

func string_at_index(string s, int idx) string {
    if idx < 0 || idx >= len(s) { return "" }
    int c = s[idx]
    return string(c)
}

func split_string(string s, string sep) []string {
    []string result = []string{}
    if len(s) == 0 { return result }

    string current = ""
    int i = 0
    int sep_len = len(sep)

    while i < len(s) {
        bool found = true

        if i + sep_len <= len(s) {
            int j = 0
            while j < sep_len {
                if s[i + j] != sep[j] {
                    found = false
                    break
                }
                j = j + 1
            }
        } else {
            found = false
        }

        if found {
            result = append(result, current)
            current = ""
            i = i + sep_len
        } else {
            current = current + string(s[i])
            i = i + 1
        }
    }

    if len(current) > 0 {
        result = append(result, current)
    }

    return result
}

func extract_json_string(string json, string key) string {
    string search_key = "\"" + key + "\":"
    int key_pos = -1
    int i = 0
    while i + len(search_key) <= len(json) {
        bool found = true
        int j = 0
        while j < len(search_key) {
            if json[i + j] != search_key[j] {
                found = false
                break
            }
            j = j + 1
        }
        if found {
            key_pos = i
            break
        }
        i = i + 1
    }

    if key_pos == -1 {
        return ""
    }

    int start = key_pos + len(search_key)
    while start < len(json) && (json[start] == 32 || json[start] == 9) {
        start = start + 1
    }

    if start >= len(json) || json[start] != 34 {
        return ""
    }

    start = start + 1
    string result = ""
    int idx = start
    while idx < len(json) {
        int c = json[idx]
        if c == 34 {
            return result
        }
        if c == 92 && idx + 1 < len(json) {
            int next_c = json[idx + 1]
            if next_c == 34 {
                result = result + "\""
                idx = idx + 2
                continue
            } else if next_c == 92 {
                result = result + "\\"
                idx = idx + 2
                continue
            }
        }
        result = result + string(c)
        idx = idx + 1
    }

    return result
}

func extract_user_message_from_json(string json_body) string {
    string search = "\"role\": \"user\""
    int user_pos = -1
    int i = 0
    while i + len(search) <= len(json_body) {
        bool found = true
        int j = 0
        while j < len(search) {
            if json_body[i + j] != search[j] {
                found = false
                break
            }
            j = j + 1
        }
        if found {
            user_pos = i
            break
        }
        i = i + 1
    }

    if user_pos == -1 {
        return "You are a helpful AI assistant."
    }

    int search_start = user_pos + len(search)
    string content_search = "\"content\":"
    int content_pos = -1
    int idx = search_start
    while idx + len(content_search) <= len(json_body) {
        bool found = true
        int j = 0
        while j < len(content_search) {
            if json_body[idx + j] != content_search[j] {
                found = false
                break
            }
            j = j + 1
        }
        if found {
            content_pos = idx
            break
        }
        idx = idx + 1
    }

    if content_pos == -1 {
        return "You are a helpful AI assistant."
    }

    int quote_start = content_pos + len(content_search)
    while quote_start < len(json_body) && json_body[quote_start] != 34 {
        quote_start = quote_start + 1
    }

    if quote_start >= len(json_body) {
        return "You are a helpful AI assistant."
    }

    quote_start = quote_start + 1
    string content = ""
    int cidx = quote_start
    while cidx < len(json_body) {
        int c = json_body[cidx]
        if c == 34 {
            return content
        }
        content = content + string(c)
        cidx = cidx + 1
    }

    return content
}

func estimate_token_count(string text) int {
    int len_text = len(text)
    int token_estimate = len_text / 4
    if token_estimate < 1 {
        token_estimate = 1
    }
    return token_estimate
}

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
}

func stream_http_header() string {
    "HTTP/1.1 200 OK\r\n" +
    "Content-Type: text/event-stream\r\n" +
    "Cache-Control: no-cache\r\n" +
    "Connection: keep-alive\r\n" +
    "Access-Control-Allow-Origin: *\r\n\r\n"
}

func write_http_response(int client_fd, http_response resp) {
    write_client_data(client_fd, format_http_response(resp))
}

func write_http_error(int client_fd, int status_code, string message, string error_type, string code) {
    string body = openai_error_body(message, error_type, code)
    write_http_response(client_fd, http_response{
        status_code: status_code,
        headers: [],
        body: body,
    })
}

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
    string chunk = openai_chat_chunk(g_stream_request_id, g_stream_model, token, "")
    write_client_data(g_stream_client_fd, chunk)
    g_stream_tokens_sent = g_stream_tokens_sent + 1
    true
}

func extract_request_id(string path) string {
    int slash = -1
    int i = 0
    while i < len(path) {
        if int(path[i]) == 47 {
            slash = i
        }
        i = i + 1
    }
    if slash < 0 || slash >= len(path) - 1 {
        return "req-0001"
    }
    return __host_slice(path, slash + 1, len(path))
}

func handle_streaming_chat(int client_fd, openai_request oreq) {
    real_text_engine_state state = load_engine()
    if !state.ready {
        write_http_error(client_fd, 500, "Inference failed: " + state.error_message, "server_error", "engine_not_ready")
        return
    }

    string model = oreq.model
    if model == "" {
        model = "Qwen2.5-0.5B-Instruct"
    }

    g_stream_client_fd = client_fd
    g_stream_request_id = oreq.request_id
    g_stream_model = model
    g_stream_tokens_sent = 0
    g_stream_max_tokens = oreq.max_tokens

    write_client_data(client_fd, stream_http_header())
    real_generation_result result = generate_response_stream(state, oreq.prompt, oreq.max_tokens, stream_openai_token)
    if !result.ok && len(result.error_message) > 0 {
        write_client_data(client_fd, openai_chat_chunk(oreq.request_id, model, "error: " + result.error_message, "stop"))
    } else {
        write_client_data(client_fd, openai_chat_chunk(oreq.request_id, model, "", "stop"))
    }
    write_client_data(client_fd, openai_done_event())
    g_stream_client_fd = -1
}

func handle_socket_connection(int client_fd) {
    string request_data = __sys_read_string(client_fd, 8192)
    if len(request_data) == 0 {
        _ = __sys_close(client_fd)
        return
    }

    http_request req = parse_http_request(request_data)
    if req.method == "POST" && (req.path == "/v1/chat/completions" || req.path == "/chat/completions") {
        openai_request_result parsed = parse_openai_request(req.body, extract_request_id(req.path))
        if !parsed.valid {
            write_http_error(client_fd, parsed.status_code, parsed.error_message, "invalid_request_error", "invalid_request")
            _ = __sys_close(client_fd)
            return
        }
        if parsed.request.stream {
            handle_streaming_chat(client_fd, parsed.request)
            _ = __sys_close(client_fd)
            return
        }
    }

    http_response resp = route_request(req)
    write_http_response(client_fd, resp)
    _ = __sys_close(client_fd)
}

func run_inference(string prompt, int max_tokens, float temperature) inference_response {
    real_text_engine_state state = load_engine()
    if !state.ready {
        return inference_response{
            text: "error: " + state.error_message,
            prompt_tokens: 0,
            completion_tokens: 0,
            success: false,
            error: state.error_message,
        }
    }
    real_generation_result result = generate_response(state, prompt, max_tokens)
    if !result.ok {
        return inference_response{
            text: result.text,
            prompt_tokens: result.prompt_tokens,
            completion_tokens: result.generated_tokens,
            success: false,
            error: result.error_message,
        }
    }
    return inference_response{
        text: result.text,
        prompt_tokens: result.prompt_tokens,
        completion_tokens: result.generated_tokens,
        success: true,
        error: result.error_message,
    }
}

func create_json_response(string status, string model, string content, int prompt_tokens, int completion_tokens) string {
    string id = "chatcmpl-" + int_to_string(12345)
    string created = int_to_string(1786879972)
    int total = prompt_tokens + completion_tokens

    string json = "{"
    json = json + "\"id\": \"" + id + "\","
    json = json + "\"object\": \"chat.completion\","
    json = json + "\"created\": " + created + ","
    json = json + "\"model\": \"" + model + "\","
    json = json + "\"choices\": [{"
    json = json + "\"index\": 0,"
    json = json + "\"message\": {"
    json = json + "\"role\": \"assistant\","
    json = json + "\"content\": \"" + json_escape(content) + "\""
    json = json + "},"
    json = json + "\"finish_reason\": \"stop\""
    json = json + "}],"
    json = json + "\"usage\": {"
    json = json + "\"prompt_tokens\": " + int_to_string(prompt_tokens) + ","
    json = json + "\"completion_tokens\": " + int_to_string(completion_tokens) + ","
    json = json + "\"total_tokens\": " + int_to_string(total)
    json = json + "}"
    json = json + "}"

    return json
}

func create_health_response() string {
    string json = "{"
    json = json + "\"status\": \"healthy\","
    json = json + "\"model\": \"Qwen2.5-0.5B-Instruct\","
    json = json + "\"model_path\": \"/app/shuwen/model/Qwen2.5-0.5B-Instruct\","
    json = json + "\"timestamp\": \"2026-08-16T19:36:00Z\","
    json = json + "\"api_version\": \"v1\""
    json = json + "}"
    return json
}

func create_models_response() string {
    string json = "{"
    json = json + "\"object\": \"list\","
    json = json + "\"data\": [{"
    json = json + "\"id\": \"Qwen2.5-0.5B-Instruct\","
    json = json + "\"object\": \"model\","
    json = json + "\"created\": 1786879900,"
    json = json + "\"owned_by\": \"neurx\""
    json = json + "}]"
    json = json + "}"
    return json
}

func create_error_response(string error_msg) string {
    string json = "{"
    json = json + "\"error\": {"
    json = json + "\"message\": \"" + json_escape(error_msg) + "\","
    json = json + "\"type\": \"invalid_request_error\""
    json = json + "}"
    json = json + "}"
    return json
}

func handle_health_check(http_request req) http_response {
    string body = create_health_response()
    return http_response{
        status_code: 200,
        headers: [],
        body: body,
    }
}

func handle_models_list(http_request req) http_response {
    string body = create_models_response()
    return http_response{
        status_code: 200,
        headers: [],
        body: body,
    }
}

func handle_chat_completions(http_request req) http_response {
    if req.method != "POST" {
        string body = create_error_response("Method not allowed")
        return http_response{
            status_code: 405,
            headers: [],
            body: body,
        }
    }

    string user_prompt = extract_user_message_from_json(req.body)
    inference_response inference_result = run_inference(user_prompt, 128, 0.7)

    if !inference_result.success {
        string body = create_error_response("Inference failed: " + inference_result.error)
        return http_response{
            status_code: 500,
            headers: [],
            body: body,
        }
    }

    string body = create_json_response("ok", "Qwen2.5-0.5B-Instruct", inference_result.text, inference_result.prompt_tokens, inference_result.completion_tokens)

    return http_response{
        status_code: 200,
        headers: [],
        body: body,
    }
}

func route_request(http_request req) http_response {
    if req.path == "/health" {
        return handle_health_check(req)
    } else if req.path == "/v1/models" {
        return handle_models_list(req)
    } else if req.path == "/v1/chat/completions" {
        return handle_chat_completions(req)
    } else {
        string body = create_error_response("Not found: " + req.path)
        return http_response{
            status_code: 404,
            headers: [],
            body: body,
        }
    }
}

func main() {
    print("\n╔════════════════════════════════════════════════════════════════╗\n")
    print("║       NeurX REST API Server (Pure S Language)                ║\n")
    print("║       OpenAI-Compatible HTTP API                             ║\n")
    print("╚════════════════════════════════════════════════════════════════╝\n")
    print("\n")

    print("📋 Configuration:\n")
    print("  Host: 0.0.0.0\n")
    print("  Port: 8888\n")
    print("  Model: Qwen2.5-0.5B-Instruct\n")
    print("\n")

    http_server server = create_http_server("0.0.0.0", 8888)

    if server.listen_fd < 0 {
        print("❌ Failed to start server\n")
        return
    }

    print("📚 API Endpoints:\n")
    print("  GET  /health                     - Health check\n")
    print("  GET  /v1/models                  - List models\n")
    print("  POST /v1/chat/completions       - Chat completion (OpenAI compatible)\n")
    print("\n")
    print("🎯 Server is running. Press Ctrl+C to stop.\n")
    print("\n")
    print("💬 Test commands:\n")
    print("  curl http://localhost:8888/health\n")
    print("  curl http://localhost:8888/v1/models\n")
    print("  curl -X POST http://localhost:8888/v1/chat/completions -H 'Content-Type: application/json' -d '{\"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}]}'\n")
    print("  curl -N -X POST http://localhost:8888/v1/chat/completions -H 'Content-Type: application/json' -d '{\"stream\": true, \"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}]}'\n")
    print("\n")

    while server.running {
        int client_fd = neurx_net_accept(server.listen_fd)
        if client_fd >= 0 {
            handle_socket_connection(client_fd)
        } else {
            print("error: accept failed\n")
        }
    }

    close_http_server(server)
}
