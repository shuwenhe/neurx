package neurx.api.s_logger
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

func format_log_entry(string log_level, string method, string path, int status) string {
    string timestamp = "[2026-08-16 21:00:00]"
    string log_entry = timestamp + " " + log_level + " " + method + " " + path + " " + int_to_string(status)
    return log_entry
}

func log_request(string method, string path) string {
    return format_log_entry("INFO", method, path, 0)
}

func log_response(string method, string path, int status) string {
    return format_log_entry("INFO", method, path, status)
}

func log_error(string error_msg) string {
    return "[2026-08-16 21:00:00] ERROR " + error_msg
}

func format_metrics(int total_requests, int successful_requests, int failed_requests) string {
    string metrics = "{"
    metrics = metrics + "\"total\":" + int_to_string(total_requests)
    metrics = metrics + ",\"success\":" + int_to_string(successful_requests)
    metrics = metrics + ",\"failed\":" + int_to_string(failed_requests)
    metrics = metrics + "}"
    return metrics
}

func main() {
    print("✅ pure S 日志系统already编译\n")
    string log1 = log_request("GET", "/health")
    print(log1)
    print("\n")
    string log2 = log_response("GET", "/health", 200)
    print(log2)
    print("\n")
    string metrics = format_metrics(1000, 950, 50)
    print(metrics)
    print("\n")
}
