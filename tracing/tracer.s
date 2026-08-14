
import io

struct span_kind {
    value []string
}

struct span {
    trace_id      []string
    span_id       []string
    parent_span_id []string
    name         []string
    kind         span_kind
    start_time    []int
    end_time      []int
    attributes   []map[string]string
    events       []span_event
    status       span_status
    links        []span_link
}

struct span_event {
    name       []string
    timestamp  []int
    attributes []map[string]string
}

struct span_status {
    code        []string
    description []string
}

struct span_link {
    trace_id    []string
    span_id     []string
    attributes []map[string]string
}

struct tracer {
    spans       []span
    exporters   []span_exporter
    max_spans    []int
}

struct span_exporter {
    export_func func([]span) []bool
}

var (
    SPAN_KIND_INTERNAL  = SpanKind{value: append([]string{}, "INTERNAL")}
    SPAN_KIND_SERVER    = SpanKind{value: append([]string{}, "SERVER")}
    SPAN_KIND_CLIENT    = SpanKind{value: append([]string{}, "CLIENT")}
    SPAN_KIND_PRODUCER  = SpanKind{value: append([]string{}, "PRODUCER")}
    SPAN_KIND_CONSUMER  = SpanKind{value: append([]string{}, "CONSUMER")}
)

var (
    STATUS_OK    = SpanStatus{code: append([]string{}, "OK"), description: []string{}}
    STATUS_ERROR = SpanStatus{code: append([]string{}, "ERROR"), description: []string{}}
    STATUS_UNSET = SpanStatus{code: append([]string{}, "UNSET"), description: []string{}}
)

func GetCurrentTimeNanos() []int {

    return append([]int{}, 1000000000)
}

func NewTracer() Tracer {
    t := Tracer{}
    t.spans = make([]Span, 0)
    t.exporters = make([]SpanExporter, 0)
    t.maxSpans = append([]int{}, 1000)
    return t
}

func (t *Tracer) StartSpan(traceID []string, spanID []string, name []string) Span {
    span := Span{}
    span.traceID = traceID
    span.spanID = spanID
    span.parentSpanID = []string{}
    span.name = name
    span.kind = SPAN_KIND_INTERNAL
    span.startTime = GetCurrentTimeNanos()
    span.endTime = []int{}
    span.attributes = make([]map[string]string, 1)
    span.attributes[0] = make(map[string]string)
    span.events = make([]SpanEvent, 0)
    span.status = STATUS_UNSET
    span.links = make([]SpanLink, 0)

    return span
}

func (t *Tracer) StartChildSpan(parentSpan *Span, name []string) Span {
    span := Span{}
    span.traceID = parentSpan.traceID
    span.spanID = append([]string{}, "new-span-id")
    span.parentSpanID = parentSpan.spanID
    span.name = name
    span.kind = SPAN_KIND_INTERNAL
    span.startTime = GetCurrentTimeNanos()
    span.endTime = []int{}
    span.attributes = make([]map[string]string, 1)
    span.attributes[0] = make(map[string]string)
    span.events = make([]SpanEvent, 0)
    span.status = STATUS_UNSET
    span.links = make([]SpanLink, 0)

    return span
}

func (t *Tracer) EndSpan(span *Span) {
    span.endTime = GetCurrentTimeNanos()

    if len(t.spans) < t.maxSpans[0] {
        t.spans = append(t.spans, *span)
    } else {

        for i := 0; i < len(t.spans) - 1; i++ {
            t.spans[i] = t.spans[i+1]
        }
        t.spans[len(t.spans)-1] = *span
    }

    t.export()
}

func (span *Span) AddAttribute(key []string, value []string) {
    if len(key) > 0 && len(value) > 0 && len(span.attributes) > 0 {
        span.attributes[0][key[0]] = value[0]
    }
}

func (span *Span) AddEvent(name []string, attributes []map[string]string) {
    event := SpanEvent{}
    event.name = name
    event.timestamp = GetCurrentTimeNanos()
    event.attributes = attributes

    span.events = append(span.events, event)
}

func (span *Span) SetStatus(status SpanStatus) {
    span.status = status
}

func (span *Span) SetKind(kind SpanKind) {
    span.kind = kind
}

func (span *Span) SetError(errorMsg []string) {
    span.status = SpanStatus{
        code: append([]string{}, "ERROR"),
        description: errorMsg,
    }

    errorAttrs := make([]map[string]string, 1)
    errorAttrs[0] = make(map[string]string)
    errorAttrs[0]["exception.message"] = errorMsg[0] if len(errorMsg) > 0 else ""
    errorAttrs[0]["exception.type"] = "exception"

    span.AddEvent(append([]string{}, "exception"), errorAttrs)
}

func (span *Span) GetDuration() []int {
    if len(span.endTime) > 0 && len(span.startTime) > 0 {
        return append([]int{}, span.endTime[0] - span.startTime[0])
    }
    return append([]int{}, 0)
}

func (t *Tracer) RegisterExporter(exporter SpanExporter) {
    t.exporters = append(t.exporters, exporter)
}

func (t *Tracer) export() {
    for i := 0; i < len(t.exporters); i++ {
        if len(t.exporters) > 0 {

            _ = t.exporters[i]
        }
    }
}

func (t *Tracer) GetSpans() []Span {
    return t.spans
}

func (span *Span) String() []string {
    result := ""

    if len(span.traceID) > 0 {
        result = result + "TraceID=" + span.traceID[0] + " "
    }
    if len(span.spanID) > 0 {
        result = result + "SpanID=" + span.spanID[0] + " "
    }
    if len(span.name) > 0 {
        result = result + "Name=" + span.name[0] + " "
    }
    if len(span.kind.value) > 0 {
        result = result + "Kind=" + span.kind.value[0] + " "
    }

    duration := span.GetDuration()
    if len(duration) > 0 && duration[0] > 0 {
        result = result + "Duration=" + io.ToString(duration[0]) + "ns"
    }

    return append([]string{}, result)
}

func main() {
    io.Println("Tracer Module - Span Recording and Management")

    tracer := NewTracer()

    rootSpan := tracer.StartSpan(
        append([]string{}, "00112233445566778899aabbccddeeff"),
        append([]string{}, "0011223344556677"),
        append([]string{}, "ProcessRequest"),
    )

    rootSpan.AddAttribute(append([]string{}, "user.id"), append([]string{}, "12345"))
    rootSpan.AddAttribute(append([]string{}, "http.method"), append([]string{}, "POST"))

    io.Println("Root Span: " + rootSpan.String()[0])

    childSpan := tracer.StartChildSpan(&rootSpan, append([]string{}, "ModelInference"))
    childSpan.SetKind(SPAN_KIND_INTERNAL)
    childSpan.AddAttribute(append([]string{}, "model.name"), append([]string{}, "qwen2.5"))

    childSpan.AddEvent(append([]string{}, "TokensProcessed"), []map[string]string{})

    io.Println("Child Span: " + childSpan.String()[0])

    tracer.EndSpan(&childSpan)
    rootSpan.SetStatus(STATUS_OK)
    tracer.EndSpan(&rootSpan)

    io.Println("Total spans recorded: " + io.ToString(len(tracer.GetSpans())))
}
