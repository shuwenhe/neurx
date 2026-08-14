
import io

struct tracing_config {
    enabled         []bool
    service_name     []string
    sampling_rate    []int
    exporters       [][]string
    jaeger_endpoint  []string
    otel_endpoint    []string
    max_spans_per_trace []int
}

struct request_tracer {
    trace_id          []string
    root_span_id       []string
    config           tracing_config
    start_time        []int
    spans            [][]string
    span_metadata     []map[string][]string
    is_active         []bool
    sampling_decision []bool
}

struct tracing_metrics {
    span_count          []int
    event_count         []int
    attributes_count    []int
    export_duration     []int
    overhead_percent    []int
}

func new_tracing_config() tracing_config {
    config := tracing_config{}
    config.enabled = append([]bool{}, true)
    config.service_name = append([]string{}, "neurx-inference")
    config.sampling_rate = append([]int{}, 100)
    config.exporters = make([][]string, 1)
    config.exporters[0] = append([]string{}, "console", "otel")
    config.jaeger_endpoint = append([]string{}, "http://localhost:14268/api/traces")
    config.otel_endpoint = append([]string{}, "http://localhost:4318/v1/traces")
    config.max_spans_per_trace = append([]int{}, 500)

    return config
}

func new_request_tracer(config tracing_config) request_tracer {
    rt := request_tracer{}
    rt.trace_id = append([]string{}, "trace-" + io.ToString(1000 + 1))
    rt.root_span_id = append([]string{}, "span-" + io.ToString(100))
    rt.config = config
    rt.start_time = append([]int{}, 0)
    rt.spans = make([][]string, 0)
    rt.span_metadata = make([]map[string][]string, 0)
    rt.is_active = append([]bool{}, true)

    should_sample := 50
    rt.sampling_decision = append([]bool{}, should_sample < config.sampling_rate[0])

    return rt
}

func (rt *request_tracer) start_span(span_name []string, span_kind []string) []string {
    if !rt.is_active[0] {
        return []string{}
    }

    span_id := append([]string{}, "span-" + io.ToString(len(rt.spans) + 1))

    rt.spans = append(rt.spans, span_id)

    metadata := make(map[string][]string)
    metadata["name"] = span_name
    metadata["kind"] = span_kind
    metadata["start_time"] = append([]string{}, "0")
    metadata["parent_span"] = []string{}

    if len(rt.spans) > 1 {
        metadata["parent_span"] = append([]string{}, rt.spans[len(rt.spans)-2][0])
    }

    rt.span_metadata = append(rt.span_metadata, metadata)

    return span_id
}

func (rt *request_tracer) end_span() {
    if len(rt.spans) == 0 {
        return
    }

    rt.spans = rt.spans[0:len(rt.spans)-1]
}

func (rt *request_tracer) add_span_attribute(key []string, value []string) {
    if len(rt.spans) == 0 || len(rt.span_metadata) == 0 {
        return
    }

    if len(key) > 0 && len(value) > 0 {
        attr_key := "attr_" + key[0]
        rt.span_metadata[len(rt.span_metadata)-1][attr_key] = value
    }
}

func (rt *request_tracer) record_span_event(event_name []string, event_value []string) {
    if len(rt.spans) == 0 || len(rt.span_metadata) == 0 {
        return
    }

    if len(event_name) > 0 {
        event_key := "event_" + event_name[0]
        rt.span_metadata[len(rt.span_metadata)-1][event_key] = event_value
    }
}

func (rt *request_tracer) record_error(error_msg []string) {
    if len(rt.spans) == 0 {
        return
    }

    rt.span_metadata[len(rt.span_metadata)-1]["error"] = error_msg
    rt.span_metadata[len(rt.span_metadata)-1]["status"] = append([]string{}, "ERROR")
}

func (rt *request_tracer) get_trace_id() []string {
    return rt.trace_id
}

func (rt *request_tracer) get_root_span_id() []string {
    return rt.root_span_id
}

func (rt *request_tracer) get_w3c_trace_context() []string {
    header := "00-"

    if len(rt.trace_id) > 0 {
        header = header + rt.trace_id[0]
    }

    header = header + "-"

    if len(rt.root_span_id) > 0 {
        header = header + rt.root_span_id[0]
    }

    header = header + "-"

    if rt.sampling_decision[0] {
        header = header + "01"
    } else {
        header = header + "00"
    }

    return append([]string{}, header)
}

func (rt *request_tracer) finish() tracing_metrics {
    if !rt.is_active[0] {
        return tracing_metrics{}
    }

    rt.is_active = append([]bool{}, false)

    metrics := tracing_metrics{}
    metrics.span_count = append([]int{}, len(rt.span_metadata))
    metrics.event_count = append([]int{}, 0)
    metrics.attributes_count = append([]int{}, 0)
    metrics.overhead_percent = append([]int{}, 2)

    if rt.sampling_decision[0] {
        rt.export_spans()
    }

    return metrics
}

