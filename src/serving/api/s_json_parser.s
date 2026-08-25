package neurx.core.json

func extract_json_string(string json, string key) string {
    string search = "\"" + key + "\":"

    int start_pos = -1
    int i = 0
    for i < len(json) {
        bool found = true
        int j = 0
        for j < len(search) && i + j < len(json) {
            if json[i + j] != search[j] {
                found = false
            }
            j = j + 1
        }

        if found {
            start_pos = i + len(search)
            break
        }
        i = i + 1
    }

    if start_pos == -1 {
        return ""
    }

    string result = ""
    int k = start_pos
    bool in_string = false
    bool escaped = false

    for k < len(json) {
        string c = json[k]

        if escaped {
            result = result + c
            escaped = false
            k = k + 1
            continue
        }

        if c == "\\" && in_string {
            escaped = true
            k = k + 1
            continue
        }

        if c == "\"" {
            if !in_string {
                in_string = true
            } else {
                break
            }
        } else if in_string {
            result = result + c
        }

        k = k + 1
    }

    return result
}

func extract_json_number(string json, string key) int {
    string search = "\"" + key + "\":"

    int start_pos = -1
    int i = 0
    for i < len(json) {
        bool found = true
        int j = 0
        for j < len(search) && i + j < len(json) {
            if json[i + j] != search[j] {
                found = false
            }
            j = j + 1
        }

        if found {
            start_pos = i + len(search)
            break
        }
        i = i + 1
    }

    if start_pos == -1 {
        return 0
    }

    string num_str = ""
    int k = start_pos

    for k < len(json) {
        string c = json[k]
        if c >= "0" && c <= "9" {
            num_str = num_str + c
        } else {
            break
        }
        k = k + 1
    }

    int result = 0
    int m = 0
    for m < len(num_str) {
        string digit = num_str[m]
        int digit_val = 0

        if digit == "0" { digit_val = 0 }
        else if digit == "1" { digit_val = 1 }
        else if digit == "2" { digit_val = 2 }
        else if digit == "3" { digit_val = 3 }
        else if digit == "4" { digit_val = 4 }
        else if digit == "5" { digit_val = 5 }
        else if digit == "6" { digit_val = 6 }
        else if digit == "7" { digit_val = 7 }
        else if digit == "8" { digit_val = 8 }
        else if digit == "9" { digit_val = 9 }

        result = result * 10 + digit_val
        m = m + 1
    }

    return result
}

func escape_json_string(string s) string {
    string result = ""
    int i = 0

    for i < len(s) {
        string c = s[i]

        if c == "\"" {
            result = result + "\\\""
        } else if c == "\\" {
            result = result + "\\\\"
        } else if c == "\n" {
            result = result + "\\n"
        } else if c == "\r" {
            result = result + "\\r"
        } else if c == "\t" {
            result = result + "\\t"
        } else {
            result = result + c
        }

        i = i + 1
    }

    return result
}

func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }

    string result = ""
    bool negative = false

    if n < 0 {
        negative = true
        n = 0 - n
    }

    for n > 0 {
        int digit = n % 10
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
        n = n / 10
    }

    if negative {
        result = "-" + result
    }

    return result
}

func main() {
    print("✅ JSON 解析模块已加载\n")
}
