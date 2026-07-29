package neurx.tests.optimizer

struct adamw_test_state {
    float param
    float grad
    float momentum
    float variance
    int step
}

func test_adamw_single_step() bool {
    println("  [Test] AdamW Single Step")
    
    float param = 1.0
    float grad = 0.1
    float momentum = 0.0
    float variance = 0.0
    int step = 0
    
    float lr = 0.001
    float beta1 = 0.9
    float beta2 = 0.999
    float eps = 1e-8
    float weight_decay = 0.01
    
    step = step + 1
    
    momentum = beta1 * momentum + (1.0 - beta1) * grad
    variance = beta2 * variance + (1.0 - beta2) * grad * grad
    
    float bias_correction1 = 1.0 - pow_approx(beta1, float(step))
    float bias_correction2 = 1.0 - pow_approx(beta2, float(step))
    
    float m_hat = momentum / bias_correction1
    float v_hat = variance / bias_correction2
    
    float update = lr * m_hat / (sqrt_approx(v_hat) + eps)
    param = param - update - weight_decay * lr * param
    
    float expected_momentum = 0.01
    float expected_variance = 0.001
    float expected_param = 0.99899
    
    bool momentum_ok = abs(momentum - expected_momentum) < 0.0001
    bool variance_ok = abs(variance - expected_variance) < 0.00001
    bool param_ok = abs(param - expected_param) < 0.0001
    
    if !momentum_ok {
        println("    FAIL: momentum = " + float_to_str(momentum) + ", expected " + float_to_str(expected_momentum))
    }
    if !variance_ok {
        println("    FAIL: variance = " + float_to_str(variance) + ", expected " + float_to_str(expected_variance))
    }
    if !param_ok {
        println("    FAIL: param = " + float_to_str(param) + ", expected " + float_to_str(expected_param))
    }
    
    if momentum_ok && variance_ok && param_ok {
        println("    PASS")
        return true
    }
    
    return false
}

func test_adamw_multi_step() bool {
    println("  [Test] AdamW Multi Step (10 iterations)")
    
    float param = 1.0
    float momentum = 0.0
    float variance = 0.0
    
    float lr = 0.001
    float beta1 = 0.9
    float beta2 = 0.999
    float eps = 1e-8
    float weight_decay = 0.01
    
    int step = 0
    while step < 10 {
        step = step + 1
        
        float grad = 0.1
        
        momentum = beta1 * momentum + (1.0 - beta1) * grad
        variance = beta2 * variance + (1.0 - beta2) * grad * grad
        
        float bias_correction1 = 1.0 - pow_approx(beta1, float(step))
        float bias_correction2 = 1.0 - pow_approx(beta2, float(step))
        
        float m_hat = momentum / bias_correction1
        float v_hat = variance / bias_correction2
        
        float update = lr * m_hat / (sqrt_approx(v_hat) + eps)
        param = param - update - weight_decay * lr * param
    }
    
    float expected_param_final = 0.990
    
    bool param_ok = abs(param - expected_param_final) < 0.01
    
    if !param_ok {
        println("    FAIL: final param = " + float_to_str(param) + ", expected ~" + float_to_str(expected_param_final))
        return false
    }
    
    println("    PASS (final param = " + float_to_str(param) + ")")
    return true
}

func run_adamw_tests() {
    println("=== AdamW Optimizer Test Suite ===")
    println("")
    
    bool test1 = test_adamw_single_step()
    bool test2 = test_adamw_multi_step()
    
    println("")
    if test1 && test2 {
        println("=== ALL ADAMW TESTS PASSED ===")
    } else {
        println("=== SOME ADAMW TESTS FAILED ===")
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
