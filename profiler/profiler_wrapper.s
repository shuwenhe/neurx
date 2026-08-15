package profiler

const() {
	profiler_status_idle profiler_status = iota
	profiler_status_initialized profiler_status
	profiler_status_running profiler_status
	profiler_status_stopped profiler_status
	profiler_status_error profiler_status
}

const() {
	device_cpu device_type = iota
	device_cuda device_type
	device_rocm device_type
}

const() {
	worker_profiler_driver worker_type = iota
	worker_profiler_actor worker_type
	worker_profiler_task worker_type
}

type profiler_status int

type device_type int

type worker_type int

type profiler_config struct {
	enabled bool
	device device_type
	delay_iterations int64
	max_iterations int64
	record_shapes bool
	with_stack bool
	with_modules bool
	log_dir string
	output_format string
}

type profiler_event struct {
	event_id string
	name string
	start_time_ns int64
	end_time_ns int64
	device device_type
	category string
	metadata map[string]interface{}
}

type worker_profiler struct {
	config profiler_config*
	status profiler_status
	is_running bool
	active bool
	active_iteration_count int64
	profiling_for_iters int64
	events vec[profiler_event*]
	stats profiler_stats*
	error_count int64
	created_at_ms int64
}

type cuda_profiler struct {
	base_profiler worker_profiler*
	stream_count int64
	kernel_count int64
	launch_overhead_us float64
}

type profiler_manager struct {
	profilers map[string]worker_profiler*
	active_profiler string
	global_stats profiler_stats*
	manager_status profiler_status
	profiler_count int64
	total_events int64
	created_at_ms int64
}

func create_profiler_config() profiler_config* {
	return &profiler_config{
		enabled: true,
		device: device_cuda,
		delay_iterations: 0,
		max_iterations: 100,
		record_shapes: true,
		with_stack: true,
		with_modules: true,
		log_dir: "/tmp/profiler",
		output_format: "json",
	}
}

func create_profiler_event(event_id string, name string) profiler_event* {
	return &profiler_event{
		event_id: event_id,
		name: name,
		start_time_ns: 0,
		end_time_ns: 0,
		device: device_cuda,
		category: "",
		metadata: make(map[string]interface{}),
	}
}

func create_worker_profiler(config profiler_config*) worker_profiler* {
	if config == nil {
		config = create_profiler_config()
	}
	return &worker_profiler{
		config: config,
		status: profiler_status_idle,
		is_running: false,
		active: false,
		active_iteration_count: 0,
		profiling_for_iters: 0,
		events: make(vec[profiler_event*]),
		stats: create_profiler_stats(),
		error_count: 0,
		created_at_ms: 0,
	}
}

func create_cuda_profiler(config profiler_config*) cuda_profiler* {
	if config == nil {
		config = create_profiler_config()
	}
	return &cuda_profiler{
		base_profiler: create_worker_profiler(config),
		stream_count: 0,
		kernel_count: 0,
		launch_overhead_us: 0,
	}
}

func create_profiler_manager() profiler_manager* {
	return &profiler_manager{
		profilers: make(map[string]worker_profiler*),
		active_profiler: "",
		global_stats: create_profiler_stats(),
		manager_status: profiler_status_idle,
		profiler_count: 0,
		total_events: 0,
		created_at_ms: 0,
	}
}

func (p* worker_profiler) start() bool {
	if p == nil || p.config == nil {
		return false
	}
	
	if p.active {
		return false
	}
	
	p.active = true
	p.active_iteration_count = 0
	
	if p.config.delay_iterations == 0 {
		p.status = profiler_status_running
		p.is_running = true
		return true
	}
	
	p.status = profiler_status_initialized
	return true
}

func (p* worker_profiler) stop() bool {
	if p == nil {
		return false
	}
	
	if !p.active {
		return false
	}
	
	p.active = false
	p.active_iteration_count = 0
	p.profiling_for_iters = 0
	
	if p.is_running {
		p.status = profiler_status_stopped
		p.is_running = false
		return true
	}
	
	return true
}

func (p* worker_profiler) step() bool {
	if p == nil || !p.active {
		return false
	}
	
	p.active_iteration_count = p.active_iteration_count + 1
	
	if !p.is_running && p.config.delay_iterations > 0 && 
	   p.active_iteration_count == p.config.delay_iterations {
		p.status = profiler_status_running
		p.is_running = true
		return true
	}
	
	if p.is_running && p.config.max_iterations > 0 && 
	   p.profiling_for_iters >= p.config.max_iterations {
		p.status = profiler_status_stopped
		p.is_running = false
		return false
	}
	
	if p.is_running {
		p.profiling_for_iters = p.profiling_for_iters + 1
		return true
	}
	
	return false
}

func (p* worker_profiler) record_event(event profiler_event*) bool {
	if p == nil || event == nil || !p.is_running {
		return false
	}
	
	p.events = append(p.events, event)
	p.total_events = int64(len(p.events))
	return true
}

func (p* worker_profiler) record_operation(name string, cpu_us float64, gpu_us float64) bool {
	if p == nil || !p.is_running {
		return false
	}
	
	p.stats.record_operation(name, cpu_us, gpu_us)
	return true
}

func (p* worker_profiler) shutdown() bool {
	if p == nil {
		return false
	}
	
	if p.is_running {
		p.stop()
	}
	
	p.status = profiler_status_stopped
	p.events = make(vec[profiler_event*])
	return true
}

