package plugins
import "sync"
import "time"
	EVENT_LOADING = 0
	EVENT_LOADED = 1
	EVENT_INITIALIZING = 2
	EVENT_INITIALIZED = 3
	EVENT_STARTING = 4
	EVENT_STARTED = 5
	EVENT_PAUSING = 6
	EVENT_PAUSED = 7
	EVENT_RESUMING = 8
	EVENT_RESUMED = 9
	EVENT_STOPPING = 10
	EVENT_STOPPED = 11
	EVENT_UNLOADING = 12
	EVENT_UNLOADED = 13
	EVENT_ERROR = 14
}

struct lifecycle_event {
	lifecycle_event_type    event_type
	string                  event_description
	string                  plugin_id
	string                  plugin_name
	int64                   event_time
	int32                   event_sequence
	plugin_state            state_before
	plugin_state            state_after
	string                  event_data
	map[string]interface{}  event_context
}

struct lifecycle_listener {
	string                  listener_id
	string                  listener_name
	lifecycle_event_type[] subscribed_events
	int32                   subscription_count
	int32                   events_received
	int64                   created_at
}

struct plugin_lifecycle_manager {
	map[string]lifecycle_listener]  listeners
	int32                           listener_count
	lifecycle_event[]            event_history
	int32                           max_history_size
	int32                           event_history_count
	int32                           total_lifecycle_events
	map[string]int64]               plugin_state_change_times
	map[string]int32]               plugin_attempt_counts
	int32                           startup_timeout_ms
	int32                           shutdown_timeout_ms
	sync.Mutex                      mu
}

struct lifecycle_transition {
	plugin_state            from_state
	plugin_state            to_state
	string                  transition_reason
	int64                   transition_start_time
	int64                   transition_end_time
	bool                    transition_success
	string                  error_message
	map[string]interface{}  transition_context
}

struct plugin_lifecycle_stats {
	int32                   total_plugins_initialized
	int32                   total_plugins_started
	int32                   total_plugins_stopped
	int32                   total_plugins_failed
	int32                   current_active_plugins
	int32                   current_paused_plugins
	int32                   total_lifecycle_events
	int32                   average_startup_time_ms
	int32                   average_shutdown_time_ms
}

func create_plugin_lifecycle_manager(max_history int32) plugin_lifecycle_manager {
	return plugin_lifecycle_manager{
		listeners:                make(map[string]lifecycle_listener),
		listener_count:           0,
		event_history:            make(lifecycle_event[], 0, max_history),
		max_history_size:         max_history,
		event_history_count:      0,
		total_lifecycle_events:   0,
		plugin_state_change_times: make(map[string]int64),
		plugin_attempt_counts:    make(map[string]int32),
		startup_timeout_ms:       5000,
		shutdown_timeout_ms:      5000,
		mu:                       sync.Mutex{},
	}
}

func create_lifecycle_event(event_type lifecycle_event_type, plugin_id string) lifecycle_event {
	return lifecycle_event{
		event_type:        event_type,
		event_description: "",
		plugin_id:         plugin_id,
		plugin_name:       "",
		event_time:        time.Now().UnixNano(),
		event_sequence:    0,
		state_before:      PLUGIN_UNINITIALIZED,
		state_after:       PLUGIN_UNINITIALIZED,
		event_data:        "",
		event_context:     make(map[string]interface{}),
	}
}

func (plugin_lifecycle_manager* m) register_listener(listener lifecycle_listener) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	_, exists := m.listeners[listener.listener_id]
	if exists {
		return false
	}
	m.listeners[listener.listener_id] = listener
	m.listener_count++
	return true
}

func (plugin_lifecycle_manager* m) unregister_listener(listener_id string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	_, exists := m.listeners[listener_id]
	if !exists {
		return false
	}
	delete(m.listeners, listener_id)
	m.listener_count--
	return true
}

func (plugin_lifecycle_manager* m) subscribe_to_event(listener_id string, event_type lifecycle_event_type) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	listener, exists := m.listeners[listener_id]
	if !exists {
		return false
	}
	listener.subscribed_events = append(listener.subscribed_events, event_type)
	listener.subscription_count++
	m.listeners[listener_id] = listener
	return true
}

func (plugin_lifecycle_manager* m) emit_lifecycle_event(event lifecycle_event) {
	m.mu.Lock()
	defer m.mu.Unlock()
	event.event_sequence = m.total_lifecycle_events
	m.total_lifecycle_events++
	if m.event_history_count < m.max_history_size {
		m.event_history = append(m.event_history, event)
		m.event_history_count++
	}
	m.plugin_state_change_times[event.plugin_id] = event.event_time
	count, exists := m.plugin_attempt_counts[event.plugin_id]
	if exists {
		m.plugin_attempt_counts[event.plugin_id] = count + 1
	} else {
		m.plugin_attempt_counts[event.plugin_id] = 1
	}
}

