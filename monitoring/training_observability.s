package neurx.monitoring.training_observability

// ═══════════════════════════════════════════════════════════════════
// Training Observability Platform — English texttrainingmonitoringEnglish texttool
//
// English text:
//   "You can't optimize what you can't measure"
//   — English textoptimize
//
// monitoringEnglish text (4 English text):
//
//   ┌──────────────────────────────────────────────────────────────┐
//   │                  TRAINING OBSERVABILITY                     │
//   ├─────────────┬─────────────┬─────────────┬───────────────────┤
//   │ PERFORMANCE │    HEALTH   │  SYSTEM     │    DEBUG           │
//   ├─────────────┼─────────────┼─────────────┼───────────────────┤
//   │ • TFLOPS    │ • Loss      │ • GPU Util  │ • Gradient Norms  │
//   │ • Throughput│ • LR curve  │ • Mem Usage │ • Activation Stats│
//   │ • Latency   │ • Grad norm │ • IO Wait   │ • Attention Patts │
//   │ • Bubble %  │ • Loss spike│ • Comm time │ • Weight Histogrm │
//   │ • Efficiency│ • NaN/Inf   │ • CPU usage │ • Data Statistics  │
//   └─────────────┴─────────────┴─────────────┴───────────────────┘
//
// English text:
//   ✓ English text: English text metrics English text
//   ✓ English text: English text
//   ✓ English text: English text/English text GPU English text
//   ✓ English text: savecompleteEnglish text
//   ✓ English textsystem: English textconfigurationEnglish text + English text (webhook/email)
//   ✓ Profiler English text: support Nsight Systems / PyTorch Profiler English text
//   ✓ English textoutput: TensorBoard / WandB / English text dashboard
//
// useEnglish text:
//   • English textmonitoringEnglish texttrainingEnglish text
//   • quickEnglish text (compute vs IO vs communication)
//   • English texttrainingEnglish text / loss English text
//   • English text OOM English text
//   • English textparameterconfigurationEnglish text
// ═══════════════════════════════════════════════════════════════════

// ============================================================================
// 1. configurationEnglish text
// ============================================================================

enum log_backend {
    LOG_TENSORBOARD,              // TensorBoard English text (English text)
    LOG_WANDB,                    // Weights & Biases (English text)
   _LOG_MLFLOW,                   // MLflow (English textmanagement)
    LOG_CUSTOM,                    // English text JSON/CSV
    LOG_CONSOLE,                  // English textoutput (English text)
    LOG_ALL                        // English textoutputEnglish text
}

enum alert_channel {
    ALERT_WEBHOOK,                 // Webhook (Slack/DingTalk/English text)
    ALERT_EMAIL,                   // Email
    ALERT_CONSOLE,                 // English text
    ALERT_LOGGER,                  // English textlogfile
}

struct monitoring_config {
    // English text
    string experiment_name          // English textName (English text "NEURX-5.2-pretrain-v1")
    string run_id                    // run ID (UUID English texttimeEnglish text)

    // logEnglish text
    log_backend primary_backend       // mainEnglish textlogEnglish text
    []log_backend additional_backends  // English textlogEnglish text
    string tensorboard_log_dir       // TensorBoard directory
    string wandb_project             // WandB English text

    // English text
    int scalar_log_interval          // Scalar English text (steps), English text 10
    int histogram_log_interval       // English text (steps), English text 500
    int profile_interval             // English text Profile English text (steps), English text 1000
    int system_stats_interval        // systemstatisticsEnglish text (seconds), English text 10

    // English textconfiguration
    bool enable_alerts               // English text
    float loss_spike_threshold       // Loss English text (English text 10x English text loss)
    float grad_explosion_threshold   // gradientEnglish text (English text grad_norm > 1000)
    float gpu_memory_warning_pct     // GPU English text (English text 90%)
    float gpu_memory_critical_pct    // GPU English text (English text 95%)
    int consecutive_loss_spikes_to_alert // English text N English text loss spike English text
    []alert_channel alert_channels    // English text
    string webhook_url                // Webhook URL (English text Slack incoming webhook)

