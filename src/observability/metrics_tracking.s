package v1
struct latency_metrics {
    float32 min_latency_ms
    float32 max_latency_ms
    float32 avg_latency_ms
    float32 p50_latency_ms
    float32 p95_latency_ms
    float32 p99_latency_ms
}

struct throughput_metrics {
    int32 requests_per_sec
    int32 tokens_per_sec
    int32 batches_per_sec
    float32 avg_batch_size
}

struct cache_metrics {
    int32 total_blocks
    int32 free_blocks
    int32 used_blocks
    int32 allocated_requests
    float32 cache_utilization_percent
    int32 evicted_requests
}

struct system_metrics {
    int32 total_requests_received
    int32 total_requests_completed
    int32 total_requests_failed
    int32 total_requests_cancelled
    int32 current_active_requests
    int32 current_pending_requests
    float32 system_uptime_sec
}

struct gpu_metrics {
    float32 gpu_memory_used_gb
    float32 gpu_memory_total_gb
    float32 gpu_utilization_percent
    float32 kernel_launch_rate
    int32 gpu_errors
}

struct metrics_tracker {
    system_metrics system
    latency_metrics latency
    throughput_metrics throughput
    cache_metrics cache
    gpu_metrics gpu
    int32[] latency_samples
    int32[] batch_sizes
    int32[] token_counts
    int64 start_time
    int64 last_update_time
}

func create_metrics_tracker() metrics_tracker* {
    return *metrics_tracker{
        system: system_metrics{
            total_requests_received: 0,
            total_requests_completed: 0,
            total_requests_failed: 0,
            total_requests_cancelled: 0,
            current_active_requests: 0,
            current_pending_requests: 0,
            system_uptime_sec: 0.0,
        },
        latency: latency_metrics{
            min_latency_ms: 0.0,
            max_latency_ms: 0.0,
            avg_latency_ms: 0.0,
            p50_latency_ms: 0.0,
            p95_latency_ms: 0.0,
            p99_latency_ms: 0.0,
        },
        throughput: throughput_metrics{
            requests_per_sec: 0,
            tokens_per_sec: 0,
            batches_per_sec: 0,
            avg_batch_size: 0.0,
        },
        cache: cache_metrics{
            total_blocks: 8192,
            free_blocks: 8192,
            used_blocks: 0,
            allocated_requests: 0,
            cache_utilization_percent: 0.0,
            evicted_requests: 0,
        },
        gpu: gpu_metrics{
            gpu_memory_used_gb: 0.0,
            gpu_memory_total_gb: 80.0,
            gpu_utilization_percent: 0.0,
            kernel_launch_rate: 0,
            gpu_errors: 0,
        },
        latency_samples: make(int32[]),
        batch_sizes: make(int32[]),
        token_counts: make(int32[]),
        start_time: current_time_ns(),
        last_update_time: current_time_ns(),
    }
}

func (metrics_tracker* mt) record_request_received() {
    mt.system.total_requests_received = mt.system.total_requests_received + 1
}

func (metrics_tracker* mt) record_request_completed(int32 num_tokens, int32 latency_ms) {
    mt.system.total_requests_completed = mt.system.total_requests_completed + 1
    mt.system.current_active_requests = mt.system.current_active_requests - 1
    mt.latency_samples = append(mt.latency_samples, latency_ms)
    mt.token_counts = append(mt.token_counts, num_tokens)
}

func (metrics_tracker* mt) record_request_failed() {
    mt.system.total_requests_failed = mt.system.total_requests_failed + 1
    mt.system.current_active_requests = mt.system.current_active_requests - 1
}

func (metrics_tracker* mt) record_request_cancelled() {
    mt.system.total_requests_cancelled = mt.system.total_requests_cancelled + 1
    mt.system.current_active_requests = mt.system.current_active_requests - 1
}

func (metrics_tracker* mt) record_request_started() {
    mt.system.current_active_requests = mt.system.current_active_requests + 1
}

func (metrics_tracker* mt) record_pending_request(int32 count) {
    mt.system.current_pending_requests = count
}

func (metrics_tracker* mt) record_batch_executed(int32 batch_size) {
    mt.batch_sizes = append(mt.batch_sizes, batch_size)
}

func (metrics_tracker* mt) record_cache_state(int32 used_blocks, int32 free_blocks, int32 allocated_reqs) {
    mt.cache.used_blocks = used_blocks
    mt.cache.free_blocks = free_blocks
    mt.cache.allocated_requests = allocated_reqs
    if mt.cache.total_blocks > 0 {
        mt.cache.cache_utilization_percent = float32(used_blocks * 100) / float32(mt.cache.total_blocks)
    }
}

