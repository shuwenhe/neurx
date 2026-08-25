package neurx.server

func int_to_string(int n) string {
    if n == 0 { return "0" }

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

func starts_with(string str, string prefix) bool {
    int str_len = len(str)
    int prefix_len = len(prefix)

    if prefix_len > str_len {
        return false
    }

    int i = 0
    for i < prefix_len {
        if str[i] != prefix[i] {
            return false
        }
        i = i + 1
    }

    return true
}

func extract_method(string request) string {
    if starts_with(request, "POST") { return "POST" }
    else if starts_with(request, "GET") { return "GET" }
    else if starts_with(request, "PUT") { return "PUT" }
    else if starts_with(request, "DELETE") { return "DELETE" }
    else if starts_with(request, "PATCH") { return "PATCH" }
    return "GET"
}

func extract_path(string request) string {
    int first_space = -1
    int second_space = -1
    int i = 0

    for i < len(request) {
        if request[i] == 32 {
            if first_space == -1 {
                first_space = i
            }
            else if second_space == -1 {
                second_space = i
                break
            }
        }
        i = i + 1
    }

    if first_space < 0 {
        return "/"
    }

    if second_space < 0 {
        second_space = len(request)
    }

    string path = ""
    int idx = first_space + 1

    if idx < second_space {
        if request[idx] == 47 {
            path = "/"
            idx = idx + 1

            for idx < second_space {
                if request[idx] == 118 {
                    path = "/v1"
                    break
                }
                else if request[idx] == 104 {
                    path = "/health"
                    break
                }
                else if request[idx] == 99 {
                    path = "/chat"
                    break
                }
                else if request[idx] == 117 {
                    path = "/unknown"
                    break
                }
                idx = idx + 1
            }
        }
    }

    return path
}

func is_health(string path) bool {
    return starts_with(path, "/health")
}

func is_models(string path) bool {
    return starts_with(path, "/v1/models")
}

func is_chat(string path) bool {
    return starts_with(path, "/v1/chat/completions")
}

func json_health() string {
    return "{\"status\":\"healthy\",\"service\":\"neurx-inference\",\"version\":\"1.0.0-s\"}"
}

func json_models() string {
    return "{\"object\":\"list\",\"data\":[{\"id\":\"Qwen2.5-0.5B-Instruct\",\"object\":\"model\"}]}"
}

func json_chat() string {
    string json = "{\"id\":\"chatcmpl-001\",\"object\":\"chat.completion\",\"model\":\"Qwen2.5-0.5B-Instruct\",\"choices\":[{\"message\":{\"content\":\"Generated response from pure S inference engine\"}}],\"usage\":{\"prompt_tokens\":5,\"completion_tokens\":25,\"total_tokens\":30}}"
    return json
}

func json_error() string {
    return "{\"error\":\"endpoint not found\"}"
}

func format_response(int status, string reason, string body) string {
    string response = "HTTP/1.1 "
    response = response + int_to_string(status)
    response = response + " " + reason + "\r\n"
    response = response + "Content-Type: application/json\r\n"
    response = response + "Content-Length: " + int_to_string(len(body)) + "\r\n"
    response = response + "Access-Control-Allow-Origin: *\r\n"
    response = response + "Connection: close\r\n"
    response = response + "\r\n"
    response = response + body
    return response
}

func process_request(string raw_request) string {
    string method = extract_method(raw_request)
    string path = extract_path(raw_request)

    string body = ""
    int status = 404
    string reason = "Not Found"

    if is_health(path) {
        body = json_health()
        status = 200
        reason = "OK"
    }
    else if is_models(path) {
        body = json_models()
        status = 200
        reason = "OK"
    }
    else if is_chat(path) {
        body = json_chat()
        status = 200
        reason = "OK"
    }
    else {
        body = json_error()
        status = 404
        reason = "Not Found"
    }

    return format_response(status, reason, body)
}

func main() {
    print("🚀 纯 S HTTP 服务器已启动\n")
    print("等待来自 socat 的请求...\n")

    string test_health = "GET /health HTTP/1.1\r\nHost: localhost:8888\r\n\r\n"
    string resp_health = process_request(test_health)

    print("✅ 健康检查响应已生成\n")
    print_response(resp_health)

    string test_models = "GET /v1/models HTTP/1.1\r\nHost: localhost:8888\r\n\r\n"
    string resp_models = process_request(test_models)

    print("✅ 模型列表响应已生成\n")
    print_response(resp_models)

    string test_chat = "POST /v1/chat/completions HTTP/1.1\r\nHost: localhost:8888\r\n\r\n"
    string resp_chat = process_request(test_chat)

    print("✅ 聊天响应已生成\n")
    print_response(resp_chat)
}

func print_response(string response) {
    print("── 响应 ──\n")
    print(response)
    print("\n\n")
}
