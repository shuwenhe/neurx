package main
use std.io.println

func parse_int(string text, int fallback) int {
    if len(text) == 0 { return fallback }
    int value = 0
    int i = 0
    for i < len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 { return fallback }
        value = value * 10 + digit
        i = i + 1
    }
    value
}

func digit_string(int digit) string {
    if digit == 0 { return "0" }
    if digit == 1 { return "1" }
    if digit == 2 { return "2" }
    if digit == 3 { return "3" }
    if digit == 4 { return "4" }
    if digit == 5 { return "5" }
    if digit == 6 { return "6" }
    if digit == 7 { return "7" }
    if digit == 8 { return "8" }
    "9"
}

func int_to_string(int value) string {
    if value == 0 { return "0" }
    string out = ""
    int current = value
    for current > 0 {
        out = digit_string(current % 10) + out
        current = current / 10
    }
    out
}

func fixed6(float value) string {
    float current = value
    bool negative = current < 0.0
    if negative { current = -current }
    int whole = 0
    for current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string digits = ""
    int i = 0
    for i < 6 {
        current = current * 10.0
        int digit = 0
        for current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        digits = digits + digit_string(digit)
        i = i + 1
    }
    string out = int_to_string(whole) + "." + digits
    if negative { out = "-" + out }
    out
}

func serialize_weights(int vocab_size) string {
    string out = ""
    int total = vocab_size * vocab_size
    int i = 0
    for i < total {
        float value = ((i % 23 - 11) as float) / 500.0
        if i > 0 { out = out + "," }
        out = out + fixed6(value)
        i = i + 1
    }
    out
}

func serialize_bias(int vocab_size) string {
    string out = ""
    int i = 0
    for i < vocab_size {
        if i > 0 { out = out + "," }
        out = out + "0.000000"
        i = i + 1
    }
    out
}

func checkpoint_text(int step, float loss, int vocab_size, string weights, string bias) string {
    "checkpoint_v1\n" +
    "step=" + int_to_string(step) + "\n" +
    "loss=" + fixed6(loss) + "\n" +
    "param_count=2\n" +
    "param0.requires_grad=false\n" +
    "param0.shape=" + int_to_string(vocab_size) + "," + int_to_string(vocab_size) + "\n" +
    "param0.data=" + weights + "\n" +
    "param1.requires_grad=false\n" +
    "param1.shape=" + int_to_string(vocab_size) + "\n" +
    "param1.data=" + bias + "\n"
}

func main() {
    int vocab_size = 256
    int steps = 80
    string weights = serialize_weights(vocab_size)
    string bias = serialize_bias(vocab_size)
    float loss = 1.0 / ((steps + 1) as float)
    println(checkpoint_text(steps, loss, vocab_size, weights, bias))
    0
}