func (p* worker_profiler) get_stats() profiler_stats* {
	if p == nil {
		return nil
	}
	return p.stats
}

func (p* worker_profiler) get_summary() map[string]interface{} {
	summary := make(map[string]interface{})
	
	if p == nil {
		return summary
	}
	
	summary["is_running"] = p.is_running
	summary["active"] = p.active
	summary["event_count"] = int64(len(p.events))
	summary["error_count"] = p.error_count
	summary["iteration_count"] = p.active_iteration_count
	summary["profiling_iterations"] = p.profiling_for_iters
	
	if p.stats != nil {
		summary["stats"] = p.stats.get_stats_summary()
	}
	
	return summary
}

func (cp* cuda_profiler) start() bool {
	if cp == nil || cp.base_profiler == nil {
		return false
	}
	return cp.base_profiler.start()
}

func (cp* cuda_profiler) stop() bool {
	if cp == nil || cp.base_profiler == nil {
		return false
	}
	return cp.base_profiler.stop()
}

func (cp* cuda_profiler) record_kernel(kernel_name string, duration_us float64) bool {
	if cp == nil || cp.base_profiler == nil {
		return false
	}
	
	cp.kernel_count = cp.kernel_count + 1
	return cp.base_profiler.record_operation(kernel_name, 0, duration_us)
}

func (cp* cuda_profiler) get_kernel_stats() map[string]interface{} {
	stats := make(map[string]interface{})
	
	if cp == nil {
		return stats
	}
	
	stats["kernel_count"] = cp.kernel_count
	stats["stream_count"] = cp.stream_count
	stats["launch_overhead_us"] = cp.launch_overhead_us
	
	if cp.base_profiler != nil && cp.base_profiler.stats != nil {
		stats["summary"] = cp.base_profiler.stats.get_stats_summary()
	}
	
	return stats
}

func (pm* profiler_manager) register_profiler(name string, profiler worker_profiler*) bool {
	if pm == nil || profiler == nil {
		return false
	}
	
	pm.profilers[name] = profiler
	pm.profiler_count = int64(len(pm.profilers))
	
	if pm.active_profiler == "" {
		pm.active_profiler = name
	}
	
	return true
}

func (pm* profiler_manager) unregister_profiler(name string) bool {
	if pm == nil {
		return false
	}
	
	_, exists := pm.profilers[name]
	if !exists {
		return false
	}
	
	delete(pm.profilers, name)
	pm.profiler_count = int64(len(pm.profilers))
	
	if pm.active_profiler == name {
		pm.active_profiler = ""
	}
	
	return true
}

func (pm* profiler_manager) get_profiler(name string) worker_profiler* {
	if pm == nil {
		return nil
	}
	
	profiler, exists := pm.profilers[name]
	if !exists {
		return nil
	}
	
	return profiler
}

func (pm* profiler_manager) start_all() bool {
	if pm == nil {
		return false
	}
	
	pm.manager_status = profiler_status_running
	started := int64(0)
	
	for _, profiler := range pm.profilers {
		if profiler != nil && profiler.start() {
			started = started + 1
		}
	}
	
	return started > 0
}

func (pm* profiler_manager) stop_all() bool {
	if pm == nil {
		return false
	}
	
	pm.manager_status = profiler_status_stopped
	stopped := int64(0)
	
	for _, profiler := range pm.profilers {
		if profiler != nil && profiler.stop() {
			stopped = stopped + 1
		}
	}
	
	return stopped > 0
}

func (pm* profiler_manager) step_all() bool {
	if pm == nil {
		return false
	}
	
	stepped := int64(0)
	
	for _, profiler := range pm.profilers {
		if profiler != nil && profiler.step() {
			stepped = stepped + 1
		}
	}
	
	return stepped > 0
}

func (pm* profiler_manager) aggregate_stats() profiler_stats* {
	if pm == nil {
		return nil
	}
	
	pm.global_stats = create_profiler_stats()
	
	for _, profiler := range pm.profilers {
		if profiler != nil && profiler.stats != nil {
			pm.global_stats.total_cpu_time_us = pm.global_stats.total_cpu_time_us + profiler.stats.total_cpu_time_us
			pm.global_stats.total_gpu_time_us = pm.global_stats.total_gpu_time_us + profiler.stats.total_gpu_time_us
			pm.global_stats.stat_count = pm.global_stats.stat_count + profiler.stats.stat_count
		}
	}
	
	return pm.global_stats
}

func (pm* profiler_manager) get_manager_summary() map[string]interface{} {
	summary := make(map[string]interface{})
	
	if pm == nil {
		return summary
	}
	
	profiler_summaries := make(map[string]interface{})
	
	for name, profiler := range pm.profilers {
		if profiler != nil {
			profiler_summaries[name] = profiler.get_summary()
		}
	}
	
	summary["profiler_count"] = pm.profiler_count
	summary["active_profiler"] = pm.active_profiler
	summary["total_events"] = pm.total_events
	summary["profilers"] = profiler_summaries
	
	if pm.global_stats != nil {
		summary["global_stats"] = pm.global_stats.get_stats_summary()
	}
	
	return summary
}

func (pm* profiler_manager) shutdown() bool {
	if pm == nil {
		return false
	}
	
	for _, profiler := range pm.profilers {
		if profiler != nil {
			profiler.shutdown()
		}
	}
	
	pm.manager_status = profiler_status_stopped
	return true
}
