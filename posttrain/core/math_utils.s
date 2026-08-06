package neurx.posttrain.core.math_utils
use std.io.println
func exp_taylor_s(float x) float {
    float result = 1.0
    float term = 1.0
    int i = 1
    int max_terms = 10
    while i <= max_terms {
        term = term * x / float_from_int_math(i)
        result = result + term
        float abs_term = term
        if abs_term < 0.0 { abs_term = 0.0 - abs_term }
        if abs_term < 1.0e-7 {
            i = max_terms + 1
        }
        i = i + 1
    }
    result
}
func exp_s(float x) float {
    if x > 100.0 {
        return 1.0e38
    }
    if x < -100.0 {
        return 0.0
    }
    exp_taylor_s(x)
}
func ln_series_s(float x) float {
    if x <= 0.0 {
        println("[ERROR] ln: argument must be positive")
        return 0.0
    }
    if x == 1.0 {
        return 0.0
    }
    float result = 0.0
    float original_x = x
    int exponent = 0
    while x >= 2.0 {
        x = x / 2.0
        exponent = exponent + 1
    }
    while x < 1.0 {
        x = x * 2.0
        exponent = exponent - 1
    }
    float z = x - 1.0
    float ln_x = 0.0
    float term = z
    int i = 1
    while i <= 15 {
        if i % 2 == 1 {
            ln_x = ln_x + term / float_from_int_math(i)
        } else {
            ln_x = ln_x - term / float_from_int_math(i)
        }
        term = term * z
        float abs_term = term / float_from_int_math(i + 1)
        if abs_term < 0.0 { abs_term = 0.0 - abs_term }
        if abs_term < 1.0e-8 {
            i = 15
        }
        i = i + 1
    }
    float ln2 = 0.693147180559945
    result = ln_x + ln2 * float_from_int_math(exponent)
    result
}
func log_s(float x) float {
    ln_series_s(x)
}
func sqrt_s(float x) float {
    if x < 0.0 {
        println("[ERROR] sqrt: argument must be non-negative")
        return 0.0
    }
    if x == 0.0 {
        return 0.0
    }
    float guess = x / 2.0
    if guess < 0.5 { guess = 0.5 }
    int iterations = 0
    while iterations < 20 {
        float next_guess = (guess + x / guess) / 2.0
        float diff = next_guess - guess
        if diff < 0.0 { diff = 0.0 - diff }
        if diff < 1.0e-6 {
            return next_guess
        }
        guess = next_guess
        iterations = iterations + 1
    }
    guess
}
func rsqrt_s(float x) float {
    if x <= 0.0 {
        println("[ERROR] rsqrt: argument must be positive")
        return 0.0
    }
    float sqrt_x = sqrt_s(x)
    if sqrt_x == 0.0 {
        return 0.0
    }
    1.0 / sqrt_x
}
func sin_s(float x) float {
    float pi = 3.141592653589793
    float two_pi = 6.283185307179586
    while x > pi {
        x = x - two_pi
    }
    while x < -pi {
        x = x + two_pi
    }
    float result = 0.0
    float term = x
    int i = 1
    while i <= 10 {
        result = result + term
        term = term * x * x / float_from_int_math(2 * i) / float_from_int_math(2 * i + 1)
        term = 0.0 - term
        float abs_term = term
        if abs_term < 0.0 { abs_term = 0.0 - abs_term }
        if abs_term < 1.0e-8 {
            i = 10
        }
        i = i + 1
    }
    result
}
func cos_s(float x) float {
    float pi = 3.141592653589793
    float two_pi = 6.283185307179586
    while x > pi {
        x = x - two_pi
    }
    while x < -pi {
        x = x + two_pi
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 10 {
        term = term * x * x / float_from_int_math(2 * i - 1) / float_from_int_math(2 * i)
        term = 0.0 - term
        result = result + term
        float abs_term = term
        if abs_term < 0.0 { abs_term = 0.0 - abs_term }
        if abs_term < 1.0e-8 {
            i = 10
        }
        i = i + 1
    }
    result
}
func tan_s(float x) float {
    float cos_x = cos_s(x)
    if cos_x == 0.0 {
        println("[ERROR] tan: cos is zero")
        return 0.0
    }
    sin_s(x) / cos_x
}
func abs_s(float x) float {
    if x < 0.0 {
        return 0.0 - x
    }
    x
}
func max_s(float a, float b) float {
    if a > b { a } else { b }
}
func min_s(float a, float b) float {
    if a < b { a } else { b }
}
func clamp_s(float x, float min_val, float max_val) float {
    if x < min_val { min_val }
    else if x > max_val { max_val }
    else { x }
}
func sign_s(float x) float {
    if x > 0.0 { 1.0 }
    else if x < 0.0 { -1.0 }
    else { 0.0 }
}
func pow_int_s(float x, int n) float {
    if n == 0 { return 1.0 }
    if n == 1 { return x }
    if n < 0 { return 1.0 / pow_int_s(x, 0 - n) }
    float result = 1.0
    int i = 0
    while i < n {
        result = result * x
        i = i + 1
    }
    result
}
func relu_s(float x) float {
    if x > 0.0 { x } else { 0.0 }
}
func sigmoid_s(float x) float {
    1.0 / (1.0 + exp_s(0.0 - x))
}
func tanh_s(float x) float {
    float exp_pos = exp_s(x)
    float exp_neg = exp_s(0.0 - x)
    (exp_pos - exp_neg) / (exp_pos + exp_neg)
}
func softplus_s(float x) float {
    if x > 20.0 {
        return x
    }
    log_s(1.0 + exp_s(x))
}
func float_from_int_math(int n) float {
    float result = 0.0
    if n == 0 { return 0.0 }
    bool neg = false
    if n < 0 { neg = true; n = 0 - n }
    int i = 0
    while i < n {
        result = result + 1.0
        i = i + 1
    }
    if neg { return 0.0 - result }
    result
}
func test_math_utils_s() {
    println("Testing math utilities...")
    float exp_1 = exp_s(1.0)
    println("exp(1.0) = " + float_to_str_math(exp_1) + " (expect ~2.718)")
    float log_e = log_s(2.718281828)
    println("log(e) = " + float_to_str_math(log_e) + " (expect ~1.0)")
    float sqrt_4 = sqrt_s(4.0)
    println("sqrt(4.0) = " + float_to_str_math(sqrt_4) + " (expect ~2.0)")
    float sin_0 = sin_s(0.0)
    println("sin(0) = " + float_to_str_math(sin_0) + " (expect 0)")
    float cos_0 = cos_s(0.0)
    println("cos(0) = " + float_to_str_math(cos_0) + " (expect 1.0)")
}
func float_to_str_math(float x) string {
    string result = ""
    bool neg = false
    if x < 0.0 { neg = true; x = 0.0 - x }
    int int_part = int_from_float_math(x)
    result = int_to_str_math(int_part)
    result = if neg { "-" + result } else { result }
    result
}
func int_from_float_math(float x) int {
    int result = 0
    while float_from_int_math(result + 1) <= x {
        result = result + 1
    }
    result
}
func int_to_str_math(int n) string {
    if n == 0 { return "0" }
    string result = ""
    int orig = n
    if n < 0 { n = 0 - n }
    while n > 0 {
        int digit = n - (n / 10) * 10
        if digit == 0 { result = "0" + result }
        else if digit == 1 { result = "1" + result }
        else if digit == 2 { result = "2" + result }
        else if digit == 3 { result = "3" + result }
        else if digit == 4 { result = "4" + result }
        else if digit == 5 { result = "5" + result }
        else if digit == 6 { result = "6" + result }
        else if digit == 7 { result = "7" + result }
        else if digit == 8 { result = "8" + result }
        else if digit == 9 { result = "9" + result }
        n = n / 10
    }
    if orig < 0 { result = "-" + result }
    result
}
