package plugins
import "time"
import "sync"
	LOADER_READY = 0
	LOADER_LOADING = 1
	LOADER_VALIDATING = 2
	LOADER_ERROR = 3
}

struct plugin_loader {
	string                  plugin_search_path
	string[]             loaded_plugin_paths
	int32                   max_plugins
	int32                   current_plugins_loaded
	loader_status           status
	map[string]string]      plugin_path_map
	int32                   total_load_attempts
	int32                   total_load_failures
	int32                   total_load_successes
	int64                   loader_start_time
	sync.Mutex              mu
}

struct plugin_package {
	string                  package_id
	string                  package_name
	string                  package_path
	string                  checksum
	plugin_metadata         metadata
	string[]             files
	int32                   file_count
	map[string]string]      file_content_map
	int64                   package_created_at
	int64                   package_size_bytes
}

struct plugin_descriptor {
	string                  descriptor_id
	string                  plugin_id
	string                  plugin_name
	string                  plugin_main_file
	string                  plugin_version
	string[]             required_modules
	string[]             exported_functions
	bool                    requires_config
	bool                    requires_init
	bool                    auto_start
	int32                   startup_timeout_ms
	int32                   shutdown_timeout_ms
}

struct load_validation_result {
	bool                    is_valid
	string[]             validation_errors
	int32                   error_count
	string                  validation_message
	int64                   validation_time
}

func create_plugin_loader(search_path string, max_plugins int32) plugin_loader {
	return plugin_loader{
		plugin_search_path:    search_path,
		loaded_plugin_paths:   make(string[], 0),
		max_plugins:           max_plugins,
		current_plugins_loaded: 0,
		status:                LOADER_READY,
		plugin_path_map:       make(map[string]string),
		total_load_attempts:   0,
		total_load_failures:   0,
		total_load_successes:  0,
		loader_start_time:     time.Now().UnixNano(),
		mu:                    sync.Mutex{},
	}
}

func create_plugin_package(id string, name string, path string) plugin_package {
	return plugin_package{
		package_id:          id,
		package_name:        name,
		package_path:        path,
		checksum:            "",
		metadata:            plugin_metadata{},
		files:               make(string[], 0),
		file_count:          0,
		file_content_map:    make(map[string]string),
		package_created_at:  time.Now().UnixNano(),
		package_size_bytes:  0,
	}
}

func create_plugin_descriptor(plugin_id string, name string) plugin_descriptor {
	return plugin_descriptor{
		descriptor_id:         "",
		plugin_id:             plugin_id,
		plugin_name:           name,
		plugin_main_file:      "",
		plugin_version:        "1.0.0",
		required_modules:      make(string[], 0),
		exported_functions:    make(string[], 0),
		requires_config:       false,
		requires_init:         true,
		auto_start:            false,
		startup_timeout_ms:    5000,
		shutdown_timeout_ms:   5000,
	}
}

func (plugin_loader* l) load_plugin(plugin_id string, plugin_path string) (plugin_package, bool) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.current_plugins_loaded >= l.max_plugins {
		return plugin_package{}, false
	}
	if l.status != LOADER_READY {
		return plugin_package{}, false
	}
	l.status = LOADER_LOADING
	l.total_load_attempts++
	pkg := create_plugin_package(plugin_id, plugin_id, plugin_path)
	l.loaded_plugin_paths = append(l.loaded_plugin_paths, plugin_path)
	l.plugin_path_map[plugin_id] = plugin_path
	l.current_plugins_loaded++
	l.total_load_successes++
	l.status = LOADER_READY
	return pkg, true
}

func (plugin_loader* l) unload_plugin(plugin_id string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	path, exists := l.plugin_path_map[plugin_id]
	if !exists {
		return false
	}
	delete(l.plugin_path_map, plugin_id)
	l.current_plugins_loaded--
	result_list := make(string[], 0)
	for p := range l.loaded_plugin_paths {
		if p != path {
			result_list = append(result_list, p)
		}
	}
	l.loaded_plugin_paths = result_list
	return true
}

