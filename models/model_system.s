package models

import (
	"fmt"
	"sync"
	"time"
)

struct model_system_config {
	int32 max_models
	int64 max_cache_size_bytes
	bool enable_caching
	cache_policy cache_eviction_policy
	int32 timeout_seconds
	default_device model_device_type
	default_precision model_precision_type
	bool enable_batching
	int32 max_batch_size
}

struct model_system_health {
	string status
	bool healthy
	int64 uptime_seconds
	time.Time last_health_check
	int32 total_models
	int32 active_models
	int32 failed_models
	float64 memory_usage_mb
	float64 cache_utilization_percent
}

struct model_system {
	sync.Mutex mu
	*model_loader loader
	*model_registry registry
	*model_adapter_registry adapter_registry
	*model_cache cache
	map[string]*model_interface active_models
	map[string]*inference_engine inference_engines
	map[string]*tokenizer_interface tokenizers
	*model_system_config config
	*model_system_health health
	map[string]interface{} stats
	time.Time created_at
	time.Time last_operation_time
	int64 total_inferences
}

func create_model_system(model_system_config* config) *model_system {
	if config == nil {
		config = &model_system_config{
			max_models: 100,
			max_cache_size_bytes: 10 * 1024 * 1024 * 1024,
			enable_caching: true,
			cache_policy: EVICT_LRU,
			timeout_seconds: 300,
			default_device: DEVICE_CUDA,
			default_precision: PRECISION_FP16,
			enable_batching: true,
			max_batch_size: 32,
		}
	}
	
	cache_config := &cache_config{
		max_size_bytes: config.max_cache_size_bytes,
		eviction_policy: config.cache_policy,
		ttl_seconds: config.timeout_seconds,
	}
	
	return &model_system{
		loader: create_model_loader(),
		registry: create_model_registry(),
		adapter_registry: create_model_adapter_registry(),
		cache: create_model_cache(cache_config),
		active_models: make(map[string]*model_interface),
		inference_engines: make(map[string]*inference_engine),
		tokenizers: make(map[string]*tokenizer_interface),
		config: config,
		health: &model_system_health{
			status: "initializing",
			healthy: true,
			last_health_check: time.Now(),
		},
		stats: make(map[string]interface{}),
		created_at: time.Now(),
	}
}

func (model_system* system) register_model_path(path string) error {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	return system.loader.register_model_path(path)
}

func (model_system* system) load_model(model_id string, model_type model_type, device model_device_type) *model_interface {
	system.mu.Lock()
	
	if int32(len(system.active_models)) >= system.config.max_models {
		system.mu.Unlock()
		return nil
	}
	
	system.mu.Unlock()
	
	load_result := system.loader.load_model(model_id, model_type, device)
	if !load_result.success {
		return nil
	}
	
	model := load_result.model_interface
	model.set_state(STATE_INITIALIZED)
	
	inference_engine := create_inference_engine(model_id, model)
	tokenizer := create_tokenizer(model_id+"_tokenizer", model_id, TOKENIZER_BPE)
	
	system.mu.Lock()
	system.active_models[model_id] = model
	system.inference_engines[model_id] = inference_engine
	system.tokenizers[model_id] = tokenizer
	system.last_operation_time = time.Now()
	system.mu.Unlock()
	
	reg_info := &model_registration_info{
		package_id: model_id,
		model_id: model_id,
		model_name: model.model_name,
		model_type: model_type,
		active: true,
	}
	system.registry.register_model(reg_info)
	
	return model
}

func (model_system* system) unload_model(model_id string) error {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	delete(system.active_models, model_id)
	delete(system.inference_engines, model_id)
	delete(system.tokenizers, model_id)
	system.registry.unregister_model(model_id)
	system.last_operation_time = time.Now()
	
	return nil
}

func (model_system* system) get_model(model_id string) *model_interface {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	return system.active_models[model_id]
}

func (model_system* system) infer(model_id string, request *inference_request) *inference_response {
	system.mu.Lock()
	
	engine, exists := system.inference_engines[model_id]
	if !exists {
		system.mu.Unlock()
		return &inference_response{
			success: false,
			error_message: fmt.Sprintf("model not found: %s", model_id),
		}
	}
	
	system.total_inferences++
	system.last_operation_time = time.Now()
	system.mu.Unlock()
	
	return engine.execute_inference(request)
}

func (model_system* system) batch_infer(model_id string, batch_request *batch_inference_request) *batch_inference_response {
	system.mu.Lock()
	
	engine, exists := system.inference_engines[model_id]
	if !exists {
		system.mu.Unlock()
		return &batch_inference_response{
			success: false,
			error_message: fmt.Sprintf("model not found: %s", model_id),
		}
	}
	
	system.total_inferences++
	system.last_operation_time = time.Now()
	system.mu.Unlock()
	
	return engine.submit_batch_inference(batch_request)
}

