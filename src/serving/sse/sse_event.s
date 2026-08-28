package sse
import "time"
	FIELD_EVENT = 0
	FIELD_DATA = 1
	FIELD_ID = 2
	FIELD_RETRY = 3
	FIELD_COMMENT = 4
}
	COMPRESSION_NONE = 0
	COMPRESSION_GZIP = 1
	COMPRESSION_DEFLATE = 2
}
struct sse_event {
	string                  event_id
	string                  event_type
	string                  event_data
	int64                   timestamp
	int32                   retry_ms
	map[string]string       headers
	int32                   data_size_bytes
	bool                    compressed
	compression_type        compression_method
	string                  source_component
	string                  trace_id
	string                  span_id
}
struct sse_field {
	event_field_type        field_type
	string                  field_name
	string                  field_value
}
struct sse_frame {
	sse_field[]          fields
	int32                   field_count
	string                  raw_data
	int32                   raw_size_bytes
	int64                   created_at
	int32                   checksum
}
struct sse_stream {
	sse_event[]          events
	int32                   event_count
	int32                   max_events_buffered
	string                  stream_id
	string                  client_id
	int64                   stream_start_time
	int64                   last_event_time
	int32                   total_bytes_sent
	int32                   total_events_sent
	bool                    is_active
	bool                    compression_enabled
	compression_type        active_compression
}
func create_sse_event(event_type string, data string) sse_event {
	return sse_event{
		event_id:              "",
		event_type:            event_type,
		event_data:            data,
		timestamp:             time.Now().UnixNano(),
		retry_ms:              0,
		headers:               make(map[string]string),
		data_size_bytes:       int32(len(data)),
		compressed:            false,
		compression_method:    COMPRESSION_NONE,
		source_component:      "",
		trace_id:              "",
		span_id:               "",
	}
}
func create_sse_field(ftype event_field_type, name string, value string) sse_field {
	return sse_field{
		field_type:  ftype,
		field_name:  name,
		field_value: value,
	}
}
func create_sse_frame() sse_frame {
	return sse_frame{
		fields:       make(sse_field[], 0, 10),
		field_count:  0,
		raw_data:     "",
		raw_size_bytes: 0,
		created_at:   time.Now().UnixNano(),
		checksum:     0,
	}
}
func create_sse_stream(stream_id string, client_id string) sse_stream {
	return sse_stream{
		events:                  make(sse_event[], 0, 1000),
		event_count:             0,
		max_events_buffered:     1000,
		stream_id:               stream_id,
		client_id:               client_id,
		stream_start_time:       time.Now().UnixNano(),
		last_event_time:         time.Now().UnixNano(),
		total_bytes_sent:        0,
		total_events_sent:       0,
		is_active:               true,
		compression_enabled:     false,
		active_compression:      COMPRESSION_NONE,
	}
}
func (sse_event* e) set_event_id(id string) {
	e.event_id = id
}
func (sse_event* e) set_event_type(etype string) {
	e.event_type = etype
}
func (sse_event* e) set_event_data(data string) {
	e.event_data = data
	e.data_size_bytes = int32(len(data))
}
func (sse_event* e) set_retry(ms int32) {
	e.retry_ms = ms
}
func (sse_event* e) add_header(key string, value string) {
	e.headers[key] = value
}
func (sse_event* e) get_header(key string) (string, bool) {
	value, exists := e.headers[key]
	return value, exists
}
func (sse_event* e) set_compression(ctype compression_type, compressed bool) {
	e.compression_method = ctype
	e.compressed = compressed
}
func (sse_event* e) set_trace_context(trace_id string, span_id string) {
	e.trace_id = trace_id
	e.span_id = span_id
}
func (sse_frame* f) add_field(field sse_field) {
	f.fields = append(f.fields, field)
	f.field_count++
}
func (sse_frame* f) add_event_field(name string, value string) {
	field := create_sse_field(FIELD_EVENT, "event", name)
	f.add_field(field)
}
func (sse_frame* f) add_data_field(data string) {
	field := create_sse_field(FIELD_DATA, "data", data)
	f.add_field(field)
}
func (sse_frame* f) add_id_field(id string) {
	field := create_sse_field(FIELD_ID, "id", id)
	f.add_field(field)
}
func (sse_frame* f) add_retry_field(ms int32) {
	field := create_sse_field(FIELD_RETRY, "retry", string(ms))
	f.add_field(field)
}
func (sse_frame* f) add_comment_field(comment string) {
	field := create_sse_field(FIELD_COMMENT, "", comment)
	f.add_field(field)
}
func (sse_frame* f) get_field_count() int32 {
	return f.field_count
}
func (sse_frame* f) set_raw_data(data string) {
	f.raw_data = data
	f.raw_size_bytes = int32(len(data))
}
func (sse_stream* s) add_event(event sse_event) bool {
	if s.event_count >= s.max_events_buffered {
		return false
	}
	s.events = append(s.events, event)
	s.event_count++
	s.last_event_time = time.Now().UnixNano()
	s.total_events_sent++
	s.total_bytes_sent = s.total_bytes_sent + event.data_size_bytes
	return true
}
func (sse_stream* s) get_events() sse_event[] {
	return s.events
}
func (sse_stream* s) clear_events() {
	s.events = make(sse_event[], 0, 1000)
	s.event_count = 0
}
func (sse_stream* s) enable_compression(ctype compression_type) {
	s.compression_enabled = true
	s.active_compression = ctype
}
func (sse_stream* s) disable_compression() {
	s.compression_enabled = false
	s.active_compression = COMPRESSION_NONE
}
func (sse_stream* s) set_active(active bool) {
	s.is_active = active
}
func (sse_stream* s) get_stream_stats() map[string]interface{} {
	stats := make(map[string]interface{})
	stats["stream_id"] = s.stream_id
	stats["client_id"] = s.client_id
	stats["event_count"] = s.event_count
	stats["total_events_sent"] = s.total_events_sent
	stats["total_bytes_sent"] = s.total_bytes_sent
	stats["is_active"] = s.is_active
	stats["compression_enabled"] = s.compression_enabled
	elapsed := (time.Now().UnixNano() - s.stream_start_time) / 1000000
	stats["stream_duration_ms"] = elapsed
	return stats
}
func (sse_stream* s) get_stream_uptime_ms() int64 {
	return (time.Now().UnixNano() - s.stream_start_time) / 1000000
}
func (sse_stream* s) close_stream() {
	s.is_active = false
	s.events = make(sse_event[], 0, 1000)
	s.event_count = 0
}
