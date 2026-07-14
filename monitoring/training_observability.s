package neurx.monitoring.training_observability

// ═══════════════════════════════════════════════════════════════════
// Training Observability Platform — 全链路训练监控与调试工具
//
// 核心理念:
//   "You can't optimize what you can't measure"
//   — 无法衡量的东西就无法优化
//
// 监控维度 (4 大类):
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
// 关键功能:
//   ✓ 实时仪表盘: 毫秒级延迟的 metrics 收集和展示
//   ✓ 自动化诊断: 自动检测常见问题并给出建议
//   ✓ 分布式感知: 聚合多节点/多 GPU 的指标
//   ✓ 历史趋势: 保存完整历史用于事后分析
//   ✓ 告警系统: 可配置阈值 + 多通道通知 (webhook/email)
//   ✓ Profiler 集成: 支持 Nsight Systems / PyTorch Profiler 导入
//   ✓ 可视化输出: TensorBoard / WandB / 自定义 dashboard
//
// 使用场景:
//   • 实时监控大规模训练是否正常
//   • 快速定位性能瓶颈 (compute vs IO vs communication)
//   • 调试训练不收敛 / loss 不降的问题
//   • 预测 OOM 并提前干预
//   • 对比不同超参数配置的效果
// ═══════════════════════════════════════════════════════════════════

// ============================================================================
// 1. 配置结构体
// ============================================================================

enum log_backend {
    LOG_TENSORBOARD,              // TensorBoard 格式 (最常用)
    LOG_WANDB,                    // Weights & Biases (云端协作)
   _LOG_MLFLOW,                   // MLflow (实验管理)
    LOG_CUSTOM,                    // 自定义 JSON/CSV
    LOG_CONSOLE,                  // 控制台输出 (调试用)
    LOG_ALL                        // 同时输出到所有后端
}

enum alert_channel {
    ALERT_WEBHOOK,                 // Webhook (Slack/DingTalk/飞书)
    ALERT_EMAIL,                   // Email
    ALERT_CONSOLE,                 // 打印到控制台
    ALERT_LOGGER,                  // 写入日志文件
}

struct monitoring_config {
    // 基础设置
    string experiment_name          // 实验名称 (如 "NEURX-5.2-pretrain-v1")
    string run_id                    // 运行 ID (UUID 或时间戳)
    
    // 日志后端
    log_backend primary_backend       // 主要日志目标
    []log_backend additional_backends  // 额外的日志目标
    string tensorboard_log_dir       // TensorBoard 目录
    string wandb_project             // WandB 项目名
    
    // 采集频率
    int scalar_log_interval          // Scalar 指标记录间隔 (steps), 如 10
    int histogram_log_interval       // 直方图记录间隔 (steps), 如 500
    int profile_interval             // 性能 Profile 间隔 (steps), 如 1000
    int system_stats_interval        // 系统统计间隔 (seconds), 如 10
    
    // 告警配置
    bool enable_alerts               // 是否启用告警
    float loss_spike_threshold       // Loss 突增检测阈值 (如 10x 平均 loss)
    float grad_explosion_threshold   // 梯度爆炸检测阈值 (如 grad_norm > 1000)
    float gpu_memory_warning_pct     // GPU 显存警告阈值 (如 90%)
    float gpu_memory_critical_pct    // GPU 显存临界阈值 (如 95%)
    int consecutive_loss_spikes_to_alert // 连续 N 次 loss spike 后告警
    []alert_channel alert_channels    // 告警通道列表
    string webhook_url                // Webhook URL (如 Slack incoming webhook)
    
    // 高级选项
    bool enable_profiling            // 启用详细 profiling (有少量开销)
    bool track_per_layer_stats       // 追踪每层的统计 (内存开销较大)
    bool collect_attention_stats     // 收集注意力模式统计
    bool monitor_data_pipeline       // 监控数据加载流水线状态
    bool enable_auto_diagnosis       // 启用自动诊断和建议
    bool save_full_history           // 保存完整历史数据 (磁盘空间换信息)
}

// 默认配置 (针对 NEURX-5.2 训练优化)
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
        
        enable_profiling: false,  // 默认关闭以减少 overhead
        track_per_layer_stats: true,
        collect_attention_stats: true,
        monitor_data_pipeline: true,
        enable_auto_diagnosis: true,
        save_full_history: true,
    }
}

// ============================================================================
// 2. 核心 Metrics 数据结构
// ============================================================================

// 单条 Metric 记录
struct metric_record {
    string name                       // 指标名称 (如 "train/loss")
    float value                       // 数值
    int64 timestamp_ms                // 时间戳
    int step                          // 训练步数
    string tag                         // 标签 (可选,用于区分子类别)
}

// 直方图 (用于分布型指标)
struct histogram_metric {
    string name
    int step
    int64 timestamp_ms
    []float bins                      // bin 边界
    []int counts                      // 每个 bin 的计数
    float min_val
    float max_val
    float mean
    float std_dev
    float p50, p90, p99              // Percentiles
}

