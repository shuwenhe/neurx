package neurx.inference.api.rest_server

use neurx.inference.api.http_server.{http_request, http_response, create_http_server, server_accept_loop, close_http_server, format_http_response, parse_http_request}

func json_escape(string s) string {
    result := ""
    for i := 0; i < len(s); i++ {
        c := s[i]
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
    }
    return result
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    string result = ""
    int n = value
    if n < 0 {
        result = "-"
        n = 0 - n
    }
    string digits = "0123456789"
    while n > 0 {
        int digit = n % 10
        if digit == 0 { result = result + "0" }
        if digit == 1 { result = result + "1" }
        if digit == 2 { result = result + "2" }
        if digit == 3 { result = result + "3" }
        if digit == 4 { result = result + "4" }
        if digit == 5 { result = result + "5" }
        if digit == 6 { result = result + "6" }
        if digit == 7 { result = result + "7" }
        if digit == 8 { result = result + "8" }
        if digit == 9 { result = result + "9" }
        n = n / 10
    }
    return result
}

func create_json_response(string status, string model, string content, int prompt_tokens, int completion_tokens) string {
    id := "chatcmpl-" + int_to_string(12345)
    created := int_to_string(1786879972)
    total := prompt_tokens + completion_tokens
    
    json := "{"
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
    json := "{"
    json = json + "\"status\": \"healthy\","
    json = json + "\"model\": \"Qwen2.5-0.5B-Instruct\","
    json = json + "\"model_path\": \"/app/shuwen/model/Qwen2.5-0.5B-Instruct\","
    json = json + "\"timestamp\": \"2026-08-16T19:36:00Z\","
    json = json + "\"api_version\": \"v1\""
    json = json + "}"
    return json
}

func create_models_response() string {
    json := "{"
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
    json := "{"
    json = json + "\"error\": {"
    json = json + "\"message\": \"" + json_escape(error_msg) + "\","
    json = json + "\"type\": \"invalid_request_error\""
    json = json + "}"
    json = json + "}"
    return json
}

func handle_health_request() http_response {
    body := create_health_response()
    return http_response{
        status_code: 200,
        headers: [],
        body: body
    }
}

func handle_models_request() http_response {
    body := create_models_response()
    return http_response{
        status_code: 200,
        headers: [],
        body: body
    }
}

func handle_chat_completion_request(string request_body) http_response {
    content := "This is a simulated inference response from the NeurX inference engine in pure S language."
    prompt_tokens := 5
    completion_tokens := 128
    
    body := create_json_response("ok", "Qwen2.5-0.5B-Instruct", content, prompt_tokens, completion_tokens)
    
    return http_response{
        status_code: 200,
        headers: [],
        body: body
    }
}

func handle_api_request(http_request request) http_response {
    path := request.path
    method := request.method
    
    if path == "/health" && method == "GET" {
        return handle_health_request()
    }
    
    if path == "/v1/models" && method == "GET" {
        return handle_models_request()
    }
    
    if path == "/v1/chat/completions" && method == "POST" {
        return handle_chat_completion_request(request.body)
    }
    
    if path == "/" && method == "GET" {
        json := "{"
        json = json + "\"name\": \"NeurX REST API\","
        json = json + "\"version\": \"1.0.0\","
        json = json + "\"model\": \"Qwen2.5-0.5B-Instruct\""
        json = json + "}"
        return http_response{
            status_code: 200,
            headers: [],
            body: json
        }
    }
    
    error_body := create_error_response("Endpoint not found: " + method + " " + path)
    return http_response{
        status_code: 404,
        headers: [],
        body: error_body
    }
}

func main() {
    print("\n╔════════════════════════════════════════════════════════════════╗\n")
    print("║       NeurX REST API Server (Pure S Language)                ║\n")
    print("║       OpenAI-Compatible HTTP API                             ║\n")
    print("╚════════════════════════════════════════════════════════════════╝\n")
    print("\n")
    
    host := "0.0.0.0"
    port := 8888
    
    print("📋 Configuration:\n")
    print("  Host: " + host + "\n")
    print("  Port: " + int_to_string(port) + "\n")
    print("  Model: Qwen2.5-0.5B-Instruct\n")
    print("\n")
    
    print("🚀 Starting REST API Server...\n")
    print("\n")
    
    server := create_http_server(host, port)
    
    if server.listen_fd < 0 {
        print("❌ Failed to start server\n")
        return
    }
    
    print("📚 API Endpoints:\n")
    print("  GET  /health                     - Health check\n")
    print("  GET  /v1/models                  - List models\n")
    print("  POST /v1/chat/completions       - Chat completion (OpenAI compatible)\n")
    print("\n")
    print("📖 Documentation: http://localhost:" + int_to_string(port) + "/docs\n")
    print("\n")
    
    server_accept_loop(server, handle_api_request)
    
    close_http_server(server)
}
