package plugins
import "sync"
import "time"
struct plugin_system {
	plugin_loader              loader
	plugin_registry            registry
	plugin_lifecycle_manager   lifecycle
	config_manager             config_mgr
	message_router             message_router_inst
	int32                      max_concurrent_plugins
	int32                      plugin_timeout_ms
	int64                      system_start_time
	int32                       total_plugins_loaded
	int32                       total_plugins_started
	int32                       total_plugins_failed
	map[string]plugin_interface]  plugin_instances
	sync.Mutex                 mu
}

struct plugin_execution_context {
	string                  execution_id
	string                  plugin_id
	int64                   execution_start_time
	int64                   execution_end_time
	int32                   execution_status_code
	string                  execution_result
	map[string]interface{}  execution_data
	string[]             execution_logs
	int32                   log_count
}

struct plugin_system_health {
	int32                   active_plugins
	int32                   failed_plugins
	int32                   idle_plugins
	int32                   paused_plugins
	int32                   total_processed_requests
	int32                   total_failed_requests
	int64                   uptime_ms
	float64                 cpu_usage_percent
	int32                   memory_usage_mb
	string                  overall_health_status
}

func create_plugin_system(max_plugins int32) plugin_system {
	return plugin_system{
		loader:                create_plugin_loader("/app/shuwen/neurx/plugins", max_plugins),
		registry:              create_plugin_registry(max_plugins),
		lifecycle:             create_plugin_lifecycle_manager(1000),
		config_mgr:            create_config_manager(),
		message_router_inst:   create_message_router(),
		max_concurrent_plugins: max_plugins,
		plugin_timeout_ms:     30000,
		system_start_time:     time.Now().UnixNano(),
		total_plugins_loaded:  0,
		total_plugins_started: 0,
		total_plugins_failed:  0,
		plugin_instances:      make(map[string]plugin_interface),
		mu:                    sync.Mutex{},
	}
}

func (plugin_system* s) load_plugin(plugin_id string, plugin_path string, metadata plugin_metadata) (plugin_interface, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	pkg, load_ok := s.loader.load_plugin(plugin_id, plugin_path)
	if !load_ok {
		s.total_plugins_failed++
		return plugin_interface{}, false
	}
	plugin := create_plugin_interface(plugin_id, metadata)
	plugin.set_state(PLUGIN_LOADED)
	reg_info, reg_ok := s.registry.register_plugin(plugin)
	if !reg_ok {
		s.total_plugins_failed++
		return plugin_interface{}, false
	}
	s.plugin_instances[plugin_id] = plugin
	s.total_plugins_loaded++
	lifecycle_event := create_lifecycle_event(EVENT_LOADED, plugin_id)
	lifecycle_event.plugin_name = metadata.plugin_name
	s.lifecycle.emit_lifecycle_event(lifecycle_event)
	_ = reg_info
	_ = pkg
	return plugin, true
}

func (plugin_system* s) initialize_plugin(plugin_id string, config plugin_config) bool {
	s.mu.Lock()
	plugin, exists := s.plugin_instances[plugin_id]
	if !exists {
		s.mu.Unlock()
		return false
	}
	config_ok := s.config_mgr.activate_config(config.config_id)
	if !config_ok {
		s.mu.Unlock()
		s.total_plugins_failed++
		return false
	}
	plugin.set_state(PLUGIN_INITIALIZED)
	s.plugin_instances[plugin_id] = plugin
	s.mu.Unlock()
	lifecycle_event := create_lifecycle_event(EVENT_INITIALIZED, plugin_id)
	s.lifecycle.emit_lifecycle_event(lifecycle_event)
	return true
}

func (plugin_system* s) start_plugin(plugin_id string) bool {
	s.mu.Lock()
	plugin, exists := s.plugin_instances[plugin_id]
	if !exists {
		s.mu.Unlock()
		return false
	}
	if plugin.current_state != PLUGIN_INITIALIZED {
		s.mu.Unlock()
		return false
	}
	plugin.set_state(PLUGIN_ACTIVE)
	s.plugin_instances[plugin_id] = plugin
	s.total_plugins_started++
	s.mu.Unlock()
	lifecycle_event := create_lifecycle_event(EVENT_STARTED, plugin_id)
	lifecycle_event.plugin_name = plugin.metadata.plugin_name
	s.lifecycle.emit_lifecycle_event(lifecycle_event)
	return true
}

func (plugin_system* s) stop_plugin(plugin_id string) bool {
	s.mu.Lock()
	plugin, exists := s.plugin_instances[plugin_id]
	if !exists {
		s.mu.Unlock()
		return false
	}
	plugin.set_state(PLUGIN_STOPPED)
	s.plugin_instances[plugin_id] = plugin
	s.mu.Unlock()
	lifecycle_event := create_lifecycle_event(EVENT_STOPPED, plugin_id)
	s.lifecycle.emit_lifecycle_event(lifecycle_event)
	return true
}

func (plugin_system* s) unload_plugin(plugin_id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, exists := s.plugin_instances[plugin_id]
	if !exists {
		return false
	}
	s.loader.unload_plugin(plugin_id)
	s.registry.unregister_plugin(plugin_id)
	delete(s.plugin_instances, plugin_id)
	return true
}

