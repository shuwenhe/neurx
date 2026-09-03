package neurx.serving.web_chat

use std.io_syscall
use std.syscall
use std.encoding
use std.runtime_nostdlib

extern "intrinsic" func __sys_socket(int domain, int type, int protocol) int
extern "intrinsic" func __sys_setsockopt(int fd, int level, int option, int value) int
extern "intrinsic" func __sys_bind(int sockfd, string ip, int port, int family) int
extern "intrinsic" func __sys_listen(int sockfd, int backlog) int
extern "intrinsic" func __sys_accept(int sockfd) int
extern "intrinsic" func __sys_write_string(int fd, string data) int
extern "intrinsic" func __sys_read_string(int fd, int n) string
extern "intrinsic" func __sys_close(int fd) int
extern "intrinsic" func __sys_inet_pton(string addr) int64

struct model_config {
    string model_id
    string model_name
    string model_path
    bool loaded
}

struct chat_request {
    string model
    []string[] messages
    int32 max_tokens
    float32 temperature
    float32 top_p
}

struct chat_response {
    []string[] choices
    int32 usage_prompt_tokens
    int32 usage_completion_tokens
}

struct web_chat_server {
    int32 port
    string host
    int32 socket_fd
    bool running
    model_config[] models
    string current_model
    map[string]string model_responses
}

func create_web_chat_server(int32 port) web_chat_server {
    server := web_chat_server{
        port: port,
        host: "127.0.0.1",
        socket_fd: -1,
        running: false,
        models: make(model_config[], 0, 10),
        current_model: "",
        model_responses: make(map[string]string),
    }
    
    server.register_model(model_config{
        model_id: "qwen-0.5b",
        model_name: "Qwen2.5-0.5B-Instruct",
        model_path: "/model/Qwen2.5-0.5B-Instruct",
        loaded: true,
    })
    
    server.register_model(model_config{
        model_id: "qwen-vl-7b",
        model_name: "Qwen2.5-VL-7B",
        model_path: "/model/Qwen2.5-VL-7B",
        loaded: true,
    })
    
    if len(server.models) > 0 {
        server.current_model = server.models[0].model_id
    }
    
    return server
}

func (s: &web_chat_server) register_model(model: model_config) {
    s.models = append(s.models, model)
    s.model_responses[model.model_id] = "Model " + model.model_name + " initialized"
}

func (s: &web_chat_server) get_model_list() string {
    response := "{"
    response = response + "\"models\":["
    
    for i := 0; i < len(s.models); i = i + 1 {
        if i > 0 {
            response = response + ","
        }
        model := s.models[i]
        response = response + "{\"id\":\"" + model.model_id + "\",\"name\":\"" + model.model_name + "\",\"loaded\":" + (if model.loaded { "true" } else { "false" }) + "}"
    }
    
    response = response + "],"
    response = response + "\"current_model\":\"" + s.current_model + "\""
    response = response + "}"
    return response
}

func (s: &web_chat_server) handle_chat_request(req: &chat_request) string {
    if len(req.model) > 0 {
        s.current_model = req.model
    }
    
    messages_str := ""
    for i := 0; i < len(req.messages); i = i + 1 {
        for j := 0; j < len(req.messages[i]); j = j + 1 {
            messages_str = messages_str + req.messages[i][j] + " "
        }
    }
    
    response := "{"
    response = response + "\"id\":\"chatcmpl-" + get_timestamp_string() + "\","
    response = response + "\"object\":\"chat.completion\","
    response = response + "\"model\":\"" + s.current_model + "\","
    response = response + "\"choices\":[{"
    response = response + "\"index\":0,"
    response = response + "\"message\":{\"role\":\"assistant\",\"content\":\"这是来自 " + s.get_model_name(s.current_model) + " 的回复。用户输入: " + messages_str + ":\n这是一个模拟响应。\"},"
    response = response + "\"finish_reason\":\"stop\""
    response = response + "}],"
    response = response + "\"usage\":{\"prompt_tokens\":" + string_of_int(count_tokens(messages_str)) + ",\"completion_tokens\":20,\"total_tokens\":" + string_of_int(count_tokens(messages_str) + 20) + "}"
    response = response + "}"
    
    return response
}