    // advancedEnglish text
    bool enable_profiling            // English text profiling (English text)
    bool track_per_layer_stats       // English textstatistics (English text)
    bool collect_attention_stats     // English textstatistics
    bool monitor_data_pipeline       // monitoringdataloadEnglish textstate
    bool enable_auto_diagnosis       // English text
    bool save_full_history           // savecompleteEnglish textdata (English textinformation)
}

// defaultconfiguration (English text NEURX-5.2 trainingoptimize)
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

        enable_profiling: false,  // defaultEnglish text overhead
        track_per_layer_stats: true,
        collect_attention_stats: true,
        monitor_data_pipeline: true,
        enable_auto_diagnosis: true,
        save_full_history: true,
    }
}

// ============================================================================
// 2. English text Metrics dataEnglish text
// ============================================================================

// English text Metric English text
struct metric_record {
    string name                       // English textName (English text "train/loss")
    float value                       // English text
    int64 timestamp_ms                // timeEnglish text
    int step                          // trainingstepEnglish text
    string tag                         // English text (English text,English text)
}

// English text (English text)
struct histogram_metric {
    string name
    int step
    int64 timestamp_ms
    []float bins                      // bin English text
    []int counts                      // English text bin English text
    float min_val
    float max_val
    float mean
    float std_dev
    float p50, p90, p99              // Percentiles
}

// English text (English texttimeEnglish textstate)
struct performance_snapshot {
    int64 timestamp_ms
    int step

    // Compute
    float tflops_achieved             // actualEnglish text TFLOPS
    float tflops_theoretical          // English text TFLOPS
    float compute_utilization         // computeEnglish text (%)
    float samples_per_second          // English text
    float tokens_per_second           // Token English text
    float steps_per_second            // Step English text

    // Memory
    float gpu_memory_used_gb          // English text (GB)
    float gpu_memory_total_gb         // English text (GB)
    float gpu_memory_peak_gb          // English text (GB)
    float cpu_memory_used_gb           // CPU English textuse (GB)

    // Communication
    float allreduce_time_ms           // AllReduce English text
    float allgather_time_ms           // AllGather English text
    float point_to_point_time_ms      // P2P English text
    float bandwidth_utilization       // English text

    // Pipeline (if PP used)
    float pipeline_bubble_ratio       // Pipeline bubble English text
    int micro_batches_in_flight       // English text micro-batch English text

    // Data loading
    float data_load_time_pct          // dataloadEnglish text
    float data_queue_size             // dataEnglish text

    // System
    float cpu_usage_pct               // CPU useEnglish text
    float gpu_sm_utilization_pct      // GPU SM English text
    float gpu_mem_bandwidth_util_pct  // English text
    float disk_io_mb_s               // English text IO English text
    float network_rx_mb_s            // English text
    float network_tx_mb_s            // English text
}

// Training Health English text
struct training_health_snapshot {
    int64 timestamp_ms
    int step

    // Core metrics
    float current_loss                // English text step English text loss
    float moving_avg_loss             // English text loss (English text N step)
    float loss_variance               // Loss English text
    float learning_rate               // English textlearning rate
    float gradient_l2_norm            // gradient L2 English text
    float gradient_max_abs           // gradientEnglish text

    // Health checks
    bool is_loss_nan                  // Loss English text NaN
    bool is_loss_inf                  // Loss English text Inf
    bool is_gradient_nan              // gradientEnglish text NaN
    bool is_gradient_exploding        // gradientEnglish text
    bool is_gpu_near_oom              // English text
    bool is_stagnating               // Loss English text
    bool is_diverging                 // Loss English text

    // Alerts triggered in this snapshot
    []alert_info active_alerts        // English text

    // Diagnostics (if enabled)
    diagnosis_result auto_diagnosis  // English textresult
}

