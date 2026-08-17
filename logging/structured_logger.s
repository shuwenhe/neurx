package logging

import "sync"
import "time"
import "encoding/json"

struct structured_logger {
	string                  logger_name
	log_level               min_level

	vec[log_entry]          entries
	int32                   max_entries
	int32                   entry_count

	vec[log_entry_batch]    batches
	int32                   batch_count

	map[string]string       default_labels
	map[string]interface{}  default_fields

	int32                   flush_interval_ms
	int64                   last_flush_time

	int32                   total_entries_logged
	int32                   total_errors_logged

	sync.Mutex              mu
}

struct logger_config {
	string                  name
	log_level               min_level
	int32                   max_entries
	int32                   flush_interval_ms
}

func create_structured_logger(config logger_config) structured_logger {
	return structured_logger{
		logger_name:          config.name,
		min_level:            config.min_level,
		entries:              make(vec[log_entry], 0, 1000),
		max_entries:          config.max_entries,
		entry_count:          0,
		batches:              make(vec[log_entry_batch], 0, 100),
		batch_count:          0,
		default_labels:       make(map[string]string),
		default_fields:       make(map[string]interface{}),
		flush_interval_ms:    config.flush_interval_ms,
		last_flush_time:      time.Now().UnixNano(),
		total_entries_logged: 0,
		total_errors_logged:  0,
		mu:                   sync.Mutex{},
	}
}

func (structured_logger* s) log_entry(entry log_entry) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if entry.level < s.min_level {
		return
	}

	entry.entry_id = "log_" + string(s.total_entries_logged)

	for key, val := range s.default_labels {
		if _, exists := entry.labels[key]; !exists {
			entry.labels[key] = val
		}
	}

	for key, val := range s.default_fields {
		if _, exists := entry.fields[key]; !exists {
			entry.fields[key] = val
		}
	}

	s.entries = append(s.entries, entry)
	s.entry_count++
	s.total_entries_logged++

	if entry.level == ERROR || entry.level == FATAL {
		s.total_errors_logged++
	}

	if s.entry_count >= s.max_entries {
		s.flush_batch()
	}
}

func (structured_logger* s) log_info(msg string, component string) {
	entry := create_log_entry()
	entry.message = msg
	entry.component = component
	entry.level = INFO
	s.log_entry(entry)
}

func (structured_logger* s) log_debug(msg string, component string) {
	entry := create_log_entry()
	entry.message = msg
	entry.component = component
	entry.level = DEBUG
	s.log_entry(entry)
}

func (structured_logger* s) log_warn(msg string, component string) {
	entry := create_log_entry()
	entry.message = msg
	entry.component = component
	entry.level = WARN
	s.log_entry(entry)
}

func (structured_logger* s) log_error(msg string, component string, error_code int32) {
	entry := create_log_entry()
	entry.message = msg
	entry.component = component
	entry.level = ERROR
	entry.error_code = error_code
	s.log_entry(entry)
}

func (structured_logger* s) log_with_context(msg string, ctx log_context, level log_level) {
	entry := create_log_entry()
	entry.message = msg
	entry.component = ctx.component
	entry.level = level
	entry.trace_id = ctx.request_id
	entry.add_field("depth", ctx.depth)

	for key, val := range ctx.metadata {
		entry.add_field(key, val)
	}

	s.log_entry(entry)
}

func (structured_logger* s) add_default_label(key string, value string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.default_labels[key] = value
}

func (structured_logger* s) add_default_field(key string, value interface{}) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.default_fields[key] = value
}

func (structured_logger* s) set_min_level(level log_level) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.min_level = level
}

func (structured_logger* s) get_entries() vec[log_entry] {
	s.mu.Lock()
	defer s.mu.Unlock()

	result := make(vec[log_entry], 0, len(s.entries))
	for entry := range s.entries {
		result = append(result, entry)
	}
	return result
}

func (structured_logger* s) flush_batch() {
	if int32(len(s.entries)) == 0 {
		return
	}

	batch := create_log_entry_batch()
	batch.source_component = s.logger_name
	batch.batch_id = s.batch_count

	for entry := range s.entries {
		batch.add_entry(entry)
	}

	s.batches = append(s.batches, batch)
	s.batch_count++
	s.entries = make(vec[log_entry], 0, 1000)
	s.entry_count = 0
	s.last_flush_time = time.Now().UnixNano()
}

func (structured_logger* s) needs_flush() bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	elapsed := (time.Now().UnixNano() - s.last_flush_time) / 1000000
	return elapsed > int64(s.flush_interval_ms) || s.entry_count >= s.max_entries
}

func (structured_logger* s) flush_if_needed() {
	s.mu.Lock()
	defer s.mu.Unlock()

	elapsed := (time.Now().UnixNano() - s.last_flush_time) / 1000000
	if elapsed > int64(s.flush_interval_ms) || s.entry_count >= s.max_entries {
		s.flush_batch()
	}
}

func (structured_logger* s) get_statistics() map[string]interface{} {
	s.mu.Lock()
	defer s.mu.Unlock()

	stats := make(map[string]interface{})
	stats["total_entries_logged"] = s.total_entries_logged
	stats["total_errors_logged"] = s.total_errors_logged
	stats["current_entries"] = s.entry_count
	stats["total_batches"] = s.batch_count
	stats["logger_name"] = s.logger_name

	return stats
}

func (structured_logger* s) clear_entries() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.entries = make(vec[log_entry], 0, 1000)
	s.entry_count = 0
}

func (structured_logger* s) clear_all() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.entries = make(vec[log_entry], 0, 1000)
	s.batches = make(vec[log_entry_batch], 0, 100)
	s.entry_count = 0
	s.batch_count = 0
	s.total_entries_logged = 0
	s.total_errors_logged = 0
}