func (s: &web_chat_server) get_model_name(model_id: string) string {
    for i := 0; i < len(s.models); i = i + 1 {
        if s.models[i].model_id == model_id {
            return s.models[i].model_name
        }
    }
    return "Unknown Model"
}

func count_tokens(text: string) int {
    return len(text) / 4
}

func get_timestamp_string() string {
    return "1234567890"
}

func string_of_int(n: int) string {
    if n == 0 { return "0" }
    if n < 0 { return "-" + string_of_int(-n) }
    
    result := ""
    temp := n
    while temp > 0 {
        digit := temp % 10
        result = (if digit == 0 { "0" } else if digit == 1 { "1" } else if digit == 2 { "2" } else if digit == 3 { "3" } else if digit == 4 { "4" } else if digit == 5 { "5" } else if digit == 6 { "6" } else if digit == 7 { "7" } else if digit == 8 { "8" } else { "9" }) + result
        temp = temp / 10
    }
    return result
}

func (s: &web_chat_server) start() {
    s.socket_fd = __sys_socket(2, 1, 0)
    if s.socket_fd < 0 {
        return
    }
    
    __sys_setsockopt(s.socket_fd, 1, 15, 1)
    __sys_bind(s.socket_fd, s.host, s.port, 2)
    __sys_listen(s.socket_fd, 128)
    
    s.running = true
    for s.running {
        client_fd := __sys_accept(s.socket_fd)
        if client_fd >= 0 {
            s.handle_client(client_fd)
        }
    }
}

func (s: &web_chat_server) handle_client(client_fd: int) {
    request := __sys_read_string(client_fd, 4096)
    response := s.parse_and_handle_request(request)
    __sys_write_string(client_fd, response)
    __sys_close(client_fd)
}

func (s: &web_chat_server) parse_and_handle_request(request: string) string {
    if len(request) == 0 {
        return get_http_error(400)
    }
    
    method := ""
    path := ""
    if len(request) > 0 {
        space_idx := find_char(request, 32)
        if space_idx > 0 {
            method = substring(request, 0, space_idx)
            second_space := find_char_from(request, 32, space_idx + 1)
            if second_space > 0 {
                path = substring(request, space_idx + 1, second_space)
            }
        }
    }
    
    if method == "GET" {
        if path == "/" || path == "/index.html" {
            return get_http_response_html(get_chat_html())
        } else if path == "/api/models" {
            return get_http_response_json(s.get_model_list())
        } else if path == "/api/health" {
            health := "{\"status\":\"ok\",\"model\":\"" + s.current_model + "\"}"
            return get_http_response_json(health)
        } else if starts_with(path, "/api/chat") {
            return get_http_response_json("{\"error\":\"Use POST for chat\"}")
        }
    } else if method == "POST" {
        if path == "/api/chat" {
            body_start := find_string(request, "\r\n\r\n")
            if body_start > 0 {
                body := substring(request, body_start + 4, len(request))
                chat_req := parse_chat_request(body)
                response := s.handle_chat_request(&chat_req)
                return get_http_response_json(response)
            }
        } else if path == "/v1/chat/completions" {
            body_start := find_string(request, "\r\n\r\n")
            if body_start > 0 {
                body := substring(request, body_start + 4, len(request))
                chat_req := parse_chat_request(body)
                response := s.handle_chat_request(&chat_req)
                return get_http_response_json(response)
            }
        }
    }
    
    return get_http_response_html(get_chat_html())
}

func parse_chat_request(json_body: string) chat_request {
    req := chat_request{
        model: "qwen-0.5b",
        messages: make([]string[], 0, 10),
        max_tokens: 256,
        temperature: 0.7,
        top_p: 0.9,
    }
    
    if contains(json_body, "\"model\"") {
        model_start := find_string(json_body, "\"model\":\"")
        if model_start >= 0 {
            model_start = model_start + 9
            model_end := find_char_from(json_body, 34, model_start)
            if model_end > model_start {
                req.model = substring(json_body, model_start, model_end)
            }
        }
    }
    
    if contains(json_body, "\"max_tokens\"") {
        tokens_idx := find_string(json_body, "\"max_tokens\":")
        if tokens_idx >= 0 {
            num_start := tokens_idx + 13
            num_end := find_char_from_any(json_body, ",}", num_start)
            if num_end > num_start {
                tokens_str := substring(json_body, num_start, num_end)
                req.max_tokens = parse_int(tokens_str)
            }
        }
    }
    
    messages := make([]string[], 0, 5)
    msg := make([]string, 0, 2)
    msg = append(msg, "user")
    msg = append(msg, "Hello")
    messages = append(messages, msg)
    req.messages = messages
    
    return req
}

