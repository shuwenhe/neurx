package neurx.inference.monitoring

import "core"
import "tensor"

type WorkerHealthStatus struct {
    HEALTHY       int32
    DEGRADED      int32
    UNHEALTHY     int32
    OFFLINE       int32
    RECOVERING    int32
}

func WorkerHealthStatusValues() WorkerHealthStatus {
    return WorkerHealthStatus{
        HEALTHY:    0,
        DEGRADED:   1,
        UNHEALTHY:  2,
        OFFLINE:    3,
        RECOVERING: 4,
    }
}

type WorkerProcessInfo struct {
    worker_id           string
    process_id          int32
    host                string
    port                int32
    gpu_device          int32
    tensor_parallel_rank int32
    pipeline_rank       int32
    status              int32
    cpu_percent         float32
    memory_mb           int32
    max_memory_mb       int32
    gpu_percent         float32
    gpu_memory_mb       int32
    uptime_sec          int64
    last_heartbeat_ms   int64
    request_count       int64
    error_count         int64
    avg_latency_ms      float32
    throughput          float32
}

type WorkerMetrics struct {
    total_requests      int64
    successful_requests int64
    failed_requests     int64
    total_tokens        int64
    avg_latency_ms      float32
    p50_latency_ms      float32
    p95_latency_ms      float32
    p99_latency_ms      float32
    throughput          float32
    memory_peak_mb      int32
    restart_count       int32
}

type HealthCheckResult struct {
    worker_id       string
    healthy         bool
    status          int32
    response_time_ms int64
    error_message   string
    timestamp_ms    int64
}

type WorkerProcessMonitor struct {
    workers             map[string]*WorkerProcessInfo
    metrics             map[string]*WorkerMetrics
    health_check_interval_ms int64
    alert_thresholds    map[string]float32
    recovery_enabled    bool
    failover_enabled    bool
}

func NewWorkerProcessMonitor() *WorkerProcessMonitor {
    return &WorkerProcessMonitor{
        workers:                   make(map[string]*WorkerProcessInfo),
        metrics:                   make(map[string]*WorkerMetrics),
        health_check_interval_ms:  5000,
        alert_thresholds: map[string]float32{
            "cpu_percent":     80.0,
            "memory_percent":  85.0,
            "gpu_percent":     90.0,
            "error_rate":      5.0,
            "latency_p99":     1000.0,
        },
        recovery_enabled:  true,
        failover_enabled:  true,
    }
}

func (monitor *WorkerProcessMonitor) RegisterWorker(
    worker_id string,
    host string,
    port int32,
    gpu_device int32,
) {
    info := &WorkerProcessInfo{
        worker_id:           worker_id,
        process_id:          int32(core.Now().Unix() % 65536),
        host:                host,
        port:                port,
        gpu_device:          gpu_device,
        tensor_parallel_rank: -1,
        pipeline_rank:       -1,
        status:              WorkerHealthStatusValues().HEALTHY,
        cpu_percent:         0,
        memory_mb:           512,
        max_memory_mb:       16384,
        gpu_percent:         0,
        gpu_memory_mb:       2048,
        uptime_sec:          0,
        last_heartbeat_ms:   core.Now().UnixMilli(),
        request_count:       0,
        error_count:         0,
        avg_latency_ms:      0.0,
        throughput:          0.0,
    }

    monitor.workers[worker_id] = info

    metrics := &WorkerMetrics{
        total_requests:      0,
        successful_requests: 0,
        failed_requests:     0,
        total_tokens:        0,
        avg_latency_ms:      0.0,
        p50_latency_ms:      0.0,
        p95_latency_ms:      0.0,
        p99_latency_ms:      0.0,
        throughput:          0.0,
        memory_peak_mb:      512,
        restart_count:       0,
    }

    monitor.metrics[worker_id] = metrics
}

func (monitor *WorkerProcessMonitor) UpdateWorkerStats(
    worker_id string,
    cpu_percent float32,
    memory_mb int32,
    gpu_percent float32,
    gpu_memory_mb int32,
) {
    info, exists := monitor.workers[worker_id]
    if !exists {
        return
    }

    info.cpu_percent = cpu_percent
    info.memory_mb = memory_mb
    info.gpu_percent = gpu_percent
    info.gpu_memory_mb = gpu_memory_mb

    metrics, _ := monitor.metrics[worker_id]
    if memory_mb > metrics.memory_peak_mb {
        metrics.memory_peak_mb = memory_mb
    }

    status := WorkerHealthStatusValues().HEALTHY

    if cpu_percent > monitor.alert_thresholds["cpu_percent"] {
        status = WorkerHealthStatusValues().DEGRADED
    }
    if memory_mb > int32(float32(info.max_memory_mb) * 0.9) {
        status = WorkerHealthStatusValues().DEGRADED
    }
    if gpu_percent > monitor.alert_thresholds["gpu_percent"] {
        status = WorkerHealthStatusValues().DEGRADED
    }

    info.status = status
    info.last_heartbeat_ms = core.Now().UnixMilli()
}

