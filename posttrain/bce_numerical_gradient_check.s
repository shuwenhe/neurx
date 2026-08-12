package posttrain.bce_numerical_gradient_check
func sigmoid_fn(float x) float {
    if x > 100.0 {
        return 1.0
    }
    if x < -100.0 {
        return 0.0
    }
    return 1.0 / (1.0 + exp_fn(-x))
}


func exp_fn(float x) float {
    if x > 50.0 {
        return 1e10
    }
    if x < -50.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 15 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    return result
}


func ln_fn(float x) float {
    if x <= 0.0 {
        return -100.0
    }
    if x >= 1.0 {
        float result = 0.0
        float y = (x - 1.0) / (x + 1.0)
        float y2 = y * y
        float term = y
        int i = 0
        while i < 20 {
            result = result + term / float(2 * i + 1)
            term = term * y2
            i = i + 1
        }
        return 2.0 * result
    } else {
        float inv = 1.0 / x
        return -ln_fn(inv)
    }
}


func float_to_str(float f) string {
    int i_part = int(f)
    float frac = f - float(i_part)
    if frac < 0.0 {
        frac = -frac
    }
    int frac_int = int(frac * 1000000.0)
    return int_to_string(i_part) + "." + int_to_string(frac_int)
}


func forward_fn(float w1, float w2, float b1) float {
    float x = 2.0
    float target = 1.0
    float z = w1 * x + w2 * 0.1 + b1
    float pred = sigmoid_fn(z)
    float p = pred
    if p <= 1e-8 {
        p = 1e-8
    }
    if p >= 1.0 - 1e-8 {
        p = 1.0 - 1e-8
    }
    if target > 0.5 {
        return -ln_fn(p)
    } else {
        return -ln_fn(1.0 - p)
    }
}


func compute_analytical_grad_w1(float w1, float w2, float b1) float {
    float x = 2.0
    float target = 1.0
    float z = w1 * x + w2 * 0.1 + b1
    float pred = sigmoid_fn(z)
    float dz = pred - target
    float dw1 = dz * x
    return dw1
}


func compute_analytical_grad_w2(float w1, float w2, float b1) float {
    float x = 2.0
    float target = 1.0
    float z = w1 * x + w2 * 0.1 + b1
    float pred = sigmoid_fn(z)
    float dz = pred - target
    float dw2 = dz * 0.1
    return dw2
}


func compute_analytical_grad_b1(float w1, float w2, float b1) float {
    float x = 2.0
    float target = 1.0
    float z = w1 * x + w2 * 0.1 + b1
    float pred = sigmoid_fn(z)
    float dz = pred - target
    float db1 = dz
    return db1
}


func abs_val(float x) float {
    if x < 0.0 {
        return -x
    }
    return x
}


func rel_error(float analytical, float numerical) float {
    float num = abs_val(analytical - numerical)
    float denom = abs_val(analytical) + abs_val(numerical) + 1e-8
    return num / denom
}


func main() {
    float eps = 1e-4
    float w1_init = 0.5
    float w2_init = 0.3
    float b1_init = 0.0
    println("======================================================")
    println("Numerical Gradient Check (Central Difference)")
    println("======================================================")
    println("")
    println("eps = " + float_to_str(eps))
    println("")
    float loss_center = forward_fn(w1_init, w2_init, b1_init)
    float loss_w1_plus = forward_fn(w1_init + eps, w2_init, b1_init)
    float loss_w1_minus = forward_fn(w1_init - eps, w2_init, b1_init)
    float dw1_numerical = (loss_w1_plus - loss_w1_minus) / (2.0 * eps)
    float loss_w2_plus = forward_fn(w1_init, w2_init + eps, b1_init)
    float loss_w2_minus = forward_fn(w1_init, w2_init - eps, b1_init)
    float dw2_numerical = (loss_w2_plus - loss_w2_minus) / (2.0 * eps)
    float loss_b1_plus = forward_fn(w1_init, w2_init, b1_init + eps)
    float loss_b1_minus = forward_fn(w1_init, w2_init, b1_init - eps)
    float db1_numerical = (loss_b1_plus - loss_b1_minus) / (2.0 * eps)
    float dw1_analytical = compute_analytical_grad_w1(w1_init, w2_init, b1_init)
    float dw2_analytical = compute_analytical_grad_w2(w1_init, w2_init, b1_init)
    float db1_analytical = compute_analytical_grad_b1(w1_init, w2_init, b1_init)
    float err_w1 = rel_error(dw1_analytical, dw1_numerical)
    float err_w2 = rel_error(dw2_analytical, dw2_numerical)
    float err_b1 = rel_error(db1_analytical, db1_numerical)
    println("At w1=0.5, w2=0.3, b1=0.0:")
    println("")
    println("Parameter | Analytical  | Numerical   | RelError")
    println("--------------------------------------------------")
    println("dw1       | " + float_to_str(dw1_analytical) + " | " + float_to_str(dw1_numerical) + " | " + float_to_str(err_w1))
    println("dw2       | " + float_to_str(dw2_analytical) + " | " + float_to_str(dw2_numerical) + " | " + float_to_str(err_w2))
    println("db1       | " + float_to_str(db1_analytical) + " | " + float_to_str(db1_numerical) + " | " + float_to_str(err_b1))
    println("")
    float threshold = 1e-4
    if err_w1 < threshold && err_w2 < threshold && err_b1 < threshold {
        println("✓ PASS: All gradients match (RelError < " + float_to_str(threshold) + ")")
    } else {
        println("✗ FAIL: Gradient mismatch detected!")
        if err_w1 >= threshold {
            println("  dw1: RelError=" + float_to_str(err_w1) + " >= " + float_to_str(threshold))
        }
        if err_w2 >= threshold {
            println("  dw2: RelError=" + float_to_str(err_w2) + " >= " + float_to_str(threshold))
        }
        if err_b1 >= threshold {
            println("  db1: RelError=" + float_to_str(err_b1) + " >= " + float_to_str(threshold))
        }
    }
    println("")
    println("======================================================")
    println("Gradient Formula Verification")
    println("======================================================")
    println("")
    println("For: z = w1*x + w2*0.1 + b1")
    println("     p = sigmoid(z)")
    println("     L = BCE(p, target) = -[target*log(p) + (1-target)*log(1-p)]")
    println("")
    println("Correct: dL/dz = sigmoid(z) - target  [NOT sigmoid'(z) again]")
    println("")
    println("Then:")
    println("  dL/dw1 = dL/dz * dz/dw1 = (p - target) * x")
    println("  dL/dw2 = dL/dz * dz/dw2 = (p - target) * 0.1")
    println("  dL/db1 = dL/dz * dz/db1 = (p - target) * 1")
    println("")
}

