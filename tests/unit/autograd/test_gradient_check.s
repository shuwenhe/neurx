package neurx.tests.gradient

func test_gradient_check_simple() bool {
    println("  [Test] Gradient Check - Simple Function")
    println("    f(x) = x^2, f'(x) = 2x")
    float x = 3.0
    float h = 0.0001
    float f_x_plus_h = (x + h) * (x + h)
    float f_x_minus_h = (x - h) * (x - h)
    float numerical_grad = (f_x_plus_h - f_x_minus_h) / (2.0 * h)
    float analytical_grad = 2.0 * x
    float error = abs(numerical_grad - analytical_grad)
    bool pass = error < 0.001
    if !pass {
        println("    FAIL: numerical_grad = " + float_to_str(numerical_grad))
        println("          analytical_grad = " + float_to_str(analytical_grad))
        println("          error = " + float_to_str(error))
        return false
    }
    println("    PASS (error = " + float_to_str(error) + ")")
    return true
}

func test_gradient_check_exp() bool {
    println("  [Test] Gradient Check - Exponential Function")
    println("    f(x) = exp(x), f'(x) = exp(x)")
    float x = 1.0
    float h = 0.0001
    float f_x_plus_h = exp_approx(x + h)
    float f_x_minus_h = exp_approx(x - h)
    float numerical_grad = (f_x_plus_h - f_x_minus_h) / (2.0 * h)
    float analytical_grad = exp_approx(x)
    float error = abs(numerical_grad - analytical_grad)
    bool pass = error < 0.01
    if !pass {
        println("    FAIL: numerical_grad = " + float_to_str(numerical_grad))
        println("          analytical_grad = " + float_to_str(analytical_grad))
        println("          error = " + float_to_str(error))
        return false
    }
    println("    PASS (error = " + float_to_str(error) + ")")
    return true
}

func test_gradient_check_embedding_loss() bool {
    println("  [Test] Gradient Check - Embedding Loss")
    println("    Simplified: L = sum(w * input)")
    float w0 = 0.5
    float w1 = 0.3
    float input0 = 1.0
    float input1 = 2.0
    float h = 0.0001
    float loss_original = w0 * input0 + w1 * input1
    float w0_plus_h = w0 + h
    float loss_w0_plus = w0_plus_h * input0 + w1 * input1
    float w0_minus_h = w0 - h
    float loss_w0_minus = w0_minus_h * input0 + w1 * input1
    float numerical_grad_w0 = (loss_w0_plus - loss_w0_minus) / (2.0 * h)
    float analytical_grad_w0 = input0
    float error = abs(numerical_grad_w0 - analytical_grad_w0)
    bool pass = error < 0.001
    if !pass {
        println("    FAIL: numerical_grad = " + float_to_str(numerical_grad_w0))
        println("          analytical_grad = " + float_to_str(analytical_grad_w0))
        println("          error = " + float_to_str(error))
        return false
    }
    println("    PASS (error = " + float_to_str(error) + ")")
    return true
}

func run_gradient_check_tests() {
    println("=== Gradient Check Test Suite ===")
    println("")
    bool test1 = test_gradient_check_simple()
    bool test2 = test_gradient_check_exp()
    bool test3 = test_gradient_check_embedding_loss()
    println("")
    if test1 && test2 && test3 {
        println("=== ALL GRADIENT CHECK TESTS PASSED ===")
    } else {
        println("=== SOME GRADIENT CHECK TESTS FAILED ===")
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

func float_to_str(float val) string {
    return ""
}

