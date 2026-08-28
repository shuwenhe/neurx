package neurx.request
func char_to_string(int ch) string {
    if ch == 32 { return " " }
    else if ch == 34 { return "\"" }
    else if ch == 43 { return "+" }
    else if ch == 44 { return "," }
    else if ch == 45 { return "-" }
    else if ch == 46 { return "." }
    else if ch == 47 { return "/" }
    else if ch >= 48 && ch <= 57 {
        if ch == 48 { return "0" }
        else if ch == 49 { return "1" }
        else if ch == 50 { return "2" }
        else if ch == 51 { return "3" }
        else if ch == 52 { return "4" }
        else if ch == 53 { return "5" }
        else if ch == 54 { return "6" }
        else if ch == 55 { return "7" }
        else if ch == 56 { return "8" }
        else if ch == 57 { return "9" }
    }
    else if ch >= 65 && ch <= 90 {
        if ch == 65 { return "A" }
        else if ch == 66 { return "B" }
        else if ch == 67 { return "C" }
        else if ch == 68 { return "D" }
        else if ch == 69 { return "E" }
        else if ch == 70 { return "F" }
        else if ch == 71 { return "G" }
        else if ch == 72 { return "H" }
        else if ch == 73 { return "I" }
        else if ch == 74 { return "J" }
        else if ch == 75 { return "K" }
        else if ch == 76 { return "L" }
        else if ch == 77 { return "M" }
        else if ch == 78 { return "N" }
        else if ch == 79 { return "O" }
        else if ch == 80 { return "P" }
        else if ch == 81 { return "Q" }
        else if ch == 82 { return "R" }
        else if ch == 83 { return "S" }
        else if ch == 84 { return "T" }
        else if ch == 85 { return "U" }
        else if ch == 86 { return "V" }
        else if ch == 87 { return "W" }
        else if ch == 88 { return "X" }
        else if ch == 89 { return "Y" }
        else if ch == 90 { return "Z" }
    }
    else if ch >= 97 && ch <= 122 {
        if ch == 97 { return "a" }
        else if ch == 98 { return "b" }
        else if ch == 99 { return "c" }
        else if ch == 100 { return "d" }
        else if ch == 101 { return "e" }
        else if ch == 102 { return "f" }
        else if ch == 103 { return "g" }
        else if ch == 104 { return "h" }
        else if ch == 105 { return "i" }
        else if ch == 106 { return "j" }
        else if ch == 107 { return "k" }
        else if ch == 108 { return "l" }
        else if ch == 109 { return "m" }
        else if ch == 110 { return "n" }
        else if ch == 111 { return "o" }
        else if ch == 112 { return "p" }
        else if ch == 113 { return "q" }
        else if ch == 114 { return "r" }
        else if ch == 115 { return "s" }
        else if ch == 116 { return "t" }
        else if ch == 117 { return "u" }
        else if ch == 118 { return "v" }
        else if ch == 119 { return "w" }
        else if ch == 120 { return "x" }
        else if ch == 121 { return "y" }
        else if ch == 122 { return "z" }
    }
    return ""
}
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
func extract_json_value(string json_body, string key) string {
    int i = 0
    int key_len = len(key)
    int json_len = len(json_body)
    for i < json_len {
        if json_body[i] == 34 {
            int j = 0
            bool match = true
            for j < key_len {
                int check_pos = i + 1 + j
                if check_pos >= json_len {
                    match = false
                    break
                }
                if key[j] != json_body[check_pos] {
                    match = false
                    break
                }
                j = j + 1
            }
            if match {
                int quote_pos = i + 1 + key_len
                if quote_pos < json_len && json_body[quote_pos] == 34 {
                    int colon_pos = quote_pos + 1
                    for colon_pos < json_len && json_body[colon_pos] == 32 {
                        colon_pos = colon_pos + 1
                    }
                    if colon_pos < json_len && json_body[colon_pos] == 58 {
                        int val_pos = colon_pos + 1
                        for val_pos < json_len && json_body[val_pos] == 32 {
                            val_pos = val_pos + 1
                        }
                        if val_pos < json_len {
                            if json_body[val_pos] == 34 {
                                val_pos = val_pos + 1
                                int end_pos = val_pos
                                for end_pos < json_len && json_body[end_pos] != 34 {
                                    end_pos = end_pos + 1
                                }
                                string value = ""
                                int idx = val_pos
                                for idx < end_pos {
                                    value = value + json_body[idx]
                                    idx = idx + 1
                                }
                                return value
                            }
                            else if json_body[val_pos] >= 48 && json_body[val_pos] <= 57 {
                                int num_end = val_pos
                                for num_end < json_len {
                                    int ch = json_body[num_end]
                                    if ch >= 48 && ch <= 57 {
                                        num_end = num_end + 1
                                    }
                                    else if ch == 46 {
                                        num_end = num_end + 1
                                    }
                                    else {
                                        break
                                    }
                                }
                                string value = ""
                                int idx = val_pos
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
        }
        i = i + 1
    }
    return ""
}
func validate_json_braces(string json_body) bool {
    int i = 0
    int brace_count = 0
    for i < len(json_body) {
        int ch = json_body[i]
        if ch == 123 {
            brace_count = brace_count + 1
        }
        else if ch == 125 {
            brace_count = brace_count - 1
        }
        i = i + 1
    }
    return brace_count == 0
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
