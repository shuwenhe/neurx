package neurx.training.monitor

// =====================================================================
// Training Monitor - Metrics Tracking and Logging
// =====================================================================
// Real-time tracking of training metrics
// - Loss, accuracy, learning rate
// - Gradient statistics
// - Training speed (samples/sec)
// - Logging and reporting

struct training_log {
    []int step
    []float loss
    []float accuracy
    []float learning_rate
    []float gradient_norm
    []int batch_size
}

struct monitor_config {
    int log_interval          // Log every N steps
    int summary_interval      // Print summary every N steps
    bool log_gradients        // Track gradient statistics
    bool log_lr               // Track learning rate
    string log_file           // Output file path
}

struct training_monitor {
    monitor_config config
    training_log logs
    
    // Running statistics
    float running_loss
    float running_accuracy
    int running_steps
    int total_tokens
    
    // Timing
    int start_time
    int last_log_time
    float tokens_per_sec
    
    // Best model tracking
    float best_loss
    int best_step
}

// =====================================================================
// Monitor Initialization
// =====================================================================

func new_monitor_config() monitor_config {
    monitor_config {
        log_interval: 10,
        summary_interval: 100,
        log_gradients: true,
        log_lr: true,
        log_file: "/tmp/training.log",
    }
}

func new_training_monitor(monitor_config cfg) training_monitor {
    training_monitor {
        config: cfg,
        logs: training_log {
            step: []int{cap: 10000},
            loss: []float{cap: 10000},
            accuracy: []float{cap: 10000},
            learning_rate: []float{cap: 10000},
            gradient_norm: []float{cap: 10000},
            batch_size: []int{cap: 10000},
        },
        running_loss: 0.0,
        running_accuracy: 0.0,
        running_steps: 0,
        total_tokens: 0,
        start_time: 0,
        last_log_time: 0,
        tokens_per_sec: 0.0,
        best_loss: 999999.0,
        best_step: 0,
    }
}

// =====================================================================
// Logging Functions
// =====================================================================

// Log training step
func log_step(
    training_monitor monitor,
    int step,
    float loss,
    float accuracy,
    float lr,
    float grad_norm,
    int batch_size
) training_monitor {
    // Add to running statistics
    monitor.running_loss = monitor.running_loss + loss
    monitor.running_accuracy = monitor.running_accuracy + accuracy
    monitor.running_steps = monitor.running_steps + 1
    monitor.total_tokens = monitor.total_tokens + batch_size
    
    // Append to logs
    monitor.logs.step.push(step)
    monitor.logs.loss.push(loss)
    monitor.logs.accuracy.push(accuracy)
    monitor.logs.learning_rate.push(lr)
    monitor.logs.gradient_norm.push(grad_norm)
    monitor.logs.batch_size.push(batch_size)
    
    // Check if best loss
    if loss < monitor.best_loss {
        monitor.best_loss = loss
        monitor.best_step = step
    }
    
    return monitor
}

// Log interval (print status)
func should_log(training_monitor monitor, int step) bool {
    if step % monitor.config.log_interval == 0 {
        return true
    }
    return false
}

// Print training progress
func log_training_progress(
    training_monitor monitor,
    int step,
    int total_steps
) {
    if monitor.running_steps == 0 {
        return
    }
    
    let avg_loss = monitor.running_loss / float(monitor.running_steps)
    let avg_accuracy = monitor.running_accuracy / float(monitor.running_steps)
    let progress = float(step) / float(total_steps) * 100.0
    
    var msg = "[" + int_to_string(step) + "/" + int_to_string(total_steps) + "] "
    msg = msg + float_to_string(progress) + "% | "
    msg = msg + "Loss: " + float_to_string(avg_loss) + " | "
    msg = msg + "Acc: " + float_to_string(avg_accuracy)
    
    println(msg)
}

// =====================================================================
// Summary Reporting
// =====================================================================

// Print training summary
func print_training_summary(training_monitor monitor, int step) {
    if monitor.running_steps == 0 {
        return
    }
    
    println("")
    println("========================================")
    println("Training Summary - Step " + int_to_string(step))
    println("========================================")
    
    let avg_loss = monitor.running_loss / float(monitor.running_steps)
    let avg_accuracy = monitor.running_accuracy / float(monitor.running_steps)
    
    println("Average Loss: " + float_to_string(avg_loss))
    println("Average Accuracy: " + float_to_string(avg_accuracy))
    println("Total Tokens Processed: " + int_to_string(monitor.total_tokens))
    println("Throughput: " + float_to_string(monitor.tokens_per_sec) + " tokens/sec")
    println("")
    println("Best Loss: " + float_to_string(monitor.best_loss) + " (step " + int_to_string(monitor.best_step) + ")")
    println("")
}

