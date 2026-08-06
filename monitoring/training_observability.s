package neurx.monitoring.training_observability
enum log_backend {
    LOG_TENSORBOARD,
    LOG_WANDB,
   _LOG_MLFLOW,
    LOG_CUSTOM,
    LOG_CONSOLE,
    LOG_ALL
}
enum alert_channel {
    ALERT_WEBHOOK,
    ALERT_EMAIL,
    ALERT_CONSOLE,
    ALERT_LOGGER,
}
struct monitoring_config {
    string experiment_name
    string run_id
    log_backend primary_backend
    []log_backend additional_backends
    string tensorboard_log_dir
    string wandb_project
    int scalar_log_interval
    int histogram_log_interval
    int profile_interval
    int system_stats_interval
    bool enable_alerts
    float loss_spike_threshold
    float grad_explosion_threshold
    float gpu_memory_warning_pct
    float gpu_memory_critical_pct
    int consecutive_loss_spikes_to_alert
    []alert_channel alert_channels
    string webhook_url
    bool enable_profiling
    bool track_per_layer_stats
    bool collect_attention_stats
    bool monitor_data_pipeline
    bool enable_auto_diagnosis
    bool save_full_history
}
func default_monitoring_config() monitoring_config {
    monitoring_config {
        experiment_name: "NEURX-5.2-Pretrain",
        run_id: generate_run_id(),
        primary_backend: LOG_TENSORBOARD,
        additional_backends: [LOG_WANDB],
        tensorboard_log_dir: "./logs/tensorboard",
        wandb_project: "neurx-training",
        scalar_log_interval: 10,
        histogram_log_interval: 500,
        profile_interval: 1000,
        system_stats_interval: 10,
        enable_alerts: true,
        loss_spike_threshold: 10.0,
        grad_explosion_threshold: 1000.0,
        gpu_memory_warning_pct: 0.90,
        gpu_memory_critical_pct: 0.95,
        consecutive_loss_spikes_to_alert: 3,
        alert_channels: [ALERT_CONSOLE],
        webhook_url: "",
        enable_profiling: false,
        track_per_layer_stats: true,
        collect_attention_stats: true,
        monitor_data_pipeline: true,
        enable_auto_diagnosis: true,
        save_full_history: true,
    }
}
struct metric_record {
    string name
    float value
    int64 timestamp_ms
    int step
    string tag
}
struct histogram_metric {
    string name
    int step
    int64 timestamp_ms
    []float bins
    []int counts
    float min_val
    float max_val
    float mean
    float std_dev
    float p50, p90, p99
}
struct performance_snapshot {
    int64 timestamp_ms
    int step
    float tflops_achieved
    float tflops_theoretical
    float compute_utilization
    float samples_per_second
    float tokens_per_second
    float steps_per_second
    float gpu_memory_used_gb
    float gpu_memory_total_gb
    float gpu_memory_peak_gb
    float cpu_memory_used_gb
    float allreduce_time_ms
    float allgather_time_ms
    float point_to_point_time_ms
    float bandwidth_utilization
    float pipeline_bubble_ratio
    int micro_batches_in_flight
    float data_load_time_pct
    float data_queue_size
    float cpu_usage_pct
    float gpu_sm_utilization_pct
    float gpu_mem_bandwidth_util_pct
    float disk_io_mb_s
    float network_rx_mb_s
    float network_tx_mb_s
}
struct training_health_snapshot {
    int64 timestamp_ms
    int step
    float current_loss
    float moving_avg_loss
    float loss_variance
    float learning_rate
    float gradient_l2_norm
    float gradient_max_abs
    bool is_loss_nan
    bool is_loss_inf
    bool is_gradient_nan
    bool is_gradient_exploding
    bool is_gpu_near_oom
    bool is_stagnating
    bool is_diverging
    []alert_info active_alerts
    diagnosis_result auto_diagnosis
}
struct alert_info {
    string alert_type
    severity_level severity
    string message
    float metric_value
    float threshold_value
    int triggered_at_step
    int64 triggered_at_timestamp
    bool acknowledged
    string suggested_action
}
enum severity_level {
    SEVERITY_INFO,
    SEVERITY_WARNING,
    SEVERITY_CRITICAL,
}
struct diagnosis_result {
    string overall_status
    string summary
    []diagnosis_issue issues
    []recommendation recommendations
    float confidence_score
}
struct diagnosis_issue {
    string category
    string description
    float impact_score
    string root_cause_hint
}
struct recommendation {
    string action
    priority prio
    expected_improvement
    complexity complexity
}
enum priority { PRIORITY_HIGH, PRIORITY_MEDIUM, PRIORITY_LOW }
enum complexity { COMPLEXITY_EASY, COMPLEXITY_MEDIUM, COMPLEXITY_HARD }
struct monitoring_manager {
    monitoring_config config
    bool is_running
    []metric_record scalar_history
    []histogram_metric histogram_history
    []performance_snapshot perf_snapshots
    []training_health_snapshot health_snapshots
    training_health_snapshot current_health
    performance_snapshot current_perf
    moving_window loss_window
    moving_window grad_window
    []alert_info alert_history
    int consecutive_loss_spike_count
    profiler_state profiler
    tensorboard_writer tb_writer
    wandb_writer wb_writer
    console_writer console
}
struct moving_window {
    []float values
    int window_size
    int current_index
    bool is_filled_once
}
struct profiler_state {
    bool is_active
    int start_step
    int end_step
    string output_path
}
struct tensorboard_writer {
    string log_dir
    file_handle file_handles[10]
}
struct wandb_writer { string project; string run_id }
struct console_writer { bool verbose }
func init_monitoring(monitoring_config cfg) monitoring_manager {
    create_directory(cfg.tensorboard_log_dir)
    tensorboard_writer tbw
    tbw.log_dir = cfg.tensorboard_log_dir
    console_writer cw
    cw.verbose = true
    moving_window lw
    lw.values = []float{cap: 100}
    lw.window_size = 100
    lw.current_index = 0
    lw.is_filled_once = false
    moving_window gw = lw
    monitoring_manager mgr
    mgr.config = cfg
    mgr.is_running = false
    mgr.scalar_history = []metric_record{}
    mgr.histogram_history = []histogram_metric{}
    mgr.perf_snapshots = []performance_snapshot{}
    mgr.health_snapshots = []training_health_snapshot{}
    mgr.loss_window = lw
    mgr.grad_window = gw
    mgr.alert_history = []alert_info{}
    mgr.consecutive_loss_spike_count = 0
    mgr.profiler.is_active = false
    mgr.tb_writer = tbw
    mgr.console = cw
    return mgr
}
func start_monitoring(ref monitoring_manager mgr) {
    mgr.is_running = true
    log_info("Monitoring started for experiment: " + mgr.config.experiment_name)
    log_info("Run ID: " + mgr.config.run_id)
}
func stop_monitoring(ref monitoring_manager mgr) {
    mgr.is_running = false
    flush_all_writers(mgr)
    generate_final_report(mgr)
    log_info("Monitoring stopped. Total records logged: " + string(len(mgr.scalar_history)))
}
func log_scalar(
    ref monitoring_manager mgr,
    string name,
    float value,
    int step
) {
    if !mgr.is_running { return }
    metric_record record
    record.name = name
    record.value = value
    record.timestamp_ms = get_current_time_ms()
    record.step = step
    append(mgr.scalar_history, record)
    if name == "train/loss" {
        update_moving_window(ref mgr.loss_window, value)
        check_for_loss_anomalies(mgr, value, step)
    } else if name == "train/grad_norm" {
        update_moving_window(ref mgr.grad_window, value)
        check_for_grad_anomalies(mgr, value, step)
    }
    if should_log_at_step(step, mgr.config.scalar_log_interval) {
        write_scalar_to_backends(mgr, record)
    }
}
func log_histogram(
    ref monitoring_manager mgr,
    string name,
    []float values,
    int step
) {
    if !mgr.is_running || !should_log_at_step(step, mgr.config.histogram_log_interval) {
        return
    }
    histogram_metric hist
    hist.name = name
    hist.step = step
    hist.timestamp_ms = get_current_time_ms()
    compute_histogram_statistics(values, ref hist)
    append(mgr.histogram_history, hist)
    write_histogram_to_backends(mgr, hist)
}
func log_performance_snapshot(ref monitoring_manager mgr, performance_snapshot snap) {
    if !mgr.is_running { return }
    snap.timestamp_ms = get_current_time_ms()
    append(mgr.perf_snapshots, snap)
    mgr.current_perf = snap
    if mgr.config.enable_auto_diagnosis {
        diagnosis_result diag = run_auto_diagnosis(mgr, snap)
        mgr.current_health.auto_diagnosis = diag
    }
    write_perf_snapshot_to_backends(mgr, snap)
    check_system_health_alerts(mgr, snap)
}
func update_training_health(
    ref monitoring_manager mgr,
    float loss,
    float lr,
    float grad_norm,
    int step
) {
    training_health_snapshot health
    health.timestamp_ms = get_current_time_ms()
    health.step = step
    health.current_loss = loss
    health.learning_rate = lr
    health.gradient_l2_norm = grad_norm
    health.moving_avg_loss = compute_moving_average(mgr.loss_window)
    health.loss_variance = compute_variance(mgr.loss_window)
    health.is_loss_nan = is_nan(loss)
    health.is_loss_inf = is_inf(loss)
    health.is_gradient_nan = is_nan(grad_norm)
    health.is_gradient_exploding = grad_norm > mgr.config.grad_explosion_threshold
    health.is_stagnating = detect_stagnation(mgr.loss_window, 0.001)
    health.is_diverging = detect_divergence(mgr.loss_window)
    mgr.current_health = health
    append(mgr.health_snapshots, health)
    log_scalar(mgr, "train/loss", loss, step)
    log_scalar(mgr, "train/loss_avg", health.moving_avg_loss, step)
    log_scalar(mgr, "train/learning_rate", lr, step)
    log_scalar(mgr, "train/gradient_norm", grad_norm, step)
    if health.moving_avg_loss > 0 {
        log_scalar(mgr, "train/loss_std", sqrt_approx(health.loss_variance), step)
    }
}
func run_auto_diagnosis(
    monitoring_manager mgr,
    performance_snapshot perf
) diagnosis_result {
    []diagnosis_issue issues = []
    []recommendation recs = []
    float confidence = 0.9
    if perf.gpu_sm_utilization_pct < 50.0 {
        diagnosis_issue issue
        issue.category = "performance"
        issue.description = "GPU SM utilization is low (" +
                           string(perf.gpu_sm_utilization_pct, 1) + "%)"
        issue.impact_score = 7.0
        issue.root_cause_hint = "Possible bottleneck in data loading or communication"
        append(issues, issue)
        if perf.data_load_time_pct > 30.0 {
            recommendation r
            r.action = "Increase num_workers or prefetch_factor in data_loader"
            r.prio = PRIORITY_HIGH
            r.expected_improvement = "+20-40% throughput"
            r.complexity = COMPLEXITY_EASY
            append(recs, r)
        }
        if perf.allreduce_time_ms > 50.0 {
            recommendation r
            r.action = "Consider gradient accumulation to reduce communication frequency"
            r.prio = PRIORITY_HIGH
            r.expected_improvement = "-30% communication overhead"
            r.complexity = COMPLEXITY_EASY
            append(recs, r)
        }
    }
    float mem_ratio = perf.gpu_memory_used_gb / perf.gpu_memory_total_gb
    if mem_ratio > mgr.config.gpu_memory_warning_pct {
        diagnosis_issue issue
        issue.category = "system"
        issue.description = "High GPU memory usage (" +
                           string(mem_ratio * 100, 1) + "%)"
        issue.impact_score = 8.0 - (mem_ratio - 0.9) * 20
        if issue.impact_score < 4.0 { issue.impact_score = 4.0 }
        if issue.impact_score > 10.0 { issue.impact_score = 10.0 }
        issue.root_cause_hint = "Consider activation checkpointing or smaller batch size"
        append(issues, issue)
        recommendation r
        r.action = "Enable gradient checkpointing or reduce micro_batch_size"
        r.prio = PRIORITY_HIGH
        r.expected_improvement = "-30-50% memory usage"
        r.complexity = COMPLEXITY_EASY
        append(recs, r)
    }
    if perf.pipeline_bubble_ratio > 0.3 {
        diagnosis_issue issue
        issue.category = "performance"
        issue.description = "Large pipeline bubble ratio (" +
                           string(perf.pipeline_bubble_ratio * 100, 1) + "%)"
        issue.impact_score = 6.0
        issue.root_cause_hint = "Increase number of micro-batches per step"
        append(issues, issue)
        recommendation r
        r.action = "Use interleaved schedule or increase global batch size"
        r.prio = PRIORITY_MEDIUM
        r.expected_improvement = "-15-25% bubble ratio"
        r.complexity = COMPLEXITY_MEDIUM
        append(recs, r)
    }
    if mgr.current_health.is_stagnating {
        diagnosis_issue issue
        issue.category = "health"
        issue.description = "Training loss appears to be stagnating"
        issue.impact_score = 7.0
        issue.root_cause_hint = "Learning rate too low, or model capacity insufficient"
        append(issues, issue)
        recommendation r
        r.action = "Check learning rate schedule; consider increasing warmup duration"
        r.prio = PRIORITY_HIGH
        r.expected_improvement = "Resume loss decrease"
        r.complexity = COMPLEXITY_EASY
        append(recs, r)
    }
    if mgr.current_health.is_gradient_exploding {
        diagnosis_issue issue
        issue.category = "health"
        issue.description = "Gradient explosion detected (norm=" +
                           string(mgr.current_health.gradient_l2_norm))
        issue.impact_score = 9.0
        issue.root_cause_hint = "LR too high, or numerical instability"
        append(issues, issue)
        recommendation r
        r.action = "Reduce max_grad_norm clipping or lower learning rate"
        r.prio = PRIORITY_CRITICAL
        r.expected_improvement = "Stabilize training"
        r.complexity = COMPLEXITY_EASY
        append(recs, r)
    }
    string status = "healthy"
    if len(issues) > 0 {
        status = "warning"
        int i = 0
        while i < len(issues) {
            if issues[i].impact_score >= 8.0 {
                status = "critical"
                break
            }
            i = i + 1
        }
    }
    string summary = "Training is " + status
    if len(issues) > 0 {
        summary = summary + ". Found " + string(len(issues)) + " issue(s): "
        if len(issues) <= 3 {
            int j = 0
            while j < len(issues) {
                if j > 0 { summary = summary + "; " }
                summary = summary + issues[j].description
                j = j + 1
            }
        } else {
            summary = summary + issues[0].description + " (and " +
                       string(len(issues)-1) + " more)"
        }
    }
    diagnosis_result result
    result.overall_status = status
    result.summary = summary
    result.issues = issues
    result.recommendations = recs
    result.confidence = confidence
    return result
}
func check_for_loss_anomalies(ref monitoring_manager mgr, float loss, int step) {
    if !mgr.config.enable_alerts { return }
    float avg = compute_moving_average(mgr.loss_window)
    if avg > 0 && loss > avg * mgr.config.loss_spike_threshold {
        mgr.consecutive_loss_spike_count = mgr.consecutive_loss_spike_count + 1
        if mgr.consecutive_loss_spike_count >= mgr.config.consecutive_loss_spikes_to_alert {
            trigger_alert(mgr, "loss_spike", SEVERITY_WARNING,
                "Loss spike detected: current=" + string(loss, 4) +
                ", average=" + string(avg, 4),
                loss, avg * mgr.config.loss_spike_threshold, step,
                "Check data quality or reduce learning rate")
            mgr.consecutive_loss_spike_count = 0
        }
    } else {
        mgr.consecutive_loss_spike_count = 0
    }
    if is_nan(loss) || is_inf(loss) {
        trigger_alert(mgr, "loss_nan_inf", SEVERITY_CRITICAL,
            "Loss is NaN or Inf: " + string(loss),
            loss, 0.0, step,
            "Immediate investigation required! Check gradients and model state.")
    }
}
func check_for_grad_anomalies(ref monitoring_manager mgr, float grad_norm, int step) {
    if !mgr.config.enable_alerts { return }
    if grad_norm > mgr.config.grad_explosion_threshold {
        trigger_alert(mgr, "gradient_explosion", SEVERITY_CRITICAL,
            "Gradient explosion detected: norm=" + string(grad_norm, 2),
            grad_norm, mgr.config.grad_explosion_threshold, step,
            "Reduce learning rate or increase gradient clipping!")
    }
}
func check_system_health_alerts(ref monitoring_manager mgr, performance_snapshot snap) {
    if !mgr.config.enable_alerts { return }
    float mem_pct = snap.gpu_memory_used_gb / snap.gpu_memory_total_gb
    if mem_pct > mgr.config.gpu_memory_critical_pct {
        trigger_alert(mgr, "oom_critical", SEVERITY_CRITICAL,
            "Critical memory pressure: " + string(mem_pct*100, 1) + "%",
            mem_pct, mgr.config.gpu_memory_critical_pct, snap.step,
            "Immediately reduce batch size or enable checkpointing!")
    } else if mem_pct > mgr.config.gpu_memory_warning_pct {
        trigger_alert(mgr, "oom_warning", SEVERITY_WARNING,
            "High memory usage: " + string(mem_pct*100, 1) + "%",
            mem_pct, mgr.config.gpu_memory_warning_pct, snap.step,
            "Consider enabling gradient checkpointing")
    }
}
func trigger_alert(
    ref monitoring_manager mgr,
    string alert_type,
    severity_level sev,
    string message,
    float metric_val,
    float threshold,
    int step,
    string suggested_action
) {
    alert_info alert
    alert.alert_type = alert_type
    alert.severity = sev
    alert.message = message
    alert.metric_value = metric_val
    alert.threshold_value = threshold
    alert.triggered_at_step = step
    alert.triggered_at_timestamp = get_current_time_ms()
    alert.acknowledged = false
    alert.suggested_action = suggested_action
    append(mgr.alert_history, alert)
    string severity_str = ""
    if sev == SEVERITY_INFO { severity_str = "INFO" }
    else if sev == SEVERITY_WARNING { severity_str = "WARNING" }
    else { severity_str = "CRITICAL" }
    log_scalar(mgr, "alerts/" + alert_type, float_of_int(sev), step)
    send_alert_notification(mgr, alert)
    print("\n⚠️  [" + severity_str + "] " + alert.message +
          "\n   Suggestion: " + alert.suggested_action + "\n")
}
func send_alert_notification(monitoring_manager mgr, alert_info alert) {
    int ch_idx = 0
    while ch_idx < len(mgr.config.alert_channels) {
        alert_channel ch = mgr.config.alert_channels[ch_idx]
        if ch == ALERT_WEBHOOK && len(mgr.config.webhook_url) > 0 {
            send_webhook_alert(mgr.config.webhook_url, alert)
        } else if ch == ALERT_CONSOLE {
        } else if ch == ALERT_LOGGER {
            write_to_log_file("[ALERT] " + alert.message)
        }
        ch_idx = ch_idx + 1
    }
}
func send_webhook_alert(string url, alert_info alert) {
}
func write_to_log_file(string msg) {
    print(msg)
}
func create_directory(string path) {
}
func log_info(string msg) {
    print("[" + format_timestamp(get_current_time_ms()) + "] " + msg)
}
func get_current_time_ms() int64 {
    extern get_system_time_ms() int64
    return get_system_time_ms()
}
func format_timestamp(int64 time_ms) string {
    int64 secs = time_ms / 1000
    int64 ms = time_ms % 1000
    int hours = int((secs / 3600) % 24)
    int mins = int((secs / 60) % 60)
    int sec = int(secs % 60)
    string h_str = string(hours)
    string m_str = string(mins)
    string s_str = string(sec)
    string ms_str = string(ms)
    if hours < 10 { h_str = "0" + h_str }
    if mins < 10 { m_str = "0" + m_str }
    if sec < 10 { s_str = "0" + s_str }
    if ms < 100 { ms_str = "0" + ms_str }
    if ms < 10 { ms_str = "0" + ms_str }
    return h_str + ":" + m_str + ":" + s_str + "." + ms_str
}
func generate_run_id() string {
    return "run_" + string(get_current_time_ms())
}
func should_log_at_step(int step, int interval) bool {
    return (step % interval == 0)
}
func append_ref([]metric_record arr, metric_record r) {}
func append_hist([]histogram_metric arr, histogram_metric h) {}
func append_perf([]performance_snapshot arr, performance_snapshot p) {}
func append_health([]training_health_snapshot arr, training_health_snapshot h) {}
func append_issues([]diagnosis_issue arr, diagnosis_issue i) {}
function append_recs([]recommendation arr, recommendation r) {}
func update_moving_window(ref moving_window win, float val) {
    win.values[win.current_index] = val
    win.current_index = win.current_index + 1
    if win.current_index >= win.window_size {
        win.current_index = 0
        win.is_filled_once = true
    }
}
func compute_moving_average(moving_window win) float {
    if !win.is_filled_once { return 0.0 }
    float sum = 0.0
    int count = 0
    int i = 0
    while i < win.window_size {
        sum = sum + win.values[i]
        count = count + 1
        i = i + 1
    }
    if count == 0 { return 0.0 }
    return sum / float_of_int(count)
}
func compute_variance(moving_window win) float {
    if !win.is_filled_once { return 0.0 }
    float avg = compute_moving_average(win)
    float var_sum = 0.0
    int count = 0
    int i = 0
    while i < win.window_size {
        float diff = win.values[i] - avg
        var_sum = var_sum + diff * diff
        count = count + 1
        i = i + 1
    }
    if count <= 1 { return 0.0 }
    return var_sum / float_of_int(count - 1)
}
func detect_stagnation(moving_window win, float threshold) bool {
    if !win.is_filled_once { return false }
    float first_half_avg = 0.0
    float second_half_avg = 0.0
    int half = win.window_size / 2
    int i = 0
    while i < half {
        first_half_avg = first_half_avg + win.values[i]
        second_half_avg = second_half_avg + win.values[half + i]
        i = i + 1
    }
    first_half_avg = first_half_avg / float_of_int(half)
    second_half_avg = second_half_avg / float_of_int(half)
    if first_half_avg == 0.0 { return false }
    float change = abs(second_half_avg - first_half_avg) / abs(first_half_avg)
    return change < threshold
}
func detect_divergence(moving_window win) bool {
    if !win.is_filled_once { return false }
    float early_avg = 0.0
    float recent_avg = 0.0
    int quarter = win.window_size / 4
    int i = 0
    while i < quarter {
        early_avg = early_avg + win.values[i]
        recent_avg = recent_avg + win.values[win.window_size - quarter + i]
        i = i + 1
    }
    early_avg = early_avg / float_of_int(quarter)
    recent_avg = recent_avg / float_of_int(quarter)
    if early_avg == 0.0 { return false }
    return recent_avg > early_avg * 2.0 && early_avg > 0.01
}
func compute_histogram_statistics([]float values, ref histogram_metric hist) {
    int n = len(values)
    if n == 0 { return }
    float sum = 0.0
    float min_val = values[0]
    float max_val = values[0]
    int i = 0
    while i < n {
        sum = sum + values[i]
        if values[i] < min_val { min_val = values[i] }
        if values[i] > max_val { max_val = values[i] }
        i = i + 1
    }
    float mean = sum / float_of_int(n)
    float var_sum = 0.0
    i = 0
    while i < n {
        float d = values[i] - mean
        var_sum = var_sum + d * d
        i = i + 1
    }
    float std = sqrt_approx(var_sum / float_of_int(n))
    hist.min_val = min_val
    hist.max_val = max_val
    hist.mean = mean
    hist.std_dev = std
    int num_bins = 50
    hist.bins = []float{cap: num_bins + 1}
    hist.counts = []int{cap: num_bins}
    float range = max_val - min_val
    if range == 0 { range = 1.0 }
    float bin_width = range / float_of_int(num_bins)
    int b = 0
    while b < num_bins {
        hist.bins[b] = min_val + float_of_int(b) * bin_width
        hist.counts[b] = 0
        b = b + 1
    }
    hist.bins[num_bins] = max_val
    i = 0
    while i < n {
        int bin_idx = int((values[i] - min_val) / bin_width)
        if bin_idx >= num_bins { bin_idx = num_bins - 1 }
        if bin_idx < 0 { bin_idx = 0 }
        hist.counts[bin_idx] = hist.counts[bin_idx] + 1
        i = i + 1
    }
    sort_float_array(values)
    hist.p50 = values[n * 50 / 100]
    hist.p90 = values[n * 90 / 100]
    hist.p99 = values[n * 99 / 100]
}
func sort_float_array(ref []float arr) {
    int n = len(arr)
    int i = 0
    while i < n - 1 {
        int j = 0
        while j < n - i - 1 {
            if arr[j] > arr[j+1] {
                float temp = arr[j]
                arr[j] = arr[j+1]
                arr[j+1] = temp
            }
            j = j + 1
        }
        i = i + 1
    }
}
func is_nan(float x) bool {
    return !(x == x)
}
func is_inf(float x) bool {
    return x > 1e38 || x < -1e38
}
func abs(float x) float {
    if x < 0 { return -x }
    return x
}
func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float g = x * 0.5
    int iter = 0
    while iter < 20 {
        float ng = (g + x / g) * 0.5
        if ng == g { break }
        g = ng
        iter = iter + 1
    }
    return g
}
func float_of_int(int n) float {
    float r = 0.0
    int i = 0
    while i < n { r = r + 1.0; i = i + 1 }
    return r
}
func string(float f, int prec) string {
    extern float_to_string(float f) string
    return float_to_string(f)
}
func string(int i) string {
    extern int_to_string(int i) string
    return int_to_string(i)
}
func write_scalar_to_backends(monitoring_manager m, metric_record r) {
    if m.config.primary_backend == LOG_CONSOLE || m.config.primary_backend == LOG_ALL {
        string output = "[METRIC] " + r.name + "=" + string(r.value) + " @step " + string(r.step)
        log_info(output)
    }
    write_to_log_file(r.name + " " + string(r.value) + " step=" + string(r.step))
}
func write_histogram_to_backends(monitoring_manager m, histogram_metric h) {
    string output = "[HIST] " + h.name + " @step " + string(h.step)
    log_info(output)
}
func write_perf_snapshot_to_backends(monitoring_manager m, performance_snapshot p) {
    string output = "[PERF] throughput=" + string(p.tokens_per_second) + " tokens/s, " +
                    "gpu_util=" + string(p.gpu_sm_utilization_pct) + "%, " +
                    "mem=" + string(p.gpu_memory_used_gb) + "GB @step " + string(p.step)
    log_info(output)
}
func flush_all_writers(monitoring_manager m) {
    log_info("Flushing all monitoring outputs...")
}
func generate_final_report(monitoring_manager m) {
    log_info("Training completed. Generated " + string(len(m.scalar_history)) + " metric records")
}
func get_monitoring_dashboard_layout() string {
    return `
╔══════════════════════════════════════════════════════════════╗
║              NEURX-5.2 training monitor dashboard              ║
╠═══════════════╦═══════════════╦═══════════════════════════════╣
║   LOSS CURVE  ║   THROUGHPUT    ║      SYSTEM HEALTH            ║
║  ┌──────────┐ ║  ┌───────────┐ ║  ┌─────────────────────────┐  ║
║  │ 📉 loss   │ ║  │ tokens/s  │ ║  │ GPU Memory ████████░░ 87%│  ║
║  │ (real-time│ ║  │ TFLOPS    │ ║  │ GPU util   ██████████ 95%│  ║
║  │  moving   │ ║  │ samples/s │ ║  │ Grad Norm  ████░░░░░ 42  │  ║
║  │  avg)     │ ║  │ steps/min │ ║  │ LR: 3e-4 → 2.9e-4      │  ║
║  └──────────┘ ║  └───────────┘ ║  │ status: ✅ healthy       │  ║
╠═══════════════╩═══════════════╩═══════════════════════════════╣
║                    RECENT ALERTS                             ║
║  [✓] step 12345: Loss within normal range (2.345)            ║
║  [!] step 12344: GPU memory high warning (89%)              ║
╠═════════════════════════════════════════════════════════════════╣
║  auto-diagnosis: No critical issues found.                 ║
║  recommendation: Training is proceeding normally.            ║
║  expected completion: ~14 days at current throughput.       ║
╚════════════════════════════════════════════════════════════════╝
`
}
func print_quick_status(monitoring_manager mgr) string {
    string status = "✅"
    if len(mgr.current_health.active_alerts) > 0 {
        status = "⚠️ "
    }
    if mgr.current_health.overall_status == "critical" {
        status = "🚨"
    }
    status + "Step[" + string(mgr.current_health.step) + "] " +
    "Loss:" + string(mgr.current_health.current_loss, 4) + " " +
    "GradNorm:" + string(mgr.current_health.gradient_l2_norm, 2) + " " +
    "TFLOPS:" + string(mgr.current_perf.tflops_achieved, 1) + " " +
    "GPU:" + string((mgr.current_perf.gpu_memory_used_gb/mgr.current_perf.gpu_memory_total_gb)*100, 1) + "%"
}