func (monitor *WorkerProcessMonitor) RecordRequest(
    worker_id string,
    success bool,
    latency_ms int64,
    tokens int32,
) {
    info, exists := monitor.workers[worker_id]
    if !exists {
        return
    }

    metrics, _ := monitor.metrics[worker_id]

    info.request_count++
    metrics.total_requests++
    metrics.total_tokens = metrics.total_tokens + int64(tokens)

    if success {
        metrics.successful_requests++
    } else {
        info.error_count++
        metrics.failed_requests++
    }

    old_avg := metrics.avg_latency_ms
    new_count := float32(metrics.total_requests)
    metrics.avg_latency_ms = (old_avg*(new_count-1) + float32(latency_ms)) / new_count

    if latency_ms > int64(metrics.p99_latency_ms) {
        metrics.p99_latency_ms = float32(latency_ms)
    }
}

func (monitor *WorkerProcessMonitor) PerformHealthCheck(
    worker_id string,
) HealthCheckResult {
    info, exists := monitor.workers[worker_id]
    if !exists {
        return HealthCheckResult{
            worker_id:      worker_id,
            healthy:        false,
            status:         WorkerHealthStatusValues().OFFLINE,
            error_message:  "worker not registered",
            timestamp_ms:   core.Now().UnixMilli(),
        }
    }

    now_ms := core.Now().UnixMilli()
    heartbeat_age_ms := now_ms - info.last_heartbeat_ms

    healthy := info.status == WorkerHealthStatusValues().HEALTHY

    if heartbeat_age_ms > monitor.health_check_interval_ms*3 {
        healthy = false
    }

    return HealthCheckResult{
        worker_id:       worker_id,
        healthy:         healthy,
        status:          info.status,
        response_time_ms: heartbeat_age_ms,
        error_message:   "",
        timestamp_ms:    now_ms,
    }
}

func (monitor *WorkerProcessMonitor) GetWorkerStatus(worker_id string) *WorkerProcessInfo {
    return monitor.workers[worker_id]
}

func (monitor *WorkerProcessMonitor) GetWorkerMetrics(worker_id string) *WorkerMetrics {
    return monitor.metrics[worker_id]
}

func (monitor *WorkerProcessMonitor) ListAllWorkers() []string {
    workers := make([]string, 0)
    for worker_id := range monitor.workers {
        workers = append(workers, worker_id)
    }
    return workers
}

func (monitor *WorkerProcessMonitor) GetHealthySummary() map[string]int32 {
    summary := make(map[string]int32)
    summary["total"] = 0
    summary["healthy"] = 0
    summary["degraded"] = 0
    summary["unhealthy"] = 0
    summary["offline"] = 0

    for _, info := range monitor.workers {
        summary["total"]++

        switch info.status {
        case WorkerHealthStatusValues().HEALTHY:
            summary["healthy"]++
        case WorkerHealthStatusValues().DEGRADED:
            summary["degraded"]++
        case WorkerHealthStatusValues().UNHEALTHY:
            summary["unhealthy"]++
        case WorkerHealthStatusValues().OFFLINE:
            summary["offline"]++
        }
    }

    return summary
}

func (monitor *WorkerProcessMonitor) TriggerRecovery(worker_id string) bool {
    if !monitor.recovery_enabled {
        return false
    }

    info, exists := monitor.workers[worker_id]
    if !exists {
        return false
    }

    info.status = WorkerHealthStatusValues().RECOVERING
    core.Println("Recovery triggered for worker:", worker_id)

    return true
}

func (monitor *WorkerProcessMonitor) PrintMonitoringSummary() {
    core.Println("=== Worker Process Monitor Summary ===")

    summary := monitor.GetHealthySummary()
    core.Println("Total workers:", summary["total"])
    core.Println("Healthy:", summary["healthy"])
    core.Println("Degraded:", summary["degraded"])
    core.Println("Unhealthy:", summary["unhealthy"])
    core.Println("Offline:", summary["offline"])

    core.Println("\nDetailed Status:")
    for _, worker_id := range monitor.ListAllWorkers() {
        info := monitor.GetWorkerStatus(worker_id)
        metrics := monitor.GetWorkerMetrics(worker_id)

        core.Print("  [", worker_id, "] ")

        switch info.status {
        case WorkerHealthStatusValues().HEALTHY:
            core.Print("HEALTHY")
        case WorkerHealthStatusValues().DEGRADED:
            core.Print("DEGRADED")
        case WorkerHealthStatusValues().UNHEALTHY:
            core.Print("UNHEALTHY")
        case WorkerHealthStatusValues().OFFLINE:
            core.Print("OFFLINE")
        }

        core.Print(" - CPU:", info.cpu_percent, "% GPU:", info.gpu_percent, "%")
        core.Print(" - Requests:", info.request_count, " Errors:", info.error_count)
        core.Println(" - Latency:", metrics.avg_latency_ms, "ms")
    }
}

func main() {
    monitor := NewWorkerProcessMonitor()

    monitor.RegisterWorker("worker_0", "127.0.0.1", 8001, 0)
    monitor.RegisterWorker("worker_1", "127.0.0.1", 8002, 1)

    monitor.UpdateWorkerStats("worker_0", 45.0, 4096, 65.0, 8192)
    monitor.RecordRequest("worker_0", true, 50, 128)

    monitor.UpdateWorkerStats("worker_1", 70.0, 8192, 80.0, 12288)
    monitor.RecordRequest("worker_1", true, 60, 256)

    monitor.PrintMonitoringSummary()
}
