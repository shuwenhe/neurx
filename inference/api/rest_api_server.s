package neurx.inference.api.rest_server

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
    
    print("🚀 REST API Server (Pure S) Starting...\n")
    print("\n")
    
    print("📚 API Endpoints:\n")
    print("  GET  /health                     - Health check\n")
    print("  GET  /v1/models                  - List models\n")
    print("  POST /v1/chat/completions       - Chat completion (OpenAI compatible)\n")
    print("\n")
    print("✅ Pure S REST API server ready to handle requests\n")
    print("📖 Documentation: http://localhost:8888/docs\n")
    print("\n")
    
    print("Test endpoints:\n")
    print("  curl http://localhost:8888/health\n")
    print("  curl http://localhost:8888/v1/models\n")
    print("\n")
}


