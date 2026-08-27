package neurx.observability.logging

import "time"


	TRACE = 0
	DEBUG = 1
	INFO = 2
	WARN = 3
	ERROR = 4
	FATAL = 5
}


	REQUEST_RECEIVED = 0
	PROCESSING_START = 1
	PROCESSING_END = 2
	REASONING_STEP = 3
	SAMPLING_EXECUTED = 4
	CACHE_HIT = 5
	CACHE_MISS = 6
	ERROR_OCCURRED = 7
	RESPONSE_SENT = 8
	STREAM_CHUNK = 9
	CHECKPOINT_CREATED = 10
	METRICS_RECORDED = 11
}

struct log_entry {
	string                  entry_id
	log_level               level
	event_type              event_category

	string                  message
	string                  component
	string                  operation

	int64                   timestamp
	int64                   unix_nanos

	string                  trace_id
	string                  span_id
	string                  parent_span_id

	map[string]interface{}  fields
	map[string]string       labels

	int32                   duration_ms
	int32                   error_code
	string                  error_message

	float32                 confidence_score
	int32                   attempt_number
}

struct log_context {
	string                  request_id
	string                  user_id
	string                  session_id

	string                  component
	int32                   depth

	map[string]interface{}  metadata
}

struct log_entry_batch {
	log_entry[]          entries
	int64                   batch_timestamp
	int32                   batch_id

	string                  source_component
	int32                   total_entries
	int32                   total_size_bytes
}

func create_log_entry() log_entry {
	return log_entry{
		entry_id:        "",
		level:           INFO,
		event_category:  REQUEST_RECEIVED,
		message:         "",
		component:       "",
		operation:       "",
		timestamp:       time.Now().Unix(),
		unix_nanos:      time.Now().UnixNano(),
		trace_id:        "",
		span_id:         "",
		parent_span_id:  "",
		fields:          make(map[string]interface{}),
		labels:          make(map[string]string),
		duration_ms:     0,
		error_code:      0,
		error_message:   "",
		confidence_score: 0.0,
		attempt_number:  0,
	}
}

func create_log_context(request_id string, component string) log_context {
	return log_context{
		request_id:   request_id,
		user_id:      "",
		session_id:   "",
		component:    component,
		depth:        0,
		metadata:     make(map[string]interface{}),
	}
}

func create_log_entry_batch() log_entry_batch {
	return log_entry_batch{
		entries:           make(log_entry[], 0, 100),
		batch_timestamp:   time.Now().UnixNano(),
		batch_id:          0,
		source_component:  "",
		total_entries:     0,
		total_size_bytes:  0,
	}
}

func (log_entry* e) set_message(msg string) {
	e.message = msg
}

func (log_entry* e) set_level(level log_level) {
	e.level = level
}

func (log_entry* e) set_component(comp string) {
	e.component = comp
}

func (log_entry* e) set_trace_context(trace_id string, span_id string) {
	e.trace_id = trace_id
	e.span_id = span_id
}

func (log_entry* e) add_field(key string, value interface{}) {
	e.fields[key] = value
}

func (log_entry* e) add_label(key string, value string) {
	e.labels[key] = value
}

func (log_entry* e) set_error(code int32, msg string) {
	e.error_code = code
	e.error_message = msg
	e.level = ERROR
}

func (log_entry* e) set_duration(ms int32) {
	e.duration_ms = ms
}

func (log_entry_batch* b) add_entry(entry log_entry) {
	b.entries = append(b.entries, entry)
	b.total_entries++
}

func (log_entry_batch* b) get_entry_count() int32 {
	return int32(len(b.entries))
}

func (log_entry_batch* b) clear() {
	b.entries = make(log_entry[], 0, 100)
	b.total_entries = 0
	b.total_size_bytes = 0
}
