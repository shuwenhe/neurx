module observability_distributed_metrics
    COUNTER,
    GAUGE,
    HISTOGRAM,
    TIMER,
}

structure metric_definition {
    string name
    string description
    metric_type mtype
    string unit
    vector tags
}

structure metric_value {
    float timestamp
    float value
    int rank
    vector tags
}

structure training_metrics {
    int global_step
    int epoch
    float timestamp
    float loss
    float loss_ema
    float loss_std
    float tokens_per_second
    float samples_per_second
    float tflops_per_gpu
    float forward_time
    float backward_time
    float optimizer_time
    float communication_time
    float data_loading_time
    float reserved_memory_gb
    float allocated_memory_gb
    float peak_memory_gb
    float all_reduce_time
    float all_to_all_time
    float all_gather_time
    float reduce_scatter_time
    float communication_volume_gb
    float gradient_norm
    float gradient_max
    float gradient_min
    int num_nan_gradients
}

structure rank_metrics {
    int rank
    training_metrics metrics
    float gpu_utilization
    float gpu_memory_used_gb
    float network_sent_gb
    float network_recv_gb
}

structure metrics_aggregator {
    int window_size
    vector history
    training_metrics current_metrics
    vector all_rank_metrics
    vector loss_history
    vector throughput_history
    float loss_spike_threshold
    float throughput_drop_threshold
    float memory_threshold_gb
}

structure anomaly_detector {
    float loss_divergence_threshold
    float gradient_explosion_threshold
    float throughput_drop_threshold
    float prev_loss
    float prev_throughput
    int anomaly_count
}

func new_metrics_aggregator(int window_size): metrics_aggregator {
    agg := metrics_aggregator
    agg.window_size = window_size
    agg.history = allocate_vector(window_size, 0.0)
    agg.loss_history = allocate_vector(window_size, 0.0)
    agg.throughput_history = allocate_vector(window_size, 0.0)
    agg.loss_spike_threshold = 2.0
    agg.throughput_drop_threshold = 0.8
    agg.memory_threshold_gb = 78.0
    return agg
}

func collect_training_metrics(
    int global_step,
    int epoch,
    float loss,
    vector predictions,
    vector targets,
    vector model_params,
    vector gradients,
    float forward_time_ms,
    float backward_time_ms,
    float optimizer_time_ms,
    float communication_time_ms,
    float data_load_time_ms,
    int batch_size,
    int sequence_length,
    float reserved_memory_gb,
    float allocated_memory_gb,
    float peak_memory_gb,
    float comm_volume_gb
): training_metrics {
    metrics := training_metrics
    metrics.global_step = global_step
    metrics.epoch = epoch
    metrics.timestamp = get_time()
    metrics.loss = loss
    metrics.loss_ema = 0.9 * metrics.loss_ema + 0.1 * loss
    total_time_ms := forward_time_ms + backward_time_ms + optimizer_time_ms + communication_time_ms
    tokens_processed := batch_size * sequence_length
    metrics.tokens_per_second = float(tokens_processed) / (total_time_ms / 1000.0)
    metrics.samples_per_second = float(batch_size) / (total_time_ms / 1000.0)
    estimated_flops := 32.0e15
    metrics.tflops_per_gpu = (estimated_flops * 2.0) / (total_time_ms / 1000.0) / 1e12
    metrics.forward_time = forward_time_ms
    metrics.backward_time = backward_time_ms
    metrics.optimizer_time = optimizer_time_ms
    metrics.communication_time = communication_time_ms
    metrics.data_loading_time = data_load_time_ms
    metrics.reserved_memory_gb = reserved_memory_gb
    metrics.allocated_memory_gb = allocated_memory_gb
    metrics.peak_memory_gb = peak_memory_gb
    metrics.communication_volume_gb = comm_volume_gb
    metrics.gradient_norm = compute_vector_norm(gradients)
    metrics.gradient_max = compute_vector_max(gradients)
    metrics.gradient_min = compute_vector_min(gradients)
    num_nan := 0
    for i in range(0, length(gradients)) {
        if is_nan(gradients[i]) {
            num_nan = num_nan + 1
        }
    }
    metrics.num_nan_gradients = num_nan
    return metrics
}

