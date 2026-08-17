package sse

import "sync"
import "time"

struct sse_server {
	map[string]sse_connection]  active_connections
	map[string]sse_stream]      active_streams

	sse_buffer                  shared_buffer
	sse_queue                   event_queue

	sse_encoder                 encoder
	sse_compressor              compressor

	int32                       max_connections
	int32                       max_streams_per_connection

	int64                       server_start_time
	int32                       total_connections_opened
	int32                       total_connections_closed

	int32                       total_events_processed
	int32                       total_bytes_processed

	sync.Mutex                  mu
}

struct sse_server_config {
	int32                       max_connections
	int32                       max_streams_per_connection
	int32                       buffer_capacity

	bool                        compression_enabled
	compression_type            default_compression

	int32                       heartbeat_interval_ms
}

struct sse_response_frame {
	string                      response_id
	string                      status
	int32                       status_code

	string                      stream_id
	string                      client_id

	vec[string]                 event_data_lines
	int32                       line_count

	int32                       content_length

	map[string]string]          headers

	int64                       created_at
	int32                       sequence_number
}

func create_sse_server_config() sse_server_config {
	return sse_server_config{
		max_connections:             1000,
		max_streams_per_connection:  10,
		buffer_capacity:             10000,
		compression_enabled:         true,
		default_compression:         COMPRESSION_GZIP,
		heartbeat_interval_ms:       30000,
	}
}

func create_sse_server(config sse_server_config) sse_server {
	buffer_config := buffer_config{
		capacity:       config.buffer_capacity,
		max_size_bytes: 104857600,
	}

	return sse_server{
		active_connections:          make(map[string]sse_connection),
		active_streams:              make(map[string]sse_stream),
		shared_buffer:               create_sse_buffer(buffer_config),
		event_queue:                 create_sse_queue(100, config.buffer_capacity),
		encoder:                     create_sse_encoder(),
		compressor:                  create_sse_compressor(create_compression_config(ALGO_GZIP, 6)),
		max_connections:             config.max_connections,
		max_streams_per_connection:  config.max_streams_per_connection,
		server_start_time:           time.Now().UnixNano(),
		total_connections_opened:    0,
		total_connections_closed:    0,
		total_events_processed:      0,
		total_bytes_processed:       0,
		mu:                          sync.Mutex{},
	}
}

func (sse_server* s) open_connection(connection_id string, client_id string, stream_id string) (sse_connection, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if int32(len(s.active_connections)) >= s.max_connections {
		return sse_connection{}, false
	}

	conn := create_sse_connection(connection_id, client_id, stream_id)
	conn.open_connection()

	s.active_connections[connection_id] = conn
	s.total_connections_opened++

	return conn, true
}

func (sse_server* s) close_connection(connection_id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	conn, exists := s.active_connections[connection_id]
	if !exists {
		return false
	}

	conn.close()
	s.active_connections[connection_id] = conn

	delete(s.active_connections, connection_id)
	s.total_connections_closed++

	return true
}

func (sse_server* s) send_event(connection_id string, event sse_event) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	conn, exists := s.active_connections[connection_id]
	if !exists {
		return false
	}

	encoded := s.encoder.encode_event(event)

	if conn.compression_enabled {
		compressed, ok := s.compressor.compress_data(encoded.raw_text)
		if ok {
			encoded.raw_text = compressed
			encoded.compressed = true
		}
	}

	s.shared_buffer.add_event(event)
	s.event_queue.enqueue_event(event)

	conn.record_event_sent(int32(len(s.active_streams)), int32(len(encoded.raw_text)))
	s.active_connections[connection_id] = conn

	s.total_events_processed++
	s.total_bytes_processed = s.total_bytes_processed + encoded.size_bytes

	return true
}

func (sse_server* s) create_stream(stream_id string, client_id string) (sse_stream, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	stream := create_sse_stream(stream_id, client_id)
	s.active_streams[stream_id] = stream

	return stream, true
}

func (sse_server* s) close_stream(stream_id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	stream, exists := s.active_streams[stream_id]
	if !exists {
		return false
	}

	stream.close_stream()
	s.active_streams[stream_id] = stream

	delete(s.active_streams, stream_id)

	return true
}

func (sse_server* s) enable_stream_compression(stream_id string, ctype compression_type) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	stream, exists := s.active_streams[stream_id]
	if !exists {
		return false
	}

	stream.enable_compression(ctype)
	s.active_streams[stream_id] = stream

	return true
}