func (plugin_loader* l) validate_plugin_package(pkg plugin_package) load_validation_result {
	result := load_validation_result{
		is_valid:            true,
		validation_errors:   make(string[], 0),
		error_count:         0,
		validation_message:  "",
		validation_time:     time.Now().UnixNano(),
	}
	if pkg.package_id == "" {
		result.is_valid = false
		result.validation_errors = append(result.validation_errors, "package_id_missing")
		result.error_count++
	}
	if pkg.package_path == "" {
		result.is_valid = false
		result.validation_errors = append(result.validation_errors, "package_path_missing")
		result.error_count++
	}
	if pkg.file_count == 0 {
		result.is_valid = false
		result.validation_errors = append(result.validation_errors, "no_files_in_package")
		result.error_count++
	}
	if result.is_valid {
		result.validation_message = "validation_passed"
	} else {
		result.validation_message = "validation_failed"
	}
	return result
}

func (plugin_loader* l) get_loaded_plugins() []string {
	l.mu.Lock()
	defer l.mu.Unlock()
	result := make(string[], 0)
	for plugin_id, _ := range l.plugin_path_map {
		result = append(result, plugin_id)
	}
	return result
}

func (plugin_loader* l) get_plugin_path(plugin_id string) (string, bool) {
	l.mu.Lock()
	defer l.mu.Unlock()
	path, exists := l.plugin_path_map[plugin_id]
	return path, exists
}

func (plugin_loader* l) register_plugin_path(plugin_id string, path string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	_, exists := l.plugin_path_map[plugin_id]
	if exists {
		return false
	}
	l.plugin_path_map[plugin_id] = path
	l.loaded_plugin_paths = append(l.loaded_plugin_paths, path)
	l.current_plugins_loaded++
	return true
}

func (plugin_loader* l) get_loader_stats() map[string]interface{} {
	l.mu.Lock()
	defer l.mu.Unlock()
	stats := make(map[string]interface{})
	stats["current_plugins_loaded"] = l.current_plugins_loaded
	stats["max_plugins"] = l.max_plugins
	stats["total_load_attempts"] = l.total_load_attempts
	stats["total_load_failures"] = l.total_load_failures
	stats["total_load_successes"] = l.total_load_successes
	stats["loader_status"] = l.status
	uptime_ms := (time.Now().UnixNano() - l.loader_start_time) / 1000000
	stats["uptime_ms"] = uptime_ms
	return stats
}

func (plugin_loader* l) reload_plugin(plugin_id string) bool {
	l.mu.Lock()
	path, exists := l.plugin_path_map[plugin_id]
	if !exists {
		l.mu.Unlock()
		return false
	}
	l.mu.Unlock()
	success := l.unload_plugin(plugin_id)
	if !success {
		return false
	}
	_, load_success := l.load_plugin(plugin_id, path)
	return load_success
}

func (plugin_loader* l) has_plugin(plugin_id string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	_, exists := l.plugin_path_map[plugin_id]
	return exists
}

func (plugin_package* p) add_file(filename string, content string) {
	p.files = append(p.files, filename)
	p.file_content_map[filename] = content
	p.file_count++
	p.package_size_bytes = p.package_size_bytes + int32(len(content))
}

func (plugin_package* p) get_file_content(filename string) (string, bool) {
	content, exists := p.file_content_map[filename]
	return content, exists
}

func (plugin_package* p) calculate_checksum() string {
	checksum := int32(0)
	for _, content := range p.file_content_map {
		for i := int32(0); i < int32(len(content)); i++ {
			checksum = checksum + int32(content[i])
		}
	}
	p.checksum = string(checksum)
	return p.checksum
}

func (plugin_descriptor* d) add_required_module(module string) {
	d.required_modules = append(d.required_modules, module)
}

func (plugin_descriptor* d) add_exported_function(function_name string) {
	d.exported_functions = append(d.exported_functions, function_name)
}

func (plugin_descriptor* d) get_required_modules() []string {
	return d.required_modules
}

func (plugin_descriptor* d) get_exported_functions() []string {
	return d.exported_functions
}
