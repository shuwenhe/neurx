package neurx.tests.math
func test_exp() bool {
    bool all_pass = true
    float test_exp_0 = exp_approx(0.0)
    if abs(test_exp_0 - 1.0) > 0.001 {
        println("FAIL: exp(0) = " + float_to_str(test_exp_0) + ", expected 1.0")
        all_pass = false
    }
    float test_exp_1 = exp_approx(1.0)
    if abs(test_exp_1 - 2.718) > 0.01 {
        println("FAIL: exp(1) = " + float_to_str(test_exp_1) + ", expected 2.718")
        all_pass = false
    }
    float test_exp_neg1 = exp_approx(-1.0)
    if abs(test_exp_neg1 - 0.368) > 0.01 {
        println("FAIL: exp(-1) = " + float_to_str(test_exp_neg1) + ", expected 0.368")
        all_pass = false
    }
    float test_exp_2 = exp_approx(2.0)
    if abs(test_exp_2 - 7.389) > 0.1 {
        println("FAIL: exp(2) = " + float_to_str(test_exp_2) + ", expected 7.389")
        all_pass = false
    }
    return all_pass
}

func test_log() bool {
    bool all_pass = true
    float test_log_1 = log_approx(1.0)
    if abs(test_log_1 - 0.0) > 0.001 {
        println("FAIL: log(1) = " + float_to_str(test_log_1) + ", expected 0.0")
        all_pass = false
    }
    float test_log_e = log_approx(2.718)
    if abs(test_log_e - 1.0) > 0.01 {
        println("FAIL: log(2.718) = " + float_to_str(test_log_e) + ", expected 1.0")
        all_pass = false
    }
    float test_log_10 = log_approx(10.0)
    if abs(test_log_10 - 2.303) > 0.01 {
        println("FAIL: log(10) = " + float_to_str(test_log_10) + ", expected 2.303")
        all_pass = false
    }
    return all_pass
}

func test_sqrt() bool {
    bool all_pass = true
    float test_sqrt_4 = sqrt_approx(4.0)
    if abs(test_sqrt_4 - 2.0) > 0.001 {
        println("FAIL: sqrt(4) = " + float_to_str(test_sqrt_4) + ", expected 2.0")
        all_pass = false
    }
    float test_sqrt_9 = sqrt_approx(9.0)
    if abs(test_sqrt_9 - 3.0) > 0.001 {
        println("FAIL: sqrt(9) = " + float_to_str(test_sqrt_9) + ", expected 3.0")
        all_pass = false
    }
    float test_sqrt_2 = sqrt_approx(2.0)
    if abs(test_sqrt_2 - 1.414) > 0.01 {
        println("FAIL: sqrt(2) = " + float_to_str(test_sqrt_2) + ", expected 1.414")
        all_pass = false
    }
    return all_pass
}

func test_pow() bool {
    bool all_pass = true
    float test_pow_2_3 = pow_approx(2.0, 3.0)
    if abs(test_pow_2_3 - 8.0) > 0.1 {
        println("FAIL: pow(2, 3) = " + float_to_str(test_pow_2_3) + ", expected 8.0")
        all_pass = false
    }
    float test_pow_10_2 = pow_approx(10.0, 2.0)
    if abs(test_pow_10_2 - 100.0) > 1.0 {
        println("FAIL: pow(10, 2) = " + float_to_str(test_pow_10_2) + ", expected 100.0")
        all_pass = false
    }
    return all_pass
}

func run_all_math_tests() {
    println("=== Math Functions Test Suite ===")
    println("")
    println("[TEST] exp_approx()...")
    bool exp_pass = test_exp()
    if exp_pass {
        println("  PASS")
    } else {
        println("  FAIL")
    }
    println("[TEST] log_approx()...")
    bool log_pass = test_log()
    if log_pass {
        println("  PASS")
    } else {
        println("  FAIL")
    }
    println("[TEST] sqrt_approx()...")
    bool sqrt_pass = test_sqrt()
    if sqrt_pass {
        println("  PASS")
    } else {
        println("  FAIL")
    }
    println("[TEST] pow_approx()...")
    bool pow_pass = test_pow()
    if pow_pass {
        println("  PASS")
    } else {
        println("  FAIL")
    }
    println("")
    if exp_pass && log_pass && sqrt_pass && pow_pass {
        println("=== ALL TESTS PASSED ===")
    } else {
        println("=== SOME TESTS FAILED ===")
    }
}

func abs(float x) float {
    if x < 0.0 {
        return -x
    }
    return x
}

func exp_approx(float x) float {
    if x > 10.0 {
        return 22026.0
    }
    if x < -10.0 {
        return 0.0001
    }
    float result = 1.0
    float term = 1.0
    int n = 1
    while n < 10 {
        term = term * x / float(n)
        result = result + term
        n = n + 1
    }
    return result
}

func log_approx(float x) float {
    if x <= 0.0 {
        return -10.0
    }
    if x == 1.0 {
        return 0.0
    }
    float y = (x - 1.0) / (x + 1.0)
    float y2 = y * y
    float result = 0.0
    float term = y
    int n = 1
    while n < 10 {
        result = result + term / float(n)
        term = term * y2
        n = n + 2
    }
    return 2.0 * result
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x / 2.0
    int i = 0
    while i < 10 {
        guess = (guess + x / guess) / 2.0
        i = i + 1
    }
    return guess
}

func pow_approx(float base, float exp) float {
    if exp == 0.0 {
        return 1.0
    }
    if base == 0.0 {
        return 0.0
    }
    return exp_approx(exp * log_approx(base))
}

func float(int val) float {
    return 0.0
}

func float_to_str(float val) string {
    return ""
}

