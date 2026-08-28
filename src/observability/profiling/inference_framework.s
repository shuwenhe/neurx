package neurx.observability.profiling.inference_framework
import "core"
import "tensor"
struct profile_event_type {
    FORWARD_START    int32
    FORWARD_END      int32
    BACKWARD_START   int32
    BACKWARD_END     int32
    PREFILL_START    int32
    PREFILL_END      int32
    DECODE_START     int32
    DECODE_END       int32
    KV_ALLOC_START   int32
    KV_ALLOC_END     int32
    COMMUNICATION    int32
    MEMORY_ALLOC     int32
    KERNEL_LAUNCH    int32
    CUSTOM           int32
}
func ProfileEventTypeValues() profile_event_type {
    return profile_event_type{
        FORWARD_START:   1,
        FORWARD_END:     2,
        BACKWARD_START:  3,
        BACKWARD_END:    4,
        PREFILL_START:   5,
        PREFILL_END:     6,
        DECODE_START:    7,
        DECODE_END:      8,
        KV_ALLOC_START:  9,
        KV_ALLOC_END:    10,
        COMMUNICATION:   11,
        MEMORY_ALLOC:    12,
        KERNEL_LAUNCH:   13,
        CUSTOM:          14,
    }
}
struct profile_event {
    event_id        string
    event_type      int32
    timestamp_ns    int64
    duration_ns     int64
    worker_id       string
    gpu_id          int32
    stream_id       int32
    name            string
    metadata        map[string]string
}
struct phase_timing {
    phase_name      string
    start_time_ns   int64
    end_time_ns     int64
    duration_ns     int64
    count           int32
}
struct profiler {
    enabled         bool
    events          []profile_event
    phase_timings   map[string]phase_timing
    request_traces  map[string][]profile_event
    max_events      int32
    current_size    int32
}
struct request_profiler {
    request_id      string
    start_time_ns   int64
    end_time_ns     int64
    phases          []phase_timing
    memory_peak_mb  int32
}
struct profiler_report {
    total_time_ns       int64
    forward_time_ns     int64
    decode_time_ns      int64
    prefill_time_ns     int64
    communication_ns    int64
    memory_overhead_mb  int32
    avg_latency_ms      float32
    p95_latency_ms      float32
    p99_latency_ms      float32
    throughput          float32
    events_count        int32
}
func NewProfiler() *profiler {
    return *profiler{
        enabled:        true,
        events:         make([]profile_event, 0),
        phase_timings:  make(map[string]phase_timing),
        request_traces: make(map[string][]profile_event),
        max_events:     1000000,
        current_size:   0,
    }
}
func (profiler* p) RecordEvent(
    event_type int32,
    name string,
    worker_id string,
    gpu_id int32,
) {
    if !p.enabled || p.current_size >= p.max_events {
        return
    }
    event := profile_event{
        event_id:     "evt_" + core.ToString(p.current_size),
        event_type:   event_type,
        timestamp_ns: core.Now().UnixNano(),
        worker_id:    worker_id,
        gpu_id:       gpu_id,
        name:         name,
        metadata:     make(map[string]string),
    }
    p.events = append(p.events, event)
    p.current_size++
}
func (profiler* p) StartPhase(phase_name string) {
    if !p.enabled {
        return
    }
    p.phase_timings[phase_name] = phase_timing{
        phase_name:    phase_name,
        start_time_ns: core.Now().UnixNano(),
        count:         0,
    }
}
func (profiler* p) EndPhase(phase_name string) {
    if !p.enabled {
        return
    }
    timing, exists := p.phase_timings[phase_name]
    if !exists {
        return
    }
    now := core.Now().UnixNano()
    timing.end_time_ns = now
    timing.duration_ns = now - timing.start_time_ns
    timing.count++
    p.phase_timings[phase_name] = timing
}
func (profiler* p) StartRequestProfile(request_id string) {
    if !p.enabled {
        return
    }
    p.request_traces[request_id] = make([]profile_event, 0)
}
func (profiler* p) RecordRequestEvent(
    request_id string,
    event_type int32,
    name string,
) {
    if !p.enabled {
        return
    }
    trace, exists := p.request_traces[request_id]
    if !exists {
        trace = make([]profile_event, 0)
    }
    event := profile_event{
        event_id:     request_id + "_" + name,
        event_type:   event_type,
        timestamp_ns: core.Now().UnixNano(),
        name:         name,
    }
    trace = append(trace, event)
    p.request_traces[request_id] = trace
}
func (profiler* p) GetPhaseMetrics(phase_name string) phase_timing {
    timing, exists := p.phase_timings[phase_name]
    if !exists {
        return phase_timing{
            phase_name: phase_name,
        }
    }
    return timing
}
func (profiler* p) GenerateReport() profiler_report {
    report := profiler_report{}
    for _, timing := range p.phase_timings {
        report.total_time_ns = report.total_time_ns + timing.duration_ns
        if timing.phase_name == "forward" {
            report.forward_time_ns = timing.duration_ns
        } else if timing.phase_name == "decode" {
            report.decode_time_ns = timing.duration_ns
        } else if timing.phase_name == "prefill" {
            report.prefill_time_ns = timing.duration_ns
        } else if timing.phase_name == "communication" {
            report.communication_ns = timing.duration_ns
        }
    }
    if p.current_size > 0 {
        report.avg_latency_ms = float32(report.total_time_ns/int64(p.current_size)) / 1e6
    }
    report.events_count = p.current_size
    return report
}
func (profiler* p) PrintProfile() {
    core.Println("╔═════════════════════════════════════╗")
    core.Println("║  Performance Profiler Report        ║")
    core.Println("╚═════════════════════════════════════╝")
    core.Println("\nPhase Timings (ms):")
    for phase_name, timing := range p.phase_timings {
        duration_ms := float32(timing.duration_ns) / 1e6
        avg_ms := 0.0
        if timing.count > 0 {
            avg_ms = float32(timing.duration_ns/int64(timing.count)) / 1e6
        }
        core.Println("  ", phase_name, ":", duration_ms, "ms (count:", timing.count, " avg:", avg_ms, "ms)")
    }
    report := p.GenerateReport()
    core.Println("\nOverall Metrics:")
    core.Println("  Total time: ", float32(report.total_time_ns)/1e6, "ms")
    core.Println("  Average latency:", report.avg_latency_ms, "ms")
    core.Println("  Forward time:", float32(report.forward_time_ns)/1e6, "ms")
    core.Println("  Decode time:", float32(report.decode_time_ns)/1e6, "ms")
    core.Println("  Prefill time:", float32(report.prefill_time_ns)/1e6, "ms")
    core.Println("  Communication time:", float32(report.communication_ns)/1e6, "ms")
    core.Println("\nEvents Recorded:", report.events_count)
}
struct timeline_analyzer {
    traces          map[string][]profile_event
    critical_paths  map[string][]profile_event
}
func NewTimelineAnalyzer() *timeline_analyzer {
    return *timeline_analyzer{
        traces:         make(map[string][]profile_event),
        critical_paths: make(map[string][]profile_event),
    }
}
func (timeline_analyzer* ta) AddTrace(request_id string, events []profile_event) {
    ta.traces[request_id] = events
}
func (timeline_analyzer* ta) FindCriticalPath(request_id string) []profile_event {
    events, exists := ta.traces[request_id]
    if !exists {
        return []profile_event{}
    }
    sorted := make([]profile_event, len(events))
    copy(sorted, events)
    critical := make([]profile_event, 0)
    for _, event := range sorted {
        if event.event_type == ProfileEventTypeValues().FORWARD_START ||
           event.event_type == ProfileEventTypeValues().FORWARD_END ||
           event.event_type == ProfileEventTypeValues().DECODE_START ||
           event.event_type == ProfileEventTypeValues().DECODE_END {
            critical = append(critical, event)
        }
    }
    ta.critical_paths[request_id] = critical
    return critical
}
func (timeline_analyzer* ta) IdentifyBottleneck(request_id string) string {
    events, exists := ta.traces[request_id]
    if !exists {
        return "no traces"
    }
    max_gap := int64(0)
    bottleneck := "unknown"
    for i := 0; i < len(events)-1; i++ {
        gap := events[i+1].timestamp_ns - events[i].timestamp_ns
        if gap > max_gap {
            max_gap = gap
            bottleneck = events[i].name + " . " + events[i+1].name
        }
    }
    return bottleneck + " (" + core.ToString(max_gap/1e6) + "ms)"
}
func main() {
    profiler := NewProfiler()
    profiler.StartPhase("forward")
    profiler.RecordEvent(ProfileEventTypeValues().FORWARD_START, "forward_pass", "worker_0", 0)
    core.Println("Recording events...")
    profiler.RecordEvent(ProfileEventTypeValues().FORWARD_END, "forward_pass", "worker_0", 0)
    profiler.EndPhase("forward")
    profiler.StartPhase("decode")
    profiler.RecordEvent(ProfileEventTypeValues().DECODE_START, "decode", "worker_0", 0)
    profiler.RecordEvent(ProfileEventTypeValues().DECODE_END, "decode", "worker_0", 0)
    profiler.EndPhase("decode")
    profiler.PrintProfile()
}