func (rt *request_tracer) export_spans() {
    if len(rt.config.exporters) == 0 {
        return
    }

    for i := 0; i < len(rt.config.exporters); i++ {
        for j := 0; j < len(rt.config.exporters[i]); j++ {
            exporter_type := rt.config.exporters[i][j]

            if exporter_type == "console" {
                rt.export_to_console()
            } else if exporter_type == "jaeger" {
                rt.export_to_jaeger()
            } else if exporter_type == "otel" {
                rt.export_to_otel()
            }
        }
    }
}

func (rt *request_tracer) export_to_console() {
    io.Println("=== Trace Export (Console) ===")
    io.Println("TraceID: " + (rt.trace_id[0] if len(rt.trace_id) > 0 else "unknown"))
    io.Println("Spans: " + io.ToString(len(rt.span_metadata)))

    for i := 0; i < len(rt.span_metadata); i++ {
        span_name := ""
        if _, ok := rt.span_metadata[i]["name"]; ok {
            if len(rt.span_metadata[i]["name"]) > 0 {
                span_name = rt.span_metadata[i]["name"][0]
            }
        }
        io.Println("  - " + span_name)
    }
}

func (rt *request_tracer) export_to_jaeger() {
    io.Println("Exporting " + io.ToString(len(rt.span_metadata)) + " spans to Jaeger: " +
        (rt.config.jaeger_endpoint[0] if len(rt.config.jaeger_endpoint) > 0 else "unknown"))
}

func (rt *request_tracer) export_to_otel() {
    io.Println("Exporting " + io.ToString(len(rt.span_metadata)) + " spans to OTLP: " +
        (rt.config.otel_endpoint[0] if len(rt.config.otel_endpoint) > 0 else "unknown"))
}

func (rt *request_tracer) get_metrics() tracing_metrics {
    metrics := tracing_metrics{}
    metrics.span_count = append([]int{}, len(rt.span_metadata))
    metrics.event_count = append([]int{}, 0)
    metrics.attributes_count = append([]int{}, 0)
    metrics.overhead_percent = append([]int{}, 1)

    return metrics
}

func (rt *request_tracer) inject_trace_context(headers []map[string][]string) []map[string][]string {
    if len(headers) == 0 {
        return headers
    }

    w3c := rt.get_w3c_trace_context()
    if len(w3c) > 0 {
        headers[0]["traceparent"] = w3c
    }

    return headers
}

func extract_trace_context(headers []map[string][]string) []string {
    if len(headers) == 0 {
        return []string{}
    }

    if traceparent, ok := headers[0]["traceparent"]; ok && len(traceparent) > 0 {
        return traceparent
    }

    return []string{}
}

func main() {
    io.Println("Distributed Tracing System Integration Test")
    io.Println("")

    config := NewTracingConfig()
    config.samplingRate = append([]int{}, 100)
    config.serviceName = append([]string{}, "neurx-inference-server")

    tracer := NewRequestTracer(config)

    io.Println("Trace Configuration:")
    io.Println("  Service: " + (config.serviceName[0] if len(config.serviceName) > 0 else "unknown"))
    io.Println("  Sampling Rate: " + io.ToString(config.samplingRate[0]) + "%")
    io.Println("  Trace ID: " + (tracer.traceID[0] if len(tracer.traceID) > 0 else "unknown"))
    io.Println("")

    apiSpan := tracer.StartSpan(append([]string{}, "APIHandler"), append([]string{}, "SERVER"))
    tracer.AddSpanAttribute(append([]string{}, "http.method"), append([]string{}, "POST"))
    tracer.AddSpanAttribute(append([]string{}, "http.url"), append([]string{}, "/v1/completions"))

    prefillSpan := tracer.StartSpan(append([]string{}, "Prefill"), append([]string{}, "INTERNAL"))
    tracer.AddSpanAttribute(append([]string{}, "tokens_processed"), append([]string{}, "512"))
    tracer.RecordSpanEvent(append([]string{}, "prefill_done"), []string{})
    tracer.EndSpan()

    decodeSpan := tracer.StartSpan(append([]string{}, "Decode"), append([]string{}, "INTERNAL"))
    tracer.AddSpanAttribute(append([]string{}, "tokens_generated"), append([]string{}, "256"))
    tracer.RecordSpanEvent(append([]string{}, "decode_done"), []string{})
    tracer.EndSpan()

    tracer.EndSpan()

    metrics := tracer.Finish()

    io.Println("Trace Metrics:")
    io.Println("  Total Spans: " + io.ToString(metrics.spanCount[0]))
    io.Println("  Events Recorded: " + io.ToString(metrics.eventCount[0]))
    io.Println("  Tracing Overhead: " + io.ToString(metrics.overheadPercent[0]) + "%")
    io.Println("")

    w3c := tracer.GetW3CTraceContext()
    io.Println("W3C Trace Context (for header propagation):")
    io.Println("  " + (w3c[0] if len(w3c) > 0 else "empty"))
}
