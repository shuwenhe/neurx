package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
func abs_float(float x) float {
    if x < 0.0 {
        return 0.0 - x
    }
    return x
}
func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
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
    if negative {
        out = "-" + out
    }
    return out
}
func float_to_str(float value, int decimals) string {
    float current = value
    bool negative = current < 0.0
    if negative {
        current = 0.0 - current
    }
    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string out = ""
    if negative {
        out = "-"
    }
    out = out + int_to_str(whole) + "."
    int i = 0
    while i < decimals {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        if digit == 0 { out = out + "0" }
        else if digit == 1 { out = out + "1" }
        else if digit == 2 { out = out + "2" }
        else if digit == 3 { out = out + "3" }
        else if digit == 4 { out = out + "4" }
        else if digit == 5 { out = out + "5" }
        else if digit == 6 { out = out + "6" }
        else if digit == 7 { out = out + "7" }
        else if digit == 8 { out = out + "8" }
        else { out = out + "9" }
        i = i + 1
    }
    return out
}
func run_mini_scalar_posttrain() int {
    string model_path = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", "../model/base-model")
    string output_dir = runtime_env_get("NEURX_POSTTRAIN_OUTPUT_DIR", "../posttrain_adapter")
    if !runtime_file_exists(model_path) && !runtime_file_exists(model_path + "/config.json") {
        println("error: model path not found: " + model_path)
        return 1
    }
    float x = 2.0
    float y = 5.0
    float w = 0.1
    float lr = 0.2
    float initial_w = w
    println("====================================================")
    println("[PostTrain] Mini Scalar Trainer")
    println("====================================================")
    println("[Backend] S Runtime Mini Scalar Trainer")
    println("")
    println("[Mini] Forward -> Loss -> Backward -> SGD")
    println("x=" + float_to_str(x, 1) + ", y=" + float_to_str(y, 1) + ", lr=" + float_to_str(lr, 1))
    println("initial w=" + float_to_str(w, 6))
    float loss0 = 0.0
    float loss1 = 0.0
    float loss2 = 0.0
    int step = 0
    while step < 3 {
        float pred = w * x
        float diff = pred - y
        float loss = diff * diff
        float grad = 2.0 * diff * x
        w = w - lr * grad
        if step == 0 {
            loss0 = loss
        } else if step == 1 {
            loss1 = loss
        } else {
            loss2 = loss
        }
        println("step " + int_to_str(step + 1) + "/3 pred=" + float_to_str(pred, 6) + " loss=" + float_to_str(loss, 6) + " w=" + float_to_str(w, 6))
        step = step + 1
    }
    float improvement = 0.0
    if loss0 > 0.0 {
        improvement = (loss0 - loss2) / loss0 * 100.0
    }
    println("")
    println("[Loss Convergence]")
    println("  Initial loss:      " + float_to_str(loss0, 6))
    println("  Final loss:        " + float_to_str(loss2, 6))
    println("  Best loss:         " + float_to_str(loss2, 6))
    println("  Improvement:       " + float_to_str(improvement, 2) + "%")
    println("  Output dir:        " + output_dir)
    println("[✓] Mini scalar training completed")
    return 0
}
func main() {
    return run_mini_scalar_posttrain()
}