// 性能快照 (某个时间点的全面状态)
struct performance_snapshot {
    int64 timestamp_ms
    int step
    
    // Compute
    float tflops_achieved             // 实际达到的 TFLOPS
    float tflops_theoretical          // 理论峰值 TFLOPS
    float compute_utilization         // 计算利用率 (%)
    float samples_per_second          // 样本吞吐量
    float tokens_per_second           // Token 吞吐量
    float steps_per_second            // Step 吞吐量
    
    // Memory
    float gpu_memory_used_gb          // 已用显存 (GB)
    float gpu_memory_total_gb         // 总显存 (GB)
    float gpu_memory_peak_gb          // 峰值显存 (GB)
    float cpu_memory_used_gb           // CPU 内存使用 (GB)
    
    // Communication
    float allreduce_time_ms           // AllReduce 耗时
    float allgather_time_ms           // AllGather 耗时
    float point_to_point_time_ms      // P2P 通信耗时
    float bandwidth_utilization       // 带道利用率
    
    // Pipeline (if PP used)
    float pipeline_bubble_ratio       // Pipeline bubble 占比
    int micro_batches_in_flight       // 在途 micro-batch 数
    
    // Data loading
    float data_load_time_pct          // 数据加载耗时占比
    float data_queue_size             // 数据队列当前大小
    
    // System
    float cpu_usage_pct               // CPU 使用率
    float gpu_sm_utilization_pct      // GPU SM 利用率
    float gpu_mem_bandwidth_util_pct  // 显存带宽利用率
    float disk_io_mb_s               // 磁盘 IO 速度
    float network_rx_mb_s            // 网络接收速度
    float network_tx_mb_s            // 网络发送速度
}

// Training Health 指标
struct training_health_snapshot {
    int64 timestamp_ms
    int step
    
    // Core metrics
    float current_loss                // 当前 step 的 loss
    float moving_avg_loss             // 移动平均 loss (最近 N 步)
    float loss_variance               // Loss 方差
    float learning_rate               // 当前学习率
    float gradient_l2_norm            // 梯度 L2 范数
    float gradient_max_abs           // 梯度最大绝对值
    
    // Health checks
    bool is_loss_nan                  // Loss 是否为 NaN
    bool is_loss_inf                  // Loss 是否为 Inf
    bool is_gradient_nan              // 梯度是否有 NaN
    bool is_gradient_exploding        // 梯度爆炸
    bool is_gpu_near_oom              // 显存接近上限
    bool is_stagnating               // Loss 是否停滞不降
    bool is_diverging                 // Loss 是否发散
    
    // Alerts triggered in this snapshot
    []alert_info active_alerts        // 当前活跃的告警
    
    // Diagnostics (if enabled)
    diagnosis_result auto_diagnosis  // 自动诊断结果
}

// 告警信息
struct alert_info {
    string alert_type                  // 告警类型 (loss_spike, grad_explode, oom_warning...)
    severity_level severity           // 严重程度 (INFO / WARNING / CRITICAL)
    string message                    // 告警消息详情
    float metric_value                // 触发告警时的指标值
    float threshold_value             // 阈值
    int triggered_at_step             // 触发的 step
    int64 triggered_at_timestamp      // 触发的时间戳
    bool acknowledged                 // 是否已确认
    string suggested_action           // 建议的处理动作
}

enum severity_level {
    SEVERITY_INFO,                   // 信息性 (不影响训练)
    SEVERITY_WARNING,                // 警告 (需要注意但不紧急)
    SEVERITY_CRITICAL,               // 严重 (需要立即处理!)
}

// 自动诊断结果
struct diagnosis_result {
    string overall_status             // "healthy" / "warning" / "critical"
    string summary                    // 一句话总结
    []diagnosis_issue issues          // 发现的具体问题列表
    []recommendation recommendations  // 改进建议列表
    float confidence_score            // 诊断置信度 (0-1)
}

struct diagnosis_issue {
    string category                    // 类别 ("performance" / "health" / "system")
    string description                // 问题描述
    float impact_score                // 影响评分 (0-10,越高越严重)
    string root_cause_hint            // 可能的根本原因提示
}

struct recommendation {
    string action                      // 建议的动作
    priority prio                     // 优先级 (HIGH / MEDIUM / LOW)
    expected_improvement             // 预期改善效果描述
    complexity complexity            // 实施复杂度 (EASY / MEDIUM / HARD)
}

enum priority { PRIORITY_HIGH, PRIORITY_MEDIUM, PRIORITY_LOW }
enum complexity { COMPLEXITY_EASY, COMPLEXITY_MEDIUM, COMPLEXITY_HARD }

// ============================================================================
// 3. Monitoring Manager 主类
// ============================================================================

struct monitoring_manager {
    monitoring_config config
    bool is_running
    
    // Metrics 存储
    []metric_record scalar_history      // 所有 scalar 历史
    []histogram_metric histogram_history // 直方图历史
    []performance_snapshot perf_snapshots  // 性能快照历史
    []training_health_snapshot health_snapshots  // 健康快照历史
    
