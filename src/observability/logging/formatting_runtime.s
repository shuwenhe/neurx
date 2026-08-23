package neurx.observability.logging

func format_scientific(float value) string {
    if value == 0.0 { return "0e+0" }
    bool negative = false
    if value < 0.0 {
        negative = true
        value = -value
    }
    int exponent = 0
    if value >= 1.0 {
        while value >= 10.0 {
            value = value / 10.0
            exponent = exponent + 1
        }
    } else if value < 1.0 {
        while value < 1.0 {
            value = value * 10.0
            exponent = exponent - 1
        }
    }
    string mantissa = float_to_string_with_decimals(value, 3)
    string result = ""
    if negative { result = "-" }
    result = result + mantissa + "e"
    if exponent >= 0 {
        result = result + "+" + int_to_string(exponent)
    } else {
        result = result + int_to_string(exponent)
    }
    result
}

func format_duration(float seconds) string {
    if seconds < 60.0 {
        return int_to_string(int(seconds)) + "s"
    } else if seconds < 3600.0 {
        int mins = int(seconds / 60.0)
        int secs = int(seconds) % 60
        return int_to_string(mins) + "m" + int_to_string(secs) + "s"
    } else {
        int hours = int(seconds / 3600.0)
        int mins = int((seconds % 3600.0) / 60.0)
        return int_to_string(hours) + "h" + int_to_string(mins) + "m"
    }
}

func compute_rolling_average([]float values) float {
    if len(values) == 0 { return 0.0 }
    float ema = values[0]
    float alpha = 0.1
    for i in 1..len(values) {
        ema = alpha * values[i] + (1.0 - alpha) * ema
    }
    ema
}

func repeat_char(byte c, int n) string {
    string s = ""
    for i in 0..n {
        s = s + char_to_string(c)
    }
    s
}

func print_overwrite(string message) {
    print("\r" + message)
}

func substring(string s, int start, int length) string {
    if start >= len(s) { return "" }
    int end = min(start + length, len(s))
    string result = ""
    for i in start..end {
        result = result + char_to_string(s[i])
    }
    result
}
