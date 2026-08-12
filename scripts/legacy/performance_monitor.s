package main
import (
    "fmt"
    "math"
    "time"
)
type performance_monitor_config struct {
    sampling_interval       int
    metrics_window          int
    alert_thresholds        map[string]float64
    enable_adaptive          bool
}
type performance_metrics struct {
    timestamp               int64
    throughput              float64
    latency_ms              float64
    memory_usage_gb         float64
    gpu_utilization         float64
    batch_size              int
    loss                    float64
    perplexity              float64
    cache_hit_rate          float64
}
type system_health_status struct {
    overall_status          string
    cpu_status              string
    memory_status           string
    gpu_status              string
    network_status          string
    alerts                  []string
}
type performance_monitor struct {
    config                  performance_monitor_config
    metrics_history         []performance_metrics
    health_history          []system_health_status
    alerts                  []alert
    recommendations         []string
}
type alert struct {
    timestamp               int64
    level                   string
    metric                  string
    value                   float64
    threshold               float64
    message                 string
}

func (monitor *performance_monitor) collect_metrics() performance_metrics {
    sample_idx := float64(len(monitor.metrics_history))
    perplexity := 100.0 / (float64(len(monitor.metrics_history)/100) + 1.0)
    if perplexity < 1.0 {
        perplexity = 1.0
    }
    metrics := performance_metrics{
        timestamp: time.Now().Unix(),
        throughput: 500.0 + math.Sin(sample_idx/10.0)*100.0,
        latency_ms: 100.0 + math.Sin(sample_idx/15.0)*20.0,
        memory_usage_gb: 16.0 + math.Sin(sample_idx/20.0)*2.0,
        gpu_utilization: 60.0 + math.Sin(sample_idx/12.0)*25.0,
        batch_size: 32,
        loss: math.Max(0.05, 2.0-math.Log(sample_idx+1.0)*0.1),
        perplexity: perplexity,
        cache_hit_rate: 0.8 + math.Sin(sample_idx/25.0)*0.1,
    }
    monitor.metrics_history = append(monitor.metrics_history, metrics)
    if len(monitor.metrics_history) > monitor.config.metrics_window {
        monitor.metrics_history = monitor.metrics_history[1:]
    }
    return metrics
}

func (monitor *performance_monitor) assess_health() system_health_status {
    status := system_health_status{
        overall_status: "healthy",
        cpu_status: "normal",
        memory_status: "normal",
        gpu_status: "normal",
        network_status: "normal",
        alerts: []string{},
    }
    if len(monitor.metrics_history) == 0 {
        return status
    }
    latest := monitor.metrics_history[len(monitor.metrics_history)-1]
    if latest.memory_usage_gb > 30.0 {
        status.memory_status = "warning"
        status.alerts = append(status.alerts,
            fmt.Sprintf("High memory usage: %.2f GB", latest.memory_usage_gb))
    }
    if latest.gpu_utilization > 95.0 {
        status.gpu_status = "critical"
        status.alerts = append(status.alerts,
            fmt.Sprintf("GPU saturated: %.1f%%", latest.gpu_utilization))
    }
    if latest.memory_usage_gb > 36.0 {
        status.memory_status = "critical"
        status.alerts = append(status.alerts,
            fmt.Sprintf("Memory critical: %.2f GB", latest.memory_usage_gb))
    }
    if latest.latency_ms > 200.0 {
        status.overall_status = "degraded"
        status.alerts = append(status.alerts,
            fmt.Sprintf("High latency: %.1f ms", latest.latency_ms))
    }
    if len(status.alerts) > 0 {
        if status.overall_status == "healthy" {
            status.overall_status = "degraded"
        }
    }
    if status.gpu_status == "critical" || status.memory_status == "critical" {
        status.overall_status = "critical"
    }
    monitor.health_history = append(monitor.health_history, status)
    return status
}

func (monitor *performance_monitor) check_alerts() []alert {
    alerts := []alert{}
    if len(monitor.metrics_history) == 0 {
        return alerts
    }
    latest := monitor.metrics_history[len(monitor.metrics_history)-1]
    if threshold, ok := monitor.config.alert_thresholds["throughput_min"]; ok {
        if latest.throughput < threshold {
            alerts = append(alerts, alert{
                timestamp: latest.timestamp,
                level: "warning",
                metric: "throughput",
                value: latest.throughput,
                threshold: threshold,
                message: fmt.Sprintf("Throughput low: %.1f tok/s (threshold: %.1f)",
                    latest.throughput, threshold),
            })
        }
    }
    if threshold, ok := monitor.config.alert_thresholds["latency_max"]; ok {
        if latest.latency_ms > threshold {
            alerts = append(alerts, alert{
                timestamp: latest.timestamp,
                level: "warning",
                metric: "latency",
                value: latest.latency_ms,
                threshold: threshold,
                message: fmt.Sprintf("Latency high: %.1f ms (threshold: %.1f)",
                    latest.latency_ms, threshold),
            })
        }
    }
    if threshold, ok := monitor.config.alert_thresholds["memory_max"]; ok {
        if latest.memory_usage_gb > threshold {
            level := "warning"
            if latest.memory_usage_gb > threshold*1.2 {
                level = "critical"
            }
            alerts = append(alerts, alert{
                timestamp: latest.timestamp,
                level: level,
                metric: "memory",
                value: latest.memory_usage_gb,
                threshold: threshold,
                message: fmt.Sprintf("Memory high: %.1f GB (threshold: %.1f)",
                    latest.memory_usage_gb, threshold),
            })
        }
    }
    if threshold, ok := monitor.config.alert_thresholds["gpu_utilization_max"]; ok {
        if latest.gpu_utilization > threshold {
            alerts = append(alerts, alert{
                timestamp: latest.timestamp,
                level: "warning",
                metric: "gpu_utilization",
                value: latest.gpu_utilization,
                threshold: threshold,
                message: fmt.Sprintf("GPU high: %.1f%% (threshold: %.1f%%)",
                    latest.gpu_utilization, threshold),
            })
        }
    }
    monitor.alerts = append(monitor.alerts, alerts...)
    return alerts
}

