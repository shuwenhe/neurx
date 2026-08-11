package neurx.posttrain.checkpoint.scheduler_state
struct scheduler_state {
    int step
    int warmup_steps
    float max_lr
    float min_lr
    string schedule_type
}
func init_scheduler_state(
    int warmup_steps,
    float max_lr,
    float min_lr
) {
    println("[SchedulerState] Initialized")
    print("  Warmup: ")
    println(int_to_str(warmup_steps))
    print("  Max LR: ")
    println(float_to_str(max_lr))
    print("  Min LR: ")
    println(float_to_str(min_lr))
}
func compute_learning_rate(
    int current_step,
    int warmup_steps,
    float max_lr,
    float min_lr,
    string schedule_type,
    int total_steps
) float {
    if current_step < warmup_steps {
        float warmup_progress = (current_step as float) / (warmup_steps as float)
        return max_lr * warmup_progress
    }
    if schedule_type == "constant" {
        return max_lr
    }
    if schedule_type == "linear" {
        int decay_steps = total_steps - warmup_steps
        int steps_after_warmup = current_step - warmup_steps
        if decay_steps <= 0 { return max_lr }
        float decay_progress = (steps_after_warmup as float) / (decay_steps as float)
        if decay_progress > 1.0 { decay_progress = 1.0 }
        return max_lr - (max_lr - min_lr) * decay_progress
    }
    int decay_steps = total_steps - warmup_steps
    int steps_after_warmup = current_step - warmup_steps
    if decay_steps <= 0 { return max_lr }
    float progress = (steps_after_warmup as float) / (decay_steps as float)
    if progress > 1.0 { progress = 1.0 }
    float pi = 3.14159265359
    float cosine_term = cos_approx(pi * progress)
    float cosine_factor = 0.5 * (1.0 + cosine_term)
    return min_lr + (max_lr - min_lr) * cosine_factor
}
func print_scheduler_state_fields(
    int step,
    int warmup_steps,
    float max_lr,
    float min_lr,
    string schedule_type,
    float current_lr
) {
    println("====================================")
    println("[Learning Rate Scheduler State]")
    println("====================================")
    print("  Step: ")
    println(int_to_str(step))
    print("  Warmup Steps: ")
    println(int_to_str(warmup_steps))
    print("  Max LR: ")
    println(float_to_str(max_lr))
    print("  Min LR: ")
    println(float_to_str(min_lr))
    print("  Schedule Type: ")
    println(schedule_type)
    print("  Current LR: ")
    println(float_to_str(current_lr))
    println("====================================")
}
func cos_approx(float x) float {
    float pi = 3.14159265359
    float normalized = x
    while normalized > pi {
        normalized = normalized - 2.0 * pi
    }
    while normalized < 0.0 - pi {
        normalized = normalized + 2.0 * pi
    }
    float x2 = normalized * normalized
    float x4 = x2 * x2
    float x6 = x4 * x2
    float x8 = x6 * x2
    float result = 1.0
    result = result - x2 / 2.0
    result = result + x4 / 24.0
    result = result - x6 / 720.0
    result = result + x8 / 40320.0
    return result
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
    while i < 8 {
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
