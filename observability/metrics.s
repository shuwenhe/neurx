package neurx.observability.metrics
struct metric_counter {
    string name
    string help
    int value
    map[string]string labels
}

struct metric_gauge {
    string name
    string help
    float value
    map[string]string labels
}

struct metric_histogram {
    string name
    string help
    []float buckets
    []int bucket_counts
    map[string]string labels
}

struct inference_metrics {
    metric_counter requests_total
    metric_counter requests_success
    metric_counter requests_failed
    metric_gauge requests_in_progress
    metric_histogram request_latency_ms
    metric_gauge avg_latency_ms
    metric_gauge p99_latency_ms
    metric_gauge p95_latency_ms
    metric_gauge tokens_per_second
    metric_gauge requests_per_second
    metric_gauge gpu_memory_used_mb
    metric_gauge gpu_memory_total_mb
    metric_gauge gpu_utilization_percent
    metric_gauge gpu_temperature_celsius
    metric_gauge model_load_time_ms
    metric_gauge model_cache_hits
    metric_gauge model_cache_misses
    float cache_hit_rate
    metric_gauge batch_size_avg
    metric_gauge batch_size_max
    metric_gauge batch_latency_ms
}

struct prometheus_registry {
    []metric_counter counters
    []metric_gauge gauges
    []metric_histogram histograms
}

func init_inference_metrics() inference_metrics {
    inference_metrics {
        requests_total: metric_counter{
            name: "neurx_requests_total",
            help: "Total number of inference requests",
            value: 0,
            labels: map[string]string{},
        },
        requests_success: metric_counter{
            name: "neurx_requests_success",
            help: "Successful inference requests",
            value: 0,
            labels: map[string]string{},
        },
        requests_failed: metric_counter{
            name: "neurx_requests_failed",
            help: "Failed inference requests",
            value: 0,
            labels: map[string]string{},
        },
        requests_in_progress: metric_gauge{
            name: "neurx_requests_in_progress",
            help: "Current in-progress requests",
            value: 0.0,
            labels: map[string]string{},
        },
        request_latency_ms: metric_histogram{
            name: "neurx_request_latency_ms",
            help: "Request latency distribution",
            buckets: []float{1.0, 10.0, 50.0, 100.0, 500.0, 1000.0, 5000.0},
            bucket_counts: []int{0, 0, 0, 0, 0, 0, 0},
            labels: map[string]string{},
        },
        avg_latency_ms: metric_gauge{
            name: "neurx_avg_latency_ms",
            help: "Average request latency",
            value: 0.0,
            labels: map[string]string{},
        },
        p99_latency_ms: metric_gauge{
            name: "neurx_p99_latency_ms",
            help: "P99 request latency",
            value: 0.0,
            labels: map[string]string{},
        },
        p95_latency_ms: metric_gauge{
            name: "neurx_p95_latency_ms",
            help: "P95 request latency",
            value: 0.0,
            labels: map[string]string{},
        },
        tokens_per_second: metric_gauge{
            name: "neurx_tokens_per_second",
            help: "Token generation throughput",
            value: 0.0,
            labels: map[string]string{},
        },
        requests_per_second: metric_gauge{
            name: "neurx_requests_per_second",
            help: "Request throughput",
            value: 0.0,
            labels: map[string]string{},
        },
        gpu_memory_used_mb: metric_gauge{
            name: "neurx_gpu_memory_used_mb",
            help: "GPU memory currently in use",
            value: 0.0,
            labels: map[string]string{},
        },
        gpu_memory_total_mb: metric_gauge{
            name: "neurx_gpu_memory_total_mb",
            help: "Total GPU memory",
            value: 12288.0,
            labels: map[string]string{},
        },
        gpu_utilization_percent: metric_gauge{
            name: "neurx_gpu_utilization_percent",
            help: "GPU utilization percentage",
            value: 0.0,
            labels: map[string]string{},
        },
        gpu_temperature_celsius: metric_gauge{
            name: "neurx_gpu_temperature_celsius",
            help: "GPU temperature in Celsius",
            value: 0.0,
            labels: map[string]string{},
        },
        model_load_time_ms: metric_gauge{
            name: "neurx_model_load_time_ms",
            help: "Time to load model",
            value: 0.0,
            labels: map[string]string{},
        },
        model_cache_hits: metric_gauge{
            name: "neurx_model_cache_hits",
            help: "KV cache hits",
            value: 0.0,
            labels: map[string]string{},
        },
        model_cache_misses: metric_gauge{
            name: "neurx_model_cache_misses",
            help: "KV cache misses",
            value: 0.0,
            labels: map[string]string{},
        },
        cache_hit_rate: 0.0,
        batch_size_avg: metric_gauge{
            name: "neurx_batch_size_avg",
            help: "Average batch size",
            value: 0.0,
            labels: map[string]string{},
        },
        batch_size_max: metric_gauge{
            name: "neurx_batch_size_max",
            help: "Maximum batch size",
            value: 0.0,
            labels: map[string]string{},
        },
        batch_latency_ms: metric_gauge{
            name: "neurx_batch_latency_ms",
            help: "Batch processing latency",
            value: 0.0,
            labels: map[string]string{},
        },
    }
}

