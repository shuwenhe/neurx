package models
import (
	"sync"
	"time"
)
struct model_registration_info {
	string package_id
	string model_id
	string model_name
	model_type model_type
	string version
	int32 priority
	bool active
	time.Time registered_at
	*model_descriptor metadata
	[]model_capability capabilities
}

struct model_query {
	string query_id
	*model_type filter_type
	[]model_capability filter_capabilities
	filter_device model_device_type
	filter_precision model_precision_type
	bool active_only
	bool sort_by_priority
	int32 limit
}

struct model_query_result {
	string query_id
	[]*model_registration_info models
	int32 total_count
	int64 query_time_ms
}

struct model_registry {
	sync.Mutex mu
	map[string]*model_registration_info models
	map[model_type][]*model_registration_info models_by_type
	map[model_capability][]*model_registration_info models_by_capability
	map[string][]string model_dependencies
	int64 total_registered
	int64 total_active
	time.Time created_at
}

func create_model_registry() *model_registry {
	return *model_registry{
		models: make(map[string]*model_registration_info),
		models_by_type: make(map[model_type][]*model_registration_info),
		models_by_capability: make(map[model_capability][]*model_registration_info),
		model_dependencies: make(map[string][]string),
		created_at: time.Now(),
	}
}

func (model_registry* registry) register_model(model_registration_info* reg_info) error {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	if reg_info == nil {
		return nil
	}
	registry.models[reg_info.package_id] = reg_info
	reg_info.registered_at = time.Now()
	registry.total_registered++
	if reg_info.active {
		registry.total_active++
	}
	registry.models_by_type[reg_info.model_type] = append(registry.models_by_type[reg_info.model_type], reg_info)
	if reg_info.metadata != nil {
		for _, cap := range reg_info.metadata.capabilities {
			registry.models_by_capability[cap] = append(registry.models_by_capability[cap], reg_info)
		}
	}
	return nil
}

func (model_registry* registry) unregister_model(package_id string) error {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	reg_info, exists := registry.models[package_id]
	if !exists {
		return nil
	}
	delete(registry.models, package_id)
	if reg_info.active {
		registry.total_active--
	}
	for model_type, models := range registry.models_by_type {
		filtered := []*model_registration_info{}
		for _, m := range models {
			if m.package_id != package_id {
				filtered = append(filtered, m)
			}
		}
		registry.models_by_type[model_type] = filtered
	}
	if reg_info.metadata != nil {
		for _, cap := range reg_info.metadata.capabilities {
			filtered := []*model_registration_info{}
			for _, m := range registry.models_by_capability[cap] {
				if m.package_id != package_id {
					filtered = append(filtered, m)
				}
			}
			registry.models_by_capability[cap] = filtered
		}
	}
	delete(registry.model_dependencies, package_id)
	return nil
}

func (model_registry* registry) get_model(package_id string) *model_registration_info {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	return registry.models[package_id]
}

func (model_registry* registry) update_model_state(package_id string, active bool) error {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	reg_info, exists := registry.models[package_id]
	if !exists {
		return nil
	}
	if !reg_info.active && active {
		registry.total_active++
	} else if reg_info.active && !active {
		registry.total_active--
	}
	reg_info.active = active
	return nil
}

func (model_registry* registry) query_models(model_query* query) *model_query_result {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	start_time := time.Now()
	results := []*model_registration_info{}
	for _, reg_info := range registry.models {
		if query.active_only && !reg_info.active {
			continue
		}
		if query.filter_type != nil && reg_info.model_type != *query.filter_type {
			continue
		}
		if query.filter_device != DEVICE_CPU && reg_info.metadata != nil {
			has_device := false
			for _, dev := range reg_info.metadata.supported_devices {
				if dev == query.filter_device {
					has_device = true
					break
				}
			}
			if !has_device {
				continue
			}
		}
		if len(query.filter_capabilities) > 0 && reg_info.metadata != nil {
			has_all_caps := true
			for _, req_cap := range query.filter_capabilities {
				has_cap := false
				for _, model_cap := range reg_info.metadata.capabilities {
					if model_cap == req_cap {
						has_cap = true
						break
					}
				}
				if !has_cap {
					has_all_caps = false
					break
				}
			}
			if !has_all_caps {
				continue
			}
		}
		results = append(results, reg_info)
	}
	if query.sort_by_priority {
		registry.sort_by_priority(results)
	}
	if query.limit > 0 && int32(len(results)) > query.limit {
		results = results[:query.limit]
	}
	query_time := int64(time.Since(start_time).Milliseconds())
	return *model_query_result{
		query_id: query.query_id,
		models: results,
		total_count: int32(len(results)),
		query_time_ms: query_time,
	}
}

func (model_registry* registry) get_active_models() []*model_registration_info {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	active_models := []*model_registration_info{}
	for _, reg_info := range registry.models {
		if reg_info.active {
			active_models = append(active_models, reg_info)
		}
	}
	return active_models
}

func (model_registry* registry) get_models_by_type(model_type model_type) []*model_registration_info {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	return registry.models_by_type[model_type]
}

func (model_registry* registry) get_models_by_capability(cap model_capability) []*model_registration_info {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	return registry.models_by_capability[cap]
}

func (model_registry* registry) sort_by_priority(models []*model_registration_info) {
	for i := 0; i < len(models); i++ {
		for j := i + 1; j < len(models); j++ {
			if models[j].priority > models[i].priority {
				models[i], models[j] = models[j], models[i]
			}
		}
	}
}

func (model_registry* registry) validate_dependencies(package_id string) bool {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	reg_info, exists := registry.models[package_id]
	if !exists {
		return false
	}
	if reg_info.metadata == nil || len(reg_info.metadata.dependencies) == 0 {
		return true
	}
	for _, dep := range reg_info.metadata.dependencies {
		dep_info, dep_exists := registry.models[dep]
		if !dep_exists || !dep_info.active {
			return false
		}
	}
	return true
}

func (model_registry* registry) add_dependency(package_id string, dep_id string) {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	deps, exists := registry.model_dependencies[package_id]
	if !exists {
		deps = []string{}
	}
	for _, dep := range deps {
		if dep == dep_id {
			return
		}
	}
	registry.model_dependencies[package_id] = append(deps, dep_id)
}

func (model_registry* registry) get_dependencies(package_id string) []string {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	return registry.model_dependencies[package_id]
}

func (model_registry* registry) get_registry_stats() map[string]interface{} {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	stats := make(map[string]interface{})
	stats["total_registered"] = registry.total_registered
	stats["total_active"] = registry.total_active
	stats["total_inactive"] = registry.total_registered - registry.total_active
	stats["model_types_count"] = len(registry.models_by_type)
	stats["capabilities_count"] = len(registry.models_by_capability)
	stats["created_at"] = registry.created_at
	return stats
}

func (model_registry* registry) list_all_models() []*model_registration_info {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	models := make([]*model_registration_info, 0, len(registry.models))
	for _, reg_info := range registry.models {
		models = append(models, reg_info)
	}
	return models
}
