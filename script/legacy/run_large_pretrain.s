package main
use neurx.pretrain.llm.gpt_large_pretrain.{gpt_large_pretrain_launch}

func main() {
    return gpt_large_pretrain_launch()
}

func str_to_int(string s, int fallback) int {
    string text = trim(s)
    if len(text) == 0 {
        return fallback
    }
    int sign = 1
    int i = 0
    if text[0] == 45 {
        sign = -1
        i = 1
    }
    int value = 0
    for i < len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}

func str_to_float(string s) float {
    string text = trim(s)
    if len(text) == 0 {
        return 0.0
    }
    bool neg = false
    int i = 0
    if text[0] == 45 {
        neg = true
        i = 1
    }
    float whole = 0.0
    for i < len(text) && text[i] >= 48 && text[i] <= 57 {
        whole = whole * 10.0 + (text[i] - 48) * 1.0
        i = i + 1
    }
    float frac = 0.0
    float scale = 1.0
    if i < len(text) && text[i] == 46 {
        i = i + 1
        for i < len(text) && text[i] >= 48 && text[i] <= 57 {
            frac = frac * 10.0 + (text[i] - 48) * 1.0
            scale = scale * 10.0
            i = i + 1
        }
    }
    float value = whole + frac / scale
    if neg {
        value = 0.0 - value
    }
    value
}

func clamp_int(int value, int min_value, int max_value) int {
    if value < min_value {
        return min_value
    }
    if value > max_value {
        return max_value
    }
    value
}

func trim(string s) string {
    int i = 0
    for i < len(s) && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = len(s) - 1
    for j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    string out = ""
    int k = i
    for k <= j {
        out = out + string_char(s[k])
        k = k + 1
    }
    out
}

func int_to_str(int n, int fallback) string {
    int value = n
    if value == 0 {
        return "0"
    }
    bool neg = value < 0
    if neg {
        value = -value
    }
    string s = ""
    for value > 0 {
        s = string_char(value - (value / 10) * 10 + 48) + s
        value = value / 10
    }
    if neg {
        s = "-" + s
    }
    s
}

func fmt_float(float val, int decimals) string {
    float value = val
    if value == 0.0 {
        return "0.0"
    }
    bool neg = value < 0.0
    if neg {
        value = 0.0 - value
    }
    int int_part = 0
    float whole = value
    for whole >= 1.0 {
        whole = whole - 1.0
        int_part = int_part + 1
    }
    float frac = value - int_part
    string s = ""
    if neg {
        s = "-"
    }
    s = s + int_to_str(int_part, 0) + "."
    int i = 0
    for i < decimals {
        frac = frac * 10.0
        int digit = 0
        float tmp = frac
        for tmp >= 1.0 {
            tmp = tmp - 1.0
            digit = digit + 1
        }
        s = s + string_char(digit + 48)
        frac = frac - digit
        i = i + 1
    }
    s
}

func string_char(int c) string {
    string(c)
}
