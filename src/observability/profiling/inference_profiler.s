package neurx.observability.profiling.inference

import "core"
import "engine"

struct layer_profile {
    layer_id         string
    layer_name       string
    layer_type       string
    time_ms          float32
    memory_bytes     int64
    input_shape      []int32
    output_shape     []int32
    num_parameters   int64
    flops           int64
}

struct request_profile {
    request_id       string
    prefill_time_ms   float32
    decode_time_ms   float32
    total_time_ms   float32
    prefill_tokens   int32
    decode_tokens    int32
    total_tokens     int32
    throughput_tps   float32
}

struct engine_profile {
    timestamp       int64
    total_requests   int64
    total_tokens     int64
    avg_latency_ms    float32
    max_latency_ms    float32
    min_latency_ms    float32
    p50_latency      float32
    p95_latency      float32
    p99_latency      float32
    throughput_tps   float32
    gpu_memory_usage  int64
    cpu_memory_usage  int64
}

struct profiler {
    is_enabled       bool
    profiles        []*engine_profile
    request_profiles map[string]*request_profile
    layer_profiles   map[string]*layer_profile
    start_time       int64
    output_dir       string
}

func new_profiler() *profiler {
    return *profiler{
        is_enabled:       false,
        profiles:        make([]*engine_profile, 0),
        request_profiles: make(map[string]*request_profile),
        layer_profiles:   make(map[string]*layer_profile),
    }
}

func (profiler* p) enable() {
    p.is_enabled = true
    p.start_time = core.CurrentTimeMs()
    core.Println("Profiler enabled")
}

func (profiler* p) disable() {
    p.is_enabled = false
    core.Println("Profiler disabled")
}

func (profiler* p) is_enabled_check() bool {
    return p.is_enabled
}

func (profiler* p) set_output_dir(dir string) {
    p.output_dir = dir
}

func (profiler* p) record_engine_stats(eng *engine.llm_engine) {
    if !p.is_enabled {
        return
    }

    stats := eng.get_stats()

    profile := *engine_profile{
        timestamp:      core.CurrentTimeMs(),
        total_requests:  int64(stats["total_requests"].(int64)),
        total_tokens:    int64(stats["total_tokens"].(int64)),
        avg_latency_ms:   stats["avg_latency_ms"].(float32),
        throughput_tps:  stats["throughput_tps"].(float32),
    }

    p.profiles = append(p.profiles, profile)

    if len(p.profiles) % 10 == 0 {
        core.Printf("Profiler: recorded %d engine profiles\n", len(p.profiles))
    }
}

func (profiler* p) record_request_profile(request_id string, prefill_time_ms, decode_time_ms float32, prefill_tokens, decode_tokens int32) {
    if !p.is_enabled {
        return
    }

    profile := *request_profile{
        request_id:     request_id,
        prefill_time_ms: prefill_time_ms,
        decode_time_ms:  decode_time_ms,
        total_time_ms:   prefill_time_ms + decode_time_ms,
        prefill_tokens: prefill_tokens,
        decode_tokens:  decode_tokens,
        total_tokens:   prefill_tokens + decode_tokens,
    }

    if profile.total_time_ms > 0 {
        profile.throughput_tps = float32(profile.total_tokens) / (profile.total_time_ms / 1000.0)
    }

    p.request_profiles[request_id] = profile
}

func (profiler* p) record_layer_profile(layer_id, layer_name, layer_type string, time_ms float32, memory_bytes int64, input_shape, output_shape []int32, num_params, flops int64) {
    if !p.is_enabled {
        return
    }

    profile := *layer_profile{
        layer_id:       layer_id,
        layer_name:     layer_name,
        layer_type:     layer_type,
        time_ms:        time_ms,
        memory_bytes:   memory_bytes,
        input_shape:    input_shape,
        output_shape:   output_shape,
        num_parameters: num_params,
        flops:         flops,
    }

    p.layer_profiles[layer_id] = profile
}

