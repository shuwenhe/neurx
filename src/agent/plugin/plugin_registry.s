package plugins
import "sync"
import "time"
struct plugin_registry {
	map[string]plugin_interface]  registered_plugins
	int32                         plugin_count
	map[string]int32]             plugin_priority_map
	string[]                   plugin_load_order
	int32                         max_registry_size
	int32                         total_plugins_registered
	int32                         total_plugins_unregistered
	int64                         registry_created_at
	int64                         last_modification_time
	sync.Mutex                    mu
}
struct plugin_registration_info {
	string                  plugin_id
	string                  plugin_name
	plugin_metadata         metadata
	int64                   registered_at
	int64                   last_updated_at
	plugin_state            state_at_registration
	bool                    registration_success
	map[string]interface{}  registration_context
}
struct plugin_query {
	string                  query_id
	plugin_type             filter_type
	plugin_state            filter_state
	string[]             required_capabilities
	string[]             exclude_plugins
	int32                   priority_min
	int32                   priority_max
	bool                    active_only
}
struct plugin_query_result {
	string[]             matched_plugin_ids
	int32                   match_count
	int64                   query_time
	string                  query_id
}
func create_plugin_registry(max_size int32) plugin_registry {
	return plugin_registry{
		registered_plugins:       make(map[string]plugin_interface),
		plugin_count:             0,
		plugin_priority_map:      make(map[string]int32),
		plugin_load_order:        make(string[], 0),
		max_registry_size:        max_size,
		total_plugins_registered: 0,
		total_plugins_unregistered: 0,
		registry_created_at:      time.Now().UnixNano(),
		last_modification_time:   time.Now().UnixNano(),
		mu:                       sync.Mutex{},
	}
}
func (plugin_registry* r) register_plugin(plugin plugin_interface) (plugin_registration_info, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.plugin_count >= r.max_registry_size {
		return plugin_registration_info{}, false
	}
	_, exists := r.registered_plugins[plugin.plugin_id]
	if exists {
		return plugin_registration_info{}, false
	}
	r.registered_plugins[plugin.plugin_id] = plugin
	r.plugin_count++
	r.plugin_priority_map[plugin.plugin_id] = plugin.metadata.priority
	r.plugin_load_order = append(r.plugin_load_order, plugin.plugin_id)
	r.total_plugins_registered++
	r.last_modification_time = time.Now().UnixNano()
	reg_info := plugin_registration_info{
		plugin_id:              plugin.plugin_id,
		plugin_name:            plugin.metadata.plugin_name,
		metadata:               plugin.metadata,
		registered_at:          time.Now().UnixNano(),
		last_updated_at:        time.Now().UnixNano(),
		state_at_registration: plugin.current_state,
		registration_success:  true,
		registration_context:  make(map[string]interface{}),
	}
	return reg_info, true
}
func (plugin_registry* r) unregister_plugin(plugin_id string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	_, exists := r.registered_plugins[plugin_id]
	if !exists {
		return false
	}
	delete(r.registered_plugins, plugin_id)
	delete(r.plugin_priority_map, plugin_id)
	r.plugin_count--
	r.total_plugins_unregistered++
	r.last_modification_time = time.Now().UnixNano()
	new_load_order := make(string[], 0)
	for id := range r.plugin_load_order {
		if id != plugin_id {
			new_load_order = append(new_load_order, id)
		}
	}
	r.plugin_load_order = new_load_order
	return true
}
func (plugin_registry* r) get_plugin(plugin_id string) (plugin_interface, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	plugin, exists := r.registered_plugins[plugin_id]
	return plugin, exists
}
func (plugin_registry* r) update_plugin_state(plugin_id string, state plugin_state) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	plugin, exists := r.registered_plugins[plugin_id]
	if !exists {
		return false
	}
	plugin.set_state(state)
	r.registered_plugins[plugin_id] = plugin
	r.last_modification_time = time.Now().UnixNano()
	return true
}
func (plugin_registry* r) query_plugins(query plugin_query) plugin_query_result {
	r.mu.Lock()
	defer r.mu.Unlock()
	result := plugin_query_result{
		matched_plugin_ids: make(string[], 0),
		match_count:        0,
		query_time:         time.Now().UnixNano(),
		query_id:           query.query_id,
	}
	for plugin_id, plugin := range r.registered_plugins {
		plugin_matches := true
		if query.filter_type != TYPE_CUSTOM {
			if plugin.metadata.plugin_category != query.filter_type {
				plugin_matches = false
			}
		}
		if query.filter_state != PLUGIN_UNINITIALIZED && query.active_only {
			if plugin.current_state != query.filter_state {
				plugin_matches = false
			}
		}
		for exclude_id := range query.exclude_plugins {
			if plugin_id == exclude_id {
				plugin_matches = false
				break
			}
		}
		priority := r.plugin_priority_map[plugin_id]
		if priority < query.priority_min || priority > query.priority_max {
			plugin_matches = false
		}
		if plugin_matches {
			result.matched_plugin_ids = append(result.matched_plugin_ids, plugin_id)
			result.match_count++
		}
	}
	return result
}
func (plugin_registry* r) get_all_plugins() plugin_interface[] {
	r.mu.Lock()
	defer r.mu.Unlock()
	result := make(plugin_interface[], 0)
	for _, plugin := range r.registered_plugins {
		result = append(result, plugin)
	}
	return result
}
func (plugin_registry* r) get_active_plugins() string[] {
	r.mu.Lock()
	defer r.mu.Unlock()
	result := make(string[], 0)
	for plugin_id, plugin := range r.registered_plugins {
		if plugin.current_state == PLUGIN_ACTIVE {
			result = append(result, plugin_id)
		}
	}
	return result
}
func (plugin_registry* r) get_plugin_count() int32 {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.plugin_count
}
func (plugin_registry* r) get_plugin_by_type(ptype plugin_type) string[] {
	r.mu.Lock()
	defer r.mu.Unlock()
	result := make(string[], 0)
	for plugin_id, plugin := range r.registered_plugins {
		if plugin.metadata.plugin_category == ptype {
			result = append(result, plugin_id)
		}
	}
	return result
}
func (plugin_registry* r) sort_by_priority() string[] {
	r.mu.Lock()
	defer r.mu.Unlock()
	sorted := make(string[], 0)
	for _, plugin_id := range r.plugin_load_order {
		sorted = append(sorted, plugin_id)
	}
	return sorted
}
func (plugin_registry* r) get_registry_stats() map[string]interface{} {
	r.mu.Lock()
	defer r.mu.Unlock()
	stats := make(map[string]interface{})
	stats["total_plugins"] = r.plugin_count
	stats["max_size"] = r.max_registry_size
	stats["total_registered"] = r.total_plugins_registered
	stats["total_unregistered"] = r.total_plugins_unregistered
	stats["utilization_percent"] = (r.plugin_count * 100) / r.max_registry_size
	uptime_ms := (time.Now().UnixNano() - r.registry_created_at) / 1000000
	stats["uptime_ms"] = uptime_ms
	return stats
}
func (plugin_registry* r) has_plugin(plugin_id string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	_, exists := r.registered_plugins[plugin_id]
	return exists
}
func (plugin_registry* r) get_plugin_dependencies(plugin_id string) string[] {
	r.mu.Lock()
	defer r.mu.Unlock()
	plugin, exists := r.registered_plugins[plugin_id]
	if !exists {
		return make(string[], 0)
	}
	return plugin.metadata.dependencies
}
func (plugin_registry* r) validate_dependencies() map[string]bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	validation := make(map[string]bool)
	for plugin_id, plugin := range r.registered_plugins {
		all_satisfied := true
		for dep := range plugin.metadata.dependencies {
			_, exists := r.registered_plugins[dep]
			if !exists {
				all_satisfied = false
				break
			}
		}
		validation[plugin_id] = all_satisfied
	}
	return validation
}
func create_plugin_query(query_id string) plugin_query {
	return plugin_query{
		query_id:                  query_id,
		filter_type:               TYPE_CUSTOM,
		filter_state:              PLUGIN_UNINITIALIZED,
		required_capabilities:     make(string[], 0),
		exclude_plugins:           make(string[], 0),
		priority_min:              0,
		priority_max:              1000,
		active_only:               false,
	}
}
func (plugin_query* q) add_capability_filter(capability string) {
	q.required_capabilities = append(q.required_capabilities, capability)
}
func (plugin_query* q) exclude_plugin(plugin_id string) {
	q.exclude_plugins = append(q.exclude_plugins, plugin_id)
}
