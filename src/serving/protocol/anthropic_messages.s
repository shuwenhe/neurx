package neurx.serving.protocol.anthropic_messages

struct anthropic_message_request {
    string model
    string system_prompt
    string user_content
    int max_tokens
    float temperature
    float top_p
    bool stream
    string stop_sequence
}

struct anthropic_message_response {
    string id
    string model
    string role
    string content
    string stop_reason
    string stop_sequence
    int input_tokens
    int output_tokens
}

struct anthropic_validation_result {
    bool valid
    string error_type
    string error_message
}

func anthropic_int_string(int value) string {
    if value == 0 { return "0" }
    int current = value
    string prefix = ""
    if current < 0 { prefix = "-"; current = 0 - current }
    string digits = ""
    for current > 0 {
        int digit = current - (current / 10) * 10
        digits = anthropic_digit_string(digit) + digits
        current = current / 10
    }
    prefix + digits
}

func anthropic_digit_string(int digit) string {
    if digit == 0 { return "0" }
    if digit == 1 { return "1" }
    if digit == 2 { return "2" }
    if digit == 3 { return "3" }
    if digit == 4 { return "4" }
    if digit == 5 { return "5" }
    if digit == 6 { return "6" }
    if digit == 7 { return "7" }
    if digit == 8 { return "8" }
    "9"
}

func anthropic_json_escape(string value) string {
    string output = ""
    int i = 0
    for i < len(value) {
        int ch = value[i]
        if ch == 34 { output = output + "\\\"" }
        else if ch == 92 { output = output + "\\\\" }
        else if ch == 10 { output = output + "\\n" }
        else if ch == 13 { output = output + "\\r" }
        else if ch == 9 { output = output + "\\t" }
        else { output = output + string(value[i]) }
        i = i + 1
    }
    output
}

func anthropic_validate_request(anthropic_message_request request) anthropic_validation_result {
    if request.model == "" {
        return anthropic_validation_result {valid: false, error_type: "invalid_request_error", error_message: "model is required"}
    }
    if request.user_content == "" {
        return anthropic_validation_result {valid: false, error_type: "invalid_request_error", error_message: "at least one user message is required"}
    }
    if request.max_tokens <= 0 {
        return anthropic_validation_result {valid: false, error_type: "invalid_request_error", error_message: "max_tokens must be positive"}
    }
    if request.temperature < 0.0 || request.temperature > 1.0 {
        return anthropic_validation_result {valid: false, error_type: "invalid_request_error", error_message: "temperature must be between zero and one"}
    }
    if request.top_p <= 0.0 || request.top_p > 1.0 {
        return anthropic_validation_result {valid: false, error_type: "invalid_request_error", error_message: "top_p must be greater than zero and at most one"}
    }
    anthropic_validation_result {valid: true, error_type: "", error_message: ""}
}

func anthropic_estimate_tokens(string text) int {
    if len(text) == 0 { return 0 }
    int tokens = 1
    int i = 0
    bool previous_space = false
    for i < len(text) {
        int ch = text[i]
        bool space = ch == 32 || ch == 10 || ch == 13 || ch == 9
        if space && !previous_space { tokens = tokens + 1 }
        previous_space = space
        i = i + 1
    }
    tokens
}

func anthropic_messages_json(anthropic_message_response response) string {
    "{\"id\":\"" + anthropic_json_escape(response.id) + "\",\"type\":\"message\",\"role\":\"assistant\",\"model\":\"" + anthropic_json_escape(response.model) + "\",\"content\":[{\"type\":\"text\",\"text\":\"" + anthropic_json_escape(response.content) + "\"}],\"stop_reason\":\"" + anthropic_json_escape(response.stop_reason) + "\",\"stop_sequence\":\"" + anthropic_json_escape(response.stop_sequence) + "\",\"usage\":{\"input_tokens\":" + anthropic_int_string(response.input_tokens) + ",\"output_tokens\":" + anthropic_int_string(response.output_tokens) + "}}"
}

func anthropic_error_json(string error_type, string message) string {
    "{\"type\":\"error\",\"error\":{\"type\":\"" + anthropic_json_escape(error_type) + "\",\"message\":\"" + anthropic_json_escape(message) + "\"}}"
}

func anthropic_sse_event(string event_name, string payload) string {
    "event: " + event_name + "\ndata: " + payload + "\n\n"
}

func anthropic_message_start_event(string id, string model, int input_tokens) string {
    string payload = "{\"type\":\"message_start\",\"message\":{\"id\":\"" + anthropic_json_escape(id) + "\",\"type\":\"message\",\"role\":\"assistant\",\"model\":\"" + anthropic_json_escape(model) + "\",\"content\":[],\"stop_reason\":null,\"usage\":{\"input_tokens\":" + anthropic_int_string(input_tokens) + ",\"output_tokens\":0}}"
    anthropic_sse_event("message_start", payload)
}

func anthropic_content_block_start_event(int index) string {
    anthropic_sse_event("content_block_start", "{\"type\":\"content_block_start\",\"index\":" + anthropic_int_string(index) + ",\"content_block\":{\"type\":\"text\",\"text\":\"\"}}")
}

func anthropic_content_delta_event(int index, string text) string {
    anthropic_sse_event("content_block_delta", "{\"type\":\"content_block_delta\",\"index\":" + anthropic_int_string(index) + ",\"delta\":{\"type\":\"text_delta\",\"text\":\"" + anthropic_json_escape(text) + "\"}}")
}

func anthropic_content_block_stop_event(int index) string {
    anthropic_sse_event("content_block_stop", "{\"type\":\"content_block_stop\",\"index\":" + anthropic_int_string(index) + "}")
}

func anthropic_message_stop_events(string stop_reason, int output_tokens) string {
    string delta = anthropic_sse_event("message_delta", "{\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"" + anthropic_json_escape(stop_reason) + "\",\"stop_sequence\":null},\"usage\":{\"output_tokens\":" + anthropic_int_string(output_tokens) + "}}")
    delta + anthropic_sse_event("message_stop", "{\"type\":\"message_stop\"}")
}
