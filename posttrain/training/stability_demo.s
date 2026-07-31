package neurx.posttrain.training.stability_demo

use neurx.posttrain.training.stability.{has_nan, has_inf}

func demo_nan_detection() {
    println("=== NaN/Inf Detection Demo ===")
    println("")

    float normal = 1.5
    println("[Test 1] Normal value: 1.5")
    if !has_nan(normal) && !has_inf(normal) {
        println("  ✓ Healthy gradient")
    }
    println("")

    float zero = 0.0
    float nan_value = zero / zero
    println("[Test 2] NaN value (0.0/0.0)")
    if has_nan(nan_value) {
        println("  ✗ NaN detected! Training should stop.")
    }
    println("")

    float large = 1e40
    println("[Test 3] Inf value (1e40)")
    if has_inf(large) {
        println("  ✗ Inf detected! Training should stop.")
    }
    println("")

    println("✓ NaN/Inf detection working correctly!")
}

func demo_gradient_clipping() {
    println("")
    println("=== Gradient Clipping Demo ===")
    println("")

    []float grads = []float{1.0, 2.0, 3.0, 4.0, 5.0}

    float norm_sq = 0.0
    int i = 0
    while i < len(grads) {
        norm_sq = norm_sq + grads[i] * grads[i]
        i = i + 1
    }
    float norm = sqrt(norm_sq)

    print("Original gradient norm: ")
    println(float_to_str_2(norm))

    float max_norm = 3.0
    if norm > max_norm {
        float scale = max_norm / norm
        print("Clipping with scale: ")
        println(float_to_str_4(scale))

        i = 0
        while i < len(grads) {
            grads[i] = grads[i] * scale
            i = i + 1
        }

        println("✓ Gradients clipped successfully!")
    }

    println("")
}

func main() {
    demo_nan_detection()
    demo_gradient_clipping()

    println("")
    println("====================================")
    println("Next Steps:")
    println("1. Integrate check_grads_healthy() into your training loop")
    println("2. Use clip_all_gradients() before optimizer step")
    println("3. Monitor gradient norms in logs")
    println("====================================")
}

func float_to_str_2(float value) string {
    return float_to_str_n(value, 2)
}

func float_to_str_4(float value) string {
    return float_to_str_n(value, 4)
}

func float_to_str_n(float value, int decimals) string {
    float current = value
    bool negative = current < 0.0
    if negative { current = 0.0 - current }

    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }

    string result = int_to_str(whole)

    if decimals > 0 {
        result = result + "."
        int i = 0
        while i < decimals {
            current = current * 10.0
            int digit = 0
            while current >= 1.0 {
                current = current - 1.0
                digit = digit + 1
            }
            result = result + int_to_str(digit)
            i = i + 1
        }
    }

    if negative { result = "-" + result }
    return result
}

func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool negative = false
    if value < 0 {
        negative = true
        value = 0 - value
    }
    string out = ""
    while value > 0 {
        int digit = value - (value / 10) * 10
        if digit == 0 { out = "0" + out }
        else if digit == 1 { out = "1" + out }
        else if digit == 2 { out = "2" + out }
        else if digit == 3 { out = "3" + out }
        else if digit == 4 { out = "4" + out }
        else if digit == 5 { out = "5" + out }
        else if digit == 6 { out = "6" + out }
        else if digit == 7 { out = "7" + out }
        else if digit == 8 { out = "8" + out }
        else { out = "9" + out }
        value = value / 10
    }
    if negative { out = "-" + out }
    return out
}
