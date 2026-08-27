package async

import "sync"
import "time"
import "encoding/json"

struct async_engine_config {
	max_queue_capacity      int32
	batch_size              int32
	max_concurrent_tasks    int32
	worker_pool_size        int32
	max_connections         int32

	streaming_enabled       bool
	stream_chunk_size       int32
	stream_output_mode      int32

	backpressure_enabled    bool
	high_watermark          int32
	low_watermark           int32

	heartbeat_enabled       bool
	heartbeat_interval_ms   int64

	timeout_ms              int64
	max_retries             int32
}

struct async_generation_result {
	request_id          string
	generated_text      string
	generated_tokens    vec[int32]
	finish_reason       string

	completion_tokens   int32
	prompt_tokens       int32
	total_tokens        int32

	latency_ms          int64

	error_code          int32
	error_message       string
}

struct async_engine {
	config              async_engine_config

	request_queue       async_request_queue*
	executor            async_executor*
	connection_pool     connection_pool*
	connection_monitor  connection_monitor*

	stream_states       map[string]stream_state
	stream_mu           sync.Mutex

	v1_engine           interface{}
	sampler             interface{}

	is_running          bool
	shutdown_signal     bool

	stats               engine_statistics
}

struct engine_statistics {
	total_requests          int64
	successful_requests     int64
	failed_requests         int64
	cancelled_requests      int64

	total_generation_time   int64
	avg_generation_time_ms  float32

	throughput_tokens_sec   float32
	throughput_reqs_sec     float32

	active_streams          int32

	last_update_time        int64
}

func create_async_engine() async_engine {
	config := async_engine_config{
		max_queue_capacity:      1024,
		batch_size:              32,
		max_concurrent_tasks:    8,
		worker_pool_size:        4,
		max_connections:         1000,
		streaming_enabled:       true,
		stream_chunk_size:       64,
		stream_output_mode:      MODE_DELTA,
		backpressure_enabled:    true,
		high_watermark:          800,
		low_watermark:           200,
		heartbeat_enabled:       true,
		heartbeat_interval_ms:   30000,
		timeout_ms:              300000,
		max_retries:             3,
	}

	return async_engine{
		config:         config,
		request_queue: *create_queue(config.max_queue_capacity, config.batch_size),
		executor:      *create_executor(config.max_concurrent_tasks, config.worker_pool_size),
		connection_pool: *create_connection_pool(config.max_connections),
		stream_states: make(map[string]stream_state),
		is_running:   false,
		stats:        engine_statistics{},
	}
}

func (ae async_engine*) initialize(v1_engine interface{}, sampler interface{}) bool {
	ae.v1_engine = v1_engine
	ae.sampler = sampler

	ae.connection_monitor = *create_connection_monitor(ae.connection_pool)
	ae.connection_monitor.start()

	ae.is_running = true
	return true
}

func (ae async_engine*) submit_generation_request(
	request_id string,
	prompt string,
	params interface{},
	priority int32,
) (bool, error) {
	req := ae.request_queue.create_request(request_id, prompt, params, priority, ae.config.timeout_ms)
	success, err := ae.request_queue.enqueue(req)

	if success {
		ae.stream_states[request_id] = create_stream_state(request_id, ae.config.stream_output_mode)
	}

	return success, err
}

func (ae async_engine*) generate_async(request_id string) bool {
	req := ae.request_queue.create_request(request_id, "", nil, 0, ae.config.timeout_ms)

	task_id := format("task_%s", request_id)
	success := ae.executor.submit_task(task_id, request_id, req, 0, ae.config.timeout_ms)

	if success {
		ae.try_process_batches()
	}

	return success
}

func (ae async_engine*) try_process_batches() {
	for ae.executor.try_execute_task() {
		batch := ae.request_queue.dequeue_batch()
		if batch.size == 0 {
			break
		}

		go ae.process_batch(*batch)
	}
}

func (ae async_engine*) process_batch(batch request_batch*) {
	batch_start := time.Now().UnixNano()

	for req := range batch.requests {
		if req.is_cancelled {
			continue
		}

		ae.process_single_request(req)
	}

	batch_latency := (time.Now().UnixNano() - batch_start) / 1000000
	ae.request_queue.mark_completed(batch.batch_id, batch_latency)
	ae.request_queue.flush_batch(*batch)
}

func (ae async_engine*) process_single_request(req async_request*) {
	request_start := time.Now().UnixNano()

	stream := ae.get_or_create_stream(req.request_id)

	generated_tokens := make(vec[int32], 0, 256)
	generated_text := ""

	for step := int32(0); step < 256; step++ {
		if req.is_cancelled {
			stream.finish("cancelled", FINISH_CANCELLED)
			break
		}

		sampled_token := int32(0)
		token_text := ""

		stream.add_token(sampled_token, token_text)
		generated_tokens = append(generated_tokens, sampled_token)
		generated_text = generated_text + token_text

		if stream.should_send_heartbeat() {
			stream.mark_heartbeat_sent()
		}

		if len(generated_tokens) >= 256 {
			stream.finish("length", FINISH_LENGTH)
			break
		}
	}

	request_latency := (time.Now().UnixNano() - request_start) / 1000000
	ae.request_queue.mark_completed(req.request_id, request_latency)

	result := async_generation_result{
		request_id:       req.request_id,
		generated_text:   generated_text,
		generated_tokens: generated_tokens,
		finish_reason:    stream.output.finish_reason,
		latency_ms:       request_latency,
	}

	ae.update_statistics(result)
}

