package neurx.posttrain.training.metrics

func record_loss(float loss) float {
    return compute_perplexity(loss)
}

func record_accuracy(int correct, int total) float {
    return compute_accuracy(correct, total)
}

func record_grad_norm(float grad_norm) float {
    return grad_norm
}

func record_learning_rate(float lr) float {
    return lr
}

func argmax([]float logits) int {
    if len(logits) == 0 { return 0 }
    int max_idx = 0
    float max_val = logits[0]
    int i = 1
    while i < len(logits) {
        if logits[i] > max_val {
            max_val = logits[i]
            max_idx = i
        }
        i = i + 1
    }
    return max_idx
}

func compute_accuracy(int correct, int total) float {
    if total == 0 { return 0.0 }
    return (correct as float) / (total as float) * 100.0
}

func compute_perplexity(float loss) float {
    return exp_approx(loss)
}

func exp_approx(float x) float {
    if x > 10.0 { return 22026.0 }
    if x < 0.0 - 10.0 { return 0.0 }
    float result = 1.0
    float term = 1.0
    int n = 1
    while n <= 10 {
        term = term * x / (n as float)
        result = result + term
        n = n + 1
    }
    return result
}

func print_metrics_inline(
    int step,
    float loss,
    float perplexity,
    float accuracy,
    float grad_norm,
    float learning_rate
) {
    print("[Step ")
    print(int_to_str(step))
    print("] Loss: ")
    print(float_to_str_4(loss))
    print(" | PPL: ")
    print(float_to_str_2(perplexity))
    print(" | Acc: ")
    print(float_to_str_2(accuracy))
    print("% | Grad: ")
    print(float_to_str_4(grad_norm))
    print(" | LR: ")
    print(float_to_str_6(learning_rate))
    println("")
}

func print_metrics_detailed(
    int step,
    int epoch,
    float loss,
    float perplexity,
    float accuracy,
    float grad_norm,
    float learning_rate,
    int total_tokens,
    int correct_tokens
) {
    println("====================================")
    println("[Training Metrics]")
    println("====================================")
    println("  Step: " + int_to_str(step))
    println("  Epoch: " + int_to_str(epoch))
    println("  Loss: " + float_to_str_4(loss))
    println("  Perplexity: " + float_to_str_2(perplexity))
    println("  Token Accuracy: " + float_to_str_2(accuracy) + "%")
    println("  Gradient Norm: " + float_to_str_4(grad_norm))
    println("  Learning Rate: " + float_to_str_6(learning_rate))
    println("  Total Tokens: " + int_to_str(total_tokens))
    println("  Correct Tokens: " + int_to_str(correct_tokens))
    println("====================================")
}

func print_training_summary(
    int total_steps,
    float final_loss,
    float final_perplexity,
    int total_tokens,
    int correct_tokens
) {
    println("")
    println("====================================")
    println("[Training Summary]")
    println("====================================")
    println("Final Loss: " + float_to_str_4(final_loss))
    println("Final Perplexity: " + float_to_str_2(final_perplexity))
    float overall_accuracy = (correct_tokens as float) / (total_tokens as float) * 100.0
    println("Overall Token Accuracy: " + float_to_str_2(overall_accuracy) + "%")
    println("Total Steps: " + int_to_str(total_steps))
    println("Total Tokens Processed: " + int_to_str(total_tokens))
    println("====================================")
}

func print_metrics_header() {
    println("")
    println("====================================")
    println("[Training Metrics Header]")
    println("====================================")
    println("Format: [Step N] Loss | PPL | Acc% | Grad | LR")
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

func float_to_str_2(float value) string {
    return float_to_str_n(value, 2)
}

func float_to_str_4(float value) string {
    return float_to_str_n(value, 4)
}

func float_to_str_6(float value) string {
    return float_to_str_n(value, 6)
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

