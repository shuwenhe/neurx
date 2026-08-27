package neurx.trainer.monitor
import "neurx.arch.mps"

    DEBUG = 0
    INFO = 1
    WARN = 2
    ERROR = 3
    CRITICAL = 4
}

struct log_entry {
    timestamp: string
    level: log_level
    message: string
    step: int
    epoch: int
    loss: float
    metric: float
}

struct training_metrics {
    loss: float
    ppl: float
    accuracy: float
    lr: float
    throughput_samples: float
    throughput_tokens: float
    memory_usage: float
    grad_norm: float
    loss_scale: float
}

struct monitor_config {
    log_level: log_level
    log_file: string
    log_interval: int
    metrics_file: string
    metrics_interval: int
    enable_wandb: bool
    wandb_project: string
    wandb_entity: string
    enable_tensorboard: bool
    tensorboard_dir: string
    enable_progress_bar: bool
}

struct training_monitor {
    config: monitor_config
    logs: []log_entry
    metrics_history: [][]training_metrics
    current_metrics: training_metrics
    total_steps: int
    start_time: float
    step_times: []float
}

func new_monitor_config() monitor_config {
    monitor_config config {
        log_level: log_level.INFO,
        log_file: "./training.log",
        log_interval: 10,
        metrics_file: "./metrics.json",
        metrics_interval: 100,
        enable_wandb: false,
        wandb_project: "neurx-training",
        wandb_entity: "",
        enable_tensorboard: true,
        tensorboard_dir: "./tb_logs",
        enable_progress_bar: true,
    }
    config
}

func new_training_monitor(monitor_config config) training_monitor {
    training_monitor monitor {
        config: config,
        logs: []log_entry{},
        metrics_history: [][]training_metrics{},
        current_metrics: training_metrics{},
        total_steps: 0,
        start_time: current_time(),
        step_times: []float{},
    }
    monitor
}

func log_debug(training_monitor monitor, string message) training_monitor {
    monitor = add_log_entry(monitor, log_level.DEBUG, message)
    monitor
}

func log_info(training_monitor monitor, string message) training_monitor {
    monitor = add_log_entry(monitor, log_level.INFO, message)
    monitor
}

func log_warn(training_monitor monitor, string message) training_monitor {
    monitor = add_log_entry(monitor, log_level.WARN, message)
    monitor
}

func log_error(training_monitor monitor, string message) training_monitor {
    monitor = add_log_entry(monitor, log_level.ERROR, message)
    monitor
}

func log_critical(training_monitor monitor, string message) training_monitor {
    monitor = add_log_entry(monitor, log_level.CRITICAL, message)
    monitor
}

func add_log_entry(training_monitor monitor, log_level level, string message) training_monitor {
    if int(level) < int(monitor.config.log_level) {
        return monitor
    }
    log_entry entry {
        timestamp: current_timestamp(),
        level: level,
        message: message,
        step: 0,
        epoch: 0,
        loss: 0.0,
        metric: 0.0,
    }
    monitor.logs = append(monitor.logs, entry)
    print_log_entry(entry)
    if len(monitor.logs) > 10000 {
        monitor.logs = monitor.logs[1000..len(monitor.logs)]
    }
    monitor
}

func print_log_entry(log_entry entry) {
    string level_str = level_to_string(entry.level)
    string log = "[" + entry.timestamp + "] [" + level_str + "] " + entry.message
    print(log)
}

func level_to_string(log_level level) string {
    switch level {
        case log_level.DEBUG: return "DEBUG"
        case log_level.INFO: return "INFO"
        case log_level.WARN: return "WARN"
        case log_level.ERROR: return "ERROR"
        case log_level.CRITICAL: return "CRITICAL"
        default: return "UNKNOWN"
    }
}

func update_metrics(training_monitor monitor, training_metrics metrics) training_monitor {
    monitor.current_metrics = metrics
    monitor.total_steps = monitor.total_steps + 1
    if monitor.total_steps % monitor.config.metrics_interval == 0 {
        monitor.metrics_history = append(monitor.metrics_history, [metrics])
        save_metrics(monitor)
    }
    if monitor.config.enable_wandb {
        log_wandb(monitor, metrics)
    }
    if monitor.config.enable_tensorboard {
        log_tensorboard(monitor, metrics)
    }
    monitor
}

