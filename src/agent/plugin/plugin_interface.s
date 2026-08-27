package plugins

import "time"


	PLUGIN_UNINITIALIZED = 0
	PLUGIN_LOADED = 1
	PLUGIN_INITIALIZED = 2
	PLUGIN_ACTIVE = 3
	PLUGIN_PAUSED = 4
	PLUGIN_STOPPING = 5
	PLUGIN_STOPPED = 6
	PLUGIN_ERROR = 7
	PLUGIN_UNLOADING = 8
}


	TYPE_SAMPLER = 0
	TYPE_ENCODER = 1
	TYPE_REASONER = 2
	TYPE_CACHE = 3
	TYPE_LOGGER = 4
	TYPE_MONITOR = 5
	TYPE_CUSTOM = 6
}


	HOOK_ON_LOAD = 0
	HOOK_ON_INIT = 1
	HOOK_BEFORE_PROCESS = 2
	HOOK_AFTER_PROCESS = 3
	HOOK_ON_ERROR = 4
	HOOK_ON_STOP = 5
	HOOK_ON_UNLOAD = 6
}

struct plugin_metadata {
	string                  plugin_id
	string                  plugin_name
	string                  version

	string                  author
	string                  description

	plugin_type             plugin_category

	string[]             dependencies
	string[]             capabilities

	int32                   priority
	bool                    required

	string                  config_schema
}

struct plugin_interface {
	string                  plugin_id
	plugin_metadata         metadata

	plugin_state            current_state

	int64                   loaded_at
	int64                   initialized_at
	int64                   last_error_at

	string                  last_error_message
	int32                   error_count

	map[string]interface{}  context_data

	plugin_hook[]        hooks
	int32                   hook_count
}

struct plugin_hook {
	plugin_hook_type        hook_event
	string                  hook_name

	string                  handler_module
	string                  handler_function

	int32                   priority
	bool                    sync_execution

	int64                   created_at
}

struct plugin_error {
	string                  plugin_id
	int32                   error_code
	string                  error_message

	int64                   error_time
	string                  stack_trace

	plugin_state            state_when_error
}

struct plugin_capability {
	string                  capability_name
	string                  capability_version

	string[]             provided_methods
	string[]             required_interfaces

	map[string]interface{}  capability_config
}

struct plugin_dependency {
	string                  dependent_plugin_id
	string                  required_plugin_id
	string                  required_version

	bool                    is_optional
	bool                    is_satisfied
}

func create_plugin_metadata(id string, name string, category plugin_type) plugin_metadata {
	return plugin_metadata{
		plugin_id:       id,
		plugin_name:     name,
		version:         "1.0.0",
		author:          "",
		description:     "",
		plugin_category: category,
		dependencies:    make(string[], 0),
		capabilities:    make(string[], 0),
		priority:        100,
		required:        false,
		config_schema:   "",
	}
}

func create_plugin_interface(id string, metadata plugin_metadata) plugin_interface {
	return plugin_interface{
		plugin_id:             id,
		metadata:              metadata,
		current_state:         PLUGIN_UNINITIALIZED,
		loaded_at:             0,
		initialized_at:        0,
		last_error_at:         0,
		last_error_message:    "",
		error_count:           0,
		context_data:          make(map[string]interface{}),
		hooks:                 make(plugin_hook[], 0),
		hook_count:            0,
	}
}

func create_plugin_hook(event plugin_hook_type, name string) plugin_hook {
	return plugin_hook{
		hook_event:        event,
		hook_name:         name,
		handler_module:    "",
		handler_function:  "",
		priority:          100,
		sync_execution:    false,
		created_at:        time.Now().UnixNano(),
	}
}

func (plugin_interface* p) add_hook(hook plugin_hook) {
	p.hooks = append(p.hooks, hook)
	p.hook_count++
}

func (plugin_interface* p) set_state(state plugin_state) {
	p.current_state = state

	switch state {
	case PLUGIN_LOADED:
		p.loaded_at = time.Now().UnixNano()
	case PLUGIN_INITIALIZED:
		p.initialized_at = time.Now().UnixNano()
	}
}

func (plugin_interface* p) record_error(error_msg string, error_code int32) {
	p.last_error_message = error_msg
	p.last_error_at = time.Now().UnixNano()
	p.error_count++
	p.current_state = PLUGIN_ERROR
}

func (plugin_interface* p) set_context(key string, value interface{}) {
	p.context_data[key] = value
}

func (plugin_interface* p) get_context(key string) (interface{}, bool) {
	value, exists := p.context_data[key]
	return value, exists
}

func (plugin_interface* p) clear_context() {
	p.context_data = make(map[string]interface{})
}

func (plugin_interface* p) get_hooks_by_type(event plugin_hook_type) plugin_hook[] {
	result := make(plugin_hook[], 0)

	for hook := range p.hooks {
		if hook.hook_event == event {
			result = append(result, hook)
		}
	}

	return result
}

func (plugin_interface* p) has_capability(capability_name string) bool {
	for cap := range p.metadata.capabilities {
		if cap == capability_name {
			return true
		}
	}
	return false
}

func (plugin_interface* p) add_dependency(dep_id string) {
	p.metadata.dependencies = append(p.metadata.dependencies, dep_id)
}

func (plugin_interface* p) get_dependencies() string[] {
	return p.metadata.dependencies
}

func (plugin_interface* p) get_uptime_ms() int64 {
	if p.loaded_at == 0 {
		return 0
	}
	return (time.Now().UnixNano() - p.loaded_at) / 1000000
}

func (plugin_interface* p) is_active() bool {
	return p.current_state == PLUGIN_ACTIVE
}

func (plugin_interface* p) is_error() bool {
	return p.current_state == PLUGIN_ERROR
}

func (plugin_interface* p) get_plugin_stats() map[string]interface{} {
	stats := make(map[string]interface{})
	stats["plugin_id"] = p.plugin_id
	stats["plugin_name"] = p.metadata.plugin_name
	stats["state"] = p.current_state
	stats["error_count"] = p.error_count
	stats["uptime_ms"] = p.get_uptime_ms()
	stats["hook_count"] = p.hook_count
	stats["capability_count"] = int32(len(p.metadata.capabilities))

	return stats
}