// English textinformation
struct alert_info {
    string alert_type                  // English text (loss_spike, grad_explode, oom_warning...)
    severity_level severity           // English text (INFO / WARNING / CRITICAL)
    string message                    // English text
    float metric_value                // English text
    float threshold_value             // English text
    int triggered_at_step             // English text step
    int64 triggered_at_timestamp      // English texttimeEnglish text
    bool acknowledged                 // English text
    string suggested_action           // English text
}

enum severity_level {
    SEVERITY_INFO,                   // informationEnglish text (English texttraining)
    SEVERITY_WARNING,                // English text (RequiredEnglish text)
    SEVERITY_CRITICAL,               // English text (RequiredEnglish text!)
}

// English textresult
struct diagnosis_result {
    string overall_status             // "healthy" / "warning" / "critical"
    string summary                    // English text
    []diagnosis_issue issues          // English text
    []recommendation recommendations  // English text
    float confidence_score            // English text (0-1)
}

struct diagnosis_issue {
    string category                    // English text ("performance" / "health" / "system")
    string description                // English textDescription
    float impact_score                // English text (0-10,English text)
    string root_cause_hint            // English textprompt
}

struct recommendation {
    string action                      // English text
    priority prio                     // English text (HIGH / MEDIUM / LOW)
    expected_improvement             // English textDescription
    complexity complexity            // English text (EASY / MEDIUM / HARD)
}

enum priority { PRIORITY_HIGH, PRIORITY_MEDIUM, PRIORITY_LOW }
enum complexity { COMPLEXITY_EASY, COMPLEXITY_MEDIUM, COMPLEXITY_HARD }

// ============================================================================
// 3. Monitoring Manager mainEnglish text
// ============================================================================

struct monitoring_manager {
    monitoring_config config
    bool is_running

    // Metrics English text
    []metric_record scalar_history      // English text scalar English text
    []histogram_metric histogram_history // English text
    []performance_snapshot perf_snapshots  // English text
    []training_health_snapshot health_snapshots  // English text

    // English textstatecache (English textquickEnglish text)
    training_health_snapshot current_health
    performance_snapshot current_perf

    // statisticsEnglish text (English text)
    moving_window loss_window           // English text N English text loss English text
    moving_window grad_window           // English text N English text grad norm English text

    // alert system
    []alert_info alert_history          // English text
    int consecutive_loss_spike_count   // English text loss spike English text

    // Profiler (English textstart)
    profiler_state profiler

    // Writers (English text backend)
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
    file_handle file_handles[10]  // English text category English textfile
}
struct wandb_writer { string project; string run_id }
struct console_writer { bool verbose }

// ============================================================================
// 4. initialize & English textmanagement
// ============================================================================

func init_monitoring(monitoring_config cfg) monitoring_manager {
    // English textdirectory
    create_directory(cfg.tensorboard_log_dir)

    // initialize writers
    tensorboard_writer tbw
    tbw.log_dir = cfg.tensorboard_log_dir

    console_writer cw
    cw.verbose = true

    // initializeEnglish text
    moving_window lw
    lw.values = []float{cap: 100}  // English text 100 English text
    lw.window_size = 100
    lw.current_index = 0
    lw.is_filled_once = false

    moving_window gw = lw  // grad window English text

    // initialize manager
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

    // Flush English text pending logs
    flush_all_writers(mgr)

    // generateEnglish text
    generate_final_report(mgr)

    log_info("Monitoring stopped. Total records logged: " + string(len(mgr.scalar_history)))
}

// ============================================================================
// 5. English text (English texttrainingEnglish text)
// ============================================================================

// English text (English text)
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

    // English text
    append(mgr.scalar_history, record)

    // English textcache
    if name == "train/loss" {
        update_moving_window(ref mgr.loss_window, value)
        check_for_loss_anomalies(mgr, value, step)
    } else if name == "train/grad_norm" {
        update_moving_window(ref mgr.grad_window, value)
        check_for_grad_anomalies(mgr, value, step)
    }

    // English text backend (English text interval)
    if should_log_at_step(step, mgr.config.scalar_log_interval) {
        write_scalar_to_backends(mgr, record)
    }
}

