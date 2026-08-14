
import io

type Resource struct {
    attributes []map[string]string
    telemetrySDKVersion []string
}

type InstrumentationScope struct {
    name    []string
    version []string
    url     []string
}

type ExportedSpan struct {
    traceID       []string
    spanID        []string
    parentSpanID  []string
    name          []string
    kind          []string
    startTimeUnix []int
    endTimeUnix   []int
    durationMs    []int
    attributes    []map[string]string
    events        []ExportedEvent
    status        []string
    errorMessage  []string
}

type ExportedEvent struct {
    name      []string
    timestamp []int
    attributes []map[string]string
}

type OTLPExporter struct {
    endpoint      []string
    resource      Resource
    scope         InstrumentationScope
    batchSize     []int
    pendingSpans  []ExportedSpan
    exportTimeout []int
}

func NewResource(serviceName []string) Resource {
    r := Resource{}
    r.attributes = make([]map[string]string, 1)
    r.attributes[0] = make(map[string]string)

    if len(serviceName) > 0 {
        r.attributes[0]["service.name"] = serviceName[0]
    }
    r.attributes[0]["service.version"] = "1.0.0"
    r.attributes[0]["telemetry.sdk.name"] = "neurx"
    r.attributes[0]["telemetry.sdk.language"] = "s"

    r.telemetrySDKVersion = append([]string{}, "1.0.0")

    return r
}

func (r *Resource) AddAttribute(key []string, value []string) {
    if len(key) > 0 && len(value) > 0 && len(r.attributes) > 0 {
        r.attributes[0][key[0]] = value[0]
    }
}

func NewInstrumentationScope(name []string, version []string) InstrumentationScope {
    scope := InstrumentationScope{}
    scope.name = name
    scope.version = version
    scope.url = append([]string{}, "https://github.com/neurx-ai/neurx")
    return scope
}

func NewOTLPExporter(endpoint []string, serviceName []string) OTLPExporter {
    exporter := OTLPExporter{}
    exporter.endpoint = endpoint
    exporter.resource = NewResource(serviceName)
    exporter.scope = NewInstrumentationScope(
        append([]string{}, "neurx.inference"),
        append([]string{}, "1.0.0"),
    )
    exporter.batchSize = append([]int{}, 100)
    exporter.pendingSpans = make([]ExportedSpan, 0)
    exporter.exportTimeout = append([]int{}, 30000)

    return exporter
}

func (exporter *OTLPExporter) ConvertSpanForExport(span interface{}) ExportedSpan {
    exported := ExportedSpan{}

    exported.traceID = append([]string{}, "sample-trace-id")
    exported.spanID = append([]string{}, "sample-span-id")
    exported.parentSpanID = []string{}
    exported.name = append([]string{}, "sample-span")
    exported.kind = append([]string{}, "INTERNAL")
    exported.startTimeUnix = append([]int{}, 1000000000)
    exported.endTimeUnix = append([]int{}, 1000010000)
    exported.durationMs = append([]int{}, 10)
    exported.attributes = make([]map[string]string, 1)
    exported.attributes[0] = make(map[string]string)
    exported.status = append([]string{}, "OK")
    exported.events = make([]ExportedEvent, 0)

    return exported
}

func (exporter *OTLPExporter) AddSpan(span interface{}) {
    exported := exporter.ConvertSpanForExport(span)
    exporter.pendingSpans = append(exporter.pendingSpans, exported)

    if len(exporter.pendingSpans) >= exporter.batchSize[0] {
        _ = exporter.Export()
    }
}

func (exporter *OTLPExporter) Export() []bool {
    if len(exporter.pendingSpans) == 0 {
        return append([]bool{}, true)
    }

    io.Println("OTLP Export: " + io.ToString(len(exporter.pendingSpans)) + " spans to " +
        (exporter.endpoint[0] if len(exporter.endpoint) > 0 else "unknown"))

    exporter.pendingSpans = make([]ExportedSpan, 0)

    return append([]bool{}, true)
}

