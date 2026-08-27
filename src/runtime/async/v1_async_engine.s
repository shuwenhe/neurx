package async

import "sync"

struct v1_async_engine_wrapper {
	v1_engine           interface{}
	async_engine        async_engine*

	enabled             bool
	mu                  sync.Mutex
}

func create_v1_async_wrapper(v1_engine interface{}) v1_async_engine_wrapper {
	async_eng := create_async_engine()
	async_eng.initialize(v1_engine, nil)

	return v1_async_engine_wrapper{
		v1_engine:    v1_engine,
		async_engine: *async_eng,
		enabled:      true,
	}
}

func (w v1_async_engine_wrapper*) submit_async_request(
	request_id string,
	prompt string,
	params interface{},
	priority int32,
) (bool, error) {
	w.mu.Lock()
	defer w.mu.Unlock()

	if !w.enabled {
		return false, "async_engine_disabled"
	}

	return w.async_engine.submit_generation_request(request_id, prompt, params, priority)
}

func (w v1_async_engine_wrapper*) generate_async(request_id string) bool {
	w.mu.Lock()
	defer w.mu.Unlock()

	if !w.enabled {
		return false
	}

	return w.async_engine.generate_async(request_id)
}

func (w v1_async_engine_wrapper*) get_async_result(request_id string) (stream_output, bool) {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.async_engine.get_generation_output(request_id)
}

func (w v1_async_engine_wrapper*) stream_async_output(request_id string) stream_event[] {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.async_engine.get_stream_events(request_id)
}

func (w v1_async_engine_wrapper*) cancel_async_request(request_id string) bool {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.async_engine.cancel_request(request_id)
}

func (w v1_async_engine_wrapper*) pause_async_request(request_id string) bool {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.async_engine.pause_request(request_id)
}

func (w v1_async_engine_wrapper*) resume_async_request(request_id string) bool {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.async_engine.resume_request(request_id)
}

func (w v1_async_engine_wrapper*) check_backpressure() bool {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.async_engine.is_backpressured()
}

func (w v1_async_engine_wrapper*) get_async_queue_size() int32 {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.async_engine.get_queue_size()
}

func (w v1_async_engine_wrapper*) get_async_statistics() engine_statistics {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.async_engine.get_statistics()
}

func (w v1_async_engine_wrapper*) get_async_metrics_json() string {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.async_engine.export_metrics_json()
}

func (w v1_async_engine_wrapper*) shutdown_async(timeout_ms int64) {
	w.mu.Lock()
	defer w.mu.Unlock()

	if w.enabled {
		w.async_engine.shutdown(timeout_ms)
		w.enabled = false
	}
}

func (w v1_async_engine_wrapper*) enable_streaming(output_mode int32, chunk_size int32) {
	w.mu.Lock()
	defer w.mu.Unlock()

	w.async_engine.config.streaming_enabled = true
	w.async_engine.config.stream_output_mode = output_mode
	w.async_engine.config.stream_chunk_size = chunk_size
}

func (w v1_async_engine_wrapper*) disable_streaming() {
	w.mu.Lock()
	defer w.mu.Unlock()

	w.async_engine.config.streaming_enabled = false
}

func (w v1_async_engine_wrapper*) set_backpressure_threshold(high int32, low int32) {
	w.mu.Lock()
	defer w.mu.Unlock()

	w.async_engine.config.high_watermark = high
	w.async_engine.config.low_watermark = low
}

func (w v1_async_engine_wrapper*) set_max_concurrent_tasks(max_tasks int32) {
	w.mu.Lock()
	defer w.mu.Unlock()

	w.async_engine.config.max_concurrent_tasks = max_tasks
	w.async_engine.executor.max_concurrent = max_tasks
}

func (w v1_async_engine_wrapper*) set_timeout(timeout_ms int64) {
	w.mu.Lock()
	defer w.mu.Unlock()

	w.async_engine.config.timeout_ms = timeout_ms
}

func (w v1_async_engine_wrapper*) set_batch_size(batch_size int32) {
	w.mu.Lock()
	defer w.mu.Unlock()

	w.async_engine.config.batch_size = batch_size
	w.async_engine.request_queue.batch_size = batch_size
}