// English text
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

    // computeEnglish textstatistics
    compute_histogram_statistics(values, ref hist)

    append(mgr.histogram_history, hist)
    write_histogram_to_backends(mgr, hist)
}

// English textcompleteEnglish text
func log_performance_snapshot(ref monitoring_manager mgr, performance_snapshot snap) {
    if !mgr.is_running { return }

    snap.timestamp_ms = get_current_time_ms()
    append(mgr.perf_snapshots, snap)
    mgr.current_perf = snap

    // English text
    if mgr.config.enable_auto_diagnosis {
        diagnosis_result diag = run_auto_diagnosis(mgr, snap)
        mgr.current_health.auto_diagnosis = diag
    }

    // English text backend
    write_perf_snapshot_to_backends(mgr, snap)

    // Check alerts based on system stats
    check_system_health_alerts(mgr, snap)
}

// trainingEnglish text (English text step English text)
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

    // Moving average of loss
    health.moving_avg_loss = compute_moving_average(mgr.loss_window)
    health.loss_variance = compute_variance(mgr.loss_window)

    // Health checks
    health.is_loss_nan = is_nan(loss)
    health.is_loss_inf = is_inf(loss)
    health.is_gradient_nan = is_nan(grad_norm)
    health.is_gradient_exploding = grad_norm > mgr.config.grad_explosion_threshold

    // Stagnation detection
    health.is_stagnating = detect_stagnation(mgr.loss_window, 0.001)  // <0.1% change over window

    // Divergence detection
    health.is_diverging = detect_divergence(mgr.loss_window)

    // Update cache
    mgr.current_health = health
    append(mgr.health_snapshots, health)

    // Log key scalars
    log_scalar(mgr, "train/loss", loss, step)
    log_scalar(mgr, "train/loss_avg", health.moving_avg_loss, step)
    log_scalar(mgr, "train/learning_rate", lr, step)
    log_scalar(mgr, "train/gradient_norm", grad_norm, step)

    // Log derived metrics
    if health.moving_avg_loss > 0 {
        log_scalar(mgr, "train/loss_std", sqrt_approx(health.loss_variance), step)
    }
}

// ============================================================================
// 6. English text
// ============================================================================