func collect_rank_metrics(
    int rank,
    training_metrics metrics,
    float gpu_utilization_percent,
    float gpu_memory_used_gb,
    float network_sent_gb,
    float network_recv_gb
): rank_metrics {
    rank_m := rank_metrics
    rank_m.rank = rank
    rank_m.metrics = metrics
    rank_m.gpu_utilization = gpu_utilization_percent
    rank_m.gpu_memory_used_gb = gpu_memory_used_gb
    rank_m.network_sent_gb = network_sent_gb
    rank_m.network_recv_gb = network_recv_gb
    return rank_m
}

func aggregate_metrics_across_ranks(
    vector all_rank_metrics,
    int num_ranks,
    metrics_aggregator aggregator
): training_metrics {
    agg_metrics := training_metrics
    if num_ranks <= 0 {
        return agg_metrics
    }
    agg_metrics.global_step = all_rank_metrics[0].metrics.global_step
    agg_metrics.epoch = all_rank_metrics[0].metrics.epoch
    agg_metrics.timestamp = get_time()
    sum_loss := 0.0
    sum_tokens_per_sec := 0.0
    sum_tflops := 0.0
    max_memory := 0.0
    sum_comm_time := 0.0
    sum_comm_volume := 0.0
    for i in range(0, num_ranks) {
        rank_m := all_rank_metrics[i].metrics
        sum_loss = sum_loss + rank_m.loss
        sum_tokens_per_sec = sum_tokens_per_sec + rank_m.tokens_per_second
        sum_tflops = sum_tflops + rank_m.tflops_per_gpu
        max_memory = max(max_memory, rank_m.peak_memory_gb)
        sum_comm_time = sum_comm_time + rank_m.communication_time
        sum_comm_volume = sum_comm_volume + rank_m.communication_volume_gb
    }
    agg_metrics.loss = sum_loss / float(num_ranks)
    agg_metrics.tokens_per_second = sum_tokens_per_sec / float(num_ranks)
    agg_metrics.tflops_per_gpu = sum_tflops / float(num_ranks)
    agg_metrics.peak_memory_gb = max_memory
    agg_metrics.communication_time = sum_comm_time / float(num_ranks)
    agg_metrics.communication_volume_gb = sum_comm_volume
    return agg_metrics
}

func detect_anomalies(
    training_metrics current_metrics,
    anomaly_detector detector
): (bool, string) {
    is_anomaly := false
    description := ""
    if detector.prev_loss > 0.0 {
        loss_ratio := current_metrics.loss / detector.prev_loss
        if loss_ratio > detector.loss_divergence_threshold {
            is_anomaly = true
            description = "Loss divergence: " + str(loss_ratio) + "x increase"
        }
    }
    detector.prev_loss = current_metrics.loss
    if current_metrics.gradient_max > detector.gradient_explosion_threshold {
        is_anomaly = true
        description = "Gradient explosion: max_grad = " + str(current_metrics.gradient_max)
    }
    if detector.prev_throughput > 0.0 {
        throughput_ratio := current_metrics.tokens_per_second / detector.prev_throughput
        if throughput_ratio < detector.throughput_drop_threshold {
            is_anomaly = true
            description = "Throughput drop: " + str(throughput_ratio) + "x decrease"
        }
    }
    detector.prev_throughput = current_metrics.tokens_per_second
    if is_nan(current_metrics.loss) || current_metrics.num_nan_gradients > 0 {
        is_anomaly = true
        description = "NaN detected in loss or gradients"
    }
    if current_metrics.peak_memory_gb > detector.throughput_drop_threshold {
        is_anomaly = true
        description = "Memory usage exceeded threshold"
    }
    if is_anomaly {
        detector.anomaly_count = detector.anomaly_count + 1
    }
    return is_anomaly, description
}

