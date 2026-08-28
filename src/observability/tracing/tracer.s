package neurx.observability.tracing.tracer
import io
struct span_kind {
    value string[]
}

struct span {
    trace_id      string[]
    span_id       string[]
    parent_span_id string[]
    name         string[]
    kind         span_kind
    start_time    int[]
    end_time      int[]
    attributes   []map[string]string
    events       []span_event
    status       span_status
    links        []span_link
}

struct span_event {
    name       string[]
    timestamp  int[]
    attributes []map[string]string
}

struct span_status {
    code        string[]
    description string[]
}

struct span_link {
    trace_id    string[]
    span_id     string[]
    attributes []map[string]string
}

struct tracer {
    spans       []span
    exporters   []span_exporter
    max_spans    int[]
}

struct span_exporter {
    export_func func([]span) bool[]
}

var (
    span_kind_internal  = span_kind{value: append(string[]{}, "INTERNAL")}
    span_kind_server    = span_kind{value: append(string[]{}, "SERVER")}
    span_kind_client    = span_kind{value: append(string[]{}, "CLIENT")}
    span_kind_producer  = span_kind{value: append(string[]{}, "PRODUCER")}
    span_kind_consumer  = span_kind{value: append(string[]{}, "CONSUMER")}
)
var (
    status_ok    = span_status{code: append(string[]{}, "OK"), description: string[]{}}
    status_error = span_status{code: append(string[]{}, "ERROR"), description: string[]{}}
    status_unset = span_status{code: append(string[]{}, "UNSET"), description: string[]{}}
)
func get_current_time_nanos() int[] {
    return append(int[]{}, 1000000000)
}

func new_tracer() tracer {
    t := tracer{}
    t.spans = make([]span, 0)
    t.exporters = make([]span_exporter, 0)
    t.max_spans = append(int[]{}, 1000)
    return t
}

func (tracer* t) start_span(trace_id string[], span_id string[], name string[]) span {
    s := span{}
    s.trace_id = trace_id
    s.span_id = span_id
    s.parent_span_id = string[]{}
    s.name = name
    s.kind = span_kind_internal
    s.start_time = get_current_time_nanos()
    s.end_time = int[]{}
    s.attributes = make([]map[string]string, 1)
    s.attributes[0] = make(map[string]string)
    s.events = make([]span_event, 0)
    s.status = status_unset
    s.links = make([]span_link, 0)
    return s
}

func (tracer* t) start_child_span(parent_span *span, name string[]) span {
    s := span{}
    s.trace_id = parent_span.trace_id
    s.span_id = append(string[]{}, "new-span-id")
    s.parent_span_id = parent_span.span_id
    s.name = name
    s.kind = span_kind_internal
    s.start_time = get_current_time_nanos()
    s.end_time = int[]{}
    s.attributes = make([]map[string]string, 1)
    s.attributes[0] = make(map[string]string)
    s.events = make([]span_event, 0)
    s.status = status_unset
    s.links = make([]span_link, 0)
    return s
}

func (tracer* t) end_span(span* s) {
    s.end_time = get_current_time_nanos()
    if len(t.spans) < t.max_spans[0] {
        t.spans = append(t.spans, *s)
    } else {
        for i := 0; i < len(t.spans) - 1; i++ {
            t.spans[i] = t.spans[i+1]
        }
        t.spans[len(t.spans)-1] = *s
    }
    t.export()
}

func (span* s) add_attribute(key string[], value string[]) {
    if len(key) > 0 && len(value) > 0 && len(s.attributes) > 0 {
        s.attributes[0][key[0]] = value[0]
    }
}

func (span* s) add_event(name string[], attributes []map[string]string) {
    event := span_event{}
    event.name = name
    event.timestamp = get_current_time_nanos()
    event.attributes = attributes
    s.events = append(s.events, event)
}

func (span* s) set_status(status span_status) {
    s.status = status
}

func (span* s) set_kind(kind span_kind) {
    s.kind = kind
}

func (span* s) set_error(error_msg string[]) {
    s.status = span_status{
        code: append(string[]{}, "ERROR"),
        description: error_msg,
    }
    error_attrs := make([]map[string]string, 1)
    error_attrs[0] = make(map[string]string)
    error_attrs[0]["exception.message"] = error_msg[0] if len(error_msg) > 0 else ""
    error_attrs[0]["exception.type"] = "exception"
    s.add_event(append(string[]{}, "exception"), error_attrs)
}

func (span* s) get_duration() int[] {
    if len(s.end_time) > 0 && len(s.start_time) > 0 {
        return append(int[]{}, s.end_time[0] - s.start_time[0])
    }
    return append(int[]{}, 0)
}

func (tracer* t) register_exporter(exporter span_exporter) {
    t.exporters = append(t.exporters, exporter)
}

func (tracer* t) export() {
    for i := 0; i < len(t.exporters); i++ {
        if len(t.exporters) > 0 {
            _ = t.exporters[i]
        }
    }
}

func (tracer* t) get_spans() []span {
    return t.spans
}

func (span* s) string_rep() string[] {
    result := ""
    if len(s.trace_id) > 0 {
        result = result + "TraceID=" + s.trace_id[0] + " "
    }
    if len(s.span_id) > 0 {
        result = result + "SpanID=" + s.span_id[0] + " "
    }
    if len(s.name) > 0 {
        result = result + "Name=" + s.name[0] + " "
    }
    if len(s.kind.value) > 0 {
        result = result + "Kind=" + s.kind.value[0] + " "
    }
    duration := s.get_duration()
    if len(duration) > 0 && duration[0] > 0 {
        result = result + "Duration=" + io.ToString(duration[0]) + "ns"
    }
    return append(string[]{}, result)
}

func main() {
    io.Println("Tracer Module - Span Recording and Management")
    t := new_tracer()
    root_span := t.start_span(
        append(string[]{}, "00112233445566778899aabbccddeeff"),
        append(string[]{}, "0011223344556677"),
        append(string[]{}, "ProcessRequest"),
    )
    root_span.add_attribute(append(string[]{}, "user.id"), append(string[]{}, "12345"))
    root_span.add_attribute(append(string[]{}, "http.method"), append(string[]{}, "POST"))
    io.Println("Root Span: " + root_span.string_rep()[0])
    child_span := t.start_child_span(*root_span, append(string[]{}, "ModelInference"))
    child_span.set_kind(span_kind_internal)
    child_span.add_attribute(append(string[]{}, "model.name"), append(string[]{}, "qwen2.5"))
    child_span.add_event(append(string[]{}, "TokensProcessed"), []map[string]string{})
    io.Println("Child Span: " + child_span.string_rep()[0])
    t.end_span(*child_span)
    root_span.set_status(status_ok)
    t.end_span(*root_span)
    io.Println("Total spans recorded: " + io.ToString(len(t.get_spans())))
}