func save_metrics(training_monitor monitor) {
    string content = "["
    for i := 0; i < len(monitor.metrics_history); i += 1 {
        if i > 0 {
            content = content + ","
        }
        content = content + metrics_to_json(monitor.metrics_history[i][0])
    }
    content = content + "]"
}

func metrics_to_json(training_metrics metrics) string {
    string json = "{"
    json = json + "\"loss\":" + string(metrics.loss) + ","
    json = json + "\"ppl\":" + string(metrics.ppl) + ","
    json = json + "\"accuracy\":" + string(metrics.accuracy) + ","
    json = json + "\"lr\":" + string(metrics.lr) + ","
    json = json + "\"throughput_samples\":" + string(metrics.throughput_samples) + ","
    json = json + "\"throughput_tokens\":" + string(metrics.throughput_tokens) + ","
    json = json + "\"memory_usage\":" + string(metrics.memory_usage) + ","
    json = json + "\"grad_norm\":" + string(metrics.grad_norm) + ","
    json = json + "\"loss_scale\":" + string(metrics.loss_scale) + ""
    json = json + "}"
    json
}

func log_wandb(training_monitor monitor, training_metrics metrics) {
}

func log_tensorboard(training_monitor monitor, training_metrics metrics) {
}

func get_metrics_summary(training_monitor monitor) string {
    string summary = "Training Metrics Summary:\n"
    summary = summary + "Total Steps: " + string(monitor.total_steps) + "\n"
    summary = summary + "Elapsed Time: " + string(format_time(current_time() - monitor.start_time)) + "\n"
    summary = summary + "\nCurrent Metrics:\n"
    summary = summary + "  Loss: " + string(format_float(monitor.current_metrics.loss, 6)) + "\n"
    summary = summary + "  PPL: " + string(format_float(monitor.current_metrics.ppl, 4)) + "\n"
    summary = summary + "  Accuracy: " + string(format_float(monitor.current_metrics.accuracy, 4)) + "\n"
    summary = summary + "  Learning Rate: " + string(format_float(monitor.current_metrics.lr, 8)) + "\n"
    summary = summary + "  Throughput: " + string(format_float(monitor.current_metrics.throughput_samples, 2)) + " samples/s\n"
    summary = summary + "  Memory Usage: " + string(format_float(monitor.current_metrics.memory_usage, 2)) + " GB\n"
    summary = summary + "\nLog Count: " + string(len(monitor.logs))
    summary
}

func format_float(float x, int decimals) string {
    string s = string(x)
    int dot_pos = 0
    for i := 0; i < len(s); i += 1 {
        if s[i] == '.' {
            dot_pos = i
            break
        }
    }
    if dot_pos == 0 {
        return s + "." + make_string(decimals, '0')
    }
    int needed = dot_pos + decimals + 1
    if len(s) < needed {
        return s + make_string(needed - len(s), '0')
    }
    s[0..needed]
}

func format_time(float seconds) string {
    int hours = int(seconds / 3600)
    int minutes = int((seconds % 3600) / 60)
    int secs = int(seconds % 60)
    string h = if hours < 10 { "0" + string(hours) } else { string(hours) }
    string m = if minutes < 10 { "0" + string(minutes) } else { string(minutes) }
    string s = if secs < 10 { "0" + string(secs) } else { string(secs) }
    h + ":" + m + ":" + s
}

func make_string(int n, char c) string {
    string s = ""
    for i := 0; i < n; i += 1 {
        s = s + c
    }
    s
}

func log_training_step(training_monitor monitor, int step, int epoch, float loss, float lr) training_monitor {
    string message = "Step " + string(step) + " | Epoch " + string(epoch) +
                     " | Loss: " + format_float(loss, 6) +
                     " | LR: " + format_float(lr, 8)
    monitor = add_log_entry(monitor, log_level.INFO, message)
    monitor
}

