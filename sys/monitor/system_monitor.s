package neurx.sys.monitor

use std.slices

struct system_metrics {
    int cpu_usage
    int64 memory_usage
    int gpu_usage
    int64 network_bandwidth
    int inference_latency_ms
    int throughput_ops_per_sec
}

struct resource_limit {
    int max_cpu_usage
    int64 max_memory_usage
    int max_gpu_usage
    int max_latency_ms
}

struct monitor_state {
    system_metrics metrics
    resource_limit limits
    int threshold_violations
}

func create_monitor() monitor_state {
    metrics := system_metrics {
        cpu_usage: 0,
        memory_usage: 0,
        gpu_usage: 0,
        network_bandwidth: 0,
        inference_latency_ms: 0,
        throughput_ops_per_sec: 0
    }
    
    limits := resource_limit {
        max_cpu_usage: 80,
        max_memory_usage: 32000000000,
        max_gpu_usage: 90,
        max_latency_ms: 100
    }
    
    monitor := monitor_state {
        metrics: metrics,
        limits: limits,
        threshold_violations: 0
    }
    monitor
}

func update_cpu_usage(monitor_state* monitor, cpu_usage: int) {
    monitor.metrics.cpu_usage = cpu_usage
    if cpu_usage > monitor.limits.max_cpu_usage {
        monitor.threshold_violations = monitor.threshold_violations + 1
    }
}

func update_memory_usage(monitor_state* monitor, memory_usage: int64) {
    monitor.metrics.memory_usage = memory_usage
    if memory_usage > monitor.limits.max_memory_usage {
        monitor.threshold_violations = monitor.threshold_violations + 1
    }
}

func update_gpu_usage(monitor_state* monitor, gpu_usage: int) {
    monitor.metrics.gpu_usage = gpu_usage
    if gpu_usage > monitor.limits.max_gpu_usage {
        monitor.threshold_violations = monitor.threshold_violations + 1
    }
}

func update_inference_latency(monitor_state* monitor, latency_ms: int) {
    monitor.metrics.inference_latency_ms = latency_ms
    if latency_ms > monitor.limits.max_latency_ms {
        monitor.threshold_violations = monitor.threshold_violations + 1
    }
}

func update_throughput(monitor_state* monitor, throughput: int) {
    monitor.metrics.throughput_ops_per_sec = throughput
}

func get_metrics(monitor_state* monitor) system_metrics {
    monitor.metrics
}

func get_violations(monitor_state* monitor) int {
    monitor.threshold_violations
}

func set_resource_limits(monitor_state* monitor, max_cpu: int, max_memory: int64, max_gpu: int, max_latency: int) {
    monitor.limits.max_cpu_usage = max_cpu
    monitor.limits.max_memory_usage = max_memory
    monitor.limits.max_gpu_usage = max_gpu
    monitor.limits.max_latency_ms = max_latency
}

func reset_violations(monitor_state* monitor) {
    monitor.threshold_violations = 0
}

func is_healthy(monitor_state* monitor) bool {
    cpu_ok := monitor.metrics.cpu_usage <= monitor.limits.max_cpu_usage
    mem_ok := monitor.metrics.memory_usage <= monitor.limits.max_memory_usage
    gpu_ok := monitor.metrics.gpu_usage <= monitor.limits.max_gpu_usage
    latency_ok := monitor.metrics.inference_latency_ms <= monitor.limits.max_latency_ms
    
    cpu_ok && mem_ok && gpu_ok && latency_ok
}

func get_health_score(monitor_state* monitor) int {
    cpu_score := 100 - monitor.metrics.cpu_usage
    gpu_score := 100 - monitor.metrics.gpu_usage
    
    latency_ratio := (monitor.metrics.inference_latency_ms * 100) / monitor.limits.max_latency_ms
    latency_score := 100 - latency_ratio
    
    (cpu_score + gpu_score + latency_score) / 3
}

func report_metrics(monitor_state* monitor) (int, int64, int, int) {
    (monitor.metrics.cpu_usage, monitor.metrics.memory_usage, monitor.metrics.gpu_usage, monitor.metrics.inference_latency_ms)
}
