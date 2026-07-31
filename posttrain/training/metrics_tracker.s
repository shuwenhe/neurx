
package neurx.posttrain.training.metrics_tracker




struct TrainingMetrics {

    []float losses
    []float learning_rates
    []float gradient_norms


    []float train_accuracies
    []float token_accuracies


    []float grad_means
    []float grad_stds
    []float grad_sparsities


    []float tokens_per_sec
    []float samples_per_sec
    []float step_times


    []float perplexities
    []int nan_counts
    []int clip_counts


    int total_steps
    int current_epoch
    float best_loss
    int best_step
}


func new_metrics_tracker() TrainingMetrics {
    TrainingMetrics m = TrainingMetrics{}

    m.losses = []float{}
    m.learning_rates = []float{}
    m.gradient_norms = []float{}
    m.train_accuracies = []float{}
    m.token_accuracies = []float{}
    m.grad_means = []float{}
    m.grad_stds = []float{}
    m.grad_sparsities = []float{}
    m.tokens_per_sec = []float{}
    m.samples_per_sec = []float{}
    m.step_times = []float{}
    m.perplexities = []float{}
    m.nan_counts = []int{}
    m.clip_counts = []int{}

    m.total_steps = 0
    m.current_epoch = 0
    m.best_loss = 1000000.0
    m.best_step = 0

    return m
}


struct StepMetrics {
    float loss
    float learning_rate
    float gradient_norm
    float train_accuracy
    float token_accuracy
    float grad_mean
    float grad_std
    float grad_sparsity
    float tokens_per_sec
    float step_time
    float perplexity
    int nan_count
    bool was_clipped
}

func (m *TrainingMetrics) record_step(StepMetrics metrics) {

    m.losses = append(m.losses, metrics.loss)
    m.learning_rates = append(m.learning_rates, metrics.learning_rate)
    m.gradient_norms = append(m.gradient_norms, metrics.gradient_norm)


    m.train_accuracies = append(m.train_accuracies, metrics.train_accuracy)
    m.token_accuracies = append(m.token_accuracies, metrics.token_accuracy)


    m.grad_means = append(m.grad_means, metrics.grad_mean)
    m.grad_stds = append(m.grad_stds, metrics.grad_std)
    m.grad_sparsities = append(m.grad_sparsities, metrics.grad_sparsity)


    m.tokens_per_sec = append(m.tokens_per_sec, metrics.tokens_per_sec)
    m.step_times = append(m.step_times, metrics.step_time)


    m.perplexities = append(m.perplexities, metrics.perplexity)
    m.nan_counts = append(m.nan_counts, metrics.nan_count)

    int clip_val = 0
    if metrics.was_clipped { clip_val = 1 }
    m.clip_counts = append(m.clip_counts, clip_val)


    m.total_steps = m.total_steps + 1


    if metrics.loss < m.best_loss {
        m.best_loss = metrics.loss
        m.best_step = m.total_steps
    }
}


func compute_recent_average([]float values, int window_size) float {
    int n = len(values)
    if n == 0 { return 0.0 }

    int start = 0
    if n > window_size {
        start = n - window_size
    }

    float sum = 0.0
    int count = 0
    int i = start
    while i < n {
        sum = sum + values[i]
        count = count + 1
        i = i + 1
    }

    if count == 0 { return 0.0 }
    return sum / ((count as float))
}


struct MetricsSummary {

    float avg_loss
    float avg_learning_rate
    float avg_gradient_norm
    float avg_train_accuracy
    float avg_token_accuracy


    float avg_grad_mean
    float avg_grad_std
    float avg_grad_sparsity


    float avg_tokens_per_sec
    float avg_step_time


    float avg_perplexity
    int total_nan_detections
    int total_clips


    int total_steps
    int current_epoch
    float best_loss
    int best_step
    float loss_improvement
}