func (model_system* system) get_tokenizer(model_id string) *tokenizer_interface {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	return system.tokenizers[model_id]
}

func (model_system* system) register_model_path_with_type(path string, model_type model_type) error {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	return system.loader.register_model_path(path)
}

func (model_system* system) list_active_models() []string {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	models := make([]string, 0, len(system.active_models))
	for model_id := range system.active_models {
		models = append(models, model_id)
	}
	return models
}

func (model_system* system) check_system_health() *model_system_health {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	uptime := int64(time.Since(system.created_at).Seconds())
	active_count := int32(0)
	failed_count := int32(0)
	
	for _, model := range system.active_models {
		state := model.get_state()
		if state == STATE_READY || state == STATE_RUNNING {
			active_count++
		} else if state == STATE_ERROR {
			failed_count++
		}
	}
	
	cache_stats := system.cache.get_stats()
	cache_util := 0.0
	if system.config.max_cache_size_bytes > 0 {
		cache_util = (float64(cache_stats.memory_usage_bytes) / float64(system.config.max_cache_size_bytes)) * 100.0
	}
	
	system.health = &model_system_health{
		status: "healthy",
		healthy: true,
		uptime_seconds: uptime,
		last_health_check: time.Now(),
		total_models: int32(len(system.active_models)),
		active_models: active_count,
		failed_models: failed_count,
		cache_utilization_percent: cache_util,
	}
	
	if failed_count > 0 {
		system.health.status = "degraded"
		system.health.healthy = false
	}
	
	return system.health
}

func (model_system* system) get_model_stats(model_id string) map[string]interface{} {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	model, exists := system.active_models[model_id]
	if !exists {
		return nil
	}
	
	stats_obj := model.get_stats()
	
	stats := make(map[string]interface{})
	stats["model_id"] = model_id
	stats["total_tokens"] = stats_obj.total_tokens
	stats["total_requests"] = stats_obj.total_requests
	stats["total_errors"] = stats_obj.total_errors
	stats["avg_latency_ms"] = stats_obj.avg_latency_ms
	stats["peak_memory_mb"] = stats_obj.peak_memory_mb
	stats["uptime_seconds"] = int64(time.Since(stats_obj.loaded_at).Seconds())
	
	return stats
}

func (model_system* system) get_system_stats() map[string]interface{} {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	uptime := int64(time.Since(system.created_at).Seconds())
	
	stats := make(map[string]interface{})
	stats["total_models"] = int32(len(system.active_models))
	stats["total_inferences"] = system.total_inferences
	stats["uptime_seconds"] = uptime
	stats["cache_enabled"] = system.config.enable_caching
	stats["cache_stats"] = system.cache.get_stats()
	stats["loader_stats"] = system.loader.get_loader_stats()
	stats["registry_stats"] = system.registry.get_registry_stats()
	stats["adapter_stats"] = system.adapter_registry.get_registry_stats()
	
	return stats
}

func (model_system* system) cache_put(key string, value interface{}, size_bytes int64) {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	if system.config.enable_caching {
		system.cache.put(key, value, CACHE_ENTRY_INFERENCE, size_bytes)
	}
}

func (model_system* system) cache_get(key string) (interface{}, bool) {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	if system.config.enable_caching {
		return system.cache.get(key)
	}
	return nil, false
}

func (model_system* system) get_health() *model_system_health {
	system.check_system_health()
	system.mu.Lock()
	defer system.mu.Unlock()
	
	return system.health
}

func (model_system* system) initialize_standard_models() error {
	system.mu.Lock()
	system.mu.Unlock()
	
	register_all_standard_adapters(system.adapter_registry)
	return nil
}

func (model_system* system) get_adapter_registry() *model_adapter_registry {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	return system.adapter_registry
}

func (model_system* system) get_model_registry() *model_registry {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	return system.registry
}

func (model_system* system) shutdown() error {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	for model_id := range system.active_models {
		delete(system.active_models, model_id)
		delete(system.inference_engines, model_id)
		delete(system.tokenizers, model_id)
	}
	
	system.cache.clear()
	system.health.status = "shutdown"
	
	return nil
}

func (model_system* system) set_config(model_system_config* config) {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	if config != nil {
		system.config = config
	}
}

func (model_system* system) get_config() *model_system_config {
	system.mu.Lock()
	defer system.mu.Unlock()
	
	return system.config
}
