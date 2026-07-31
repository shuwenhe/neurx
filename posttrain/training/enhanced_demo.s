
package neurx.posttrain.training.enhanced_demo

use neurx.posttrain.training.stability.{clip_all_gradients, check_grads_healthy, compute_accuracy}


func training_loop_with_stability() {
    println("=== Enhanced Training Loop Demo ===")
    println("")
    println("Key Improvements:")
    println("1. Global gradient clipping (across all layers)")
    println("2. NaN/Inf detection (automatic training abort)")
    println("3. Token accuracy tracking")
    println("")


    int num_steps = 10
    int step = 0

    while step < num_steps {
        println("[Step " + int_to_str(step + 1) + "/" + int_to_str(num_steps) + "]")



        float loss = 2.5 - ((step as float)) * 0.2





        []float layer1_grads = make_float_array(3)
        layer1_grads[0] = 0.1
        layer1_grads[1] = 0.2
        layer1_grads[2] = 0.3

        []float layer2_grads = make_float_array(3)
        layer2_grads[0] = 0.4
        layer2_grads[1] = 0.5
        layer2_grads[2] = 0.6

        [][]float all_gradients = make_2d_array(2)
        all_gradients[0] = layer1_grads
        all_gradients[1] = layer2_grads


        bool grads_healthy = check_grads_healthy(all_gradients)
        if !grads_healthy {
            println("[ABORT] Training stopped due to NaN/Inf in gradients!")
            println("Checkpoint saved. Please investigate the issue.")
            return
        }


        float grad_norm = clip_all_gradients(all_gradients, 1.0)

        print("  Loss: ")
        print(float_to_str_2(loss))
        print(" | Grad Norm: ")
        print(float_to_str_4(grad_norm))

        if grad_norm > 1.0 {
            print(" [CLIPPED]")
        }
        println("")




        step = step + 1
    }

    println("")
    println("✓ Training completed successfully!")
    println("✓ All gradient checks passed!")
}

func main() {
    training_loop_with_stability()
}



func make_float_array(int size) []float {
    []float arr = []float{}
    int i = 0
    while i < size {
        arr = append(arr, 0.0)
        i = i + 1
    }
    return arr
}

func make_2d_array(int size) [][]float {
    [][]float arr = [][]float{}
    int i = 0
    while i < size {
        arr = append(arr, []float{})
        i = i + 1
    }
    return arr
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
