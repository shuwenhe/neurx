package sse
import "time"
import "sync"
struct api_streaming_adapter {
	sse_server                  server
	streaming_pipeline          pipeline
	map[string]api_request]    active_requests
	int32                       max_concurrent_api_requests
	int32                       api_timeout_ms
	int32                       total_api_requests
	int32                       total_api_completions
	int32                       total_api_errors
	sync.Mutex                  mu
}

struct api_request {
	string                      request_id
	string                      request_type
	string                      model
	string                      endpoint
	string                      trace_id
	string                      span_id
	int64                       request_time
	int64                       response_start_time
	int64                       response_end_time
	int32                       prompt_tokens
	int32                       completion_tokens
	string                      stop_reason
	bool                        streaming_enabled
}

struct api_chat_request {
	string                      model
	[]string                messages
	float32                     temperature
	int32                       max_tokens
	string                      trace_id
	string                      request_id
	bool                        stream
}

struct api_completion_request {
	string                      model
	string                      prompt
	float32                     temperature
	int32                       max_tokens
	string                      trace_id
	string                      request_id
	bool                        stream
}

struct api_response_adapter {
	string                      response_id
	int32                       status_code
	string                      status_message
	[]string                 content_chunks
	int32                       chunk_count
	int32                       prompt_tokens
	int32                       completion_tokens
	int64                       created_timestamp
	string                      model
}

struct api_embedding_stream {
	string                      embedding_request_id
	int32                       embedding_dimension
	float32[][]]          embeddings
	int32                       embedding_count
	int64                       embedding_start_time
	int64                       embedding_end_time
}

func create_api_streaming_adapter(server sse_server, max_concurrent int32) api_streaming_adapter {
	return api_streaming_adapter{
		server:                          server,
		pipeline:                        create_streaming_pipeline(max_concurrent, 10000),
		active_requests:                 make(map[string]api_request),
		max_concurrent_api_requests:     max_concurrent,
		api_timeout_ms:                  60000,
		total_api_requests:              0,
		total_api_completions:           0,
		total_api_errors:                0,
		mu:                              sync.Mutex{},
	}
}

func (api_streaming_adapter* a) handle_streaming_chat_request(request api_chat_request) (api_response_adapter, bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if int32(len(a.active_requests)) >= a.max_concurrent_api_requests {
		response := api_response_adapter{
			response_id:       "",
			status_code:       429,
			status_message:    "too_many_requests",
			content_chunks:    make([]string, 0),
			chunk_count:       0,
			prompt_tokens:     0,
			completion_tokens: 0,
			created_timestamp: time.Now().UnixNano(),
			model:             request.model,
		}
		return response, false
	}
	api_req := api_request{
		request_id:            request.request_id,
		request_type:          "chat_completion",
		model:                 request.model,
		endpoint:              "/v1/chat/completions",
		trace_id:              request.trace_id,
		span_id:               "",
		request_time:          time.Now().UnixNano(),
		response_start_time:   0,
		response_end_time:     0,
		prompt_tokens:         0,
		completion_tokens:     0,
		stop_reason:           "",
		streaming_enabled:     request.stream,
	}
	a.active_requests[request.request_id] = api_req
	a.total_api_requests++
	a.pipeline.begin_streaming_request(request.request_id, request.trace_id, request.model)
	response := api_response_adapter{
		response_id:       request.request_id,
		status_code:       200,
		status_message:    "ok",
		content_chunks:    make([]string, 0),
		chunk_count:       0,
		prompt_tokens:     int32(len(request.messages)) * 10,
		completion_tokens: 0,
		created_timestamp: time.Now().UnixNano(),
		model:             request.model,
	}
	return response, true
}

func (api_streaming_adapter* a) handle_streaming_completion_request(request api_completion_request) (api_response_adapter, bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if int32(len(a.active_requests)) >= a.max_concurrent_api_requests {
		return api_response_adapter{
			status_code:    429,
			status_message: "too_many_requests",
		}, false
	}
	api_req := api_request{
		request_id:            request.request_id,
		request_type:          "text_completion",
		model:                 request.model,
		endpoint:              "/v1/completions",
		trace_id:              request.trace_id,
		request_time:          time.Now().UnixNano(),
		prompt_tokens:         int32(len(request.prompt)) / 4,
		streaming_enabled:     request.stream,
	}
	a.active_requests[request.request_id] = api_req
	a.total_api_requests++
	a.pipeline.begin_streaming_request(request.request_id, request.trace_id, request.model)
	response := api_response_adapter{
		response_id:       request.request_id,
		status_code:       200,
		status_message:    "ok",
		content_chunks:    make([]string, 0),
		prompt_tokens:     int32(len(request.prompt)) / 4,
		completion_tokens: 0,
		created_timestamp: time.Now().UnixNano(),
		model:             request.model,
	}
	return response, true
}

