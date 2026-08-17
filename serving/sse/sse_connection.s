package sse

import "sync"
import "time"

enum connection_state {
	CONN_INITIALIZED = 0
	CONN_OPEN = 1
	CONN_PAUSED = 2
	CONN_RESUMING = 3
	CONN_CLOSED = 4
	CONN_FAILED = 5
}

struct resume_token {
	string                  token_id
	int32                   last_event_id
	int64                   resume_timestamp

	string                  client_id
	string                  stream_id

	int32                   events_before_pause
	int32                   bytes_before_pause

	bool                    is_valid
	int64                   token_expiry
}

struct connection_checkpoint {
	int32                   checkpoint_id
	int32                   last_sent_event_id
	int64                   checkpoint_time

	int32                   total_events_sent
	int32                   total_bytes_sent

	string                  last_event_data_hash
}

struct sse_connection {
	string                  connection_id
	string                  client_id
	string                  stream_id

	connection_state        current_state

	int64                   connection_open_time
	int64                   last_heartbeat_time
	int64                   last_activity_time

	int32                   total_events_sent
	int32                   total_bytes_sent

	int32                   heartbeat_interval_ms
	int32                   idle_timeout_ms

	vec[resume_token]       resume_tokens
	vec[connection_checkpoint] checkpoints

	int32                   current_checkpoint_id

	map[string]string       metadata

	sync.Mutex              mu

	bool                    compression_enabled
	compression_type        active_compression
}

struct reconnection_info {
	string                  resume_token
	int32                   expected_event_id
	int64                   disconnection_time
	int32                   reconnection_attempts
}

func create_sse_connection(connection_id string, client_id string, stream_id string) sse_connection {
	return sse_connection{
		connection_id:          connection_id,
		client_id:              client_id,
		stream_id:              stream_id,
		current_state:          CONN_INITIALIZED,
		connection_open_time:   time.Now().UnixNano(),
		last_heartbeat_time:    time.Now().UnixNano(),
		last_activity_time:     time.Now().UnixNano(),
		total_events_sent:      0,
		total_bytes_sent:       0,
		heartbeat_interval_ms:  30000,
		idle_timeout_ms:        300000,
		resume_tokens:          make(vec[resume_token], 0),
		checkpoints:            make(vec[connection_checkpoint], 0),
		current_checkpoint_id:  0,
		metadata:               make(map[string]string),
		mu:                     sync.Mutex{},
		compression_enabled:    false,
		active_compression:     COMPRESSION_NONE,
	}
}

func create_resume_token(client_id string, stream_id string, last_event_id int32) resume_token {
	return resume_token{
		token_id:              "",
		last_event_id:         last_event_id,
		resume_timestamp:      time.Now().UnixNano(),
		client_id:             client_id,
		stream_id:             stream_id,
		events_before_pause:   0,
		bytes_before_pause:    0,
		is_valid:              true,
		token_expiry:          time.Now().UnixNano() + 3600000000000,
	}
}

func (sse_connection* c) open_connection() bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.current_state == CONN_INITIALIZED {
		c.current_state = CONN_OPEN
		c.connection_open_time = time.Now().UnixNano()
		c.last_heartbeat_time = time.Now().UnixNano()
		return true
	}

	return false
}

func (sse_connection* c) get_state() connection_state {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.current_state
}

func (sse_connection* c) record_event_sent(event_id int32, event_size int32) {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.total_events_sent++
	c.total_bytes_sent = c.total_bytes_sent + event_size
	c.last_activity_time = time.Now().UnixNano()
}

func (sse_connection* c) send_heartbeat() {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.last_heartbeat_time = time.Now().UnixNano()
	c.last_activity_time = time.Now().UnixNano()
}

func (sse_connection* c) is_idle() bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	idle_time := time.Now().UnixNano() - c.last_activity_time
	return idle_time > int64(c.idle_timeout_ms)*1000000
}

func (sse_connection* c) need_heartbeat() bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	time_since_heartbeat := time.Now().UnixNano() - c.last_heartbeat_time
	return time_since_heartbeat > int64(c.heartbeat_interval_ms)*1000000
}

