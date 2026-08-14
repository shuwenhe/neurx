package neurx.inference.api.openai_protocol
struct openai_request {
    string request_id
    string model
    string prompt
    int max_tokens
    int temperature_milli
    int top_p_milli
    bool stream
    string response_format
    string tool_choice
    string tool_parser
    string adapter_id
    string user
}

struct openai_request_result {
    openai_request request
    bool valid
    int status_code
    string error_message
}

func openai_substring(string text, int start, int end) string {
    string result = ""
    int i = start
    while i < end && i < len(text) {
        result = result + string(text[i])
        i = i + 1
    }
    result
}

func openai_find(string text, string pattern, int start) int {
    int i = start
    while i + len(pattern) <= len(text) {
        int j = 0
        bool matches = true
        while j < len(pattern) {
            if text[i + j] != pattern[j] {
                matches = false
                break
            }
            j = j + 1
        }
        if matches {
            return i
        }
        i = i + 1
    }
    -1
}

func openai_is_space(int ch) bool {
    ch == 32 || ch == 10 || ch == 13 || ch == 9
}

func openai_skip_space(string text, int start) int {
    int i = start
    while i < len(text) && openai_is_space(int(text[i])) {
        i = i + 1
    }
    i
}

func openai_field_start(string body, string key) int {
    int key_start = openai_find(body, "\"" + key + "\"", 0)
    if key_start < 0 {
        return -1
    }
    int colon = openai_find(body, ":", key_start + len(key) + 2)
    if colon < 0 {
        return -1
    }
    openai_skip_space(body, colon + 1)
}

func openai_json_string(string body, string key) string {
    int start = openai_field_start(body, key)
    if start < 0 || start >= len(body) || int(body[start]) != 34 {
        return ""
    }
    string value = ""
    bool escaped = false
    int i = start + 1
    while i < len(body) {
        int ch = int(body[i])
        if escaped {
            value = value + string(body[i])
            escaped = false
        } else if ch == 92 {
            escaped = true
        } else if ch == 34 {
            return value
        } else {
            value = value + string(body[i])
        }
        i = i + 1
    }
    ""
}

func openai_json_int(string body, string key, int default_value) int {
    int start = openai_field_start(body, key)
    if start < 0 {
        return default_value
    }
    bool negative = false
    if start < len(body) && int(body[start]) == 45 {
        negative = true
        start = start + 1
    }
    int value = 0
    bool found = false
    int i = start
    while i < len(body) && int(body[i]) >= 48 && int(body[i]) <= 57 {
        value = value * 10 + int(body[i]) - 48
        found = true
        i = i + 1
    }
    if !found {
        return default_value
    }
    if negative {
        return 0 - value
    }
    value
}

func openai_json_bool(string body, string key, bool default_value) bool {
    int start = openai_field_start(body, key)
    if start < 0 {
        return default_value
    }
    if openai_find(body, "true", start) == start {
        return true
    }
    if openai_find(body, "false", start) == start {
        return false
    }
    default_value
}

func openai_json_decimal_milli(string body, string key, int default_value) int {
    int start = openai_field_start(body, key)
    if start < 0 {
        return default_value
    }
    bool negative = false
    if start < len(body) && int(body[start]) == 45 {
        negative = true
        start = start + 1
    }
    int whole = 0
    bool found = false
    int i = start
    while i < len(body) && int(body[i]) >= 48 && int(body[i]) <= 57 {
        whole = whole * 10 + int(body[i]) - 48
        found = true
        i = i + 1
    }
    int fraction = 0
    int digits = 0
    if i < len(body) && int(body[i]) == 46 {
        i = i + 1
        while i < len(body) && int(body[i]) >= 48 && int(body[i]) <= 57 && digits < 3 {
            fraction = fraction * 10 + int(body[i]) - 48
            digits = digits + 1
            i = i + 1
        }
    }
    if !found {
        return default_value
    }
    while digits < 3 {
        fraction = fraction * 10
        digits = digits + 1
    }
    int value = whole * 1000 + fraction
    if negative {
        return 0 - value
    }
    value
}

func openai_latest_message_content(string body) string {
    int messages = openai_find(body, "\"messages\"", 0)
    if messages < 0 {
        return openai_json_string(body, "prompt")
    }
    string latest = ""
    int search_from = messages
    int content = openai_find(body, "\"content\"", search_from)
    while content >= 0 {
        string tail = openai_substring(body, content, len(body))
        string value = openai_json_string(tail, "content")
        if value != "" {
            latest = value
        }
        search_from = content + len("\"content\"")
        content = openai_find(body, "\"content\"", search_from)
    }
    latest
}