func (api_streaming_adapter* a) write_completion_chunk(request_id string, chunk string) bool {
	a.mu.Lock()
	api_req, exists := a.active_requests[request_id]
	if !exists {
		a.mu.Unlock()
		return false
	}
	api_req.completion_tokens++
	a.active_requests[request_id] = api_req
	a.mu.Unlock()
	return a.pipeline.stream_content_delta(request_id, chunk)
}

func (api_streaming_adapter* a) write_reasoning_trace(request_id string, trace_data string, reasoning_type string) bool {
	a.mu.Lock()
	api_req, exists := a.active_requests[request_id]
	if !exists {
		a.mu.Unlock()
		return false
	}
	a.mu.Unlock()
	trace_event_data := "reasoning:" + reasoning_type + ":" + trace_data
	return a.pipeline.handler.log_reasoning_step(request_id, 1, trace_event_data)
}

func (api_streaming_adapter* a) finalize_completion(request_id string, finish_reason string) (api_response_adapter, bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	api_req, exists := a.active_requests[request_id]
	if !exists {
		return api_response_adapter{}, false
	}
	api_req.response_end_time = time.Now().UnixNano()
	api_req.stop_reason = finish_reason
	stats := a.pipeline.finish_stream(request_id, finish_reason)
	delete(a.active_requests, request_id)
	a.total_api_completions++
	response := api_response_adapter{
		response_id:       request_id,
		status_code:       200,
		status_message:    "ok",
		content_chunks:    make([]string, 0),
		prompt_tokens:     api_req.prompt_tokens,
		completion_tokens: api_req.completion_tokens,
		created_timestamp: time.Now().UnixNano(),
		model:             api_req.model,
	}
	return response, true
}

func (api_streaming_adapter* a) handle_api_error(request_id string, error_code int32, error_message string) bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	api_req, exists := a.active_requests[request_id]
	if !exists {
		return false
	}
	api_req.response_end_time = time.Now().UnixNano()
	delete(a.active_requests, request_id)
	a.total_api_errors++
	return a.pipeline.handler.fail_stream(request_id, error_message)
}

func (api_streaming_adapter* a) get_adapter_stats() map[string]interface{} {
	a.mu.Lock()
	defer a.mu.Unlock()
	stats := make(map[string]interface{})
	stats["active_api_requests"] = int32(len(a.active_requests))
	stats["total_api_requests"] = a.total_api_requests
	stats["total_api_completions"] = a.total_api_completions
	stats["total_api_errors"] = a.total_api_errors
	pipeline_stats := a.pipeline.get_pipeline_stats()
	stats["pipeline_stats"] = pipeline_stats
	return stats
}

func (api_streaming_adapter* a) log_api_event(request_id string, event_type string, event_data string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	log_entry := stream_event_log{
		event_type:       STREAM_CHUNK_RECEIVED,
		event_timestamp:  time.Now().UnixNano(),
		stream_id:        request_id,
		request_id:       request_id,
		event_data:       event_data,
		event_size_bytes: int32(len(event_data)),
		source_component: "api_adapter",
		event_metadata:   make(map[string]interface{}),
	}
	if int32(len(a.pipeline.event_logs)) < a.pipeline.event_log_capacity {
		a.pipeline.event_logs = append(a.pipeline.event_logs, log_entry)
	}
}

struct api_endpoint_handler {
	api_streaming_adapter       adapter
	string                      endpoint_base_path
	int32                       rate_limit_requests_per_minute
	int32                       current_request_count
	int64                       current_minute_start
}

func create_api_endpoint_handler(adapter api_streaming_adapter) api_endpoint_handler {
	return api_endpoint_handler{
		adapter:                          adapter,
		endpoint_base_path:               "/v1",
		rate_limit_requests_per_minute:   60,
		current_request_count:            0,
		current_minute_start:             time.Now().UnixNano(),
	}
}

func (api_endpoint_handler* h) check_rate_limit() bool {
	now := time.Now().UnixNano()
	elapsed := (now - h.current_minute_start) / 1000000000
	if elapsed > 60000 {
		h.current_minute_start = now
		h.current_request_count = 0
	}
	if h.current_request_count >= h.rate_limit_requests_per_minute {
		return false
	}
	h.current_request_count++
	return true
}

func (api_endpoint_handler* h) handle_chat_completions_stream(request api_chat_request) (api_response_adapter, bool) {
	if !h.check_rate_limit() {
		return api_response_adapter{
			status_code:    429,
			status_message: "rate_limited",
		}, false
	}
	return h.adapter.handle_streaming_chat_request(request)
}

func (api_endpoint_handler* h) handle_completions_stream(request api_completion_request) (api_response_adapter, bool) {
	if !h.check_rate_limit() {
		return api_response_adapter{
			status_code:    429,
			status_message: "rate_limited",
		}, false
	}
	return h.adapter.handle_streaming_completion_request(request)
}
