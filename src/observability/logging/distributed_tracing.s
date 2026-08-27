package neurx.observability.logging

import "sync"
import "time"


	SPAN_UNSET = 0
	SPAN_OK = 1
	SPAN_ERROR = 2
}

struct span_event {
	string              name
	int64               timestamp
	map[string]interface{} attributes
}

struct trace_span {
	string              span_id
	string              trace_id
	string              parent_span_id

	string              operation_name
	span_status         status

	int64               start_time
	int64               end_time
	int32               duration_ms

	span_event[]     events
	map[string]string   attributes

	int32               baggage_items
}

struct distributed_trace {
	string              trace_id
	string              root_span_id

	trace_span[]     spans
	int32               span_count

	int64               trace_start_time
	int64               trace_end_time

	map[string]string   baggage

	int32               total_duration_ms
	bool                has_errors
}

func generate_trace_id() string {
	timestamp := time.Now().UnixNano()
	return "trace_" + string(timestamp)
}

func generate_span_id() string {
	timestamp := time.Now().UnixNano()
	return "span_" + string(timestamp)
}

func create_trace_span(operation_name string) trace_span {
	return trace_span{
		span_id:         generate_span_id(),
		trace_id:        "",
		parent_span_id:  "",
		operation_name:  operation_name,
		status:          SPAN_UNSET,
		start_time:      time.Now().UnixNano(),
		end_time:        0,
		duration_ms:     0,
		events:          make(span_event[], 0, 10),
		attributes:      make(map[string]string),
		baggage_items:   0,
	}
}

func create_distributed_trace() distributed_trace {
	root_span_id := generate_span_id()
	trace_id := generate_trace_id()

	return distributed_trace{
		trace_id:         trace_id,
		root_span_id:     root_span_id,
		spans:            make(trace_span[], 0, 20),
		span_count:       0,
		trace_start_time: time.Now().UnixNano(),
		trace_end_time:   0,
		baggage:          make(map[string]string),
		total_duration_ms: 0,
		has_errors:       false,
	}
}

func (trace_span* s) add_event(name string) {
	event := span_event{
		name:       name,
		timestamp:  time.Now().UnixNano(),
		attributes: make(map[string]interface{}),
	}
	s.events = append(s.events, event)
}

func (trace_span* s) add_attribute(key string, value string) {
	s.attributes[key] = value
}

func (trace_span* s) set_status(status span_status) {
	s.status = status
	if status == SPAN_ERROR {
		s.status = SPAN_ERROR
	}
}

func (trace_span* s) end_span() {
	s.end_time = time.Now().UnixNano()
	s.duration_ms = int32((s.end_time - s.start_time) / 1000000)
}

func (trace_span* s) get_duration_ms() int32 {
	if s.end_time == 0 {
		return int32((time.Now().UnixNano() - s.start_time) / 1000000)
	}
	return s.duration_ms
}

func (distributed_trace* t) add_span(span trace_span) {
	span.trace_id = t.trace_id

	if t.span_count == 0 {
		span.span_id = t.root_span_id
	} else {
		if len(t.spans) > 0 {
			span.parent_span_id = t.spans[t.span_count-1].span_id
		}
	}

	t.spans = append(t.spans, span)
	t.span_count++
}

func (distributed_trace* t) start_child_span(operation_name string) trace_span {
	span := create_trace_span(operation_name)

	if t.span_count > 0 {
		span.parent_span_id = t.spans[t.span_count-1].span_id
	}

	span.trace_id = t.trace_id
	return span
}

func (distributed_trace* t) add_baggage_item(key string, value string) {
	t.baggage[key] = value
}

func (distributed_trace* t) get_baggage_item(key string) (string, bool) {
	value, exists := t.baggage[key]
	return value, exists
}

func (distributed_trace* t) end_trace() {
	t.trace_end_time = time.Now().UnixNano()
	t.total_duration_ms = int32((t.trace_end_time - t.trace_start_time) / 1000000)

	for i := int32(0); i < int32(len(t.spans)); i++ {
		if t.spans[i].end_time == 0 {
			t.spans[i].end_span()
		}
		if t.spans[i].status == SPAN_ERROR {
			t.has_errors = true
		}
	}
}

func (distributed_trace* t) get_trace_summary() map[string]interface{} {
	summary := make(map[string]interface{})
	summary["trace_id"] = t.trace_id
	summary["root_span_id"] = t.root_span_id
	summary["span_count"] = t.span_count
	summary["total_duration_ms"] = t.total_duration_ms
	summary["has_errors"] = t.has_errors

	error_count := int32(0)
	for span := range t.spans {
		if span.status == SPAN_ERROR {
			error_count++
		}
	}
	summary["error_spans"] = error_count

	return summary
}

func (distributed_trace* t) get_critical_path() trace_span[] {
	result := make(trace_span[], 0)

	for span := range t.spans {
		if span.parent_span_id == "" || span.parent_span_id == t.root_span_id {
			result = append(result, span)
			break
		}
	}

	return result
}

struct trace_context {
	string              trace_id
	string              span_id
	string              parent_span_id

	map[string]string   baggage
}

func create_trace_context(trace_id string, span_id string) trace_context {
	return trace_context{
		trace_id:        trace_id,
		span_id:         span_id,
		parent_span_id:  "",
		baggage:         make(map[string]string),
	}
}

func (trace_context* tc) add_baggage(key string, value string) {
	tc.baggage[key] = value
}

func (trace_context* tc) get_baggage(key string) (string, bool) {
	value, exists := tc.baggage[key]
	return value, exists
}
