package main
use neurx.posttrain.training.stability.{clip_all_gradients, check_grads_healthy}
use neurx.posttrain.training.metrics.{
    create_metrics,
    update_step,
    update_epoch,
    update_loss,
    update_accuracy,
    update_grad_norm,
    update_learning_rate,
    print_metrics_inline,
    print_metrics_summary,
    train_metrics
}
use neurx.posttrain.training.accuracy.{compute_token_accuracy, accuracy_percentage}

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
    train_metrics metrics
    metrics = create_metrics()
    float loss = 10.0
    int epoch = 0
    int total_steps = 0
    int total_clips = 0
    for epoch < 3 {
        println("====================================================")
        println("[Epoch " + int_to_str(epoch + 1) + "/3]")
        println("====================================================")
        metrics = update_epoch(metrics, epoch + 1)
        int step = 0
        for step < 100 {
            total_steps = total_steps + 1
            step = step + 1
            loss = loss - 0.08
            if loss < 0.5 { loss = 0.5 }
            []float layer1_grad
            []float layer2_grad
            int i = 0
            for i < 10 {
                float grad_val = 0.5 + ((total_steps + i) as float) * 0.01
                if total_steps == (total_steps / 50) * 50 {
                    grad_val = grad_val * 3.0
                }
                layer1_grad = append(layer1_grad, grad_val)
                layer2_grad = append(layer2_grad, grad_val * 0.8)
                i = i + 1
            }
            []float[] gradients
            gradients = append(gradients, layer1_grad)
            gradients = append(gradients, layer2_grad)
            bool grads_healthy = check_grads_healthy(gradients)
            if !grads_healthy {
                println("[ABORT] NaN/Inf detected at step " + int_to_str(total_steps))
                return
            }
            float grad_norm = clip_all_gradients(gradients, 1.0)
            if grad_norm > 1.0 {
                total_clips = total_clips + 1
            }
            int correct_tokens = 400 + total_steps / 3
            int total_tokens = 512
            metrics = update_step(metrics, total_steps)
            metrics = update_loss(metrics, loss)
            metrics = update_accuracy(metrics, correct_tokens, total_tokens)
            metrics = update_grad_norm(metrics, grad_norm)
            float lr = 0.0005 * (1.0 - ((total_steps as float) / 300.0))
            metrics = update_learning_rate(metrics, lr)
            if step == 10 || step == 20 || step == 50 || step == 100 {
                print_metrics_inline(metrics)
            }
        }
        epoch = epoch + 1
        println("")
    }
    println("")
    print_metrics_summary(metrics)
    println("")
    println("====================================================")
    println("[Training Infrastructure Statistics]")
    println("====================================================")
    println("Gradient Clips Applied: " + int_to_str(total_clips))
    float clip_rate = (total_clips as float) / (total_steps as float) * 100.0
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

func float_to_str_2(float value) string {
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
    for i < 2 {
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