func (sse_connection* c) create_checkpoint() connection_checkpoint {
	c.mu.Lock()
	defer c.mu.Unlock()

	checkpoint := connection_checkpoint{
		checkpoint_id:           c.current_checkpoint_id,
		last_sent_event_id:      c.total_events_sent,
		checkpoint_time:         time.Now().UnixNano(),
		total_events_sent:       c.total_events_sent,
		total_bytes_sent:        c.total_bytes_sent,
		last_event_data_hash:    "",
	}

	c.checkpoints = append(c.checkpoints, checkpoint)
	c.current_checkpoint_id++

	return checkpoint
}

func (sse_connection* c) create_resume_token(last_event_id int32) resume_token {
	c.mu.Lock()
	defer c.mu.Unlock()

	token := create_resume_token(c.client_id, c.stream_id, last_event_id)
	token.events_before_pause = c.total_events_sent
	token.bytes_before_pause = c.total_bytes_sent

	c.resume_tokens = append(c.resume_tokens, token)

	return token
}

func (sse_connection* c) pause() resume_token {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.current_state != CONN_OPEN {
		return resume_token{}
	}

	c.current_state = CONN_PAUSED

	token := create_resume_token(c.client_id, c.stream_id, c.total_events_sent)
	token.events_before_pause = c.total_events_sent
	token.bytes_before_pause = c.total_bytes_sent

	c.resume_tokens = append(c.resume_tokens, token)

	return token
}

func (sse_connection* c) resume(resume_token resume_token) bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.current_state != CONN_PAUSED {
		return false
	}

	if !resume_token.is_valid {
		return false
	}

	now := time.Now().UnixNano()
	if now > resume_token.token_expiry {
		return false
	}

	c.current_state = CONN_RESUMING
	c.last_activity_time = now

	return true
}

func (sse_connection* c) resume_complete() bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.current_state == CONN_RESUMING {
		c.current_state = CONN_OPEN
		c.last_activity_time = time.Now().UnixNano()
		return true
	}

	return false
}

func (sse_connection* c) close() {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.current_state = CONN_CLOSED
	c.resume_tokens = make(vec[resume_token], 0)
}

func (sse_connection* c) mark_failed() {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.current_state = CONN_FAILED
}

func (sse_connection* c) get_connection_stats() map[string]interface{} {
	c.mu.Lock()
	defer c.mu.Unlock()

	stats := make(map[string]interface{})
	stats["connection_id"] = c.connection_id
	stats["client_id"] = c.client_id
	stats["stream_id"] = c.stream_id
	stats["state"] = c.current_state
	stats["total_events_sent"] = c.total_events_sent
	stats["total_bytes_sent"] = c.total_bytes_sent

	uptime := (time.Now().UnixNano() - c.connection_open_time) / 1000000
	stats["uptime_ms"] = uptime

	idle_time := (time.Now().UnixNano() - c.last_activity_time) / 1000000
	stats["idle_time_ms"] = idle_time

	return stats
}

func (sse_connection* c) set_metadata(key string, value string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.metadata[key] = value
}

func (sse_connection* c) get_metadata(key string) (string, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	value, exists := c.metadata[key]
	return value, exists
}

func (sse_connection* c) enable_compression(ctype compression_type) {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.compression_enabled = true
	c.active_compression = ctype
}

func (sse_connection* c) disable_compression() {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.compression_enabled = false
	c.active_compression = COMPRESSION_NONE
}

func (sse_connection* c) get_connection_duration_ms() int64 {
	c.mu.Lock()
	defer c.mu.Unlock()

	return (time.Now().UnixNano() - c.connection_open_time) / 1000000
}

func (sse_connection* c) validate_resume_token(token resume_token) bool {
	if !token.is_valid {
		return false
	}

	now := time.Now().UnixNano()
	if now > token.token_expiry {
		return false
	}

	if token.client_id != c.client_id {
		return false
	}

	if token.stream_id != c.stream_id {
		return false
	}

	return true
}
