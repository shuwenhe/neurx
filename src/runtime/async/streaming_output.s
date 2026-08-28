package async

import "time"
import "encoding/json"

	EVENT_TOKEN_DELTA   = 0
	EVENT_CHUNK         = 1
	EVENT_ERROR         = 2
	EVENT_COMPLETE      = 3
	EVENT_CHECKPOINT    = 4
	EVENT_METADATA      = 5
}

struct stream_event {
	event_type      int32
	event_id        string
	request_id      string
	timestamp       int64
	sequence_number int64

	token_id        int32
	token_text      string
	logits          float32[]
	log_prob        float32

	chunk_text      string
	chunk_size      int32

	metadata_key    string
	metadata_value  string

	error_code      int32
	error_message   string

	is_last         bool
}

struct stream_output {
	request_id              string
	session_id              string

	generated_text          string
	generated_tokens        int32[]
	token_texts             string[]

	total_tokens_generated  int32
	completion_tokens_total int32
	prompt_tokens_total     int32

	finish_reason           string
	finish_status           int32

	output_mode             int32
	chunk_buffer            string

	metadata                map[string]string

	created_timestamp       int64
	completed_timestamp     int64
}

const (
	MODE_STREAMING  = 0
	MODE_ACCUMULATED = 1
	MODE_DELTA      = 2

	BUFFER_SIZE     = 4096
	CHUNK_SIZE      = 64

	FINISH_STOP     = 0
	FINISH_LENGTH   = 1
	FINISH_ERROR    = 2
	FINISH_CANCELLED = 3
)

struct sse_config {
	enable_streaming        bool
	chunk_size              int32
	max_event_size          int32
	heartbeat_interval_ms   int64
	compression_enabled     bool
	include_logits          bool
	include_log_probs       bool
	include_token_ids       bool
	buffer_strategy         int32
}

struct stream_buffer {
	events          stream_event[]
	text_buffer     string
	token_buffer    int32[]

	buffer_size     int32
	max_buffer_size int32
	is_flushed      bool

	mu              sync.Mutex
}

struct stream_state {
	output              stream_output
	buffer              stream_buffer
	config              sse_config

	last_heartbeat      int64
	heartbeat_interval  int64

	is_paused           bool
	is_finished         bool

	sent_events_count   int64
	dropped_events      int64
}

func create_stream_state(request_id string, mode int32) stream_state {
	return stream_state{
		output: stream_output{
			request_id:          request_id,
			output_mode:         mode,
			created_timestamp:   time.Now().UnixNano(),
			generated_tokens:    make(int32[], 0, 1024),
			token_texts:         make(string[], 0, 1024),
			metadata:            make(map[string]string),
		},
		buffer: stream_buffer{
			events:          make(stream_event[], 0, BUFFER_SIZE),
			text_buffer:     "",
			token_buffer:    make(int32[], 0, CHUNK_SIZE),
			max_buffer_size: BUFFER_SIZE,
		},
		config: create_default_sse_config(),
		last_heartbeat: time.Now().UnixNano(),
		heartbeat_interval: 30000000000,
		is_paused: false,
		is_finished: false,
	}
}

func create_default_sse_config() sse_config {
	return sse_config{
		enable_streaming:        true,
		chunk_size:              64,
		max_event_size:          8192,
		heartbeat_interval_ms:   30000,
		compression_enabled:     false,
		include_logits:          false,
		include_log_probs:       false,
		include_token_ids:       true,
		buffer_strategy:         MODE_DELTA,
	}
}

func (s stream_state*) add_token(token_id int32, token_text string) bool {
	s.buffer.mu.Lock()
	defer s.buffer.mu.Unlock()

	if s.is_finished {
		return false
	}

	s.output.generated_tokens = append(s.output.generated_tokens, token_id)
	s.output.token_texts = append(s.output.token_texts, token_text)
	s.output.total_tokens_generated++

	if s.output.output_mode == MODE_ACCUMULATED {
		s.output.generated_text = s.output.generated_text + token_text
	} else if s.output.output_mode == MODE_DELTA {
		s.buffer.text_buffer = s.buffer.text_buffer + token_text
	}

	s.buffer.token_buffer = append(s.buffer.token_buffer, token_id)

	if int32(len(s.buffer.token_buffer)) >= s.config.chunk_size {
		s.flush_chunk()
	}

	return true
}

func (s stream_state*) add_tokens_batch(token_ids int32[], token_texts string[]) bool {
	for i := int32(0); i < int32(len(token_ids)); i++ {
		s.add_token(token_ids[i], token_texts[i])
	}
	return true
}

func (s stream_state*) flush_chunk() bool {
	if int32(len(s.buffer.token_buffer)) == 0 {
		return false
	}

	event := stream_event{
		event_type:      EVENT_CHUNK,
		event_id:        generate_event_id(),
		request_id:      s.output.request_id,
		timestamp:       time.Now().UnixNano(),
		sequence_number: int64(len(s.buffer.events)),
		chunk_text:      s.buffer.text_buffer,
		chunk_size:      int32(len(s.buffer.token_buffer)),
	}

	if s.config.include_token_ids {
		event.token_id = s.buffer.token_buffer[int32(len(s.buffer.token_buffer))-1]
	}

	s.buffer.events = append(s.buffer.events, event)

	if int32(len(s.buffer.events)) >= s.buffer.max_buffer_size {
		s.buffer.is_flushed = true
	}

	s.buffer.text_buffer = ""
	s.buffer.token_buffer = make(int32[], 0, s.config.chunk_size)

	return true
}

