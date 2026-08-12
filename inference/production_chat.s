package neurx.inference.production_chat
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __sys_socket(int domain, int socket_type, int protocol) int
extern "intrinsic" func __sys_connect(int fd, string host, int port, int family) int
extern "intrinsic" func __sys_write_string(int fd, string data) int
extern "intrinsic" func __sys_close(int fd) int
extern "intrinsic" func __sys_set_deadline_ms(int fd, int read_timeout_ms, int write_timeout_ms) int
func runtime_env_get(string name, string default_value) string {
    default_value
}


func runtime_file_exists(string path) bool {
    true
}


func runtime_run_command_output(string command) string {
    ""
}


func trim(string s) string {
    int i = 0
    while i < len(s) && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = len(s) - 1
    while j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    return __host_slice(s, i, j + 1)
}


func shell_escape(string value) string {
    string output = "'"
    int index = 0
    while index < len(value) {
        string character = __host_slice(value, index, index + 1)
        if character == "'" {
            output = output + "'\"'\"'"
        } else {
            output = output + character
        }
        index = index + 1
    }
    output + "'"
}


func read_user_line() string {
    trim(__sys_read_string(0, 4096))
}


func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    string output = ""
    int current = value
    while current > 0 {
        int digit = current - (current / 10) * 10
        output = __host_slice("0123456789", digit, digit + 1) + output
        current = current / 10
    }
    output
}


func parse_positive_int(string text, int fallback) int {
    if len(text) == 0 {
        return fallback
    }
    int value = 0
    int index = 0
    while index < len(text) {
        string digit = __host_slice(text, index, index + 1)
        int number = -1
        if digit == "0" { number = 0 }
        if digit == "1" { number = 1 }
        if digit == "2" { number = 2 }
        if digit == "3" { number = 3 }
        if digit == "4" { number = 4 }
        if digit == "5" { number = 5 }
        if digit == "6" { number = 6 }
        if digit == "7" { number = 7 }
        if digit == "8" { number = 8 }
        if digit == "9" { number = 9 }
        if number < 0 {
            return fallback
        }
        value = value * 10 + number
        index = index + 1
    }
    if value <= 0 {
        return fallback
    }
    value
}


func index_of(string text, string needle) int {
    if len(needle) == 0 || len(needle) > len(text) {
        return -1
    }
    int index = 0
    while index <= len(text) - len(needle) {
        int inner = 0
        while inner < len(needle) &&
              __host_slice(text, index + inner, index + inner + 1) ==
              __host_slice(needle, inner, inner + 1) {
            inner = inner + 1
        }
        if inner == len(needle) {
            return index
        }
        index = index + 1
    }
    -1
}


func starts_with(string text, string prefix) bool {
    if len(prefix) > len(text) {
        return false
    }
    __host_slice(text, 0, len(prefix)) == prefix
}


func http_request(string host, int port, string method, string path, string body, string extra_headers) string {
    int fd = __sys_socket(2, 1, 0)
    if fd < 0 {
        print("[HTTP] Socket creation failed\n")
        return ""
    }
    print("[HTTP] Socket created: fd=" + int_to_string(fd) + "\n")
    if __sys_connect(fd, host, port, 2) < 0 {
        print("[HTTP] Connection failed to " + host + ":" + int_to_string(port) + "\n")
        _ = __sys_close(fd)
        return ""
    }
    print("[HTTP] Connected to " + host + ":" + int_to_string(port) + "\n")
    _ = __sys_set_deadline_ms(fd, 600000, 30000)
    string request = method + " " + path + " HTTP/1.1\r\n" +
        "Host: " + host + "\r\n" +
        "Connection: close\r\n" +
        "Content-Length: " + int_to_string(len(body)) + "\r\n" +
        extra_headers + "\r\n" + body
    int offset = 0
    while offset < len(request) {
        string remaining = __host_slice(request, offset, len(request))
        int written = __sys_write_string(fd, remaining)
        if written <= 0 {
            _ = __sys_close(fd)
            return ""
        }
        offset = offset + written
    }
    string response = ""
    string chunk = __sys_read_string(fd, 65536)
    while len(chunk) > 0 {
        response = response + chunk
        chunk = __sys_read_string(fd, 65536)
    }
    _ = __sys_close(fd)
    response
}


func http_body(string response) string {
    if !starts_with(response, "HTTP/1.1 200") {
        return ""
    }
    int separator = index_of(response, "\r\n\r\n")
    if separator < 0 {
        return ""
    }
    __host_slice(response, separator + 4, len(response))
}


func backend_ready(string host, int port) bool {
    string response = http_request(host, port, "GET", "/health", "", "")
    string body = http_body(response)
    index_of(body, "\"status\":\"ok\"") >= 0 &&
        index_of(body, "\"backend\":\"neurx-s-cpu\"") >= 0
}


func stop_owned_backend(bool owned, string pid_file) int {
    if !owned {
        return 0
    }
    _ = runtime_run_command_output(
        "if test -s " + shell_escape(pid_file) +
        "; then kill \"$(cat " + shell_escape(pid_file) +
        ")\" 2>/dev/null || true; fi"
    )
    0
}


func ends_with(string text, string suffix) bool {
    int text_len = len(text)
    int suffix_len = len(suffix)
    if suffix_len > text_len {
        return false
    }
    int offset = text_len - suffix_len
    int i = 0
    while i < suffix_len {
        if text[offset + i] != suffix[i] {
            return false
        }
        i = i + 1
    }
    return true
}


