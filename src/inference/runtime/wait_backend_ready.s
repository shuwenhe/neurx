package neurx.inference.native
extern func runtime_env_get(string key, string default_value) string
extern "intrinsic" func __sys_socket(int domain, int type, int protocol) int
extern "intrinsic" func __sys_connect(int sockfd, string ip, int port, int family) int
extern "intrinsic" func __sys_close(int fd) int
func parse_int_or_default(string s, int default_val) int {
    if len(s) == 0 {
        return default_val
    }
    int result = 0
    int i = 0
    for i < len(s) {
        int ch = s[i]
        if ch >= 48 && ch <= 57 {
            result = result * 10 + (ch - 48)
        } else {
            return result
        }
        i = i + 1
    }
    result
}

func format_int(int value) string {
    if value == 0 { return "0" }
    if value == 1 { return "1" }
    if value == 2 { return "2" }
    if value == 3 { return "3" }
    if value == 4 { return "4" }
    if value == 5 { return "5" }
    if value == 6 { return "6" }
    if value == 7 { return "7" }
    if value == 8 { return "8" }
    if value == 9 { return "9" }
    if value == 10 { return "10" }
    if value == 20 { return "20" }
    if value == 30 { return "30" }
    if value == 40 { return "40" }
    if value == 50 { return "50" }
    if value == 100 { return "100" }
    if value == 150 { return "150" }
    return ""
}

func main() {
    string host = runtime_env_get("NEURX_S_HOST", "127.0.0.1")
    int port = parse_int_or_default(runtime_env_get("NEURX_S_PORT", "18083"), 18083)
    int max_attempts = 150
    int attempt = 0
    bool backend_ready = false
    print("[HealthCheck] Waiting for backend at " + host + ":" + runtime_env_get("NEURX_S_PORT", "18083") + "\n")
    for attempt < max_attempts && !backend_ready {
        attempt = attempt + 1
        int sock = __sys_socket(2, 1, 6)
        if sock < 0 {
            int sleep_ms = 0
            for sleep_ms < 100000 { sleep_ms = sleep_ms + 1 }
            continue
        }
        int connect_result = __sys_connect(sock, host, port, 2)
        if connect_result == 0 {
            print("[HealthCheck] ✅ Backend ready on attempt " + format_int(attempt) + "\n")
            backend_ready = true
            _ = __sys_close(sock)
            break
        }
        _ = __sys_close(sock)
        int sleep_ms = 0
        for sleep_ms < 100000 { sleep_ms = sleep_ms + 1 }
        if attempt == 10 || attempt == 20 || attempt == 30 || attempt == 50 || attempt == 100 {
            print("[HealthCheck] Checking... attempt " + format_int(attempt) + "\n")
        }
    }
    if backend_ready {
        print("[HealthCheck] Success! Backend ready\n")
    } else {
        print("[HealthCheck] Timeout after attempts\n")
    }
}