func (span *ExportedSpan) ToOTLPJSON() []string {
    json := "{"

    if len(span.traceID) > 0 {
        json = json + "\"traceId\":\"" + span.traceID[0] + "\","
    }

    if len(span.spanID) > 0 {
        json = json + "\"spanId\":\"" + span.spanID[0] + "\","
    }

    if len(span.parentSpanID) > 0 {
        json = json + "\"parentSpanId\":\"" + span.parentSpanID[0] + "\","
    }

    if len(span.name) > 0 {
        json = json + "\"name\":\"" + span.name[0] + "\","
    }

    if len(span.kind) > 0 {
        json = json + "\"kind\":\"" + span.kind[0] + "\","
    }

    if len(span.startTimeUnix) > 0 {
        json = json + "\"startTimeUnixNano\":" + io.ToString(span.startTimeUnix[0]) + ","
    }

    if len(span.endTimeUnix) > 0 {
        json = json + "\"endTimeUnixNano\":" + io.ToString(span.endTimeUnix[0]) + ","
    }

    if len(span.status) > 0 {
        json = json + "\"status\":{\"code\":\"" + span.status[0] + "\"}"
        if len(span.errorMessage) > 0 {
            json = json + ",\"description\":\"" + span.errorMessage[0] + "\""
        }
    }

    if json[len(json)-1:len(json)] == "," {
        json = json[0:len(json)-1]
    }

    json = json + "}"

    return append([]string{}, json)
}

func (exporter *OTLPExporter) ExportFormat() []string {
    format := ""
    format = format + "OTLP HTTP Protocol v0.20.0\n"
    format = format + "Endpoint: " + (exporter.endpoint[0] if len(exporter.endpoint) > 0 else "not set") + "\n"
    format = format + "Service: " + (exporter.resource.attributes[0]["service.name"] if len(exporter.resource.attributes) > 0 else "unknown") + "\n"
    format = format + "Batch Size: " + io.ToString(exporter.batchSize[0]) + "\n"
    format = format + "Export Timeout: " + io.ToString(exporter.exportTimeout[0]) + "ms\n"

    return append([]string{}, format)
}

func GenerateW3CTraceContextHeader(traceID []string, spanID []string, sampled bool) []string {
    header := "traceparent: 00-"

    if len(traceID) > 0 {
        header = header + traceID[0]
    } else {
        header = header + "00000000000000000000000000000000"
    }

    header = header + "-"

    if len(spanID) > 0 {
        header = header + spanID[0]
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
}

func GenerateTracestateHeader(vendorData []map[string]string) []string {
    if len(vendorData) == 0 {
        return append([]string{}, "")
    }

    header := "tracestate: "
    first := true

    if len(vendorData) > 0 {
        for k, v := range vendorData[0] {
            if !first {
                header = header + ","
            }
            header = header + k + "=" + v
            first = false
        }
    }

    return append([]string{}, header)
}

func main() {
    io.Println("OpenTelemetry Adapter - Distributed Tracing Export")
    io.Println("")

    exporter := NewOTLPExporter(
        append([]string{}, "http://localhost:4318/v1/traces"),
        append([]string{}, "neurx-inference-server"),
    )

    io.Println("Exporter Configuration:")
    io.Println(exporter.ExportFormat()[0])
    io.Println("")

    span := ExportedSpan{}
    span.traceID = append([]string{}, "00112233445566778899aabbccddeeff")
    span.spanID = append([]string{}, "0011223344556677")
    span.name = append([]string{}, "ModelInference")
    span.kind = append([]string{}, "INTERNAL")
    span.startTimeUnix = append([]int{}, 1692864000000000000)
    span.endTimeUnix = append([]int{}, 1692864000010000000)
    span.status = append([]string{}, "OK")

    io.Println("Sample Span JSON Export:")
    io.Println(span.ToOTLPJSON()[0])
    io.Println("")

    w3c := GenerateW3CTraceContextHeader(
        append([]string{}, "00112233445566778899aabbccddeeff"),
        append([]string{}, "0011223344556677"),
        true,
    )
    io.Println("W3C Trace Context Header:")
    io.Println(w3c[0])
}
