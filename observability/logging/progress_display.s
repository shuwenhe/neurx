package neurx.observability.logging

func print_progress_bar(
    training_metrics metrics,
    logger_config cfg
) {
    if !cfg.show_progress_bar { return }
    float percent = 0.0
    if metrics.total_steps > 0 {
        percent = float(metrics.global_step) / float(metrics.total_steps) * 100.0
    }
    int bar_width = 40
    int filled = int(percent / 100.0 * float(bar_width))
    if filled > bar_width { filled = bar_width }
    string bar = "["
    for i in 0..bar_width {
        if i < filled {
            bar = bar + "="
        } else if i == filled && percent < 100.0 {
            bar = bar + ">"
        } else {
            bar = bar + " "
        }
    }
    bar = bar + "]"
    string status_line = ""
    status_line = status_line + "Epoch " +
                   int_to_string(metrics.epoch + 1) + "/" +
                   int_to_string(metrics.total_epochs) + " | "
    status_line = status_line + bar + " "
    status_line = status_line + format_percent(percent, 5, 1) + "% | "
    status_line = status_line + "Step: " + int_to_string(metrics.global_step)
    if metrics.total_steps > 0 {
        status_line = status_line + "/" + int_to_string(metrics.total_steps)
    }
    status_line = status_line + " | "
    if len(metrics.recent_losses) > 0 {
        float smoothed = compute_rolling_average(metrics.recent_losses)
        status_line = status_line + "Loss: " +
                       format_float(smoothed, 6, 4) + " "
    }
    status_line = status_line + "(" + format_float(metrics.current_loss, 6, 4) + ")"
    if metrics.current_lr > 0.0 {
        status_line = status_line + " | LR: " +
                       format_scientific(metrics.current_lr)
    }
    if metrics.samples_per_second > 0.0 {
        status_line = status_line + " | " +
                       format_float(metrics.samples_per_second, 6, 1) + " samples/s"
    }
    if metrics.tokens_per_second > 0.0 {
        status_line = status_line + " (" +
                       format_float(metrics.tokens_per_second, 7, 0) + " tok/s)"
    }
    if metrics.avg_step_time > 0.0 && metrics.total_steps > metrics.global_step {
        int steps_remaining = metrics.total_steps - metrics.global_step
        float eta_seconds = float(steps_remaining) * metrics.avg_step_time
        status_line = status_line + " | ETA: " + format_duration(eta_seconds)
    }
    if metrics.gpu_memory_used_gb > 0.0 {
        status_line = status_line + " | GPU: " +
                       format_float(metrics.gpu_memory_used_gb, 4, 1) + "/" +
                       format_float(metrics.gpu_memory_total_gb, 4, 1) + " GB"
    }
    print_overwrite(status_line)
}
