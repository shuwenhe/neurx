package sse

import "time"

struct sse_encoder {
	compression_type        default_compression
	bool                    enable_multiline
	bool                    enable_escape

	int32                   max_line_length
	string                  line_separator

	int32                   total_events_encoded
	int32                   total_bytes_encoded

	map[string]int32        field_counts
}

struct encoded_event {
	string                  raw_text
	int32                   size_bytes

	string[]             lines
	int32                   line_count

	bool                    compressed
	string                  compression_method

	int64                   encoded_time
}


	FORMAT_TEXT = 0
	FORMAT_JSON = 1
	FORMAT_PROTOBUF = 2
}

func create_sse_encoder() sse_encoder {
	return sse_encoder{
		default_compression:    COMPRESSION_NONE,
		enable_multiline:       true,
		enable_escape:          true,
		max_line_length:        8192,
		line_separator:         "\n",
		total_events_encoded:   0,
		total_bytes_encoded:    0,
		field_counts:           make(map[string]int32),
	}
}

func (sse_encoder* e) encode_event(event sse_event) encoded_event {
	encoded := encoded_event{
		raw_text:            "",
		size_bytes:          0,
		lines:               make(string[], 0),
		line_count:          0,
		compressed:          false,
		compression_method:  "none",
		encoded_time:        time.Now().UnixNano(),
	}

	output := ""

	if event.event_type != "" {
		output = output + "event: " + event.event_type + "\n"
		e.field_counts["event"]++
	}

	if event.event_id != "" {
		output = output + "id: " + event.event_id + "\n"
		e.field_counts["id"]++
	}

	if event.retry_ms > 0 {
		output = output + "retry: " + string(event.retry_ms) + "\n"
		e.field_counts["retry"]++
	}

	if event.event_data != "" {
		data := event.event_data

		if e.enable_multiline {
			lines := make(string[], 0)
			current_line := ""

			for i := int32(0); i < int32(len(data)); i++ {
				if int32(len(current_line)) >= e.max_line_length {
					lines = append(lines, current_line)
					current_line = ""
				}
				current_line = current_line + string(data[i])
			}

			if int32(len(current_line)) > 0 {
				lines = append(lines, current_line)
			}

			for line := range lines {
				output = output + "data: " + line + "\n"
			}
		} else {
			output = output + "data: " + data + "\n"
		}

		e.field_counts["data"]++
	}

	output = output + "\n"

	encoded.raw_text = output
	encoded.size_bytes = int32(len(output))
	encoded.line_count = int32(len(output))

	e.total_events_encoded++
	e.total_bytes_encoded = e.total_bytes_encoded + encoded.size_bytes

	return encoded
}

func (sse_encoder* e) encode_event_json(event sse_event) string {
	json_str := "{"
	json_str = json_str + "\"event\":\"" + event.event_type + "\","
	json_str = json_str + "\"id\":\"" + event.event_id + "\","
	json_str = json_str + "\"data\":\"" + event.event_data + "\","
	json_str = json_str + "\"retry\":" + string(event.retry_ms)
	json_str = json_str + "}\n"

	return json_str
}

func (sse_encoder* e) encode_frame(frame sse_frame) string {
	output := ""

	for field := range frame.fields {
		switch field.field_type {
		case FIELD_EVENT:
			output = output + "event: " + field.field_value + "\n"
		case FIELD_DATA:
			output = output + "data: " + field.field_value + "\n"
		case FIELD_ID:
			output = output + "id: " + field.field_value + "\n"
		case FIELD_RETRY:
			output = output + "retry: " + field.field_value + "\n"
		case FIELD_COMMENT:
			output = output + ": " + field.field_value + "\n"
		}
	}

	output = output + "\n"

	return output
}

func (sse_encoder* e) escape_data(data string) string {
	escaped := ""

	for i := int32(0); i < int32(len(data)); i++ {
		ch := data[i]

		if ch == '\n' {
			escaped = escaped + "\\n"
		} else if ch == '\r' {
			escaped = escaped + "\\r"
		} else if ch == '"' {
			escaped = escaped + "\\\""
		} else if ch == '\\' {
			escaped = escaped + "\\\\"
		} else {
			escaped = escaped + string(ch)
		}
	}

	return escaped
}

func (sse_encoder* e) split_multiline(data string) string[] {
	lines := make(string[], 0)
	current_line := ""

	for i := int32(0); i < int32(len(data)); i++ {
		if data[i] == '\n' {
			if int32(len(current_line)) > 0 {
				lines = append(lines, current_line)
			}
			current_line = ""
		} else {
			current_line = current_line + string(data[i])

			if int32(len(current_line)) >= e.max_line_length {
				lines = append(lines, current_line)
				current_line = ""
			}
		}
	}

	if int32(len(current_line)) > 0 {
		lines = append(lines, current_line)
	}

	return lines
}

func (sse_encoder* e) get_encoder_stats() map[string]interface{} {
	stats := make(map[string]interface{})
	stats["total_events_encoded"] = e.total_events_encoded
	stats["total_bytes_encoded"] = e.total_bytes_encoded
	stats["compression_enabled"] = e.default_compression != COMPRESSION_NONE

	return stats
}

func (sse_encoder* e) reset_stats() {
	e.total_events_encoded = 0
	e.total_bytes_encoded = 0
	e.field_counts = make(map[string]int32)
}

struct sse_batch_encoder {
	encoded_event[]      encoded_events
	int32                   event_count

	int32                   batch_size_bytes
	int32                   max_batch_size

	bool                    ready_to_send
}

func create_sse_batch_encoder(max_batch_size int32) sse_batch_encoder {
	return sse_batch_encoder{
		encoded_events:   make(encoded_event[], 0, 100),
		event_count:      0,
		batch_size_bytes: 0,
		max_batch_size:   max_batch_size,
		ready_to_send:    false,
	}
}

func (sse_batch_encoder* b) add_encoded_event(event encoded_event) bool {
	if b.batch_size_bytes+event.size_bytes > b.max_batch_size {
		b.ready_to_send = true
		return false
	}

	b.encoded_events = append(b.encoded_events, event)
	b.event_count++
	b.batch_size_bytes = b.batch_size_bytes + event.size_bytes

	return true
}

func (sse_batch_encoder* b) get_batch_data() string {
	output := ""

	for event := range b.encoded_events {
		output = output + event.raw_text
	}

	return output
}

func (sse_batch_encoder* b) get_batch_size_bytes() int32 {
	return b.batch_size_bytes
}

func (sse_batch_encoder* b) clear_batch() {
	b.encoded_events = make(encoded_event[], 0, 100)
	b.event_count = 0
	b.batch_size_bytes = 0
	b.ready_to_send = false
}

func (sse_batch_encoder* b) is_batch_ready() bool {
	return b.ready_to_send || b.batch_size_bytes > 0
}
