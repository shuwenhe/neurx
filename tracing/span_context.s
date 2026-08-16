import io

struct trace_id {
    value []byte
}

struct span_id {
    value []byte
}

struct trace_flags {
    sampled bool
}

struct span_context {
    trace_id    trace_id
    span_id     span_id
    trace_flags trace_flags
    trace_state []map[string]string
}

struct baggage {
    items []map[string]string
}

func new_trace_id() trace_id {
    id := trace_id{}
    id.value = make([]byte, 16)

    for i := 0; i < 16; i++ {
        id.value[i] = byte((i + 1) * 7 % 256)
    }

    return id
}

func new_span_id() span_id {
    id := span_id{}
    id.value = make([]byte, 8)

    for i := 0; i < 8; i++ {
        id.value[i] = byte((i + 1) * 13 % 256)
    }

    return id
}

func (trace_id* t) to_hex() []string {
    hex := ""
    hex_chars := []string{"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}

    for i := 0; i < len(t.value); i++ {
        b := t.value[i]
        hex = hex + hex_chars[b / 16]
        hex = hex + hex_chars[b % 16]
    }

    return append([]string{}, hex)
}

func (span_id* s) to_hex() []string {
    hex := ""
    hex_chars := []string{"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}

    for i := 0; i < len(s.value); i++ {
        b := s.value[i]
        hex = hex + hex_chars[b / 16]
        hex = hex + hex_chars[b % 16]
    }

    return append([]string{}, hex)
}

func new_span_context() span_context {
    ctx := span_context{}
    ctx.trace_id = new_trace_id()
    ctx.span_id = new_span_id()
    ctx.trace_flags.sampled = true
    ctx.trace_state = make([]map[string]string, 0)

    return ctx
}

func new_child_span_context(span_context* parent_ctx) span_context {
    ctx := span_context{}
    ctx.trace_id = parent_ctx.trace_id
    ctx.span_id = new_span_id()
    ctx.trace_flags = parent_ctx.trace_flags
    ctx.trace_state = parent_ctx.trace_state

    return ctx
}

func (span_context* c) get_trace_id() trace_id {
    return c.trace_id
}

func (span_context* c) get_span_id() span_id {
    return c.span_id
}

func (span_context* c) is_sampled() bool {
    return c.trace_flags.sampled
}

func (span_context* c) set_sampled(sampled bool) {
    c.trace_flags.sampled = sampled
}

func (span_context* c) w3c_format() []string {
    trace_id_hex := c.trace_id.to_hex()
    span_id_hex := c.span_id.to_hex()

    flags := "00"
    if c.trace_flags.sampled {
        flags = "01"
    }

    result := "00-" + trace_id_hex[0] + "-" + span_id_hex[0] + "-" + flags

    return append([]string{}, result)
}

func parse_w3c_format(header []string) span_context {
    ctx := span_context{}

    if len(header) > 0 {

        header_str := header[0]

        ctx.trace_id = new_trace_id()
        ctx.span_id = new_span_id()
        ctx.trace_flags.sampled = true
    }

    return ctx
}

func new_baggage() baggage {
    b := baggage{}
    b.items = make([]map[string]string, 1)
    b.items[0] = make(map[string]string)
    return b
}

func (baggage* b) set(key []string, value []string) {
    if len(key) > 0 && len(value) > 0 && len(b.items) > 0 {
        b.items[0][key[0]] = value[0]
    }
}

func (baggage* b) get(key []string) []string {
    if len(key) > 0 && len(b.items) > 0 {
        if val, ok := b.items[0][key[0]]; ok {
            return append([]string{}, val)
        }
    }
    return []string{}
}

func (baggage* b) merge(baggage* other) {
    if len(other.items) > 0 {
        for k, v := range other.items[0] {
            b.set(append([]string{}, k), append([]string{}, v))
        }
    }
}

func main() {
    io.Println("Span Context Module - OpenTelemetry Tracing Foundation")

    root_ctx := new_span_context()
    io.Println("Root Trace ID: " + root_ctx.get_trace_id().to_hex()[0])
    io.Println("Root Span ID: " + root_ctx.get_span_id().to_hex()[0])
    io.Println("W3C Format: " + root_ctx.w3c_format()[0])
    io.Println("Sampled: " + io.ToString(root_ctx.is_sampled()))

    child_ctx := new_child_span_context(&root_ctx)
    io.Println("Child Trace ID: " + child_ctx.get_trace_id().to_hex()[0])
    io.Println("Child Span ID: " + child_ctx.get_span_id().to_hex()[0])

    bag := new_baggage()
    bag.set(append([]string{}, "user_id"), append([]string{}, "12345"))
    bag.set(append([]string{}, "session"), append([]string{}, "abc-def"))

    user_id := bag.get(append([]string{}, "user_id"))
    if len(user_id) > 0 {
        io.Println("Baggage user_id: " + user_id[0])
    }
}
