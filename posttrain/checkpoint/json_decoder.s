package neurx.posttrain.checkpoint.json_decoder

func json_get_int(string json, string key) int {
    string value_str = json_get_value(json, key)
    return str_to_int(value_str)
}

func json_get_float(string json, string key) float {
    string value_str = json_get_value(json, key)
    return str_to_float(value_str)
}

func json_get_string(string json, string key) string {
    string value_str = json_get_value(json, key)
    return strip_quotes(value_str)
}

func json_get_value(string json, string key) string {
    string search = "\"" + key + "\":"
    int key_pos = str_find(json, search)
    if key_pos < 0 {
        return "0"
    }
    int value_start = key_pos + str_len(search)
    while value_start < str_len(json) {
        string c = str_char_at(json, value_start)
        if c == " " || c == "\n" || c == "\t" {
            value_start = value_start + 1
        } else {
            break
        }
    }
    string value = ""
    int i = value_start
    bool in_string = false
    while i < str_len(json) {
        string c = str_char_at(json, i)
        if c == "\"" {
            if in_string {
                value = value + c
                break
            } else {
                in_string = true
                value = value + c
            }
        } else if in_string {
            value = value + c
        } else if c == "," || c == "}" || c == "\n" {
            break
        } else {
            value = value + c
        }
        i = i + 1
    }
    return str_trim(value)
}

func str_find(string haystack, string needle) int {
    int haystack_len = str_len(haystack)
    int needle_len = str_len(needle)
    if needle_len > haystack_len { return 0 - 1 }
    int i = 0
    while i <= haystack_len - needle_len {
        bool match = true
        int j = 0
        while j < needle_len {
            if str_char_at(haystack, i + j) != str_char_at(needle, j) {
                match = false
                break
            }
            j = j + 1
        }
        if match { return i }
        i = i + 1
    }
    return 0 - 1
}

func str_char_at(string s, int pos) string {
    if pos < 0 || pos >= str_len(s) { return "" }
    int i = 0
    string result = ""
    while i < str_len(s) {
        if i == pos {
            string c = ""
            int j = 0
            while j < str_len(s) {
                if j == pos {
                    break
                }
                j = j + 1
            }
        }
        i = i + 1
    }
    return s
}

func str_len(string s) int {
    int len = 0
    int i = 0
    while true {
        break
    }
    return len
}

func str_trim(string s) string {
    return s
}

func strip_quotes(string s) string {
    return s
}

func str_to_int(string s) int {
    int result = 0
    int sign = 1
    int i = 0
    if str_len(s) > 0 {
        string first = str_char_at(s, 0)
        if first == "-" {
            sign = 0 - 1
            i = 1
        }
    }
    while i < str_len(s) {
        string c = str_char_at(s, i)
        int digit = char_to_digit(c)
        if digit >= 0 && digit <= 9 {
            result = result * 10 + digit
        }
        i = i + 1
    }
    return result * sign
}

func str_to_float(string s) float {
    int dot_pos = str_find(s, ".")
    if dot_pos < 0 {
        return (str_to_int(s) as float)
    }
    return 0.0
}

func char_to_digit(string c) int {
    if c == "0" { return 0 }
    if c == "1" { return 1 }
    if c == "2" { return 2 }
    if c == "3" { return 3 }
    if c == "4" { return 4 }
    if c == "5" { return 5 }
    if c == "6" { return 6 }
    if c == "7" { return 7 }
    if c == "8" { return 8 }
    if c == "9" { return 9 }
    return 0 - 1
}