func (m *TrainingMetrics) get_summary(int window_size) MetricsSummary {
    MetricsSummary summary = MetricsSummary{}


    summary.avg_loss = compute_recent_average(m.losses, window_size)
    summary.avg_learning_rate = compute_recent_average(m.learning_rates, window_size)
    summary.avg_gradient_norm = compute_recent_average(m.gradient_norms, window_size)
    summary.avg_train_accuracy = compute_recent_average(m.train_accuracies, window_size)
    summary.avg_token_accuracy = compute_recent_average(m.token_accuracies, window_size)

    summary.avg_grad_mean = compute_recent_average(m.grad_means, window_size)
    summary.avg_grad_std = compute_recent_average(m.grad_stds, window_size)
    summary.avg_grad_sparsity = compute_recent_average(m.grad_sparsities, window_size)

    summary.avg_tokens_per_sec = compute_recent_average(m.tokens_per_sec, window_size)
    summary.avg_step_time = compute_recent_average(m.step_times, window_size)

    summary.avg_perplexity = compute_recent_average(m.perplexities, window_size)


    summary.total_nan_detections = sum_int_array(m.nan_counts)
    summary.total_clips = sum_int_array(m.clip_counts)


    summary.total_steps = m.total_steps
    summary.current_epoch = m.current_epoch
    summary.best_loss = m.best_loss
    summary.best_step = m.best_step


    int n = len(m.losses)
    if n >= window_size {
        float recent_avg = compute_recent_average(m.losses, window_size)


        float sum = 0.0
        int i = 0
        while i < window_size && i < n {
            sum = sum + m.losses[i]
            i = i + 1
        }
        float early_avg = sum / ((window_size as float))

        summary.loss_improvement = early_avg - recent_avg
    } else {
        summary.loss_improvement = 0.0
    }

    return summary
}


func print_metrics_summary(MetricsSummary summary) {
    println("=" * 60)
    println("[Training Metrics Summary]")
    println("=" * 60)


    println("[Loss & Learning]")
    print("  Avg Loss:         ")
    println(float_to_str_4(summary.avg_loss))
    print("  Avg LR:           ")
    println(float_to_str_6(summary.avg_learning_rate))
    print("  Best Loss:        ")
    print(float_to_str_4(summary.best_loss))
    print(" (Step ")
    print(int_to_str(summary.best_step))
    println(")")
    print("  Loss Improvement: ")
    println(float_to_str_4(summary.loss_improvement))


    println("")
    println("[Accuracy]")
    print("  Train Accuracy:   ")
    println(float_to_str_4(summary.avg_train_accuracy * 100.0) + "%")
    print("  Token Accuracy:   ")
    println(float_to_str_4(summary.avg_token_accuracy * 100.0) + "%")


    println("")
    println("[Gradient Health]")
    print("  Avg Grad Norm:    ")
    println(float_to_str_4(summary.avg_gradient_norm))
    print("  Avg Grad Mean:    ")
    println(float_to_str_6(summary.avg_grad_mean))
    print("  Avg Grad Std:     ")
    println(float_to_str_6(summary.avg_grad_std))
    print("  Avg Sparsity:     ")
    println(float_to_str_4(summary.avg_grad_sparsity * 100.0) + "%")
    print("  Total Clips:      ")
    println(int_to_str(summary.total_clips))
    print("  Total NaN Detect: ")
    println(int_to_str(summary.total_nan_detections))


    println("")
    println("[Performance]")
    print("  Avg Tokens/sec:   ")
    println(float_to_str_1(summary.avg_tokens_per_sec))
    print("  Avg Step Time:    ")
    println(float_to_str_4(summary.avg_step_time) + " sec")


    println("")
    println("[Model Quality]")
    print("  Avg Perplexity:   ")
    println(float_to_str_4(summary.avg_perplexity))


    println("")
    println("[Global Stats]")
    print("  Total Steps:      ")
    println(int_to_str(summary.total_steps))
    print("  Current Epoch:    ")
    println(int_to_str(summary.current_epoch))

    println("=" * 60)
}


func print_step_progress(int step, StepMetrics metrics) {
    print("[Step ")
    print(int_to_str(step))
    print("] Loss: ")
    print(float_to_str_4(metrics.loss))
    print(" | LR: ")
    print(float_to_str_6(metrics.learning_rate))
    print(" | Acc: ")
    print(float_to_str_2(metrics.train_accuracy * 100.0))
    print("% | Grad: ")
    print(float_to_str_4(metrics.gradient_norm))

    if metrics.was_clipped {
        print(" [CLIPPED]")
    }
    if metrics.nan_count > 0 {
        print(" [NaN!]")
    }

    println("")
}




func sum_int_array([]int arr) int {
    int sum = 0
    int i = 0
    while i < len(arr) {
        sum = sum + arr[i]
        i = i + 1
    }
    return sum
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

func float_to_str_1(float value) string {
    return float_to_str_n(value, 1)
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
