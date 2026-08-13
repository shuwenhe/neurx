package neurx.serving.protocol.openai_tgi
func serving_json_escape(string value) string {
    string out = ""
    int i = 0
    while i < len(value) {
        string ch = string(value[i])
        if ch == "\\" {
            out = out + "\\\\"
        } else if ch == "\"" {
            out = out + "\\\""
        } else if ch == "\n" {
            out = out + "\\n"
        } else if ch == "\r" {
            out = out + "\\r"
        } else if ch == "\t" {
            out = out + "\\t"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out
}
func serving_bool_json(bool value) string {
    if value { return "true" }
    "false"
}
func openai_chat_sse_chunk(string request_id, string model, int created, string content, string finish_reason) string {
    string finish = "null"
    if finish_reason != "" {
        finish = "\"" + serving_json_escape(finish_reason) + "\""
    }
    string payload = "{\"id\":\"" + serving_json_escape(request_id) + "\","
    payload = payload + "\"object\":\"chat.completion.chunk\","
    payload = payload + "\"created\":" + string(created) + ","
    payload = payload + "\"model\":\"" + serving_json_escape(model) + "\","
    payload = payload + "\"choices\":[{\"index\":0,\"delta\":{\"content\":\"" + serving_json_escape(content) + "\"},"
    payload = payload + "\"finish_reason\":" + finish + "}]}"
    "data: " + payload + "\n\n"
}
func openai_sse_done() string {
    "data: [DONE]\n\n"
}
func openai_error_json(string message, string error_type, int status) string {
    "{\"error\":{\"message\":\"" + serving_json_escape(message) + "\",\"type\":\"" + serving_json_escape(error_type) + "\",\"code\":" + string(status) + "}}"
}
func tgi_token_sse(int token_id, string token_text, bool special) string {
    string payload = "{\"token\":{\"id\":" + string(token_id) + ",\"text\":\"" + serving_json_escape(token_text) + "\",\"logprob\":null,\"special\":" + serving_bool_json(special) + "},\"generated_text\":null,\"details\":null}"
    "data: " + payload + "\n\n"
}
func tgi_final_sse(int token_id, string token_text, string generated_text, string finish_reason, int generated_tokens) string {
    string payload = "{\"token\":{\"id\":" + string(token_id) + ",\"text\":\"" + serving_json_escape(token_text) + "\",\"logprob\":null,\"special\":false},"
    payload = payload + "\"generated_text\":\"" + serving_json_escape(generated_text) + "\","
    payload = payload + "\"details\":{\"finish_reason\":\"" + serving_json_escape(finish_reason) + "\",\"generated_tokens\":" + string(generated_tokens) + "}}"
    "data: " + payload + "\n\n"
}
func serving_route_kind(string method, string path) string {
    if method == "POST" && path == "/v1/chat/completions" { return "openai-chat" }
    if method == "POST" && path == "/v1/completions" { return "openai-completion" }
    if method == "POST" && path == "/generate" { return "tgi-generate" }
    if method == "POST" && path == "/generate_stream" { return "tgi-stream" }
    if method == "GET" && path == "/health" { return "health" }
    if method == "GET" && path == "/metrics" { return "metrics" }
    "not-found"
}
