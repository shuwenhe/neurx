package main
use neurx.posttrain.training.stability.{clip_all_gradients, check_grads_healthy}
use neurx.posttrain.training.metrics.{
    print_metrics_inline,
    print_training_summary,
    compute_perplexity,
    compute_accuracy
}
use neurx.posttrain.training.accuracy.{argmax, accuracy_percentage}

func main() {
    println("====================================================")
    println("[Phase 2B] Complete Training Infrastructure")
    println("====================================================")
    println("Components:")
    println("  ✓ Gradient Stability Layer")
    println("  ✓ Metrics Collection System")
    println("  ✓ Token Accuracy Tracking")
    println("")
    println("Training Configuration:")
    println("  Epochs: 3")
    println("  Steps per Epoch: 100")
    println("  Max Gradient Norm: 1.0")
    println("")
    float loss
    int epoch
    int total_steps
    int total_tokens
    int correct_tokens
    int total_clips
    loss = 0.0
    loss = loss + 10.0
    epoch = 0
    total_steps = 0
    total_tokens = 0
    correct_tokens = 0
    total_clips = 0
    while epoch < 3 {
        println("====================================================")
        println("[Epoch " + int_to_str(epoch + 1) + "/3]")
        println("====================================================")
        int step
        step = 0
        while step < 100 {
            total_steps = total_steps + 1
            step = step + 1
            loss = loss - 0.08
            if loss < 0.5 { loss = 0.5 }
            []float layer1_grad
            []float layer2_grad
            int i
            i = 0
            while i < 10 {
                float grad_val
                grad_val = 0.5 + ((total_steps + i) as float) * 0.01
                if total_steps == (total_steps / 50) * 50 {
                    grad_val = grad_val * 3.0
                }
                layer1_grad = append(layer1_grad, grad_val)
                layer2_grad = append(layer2_grad, grad_val * 0.8)
                i = i + 1
            }
            [][]float gradients
            gradients = append(gradients, layer1_grad)
            gradients = append(gradients, layer2_grad)
            bool grads_healthy
            grads_healthy = check_grads_healthy(gradients)
            if !grads_healthy {
                println("[ABORT] NaN/Inf detected at step " + int_to_str(total_steps))
                return
            }
            float grad_norm
            grad_norm = clip_all_gradients(gradients, 1.0)
            if grad_norm > 1.0 {
                total_clips = total_clips + 1
            }
            int step_correct
            int step_total
            step_correct = 400 + total_steps / 3
            step_total = 512
            correct_tokens = correct_tokens + step_correct
            total_tokens = total_tokens + step_total
            float perplexity
            float accuracy
            float lr
            perplexity = compute_perplexity(loss)
            accuracy = compute_accuracy(step_correct, step_total)
            lr = 0.0005 * (1.0 - ((total_steps as float) / 300.0))
            if step == 10 || step == 20 || step == 50 || step == 100 {
                print_metrics_inline(
                    total_steps,
                    loss,
                    perplexity,
                    accuracy,
                    grad_norm,
                    lr
                )
            }
        }
        epoch = epoch + 1
        println("")
    }
    println("")
    print_training_summary(
        total_steps,
        loss,
        compute_perplexity(loss),
        total_tokens,
        correct_tokens
    )
    println("")
    println("====================================================")
    println("[Training Infrastructure Statistics]")
    println("====================================================")
    println("Gradient Clips Applied: " + int_to_str(total_clips))
    float clip_rate
    clip_rate = (total_clips as float) / (total_steps as float) * 100.0
    println("Clipping Rate: " + float_to_str_2(clip_rate) + "%")
    println("NaN/Inf Detections: 0 (Training Stable ✓)")
    println("")
    println("[✓] Phase 2B Step 2 Complete: Observability Enabled")
    println("")
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
    while i < 2 {
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

