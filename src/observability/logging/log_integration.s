package neurx.observability.logging

import "sync"
import "time"
import "encoding/json"

struct logging_system {
	structured_logger* logger
	log_collector*     collector

	metrics_registry*  metrics

	vec[distributed_trace] traces
	int32              trace_count
	int32              max_traces

	map[string]string  component_mapping

	string             system_name
	string             system_version

	int64              startup_time
	int32              total_requests_processed
	int32              total_errors_encountered

	sync.Mutex         mu
}

struct logging_config {
	string             system_name
	string             system_version
	int32              max_entries_per_logger
	int32              flush_interval_ms
	int32              max_traces_retained
}

func create_logging_system(config logging_config) logging_system {
	logger_cfg := logger_config{
		name:                 config.system_name,
		min_level:            DEBUG,
		max_entries:          config.max_entries_per_logger,
		flush_interval_ms:    config.flush_interval_ms,
	}

	logger := create_structured_logger(logger_cfg)
	collector := create_log_collector()
	metrics := create_metrics_registry()

	return logging_system{
		logger:                      *logger,
		collector:                   *collector,
		metrics:                     *metrics,
		traces:                      make(vec[distributed_trace], 0, config.max_traces_retained),
		trace_count:                 0,
		max_traces:                  config.max_traces_retained,
		component_mapping:           make(map[string]string),
		system_name:                 config.system_name,
		system_version:              config.system_version,
		startup_time:                time.Now().UnixNano(),
		total_requests_processed:    0,
		total_errors_encountered:    0,
		mu:                          sync.Mutex{},
	}
}

func (logging_system* sys) log_api_request(request_id string, endpoint string, component string) {
	ctx := create_log_context(request_id, component)
	entry := create_log_entry()
	entry.message = "API request received: " + endpoint
	entry.component = component
	entry.trace_id = request_id
	entry.event_category = REQUEST_RECEIVED
	entry.level = INFO

	sys.logger.log_entry(entry)
	sys.metrics.increment_counter("api.requests.total")

	sys.mu.Lock()
	sys.total_requests_processed++
	sys.mu.Unlock()
}

func (logging_system* sys) log_reasoning_step(request_id string, step_number int32, reasoning_text string, confidence float32) {
	entry := create_log_entry()
	entry.message = "Reasoning step " + string(step_number) + " completed"
	entry.component = "reasoning"
	entry.trace_id = request_id
	entry.event_category = REASONING_STEP
	entry.level = DEBUG
	entry.confidence_score = confidence
	entry.add_field("step_number", step_number)
	entry.add_field("reasoning_text_length", int32(len(reasoning_text)))

	sys.logger.log_entry(entry)
	sys.metrics.record_observation("reasoning.step.confidence", confidence,
		map[string]string{"request_id": request_id})
}

func (logging_system* sys) log_sampling_execution(request_id string, method string, duration_ms int32, selected_index int32) {
	entry := create_log_entry()
	entry.message = "Sampling method " + method + " executed"
	entry.component = "sampling"
	entry.trace_id = request_id
	entry.event_category = SAMPLING_EXECUTED
	entry.level = DEBUG
	entry.duration_ms = duration_ms
	entry.add_field("method", method)
	entry.add_field("selected_index", selected_index)

	sys.logger.log_entry(entry)
	sys.metrics.record_histogram_value("sampling.execution_time_ms", float32(duration_ms))
}

func (logging_system* sys) log_async_processing(request_id string, queue_size int32, priority int32) {
	entry := create_log_entry()
	entry.message = "Async request queued"
	entry.component = "async_engine"
	entry.trace_id = request_id
	entry.event_category = PROCESSING_START
	entry.level = DEBUG
	entry.add_field("queue_size", queue_size)
	entry.add_field("priority", priority)

	sys.logger.log_entry(entry)
	sys.metrics.set_gauge("async.queue_size", float32(queue_size))
}

