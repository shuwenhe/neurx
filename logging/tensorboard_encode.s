package neurx.logging
func encode_scalar_summary(
    string tag,
    float value,
    int step
) []byte {
    string content = "scalar:" + tag + ":" + float_to_string(value) + ":" + int_to_string(step)
    string_to_bytes(content)
}
func write_event(
    file_handle f,
    int step,
    []byte data
) {
}
func float_to_string(float x) string {
    if x == float(int(x)) {
        return int_to_string(int(x)) + ".0"
    }
    int int_part = int(x)
    float frac = abs_float(x - float(int_part))
    string result = int_to_string(int_part) + "."
    for i in 0..6 {
        frac = frac * 10.0
        int digit = int(frac)
        result = result + char_to_string(byte('0' + digit))
        frac = frac - float(digit)
        if frac < 1e-6 { break }
    }
    result
}
func int_to_string(int x) string {
    if x == 0 { return "0" }
    bool negative = false
    if x < 0 {
        negative = true
        x = -x
    }
    []byte digits = []
    while x > 0 {
        digits.push('0' + byte(x % 10))
        x = x / 10
    }
    string result = ""
    if negative { result = "-" }
    for i in len(digits)-1 .. 0 {
        result = result + char_to_string(digits[i])
    }
    result
}
func char_to_string(byte c) string {
    string(1, c)
}
