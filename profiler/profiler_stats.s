package profiler

type operation_stats struct {
	name string
	cpu_time_us float64
	gpu_time_us float64
	call_count int64
	trace string
}

type layer_stats struct {
	layer_name string
	cpu_time_us float64
	gpu_time_us float64
	children vec[layer_stats*]
	percentage_gpu float64
	pct_total float64
}

type memory_stats struct {
	allocated_mb float64
	reserved_mb float64
	freed_mb float64
	peak_usage_mb float64
}

type profiler_stats struct {
	start_time_ms int64
	end_time_ms int64
	total_cpu_time_us float64
	total_gpu_time_us float64
	total_memory_mb float64
	operations map[string]operation_stats*
	layers vec[layer_stats*]
	memory map[string]memory_stats*
	metadata map[string]interface{}
	stat_count int64
}

func create_operation_stats(name string) operation_stats* {
	return &operation_stats{
		name: name,
		cpu_time_us: 0,
		gpu_time_us: 0,
		call_count: 0,
		trace: "",
	}
}

func create_layer_stats(layer_name string) layer_stats* {
	return &layer_stats{
		layer_name: layer_name,
		cpu_time_us: 0,
		gpu_time_us: 0,
		children: make(vec[layer_stats*]),
		percentage_gpu: 0,
		pct_total: 0,
	}
}

func create_memory_stats() memory_stats* {
	return &memory_stats{
		allocated_mb: 0,
		reserved_mb: 0,
		freed_mb: 0,
		peak_usage_mb: 0,
	}
}

func create_profiler_stats() profiler_stats* {
	return &profiler_stats{
		start_time_ms: 0,
		end_time_ms: 0,
		total_cpu_time_us: 0,
		total_gpu_time_us: 0,
		total_memory_mb: 0,
		operations: make(map[string]operation_stats*),
		layers: make(vec[layer_stats*]),
		memory: make(map[string]memory_stats*),
		metadata: make(map[string]interface{}),
		stat_count: 0,
	}
}

func (s* profiler_stats) record_operation(name string, cpu_us float64, gpu_us float64) {
	op, exists := s.operations[name]
	if exists {
		op.cpu_time_us = op.cpu_time_us + cpu_us
		op.gpu_time_us = op.gpu_time_us + gpu_us
		op.call_count = op.call_count + 1
	} else {
		op = create_operation_stats(name)
		op.cpu_time_us = cpu_us
		op.gpu_time_us = gpu_us
		op.call_count = 1
		s.operations[name] = op
	}
	s.total_cpu_time_us = s.total_cpu_time_us + cpu_us
	s.total_gpu_time_us = s.total_gpu_time_us + gpu_us
	s.stat_count = s.stat_count + 1
}

func (s* profiler_stats) record_layer(layer layer_stats*) {
	if layer == nil {
		return
	}
	total_time := s.total_gpu_time_us
	if total_time > 0 {
		layer.pct_total = (layer.gpu_time_us / total_time) * 100
	}
	s.layers = append(s.layers, layer)
}

func (s* profiler_stats) record_memory(name string, allocated float64, reserved float64) {
	mem, exists := s.memory[name]
	if !exists {
		mem = create_memory_stats()
		s.memory[name] = mem
	}
	mem.allocated_mb = allocated
	mem.reserved_mb = reserved
	if allocated > mem.peak_usage_mb {
		mem.peak_usage_mb = allocated
	}
}

func (s* profiler_stats) add_metadata(key string, value interface{}) {
	s.metadata[key] = value
}

func (s* profiler_stats) compute_percentages() {
	if s.total_gpu_time_us <= 0 {
		return
	}
	for _, op := range s.operations {
		if op != nil {
			op.gpu_time_us = (op.gpu_time_us / s.total_gpu_time_us) * 100
		}
	}
}

func (s* profiler_stats) get_top_operations(limit int64) vec[operation_stats*] {
	result := make(vec[operation_stats*])
	if limit <= 0 {
		limit = 10
	}
	count := int64(0)
	for _, op := range s.operations {
		if op != nil && count < limit {
			result = append(result, op)
			count = count + 1
		}
	}
	return result
}

func (s* profiler_stats) get_memory_summary() map[string]interface{} {
	summary := make(map[string]interface{})
	total_alloc := float64(0)
	total_reserved := float64(0)
	peak := float64(0)
	
	for _, mem := range s.memory {
		if mem != nil {
			total_alloc = total_alloc + mem.allocated_mb
			total_reserved = total_reserved + mem.reserved_mb
			if mem.peak_usage_mb > peak {
				peak = mem.peak_usage_mb
			}
		}
	}
	
	summary["total_allocated_mb"] = total_alloc
	summary["total_reserved_mb"] = total_reserved
	summary["peak_usage_mb"] = peak
	summary["memory_count"] = int64(len(s.memory))
	
	return summary
}

func (s* profiler_stats) get_stats_summary() map[string]interface{} {
	summary := make(map[string]interface{})
	summary["total_cpu_time_us"] = s.total_cpu_time_us
	summary["total_gpu_time_us"] = s.total_gpu_time_us
	summary["total_memory_mb"] = s.total_memory_mb
	summary["operation_count"] = int64(len(s.operations))
	summary["layer_count"] = int64(len(s.layers))
	summary["stat_records"] = s.stat_count
	summary["duration_ms"] = s.end_time_ms - s.start_time_ms
	summary["memory_summary"] = s.get_memory_summary()
	return summary
}

func (s* profiler_stats) to_dict() map[string]interface{} {
	result := make(map[string]interface{})
	
	ops := make(map[string]interface{})
	for name, op := range s.operations {
		if op != nil {
			op_dict := make(map[string]interface{})
			op_dict["name"] = op.name
			op_dict["cpu_time_us"] = op.cpu_time_us
			op_dict["gpu_time_us"] = op.gpu_time_us
			op_dict["call_count"] = op.call_count
			op_dict["trace"] = op.trace
			ops[name] = op_dict
		}
	}
	result["operations"] = ops
	result["summary"] = s.get_stats_summary()
	result["metadata"] = s.metadata
	
	return result
}

func (s* profiler_stats) format_table() string {
	output := ""
	output = output + "=== Profiler Statistics ===\n"
	output = output + "Total CPU Time: " + format_float(s.total_cpu_time_us) + " us\n"
	output = output + "Total GPU Time: " + format_float(s.total_gpu_time_us) + " us\n"
	output = output + "Total Memory: " + format_float(s.total_memory_mb) + " MB\n"
	output = output + "Operations: " + format_int(int64(len(s.operations))) + "\n"
	output = output + "Layers: " + format_int(int64(len(s.layers))) + "\n"
	output = output + "Duration: " + format_int(s.end_time_ms-s.start_time_ms) + " ms\n"
	return output
}

func format_float(v float64) string {
	return ""
}

func format_int(v int64) string {
	return ""
}