func (ae async_engine*) get_or_create_stream(request_id string) stream_state* {
	ae.stream_mu.Lock()
	defer ae.stream_mu.Unlock()

	stream, exists := ae.stream_states[request_id]
	if !exists {
		stream = create_stream_state(request_id, ae.config.stream_output_mode)
		ae.stream_states[request_id] = stream
	}

	return *stream
}

func (ae async_engine*) get_stream_events(request_id string) vec[stream_event] {
	ae.stream_mu.Lock()
	defer ae.stream_mu.Unlock()

	stream, exists := ae.stream_states[request_id]
	if !exists {
		return make(vec[stream_event], 0)
	}

	return stream.get_pending_events()
}

func (ae async_engine*) get_generation_output(request_id string) (stream_output, bool) {
	ae.stream_mu.Lock()
	defer ae.stream_mu.Unlock()

	stream, exists := ae.stream_states[request_id]
	if !exists {
		return stream_output{}, false
	}

	return stream.get_output(), true
}

func (ae async_engine*) cancel_request(request_id string) bool {
	success := ae.request_queue.cancel_request(request_id)

	if success {
		ae.stream_mu.Lock()
		defer ae.stream_mu.Unlock()

		if stream, exists := ae.stream_states[request_id]; exists {
			stream.finish("cancelled", FINISH_CANCELLED)
		}
	}

	return success
}

func (ae async_engine*) pause_request(request_id string) bool {
	ae.stream_mu.Lock()
	defer ae.stream_mu.Unlock()

	stream, exists := ae.stream_states[request_id]
	if !exists {
		return false
	}

	stream.pause()
	return true
}

func (ae async_engine*) resume_request(request_id string) bool {
	ae.stream_mu.Lock()
	defer ae.stream_mu.Unlock()

	stream, exists := ae.stream_states[request_id]
	if !exists {
		return false
	}

	stream.resume()
	return true
}

func (ae async_engine*) get_backpressure_status() bool {
	return ae.request_queue.is_backpressured()
}

func (ae async_engine*) get_queue_size() int32 {
	return ae.request_queue.get_queue_size()
}

func (ae async_engine*) update_statistics(result async_generation_result) {
	ae.stats.total_requests++

	if result.error_code == 0 {
		ae.stats.successful_requests++
	} else {
		ae.stats.failed_requests++
	}

	ae.stats.total_generation_time += result.latency_ms
	ae.stats.avg_generation_time_ms = float32(ae.stats.total_generation_time) / float32(ae.stats.total_requests)
}

func (ae async_engine*) get_statistics() engine_statistics {
	ae.stats.last_update_time = time.Now().UnixNano()
	ae.stats.active_streams = int32(len(ae.stream_states))
	return ae.stats
}

func (ae async_engine*) is_backpressured() bool {
	return ae.request_queue.is_backpressured()
}

func (ae async_engine*) get_connection_metrics() connection_metrics {
	return ae.connection_pool.get_metrics()
}

func (ae async_engine*) register_connection(
	connection_id string,
	client_id string,
	remote_addr string,
	local_addr string,
) connection_info {
	return ae.connection_pool.register_connection(
		connection_id, client_id, remote_addr, local_addr,
	)
}

func (ae async_engine*) close_connection(connection_id string) bool {
	return ae.connection_pool.close_connection(connection_id)
}

func (ae async_engine*) shutdown(timeout_ms int64) {
	ae.shutdown_signal = true
	ae.is_running = false

	if ae.connection_monitor != nil {
		ae.connection_monitor.stop()
	}

	ae.executor.shutdown(timeout_ms)
}

func (ae async_engine*) get_engine_config() async_engine_config {
	return ae.config
}

func (ae async_engine*) update_config(new_config async_engine_config) bool {
	if ae.is_running {
		ae.request_queue.capacity = new_config.max_queue_capacity
		ae.executor.max_concurrent = new_config.max_concurrent_tasks
	}
	ae.config = new_config
	return true
}

func (ae async_engine*) export_metrics_json() string {
	stats := ae.get_statistics()
	queue_stats := ae.request_queue.get_statistics()
	conn_metrics := ae.get_connection_metrics()

	metrics := map[string]interface{}{
		"engine": map[string]interface{}{
			"total_requests": stats.total_requests,
			"successful": stats.successful_requests,
			"failed": stats.failed_requests,
			"avg_latency_ms": stats.avg_generation_time_ms,
		},
		"queue": map[string]interface{}{
			"capacity": ae.request_queue.capacity,
			"size": ae.request_queue.current_load,
			"backpressured": ae.request_queue.is_backpressure,
			"backpressure_hits": queue_stats.backpressure_hits,
		},
		"connections": map[string]interface{}{
			"active": conn_metrics.active_connections,
			"total_connections": conn_metrics.total_connections,
			"bytes_sent": conn_metrics.total_bytes_sent,
			"bytes_received": conn_metrics.total_bytes_received,
		},
	}

	return json.Marshal(metrics)
}