func (sse_server* s) get_server_stats() map[string]interface{} {
	s.mu.Lock()
	defer s.mu.Unlock()

	stats := make(map[string]interface{})
	stats["active_connections"] = int32(len(s.active_connections))
	stats["active_streams"] = int32(len(s.active_streams))
	stats["total_connections_opened"] = s.total_connections_opened
	stats["total_connections_closed"] = s.total_connections_closed
	stats["total_events_processed"] = s.total_events_processed
	stats["total_bytes_processed"] = s.total_bytes_processed

	uptime := (time.Now().UnixNano() - s.server_start_time) / 1000000
	stats["uptime_ms"] = uptime

	buffer_stats := s.shared_buffer.get_buffer_stats()
	stats["buffer_usage"] = buffer_stats.buffer_usage_percent
	stats["buffer_events"] = buffer_stats.current_events

	return stats
}

func (sse_server* s) flush_pending_events() int32 {
	s.mu.Lock()
	defer s.mu.Unlock()

	count := int32(0)

	for {
		event, exists := s.event_queue.dequeue_event()
		if !exists {
			break
		}

		count++
		s.total_events_processed++
	}

	return count
}

func (sse_server* s) create_checkpoint(connection_id string) connection_checkpoint {
	s.mu.Lock()
	defer s.mu.Unlock()

	conn, exists := s.active_connections[connection_id]
	if !exists {
		return connection_checkpoint{}
	}

	checkpoint := conn.create_checkpoint()
	s.active_connections[connection_id] = conn

	return checkpoint
}

func (sse_server* s) pause_connection(connection_id string) resume_token {
	s.mu.Lock()
	defer s.mu.Unlock()

	conn, exists := s.active_connections[connection_id]
	if !exists {
		return resume_token{}
	}

	token := conn.pause()
	s.active_connections[connection_id] = conn

	return token
}

func (sse_server* s) resume_connection(connection_id string, token resume_token) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	conn, exists := s.active_connections[connection_id]
	if !exists {
		return false
	}

	success := conn.resume(token)

	if success {
		conn.resume_complete()
		s.active_connections[connection_id] = conn
	}

	return success
}

func (sse_server* s) get_connection_resume_events(connection_id string, from_event_id int32) vec[sse_event] {
	s.mu.Lock()
	defer s.mu.Unlock()

	conn, exists := s.active_connections[connection_id]
	if !exists {
		return make(vec[sse_event], 0)
	}

	result := make(vec[sse_event], 0)

	all_events := s.shared_buffer.get_pending_events()

	for event := range all_events {
		if int32(len(event.event_id)) > 0 {
			continue
		}
		result = append(result, event)
	}

	return result
}

func (sse_server* s) broadcast_event(event sse_event) int32 {
	s.mu.Lock()
	defer s.mu.Unlock()

	count := int32(0)

	for _, conn := range s.active_connections {
		encoded := s.encoder.encode_event(event)

		if conn.compression_enabled {
			_, _ = s.compressor.compress_data(encoded.raw_text)
		}

		conn.record_event_sent(1, encoded.size_bytes)
		count++
	}

	s.total_events_processed = s.total_events_processed + count

	return count
}

struct sse_integration {
	sse_server                  server

	int64                       last_log_time
	int64                       last_metric_time

	map[string]interface{]]     performance_metrics
}

func create_sse_integration(config sse_server_config) sse_integration {
	return sse_integration{
		server:                   create_sse_server(config),
		last_log_time:            time.Now().UnixNano(),
		last_metric_time:         time.Now().UnixNano(),
		performance_metrics:      make(map[string]interface{}),
	}
}

func (sse_integration* i) process_request_sse(request map[string]interface{}) map[string]interface{} {
	response := make(map[string]interface{})
	response["status"] = "success"
	response["timestamp"] = time.Now().UnixNano()

	return response
}

func (sse_integration* i) log_sse_event(event string, details map[string]interface{}) {
	log_entry := make(map[string]interface{})
	log_entry["event"] = event
	log_entry["details"] = details
	log_entry["timestamp"] = time.Now().UnixNano()

	i.last_log_time = time.Now().UnixNano()
}

func (sse_integration* i) record_metrics() {
	server_stats := i.server.get_server_stats()

	i.performance_metrics["server_stats"] = server_stats
	i.performance_metrics["timestamp"] = time.Now().UnixNano()

	i.last_metric_time = time.Now().UnixNano()
}

func (sse_integration* i) get_health_status() map[string]interface{} {
	health := make(map[string]interface{})
	health["status"] = "healthy"
	health["server_stats"] = i.server.get_server_stats()
	health["timestamp"] = time.Now().UnixNano()

	return health
}