func (profiler* p) get_engine_stats() map[string]interface{} {
    stats := make(map[string]interface{})

    if len(p.profiles) == 0 {
        return stats
    }

    latencies := make([]float32, 0)
    total_latency := float32(0)
    max_latency := float32(0)
    min_latency := float32(1e9)

    for _, profile := range p.profiles {
        if profile.avg_latency_ms > 0 {
            latencies = append(latencies, profile.avg_latency_ms)
            total_latency = total_latency + profile.avg_latency_ms
            if profile.avg_latency_ms > max_latency {
                max_latency = profile.avg_latency_ms
            }
            if profile.avg_latency_ms < min_latency {
                min_latency = profile.avg_latency_ms
            }
        }
    }

    stats["total_samples"] = int32(len(p.profiles))
    stats["total_requests"] = p.profiles[len(p.profiles)-1].total_requests
    stats["total_tokens"] = p.profiles[len(p.profiles)-1].total_tokens
    stats["avg_latency_ms"] = total_latency / float32(len(latencies))
    stats["max_latency_ms"] = max_latency
    stats["min_latency_ms"] = min_latency
    stats["avg_throughput_tps"] = p.profiles[len(p.profiles)-1].throughput_tps

    return stats
}

func (profiler* p) get_request_stats() map[string]interface{} {
    stats := make(map[string]interface{})

    if len(p.request_profiles) == 0 {
        return stats
    }

    total_time_ms := float32(0)
    total_tokens := int32(0)
    num_requests := int32(len(p.request_profiles))

    for _, profile := range p.request_profiles {
        total_time_ms = total_time_ms + profile.total_time_ms
        total_tokens = total_tokens + profile.total_tokens
    }

    stats["total_requests"] = num_requests
    stats["total_tokens"] = total_tokens
    stats["avg_request_time_ms"] = total_time_ms / float32(num_requests)
    stats["avg_tokens_per_request"] = total_tokens / num_requests
    stats["avg_throughput_tps"] = float32(total_tokens) / (total_time_ms / 1000.0)

    return stats
}

func (profiler* p) get_layer_stats() map[string]interface{} {
    stats := make(map[string]interface{})

    if len(p.layer_profiles) == 0 {
        return stats
    }

    total_time_ms := float32(0)
    total_memory := int64(0)
    total_flops := int64(0)

    layer_stats := make([]map[string]interface{}, 0)

    for _, profile := range p.layer_profiles {
        total_time_ms = total_time_ms + profile.time_ms
        total_memory = total_memory + profile.memory_bytes
        total_flops = total_flops + profile.flops

        layer_stat := make(map[string]interface{})
        layer_stat["layer_id"] = profile.layer_id
        layer_stat["layer_name"] = profile.layer_name
        layer_stat["layer_type"] = profile.layer_type
        layer_stat["time_ms"] = profile.time_ms
        layer_stat["memory_bytes"] = profile.memory_bytes
        layer_stat["num_parameters"] = profile.num_parameters
        layer_stat["flops"] = profile.flops

        if profile.time_ms > 0 {
            layer_stat["gflops"] = float32(profile.flops) / (float32(profile.time_ms) * 1e6)
        }

        layer_stats = append(layer_stats, layer_stat)
    }

    stats["total_layers"] = int32(len(p.layer_profiles))
    stats["total_time_ms"] = total_time_ms
    stats["total_memory_bytes"] = total_memory
    stats["total_flops"] = total_flops
    stats["layers"] = layer_stats

    return stats
}

func (profiler* p) save_profile(filename string) error {
    if len(p.profiles) == 0 {
        return core.Errorf("no profiles to save")
    }

    profile_dir := p.output_dir
    if profile_dir == "" {
        profile_dir = "/tmp/profile"
    }

    core.Printf("Saving profiles to %s/%s\n", profile_dir, filename)

    return nil
}

func (profiler* p) print_summary() {
    core.Println("=" * 50)
    core.Println("Profiler Summary")
    core.Println("=" * 50)

    engine_stats := p.get_engine_stats()
    core.Println("\nEngine Statistics:")
    for key, value := range engine_stats {
        core.Printf("  %s: %v\n", key, value)
    }

    request_stats := p.get_request_stats()
    core.Println("\nRequest Statistics:")
    for key, value := range request_stats {
        core.Printf("  %s: %v\n", key, value)
    }

    layer_stats := p.get_layer_stats()
    core.Println("\nLayer Statistics:")
    for key, value := range layer_stats {
        core.Printf("  %s: %v\n", key, value)
    }

    core.Println("=" * 50)
}

func (profiler* p) reset() {
    p.profiles = make([]*engine_profile, 0)
    p.request_profiles = make(map[string]*request_profile)
    p.layer_profiles = make(map[string]*layer_profile)
    core.Println("Profiler reset")
}