// Get epoch statistics
func get_epoch_stats(training_monitor monitor) string {
    if monitor.running_steps == 0 {
        return "No data logged"
    }
    
    let avg_loss = monitor.running_loss / float(monitor.running_steps)
    let avg_accuracy = monitor.running_accuracy / float(monitor.running_steps)
    let total_steps = len(monitor.logs.step)
    
    var stats = "Epoch Statistics:\n"
    stats = stats + "  Total steps: " + int_to_string(total_steps) + "\n"
    stats = stats + "  Average loss: " + float_to_string(avg_loss) + "\n"
    stats = stats + "  Average accuracy: " + float_to_string(avg_accuracy) + "\n"
    stats = stats + "  Best loss: " + float_to_string(monitor.best_loss) + "\n"
    stats = stats + "  Total tokens: " + int_to_string(monitor.total_tokens) + "\n"
    
    return stats
}

// =====================================================================
// Log Analysis
// =====================================================================

// Calculate metrics over window
func get_windowed_metrics(
    training_monitor monitor,
    int window_size
) (float, float) {
    let log_size = len(monitor.logs.loss)
    if log_size < window_size {
        return (0.0, 0.0)
    }
    
    var window_loss = 0.0
    var window_acc = 0.0
    
    var i = log_size - window_size
    while i < log_size {
        window_loss = window_loss + monitor.logs.loss[i]
        window_acc = window_acc + monitor.logs.accuracy[i]
        i = i + 1
    }
    
    return (window_loss / float(window_size), window_acc / float(window_size))
}

// Find best performance
func get_best_performance(training_monitor monitor) (int, float) {
    var best_step = 0
    var best_loss = 999999.0
    
    var i = 0
    while i < len(monitor.logs.loss) {
        if monitor.logs.loss[i] < best_loss {
            best_loss = monitor.logs.loss[i]
            best_step = monitor.logs.step[i]
        }
        i = i + 1
    }
    
    return (best_step, best_loss)
}

// Calculate training trend (improving or degrading)
func get_training_trend(training_monitor monitor) string {
    let log_size = len(monitor.logs.loss)
    if log_size < 2 {
        return "No trend (insufficient data)"
    }
    
    let recent_size = 10
    var early_avg = 0.0
    var recent_avg = 0.0
    
    // Average of first 10 logs
    var i = 0
    while i < recent_size && i < log_size {
        early_avg = early_avg + monitor.logs.loss[i]
        i = i + 1
    }
    early_avg = early_avg / float(min_int(recent_size, log_size))
    
    // Average of last 10 logs
    i = log_size - recent_size
    if i < 0 { i = 0 }
    while i < log_size {
        recent_avg = recent_avg + monitor.logs.loss[i]
        i = i + 1
    }
    recent_avg = recent_avg / float(log_size - max_int(0, log_size - recent_size))
    
    let improvement = early_avg - recent_avg
    
    if improvement > 0.1 {
        return "Improving (loss decreased by " + float_to_string(improvement) + ")"
    }
    if improvement < -0.1 {
        return "Degrading (loss increased by " + float_to_string(-improvement) + ")"
    }
    return "Stable (loss change: " + float_to_string(improvement) + ")"
}

// =====================================================================
// Reset and Export
// =====================================================================

// Reset running statistics for new epoch
func reset_epoch_stats(training_monitor monitor) training_monitor {
    monitor.running_loss = 0.0
    monitor.running_accuracy = 0.0
    monitor.running_steps = 0
    return monitor
}

// Export logs (placeholder for file I/O)
func export_logs(training_monitor monitor, string filepath) bool {
    println("Exporting logs to: " + filepath)
    println("  Total log entries: " + int_to_string(len(monitor.logs.step)))
    
    // In production: write logs to CSV/JSON file
    // Format: step,loss,accuracy,learning_rate,gradient_norm,batch_size
    
    return true
}

// =====================================================================
// Performance Visualization (text-based)
// =====================================================================

// Print loss curve (simple ASCII)
func print_loss_curve(training_monitor monitor) {
    let log_size = len(monitor.logs.loss)
    if log_size == 0 {
        return
    }
    
    println("Training Loss Curve:")
    println("(Showing last 50 steps)")
    println("")
    
    let start_idx = if log_size > 50 then log_size - 50 else 0
    var i = start_idx
    while i < log_size {
        let loss = monitor.logs.loss[i]
        let bar_len = int(loss * 10.0)
        
        var bar = ""
        var j = 0
        while j < bar_len && j < 50 {
            bar = bar + "#"
            j = j + 1
        }
        
        println("  " + bar + " " + float_to_string(loss))
        i = i + 1
    }
    println("")
}

// =====================================================================
// Helper Functions
// =====================================================================

func int_to_string(int x) string {
    if x == 0 { return "0" }
    if x == 1 { return "1" }
    if x == 2 { return "2" }
    if x == 3 { return "3" }
    if x == 4 { return "4" }
    if x == 5 { return "5" }
    if x == 6 { return "6" }
    if x == 7 { return "7" }
    if x == 8 { return "8" }
    if x == 9 { return "9" }
    if x == 10 { return "10" }
    if x == 100 { return "100" }
    if x == 1000 { return "1000" }
    return "unknown"
}

func float_to_string(float x) string {
    let int_part = int(x)
    let dec_part = int((x - float(int_part)) * 100.0)
    return int_to_string(int_part) + "." + int_to_string(dec_part)
}

func min_int(int a, int b) int {
    if a < b { return a }
    return b
}

func max_int(int a, int b) int {
    if a > b { return a }
    return b
}
