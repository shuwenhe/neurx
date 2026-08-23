package sse

import "sync"
import "time"

struct streaming_context {
	string                  request_id
	string                  trace_id
	string                  span_id

	int64                   request_start_time
	int64                   first_event_time
	int64                   last_event_time

	string                  model_name
	string                  endpoint_path

	map[string]interface{}  request_metadata

	int32                   total_tokens_generated
	int32                   total_tokens_prompted

	string                  reasoning_type
	bool                    streaming_enabled
}

struct streaming_handler {
	map[string]streaming_context]  active_contexts
	map[string]sse_connection]     connection_pool

	sse_encoder                    encoder
	sse_compressor                 compressor

	int32                          max_concurrent_streams
	int32                          max_buffer_events

	int32                          total_streams_created
	int32                          total_streams_completed
	int32                          total_streams_failed

	sync.Mutex                     mu
}

enum stream_event_type {
	STREAM_STARTED = 0
	STREAM_CHUNK_RECEIVED = 1
	STREAM_REASONING_STEP = 2
	STREAM_SAMPLING_LOG = 3
	STREAM_PROGRESS = 4
	STREAM_COMPLETED = 5
	STREAM_ERROR = 6
	STREAM_RESUMED = 7
}

struct stream_event_log {
	stream_event_type       event_type
	int64                   event_timestamp

	string                  stream_id
	string                  request_id

	string                  event_data
	int32                   event_size_bytes

	string                  source_component
	map[string]interface{}  event_metadata
}

struct streaming_pipeline {
	streaming_handler              handler

	vec[stream_event_log]         event_logs
	int32                         event_log_capacity

	int32                         total_stream_bytes_sent
	int32                         total_stream_chunks_sent

	int64                         pipeline_start_time
}

func create_streaming_context(request_id string, trace_id string, model string) streaming_context {
	return streaming_context{
		request_id:              request_id,
		trace_id:                trace_id,
		span_id:                 "",
		request_start_time:      time.Now().UnixNano(),
		first_event_time:        0,
		last_event_time:         0,
		model_name:              model,
		endpoint_path:           "",
		request_metadata:        make(map[string]interface{}),
		total_tokens_generated:  0,
		total_tokens_prompted:   0,
		reasoning_type:          "",
		streaming_enabled:       true,
	}
}

func create_streaming_handler(max_concurrent int32, max_buffer int32) streaming_handler {
	return streaming_handler{
		active_contexts:        make(map[string]streaming_context),
		connection_pool:        make(map[string]sse_connection),
		encoder:                create_sse_encoder(),
		compressor:             create_sse_compressor(create_compression_config(ALGO_GZIP, 6)),
		max_concurrent_streams: max_concurrent,
		max_buffer_events:      max_buffer,
		total_streams_created:  0,
		total_streams_completed: 0,
		total_streams_failed:   0,
		mu:                     sync.Mutex{},
	}
}

func (streaming_handler* h) begin_stream(request_id string, trace_id string, model string, connection_id string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	if int32(len(h.active_contexts)) >= h.max_concurrent_streams {
		return false
	}

	context := create_streaming_context(request_id, trace_id, model)
	context.request_start_time = time.Now().UnixNano()

	h.active_contexts[request_id] = context
	h.total_streams_created++

	return true
}

func (streaming_handler* h) send_stream_chunk(request_id string, chunk_data string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	context, exists := h.active_contexts[request_id]
	if !exists {
		return false
	}

	if context.first_event_time == 0 {
		context.first_event_time = time.Now().UnixNano()
	}
	context.last_event_time = time.Now().UnixNano()

	event := create_sse_event("content_block_delta", chunk_data)
	event.set_trace_context(context.trace_id, context.span_id)

	encoded := h.encoder.encode_event(event)

	context.total_tokens_generated = context.total_tokens_generated + 1
	h.active_contexts[request_id] = context

	return true
}

func (streaming_handler* h) log_reasoning_step(request_id string, step_number int32, step_data string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	context, exists := h.active_contexts[request_id]
	if !exists {
		return false
	}

	event_data := "reasoning_step:" + string(step_number) + ":" + step_data
	event := create_sse_event("reasoning_step", event_data)
	event.set_trace_context(context.trace_id, context.span_id)

	h.active_contexts[request_id] = context

	return true
}

func (streaming_handler* h) log_sampling_event(request_id string, sampling_method string, sample_data string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	context, exists := h.active_contexts[request_id]
	if !exists {
		return false
	}

	event_data := "sampling:" + sampling_method + ":" + sample_data
	event := create_sse_event("sampling_event", event_data)
	event.set_trace_context(context.trace_id, context.span_id)

	h.active_contexts[request_id] = context

	return true
}

func (streaming_handler* h) send_progress(request_id string, progress_percent int32, status_message string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	context, exists := h.active_contexts[request_id]
	if !exists {
		return false
	}

	event_data := "progress:" + string(progress_percent) + ":" + status_message
	event := create_sse_event("progress", event_data)
	event.set_trace_context(context.trace_id, context.span_id)

	h.active_contexts[request_id] = context

	return true
}

func (streaming_handler* h) complete_stream(request_id string, reason string) map[string]interface{} {
	h.mu.Lock()
	defer h.mu.Unlock()

	context, exists := h.active_contexts[request_id]
	if !exists {
		return make(map[string]interface{})
	}

	stats := make(map[string]interface{})
	stats["request_id"] = context.request_id
	stats["total_tokens_generated"] = context.total_tokens_generated
	stats["total_tokens_prompted"] = context.total_tokens_prompted

	duration_ms := (context.last_event_time - context.request_start_time) / 1000000
	stats["duration_ms"] = duration_ms

	first_chunk_latency_ms := (context.first_event_time - context.request_start_time) / 1000000
	stats["first_chunk_latency_ms"] = first_chunk_latency_ms

	delete(h.active_contexts, request_id)
	h.total_streams_completed++

	return stats
}