func log_validation(training_monitor monitor, int step, float val_loss, float val_ppl) training_monitor {
    string message = "Validation | Step " + string(step) +
                     " | Loss: " + format_float(val_loss, 6) +
                     " | PPL: " + format_float(val_ppl, 4)
    monitor = add_log_entry(monitor, log_level.INFO, message)
    monitor
}

func log_checkpoint(training_monitor monitor, string path, int step) training_monitor {
    string message = "checkpoint saved: " + path + " (step " + string(step) + ")"
    monitor = add_log_entry(monitor, log_level.INFO, message)
    monitor
}

func log_device_info(training_monitor monitor, mps.mps_context ctx) training_monitor {
    for i := 0; i < len(ctx.devices); i += 1 {
        string info = mps.mps_get_device_info(ctx.devices[i])
        monitor = add_log_entry(monitor, log_level.INFO, info)
    }
    monitor
}

func log_config(training_monitor monitor, string config_str) training_monitor {
    monitor = add_log_entry(monitor, log_level.INFO, "Training Configuration:")
    monitor = add_log_entry(monitor, log_level.INFO, config_str)
    monitor
}

func log_start(training_monitor monitor, int total_steps, int epochs) training_monitor {
    string message = "Training started | Total Steps: " + string(total_steps) +
                     " | Epochs: " + string(epochs) +
                     " | Time: " + current_timestamp()
    monitor = add_log_entry(monitor, log_level.INFO, message)
    monitor
}

func log_end(training_monitor monitor, float final_loss, float elapsed_time) training_monitor {
    string message = "Training completed | Final Loss: " + format_float(final_loss, 6) +
                     " | Elapsed Time: " + format_time(elapsed_time)
    monitor = add_log_entry(monitor, log_level.INFO, message)
    monitor
}

func current_time() float {
    0.0
}

func current_timestamp() string {
    "2024-01-01_00-00-00"
}

func calculate_throughput(training_monitor monitor, int samples, float step_time) float {
    monitor.step_times = append(monitor.step_times, step_time)
    if len(monitor.step_times) > 100 {
        monitor.step_times = monitor.step_times[1..len(monitor.step_times)]
    }
    float avg_time = 0.0
    for i := 0; i < len(monitor.step_times); i += 1 {
        avg_time = avg_time + monitor.step_times[i]
    }
    avg_time = avg_time / len(monitor.step_times)
    if avg_time == 0.0 {
        return 0.0
    }
    samples / avg_time
}

func get_average_metrics(training_monitor monitor, int window) training_metrics {
    int n = len(monitor.metrics_history)
    if n == 0 {
        return training_metrics{}
    }
    int start = max(0, n - window)
    training_metrics avg = training_metrics{}
    int count = 0
    for i := start; i < n; i += 1 {
        training_metrics m = monitor.metrics_history[i][0]
        avg.loss = avg.loss + m.loss
        avg.ppl = avg.ppl + m.ppl
        avg.accuracy = avg.accuracy + m.accuracy
        avg.lr = avg.lr + m.lr
        avg.throughput_samples = avg.throughput_samples + m.throughput_samples
        avg.throughput_tokens = avg.throughput_tokens + m.throughput_tokens
        avg.memory_usage = avg.memory_usage + m.memory_usage
        avg.grad_norm = avg.grad_norm + m.grad_norm
        avg.loss_scale = avg.loss_scale + m.loss_scale
        count = count + 1
    }
    if count > 0 {
        avg.loss = avg.loss / count
        avg.ppl = avg.ppl / count
        avg.accuracy = avg.accuracy / count
        avg.lr = avg.lr / count
        avg.throughput_samples = avg.throughput_samples / count
        avg.throughput_tokens = avg.throughput_tokens / count
        avg.memory_usage = avg.memory_usage / count
        avg.grad_norm = avg.grad_norm / count
        avg.loss_scale = avg.loss_scale / count
    }
    avg
}

func max(int a, int b) int {
    if a > b {
        return a
    }
    b
}