func run_auto_diagnosis(
    monitoring_manager mgr,
    performance_snapshot perf
) diagnosis_result {
    []diagnosis_issue issues = []
    []recommendation recs = []
    float confidence = 0.9

    // === Performance Diagnosis ===

    // 1. GPU utilization low?
    if perf.gpu_sm_utilization_pct < 50.0 {
        diagnosis_issue issue
        issue.category = "performance"
        issue.description = "GPU SM utilization is low (" +
                           string(perf.gpu_sm_utilization_pct, 1) + "%)"
        issue.impact_score = 7.0
        issue.root_cause_hint = "Possible bottleneck in data loading or communication"
        append(issues, issue)

        // Recommendation
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

    // 2. Memory pressure?
    float mem_ratio = perf.gpu_memory_used_gb / perf.gpu_memory_total_gb
    if mem_ratio > mgr.config.gpu_memory_warning_pct {
        diagnosis_issue issue
        issue.category = "system"
        issue.description = "High GPU memory usage (" +
                           string(mem_ratio * 100, 1) + "%)"
        issue.impact_score = 8.0 - (mem_ratio - 0.9) * 20  // English text
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

    // 3. Pipeline bubble large?
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

    // === Health Diagnosis ===

    // 4. Loss stagnation?
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

    // 5. Gradient issues?
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

    // Determine overall status
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

    // Build summary
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

// ============================================================================
// 7. alert system
// ============================================================================

// Loss anomaly check
func check_for_loss_anomalies(ref monitoring_manager mgr, float loss, int step) {
    if !mgr.config.enable_alerts { return }

    float avg = compute_moving_average(mgr.loss_window)

    // Spike detection
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

    // NaN/Inf detection
    if is_nan(loss) || is_inf(loss) {
        trigger_alert(mgr, "loss_nan_inf", SEVERITY_CRITICAL,
            "Loss is NaN or Inf: " + string(loss),
            loss, 0.0, step,
            "Immediate investigation required! Check gradients and model state.")
    }
}

// Gradient anomaly check
func check_for_grad_anomalies(ref monitoring_manager mgr, float grad_norm, int step) {
    if !mgr.config.enable_alerts { return }

    if grad_norm > mgr.config.grad_explosion_threshold {
        trigger_alert(mgr, "gradient_explosion", SEVERITY_CRITICAL,
            "Gradient explosion detected: norm=" + string(grad_norm, 2),
            grad_norm, mgr.config.grad_explosion_threshold, step,
            "Reduce learning rate or increase gradient clipping!")
    }
}

// System health check (from perf snapshot)
func check_system_health_alerts(ref monitoring_manager mgr, performance_snapshot snap) {
    if !mgr.config.enable_alerts { return }

    // Memory alerts
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

// English text (English text)
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

    // Add to history
    append(mgr.alert_history, alert)

    // Log as scalar
    string severity_str = ""
    if sev == SEVERITY_INFO { severity_str = "INFO" }
    else if sev == SEVERITY_WARNING { severity_str = "WARNING" }
    else { severity_str = "CRITICAL" }

    log_scalar(mgr, "alerts/" + alert_type, float_of_int(sev), step)

    // Send to notification channels
    send_alert_notification(mgr, alert)

    // Console output
    print("\n⚠️  [" + severity_str + "] " + alert.message +
          "\n   Suggestion: " + alert.suggested_action + "\n")
}

// English text
func send_alert_notification(monitoring_manager mgr, alert_info alert) {
    int ch_idx = 0
    while ch_idx < len(mgr.config.alert_channels) {
        alert_channel ch = mgr.config.alert_channels[ch_idx]

        if ch == ALERT_WEBHOOK && len(mgr.config.webhook_url) > 0 {
            send_webhook_alert(mgr.config.webhook_url, alert)
        } else if ch == ALERT_CONSOLE {
            // Already printed above
        } else if ch == ALERT_LOGGER {
            write_to_log_file("[ALERT] " + alert.message)
        }
        // ... email etc.

        ch_idx = ch_idx + 1
    }
}

func send_webhook_alert(string url, alert_info alert) {
    // HTTP POST to webhook URL with JSON payload
    // ...
}

func write_to_log_file(string msg) {
    // Write message to training log file
    print(msg)
}

// ============================================================================
// 8. helperfunction & English texttool
// ============================================================================

func create_directory(string path) {
    // Create directory if it doesn't exist
    // Implementation depends on OS and file system support
    // For now, we rely on mkdir being called from Makefile
}

func log_info(string msg) {
    // Print log message to console with timestamp and newline
    // This ensures logs are visible during training
    print("[" + format_timestamp(get_current_time_ms()) + "] " + msg)
}

func get_current_time_ms() int64 {
    // Get current time in milliseconds
    // Fallback: use step-based pseudo time if system timer unavailable
    extern get_system_time_ms() int64
    return get_system_time_ms()
}

func format_timestamp(int64 time_ms) string {
    // Format milliseconds as HH:MM:SS.mmm
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
    // Generate UUID-like ID from timestamp
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

    // Simple heuristic: recent losses are consistently higher than earlier ones
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

    // Diverging if recent > 2x early and both are significant
    return recent_avg > early_avg * 2.0 && early_avg > 0.01
}

func compute_histogram_statistics([]float values, ref histogram_metric hist) {
    // Compute basic statistics
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

    // Variance
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

    // Histogram bins (simplified: use 50 fixed bins)
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

    // Count values in each bin
    i = 0
    while i < n {
        int bin_idx = int((values[i] - min_val) / bin_width)
        if bin_idx >= num_bins { bin_idx = num_bins - 1 }
        if bin_idx < 0 { bin_idx = 0 }
        hist.counts[bin_idx] = hist.counts[bin_idx] + 1
        i = i + 1
    }

    // Compute percentiles (simplified: sort and pick)
    // For efficiency in production, would use more sophisticated method
    sort_float_array(values)
    hist.p50 = values[n * 50 / 100]
    hist.p90 = values[n * 90 / 100]
    hist.p99 = values[n * 99 / 100]
}

func sort_float_array(ref []float arr) {
    // Simplified bubble sort (use quicksort in production)
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
    // NaN check: x != x
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
    // Format float to string - basic implementation
    // Converts float to string representation
    extern float_to_string(float f) string
    return float_to_string(f)
}

func string(int i) string {
    // Convert integer to string
    extern int_to_string(int i) string
    return int_to_string(i)
}

// Writer implementations
func write_scalar_to_backends(monitoring_manager m, metric_record r) {
    // Write metric to configured backends (console, tensorboard, wandb, etc.)
    if m.config.primary_backend == LOG_CONSOLE || m.config.primary_backend == LOG_ALL {
        string output = "[METRIC] " + r.name + "=" + string(r.value) + " @step " + string(r.step)
        log_info(output)
    }
    write_to_log_file(r.name + " " + string(r.value) + " step=" + string(r.step))
}

func write_histogram_to_backends(monitoring_manager m, histogram_metric h) {
    // Write histogram metric to backends
    string output = "[HIST] " + h.name + " @step " + string(h.step)
    log_info(output)
}

func write_perf_snapshot_to_backends(monitoring_manager m, performance_snapshot p) {
    // Write performance snapshot to backends
    string output = "[PERF] throughput=" + string(p.tokens_per_second) + " tokens/s, " +
                    "gpu_util=" + string(p.gpu_sm_utilization_pct) + "%, " +
                    "mem=" + string(p.gpu_memory_used_gb) + "GB @step " + string(p.step)
    log_info(output)
}

func flush_all_writers(monitoring_manager m) {
    // Flush all output writers to ensure logs are written
    log_info("Flushing all monitoring outputs...")
}

func generate_final_report(monitoring_manager m) {
    // Generate and save final training report
    log_info("Training completed. Generated " + string(len(m.scalar_history)) + " metric records")
}

// ============================================================================
// 9. NEURX-5.2 English textmonitoring Dashboard configuration
// ============================================================================

// English textrecommendedEnglish text NEURX-5.2 monitoringEnglish text
func get_monitoring_dashboard_layout() string {
    return `
╔══════════════════════════════════════════════════════════════╗
║              NEURX-5.2 Training Monitor Dashboard              ║
╠═══════════════╦═══════════════╦═══════════════════════════════╣
║   LOSS CURVE  ║   THROUGHPUT    ║      SYSTEM HEALTH            ║
║  ┌──────────┐ ║  ┌───────────┐ ║  ┌─────────────────────────┐  ║
║  │ 📉 Loss   │ ║  │ tokens/s  │ ║  │ GPU Memory ████████░░ 87%│  ║
║  │ (real-time│ ║  │ TFLOPS    │ ║  │ GPU Util   ██████████ 95%│  ║
║  │  moving   │ ║  │ samples/s │ ║  │ Grad Norm  ████░░░░░ 42  │  ║
║  │  avg)     │ ║  │ steps/min │ ║  │ LR: 3e-4 → 2.9e-4      │  ║
║  └──────────┘ ║  └───────────┘ ║  │ Status: ✅ Healthy       │  ║
╠═══════════════╩═══════════════╩═══════════════════════════════╣
║                    RECENT ALERTS                             ║
║  [✓] Step 12345: Loss within normal range (2.345)            ║
║  [!] Step 12344: GPU memory high warning (89%)              ║
╠═════════════════════════════════════════════════════════════════╣
║  Auto-Diagnosis: No critical issues found.                 ║
║  Recommendation: Training is proceeding normally.            ║
║  Expected completion: ~14 days at current throughput.       ║
╚════════════════════════════════════════════════════════════════╝
`
}

// Print a one-line status summary
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
