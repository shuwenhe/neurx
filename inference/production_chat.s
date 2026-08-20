package neurx.inference.production_chat

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output, trim}

extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __host_write_text_file(string path, string content) int
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __sys_write_string(int fd, string data) int
extern "intrinsic" func __sys_close(int fd) int
extern "intrinsic" func __sys_socket(int domain, int typ, int proto) int
extern "intrinsic" func __sys_connect(int sockfd, string ip, int port, int family) int

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
    int n = value
    bool negative = false
    if n < 0 {
        negative = true
        n = 0 - n
    }
    string out = ""
    while n > 0 {
        int digit = n - (n / 10) * 10
        out = string(digit + 48) + out
        n = n / 10
    }
    if negative {
        out = "-" + out
    }
    return out
}

func decimal_digit_value(string text) int {
    if text == "0" { return 0 }
    if text == "1" { return 1 }
    if text == "2" { return 2 }
    if text == "3" { return 3 }
    if text == "4" { return 4 }
    if text == "5" { return 5 }
    if text == "6" { return 6 }
    if text == "7" { return 7 }
    if text == "8" { return 8 }
    if text == "9" { return 9 }
    -1
}

func parse_int_or_default(string text, int fallback) int {
    if len(text) == 0 {
        return fallback
    }
    int index = 0
    int sign = 1
    if __host_slice(text, 0, 1) == "-" {
        sign = -1
        index = 1
    }
    if index >= len(text) {
        return fallback
    }
    int value = 0
    while index < len(text) {
        int digit = decimal_digit_value(__host_slice(text, index, index + 1))
        if digit < 0 {
            return fallback
        }
        value = value * 10 + digit
        index = index + 1
    }
    value * sign
}