func (monitor *performance_monitor) generate_recommendations() {
    monitor.recommendations = []string{}
    if len(monitor.metrics_history) < 2 {
        return
    }
    latest := monitor.metrics_history[len(monitor.metrics_history)-1]
    prev := monitor.metrics_history[len(monitor.metrics_history)-2]
    if latest.memory_usage_gb > prev.memory_usage_gb*1.1 {
        monitor.recommendations = append(monitor.recommendations,
            "Consider reducing batch size to lower memory usage")
    }
    if latest.latency_ms > prev.latency_ms*1.15 {
        monitor.recommendations = append(monitor.recommendations,
            "Latency increasing - consider enabling inference optimization")
    }
    if latest.gpu_utilization < 50.0 {
        monitor.recommendations = append(monitor.recommendations,
            "GPU underutilized - consider increasing batch size")
    }
    if latest.gpu_utilization > 90.0 {
        monitor.recommendations = append(monitor.recommendations,
            "GPU saturated - consider reducing batch size")
    }
    if len(monitor.metrics_history) > 10 {
        recent_ppls := []float64{}
        for i := len(monitor.metrics_history)-10; i < len(monitor.metrics_history); i++ {
            recent_ppls = append(recent_ppls, monitor.metrics_history[i].perplexity)
        }
        improvement := recent_ppls[0] - recent_ppls[len(recent_ppls)-1]
        if improvement < 0.1 {
            monitor.recommendations = append(monitor.recommendations,
                "Perplexity plateau - consider adjusting learning rate")
        }
    }
}

func (monitor *performance_monitor) print_dashboard() {
    if len(monitor.metrics_history) == 0 {
        fmt.Println("No metrics collected yet")
        return
    }
    latest := monitor.metrics_history[len(monitor.metrics_history)-1]
    health := monitor.assess_health()
    fmt.Println("\n╔════════════════════════════════════════════════════════╗")
    fmt.Println("║  Performance Monitoring Dashboard                     ║")
    fmt.Println("╚════════════════════════════════════════════════════════╝\n")
    fmt.Printf("System status: %s\n", health.overall_status)
    fmt.Println("\nReal-time Metrics:")
    fmt.Printf("  Throughput: %.1f tokens/sec\n", latest.throughput)
    fmt.Printf("  Latency: %.2f ms\n", latest.latency_ms)
    fmt.Printf("  Memory: %.2f GB\n", latest.memory_usage_gb)
    fmt.Printf("  GPU Utilization: %.1f%%\n", latest.gpu_utilization)
    fmt.Printf("  cache Hit Rate: %.1f%%\n", latest.cache_hit_rate*100)
    fmt.Println("\nTraining Progress:")
    fmt.Printf("  Loss: %.4f\n", latest.loss)
    fmt.Printf("  Perplexity: %.2f\n", latest.perplexity)
    fmt.Printf("  batch_2 Size: %d\n", latest.batch_size)
    if len(health.alerts) > 0 {
        fmt.Println("\nAlerts:")
        for i, alert := range health.alerts {
            fmt.Printf("  %d. %s\n", i+1, alert)
        }
    }
    monitor.generate_recommendations()
    if len(monitor.recommendations) > 0 {
        fmt.Println("\nRecommendations:")
        for i, rec := range monitor.recommendations {
            fmt.Printf("  %d. %s\n", i+1, rec)
        }
    }
}

func (monitor *performance_monitor) snapshot_summary() string {
    if len(monitor.metrics_history) == 0 {
        return "no metrics collected"
    }
    latest := monitor.metrics_history[len(monitor.metrics_history)-1]
    health := monitor.assess_health()
    return fmt.Sprintf(
        "status=%s throughput=%.1f latency=%.1fms memory=%.2fGB gpu=%.1f%% loss=%.4f ppl=%.2f alerts=%d",
        health.overall_status,
        latest.throughput,
        latest.latency_ms,
        latest.memory_usage_gb,
        latest.gpu_utilization,
        latest.loss,
        latest.perplexity,
        len(health.alerts),
    )
}

func new_performance_monitor() *performance_monitor {
    return &performance_monitor{
        config: performance_monitor_config{
            sampling_interval: 5,
            metrics_window: 100,
            alert_thresholds: map[string]float64{
                "throughput_min": 300.0,
                "latency_max": 150.0,
                "memory_max": 40.0,
                "gpu_utilization_max": 95.0,
            },
            enable_adaptive: true,
        },
        metrics_history: []performance_metrics{},
        health_history: []system_health_status{},
        alerts: []alert{},
        recommendations: []string{},
    }
}

func (monitor *performance_monitor) monitor_training(duration_steps int) {
    fmt.Println("╔════════════════════════════════════════════════════════╗")
    fmt.Println("║  Performance Monitoring System                        ║")
    fmt.Println("║  Real-time tracking and adaptive optimization         ║")
    fmt.Println("╚════════════════════════════════════════════════════════╝\n")
    for step := 0; step < duration_steps; step++ {
        metrics := monitor.collect_metrics()
        monitor.check_alerts()
        if (step+1) % 10 == 0 {
            fmt.Printf("[Step %d] Throughput: %.1f tok/s, Latency: %.1f ms, GPU: %.1f%%\n",
                step+1, metrics.throughput, metrics.latency_ms, metrics.gpu_utilization)
        }
    }
    monitor.print_dashboard()
}

