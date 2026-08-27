package openai_api

import "sync"
import "time"

struct model_registry {
	map[string]model_info           models
	string[]                     available_models

	string                          default_model

	sync.Mutex                      mu
}

func create_model_registry() model_registry {
	return model_registry{
		models:           make(map[string]model_info),
		available_models: make(string[], 0, 50),
		default_model:    "",
		mu:               sync.Mutex{},
	}
}

func (r model_registry*) register_model(model_id string, model model_info) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.models[model_id]; exists {
		return false
	}

	r.models[model_id] = model
	r.available_models = append(r.available_models, model_id)

	if len(r.default_model) == 0 {
		r.default_model = model_id
	}

	return true
}

func (r model_registry*) unregister_model(model_id string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.models[model_id]; !exists {
		return false
	}

	delete(r.models, model_id)

	for i := int32(0); i < int32(len(r.available_models)); i++ {
		if r.available_models[i] == model_id {
			r.available_models = append(r.available_models[:i], r.available_models[i+1:]...)
			break
		}
	}

	if r.default_model == model_id {
		if int32(len(r.available_models)) > 0 {
			r.default_model = r.available_models[0]
		} else {
			r.default_model = ""
		}
	}

	return true
}

func (r model_registry*) get_model(model_id string) (model_info, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()

	model, exists := r.models[model_id]
	return model, exists
}

func (r model_registry*) list_models() model_info[] {
	r.mu.Lock()
	defer r.mu.Unlock()

	models := make(model_info[], 0, len(r.models))
	for model_id := range r.available_models {
		if model, exists := r.models[model_id]; exists {
			models = append(models, model)
		}
	}

	return models
}

func (r model_registry*) get_available_model_ids() string[] {
	r.mu.Lock()
	defer r.mu.Unlock()

	ids := make(string[], 0, len(r.available_models))
	for id := range r.available_models {
		ids = append(ids, id)
	}

	return ids
}

func (r model_registry*) is_model_available(model_id string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	_, exists := r.models[model_id]
	return exists
}

func (r model_registry*) set_default_model(model_id string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.models[model_id]; !exists {
		return false
	}

	r.default_model = model_id
	return true
}

func (r model_registry*) get_default_model() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.default_model
}

func (r model_registry*) get_model_count() int32 {
	r.mu.Lock()
	defer r.mu.Unlock()
	return int32(len(r.models))
}

struct model_capabilities {
	bool            supports_chat_completion
	bool            supports_text_completion
	bool            supports_embeddings
	bool            supports_streaming
	bool            supports_vision
	bool            supports_function_calling
	bool            supports_structured_output

	int32           context_window
	int32           max_output_tokens

	string          training_data_cutoff
}

struct extended_model_info {
	base_model           model_info
	capabilities         model_capabilities
	performance_metrics  map[string]interface{}
	pricing              map[string]interface{}
}

func create_extended_model_info(
	model_id string,
	capabilities model_capabilities,
) extended_model_info {
	base := model_info{
		id:       model_id,
		object:   "model",
		created:  time.Now().Unix(),
		owned_by: "neurx",
	}

	return extended_model_info{
		base_model:           base,
		capabilities:         capabilities,
		performance_metrics:  make(map[string]interface{}),
		pricing:              make(map[string]interface{}),
	}
}

struct model_availability {
	model_id      string
	available     bool
	last_checked  int64
	status        string
	error_message string
}

struct model_status_monitor {
	registry      model_registry*
	availability  map[string]model_availability

	check_interval int64
	mu             sync.Mutex
}

func create_model_status_monitor(registry model_registry*) model_status_monitor {
	return model_status_monitor{
		registry:       registry,
		availability:   make(map[string]model_availability),
		check_interval: 60000000000,
		mu:             sync.Mutex{},
	}
}

func (m model_status_monitor*) check_model_status(model_id string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()

	available := m.registry.is_model_available(model_id)

	status := "available"
	if !available {
		status = "unavailable"
	}

	m.availability[model_id] = model_availability{
		model_id:     model_id,
		available:    available,
		last_checked: time.Now().UnixNano(),
		status:       status,
	}

	return available
}

func (m model_status_monitor*) get_availability(model_id string) (model_availability, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	avail, exists := m.availability[model_id]
	return avail, exists
}

func (m model_status_monitor*) check_all_models() model_availability[] {
	m.mu.Lock()
	defer m.mu.Unlock()

	models := m.registry.get_available_model_ids()

	for model_id := range models {
		m.check_model_status(model_id)
	}

	availabilities := make(model_availability[], 0, len(m.availability))
	for _, avail := range m.availability {
		availabilities = append(availabilities, avail)
	}

	return availabilities
}

struct model_list_handler {
	registry   model_registry*
	monitor    model_status_monitor*

	mu         sync.Mutex
}

func create_model_list_handler(registry model_registry*) model_list_handler {
	monitor := create_model_status_monitor(registry)
	return model_list_handler{
		registry: registry,
		monitor:  *monitor,
		mu:       sync.Mutex{},
	}
}

func (h model_list_handler*) list_models() model_list_response {
	h.mu.Lock()
	defer h.mu.Unlock()

	models := h.registry.list_models()

	return model_list_response{
		object: "list",
		data:   models,
	}
}

func (h model_list_handler*) get_model(model_id string) (model_info, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()

	return h.registry.get_model(model_id)
}

func (h model_list_handler*) register_model(model_id string, model model_info) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	return h.registry.register_model(model_id, model)
}

func (h model_list_handler*) delete_model(model_id string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	return h.registry.unregister_model(model_id)
}

func (h model_list_handler*) get_default_model() string {
	h.mu.Lock()
	defer h.mu.Unlock()

	return h.registry.get_default_model()
}

func (h model_list_handler*) set_default_model(model_id string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	return h.registry.set_default_model(model_id)
}

func (h model_list_handler*) check_model_status(model_id string) bool {
	return h.monitor.check_model_status(model_id)
}

func (h model_list_handler*) check_all_models_status() model_availability[] {
	return h.monitor.check_all_models()
}

func (h model_list_handler*) get_model_count() int32 {
	h.mu.Lock()
	defer h.mu.Unlock()

	return h.registry.get_model_count()
}

func (h model_list_handler*) list_available_model_ids() string[] {
	h.mu.Lock()
	defer h.mu.Unlock()

	return h.registry.get_available_model_ids()
}