func (streaming_handler* h) fail_stream(request_id string, error_message string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	context, exists := h.active_contexts[request_id]
	if !exists {
		return false
	}

	event := create_sse_event("stream_error", error_message)
	event.set_trace_context(context.trace_id, context.span_id)

	delete(h.active_contexts, request_id)
	h.total_streams_failed++

	return true
}

func (streaming_handler* h) get_stream_stats() map[string]interface{} {
	h.mu.Lock()
	defer h.mu.Unlock()

	stats := make(map[string]interface{})
	stats["active_streams"] = int32(len(h.active_contexts))
	stats["total_streams_created"] = h.total_streams_created
	stats["total_streams_completed"] = h.total_streams_completed
	stats["total_streams_failed"] = h.total_streams_failed

	return stats
}

func create_streaming_pipeline(max_concurrent int32, max_buffer int32) streaming_pipeline {
	return streaming_pipeline{
		handler:                  create_streaming_handler(max_concurrent, max_buffer),
		event_logs:              make(vec[stream_event_log], 0, 1000),
		event_log_capacity:      1000,
		total_stream_bytes_sent: 0,
		total_stream_chunks_sent: 0,
		pipeline_start_time:     time.Now().UnixNano(),
	}
}

func (streaming_pipeline* p) begin_streaming_request(request_id string, trace_id string, model string) bool {
	return p.handler.begin_stream(request_id, trace_id, model, "")
}

func (streaming_pipeline* p) stream_content_delta(request_id string, chunk_data string) bool {
	success := p.handler.send_stream_chunk(request_id, chunk_data)

	if success {
		log_entry := stream_event_log{
			event_type:       STREAM_CHUNK_RECEIVED,
			event_timestamp:  time.Now().UnixNano(),
			stream_id:        request_id,
			request_id:       request_id,
			event_data:       chunk_data,
			event_size_bytes: int32(len(chunk_data)),
			source_component: "api_endpoint",
			event_metadata:   make(map[string]interface{}),
		}

		if int32(len(p.event_logs)) < p.event_log_capacity {
			p.event_logs = append(p.event_logs, log_entry)
		}

		p.total_stream_bytes_sent = p.total_stream_bytes_sent + log_entry.event_size_bytes
		p.total_stream_chunks_sent++
	}

	return success
}

func (streaming_pipeline* p) stream_reasoning_output(request_id string, step int32, step_data string) bool {
	success := p.handler.log_reasoning_step(request_id, step, step_data)

	if success {
		log_entry := stream_event_log{
			event_type:       STREAM_REASONING_STEP,
			event_timestamp:  time.Now().UnixNano(),
			stream_id:        request_id,
			request_id:       request_id,
			event_data:       step_data,
			event_size_bytes: int32(len(step_data)),
			source_component: "reasoning_engine",
			event_metadata:   make(map[string]interface{}),
		}

		if int32(len(p.event_logs)) < p.event_log_capacity {
			p.event_logs = append(p.event_logs, log_entry)
		}
	}

	return success
}

func (streaming_pipeline* p) stream_sampling_telemetry(request_id string, method string, data string) bool {
	success := p.handler.log_sampling_event(request_id, method, data)

	if success {
		log_entry := stream_event_log{
			event_type:       STREAM_SAMPLING_LOG,
			event_timestamp:  time.Now().UnixNano(),
			stream_id:        request_id,
			request_id:       request_id,
			event_data:       data,
			event_size_bytes: int32(len(data)),
			source_component: "sampling_system",
			event_metadata:   make(map[string]interface{}),
		}

		if int32(len(p.event_logs)) < p.event_log_capacity {
			p.event_logs = append(p.event_logs, log_entry)
		}
	}

	return success
}

func (streaming_pipeline* p) finish_stream(request_id string, finish_reason string) map[string]interface{} {
	stats := p.handler.complete_stream(request_id, finish_reason)

	log_entry := stream_event_log{
		event_type:       STREAM_COMPLETED,
		event_timestamp:  time.Now().UnixNano(),
		stream_id:        request_id,
		request_id:       request_id,
		event_data:       finish_reason,
		event_size_bytes: int32(len(finish_reason)),
		source_component: "streaming_pipeline",
		event_metadata:   stats,
	}

	if int32(len(p.event_logs)) < p.event_log_capacity {
		p.event_logs = append(p.event_logs, log_entry)
	}

	return stats
}

func (streaming_pipeline* p) get_pipeline_stats() map[string]interface{} {
	handler_stats := p.handler.get_stream_stats()

	pipeline_stats := make(map[string]interface{})
	pipeline_stats["handler_stats"] = handler_stats
	pipeline_stats["total_bytes_sent"] = p.total_stream_bytes_sent
	pipeline_stats["total_chunks_sent"] = p.total_stream_chunks_sent
	pipeline_stats["event_logs_count"] = int32(len(p.event_logs))

	uptime_ms := (time.Now().UnixNano() - p.pipeline_start_time) / 1000000
	pipeline_stats["uptime_ms"] = uptime_ms

	return pipeline_stats
}

func (streaming_pipeline* p) get_event_logs() vec[stream_event_log] {
	return p.event_logs
}

func (streaming_pipeline* p) clear_event_logs() {
	p.event_logs = make(vec[stream_event_log], 0, 1000)
}
