package neurx.request

func starts_with(string str, string prefix) bool {
    int i = 0
    for i < len(prefix) {
        if i >= len(str) { return false }
        if str[i] != prefix[i] { return false }
        i = i + 1
    }
    return true
}

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

func extract_json_string_value(string json_body, string key) string {
    int key_start = 0
    int i = 0

    for i < len(json_body) - len(key) {
        bool key_found = false

        if json_body[i] == 34 {
            int j = 0
            bool match = true

            for j < len(key) && i + 1 + j < len(json_body) {
                if key[j] != json_body[i + 1 + j] {
                    match = false
                    break
                }
                j = j + 1
            }

            if match && i + 1 + len(key) < len(json_body) && json_body[i + 1 + len(key)] == 34 {
                int colon_pos = i + 2 + len(key)

                for colon_pos < len(json_body) && json_body[colon_pos] == 32 {
                    colon_pos = colon_pos + 1
                }

                if colon_pos < len(json_body) && json_body[colon_pos] == 58 {
                    colon_pos = colon_pos + 1

                    for colon_pos < len(json_body) && json_body[colon_pos] == 32 {
                        colon_pos = colon_pos + 1
                    }

                    if colon_pos < len(json_body) && json_body[colon_pos] == 34 {
                        int value_start = colon_pos + 1
                        int value_end = value_start

                        for value_end < len(json_body) && json_body[value_end] != 34 {
                            value_end = value_end + 1
                        }

                        string value = ""
                        int idx = value_start

                        for idx < value_end {
                            value = value + json_body[idx]
                            idx = idx + 1
                        }

                        return value
                    }
                }
            }
        }

        i = i + 1
    }

    return ""
}

func extract_json_number_value(string json_body, string key) string {
    int key_start = 0
    int i = 0

    for i < len(json_body) - len(key) {
        if json_body[i] == 34 {
            int j = 0
            bool match = true

            for j < len(key) && i + 1 + j < len(json_body) {
                if key[j] != json_body[i + 1 + j] {
                    match = false
                    break
                }
                j = j + 1
            }

            if match && i + 1 + len(key) < len(json_body) && json_body[i + 1 + len(key)] == 34 {
                int colon_pos = i + 2 + len(key)

                for colon_pos < len(json_body) && json_body[colon_pos] == 32 {
                    colon_pos = colon_pos + 1
                }

                if colon_pos < len(json_body) && json_body[colon_pos] == 58 {
                    colon_pos = colon_pos + 1

                    for colon_pos < len(json_body) && json_body[colon_pos] == 32 {
                        colon_pos = colon_pos + 1
                    }

                    if colon_pos < len(json_body) {
                        int ch = json_body[colon_pos]

                        bool is_digit = false
                        bool is_minus = false

                        if ch >= 48 && ch <= 57 {
                            is_digit = true
                        }

                        if ch == 45 {
                            is_minus = true
                        }

                        if is_digit {
                            int num_end = colon_pos

                            for num_end < len(json_body) {
                                int digit_ch = json_body[num_end]

                                if (digit_ch >= 48 && digit_ch <= 57) || digit_ch == 45 || digit_ch == 46 {
                                    num_end = num_end + 1
                                }
                                else {
                                    break
                                }
                            }

                            string value = ""
                            int idx = colon_pos

                            for idx < num_end {
                                value = value + json_body[idx]
                                idx = idx + 1
                            }

                            return value
                        }

                        if is_minus {
                            int num_end = colon_pos

                            for num_end < len(json_body) {
                                int digit_ch = json_body[num_end]

                                if (digit_ch >= 48 && digit_ch <= 57) || digit_ch == 45 || digit_ch == 46 {
                                    num_end = num_end + 1
                                }
                                else {
                                    break
                                }
                            }

                            string value = ""
                            int idx = colon_pos

                            for idx < num_end {
                                value = value + json_body[idx]
                                idx = idx + 1
                            }

                            return value
                        }
                    }
                }
            }
        }

        i = i + 1
    }

    return ""
}

func validate_json_structure(string json_body) bool {
    if len(json_body) < 2 { return false }

    int brace_count = 0
    int bracket_count = 0
    bool in_string = false
    int i = 0

    for i < len(json_body) {
        int ch = json_body[i]

        if ch == 34 {
            if i == 0 || json_body[i - 1] != 92 {
                in_string = !in_string
            }
        }

        if !in_string {
            if ch == 123 {
                brace_count = brace_count + 1
            }
            else if ch == 125 {
                brace_count = brace_count - 1
            }
            else if ch == 91 {
                bracket_count = bracket_count + 1
            }
            else if ch == 93 {
                bracket_count = bracket_count - 1
            }
        }

        i = i + 1
    }

    return brace_count == 0 && bracket_count == 0
}

func validate_model_param(string model) bool {
    if len(model) == 0 { return false }

    if starts_with(model, "Qwen") {
        return true
    }

    if starts_with(model, "gpt") {
        return true
    }

    if starts_with(model, "claude") {
        return true
    }

    return false
}

func validate_temperature(string temp_str) bool {
    if len(temp_str) == 0 {
        return false
    }

    int i = 0
    bool has_digit = false

    for i < len(temp_str) {
        int ch = temp_str[i]

        if ch >= 48 && ch <= 57 {
            has_digit = true
        }

        i = i + 1
    }

    return has_digit
}

func format_error_response(int status, string error_msg) string {
    string body = "{\"error\":\"" + error_msg + "\"}"

    string response = "HTTP/1.1 "
    response = response + int_to_string(status)
    response = response + " Error\r\n"
    response = response + "Content-Type: application/json\r\n"
    response = response + "Content-Length: " + int_to_string(len(body)) + "\r\n"
    response = response + "Access-Control-Allow-Origin: *\r\n"
    response = response + "Connection: close\r\n\r\n"
    response = response + body

    return response
}

func main() {
    print("✅ pure S 请求validationmodulealready编译\n")
}