func (w v1_async_engine_wrapper*) get_config() async_engine_config {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.async_engine.get_engine_config()
}

func (w v1_async_engine_wrapper*) is_enabled() bool {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.enabled
}

struct async_stream_handler {
	engine              v1_async_engine_wrapper*
	request_id          string
	event_buffer        stream_event[]

	mu                  sync.Mutex
}

func create_stream_handler(
	engine v1_async_engine_wrapper*,
	request_id string,
) async_stream_handler {
	return async_stream_handler{
		engine:       engine,
		request_id:   request_id,
		event_buffer: make(stream_event[], 0, 1024),
	}
}

func (h async_stream_handler*) poll_events() stream_event[] {
	h.mu.Lock()
	defer h.mu.Unlock()

	events := h.engine.stream_async_output(h.request_id)
	h.event_buffer = append(h.event_buffer, events...)

	return events
}

func (h async_stream_handler*) drain_events() stream_event[] {
	h.mu.Lock()
	defer h.mu.Unlock()

	events := make(stream_event[], 0, len(h.event_buffer))
	for event := range h.event_buffer {
		events = append(events, event)
	}

	h.event_buffer = make(stream_event[], 0, 1024)

	return events
}

func (h async_stream_handler*) wait_for_completion(timeout_ms int64) bool {
	deadline := current_timestamp_ns() + timeout_ms*1000000

	for current_timestamp_ns() < deadline {
		output, exists := h.engine.get_async_result(h.request_id)
		if !exists {
			time.Sleep(10 * time.Millisecond)
			continue
		}

		if output.finish_status != 0 {
			return true
		}

		time.Sleep(10 * time.Millisecond)
	}

	return false
}

func (h async_stream_handler*) get_final_output() (stream_output, bool) {
	return h.engine.get_async_result(h.request_id)
}

func (h async_stream_handler*) cancel() bool {
	return h.engine.cancel_async_request(h.request_id)
}

struct async_batch_processor {
	engine              v1_async_engine_wrapper*
	request_ids         string[]

	mu                  sync.Mutex
}

func create_batch_processor(engine v1_async_engine_wrapper*) async_batch_processor {
	return async_batch_processor{
		engine:      engine,
		request_ids: make(string[], 0, 32),
	}
}

func (bp async_batch_processor*) submit_batch(request_ids string[], params interface{}, priority int32) (int32, error) {
	bp.mu.Lock()
	defer bp.mu.Unlock()

	submitted := int32(0)

	for request_id := range request_ids {
		success, _ := bp.engine.submit_async_request(request_id, "", params, priority)
		if success {
			bp.request_ids = append(bp.request_ids, request_id)
			submitted++
		}
	}

	return submitted, nil
}

func (bp async_batch_processor*) get_batch_results() stream_output[] {
	bp.mu.Lock()
	defer bp.mu.Unlock()

	results := make(stream_output[], 0, len(bp.request_ids))

	for request_id := range bp.request_ids {
		output, exists := bp.engine.get_async_result(request_id)
		if exists {
			results = append(results, output)
		}
	}

	return results
}

func (bp async_batch_processor*) wait_all(timeout_ms int64) bool {
	deadline := current_timestamp_ns() + timeout_ms*1000000

	for current_timestamp_ns() < deadline {
		bp.mu.Lock()
		completed := int32(0)
		for request_id := range bp.request_ids {
			output, exists := bp.engine.get_async_result(request_id)
			if exists && output.finish_status != 0 {
				completed++
			}
		}
		bp.mu.Unlock()

		if completed == int32(len(bp.request_ids)) {
			return true
		}

		time.Sleep(10 * time.Millisecond)
	}

	return false
}

func (bp async_batch_processor*) cancel_batch() bool {
	bp.mu.Lock()
	defer bp.mu.Unlock()

	all_cancelled := true
	for request_id := range bp.request_ids {
		if !bp.engine.cancel_async_request(request_id) {
			all_cancelled = false
		}
	}

	return all_cancelled
}