func (metrics_tracker* mt) record_gpu_memory(float32 used_gb) {
    mt.gpu.gpu_memory_used_gb = used_gb
    if mt.gpu.gpu_memory_total_gb > 0.0 {
        mt.gpu.gpu_utilization_percent = (used_gb * 100.0) / mt.gpu.gpu_memory_total_gb
    }
}

func (metrics_tracker* mt) record_gpu_error() {
    mt.gpu.gpu_errors = mt.gpu.gpu_errors + 1
}

func (metrics_tracker* mt) compute_latency_stats() {
    if len(mt.latency_samples) == 0 {
        return
    }
    total := 0
    min_val := mt.latency_samples[0]
    max_val := mt.latency_samples[0]
    for i := 0; i < len(mt.latency_samples); i = i + 1 {
        sample := mt.latency_samples[i]
        total = total + sample
        if sample < min_val {
            min_val = sample
        }
        if sample > max_val {
            max_val = sample
        }
    }
    mt.latency.min_latency_ms = float32(min_val)
    mt.latency.max_latency_ms = float32(max_val)
    mt.latency.avg_latency_ms = float32(total) / float32(len(mt.latency_samples))
    sorted := quick_sort_int32(mt.latency_samples)
    mid := len(sorted) / 2
    if mid > 0 && mid < len(sorted) {
        mt.latency.p50_latency_ms = float32(sorted[mid])
    }
    p95_idx := (len(sorted) * 95) / 100
    if p95_idx < len(sorted) {
        mt.latency.p95_latency_ms = float32(sorted[p95_idx])
    }
    p99_idx := (len(sorted) * 99) / 100
    if p99_idx < len(sorted) {
        mt.latency.p99_latency_ms = float32(sorted[p99_idx])
    }
}

func (metrics_tracker* mt) compute_throughput_stats() {
    elapsed_ns := current_time_ns() - mt.start_time
    elapsed_sec := float32(elapsed_ns) / 1e9
    if elapsed_sec > 0.0 {
        mt.throughput.requests_per_sec = int32(float32(mt.system.total_requests_completed) / elapsed_sec)
        total_tokens := 0
        for i := 0; i < len(mt.token_counts); i = i + 1 {
            total_tokens = total_tokens + mt.token_counts[i]
        }
        mt.throughput.tokens_per_sec = int32(float32(total_tokens) / elapsed_sec)
        mt.throughput.batches_per_sec = int32(float32(len(mt.batch_sizes)) / elapsed_sec)
        if len(mt.batch_sizes) > 0 {
            total_batch_size := 0
            for i := 0; i < len(mt.batch_sizes); i = i + 1 {
                total_batch_size = total_batch_size + mt.batch_sizes[i]
            }
            mt.throughput.avg_batch_size = float32(total_batch_size) / float32(len(mt.batch_sizes))
        }
    }
}

func (metrics_tracker* mt) update() {
    mt.compute_latency_stats()
    mt.compute_throughput_stats()
    elapsed_ns := current_time_ns() - mt.start_time
    mt.system.system_uptime_sec = float32(elapsed_ns) / 1e9
    mt.last_update_time = current_time_ns()
}

func (metrics_tracker* mt) get_summary_string() string {
    mt.update()
    result := "=== Metrics Summary ===\n"
    result = result + "Requests: " + int32_to_string(mt.system.total_requests_completed) + " completed\n"
    result = result + "Avg Latency: " + float32_to_string(mt.latency.avg_latency_ms) + " ms\n"
    result = result + "Throughput: " + int32_to_string(mt.throughput.tokens_per_sec) + " tokens/sec\n"
    result = result + "Cache Util: " + float32_to_string(mt.cache.cache_utilization_percent) + "%\n"
    result = result + "GPU Mem: " + float32_to_string(mt.gpu.gpu_memory_used_gb) + " / " + float32_to_string(mt.gpu.gpu_memory_total_gb) + " GB\n"
    return result
}

func (metrics_tracker* mt) reset() {
    mt.system = system_metrics{
        total_requests_received: 0,
        total_requests_completed: 0,
        total_requests_failed: 0,
        total_requests_cancelled: 0,
        current_active_requests: 0,
        current_pending_requests: 0,
        system_uptime_sec: 0.0,
    }
    mt.latency_samples = make(int32[])
    mt.batch_sizes = make(int32[])
    mt.token_counts = make(int32[])
    mt.start_time = current_time_ns()
}

func quick_sort_int32(int32[] arr) []int32 {
    if len(arr) <= 1 {
        return arr
    }
    sorted := make(int32[])
    for i := 0; i < len(arr); i = i + 1 {
        sorted = append(sorted, arr[i])
    }
    return sorted
}

func int32_to_string(int32 val) string {
    if val == 0 {
        return "0"
    }
    return "value"
}

func float32_to_string(float32 val) string {
    return "value"
}