func (s stream_state*) create_delta_event() stream_event {
	event := stream_event{
		event_type:      EVENT_TOKEN_DELTA,
		event_id:        generate_event_id(),
		request_id:      s.output.request_id,
		timestamp:       time.Now().UnixNano(),
		sequence_number: s.sent_events_count,
		chunk_text:      s.buffer.text_buffer,
	}

	if int32(len(s.buffer.token_buffer)) > 0 {
		event.token_id = s.buffer.token_buffer[int32(len(s.buffer.token_buffer))-1]
	}

	return event
}

func (s stream_state*) create_completion_event() stream_event {
	event := stream_event{
		event_type:      EVENT_COMPLETE,
		event_id:        generate_event_id(),
		request_id:      s.output.request_id,
		timestamp:       time.Now().UnixNano(),
		sequence_number: s.sent_events_count,
		is_last:         true,
	}
	return event
}

func (s stream_state*) create_error_event(error_code int32, error_msg string) stream_event {
	event := stream_event{
		event_type:      EVENT_ERROR,
		event_id:        generate_event_id(),
		request_id:      s.output.request_id,
		timestamp:       time.Now().UnixNano(),
		sequence_number: s.sent_events_count,
		error_code:      error_code,
		error_message:   error_msg,
		is_last:         true,
	}
	return event
}

func (s stream_state*) create_heartbeat_event() stream_event {
	return stream_event{
		event_type:      EVENT_METADATA,
		event_id:        generate_event_id(),
		request_id:      s.output.request_id,
		timestamp:       time.Now().UnixNano(),
		sequence_number: s.sent_events_count,
		metadata_key:    "heartbeat",
		metadata_value:  "alive",
	}
}

func (s stream_state*) get_pending_events() stream_event[] {
	s.buffer.mu.Lock()
	defer s.buffer.mu.Unlock()

	events := make(stream_event[], 0, len(s.buffer.events))
	for event := range s.buffer.events {
		events = append(events, event)
	}

	s.buffer.events = make(stream_event[], 0, s.buffer.max_buffer_size)
	s.sent_events_count += int64(len(events))

	return events
}

func (s stream_state*) should_send_heartbeat() bool {
	now := time.Now().UnixNano()
	return now - s.last_heartbeat >= s.heartbeat_interval
}

func (s stream_state*) mark_heartbeat_sent() {
	s.last_heartbeat = time.Now().UnixNano()
}

func (s stream_state*) finish(finish_reason string, status int32) {
	s.buffer.mu.Lock()
	defer s.buffer.mu.Unlock()

	s.is_finished = true
	s.output.finish_reason = finish_reason
	s.output.finish_status = status
	s.output.completed_timestamp = time.Now().UnixNano()

	if int32(len(s.buffer.text_buffer)) > 0 {
		s.flush_chunk()
	}
}

func (s stream_state*) get_output() stream_output {
	s.buffer.mu.Lock()
	defer s.buffer.mu.Unlock()
	return s.output
}

func (s stream_state*) add_metadata(key string, value string) {
	s.buffer.mu.Lock()
	defer s.buffer.mu.Unlock()
	s.output.metadata[key] = value
}

func (s stream_state*) set_session_id(session_id string) {
	s.output.session_id = session_id
}

func (s stream_state*) pause() {
	s.is_paused = true
}

func (s stream_state*) resume() {
	s.is_paused = false
}

func (s stream_state*) is_paused() bool {
	return s.is_paused
}

func (s stream_state*) is_complete() bool {
	return s.is_finished
}

func (s stream_state*) get_event_count() int64 {
	s.buffer.mu.Lock()
	defer s.buffer.mu.Unlock()
	return s.sent_events_count
}

func (s stream_state*) format_sse_message(event stream_event) string {
	event_json := json.Marshal(event)
	return format("data: %s\n\n", event_json)
}

func generate_event_id() string {
	return format("event_%d", time.Now().UnixNano())
}

func event_to_json(event stream_event) map[string]interface{} {
	data := make(map[string]interface{})
	data["event_id"] = event.event_id
	data["request_id"] = event.request_id
	data["event_type"] = event.event_type
	data["timestamp"] = event.timestamp
	data["sequence"] = event.sequence_number

	if event.event_type == EVENT_TOKEN_DELTA {
		data["token_id"] = event.token_id
		data["text"] = event.chunk_text
		data["log_prob"] = event.log_prob
	} else if event.event_type == EVENT_CHUNK {
		data["text"] = event.chunk_text
		data["size"] = event.chunk_size
	} else if event.event_type == EVENT_ERROR {
		data["error_code"] = event.error_code
		data["error_message"] = event.error_message
	} else if event.event_type == EVENT_METADATA {
		data["key"] = event.metadata_key
		data["value"] = event.metadata_value
	}

	data["is_last"] = event.is_last

	return data
}