    // 当前状态缓存 (用于快速访问)
    training_health_snapshot current_health
    performance_snapshot current_perf
    
    // 统计窗口 (移动平均等)
    moving_window loss_window           // 最近 N 个 loss 值
    moving_window grad_window           // 最近 N 个 grad norm 值
    
    // Alert 系统
    []alert_info alert_history          // 历史告警
    int consecutive_loss_spike_count   // 连续 loss spike 计数
    
    // Profiler (按需启动)
    profiler_state profiler
    
    // Writers (对应各 backend)
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
    file_handle file_handles[10]  // 不同 category 用不同文件
}
struct wandb_writer { string project; string run_id }
struct console_writer { bool verbose }

// ============================================================================
// 4. 初始化 & 生命周期管理
// ============================================================================

func init_monitoring(monitoring_config cfg) monitoring_manager {
    // 创建目录
    create_directory(cfg.tensorboard_log_dir)
    
    // 初始化 writers
    tensorboard_writer tbw
    tbw.log_dir = cfg.tensorboard_log_dir
    
    console_writer cw
    cw.verbose = true
    
    // 初始化移动窗口
    moving_window lw
    lw.values = []float{cap: 100}  // 保留最近 100 个值
    lw.window_size = 100
    lw.current_index = 0
    lw.is_filled_once = false
    
    moving_window gw = lw  // grad window 同样大小
    
    // 初始化 manager
    monitoring_manager mgr
    mgr.config = cfg
    mgr.is_running = false
    mgr.scalar_history = []metric_record{}
    mgr.histogram_history = []histogram_metric{}
    mgr.perf_snapshots = []performance_snapshot{}
   _mgr.health_snapshots = []training_health_snapshot{}
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
    
    // Flush 所有 pending logs
    flush_all_writers(mgr)
    
    // 生成最终报告
    generate_final_report(mgr)
    
    log_info("Monitoring stopped. Total records logged: " + string(len(mgr.scalar_history)))
}

// ============================================================================
// 5. 核心记录接口 (供训练循环调用)
// ============================================================================

// 记录标量指标 (最常用的接口)
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
    
    // 加入历史
    append(mgr.scalar_history, record)
    
    // 更新特定缓存
    if name == "train/loss" {
        update_moving_window(ref mgr.loss_window, value)
        check_for_loss_anomalies(mgr, value, step)
    } else if name == "train/grad_norm" {
        update_moving_window(ref mgr.grad_window, value)
        check_for_grad_anomalies(mgr, value, step)
    }
    
    // 写入各 backend (如果到达 interval)
    if should_log_at_step(step, mgr.config.scalar_log_interval) {
        write_scalar_to_backends(mgr, record)
    }
}

// 记录直方图
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
    
    // 计算直方图统计
    compute_histogram_statistics(values, ref hist)
    
    append(mgr.histogram_history, hist)
    write_histogram_to_backends(mgr, hist)
}

// 记录完整的性能快照
func log_performance_snapshot(ref monitoring_manager mgr, performance_snapshot snap) {
    if !mgr.is_running { return }
    
    snap.timestamp_ms = get_current_time_ms()
    append(mgr.perf_snapshots, snap)
    mgr.current_perf = snap
    
    // 自动诊断
    if mgr.config.enable_auto_diagnosis {
        diagnosis_result diag = run_auto_diagnosis(mgr, snap)
        mgr.current_health.auto_diagnosis = diag
    }
    
    // 写入 backend
    write_perf_snapshot_to_backends(mgr, snap)
    
    // Check alerts based on system stats
    check_system_health_alerts(mgr, snap)
}

// 训练健康快照 (通常每个 step 都调用)
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
// 6. 自动诊断引擎
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
            r.action = "Increase num_workers or prefetch_factor in DataLoader"
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
        issue.impact_score = 8.0 - (mem_ratio - 0.9) * 20  // 越高越严重
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
// 7. Alert 系统
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

// 触发告警 (统一入口)
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

// 发送通知到各通道
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

func write_to_log_file(string msg) {}

// ============================================================================
// 8. 辅助函数 & 数学工具
// ============================================================================

func create_directory(string path) {}
func log_info(string msg) {}
func get_current_time_ms() int64 { return 0 }

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

func string(float f, int prec) string { return "" }
func string(int i) string { return "" }

// Writer implementations (stubs)
func write_scalar_to_backends(monitoring_manager m, metric_record r) {}
func write_histogram_to_backends(monitoring_manager m, histogram_metric h) {}
func write_perf_snapshot_to_backends(monitoring_manager m, performance_snapshot p) {}
func flush_all_writers(monitoring_manager m) {}
func generate_final_report(monitoring_manager m) {}

// ============================================================================
// 9. NEURX-5.2 特定监控 Dashboard 配置
// ============================================================================

// 创建推荐的 NEURX-5.2 监控面板布局
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