func (plugin_lifecycle_manager* m) get_event_history(plugin_id string) []lifecycle_event {
	m.mu.Lock()
	defer m.mu.Unlock()
	result := make(lifecycle_event[], 0)
	for event := range m.event_history {
		if event.plugin_id == plugin_id {
			result = append(result, event)
		}
	}
	return result
}

func (plugin_lifecycle_manager* m) get_all_events() []lifecycle_event {
	m.mu.Lock()
	defer m.mu.Unlock()
	result := make(lifecycle_event[], 0)
	for event := range m.event_history {
		result = append(result, event)
	}
	return result
}

func (plugin_lifecycle_manager* m) get_plugin_attempt_count(plugin_id string) int32 {
	m.mu.Lock()
	defer m.mu.Unlock()
	count, exists := m.plugin_attempt_counts[plugin_id]
	if exists {
		return count
	}
	return 0
}

func (plugin_lifecycle_manager* m) record_transition(transition lifecycle_transition) {
	m.mu.Lock()
	defer m.mu.Unlock()
	duration_ms := (transition.transition_end_time - transition.transition_start_time) / 1000000
	event_data := "transition:" + string(transition.from_state) + "." + string(transition.to_state)
	event := lifecycle_event{
		event_type:        EVENT_STARTED,
		event_description: transition.transition_reason,
		event_time:        transition.transition_end_time,
		event_sequence:    m.total_lifecycle_events,
		state_before:      transition.from_state,
		state_after:       transition.to_state,
		event_data:        event_data,
		event_context:     transition.transition_context,
	}
	m.total_lifecycle_events++
	if m.event_history_count < m.max_history_size {
		m.event_history = append(m.event_history, event)
		m.event_history_count++
	}
}

func (plugin_lifecycle_manager* m) get_lifecycle_stats() plugin_lifecycle_stats {
	m.mu.Lock()
	defer m.mu.Unlock()
	stats := plugin_lifecycle_stats{
		total_plugins_initialized: 0,
		total_plugins_started:     0,
		total_plugins_stopped:     0,
		total_plugins_failed:      0,
		current_active_plugins:    0,
		current_paused_plugins:    0,
		total_lifecycle_events:    m.total_lifecycle_events,
		average_startup_time_ms:   0,
		average_shutdown_time_ms:  0,
	}
	init_count := int32(0)
	startup_total := int32(0)
	for event := range m.event_history {
		if event.event_type == EVENT_INITIALIZED {
			stats.total_plugins_initialized++
			init_count++
		}
		if event.event_type == EVENT_STARTED {
			stats.total_plugins_started++
			startup_total = startup_total + int32((event.event_time)/1000000)
		}
		if event.event_type == EVENT_STOPPED {
			stats.total_plugins_stopped++
		}
		if event.event_type == EVENT_ERROR {
			stats.total_plugins_failed++
		}
	}
	if init_count > 0 {
		stats.average_startup_time_ms = startup_total / init_count
	}
	return stats
}

func (plugin_lifecycle_manager* m) clear_event_history() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.event_history = make(lifecycle_event[], 0, m.max_history_size)
	m.event_history_count = 0
}

func (plugin_lifecycle_manager* m) get_listener_subscription_count(listener_id string) int32 {
	m.mu.Lock()
	defer m.mu.Unlock()
	listener, exists := m.listeners[listener_id]
	if exists {
		return listener.subscription_count
	}
	return 0
}

func create_lifecycle_listener(listener_id string, name string) lifecycle_listener {
	return lifecycle_listener{
		listener_id:         listener_id,
		listener_name:       name,
		subscribed_events:   make(lifecycle_event_type[], 0),
		subscription_count:  0,
		events_received:     0,
		created_at:          time.Now().UnixNano(),
	}
}

func create_lifecycle_transition(from plugin_state, to plugin_state) lifecycle_transition {
	return lifecycle_transition{
		from_state:               from,
		to_state:                 to,
		transition_reason:        "",
		transition_start_time:    time.Now().UnixNano(),
		transition_end_time:      0,
		transition_success:       false,
		error_message:            "",
		transition_context:       make(map[string]interface{}),
	}
}

func (lifecycle_transition* t) mark_success() {
	t.transition_end_time = time.Now().UnixNano()
	t.transition_success = true
}

func (lifecycle_transition* t) mark_failed(error_msg string) {
	t.transition_end_time = time.Now().UnixNano()
	t.transition_success = false
	t.error_message = error_msg
}

func (lifecycle_transition* t) get_duration_ms() int64 {
	return (t.transition_end_time - t.transition_start_time) / 1000000
}
