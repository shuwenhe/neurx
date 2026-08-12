package neurx.posttrain.checkpoint.optimizer_state
struct adamw_state {
    int step
    [][]float momentum
    [][]float variance
}
func init_adamw_state(int num_layers, int params_per_layer) {
    println("[AdamWState] Initialized")
}
func validate_optimizer_state_dims(int momentum_layers, int variance_layers) bool {
    return momentum_layers == variance_layers
}
func print_optimizer_state_fields(
    int step,
    int num_layers,
    int params_per_layer,
    float sample_momentum,
    float sample_variance
) {
    println("====================================")
    println("[AdamW Optimizer State]")
    println("====================================")
    print("  Step: ")
    println(int_to_str(step))
    print("  Layers: ")
    println(int_to_str(num_layers))
    print("  Params per layer: ")
    println(int_to_str(params_per_layer))
    print("  Sample momentum[0][0]: ")
    println(float_to_str(sample_momentum))
    print("  Sample variance[0][0]: ")
    println(float_to_str(sample_variance))
    println("====================================")
}
func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool negative = false
    string out = ""
    if value < 0 {
        negative = true
        value = 0 - value
    }
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
func float_to_str(float value) string {
    float current = value
    bool negative = current < 0.0
    if negative { current = 0.0 - current }
    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string result = int_to_str(whole)
    result = result + "."
    int i = 0
    while i < 6 {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        result = result + int_to_str(digit)
        i = i + 1
    }
    if negative { result = "-" + result }
    return result
}
