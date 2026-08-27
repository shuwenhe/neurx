package plugins

import "sync"
import "time"

struct plugin_config {
	string                  config_id
	string                  plugin_id

	map[string]interface{}  config_data

	string                  config_schema
	bool                    schema_validated

	int64                   created_at
	int64                   last_modified_at

	int32                   version

	bool                    is_active
}

struct config_validation_rule {
	string                  rule_id
	string                  field_name
	string                  rule_type

	interface{}             expected_value
	interface{}             min_value
	interface{}             max_value

	bool                    is_required
	interface{}[]        allowed_values

	string                  error_message
}

struct config_schema {
	string                  schema_id
	config_validation_rule[]  rules
	int32                   rule_count

	bool                    strict_mode
	int32                   schema_version
}

struct config_manager {
	map[string]plugin_config]     configs
	int32                         config_count

	map[string]config_schema]     schemas
	int32                         schema_count

	map[string]int32]             config_versions

	int32                         total_configs_created
	int32                         total_configs_updated
	int32                         total_configs_deleted

	int32                         validation_failures

	sync.Mutex                    mu
}

struct config_change_log {
	string                  change_id
	string                  config_id

	int64                   change_time
	int32                   change_sequence

	string                  changed_by

	map[string]interface{}  old_value
	map[string]interface{}  new_value

	string                  change_reason
}

func create_plugin_config(config_id string, plugin_id string) plugin_config {
	return plugin_config{
		config_id:         config_id,
		plugin_id:         plugin_id,
		config_data:       make(map[string]interface{}),
		config_schema:     "",
		schema_validated:  false,
		created_at:        time.Now().UnixNano(),
		last_modified_at:  time.Now().UnixNano(),
		version:           1,
		is_active:         false,
	}
}

func create_config_manager() config_manager {
	return config_manager{
		configs:                  make(map[string]plugin_config),
		config_count:             0,
		schemas:                  make(map[string]config_schema),
		schema_count:             0,
		config_versions:          make(map[string]int32),
		total_configs_created:    0,
		total_configs_updated:    0,
		total_configs_deleted:    0,
		validation_failures:      0,
		mu:                       sync.Mutex{},
	}
}

func create_config_schema(schema_id string) config_schema {
	return config_schema{
		schema_id:        schema_id,
		rules:            make(config_validation_rule[], 0),
		rule_count:       0,
		strict_mode:      false,
		schema_version:   1,
	}
}

func create_validation_rule(rule_id string, field_name string, rule_type string) config_validation_rule {
	return config_validation_rule{
		rule_id:          rule_id,
		field_name:       field_name,
		rule_type:        rule_type,
		expected_value:   nil,
		min_value:        nil,
		max_value:        nil,
		is_required:      false,
		allowed_values:   make(interface{}[], 0),
		error_message:    "",
	}
}

func (config_manager* m) create_config(config_id string, plugin_id string) (plugin_config, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	_, exists := m.configs[config_id]
	if exists {
		return plugin_config{}, false
	}

	config := create_plugin_config(config_id, plugin_id)
	m.configs[config_id] = config
	m.config_count++
	m.config_versions[config_id] = 1
	m.total_configs_created++

	return config, true
}

func (config_manager* m) set_config_value(config_id string, key string, value interface{}) bool {
	m.mu.Lock()
	defer m.mu.Unlock()

	config, exists := m.configs[config_id]
	if !exists {
		return false
	}

	config.config_data[key] = value
	config.last_modified_at = time.Now().UnixNano()
	config.version++

	m.configs[config_id] = config
	m.total_configs_updated++

	return true
}

func (config_manager* m) get_config_value(config_id string, key string) (interface{}, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	config, exists := m.configs[config_id]
	if !exists {
		return nil, false
	}

	value, value_exists := config.config_data[key]
	return value, value_exists
}

func (config_manager* m) get_all_config_values(config_id string) (map[string]interface{}, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	config, exists := m.configs[config_id]
	if !exists {
		return make(map[string]interface{}), false
	}

	return config.config_data, true
}

func (config_manager* m) delete_config(config_id string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()

	_, exists := m.configs[config_id]
	if !exists {
		return false
	}

	delete(m.configs, config_id)
	delete(m.config_versions, config_id)
	m.config_count--
	m.total_configs_deleted++

	return true
}

func (config_manager* m) register_schema(schema config_schema) bool {
	m.mu.Lock()
	defer m.mu.Unlock()

	_, exists := m.schemas[schema.schema_id]
	if exists {
		return false
	}

	m.schemas[schema.schema_id] = schema
	m.schema_count++

	return true
}

func (config_manager* m) validate_config(config_id string, schema_id string) (bool, string[]) {
	m.mu.Lock()
	defer m.mu.Unlock()

	config, config_exists := m.configs[config_id]
	if !config_exists {
		return false, make(string[], 0)
	}

	schema, schema_exists := m.schemas[schema_id]
	if !schema_exists {
		return false, make(string[], 0)
	}

	errors := make(string[], 0)

	for rule := range schema.rules {
		value, exists := config.config_data[rule.field_name]

		if rule.is_required && !exists {
			errors = append(errors, "required_field_missing:" + rule.field_name)
		}

		if exists && value == nil {
			if rule.is_required {
				errors = append(errors, "field_null_not_allowed:" + rule.field_name)
			}
		}
	}

	if int32(len(errors)) > 0 {
		m.validation_failures++
		return false, errors
	}

	config.schema_validated = true
	m.configs[config_id] = config

	return true, errors
}

func (config_manager* m) activate_config(config_id string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()

	config, exists := m.configs[config_id]
	if !exists {
		return false
	}

	config.is_active = true
	m.configs[config_id] = config

	return true
}

func (config_manager* m) deactivate_config(config_id string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()

	config, exists := m.configs[config_id]
	if !exists {
		return false
	}

	config.is_active = false
	m.configs[config_id] = config

	return true
}

func (config_manager* m) get_config_version(config_id string) int32 {
	m.mu.Lock()
	defer m.mu.Unlock()

	version, exists := m.config_versions[config_id]
	if exists {
		return version
	}
	return 0
}

func (config_manager* m) get_config_stats() map[string]interface{} {
	m.mu.Lock()
	defer m.mu.Unlock()

	stats := make(map[string]interface{})
	stats["total_configs"] = m.config_count
	stats["total_schemas"] = m.schema_count
	stats["total_created"] = m.total_configs_created
	stats["total_updated"] = m.total_configs_updated
	stats["total_deleted"] = m.total_configs_deleted
	stats["validation_failures"] = m.validation_failures

	return stats
}

func (config_schema* s) add_rule(rule config_validation_rule) {
	s.rules = append(s.rules, rule)
	s.rule_count++
}

func (config_schema* s) get_rules() config_validation_rule[] {
	return s.rules
}

func (config_validation_rule* r) set_required(required bool) {
	r.is_required = required
}

func (config_validation_rule* r) add_allowed_value(value interface{}) {
	r.allowed_values = append(r.allowed_values, value)
}

func (plugin_config* c) is_valid() bool {
	return c.schema_validated
}

func (plugin_config* c) get_config_data() map[string]interface{} {
	return c.config_data
}

func (plugin_config* c) merge_config(other plugin_config) bool {
	if c.plugin_id != other.plugin_id {
		return false
	}

	for key, value := range other.config_data {
		c.config_data[key] = value
	}

	c.last_modified_at = time.Now().UnixNano()
	c.version++

	return true
}
