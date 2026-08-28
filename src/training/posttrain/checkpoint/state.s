package neurx.posttrain.checkpoint.state
struct trainer_state {
    int step
    int epoch
    int global_tokens
    int samples_seen
    float best_loss
    float last_loss
    float wall_time
    int last_checkpoint_step
}

func init_trainer_state(int dummy) {
    println("[TrainerState] Initialized with defaults")
}

func print_trainer_state_fields(
    int step,
    int epoch,
    int global_tokens,
    int samples_seen,
    float best_loss,
    float last_loss,
    float wall_time,
    int last_checkpoint_step
) {
    println("====================================")
    println("[Trainer State]")
    println("====================================")
    print("  Step: ")
    println(int_to_str(step))
    print("  Epoch: ")
    println(int_to_str(epoch))
    print("  Global Tokens: ")
    println(int_to_str(global_tokens))
    print("  Samples Seen: ")
    println(int_to_str(samples_seen))
    print("  Best Loss: ")
    println(float_to_str(best_loss))
    print("  Last Loss: ")
    println(float_to_str(last_loss))
    print("  Wall Time: ")
    print(float_to_str(wall_time))
    println(" seconds")
    print("  Last Checkpoint Step: ")
    println(int_to_str(last_checkpoint_step))
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
    for value > 0 {
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
    for current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string result = int_to_str(whole)
    result = result + "."
    int i = 0
    for i < 4 {
        current = current * 10.0
        int digit = 0
        for current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        result = result + int_to_str(digit)
        i = i + 1
    }
    if negative { result = "-" + result }
    return result
}