func get_http_response_json(json_data: string) string {
    response := "HTTP/1.1 200 OK\r\n"
    response = response + "Content-Type: application/json\r\n"
    response = response + "Content-Length: " + string_of_int(len(json_data)) + "\r\n"
    response = response + "Access-Control-Allow-Origin: *\r\n"
    response = response + "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
    response = response + "Access-Control-Allow-Headers: Content-Type\r\n"
    response = response + "Connection: close\r\n"
    response = response + "\r\n"
    response = response + json_data
    return response
}

func get_http_response_html(html_data: string) string {
    response := "HTTP/1.1 200 OK\r\n"
    response = response + "Content-Type: text/html; charset=utf-8\r\n"
    response = response + "Content-Length: " + string_of_int(len(html_data)) + "\r\n"
    response = response + "Connection: close\r\n"
    response = response + "\r\n"
    response = response + html_data
    return response
}

func get_http_error(code: int) string {
    return "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nBad Request"
}

func get_chat_html() string {
    return "<!DOCTYPE html><html><head><title>NeurX Chat</title></head><body>Chat UI loading...</body></html>"
}

func find_char(s: string, ch: int) int {
    for i := 0; i < len(s); i = i + 1 {
        if ord_char(s, i) == ch {
            return i
        }
    }
    return -1
}

func find_char_from(s: string, ch: int, start: int) int {
    for i := start; i < len(s); i = i + 1 {
        if ord_char(s, i) == ch {
            return i
        }
    }
    return -1
}

func find_char_from_any(s: string, chars: string, start: int) int {
    for i := start; i < len(s); i = i + 1 {
        c := ord_char(s, i)
        for j := 0; j < len(chars); j = j + 1 {
            if ord_char(chars, j) == c {
                return i
            }
        }
    }
    return len(s)
}

func find_string(s: string, pattern: string) int {
    if len(pattern) == 0 || len(pattern) > len(s) {
        return -1
    }
    
    for i := 0; i < len(s) - len(pattern) + 1; i = i + 1 {
        match := true
        for j := 0; j < len(pattern); j = j + 1 {
            if ord_char(s, i + j) != ord_char(pattern, j) {
                match = false
                break
            }
        }
        if match {
            return i
        }
    }
    return -1
}

func substring(s: string, start: int, end: int) string {
    if start < 0 || end > len(s) || start > end {
        return ""
    }
    result := ""
    for i := start; i < end; i = i + 1 {
        result = result + char_at(s, i)
    }
    return result
}

func char_at(s: string, index: int) string {
    if index < 0 || index >= len(s) {
        return ""
    }
    c := ord_char(s, index)
    if c == 0 { return "" }
    if c < 128 {
        return string_from_byte(c)
    }
    return ""
}

func string_from_byte(b: int) string {
    cs := make([]int, 1)
    cs[0] = b
    return string(cs)
}

func ord_char(s: string, index: int) int {
    if index < 0 || index >= len(s) {
        return 0
    }
    
    b := 0
    for i := 0; i <= index && i < len(s); i = i + 1 {
        c := s[i : i+1]
        if len(c) > 0 {
            for j := 0; j < len(c); j = j + 1 {
                b = b + 1
            }
        }
    }
    return b
}

func starts_with(s: string, prefix: string) bool {
    if len(prefix) > len(s) {
        return false
    }
    for i := 0; i < len(prefix); i = i + 1 {
        if ord_char(s, i) != ord_char(prefix, i) {
            return false
        }
    }
    return true
}

func contains(s: string, substr: string) bool {
    return find_string(s, substr) >= 0
}

func parse_int(s: string) int {
    result := 0
    for i := 0; i < len(s); i = i + 1 {
        ch := ord_char(s, i)
        if ch >= 48 && ch <= 57 {
            result = result * 10 + (ch - 48)
        }
    }
    return result
}

func main() {
    server := create_web_chat_server(8081)
    server.start()
}
