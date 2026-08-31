package openai_api
import "sync"
	ERR_INVALID_REQUEST_ERROR      = 0
	ERR_AUTHENTICATION_ERROR        = 1
	ERR_PERMISSION_ERROR            = 2
	ERR_NOT_FOUND_ERROR             = 3
	ERR_RATE_LIMIT_ERROR            = 4
	ERR_SERVER_ERROR                = 5
	ERR_SERVICE_UNAVAILABLE_ERROR   = 6
	ERR_TIMEOUT_ERROR               = 7
	ERR_CONTENT_FILTER_ERROR        = 8
}

struct api_error {
	int32           error_type
	string          message
	string          code
	string          param
	int32           status_code
	string          request_id
	int64           timestamp
	string          internal_error
	string          suggestion
}

func create_api_error(
	error_type int32,
	message string,
	status_code int32,
) api_error {
	return api_error{
		error_type:  error_type,
		message:     message,
		status_code: status_code,
		code:        error_type_to_code(error_type),
	}
}

func (e api_error) to_response() error_response {
	return create_error_response(e.status_code, e.message, e.code)
}

func error_type_to_code(error_type int32) string {
	switch error_type {
	case ERR_INVALID_REQUEST_ERROR:
		return "invalid_request_error"
	case ERR_AUTHENTICATION_ERROR:
		return "authentication_error"
	case ERR_PERMISSION_ERROR:
		return "permission_error"
	case ERR_NOT_FOUND_ERROR:
		return "not_found_error"
	case ERR_RATE_LIMIT_ERROR:
		return "rate_limit_error"
	case ERR_SERVER_ERROR:
		return "server_error"
	case ERR_SERVICE_UNAVAILABLE_ERROR:
		return "service_unavailable_error"
	case ERR_TIMEOUT_ERROR:
		return "timeout_error"
	case ERR_CONTENT_FILTER_ERROR:
		return "content_filter_error"
	default:
		return "internal_error"
	}
}

func error_code_to_type(code string) int32 {
	switch code {
	case "invalid_request_error":
		return ERR_INVALID_REQUEST_ERROR
	case "authentication_error":
		return ERR_AUTHENTICATION_ERROR
	case "permission_error":
		return ERR_PERMISSION_ERROR
	case "not_found_error":
		return ERR_NOT_FOUND_ERROR
	case "rate_limit_error":
		return ERR_RATE_LIMIT_ERROR
	case "server_error":
		return ERR_SERVER_ERROR
	case "service_unavailable_error":
		return ERR_SERVICE_UNAVAILABLE_ERROR
	case "timeout_error":
		return ERR_TIMEOUT_ERROR
	case "content_filter_error":
		return ERR_CONTENT_FILTER_ERROR
	default:
		return ERR_SERVER_ERROR
	}
}

struct error_handler {
	api_error[]              errors
	map[string]int32            error_counts
	sync.Mutex                  mu
}

func create_error_handler() error_handler {
	return error_handler{
		errors:       make(api_error[], 0, 1000),
		error_counts: make(map[string]int32),
		mu:           sync.Mutex{},
	}
}

func (h error_handler*) handle_error(err api_error) error_response {
	h.mu.Lock()
	h.errors = append(h.errors, err)
	h.error_counts[err.code]++
	h.mu.Unlock()
	return err.to_response()
}

func (h error_handler*) get_error_count(error_code string) int32 {
	h.mu.Lock()
	defer h.mu.Unlock()
	count, exists := h.error_counts[error_code]
	if !exists {
		return 0
	}
	return count
}

func (h error_handler*) get_total_errors() int32 {
	h.mu.Lock()
	defer h.mu.Unlock()
	return int32(len(h.errors))
}

func (h error_handler*) get_error_stats() map[string]int32 {
	h.mu.Lock()
	defer h.mu.Unlock()
	stats := make(map[string]int32)
	for code, count := range h.error_counts {
		stats[code] = count
	}
	return stats
}

func (h error_handler*) clear_error_history() {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.errors = make(api_error[], 0, 1000)
	h.error_counts = make(map[string]int32)
}

struct error_recovery {
	bool                        retry_enabled
	int32                       max_retries
	int64                       retry_delay_ms
	map[string]bool             retriable_errors
	sync.Mutex                  mu
}

func create_error_recovery() error_recovery {
	retriable := make(map[string]bool)
	retriable["rate_limit_error"] = true
	retriable["timeout_error"] = true
	retriable["service_unavailable_error"] = true
	retriable["server_error"] = true
	return error_recovery{
		retry_enabled:    true,
		max_retries:      3,
		retry_delay_ms:   100,
		retriable_errors: retriable,
		mu:               sync.Mutex{},
	}
}

func (r error_recovery*) is_retriable(error_code string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	retriable, exists := r.retriable_errors[error_code]
	return exists && retriable
}

func (r error_recovery*) add_retriable_error(error_code string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.retriable_errors[error_code] = true
}

func (r error_recovery*) remove_retriable_error(error_code string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.retriable_errors, error_code)
}

func (r error_recovery*) get_backoff_delay(attempt_number int32) int64 {
	if !r.retry_enabled || attempt_number <= 0 {
		return 0
	}
	delay := r.retry_delay_ms
	for i := int32(0); i < attempt_number-1; i++ {
		delay = delay * 2
		if delay > 10000 {
			delay = 10000
		}
	}
	return delay
}

struct content_filter {
	bool                        enabled
	string[]                 filter_rules
	int64                       blocked_count
	sync.Mutex                  mu
}

func create_content_filter() content_filter {
	return content_filter{
		enabled:       true,
		filter_rules:  make(string[], 0),
		blocked_count: 0,
		mu:            sync.Mutex{},
	}
}

func (f content_filter*) check_content(content string) (bool, string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if !f.enabled {
		return true, ""
	}
	for rule := range f.filter_rules {
		if contains(content, rule) {
			f.blocked_count++
			return false, "content_filtered"
		}
	}
	return true, ""
}

func (f content_filter*) add_filter_rule(rule string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.filter_rules = append(f.filter_rules, rule)
}

func (f content_filter*) get_blocked_count() int64 {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.blocked_count
}

struct error_logging {
	bool                        enable_logging
	string                      log_level
	string[]                 error_logs
	int32                       max_log_size
	sync.Mutex                  mu
}

func create_error_logging() error_logging {
	return error_logging{
		enable_logging: true,
		log_level:      "error",
		error_logs:     make(string[], 0, 10000),
		max_log_size:   10000,
		mu:             sync.Mutex{},
	}
}

func (l error_logging*) log_error(error_msg string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if !l.enable_logging {
		return
	}
	if int32(len(l.error_logs)) >= l.max_log_size {
		remove_count := l.max_log_size / 10
		l.error_logs = l.error_logs[remove_count:]
	}
	l.error_logs = append(l.error_logs, error_msg)
}

func (l error_logging*) get_error_logs() []string {
	l.mu.Lock()
	defer l.mu.Unlock()
	logs := make(string[], 0, len(l.error_logs))
	for log := range l.error_logs {
		logs = append(logs, log)
	}
	return logs
}

func (l error_logging*) clear_logs() {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.error_logs = make(string[], 0, 10000)
}

func contains(text string, substring string) bool {
	if len(substring) > len(text) {
		return false
	}
	for i := int32(0); i <= int32(len(text))-int32(len(substring)); i++ {
		match := true
		for j := int32(0); j < int32(len(substring)); j++ {
			if text[i+j] != substring[j] {
				match = false
				break
			}
		}
		if match {
			return true
		}
	}
	return false
}
