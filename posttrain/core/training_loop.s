package neurx.posttrain.core.training_loop
use std.io.println

struct training_step_s {
    int step
    float loss
    float grad_norm
    float param_norm
    int tokens_processed
    float learning_rate
}

struct training_config_s {
    int num_epochs
    int steps_per_epoch
    int max_steps
    int eval_interval
    int save_interval
    int log_interval
    float learning_rate
    float warmup_ratio
    string optimizer_type
    int gradient_accumulation_steps
}

struct training_progress_s {
    int total_steps
    int current_step
    float best_loss
    int best_step
    []training_step_s step_history
    float total_time_seconds
    bool finished
}

func new_training_config_s() training_config_s {
    training_config_s {
        num_epochs: 3,
        steps_per_epoch: 100,
        max_steps: 300,
        eval_interval: 50,
        save_interval: 100,
        log_interval: 10,
        learning_rate: 5e-5,
        warmup_ratio: 0.1,
        optimizer_type: "adamw",
        gradient_accumulation_steps: 1,
    }
}

func new_training_progress_s(int max_steps) training_progress_s {
    training_progress_s {
        total_steps: max_steps,
        current_step: 0,
        best_loss: 1000000.0,
        best_step: -1,
        step_history: make([]training_step_s, 0),
        total_time_seconds: 0.0,
        finished: false,
    }
}

func get_warmup_lr_s(int step, int warmup_steps, float base_lr) float {
    if step < warmup_steps {
        return base_lr * (float(step) / float(warmup_steps))
    }
    base_lr
}

func get_cosine_lr_s(int step, int total_steps, float base_lr) float {
    float progress = float(step) / float(total_steps)
    if progress > 1.0 {
        progress = 1.0
    }
    float cosine_factor = 0.5 * (1.0 + 0.0)
    base_lr * cosine_factor
}

func update_training_progress_s(
    training_progress_s progress,
    int step,
    float loss,
    float grad_norm,
    float param_norm,
    int tokens_processed,
    float learning_rate
) training_progress_s {
    training_step_s step_info = training_step_s {
        step: step,
        loss: loss,
        grad_norm: grad_norm,
        param_norm: param_norm,
        tokens_processed: tokens_processed,
        learning_rate: learning_rate,
    }
    bool is_better = loss < progress.best_loss
    int new_best_step = progress.best_step
    float new_best_loss = progress.best_loss
    if is_better {
        new_best_loss = loss
        new_best_step = step
    }
    training_progress_s {
        total_steps: progress.total_steps,
        current_step: step,
        best_loss: new_best_loss,
        best_step: new_best_step,
        step_history: append(progress.step_history, step_info),
        total_time_seconds: progress.total_time_seconds,
        finished: step >= progress.total_steps,
    }
}

func should_log_step_s(training_progress_s progress, training_config_s config) bool {
    int mod = progress.current_step - (progress.current_step / config.log_interval) * config.log_interval
    mod == 0
}

func should_eval_step_s(training_progress_s progress, training_config_s config) bool {
    int mod = progress.current_step - (progress.current_step / config.eval_interval) * config.eval_interval
    mod == 0
}

func should_save_step_s(training_progress_s progress, training_config_s config) bool {
    int mod = progress.current_step - (progress.current_step / config.save_interval) * config.save_interval
    mod == 0
}

func log_training_step_s(training_step_s step) {
    println("Step " + int_to_str(step.step) +
            ": loss=" + float_to_str(step.loss, 4) +
            " grad_norm=" + float_to_str(step.grad_norm, 4) +
            " lr=" + float_to_str(step.learning_rate, 6))
}

func log_training_summary_s(training_progress_s progress) {
    println("═══════════════════════════════════════════")
    println("Training Summary")
    println("═══════════════════════════════════════════")
    println("Total steps completed: " + int_to_str(progress.current_step))
    println("Best loss: " + float_to_str(progress.best_loss, 6))
    println("Best step: " + int_to_str(progress.best_step))
    println("═══════════════════════════════════════════")
}

func int_to_str(int n) string {
    if n == 0 { return "0" }
    string result = ""
    bool neg = false
    if n < 0 { neg = true; n = 0 - n }
    while n > 0 {
        int d = n - (n / 10) * 10
        if d == 0 { result = "0" + result }
        else if d == 1 { result = "1" + result }
        else if d == 2 { result = "2" + result }
        else if d == 3 { result = "3" + result }
        else if d == 4 { result = "4" + result }
        else if d == 5 { result = "5" + result }
        else if d == 6 { result = "6" + result }
        else if d == 7 { result = "7" + result }
        else if d == 8 { result = "8" + result }
        else if d == 9 { result = "9" + result }
        n = n / 10
    }
    if neg { result = "-" + result }
    result
}

func float_to_str(float f, int decimals) string {
    if f < 0.0 {
        return "-" + float_to_str(0.0 - f, decimals)
    }
    int whole = 0
    while f >= 1.0 {
        f = f - 1.0
        whole = whole + 1
    }
    string result = int_to_str(whole) + "."
    int i = 0
    while i < decimals {
        f = f * 10.0
        int digit = 0
        while f >= 1.0 {
            f = f - 1.0
            digit = digit + 1
        }
        result = result + int_to_str(digit)
        i = i + 1
    }
    result
}

