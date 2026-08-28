package neurx.inference.streaming_chat
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, trim}
extern "intrinsic" func __sys_socket(int domain, int type, int protocol) int
extern "intrinsic" func __sys_connect(int sockfd, string ip, int port, int family) int
extern "intrinsic" func __sys_write_string(int fd, string data) int
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __sys_close(int fd) int
extern "intrinsic" func __host_slice(string text, int start, int end) string
func int_to_string(int value) string {
    if value == 0 { return "0" }
    int n = value
    bool negative = false
    if n < 0 {
        negative = true
        n = 0 - n
    }
    string out = ""
    for n > 0 {
        int digit = n - (n / 10) * 10
        out = string(digit + 48) + out
        n = n / 10
    }
    if negative { out = "-" + out }
    return out
}
func read_line() string {
    string result = __sys_read_string(0, 4096)
    trim(result)
}
func json_escape(string value) string {
    string output = ""
    int i = 0
    for i < len(value) {
        string ch = __host_slice(value, i, i + 1)
        if ch == "\\" { output = output + "\\\\" }
        else if ch == "\"" { output = output + "\\\"" }
        else if ch == "\n" { output = output + "\\n" }
        else if ch == "\r" { output = output + "\\r" }
        else if ch == "\t" { output = output + "\\t" }
        else { output = output + ch }
        i = i + 1
    }
    return output
}
func send_request(int sockfd, string prompt, int max_tokens) {
    string request = "POST /v1/generate HTTP/1.1\r\n"
    request = request + "Host: localhost\r\n"
    request = request + "Content-Type: application/json\r\n"
    string body = "{\"action\": \"generate\", \"prompt\": \"" + json_escape(prompt) + "\", \"max_tokens\": " + int_to_string(max_tokens) + "}"
    request = request + "Content-Length: " + int_to_string(len(body)) + "\r\n"
    request = request + "Connection: close\r\n"
    request = request + "\r\n"
    request = request + body
    _ = __sys_write_string(sockfd, request)
}
func main() {
    _ = __sys_write_string(1, "\n")
    _ = __sys_write_string(1, "========================================\n")
    _ = __sys_write_string(1, "  NeurX Streaming Chat\n")
    _ = __sys_write_string(1, "========================================\n")
    _ = __sys_write_string(1, "Commands: /exit, /reset, /max [N]\n\n")
    string backend_ip = "127.0.0.1"
    int backend_port = 18084
    int max_tokens = 256
    string history = ""
    for true {
        _ = __sys_write_string(1, "You: ")
        string user_input = read_line()
        if len(user_input) == 0 {
            continue
        }
        if user_input == "/exit" {
            _ = __sys_write_string(1, "Goodbye!\n")
            return
        }
        if user_input == "/reset" {
            history = ""
            _ = __sys_write_string(1, "History cleared.\n\n")
            continue
        }
        string prompt = history + user_input
        _ = __sys_write_string(1, "Assistant: ")
        int sockfd = __sys_socket(2, 1, 0)
        if sockfd < 0 {
            _ = __sys_write_string(1, "Error: Failed to create socket\n\n")
            continue
        }
        int result = __sys_connect(sockfd, backend_ip, backend_port, 2)
        if result < 0 {
            _ = __sys_write_string(1, "Error: Failed to connect to backend\n\n")
            _ = __sys_close(sockfd)
            continue
        }
        send_request(sockfd, prompt, max_tokens)
        int token_count = 0
        string response = __sys_read_string(sockfd, 1024)
        int i = 0
        bool in_body = false
        bool first_token = true
        for i < len(response) {
            if !in_body {
                string chunk = __host_slice(response, i, i + 4)
                if chunk == "\r\n\r\n" {
                    in_body = true
                    i = i + 4
                    continue
                }
            } else {
                string ch = __host_slice(response, i, i + 1)
                if ch != "\r" && ch != "\n" && ch != " " && len(ch) > 0 {
                    if !first_token {
                        _ = __sys_write_string(1, " ")
                    }
                    _ = __sys_write_string(1, ch)
                    token_count = token_count + 1
                    first_token = false
                }
            }
            i = i + 1
        }
        _ = __sys_close(sockfd)
        _ = __sys_write_string(1, "\n\n")
        _ = __sys_write_string(1, "[Generated ")
        _ = __sys_write_string(1, int_to_string(token_count))
        _ = __sys_write_string(1, " tokens]\n\n")
        history = prompt + " "
    }
}