func record_request(inference_metrics m, bool success, float latency_ms) inference_metrics {
    m.requests_total.value = m.requests_total.value + 1
    if success {
        m.requests_success.value = m.requests_success.value + 1
    } else {
        m.requests_failed.value = m.requests_failed.value + 1
    }
    m.avg_latency_ms.value = (m.avg_latency_ms.value * float(m.requests_total.value - 1) + latency_ms) / float(m.requests_total.value)
    m
}

func record_batch(inference_metrics m, int batch_size, float latency_ms) inference_metrics {
    m.batch_size_avg.value = (m.batch_size_avg.value + float(batch_size)) / 2.0
    if float(batch_size) > m.batch_size_max.value {
        m.batch_size_max.value = float(batch_size)
    }
    m.batch_latency_ms.value = latency_ms
    m
}

func record_gpu_metrics(
    inference_metrics m,
    float memory_used_mb,
    float memory_total_mb,
    float utilization_percent,
    float temperature_celsius,
) inference_metrics {
    m.gpu_memory_used_mb.value = memory_used_mb
    m.gpu_memory_total_mb.value = memory_total_mb
    m.gpu_utilization_percent.value = utilization_percent
    m.gpu_temperature_celsius.value = temperature_celsius
    m
}

func update_cache_metrics(
    inference_metrics m,
    float hits,
    float misses,
) inference_metrics {
    m.model_cache_hits.value = hits
    m.model_cache_misses.value = misses
    if hits + misses > 0.0 {
        m.cache_hit_rate = hits / (hits + misses)
    }
    m
}

func export_prometheus_metrics(inference_metrics m) string {
    string output = ""
    output = output + "# HELP neurx_requests_total Total number of inference requests\n"
    output = output + "# TYPE neurx_requests_total counter\n"
    output = output + "neurx_requests_total " + int_to_str(m.requests_total.value) + "\n"
    output = output + "# HELP neurx_requests_success Successful inference requests\n"
    output = output + "# TYPE neurx_requests_success counter\n"
    output = output + "neurx_requests_success " + int_to_str(m.requests_success.value) + "\n"
    output = output + "# HELP neurx_requests_failed Failed inference requests\n"
    output = output + "# TYPE neurx_requests_failed counter\n"
    output = output + "neurx_requests_failed " + int_to_str(m.requests_failed.value) + "\n"
    output = output + "# HELP neurx_requests_in_progress Current in-progress requests\n"
    output = output + "# TYPE neurx_requests_in_progress gauge\n"
    output = output + "neurx_requests_in_progress " + float_to_str(m.requests_in_progress.value) + "\n"
    output = output + "# HELP neurx_avg_latency_ms Average request latency\n"
    output = output + "# TYPE neurx_avg_latency_ms gauge\n"
    output = output + "neurx_avg_latency_ms " + float_to_str(m.avg_latency_ms.value) + "\n"
    output = output + "# HELP neurx_p99_latency_ms P99 request latency\n"
    output = output + "# TYPE neurx_p99_latency_ms gauge\n"
    output = output + "neurx_p99_latency_ms " + float_to_str(m.p99_latency_ms.value) + "\n"
    output = output + "# HELP neurx_tokens_per_second Token generation throughput\n"
    output = output + "# TYPE neurx_tokens_per_second gauge\n"
    output = output + "neurx_tokens_per_second " + float_to_str(m.tokens_per_second.value) + "\n"
    output = output + "# HELP neurx_gpu_memory_used_mb GPU memory currently in use\n"
    output = output + "# TYPE neurx_gpu_memory_used_mb gauge\n"
    output = output + "neurx_gpu_memory_used_mb " + float_to_str(m.gpu_memory_used_mb.value) + "\n"
    output = output + "# HELP neurx_gpu_utilization_percent GPU utilization percentage\n"
    output = output + "# TYPE neurx_gpu_utilization_percent gauge\n"
    output = output + "neurx_gpu_utilization_percent " + float_to_str(m.gpu_utilization_percent.value) + "\n"
    output = output + "# HELP neurx_cache_hit_rate KV cache hit rate\n"
    output = output + "# TYPE neurx_cache_hit_rate gauge\n"
    output = output + "neurx_cache_hit_rate " + float_to_str(m.cache_hit_rate) + "\n"
    output
}

struct health_status {
    bool healthy
    string status
    string message
    int uptime_seconds
}

func check_system_health(inference_metrics m) health_status {
    bool healthy = true
    string status = "healthy"
    string message = "All systems operational"
    if m.requests_failed.value > 0 {
        status = "degraded"
        message = "Some requests failed"
    }
    if m.gpu_temperature_celsius.value > 85.0 {
        status = "degraded"
        message = "GPU temperature high"
    }
    if m.gpu_utilization_percent.value < 10.0 && m.requests_total.value > 0 {
        status = "degraded"
        message = "Low GPU utilization"
    }
    health_status {
        healthy: healthy,
        status: status,
        message: message,
        uptime_seconds: 3600,
    }
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    bool neg = n < 0
    if neg {
        n = -n
    }
    string s = ""
    while n > 0 {
        s = string((n % 10) + 48) + s
        n = n / 10
    }
    if neg {
        s = "-" + s
    }
    return s
}

func float_to_str(float f) string {
    int int_part = int(f)
    int frac_part = int((f - float(int_part)) * 100.0)
    if frac_part < 0 {
        frac_part = -frac_part
    }
    return int_to_str(int_part) + "." + int_to_str(frac_part)
}

func int(float f) int {
    if f >= 0.0 {
        int(f + 0.5)
    } else {
        int(f - 0.5)
    }
}