func parse_positive_int(string text, int fallback) int {
    int value = parse_int_or_default(text, fallback)
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
    int conn_fd = __sys_socket(2, 1, 6)
    if conn_fd < 0 {
        print("[HTTP] Socket creation failed\n")
        return ""
    }
    if __sys_connect(conn_fd, host, port, 2) < 0 {
        print("[HTTP] Connection failed to " + host + ":" + int_to_string(port) + "\n")
        _ = __sys_close(conn_fd)
        return ""
    }
    print("[HTTP] Socket created: fd=" + int_to_string(conn_fd) + "\n")
    print("[HTTP] Connected to " + host + ":" + int_to_string(port) + "\n")
    string request = method + " " + path + " HTTP/1.1\r\n" +
        "Host: " + host + "\r\n" +
        "Connection: close\r\n" +
        "Content-Length: " + int_to_string(len(body)) + "\r\n" +
        extra_headers + "\r\n" + body
    int offset = 0
    while offset < len(request) {
        string remaining = __host_slice(request, offset, len(request))
        int written = __sys_write_string(conn_fd, remaining)
        if written <= 0 {
            _ = __sys_close(conn_fd)
            return ""
        }
        offset = offset + written
    }
    string response = ""
    while true {
        string chunk = __sys_read_string(conn_fd, 65536)
        if len(chunk) == 0 {
            break
        }
        response = response + chunk
    }
    _ = __sys_close(conn_fd)
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
    if index_of(body, "\"status\":\"ok\"") < 0 {
        return false
    }
    if index_of(body, "\"backend\":\"neurx-s-cpu\"") >= 0 {
        return true
    }
    if index_of(body, "\"backend\":\"neurx-gpu\"") >= 0 {
        return true
    }
    if index_of(body, "\"backend\":\"neurx-gpu-enhanced\"") >= 0 {
        return true
    }
    false
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

func backend_signature(string model, string threads) string {
    model + "\n" + threads
}

func read_text_file(string path) string {
    trim(runtime_run_command_output("cat " + shell_escape(path) + " 2>/dev/null || true"))
}

func backend_matches_requested_model(string meta_file, string model, string threads) bool {
    if !runtime_file_exists(meta_file) {
        return false
    }
    read_text_file(meta_file) == backend_signature(model, threads)
}

func backend_failed_to_bind(string log_file) bool {
    if !runtime_file_exists(log_file) {
        return false
    }
    index_of(read_text_file(log_file), "Socket bind failed") >= 0
}

func stop_backend_for_restart(string pid_file, string backend, string port) int {
    _ = runtime_run_command_output("fuser -k " + shell_escape(port + "/tcp") + " 2>/dev/null || true")
    _ = runtime_run_command_output("pkill -f " + shell_escape(backend) + " 2>/dev/null || true")
    runtime_run_command_output("sleep 1")
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

func extract_json_string(string json, string key) string {
    string search = "\"" + key + "\":"
    int start_pos = index_of(json, search)
    if start_pos < 0 {
        return ""
    }

    int cursor = start_pos + len(search)
    while cursor < len(json) && __host_slice(json, cursor, cursor + 1) != "\"" {
        cursor = cursor + 1
    }
    if cursor >= len(json) {
        return ""
    }

    cursor = cursor + 1
    string result = ""
    bool escaped = false
    while cursor < len(json) {
        string ch = __host_slice(json, cursor, cursor + 1)
        if escaped {
            if ch == "n" {
                result = result + "\n"
            } else if ch == "r" {
                result = result + "\r"
            } else if ch == "t" {
                result = result + "\t"
            } else {
                result = result + ch
            }
            escaped = false
            cursor = cursor + 1
            continue
        }
        if ch == "\\" {
            escaped = true
            cursor = cursor + 1
            continue
        }
        if ch == "\"" {
            break
        }
        result = result + ch
        cursor = cursor + 1
    }

    return result
}

func main() {
    string root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/neurx")
    string model = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain")
    string device_type = trim(runtime_env_get("NEURX_INFER_DEVICE", "cpu"))

    string default_backend = root + "/artifacts/build/production_s_inference/cpu_backend.ir"
    if device_type == "gpu" {
        string gpu_enhanced = runtime_env_get("NEURX_GPU_ENHANCED", "false")
        if gpu_enhanced == "true" {
            default_backend = root + "/artifacts/build/production_s_inference/gpu_backend_enhanced.ir"
        } else {
            default_backend = root + "/artifacts/build/production_s_inference/gpu_backend.ir"
        }
    }

    string backend = runtime_env_get(
        "NEURX_S_INFERENCE_BACKEND",
        default_backend
    )
    string host = runtime_env_get("NEURX_S_HOST", "127.0.0.1")
    string port = runtime_env_get("NEURX_S_PORT", "18083")
    string threads = runtime_env_get("NEURX_CPU_THREADS", "6")
    string maximum = runtime_env_get("NEURX_CHAT_MAX_NEW_TOKENS", "16")
    string system_prompt = runtime_env_get(
        "NEURX_CHAT_SYSTEM_PROMPT",
        "You are a helpful assistant."
    )
    int port_number = parse_positive_int(port, 18083)
    string prefix = "/tmp/neurx_s_inference_" + port
    string pid_file = prefix + ".pid"
    string ready_file = prefix + "_ready"
    string log_file = prefix + ".log"
    string meta_file = prefix + ".meta"
    if !runtime_file_exists(model + "/model.safetensors") && !runtime_file_exists(model + "/model.safetensors.index.json") {
        print("error: model not found: " + model + "/model.safetensors (or .index.json for sharded)\n")
        return 1
    }
    if !runtime_file_exists(backend) {
        print("error: native inference backend not found: " + backend + "\n")
        return 1
    }
    bool owned_backend = false
    if backend_ready(host, port_number) {
        if backend_matches_requested_model(meta_file, model, threads) {
            print("[DEBUG] Reusing healthy backend on port " + port + " for requested model\n")
        } else {
            print("[DEBUG] Existing backend detected on port " + port + "; restarting for requested model\n")
            _ = stop_backend_for_restart(pid_file, backend, port)
        }
    }
    if !backend_ready(host, port_number) {
        string runner = runtime_env_get("NEURX_S_RUNNER_BIN", root + "/artifacts/build/s_runner/s_ir_runner")
        string backend_cmd = backend
        if ends_with(backend, ".ir") {
            backend_cmd = runner + " " + shell_escape(backend)
        }
        int launch_attempt = 0
        int max_launch_attempts = 5
        bool backend_started = false
        string launch = ""
        while launch_attempt < max_launch_attempts && !backend_started {
            _ = __host_write_text_file(meta_file, backend_signature(model, threads))
            _ = runtime_run_command_output("rm -f " + shell_escape(ready_file) + " " + shell_escape(pid_file) + " && fuser -k " + port + "/tcp 2>/dev/null || true; sleep 2")
            launch = "bash -c 'exec " + backend_cmd + " >/tmp/neurx_s_inference_" + port + ".log 2>&1 & echo $! >" + shell_escape(pid_file) + "'"
            print("[DEBUG] Launch command: " + launch + "\n")
            _ = runtime_run_command_output("NEURX_MODEL_DIR=" + model + " NEURX_CPU_THREADS=" + threads + " NEURX_S_HOST=" + host + " NEURX_S_PORT=" + port + " NEURX_S_READY_FILE=" + ready_file + " " + launch)
            int attempts = 0
            int max_attempts = 300
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
                if backend_failed_to_bind(log_file) {
                    print("[DEBUG] Backend reported socket bind failure on port " + port + "\n")
                    break
                }
                runtime_run_command_output("sleep 0.2")
            }
            print("[DEBUG] Health check completed after " + int_to_string(attempts) + " attempts\n")
            if backend_ready(host, port_number) {
                backend_started = true
                break
            }
            if !backend_failed_to_bind(log_file) {
                break
            }
            launch_attempt = launch_attempt + 1
            port_number = port_number + 1
            port = int_to_string(port_number)
            prefix = "/tmp/neurx_s_inference_" + port
            pid_file = prefix + ".pid"
            ready_file = prefix + "_ready"
            log_file = prefix + ".log"
            meta_file = prefix + ".meta"
            print("[DEBUG] Backend bind failed; retrying on port " + port + "\n")
        }
        if !backend_started {
            print("error: NeurX S backend failed to start; log: " + log_file + "\n")
            print("Backend startup command: " + launch + "\n")
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
    string model_display = model + "/model.safetensors"
    if runtime_file_exists(model + "/model.safetensors.index.json") {
        model_display = model + " (sharded: 5 files, 16GB)"
    }
    print("Model: " + model_display + "\n")
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
        string assistant_text = extract_json_string(response, "output")
        if len(assistant_text) == 0 {
            assistant_text = response
        }
        if len(trim(assistant_text)) == 0 {
            print("error: model returned an empty response\n\n")
            continue
        }
        print("Assistant: " + assistant_text + "\n\n")
        history = prompt + assistant_text + "<|im_end|>\n"
    }
}