func (plugin_system* s) send_message_to_plugin(message plugin_message) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	receiver, exists := s.plugin_instances[message.receiver_plugin_id]
	if !exists {
		return false
	}
	if receiver.current_state != PLUGIN_ACTIVE {
		return false
	}
	return s.message_router_inst.route_message(message)
}

func (plugin_system* s) get_plugin_status(plugin_id string) (plugin_interface, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	plugin, exists := s.plugin_instances[plugin_id]
	return plugin, exists
}

func (plugin_system* s) get_system_health() plugin_system_health {
	s.mu.Lock()
	defer s.mu.Unlock()
	health := plugin_system_health{
		active_plugins:         0,
		failed_plugins:         0,
		idle_plugins:           0,
		paused_plugins:         0,
		total_processed_requests: 0,
		total_failed_requests:  0,
		uptime_ms:              (time.Now().UnixNano() - s.system_start_time) / 1000000,
		cpu_usage_percent:      0.0,
		memory_usage_mb:        0,
		overall_health_status:  "healthy",
	}
	for _, plugin := range s.plugin_instances {
		switch plugin.current_state {
		case PLUGIN_ACTIVE:
			health.active_plugins++
		case PLUGIN_ERROR:
			health.failed_plugins++
		case PLUGIN_PAUSED:
			health.paused_plugins++
		default:
			health.idle_plugins++
		}
	}
	if health.failed_plugins > 0 {
		health.overall_health_status = "degraded"
	}
	if health.failed_plugins > int32(len(s.plugin_instances))/2 {
		health.overall_health_status = "critical"
	}
	return health
}

func (plugin_system* s) get_system_stats() map[string]interface{} {
	s.mu.Lock()
	defer s.mu.Unlock()
	stats := make(map[string]interface{})
	stats["total_plugins_loaded"] = s.total_plugins_loaded
	stats["total_plugins_started"] = s.total_plugins_started
	stats["total_plugins_failed"] = s.total_plugins_failed
	stats["current_plugins"] = int32(len(s.plugin_instances))
	loader_stats := s.loader.get_loader_stats()
	stats["loader_stats"] = loader_stats
	registry_stats := s.registry.get_registry_stats()
	stats["registry_stats"] = registry_stats
	uptime_ms := (time.Now().UnixNano() - s.system_start_time) / 1000000
	stats["system_uptime_ms"] = uptime_ms
	return stats
}

func create_plugin_execution_context(exec_id string, plugin_id string) plugin_execution_context {
	return plugin_execution_context{
		execution_id:           exec_id,
		plugin_id:              plugin_id,
		execution_start_time:   time.Now().UnixNano(),
		execution_end_time:     0,
		execution_status_code:  0,
		execution_result:       "",
		execution_data:         make(map[string]interface{}),
		execution_logs:         make(string[], 0),
		log_count:              0,
	}
}

func (plugin_execution_context* c) add_log_entry(log_entry string) {
	c.execution_logs = append(c.execution_logs, log_entry)
	c.log_count++
}

func (plugin_execution_context* c) mark_complete(status_code int32, result string) {
	c.execution_end_time = time.Now().UnixNano()
	c.execution_status_code = status_code
	c.execution_result = result
}

func (plugin_execution_context* c) get_duration_ms() int64 {
	if c.execution_end_time == 0 {
		return (time.Now().UnixNano() - c.execution_start_time) / 1000000
	}
	return (c.execution_end_time - c.execution_start_time) / 1000000
}

func (plugin_system* s) get_all_plugin_states() map[string]plugin_state {
	s.mu.Lock()
	defer s.mu.Unlock()
	states := make(map[string]plugin_state)
	for plugin_id, plugin := range s.plugin_instances {
		states[plugin_id] = plugin.current_state
	}
	return states
}

func (plugin_system* s) pause_plugin(plugin_id string) bool {
	s.mu.Lock()
	plugin, exists := s.plugin_instances[plugin_id]
	if !exists {
		s.mu.Unlock()
		return false
	}
	if plugin.current_state != PLUGIN_ACTIVE {
		s.mu.Unlock()
		return false
	}
	plugin.set_state(PLUGIN_PAUSED)
	s.plugin_instances[plugin_id] = plugin
	s.mu.Unlock()
	lifecycle_event := create_lifecycle_event(EVENT_PAUSED, plugin_id)
	s.lifecycle.emit_lifecycle_event(lifecycle_event)
	return true
}

func (plugin_system* s) resume_plugin(plugin_id string) bool {
	s.mu.Lock()
	plugin, exists := s.plugin_instances[plugin_id]
	if !exists {
		s.mu.Unlock()
		return false
	}
	if plugin.current_state != PLUGIN_PAUSED {
		s.mu.Unlock()
		return false
	}
	plugin.set_state(PLUGIN_ACTIVE)
	s.plugin_instances[plugin_id] = plugin
	s.mu.Unlock()
	lifecycle_event := create_lifecycle_event(EVENT_RESUMED, plugin_id)
	s.lifecycle.emit_lifecycle_event(lifecycle_event)
	return true
}