func main() {
    string root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/neurx")
    string model = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain")
    string device_type = trim(runtime_env_get("NEURX_INFER_DEVICE", "cpu"))
    string backend = runtime_env_get(
        "NEURX_S_INFERENCE_BACKEND",
        root + "/artifacts/build/production_s_inference/cpu_backend.ir"
    )
    string host = runtime_env_get("NEURX_S_HOST", "127.0.0.1")
    string port = runtime_env_get("NEURX_S_PORT", "18083")
    string threads = runtime_env_get("NEURX_CPU_THREADS", "6")
    string maximum = runtime_env_get("NEURX_CHAT_MAX_NEW_TOKENS", "128")
    string system_prompt = runtime_env_get(
        "NEURX_CHAT_SYSTEM_PROMPT",
        "You are a helpful assistant."
    )
    int port_number = parse_positive_int(port, 18083)
    string prefix = "/tmp/neurx_s_inference_" + port
    string pid_file = prefix + ".pid"
    string ready_file = prefix + "_ready"
    string log_file = prefix + ".log"
    if !runtime_file_exists(model + "/model.safetensors") {
        print("error: model not found: " + model + "/model.safetensors\n")
        return 1
    }
    if !runtime_file_exists(backend) {
        print("error: native inference backend not found: " + backend + "\n")
        return 1
    }
    bool owned_backend = false
    if !backend_ready(host, port_number) {
        string runner = runtime_env_get("NEURX_S_RUNNER_BIN", root + "/artifacts/build/s_runner/s_ir_runner")
        string backend_cmd = backend
        if ends_with(backend, ".ir") {
            backend_cmd = runner + " " + shell_escape(backend)
        }
        string launch =
            "rm -f " + shell_escape(ready_file) + "; " +
            "NEURX_MODEL_DIR=" + shell_escape(model) +
            " NEURX_CPU_THREADS=" + shell_escape(threads) +
            " NEURX_S_HOST=" + shell_escape(host) +
            " NEURX_S_PORT=" + shell_escape(port) +
            " NEURX_S_READY_FILE=" + shell_escape(ready_file) +
            " nohup " + backend_cmd +
            " >" + shell_escape(log_file) + " 2>&1 < /dev/null &"
        _ = runtime_run_command_output(launch)
        int attempts = 0
        int max_attempts = 200
        print("[DEBUG] Starting health check attempts for backend at " + host + ":" + int_to_string(port_number) + "\n")
        while attempts < max_attempts && !backend_ready(host, port_number) {
            attempts = attempts + 1
            if attempts == 1 {
                string debug_response = http_request(host, port_number, "GET", "/health", "", "")
                print("[DEBUG] First HTTP response length: " + int_to_string(len(debug_response)) + "\n")
                if len(debug_response) > 0 {
                    print("[DEBUG] Response preview: " + __host_slice(debug_response, 0, 200) + "\n")
                }
            }
            if attempts < 10 {
                runtime_run_command_output("sleep 0.05")
            }
        }
        print("[DEBUG] Health check completed after " + int_to_string(attempts) + " attempts\n")
        if !backend_ready(host, port_number) {
            print("error: NeurX S backend failed to start; log: " + log_file + "\n")
            return 1
        }
        owned_backend = true
    }
    string device_requested = device_type
    string actual_backend = "CPU (real S engine)"
    string cuda_status = ""
    if device_requested == "cuda" || device_requested == "gpu" {
        cuda_status = "CPU-backed real S inference path"
        actual_backend = "CPU (real S engine)"
    }
    if device_requested == "npu" {
        cuda_status = "CPU-backed real S inference path"
        actual_backend = "CPU (real S engine)"
    }
    print("NeurX production S inference engine\n")
    print("Model: " + model + "/model.safetensors\n")
    print("Actual Backend: " + actual_backend + ", threads=" + threads + ", persistent KV-cache\n")
    print("Requested Device: " + device_requested + "\n")
    if len(cuda_status) > 0 {
        print("Status: " + cuda_status + "\n")
    }
    print("Python: disabled\n")
    print("Type /exit to quit, /reset to clear history.\n\n")
    string history = "<|im_start|>system\n" + system_prompt + "<|im_end|>\n"
    while true {
        print("You: ")
        string user_text = read_user_line()
        if len(user_text) == 0 || user_text == "/exit" || user_text == "exit" || user_text == "quit" {
            _ = stop_owned_backend(owned_backend, pid_file)
            return 0
        }
        if user_text == "/reset" {
            history = "<|im_start|>system\n" + system_prompt + "<|im_end|>\n"
            _ = http_request(host, port_number, "POST", "/reset", "", "")
            print("History and KV-cache cleared.\n\n")
            continue
        }
        string prompt = history +
            "<|im_start|>user\n" + user_text + "<|im_end|>\n" +
            "<|im_start|>assistant\n"
        string raw_response = http_request(
            host,
            port_number,
            "POST",
            "/v1/generate",
            prompt,
            "X-Max-New-Tokens: " + maximum + "\r\n"
        )
        string response = http_body(raw_response)
        if len(response) == 0 {
            print("error: native inference request failed; log: " + log_file + "\n\n")
            continue
        }
        if len(trim(response)) == 0 {
            print("error: model returned an empty response\n\n")
            continue
        }
        print("Assistant: " + response + "\n\n")
        history = prompt + response + "<|im_end|>\n"
    }
}

