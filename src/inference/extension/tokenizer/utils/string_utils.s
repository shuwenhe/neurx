package neurx.util.string_utils
extern "intrinsic" func __host_slice(string text, int start, int end) string

func string_split(string text, string delimiter) []string {
    []string result = []string{cap: 1000}
    int result_count = 0
    if len(text) == 0 || len(delimiter) == 0 {
        if len(text) > 0 {
            result[0] = text
            result_count = 1
        }
        return result
    }
    int start = 0
    int i = 0
    int delim_len = len(delimiter)
    for i <= len(text) - delim_len {
        if __host_slice(text, i, i + delim_len) == delimiter {
            if i > start || result_count == 0 {
                string part = __host_slice(text, start, i)
                result[result_count] = part
                result_count = result_count + 1
            }
            start = i + delim_len
            i = i + delim_len
        } else {
            i = i + 1
        }
    }
    if start < len(text) {
        result[result_count] = __host_slice(text, start, len(text))
        result_count = result_count + 1
    } else if result_count == 0 {
        result[0] = ""
        result_count = 1
    }
    return result
}

func string_contains(string text, string substr) bool {
    return string_index_of(text, substr) >= 0
}

func string_index_of(string text, string substr) int {
    if len(substr) == 0 {
        return 0
    }
    int i = 0
    int text_len = len(text)
    int substr_len = len(substr)
    for i <= text_len - substr_len {
        if __host_slice(text, i, i + substr_len) == substr {
            return i
        }
        i = i + 1
    }
    return -1
}

func string_last_index_of(string text, string ch) int {
    int last_idx = -1
    int i = 0
    for i < len(text) {
        if __host_slice(text, i, i + 1) == ch {
            last_idx = i
        }
        i = i + 1
    }
    return last_idx
}

func string_trim(string text) string {
    int start = 0
    int end = len(text)
    for start < end {
        string ch = __host_slice(text, start, start + 1)
        if ch != " " && ch != "\t" && ch != "\n" && ch != "\r" {
            break
        }
        start = start + 1
    }
    for end > start {
        string ch = __host_slice(text, end - 1, end)
        if ch != " " && ch != "\t" && ch != "\n" && ch != "\r" {
            break
        }
        end = end - 1
    }
    return __host_slice(text, start, end)
}

func string_starts_with(string text, string prefix) bool {
    if len(prefix) > len(text) {
        return false
    }
    return __host_slice(text, 0, len(prefix)) == prefix
}

func string_ends_with(string text, string suffix) bool {
    if len(suffix) > len(text) {
        return false
    }
    return __host_slice(text, len(text) - len(suffix), len(text)) == suffix
}

func string_to_lower(string text) string {
    string result = ""
    int i = 0
    for i < len(text) {
        string ch = __host_slice(text, i, i + 1)
        int ascii = int(ch[0])
        if ascii >= 65 && ascii <= 90 {
            result = result + __host_slice("abcdefghijklmnopqrstuvwxyz", ascii - 65, ascii - 64)
        } else {
            result = result + ch
        }
        i = i + 1
    }
    return result
}

func string_to_upper(string text) string {
    string result = ""
    int i = 0
    for i < len(text) {
        string ch = __host_slice(text, i, i + 1)
        int ascii = int(ch[0])
        if ascii >= 97 && ascii <= 122 {
            result = result + __host_slice("ABCDEFGHIJKLMNOPQRSTUVWXYZ", ascii - 97, ascii - 64)
        } else {
            result = result + ch
        }
        i = i + 1
    }
    return result
}

func int_to_string(int num) string {
    if num == 0 {
        return "0"
    }
    string result = ""
    int n = num
    if n < 0 {
        result = "-"
        n = -n
    }
    string digits = "0123456789"
    int temp = n
    int digit_count = 0
    for temp > 0 {
        digit_count = digit_count + 1
        temp = temp / 10
    }
    int idx = 0
    for idx < digit_count {
        int power = 1
        int p = digit_count - idx - 1
        int count_p = 0
        for count_p < p {
            power = power * 10
            count_p = count_p + 1
        }
        int digit = (n / power) % 10
        result = result + __host_slice(digits, digit, digit + 1)
        idx = idx + 1
    }
    return result
}

func string_to_int(string text) int {
    int result = 0
    int i = 0
    int start = 0
    bool negative = false
    if len(text) > 0 && __host_slice(text, 0, 1) == "-" {
        negative = true
        start = 1
    }
    i = start
    for i < len(text) {
        string ch = __host_slice(text, i, i + 1)
        if ch >= "0" && ch <= "9" {
            result = result * 10 + (int(ch[0]) - int("0"[0]))
        }
        i = i + 1
    }
    if negative {
        result = -result
    }
    return result
}

func string_join([]string parts, string separator) string {
    string result = ""
    int i = 0
    for i < len(parts) {
        if i > 0 {
            result = result + separator
        }
        result = result + parts[i]
        i = i + 1
    }
    return result
}

func string_replace(string text, string old_str, string new_str) string {
    string result = ""
    int i = 0
    int old_len = len(old_str)
    for i < len(text) {
        if i <= len(text) - old_len && __host_slice(text, i, i + old_len) == old_str {
            result = result + new_str
            i = i + old_len
        } else {
            result = result + __host_slice(text, i, i + 1)
            i = i + 1
        }
    }
    return result
}