func compute_timing_breakdown(
    training_metrics metrics
): (float, float, float, float, float) {
    total_time := metrics.forward_time + metrics.backward_time + metrics.optimizer_time +
                            metrics.communication_time + metrics.data_loading_time
    if total_time <= 0.0 {
        return 0.0, 0.0, 0.0, 0.0, 0.0
    }
    pct_forward := (metrics.forward_time / total_time) * 100.0
    pct_backward := (metrics.backward_time / total_time) * 100.0
    pct_optimizer := (metrics.optimizer_time / total_time) * 100.0
    pct_communication := (metrics.communication_time / total_time) * 100.0
    pct_data_load := (metrics.data_loading_time / total_time) * 100.0
    return pct_forward, pct_backward, pct_optimizer, pct_communication, pct_data_load
}

func identify_communication_bottlenecks(
    training_metrics metrics,
    int num_ranks,
    int num_layers
): string {
    bottleneck_info := ""
    total_compute_time := metrics.forward_time + metrics.backward_time + metrics.optimizer_time
    comm_ratio := metrics.communication_time / total_compute_time
    if comm_ratio > 0.2 {
        bottleneck_info = "High communication overhead: " + str(comm_ratio * 100.0) + "%"
    }
    avg_comm_per_layer := metrics.communication_time / float(num_layers)
    if avg_comm_per_layer > 100.0 {
        bottleneck_info = bottleneck_info + "\nLarge all-reduce latency: " + str(avg_comm_per_layer) + "ms per layer"
    }
    all_reduce_ratio := metrics.all_reduce_time / metrics.communication_time
    if all_reduce_ratio > 0.5 {
        bottleneck_info = bottleneck_info + "\nAll-reduce dominates: " + str(all_reduce_ratio * 100.0) + "%"
    }
    return bottleneck_info
}

func print_metrics_summary(
    training_metrics metrics,
    metrics_aggregator aggregator
): void {
    (pct_fwd, pct_bwd, pct_opt, pct_comm, pct_data) := compute_timing_breakdown(metrics)
    println("===== Training Metrics (Step " + str(metrics.global_step) + ") =====")
    println("Loss: " + str(metrics.loss) + " (EMA: " + str(metrics.loss_ema) + ")")
    println("Throughput: " + str(metrics.tokens_per_second) + " tokens/sec")
    println("TFLOPS/GPU: " + str(metrics.tflops_per_gpu) + " TFLOPS")
    println("Timing: " + str(pct_fwd) + "% fwd, " + str(pct_bwd) + "% bwd, " + str(pct_opt) + "% opt, " +
            str(pct_comm) + "% comm, " + str(pct_data) + "% data")
    println("Memory: " + str(metrics.allocated_memory_gb) + "GB / " + str(metrics.reserved_memory_gb) + "GB reserved")
    println("Grad norm: " + str(metrics.gradient_norm) + " (max: " + str(metrics.gradient_max) + ")")
}

func export_metrics_to_file(
    training_metrics metrics,
    string output_file
): void {
}

func new_anomaly_detector(): anomaly_detector {
    detector := anomaly_detector
    detector.loss_divergence_threshold = 5.0
    detector.gradient_explosion_threshold = 1e8
    detector.throughput_drop_threshold = 0.8
    detector.prev_loss = 0.0
    detector.prev_throughput = 0.0
    detector.anomaly_count = 0
    return detector
}

func compute_vector_norm(vector v): float {
    norm_sq := 0.0
    for i in range(0, length(v)) {
        norm_sq = norm_sq + v[i] * v[i]
    }
    return sqrt(norm_sq)
}

func compute_vector_max(vector v): float {
    max_val := -inf
    for i in range(0, length(v)) {
        if abs(v[i]) > max_val {
            max_val = abs(v[i])
        }
    }
    return max_val
}

func compute_vector_min(vector v): float {
    min_val := inf
    for i in range(0, length(v)) {
        if abs(v[i]) < min_val {
            min_val = abs(v[i])
        }
    }
    return min_val
}

func get_time(): float {
    return 0.0
}

func is_nan(float val): bool {
    return val != val
}

func println(string msg): void {
}

func recommended_monitoring_config_2t(): metrics_aggregator {
    return new_metrics_aggregator(1000)
}