func (logging_system* sys) log_error_event(request_id string, component string, error_code int32, error_msg string) {
	entry := create_log_entry()
	entry.message = error_msg
	entry.component = component
	entry.trace_id = request_id
	entry.event_category = ERROR_OCCURRED
	entry.level = ERROR
	entry.error_code = error_code
	entry.error_message = error_msg

	sys.logger.log_entry(entry)
	sys.metrics.increment_counter("errors.total")

	sys.mu.Lock()
	sys.total_errors_encountered++
	sys.mu.Unlock()
}

func (logging_system* sys) start_trace(trace_id string) distributed_trace {
	trace := create_distributed_trace()
	trace.trace_id = trace_id

	sys.mu.Lock()
	sys.traces = append(sys.traces, trace)
	sys.trace_count++

	if sys.trace_count > sys.max_traces {
		sys.traces = sys.traces[1:]
		sys.trace_count = sys.max_traces
	}
	sys.mu.Unlock()

	return trace
}

func (logging_system* sys) end_trace(trace_id string) {
	sys.mu.Lock()
	defer sys.mu.Unlock()

	for i := int32(0); i < int32(len(sys.traces)); i++ {
		if sys.traces[i].trace_id == trace_id {
			sys.traces[i].end_trace()
			sys.metrics.record_histogram_value("trace.duration_ms", float32(sys.traces[i].total_duration_ms))
			break
		}
	}
}

func (logging_system* sys) flush_all() {
	sys.logger.flush_if_needed()
	sys.collector.collect_all()
}

func (logging_system* sys) get_system_health() map[string]interface{} {
	health := make(map[string]interface{})
	health["system_name"] = sys.system_name
	health["system_version"] = sys.system_version

	uptime_ms := (time.Now().UnixNano() - sys.startup_time) / 1000000
	health["uptime_ms"] = uptime_ms

	sys.mu.Lock()
	health["total_requests"] = sys.total_requests_processed
	health["total_errors"] = sys.total_errors_encountered
	health["active_traces"] = sys.trace_count
	sys.mu.Unlock()

	logger_stats := sys.logger.get_statistics()
	health["logger_stats"] = logger_stats

	collector_stats := sys.collector.get_collection_stats()
	health["collector_stats"] = map[string]interface{}{
		"total_entries":  collector_stats.total_entries,
		"total_errors":   collector_stats.total_errors,
		"total_batches":  collector_stats.total_batches,
	}

	metrics_stats := sys.metrics.get_statistics()
	health["metrics_stats"] = metrics_stats

	return health
}

func (logging_system* sys) export_as_json() string {
	sys.flush_all()

	entries := sys.collector.get_collected_entries()

	json_str := "{"
	json_str = json_str + "\"system\":\"" + sys.system_name + "\","
	json_str = json_str + "\"version\":\"" + sys.system_version + "\","
	json_str = json_str + "\"timestamp\":" + string(time.Now().Unix()) + ","
	json_str = json_str + "\"entry_count\":" + string(int32(len(entries))) + ","
	json_str = json_str + "\"traces\":" + string(sys.trace_count)
	json_str = json_str + "}"

	return json_str
}

func (logging_system* sys) clear_all_logs() {
	sys.logger.clear_all()
	sys.collector.clear()
	sys.traces = make(vec[distributed_trace], 0, sys.max_traces)
	sys.trace_count = 0
}

func (logging_system* sys) get_performance_summary() map[string]interface{} {
	summary := make(map[string]interface{})

	collector_stats := sys.collector.get_collection_stats()
	summary["total_log_entries"] = collector_stats.total_entries
	summary["total_errors"] = collector_stats.total_errors
	summary["errors_ratio"] = 0.0

	if collector_stats.total_entries > 0 {
		summary["errors_ratio"] = float32(collector_stats.total_errors) / float32(collector_stats.total_entries)
	}

	sys.mu.Lock()
	summary["total_requests"] = sys.total_requests_processed
	sys.mu.Unlock()

	metrics_stats := sys.metrics.get_statistics()
	summary["metrics_tracked"] = metrics_stats["total_metrics"]
	summary["metric_observations"] = metrics_stats["total_points"]

	return summary
}
