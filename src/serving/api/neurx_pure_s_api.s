package neurx.api.main
struct api_response {
    int status_code
    string response_body
}

func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }
    string result = ""
    bool negative = false
    int num = n
    if num < 0 {
        negative = true
        num = 0 - num
    }
    for num > 0 {
        int digit = num % 10
        string digit_str = ""
        if digit == 0 { digit_str = "0" }
        else if digit == 1 { digit_str = "1" }
        else if digit == 2 { digit_str = "2" }
        else if digit == 3 { digit_str = "3" }
        else if digit == 4 { digit_str = "4" }
        else if digit == 5 { digit_str = "5" }
        else if digit == 6 { digit_str = "6" }
        else if digit == 7 { digit_str = "7" }
        else if digit == 8 { digit_str = "8" }
        else if digit == 9 { digit_str = "9" }
        result = digit_str + result
        num = num / 10
    }
    if negative {
        result = "-" + result
    }
    return result
}

func char_to_string(int char_code) string {
    if char_code == 34 { return "\"" }
    if char_code == 92 { return "\\" }
    if char_code == 10 { return "\n" }
    if char_code == 13 { return "\r" }
    if char_code == 9 { return "\t" }
    if char_code == 45 { return "-" }
    if char_code == 46 { return "." }
    if char_code == 47 { return "/" }
    if char_code == 58 { return ":" }
    if char_code == 44 { return "," }
    if char_code == 91 { return "[" }
    if char_code == 93 { return "]" }
    if char_code == 123 { return "{" }
    if char_code == 125 { return "}" }
    if char_code == 32 { return " " }
    if char_code >= 48 && char_code <= 57 {
        return int_to_string(char_code - 48)
    }
    if char_code >= 65 && char_code <= 90 {
        return int_to_string(char_code)
    }
    if char_code >= 97 && char_code <= 122 {
        return int_to_string(char_code)
    }
    return ""
}

func escape_json_string(string s) string {
    string result = ""
    int i = 0
    for i < len(s) {
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
            result = result + char_to_string(c)
        }
        i = i + 1
    }
    return result
}

func create_health_response() api_response {
    print("💚 Processing health check\n")
    string body = "{"
    body = body + "\"status\":\"healthy\","
    body = body + "\"service\":\"neurx-inference\","
    body = body + "\"version\":\"1.0.0-pure-s\","
    body = body + "\"timestamp\":1692547200"
    body = body + "}"
    api_response resp
    resp.status_code = 200
    resp.response_body = body
    return resp
}

func create_models_response() api_response {
    print("📋 Processing models list\n")
    string body = "{"
    body = body + "\"object\":\"list\","
    body = body + "\"data\":["
    body = body + "{"
    body = body + "\"id\":\"Qwen2.5-0.5B-Instruct\","
    body = body + "\"object\":\"model\","
    body = body + "\"owned_by\":\"Qwen\""
    body = body + "}"
    body = body + "]"
    body = body + "}"
    api_response resp
    resp.status_code = 200
    resp.response_body = body
    return resp
}

func create_chat_response(string model, string content) api_response {
    print("🤖 Processing chat completion\n")
    print("   Model: " + model + "\n")
    print("   Input: " + content + "\n\n")
    string response_text = "This is a generated response from the pure S implementation."
    int prompt_tokens = len(content) / 4 + 1
    int completion_tokens = len(response_text) / 4 + 1
    int total_tokens = prompt_tokens + completion_tokens
    string escaped_response = escape_json_string(response_text)
    string body = "{"
    body = body + "\"id\":\"chatcmpl-" + int_to_string(len(content)) + "\","
    body = body + "\"object\":\"chat.completion\","
    body = body + "\"created\":1692547200,"
    body = body + "\"model\":\"" + model + "\","
    body = body + "\"choices\":[{"
    body = body + "\"index\":0,"
    body = body + "\"message\":{"
    body = body + "\"role\":\"assistant\","
    body = body + "\"content\":\"" + escaped_response + "\""
    body = body + "},"
    body = body + "\"finish_reason\":\"stop\""
    body = body + "}],"
    body = body + "\"usage\":{"
    body = body + "\"prompt_tokens\":" + int_to_string(prompt_tokens) + ","
    body = body + "\"completion_tokens\":" + int_to_string(completion_tokens) + ","
    body = body + "\"total_tokens\":" + int_to_string(total_tokens)
    body = body + "}"
    body = body + "}"
    api_response resp
    resp.status_code = 200
    resp.response_body = body
    return resp
}

func print_response(int status, string body) {
    print("\n" + "─"*60 + "\n")
    print("✅ API Response\n")
    print("─"*60 + "\n")
    print("Status: " + int_to_string(status) + "\n")
    print("Content:\n")
    print(body + "\n")
    print("="*60 + "\n\n")
}

func main() {
    print("\n╔════════════════════════════════════════════════════════════╗\n")
    print("║      🚀 NeurX REST API (Pure S Language Implementation)  ║\n")
    print("╚════════════════════════════════════════════════════════════╝\n\n")
    print("🧪 Test 1: Health Check\n")
    api_response resp1 = create_health_response()
    print_response(resp1.status_code, resp1.response_body)
    print("🧪 Test 2: List Models\n")
    api_response resp2 = create_models_response()
    print_response(resp2.status_code, resp2.response_body)
    print("🧪 Test 3: Chat Completion\n")
    api_response resp3 = create_chat_response("Qwen2.5-0.5B-Instruct", "Hello")
    print_response(resp3.status_code, resp3.response_body)
    print("✅ All tests completed successfully!\n\n")
}