func openai_response_format(string body) string {
    int start = openai_field_start(body, "response_format")
    if start < 0 {
        return "text"
    }
    if start < len(body) && int(body[start]) == 34 {
        return openai_json_string(body, "response_format")
    }
    string tail = openai_substring(body, start, len(body))
    string format_type = openai_json_string(tail, "type")
    if format_type == "" {
        return "text"
    }
    format_type
}

func new_openai_request_result(openai_request request, bool valid, int status_code, string error_message) openai_request_result {
    openai_request_result result
    result.request = request
    result.valid = valid
    result.status_code = status_code
    result.error_message = error_message
    result
}

func parse_openai_request(string body, string request_id) openai_request_result {
    openai_request request
    request.request_id = request_id
    request.model = openai_json_string(body, "model")
    request.prompt = openai_latest_message_content(body)
    request.max_tokens = openai_json_int(body, "max_completion_tokens", 0)
    if request.max_tokens <= 0 {
        request.max_tokens = openai_json_int(body, "max_tokens", 256)
    }
    request.temperature_milli = openai_json_decimal_milli(body, "temperature", openai_json_int(body, "temperature_milli", 700))
    request.top_p_milli = openai_json_decimal_milli(body, "top_p", openai_json_int(body, "top_p_milli", 1000))
    request.stream = openai_json_bool(body, "stream", false)
    request.response_format = openai_response_format(body)
    request.tool_choice = openai_json_string(body, "tool_choice")
    request.tool_parser = openai_json_string(body, "tool_parser")
    request.adapter_id = openai_json_string(body, "adapter_id")
    request.user = openai_json_string(body, "user")
    if request.model == "" {
        return new_openai_request_result(request, false, 400, "model is required")
    }
    if request.prompt == "" {
        return new_openai_request_result(request, false, 400, "prompt or messages content is required")
    }
    if request.max_tokens <= 0 {
        return new_openai_request_result(request, false, 400, "max_tokens must be positive")
    }
    if request.temperature_milli < 0 || request.temperature_milli > 2000 {
        return new_openai_request_result(request, false, 400, "temperature_milli must be between 0 and 2000")
    }
    if request.top_p_milli <= 0 || request.top_p_milli > 1000 {
        return new_openai_request_result(request, false, 400, "top_p_milli must be between 1 and 1000")
    }
    new_openai_request_result(request, true, 200, "")
}

func openai_json_escape(string text) string {
    string escaped = ""
    int i = 0
    while i < len(text) {
        int ch = int(text[i])
        if ch == 34 {
            escaped = escaped + "\\\""
        } else if ch == 92 {
            escaped = escaped + "\\\\"
        } else if ch == 10 {
            escaped = escaped + "\\n"
        } else if ch == 13 {
            escaped = escaped + "\\r"
        } else if ch == 9 {
            escaped = escaped + "\\t"
        } else {
            escaped = escaped + string(text[i])
        }
        i = i + 1
    }
    escaped
}

func openai_chat_chunk(string request_id, string model, string content, string finish_reason) string {
    string finish = "null"
    if finish_reason != "" {
        finish = "\"" + openai_json_escape(finish_reason) + "\""
    }
    string json = "{\"id\":\"" + openai_json_escape(request_id) + "\",\"object\":\"chat.completion.chunk\",\"model\":\"" + openai_json_escape(model) + "\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"" + openai_json_escape(content) + "\"},\"finish_reason\":" + finish + "}]}"
    "data: " + json + "\n\n"
}

func openai_done_event() string {
    "data: [DONE]\n\n"
}

func openai_error_body(string message, string error_type, string code) string {
    "{\"error\":{\"message\":\"" + openai_json_escape(message) + "\",\"type\":\"" + openai_json_escape(error_type) + "\",\"code\":\"" + openai_json_escape(code) + "\"}}"
}

func openai_embedding_body(string model, []float embedding, int prompt_tokens) string {
    string values = ""
    int i = 0
    while i < len(embedding) {
        if i > 0 {
            values = values + ","
        }
        values = values + float_to_str(embedding[i], 8)
        i = i + 1
    }
    "{\"object\":\"list\",\"data\":[{\"object\":\"embedding\",\"index\":0,\"embedding\":[" + values + "]}],\"model\":\"" + openai_json_escape(model) + "\",\"usage\":{\"prompt_tokens\":" + int_to_str(prompt_tokens) + ",\"total_tokens\":" + int_to_str(prompt_tokens) + "}}"
}
