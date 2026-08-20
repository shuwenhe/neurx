package neurx.inference.chat_client

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, trim}

extern "intrinsic" func __sys_socket(int domain, int type, int protocol) int

extern "intrinsic" func __sys_connect(int sockfd, string ip, int port, int family) int

extern "intrinsic" func __sys_read_string(int fd, int count) string

extern "intrinsic" func __sys_write_string(int fd, string data) int

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

    while n > 0 {

        int digit = n - (n / 10) * 10

        out = string(digit + 48) + out

        n = n / 10

    }

    if negative { out = "-" + out }

    return out

}

func string_to_int(string text) int {

    string trimmed = trim(text)

    if len(trimmed) == 0 { return 0 }

    bool negative = false

    int start = 0

    if __host_slice(trimmed, 0, 1) == "-" {

        negative = true

        start = 1

    }

    int result = 0

    int i = start

    while i < len(trimmed) {

        string ch = __host_slice(trimmed, i, i + 1)

        int digit = -1

        if ch == "0" { digit = 0 }

        else if ch == "1" { digit = 1 }

        else if ch == "2" { digit = 2 }

        else if ch == "3" { digit = 3 }

        else if ch == "4" { digit = 4 }

        else if ch == "5" { digit = 5 }

        else if ch == "6" { digit = 6 }

        else if ch == "7" { digit = 7 }

        else if ch == "8" { digit = 8 }

        else if ch == "9" { digit = 9 }

        if digit < 0 { break }

        result = result * 10 + digit

        i = i + 1

    }

    if negative { result = 0 - result }

    return result

}

func read_line() string {

    string result = __sys_read_string(0, 4096)

    trim(result)

}

func extract_json_string(string json, string key) string {

    string search = "\"" + key + "\":"

    int pos = 0

    int i = 0

    while i < len(json) {

        bool match = true

        int j = 0

        while j < len(search) && i + j < len(json) {

            string ch = __host_slice(json, i + j, i + j + 1)

            string search_ch = __host_slice(search, j, j + 1)

            if ch != search_ch {

                match = false

                break

            }

            j = j + 1

        }

        if match && i + len(search) < len(json) {

            pos = i + len(search)

            i = len(json)

            break

        }

        i = i + 1

    }

    if pos == 0 { return "" }

    int start = pos

    while start < len(json) {

        string ch = __host_slice(json, start, start + 1)

        if ch == "\"" { break }

        if ch != " " && ch != "\n" && ch != "\r" && ch != "\t" { break }

        start = start + 1

    }

    if start >= len(json) || __host_slice(json, start, start + 1) != "\"" {

        return ""

    }

    int end = start + 1

    bool escaped = false

    while end < len(json) {

        string ch = __host_slice(json, end, end + 1)

        if ch == "\\" && !escaped {

            escaped = true

        } else if ch == "\"" && !escaped {

            break

        } else {

            escaped = false

        }

        end = end + 1

    }

    string result = __host_slice(json, start + 1, end)

    return result

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

func starts_with(string text, string prefix) bool {

    if len(prefix) > len(text) { return false }

    int i = 0

    while i < len(prefix) {

        if __host_slice(text, i, i + 1) != __host_slice(prefix, i, i + 1) {

            return false

        }

        i = i + 1

    }

    return true

}

func index_of(string text, string needle) int {

    if len(needle) > len(text) { return -1 }

    if len(needle) == 0 { return 0 }

    int i = 0

    while i <= len(text) - len(needle) {

        bool match = true

        int j = 0

        while j < len(needle) {

            if __host_slice(text, i + j, i + j + 1) != __host_slice(needle, j, j + 1) {

                match = false

                break

            }

            j = j + 1

        }

        if match { return i }

        i = i + 1

    }

    return -1

}

func main() {

    string host = runtime_env_get("NEURX_S_HOST", "127.0.0.1")

    string port_str = runtime_env_get("NEURX_S_PORT", "18083")

    int port = string_to_int(port_str)

    string model = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain")

    string max_tokens = runtime_env_get("NEURX_CHAT_MAX_NEW_TOKENS", "16")

    string system_prompt = runtime_env_get(

        "NEURX_CHAT_SYSTEM_PROMPT",

        "You are a helpful assistant."

    )

    print("\n")

    print("╔════════════════════════════════════════════════════════════════╗\n")

    print("║          NeurX GPU-Accelerated Chat Client (Pure S)            ║\n")

    print("╚════════════════════════════════════════════════════════════════╝\n")

    print("\n")

    print("Server: " + host + ":" + port_str + "\n")

    print("Model: " + model + "\n")

    print("Max Tokens: " + max_tokens + "\n")

    print("Type: /exit to quit, /reset to clear history\n")

    print("\n")

    print("🔍 Checking backend health...\n")

    string health_response = ""

    int health_check_retries = 0

    int max_health_retries = 20

    while len(health_response) == 0 && health_check_retries < max_health_retries {

        health_response = http_request(host, port, "GET", "/health", "", "")

        if len(health_response) == 0 {

            health_check_retries = health_check_retries + 1

            if health_check_retries < max_health_retries {

                print("   [Retry " + int_to_string(health_check_retries) + "/" + int_to_string(max_health_retries) + "] Backend not ready yet, retrying...\n")

                int wait_ms = 3000000

                while wait_ms > 0 { wait_ms = wait_ms - 1 }

            }

        }

    }

    if len(health_response) == 0 {

        print("❌ ERROR: Backend not responding after " + int_to_string(max_health_retries) + " retries\n")

        print("   Check: ps aux | grep s_ir_runner\n")

        print("   Logs: tail -50 /tmp/neurx_gpu_backend.log\n")

        return

    }

    print("✅ Backend is ready\n\n")

    string history = "<|im_start|>system\n" + system_prompt + "<|im_end|>\n"

    int turn = 0

    int empty_attempts = 0

    while true {

        print("You: ")

        string user_input = read_line()

        if len(user_input) == 0 {

            empty_attempts = empty_attempts + 1

            if empty_attempts >= 3 {

                print("\n👋 Goodbye!\n")

                return

            }

            continue

        }

        empty_attempts = 0

        if user_input == "/exit" || user_input == "exit" || user_input == "quit" {

            print("\n👋 Goodbye!\n")

            return

        }

        if user_input == "/reset" {

            history = "<|im_start|>system\n" + system_prompt + "<|im_end|>\n"

            _ = http_request(host, port, "POST", "/reset", "", "")

            print("✅ History cleared\n\n")

            continue

        }

        turn = turn + 1

        string prompt = history +

            "<|im_start|>user\n" + user_input + "<|im_end|>\n" +

            "<|im_start|>assistant\n"

        print("⏳ Generating response...\n")

        string request_body = "{\"action\":\"generate\",\"prompt\":\""+ prompt + "\"}"

        string raw_response = http_request(

            host,

            port,

            "POST",

            "/v1/generate",

            request_body,

            "Content-Type: application/json\r\nX-Max-New-Tokens: " + max_tokens + "\r\n"

        )

        string response = http_body(raw_response)

        if len(response) == 0 {

            print("❌ ERROR: Backend request failed\n\n")

            continue

        }

        string assistant_text = extract_json_string(response, "output")

        if len(assistant_text) == 0 {

            assistant_text = response

        }

        if len(trim(assistant_text)) == 0 {

            print("⚠️  Model returned empty response\n\n")

            continue

        }

        print("\nAssistant: " + assistant_text + "\n\n")

        history = prompt + assistant_text + "<|im_end|>\n"

    }

}
