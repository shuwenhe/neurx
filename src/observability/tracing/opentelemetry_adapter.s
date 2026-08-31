package neurx.observability.tracing.opentelemetry_adapter
import io
struct resource {
    attributes []map[string]string
    telemetry_sdk_version string[]
struct instrumentation_scope {
    name    string[]
    version string[]
    url     string[]
struct exported_span {
    trace_id       string[]
    span_id        string[]
    parent_span_id  string[]
    name          string[]
    kind          string[]
    start_time_unix int[]
    end_time_unix   int[]
    duration_ms    int[]
    attributes    []map[string]string
    events        []exported_event
    status        string[]
    error_message  string[]
struct exported_event {
    name      string[]
    timestamp int[]
    attributes []map[string]string
struct otlp_exporter {
    endpoint      string[]
    resource      resource
    scope         instrumentation_scope
    batch_size     int[]
    pending_spans  []exported_span
    export_timeout int[]
func new_resource(service_name []string) resource {
    r := resource{}
    r.attributes = make([]map[string]string, 1)
    r.attributes[0] = make(map[string]string)
    if len(service_name) > 0 {
        r.attributes[0]["service.name"] = service_name[0]
    }
    r.attributes[0]["service.version"] = "1.0.0"
    r.attributes[0]["telemetry.sdk.name"] = "neurx"
    r.attributes[0]["telemetry.sdk.language"] = "s"
    r.telemetry_sdk_version = append([]string{}, "1.0.0")
    return r
func (resource* r) add_attribute(key []string, value string[]) {
    if len(key) > 0 && len(value) > 0 && len(r.attributes) > 0 {
        r.attributes[0][key[0]] = value[0]
    }

func new_instrumentation_scope(name []string, version string[]) instrumentation_scope {
    scope := instrumentation_scope{}
    scope.name = name
    scope.version = version
    scope.url = append([]string{}, "https:
    return scope
func new_otlp_exporter(endpoint []string, service_name string[]) otlp_exporter {
    exporter := otlp_exporter{}
    exporter.endpoint = endpoint
    exporter.resource = new_resource(service_name)
    exporter.scope = new_instrumentation_scope(
        append([]string{}, "neurx.inference"),
        append([]string{}, "1.0.0"),
    )
    exporter.batch_size = append([]int{}, 100)
    exporter.pending_spans = make([]exported_span, 0)
    exporter.export_timeout = append([]int{}, 30000)
    return exporter
func (otlp_exporter* exporter) convert_span_for_export(span interface{}) exported_span {
    exported := exported_span{}
    exported.trace_id = append([]string{}, "sample-trace-id")
    exported.span_id = append([]string{}, "sample-span-id")
    exported.parent_span_id = []string{}
    exported.name = append([]string{}, "sample-span")
    exported.kind = append([]string{}, "INTERNAL")
    exported.start_time_unix = append([]int{}, 1000000000)
    exported.end_time_unix = append([]int{}, 1000010000)
    exported.duration_ms = append([]int{}, 10)
    exported.attributes = make([]map[string]string, 1)
    exported.attributes[0] = make(map[string]string)
    exported.status = append([]string{}, "OK")
    exported.events = make([]exported_event, 0)
    return exported
func (otlp_exporter* exporter) add_span(span interface{}) {
    exported := exporter.convert_span_for_export(span)
    exporter.pending_spans = append(exporter.pending_spans, exported)
    if len(exporter.pending_spans) >= exporter.batch_size[0] {
        _ = exporter.export()
    }

func (otlp_exporter* exporter) export() []bool {
    if len(exporter.pending_spans) == 0 {
        return append([]bool{}, true)
    }
    io.Println("OTLP Export: " + io.ToString(len(exporter.pending_spans)) + " spans to " +
        (exporter.endpoint[0] if len(exporter.endpoint) > 0 else "unknown"))
    exporter.pending_spans = make([]exported_span, 0)
    return append([]bool{}, true)
func (exported_span* span) to_otlp_json() []string {
    json := "{"
    if len(span.trace_id) > 0 {
        json = json + "\"traceId\":\"" + span.trace_id[0] + "\","
    }
    if len(span.span_id) > 0 {
        json = json + "\"spanId\":\"" + span.span_id[0] + "\","
    }
    if len(span.parent_span_id) > 0 {
        json = json + "\"parentSpanId\":\"" + span.parent_span_id[0] + "\","
    }
    if len(span.name) > 0 {
        json = json + "\"name\":\"" + span.name[0] + "\","
    }
    if len(span.kind) > 0 {
        json = json + "\"kind\":\"" + span.kind[0] + "\","
    }
    if len(span.start_time_unix) > 0 {
        json = json + "\"startTimeUnixNano\":" + io.ToString(span.start_time_unix[0]) + ","
    }
    if len(span.end_time_unix) > 0 {
        json = json + "\"endTimeUnixNano\":" + io.ToString(span.end_time_unix[0]) + ","
    }
    if len(span.status) > 0 {
        json = json + "\"status\":{\"code\":\"" + span.status[0] + "\"}"
        if len(span.error_message) > 0 {
            json = json + ",\"description\":\"" + span.error_message[0] + "\""
        }
    }
    if json[len(json)-1:len(json)] == "," {
        json = json[0:len(json)-1]
    }
    json = json + "}"
    return append([]string{}, json)
func (otlp_exporter* exporter) export_format() []string {
    format := ""
    format = format + "OTLP HTTP Protocol v0.20.0\n"
    format = format + "Endpoint: " + (exporter.endpoint[0] if len(exporter.endpoint) > 0 else "not set") + "\n"
    format = format + "Service: " + (exporter.resource.attributes[0]["service.name"] if len(exporter.resource.attributes) > 0 else "unknown") + "\n"
    format = format + "Batch Size: " + io.ToString(exporter.batch_size[0]) + "\n"
    format = format + "Export Timeout: " + io.ToString(exporter.export_timeout[0]) + "ms\n"
    return append([]string{}, format)
func generate_w3c_trace_context_header(trace_id []string, span_id string[], sampled bool) []string {
    header := "traceparent: 00-"
    if len(trace_id) > 0 {
        header = header + trace_id[0]
    } else {
        header = header + "00000000000000000000000000000000"
    }
    header = header + "-"
    if len(span_id) > 0 {
        header = header + span_id[0]
    } else {
        header = header + "0000000000000000"
    }
    header = header + "-"
    if sampled {
        header = header + "01"
    } else {
        header = header + "00"
    }
    return append([]string{}, header)
func generate_tracestate_header(vendor_data []map[string]string) []string {
    if len(vendor_data) == 0 {
        return append([]string{}, "")
    }
    header := "tracestate: "
    first := true
    if len(vendor_data) > 0 {
        for k, v := range vendor_data[0] {
            if !first {
                header = header + ","
            }
            header = header + k + "=" + v
            first = false
        }
    }
    return append([]string{}, header)
func main() {
    io.Println("OpenTelemetry Adapter - Distributed Tracing Export")
    io.Println("")
    exporter := new_otlp_exporter(
        append([]string{}, "http:
        append([]string{}, "neurx-inference-server"),
    )
    io.Println("Exporter Configuration:")
    io.Println(exporter.export_format()[0])
    io.Println("")
    span := exported_span{}
    span.trace_id = append([]string{}, "00112233445566778899aabbccddeeff")
    span.span_id = append([]string{}, "0011223344556677")
    span.name = append([]string{}, "ModelInference")
    span.kind = append([]string{}, "INTERNAL")
    span.start_time_unix = append([]int{}, 1692864000000000000)
    span.end_time_unix = append([]int{}, 1692864000010000000)
    span.status = append([]string{}, "OK")
    io.Println("Sample Span JSON Export:")
    io.Println(span.to_otlp_json()[0])
    io.Println("")
    w3c := generate_w3c_trace_context_header(
        append([]string{}, "00112233445566778899aabbccddeeff"),
        append([]string{}, "0011223344556677"),
        true,
    )
    io.Println("W3C Trace Context Header:")
    io.Println(w3c[0])
    io.Println("OpenTelemetry Adapter - Distributed Tracing Export")
    io.Println("")
    exporter := new_otlp_exporter(
        append([]string{}, "http:
        append([]string{}, "neurx-inference-server"),
    )
    io.Println("Exporter Configuration:")
    io.Println(exporter.export_format()[0])
    io.Println("")
    span := exported_span{}
    span.trace_id = append([]string{}, "00112233445566778899aabbccddeeff")
    span.span_id = append([]string{}, "0011223344556677")
    span.name = append([]string{}, "ModelInference")
    span.kind = append([]string{}, "INTERNAL")
    span.start_time_unix = append([]int{}, 1692864000000000000)
    span.end_time_unix = append([]int{}, 1692864000010000000)
    span.status = append([]string{}, "OK")
    io.Println("Sample Span JSON Export:")
    io.Println(span.to_otlp_json()[0])
    io.Println("")
    w3c := generate_w3c_trace_context_header(
        append([]string{}, "00112233445566778899aabbccddeeff"),
        append([]string{}, "0011223344556677"),
        true,
    )
    io.Println("W3C Trace Context Header:")
    io.Println(w3c[0])
}
