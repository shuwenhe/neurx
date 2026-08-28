package openai_api
import "sync"
import "time"
struct token_usage {
	int64   prompt_tokens
	int64   completion_tokens
	int64   total_tokens
	int64   cache_read_tokens
	int64   cache_creation_tokens
}

struct request_usage_record {
	string          request_id
	string          user_id
	string          model_id
	int64           timestamp
	int64           duration_ms
	token_usage     tokens
	string          endpoint
	string          method
	int32           status_code
	string          error_code
}

struct user_quota {
	string          user_id
	int64           monthly_limit
	int64           daily_limit
	int64           hourly_limit
	int64           monthly_used
	int64           daily_used
	int64           hourly_used
	int64           last_reset_time
	bool            is_limited
}

struct usage_tracker {
	request_usage_record[]   records
	map[string]user_quota       user_quotas
	int64                       total_tokens_used
	int64                       total_requests
	map[string]int64            model_usage
	map[string]int64            endpoint_usage
	sync.Mutex                  mu
}

func create_usage_tracker() usage_tracker {
	return usage_tracker{
		records:           make(request_usage_record[], 0, 10000),
		user_quotas:       make(map[string]user_quota),
		total_tokens_used: 0,
		total_requests:    0,
		model_usage:       make(map[string]int64),
		endpoint_usage:    make(map[string]int64),
		mu:                sync.Mutex{},
	}
}

func (t usage_tracker*) record_request(
	request_id string,
	user_id string,
	model_id string,
	tokens token_usage,
	endpoint string,
	duration_ms int64,
	status_code int32,
) bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	record := request_usage_record{
		request_id:  request_id,
		user_id:     user_id,
		model_id:    model_id,
		timestamp:   time.Now().UnixNano(),
		duration_ms: duration_ms,
		tokens:      tokens,
		endpoint:    endpoint,
		status_code: status_code,
	}
	t.records = append(t.records, record)
	t.total_tokens_used += tokens.total_tokens
	t.total_requests++
	if _, exists := t.model_usage[model_id]; !exists {
		t.model_usage[model_id] = 0
	}
	t.model_usage[model_id] += tokens.total_tokens
	if _, exists := t.endpoint_usage[endpoint]; !exists {
		t.endpoint_usage[endpoint] = 0
	}
	t.endpoint_usage[endpoint]++
	if len(user_id) > 0 {
		t.update_user_quota(user_id, tokens.total_tokens)
	}
	return true
}

func (t usage_tracker*) update_user_quota(user_id string, tokens_used int64) bool {
	quota, exists := t.user_quotas[user_id]
	if !exists {
		quota = user_quota{
			user_id:        user_id,
			monthly_limit:  1000000,
			daily_limit:    100000,
			hourly_limit:   10000,
			last_reset_time: time.Now().UnixNano(),
		}
	}
	quota.monthly_used += tokens_used
	quota.daily_used += tokens_used
	quota.hourly_used += tokens_used
	if quota.daily_used > quota.daily_limit {
		quota.is_limited = true
	}
	t.user_quotas[user_id] = quota
	return !quota.is_limited
}

func (t usage_tracker*) check_user_quota(user_id string) (bool, int64) {
	t.mu.Lock()
	defer t.mu.Unlock()
	quota, exists := t.user_quotas[user_id]
	if !exists {
		return true, 0
	}
	available := quota.daily_limit - quota.daily_used
	if available < 0 {
		available = 0
	}
	return available > 0, available
}

func (t usage_tracker*) get_user_usage_stats(user_id string) (token_usage, bool) {
	t.mu.Lock()
	defer t.mu.Unlock()
	total_prompt := int64(0)
	total_completion := int64(0)
	total_tokens := int64(0)
	for record := range t.records {
		if record.user_id == user_id {
			total_prompt += record.tokens.prompt_tokens
			total_completion += record.tokens.completion_tokens
			total_tokens += record.tokens.total_tokens
		}
	}
	return token_usage{
		prompt_tokens:     total_prompt,
		completion_tokens: total_completion,
		total_tokens:      total_tokens,
	}, total_tokens > 0
}

func (t usage_tracker*) get_model_usage_stats(model_id string) int64 {
	t.mu.Lock()
	defer t.mu.Unlock()
	usage, exists := t.model_usage[model_id]
	if !exists {
		return 0
	}
	return usage
}

func (t usage_tracker*) get_endpoint_usage_stats(endpoint string) int64 {
	t.mu.Lock()
	defer t.mu.Unlock()
	usage, exists := t.endpoint_usage[endpoint]
	if !exists {
		return 0
	}
	return usage
}

func (t usage_tracker*) get_total_usage() (int64, int64) {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.total_requests, t.total_tokens_used
}

func (t usage_tracker*) get_usage_report() map[string]interface{} {
	t.mu.Lock()
	defer t.mu.Unlock()
	avg_tokens_per_request := int64(0)
	if t.total_requests > 0 {
		avg_tokens_per_request = t.total_tokens_used / t.total_requests
	}
	report := map[string]interface{}{
		"total_requests": t.total_requests,
		"total_tokens_used": t.total_tokens_used,
		"avg_tokens_per_request": avg_tokens_per_request,
		"unique_users": len(t.user_quotas),
		"models_used": len(t.model_usage),
		"endpoints_used": len(t.endpoint_usage),
	}
	return report
}

struct usage_limiter {
	max_requests_per_minute int32
	max_tokens_per_minute   int32
	current_minute_start    int64
	requests_this_minute    int32
	tokens_this_minute      int64
	mu                      sync.Mutex
}

func create_usage_limiter(
	max_requests int32,
	max_tokens int32,
) usage_limiter {
	return usage_limiter{
		max_requests_per_minute: max_requests,
		max_tokens_per_minute:   max_tokens,
		current_minute_start:    time.Now().UnixNano(),
		requests_this_minute:    0,
		tokens_this_minute:      0,
		mu:                      sync.Mutex{},
	}
}

func (l usage_limiter*) check_limits(tokens_requested int32) (bool, string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := time.Now().UnixNano()
	elapsed_ms := (now - l.current_minute_start) / 1000000
	if elapsed_ms > 60000 {
		l.current_minute_start = now
		l.requests_this_minute = 0
		l.tokens_this_minute = 0
	}
	if l.requests_this_minute >= l.max_requests_per_minute {
		return false, "rate_limit_exceeded_requests"
	}
	if l.tokens_this_minute+int64(tokens_requested) > int64(l.max_tokens_per_minute) {
		return false, "rate_limit_exceeded_tokens"
	}
	return true, ""
}

func (l usage_limiter*) record_usage(tokens_used int32) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.requests_this_minute++
	l.tokens_this_minute += int64(tokens_used)
}

func (l usage_limiter*) get_remaining_quota() (int32, int64) {
	l.mu.Lock()
	defer l.mu.Unlock()
	remaining_requests := l.max_requests_per_minute - l.requests_this_minute
	if remaining_requests < 0 {
		remaining_requests = 0
	}
	remaining_tokens := int64(l.max_tokens_per_minute) - l.tokens_this_minute
	if remaining_tokens < 0 {
		remaining_tokens = 0
	}
	return remaining_requests, remaining_tokens
}

struct usage_aggregator {
	daily_stats    map[string]token_usage
	hourly_stats   map[string]token_usage
	mu             sync.Mutex
}

func create_usage_aggregator() usage_aggregator {
	return usage_aggregator{
		daily_stats:  make(map[string]token_usage),
		hourly_stats: make(map[string]token_usage),
		mu:           sync.Mutex{},
	}
}

func (a usage_aggregator*) aggregate_daily(date string, stats token_usage) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.daily_stats[date] = stats
}

func (a usage_aggregator*) aggregate_hourly(hour string, stats token_usage) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.hourly_stats[hour] = stats
}

func (a usage_aggregator*) get_daily_stats(date string) (token_usage, bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	stats, exists := a.daily_stats[date]
	return stats, exists
}

func (a usage_aggregator*) get_hourly_stats(hour string) (token_usage, bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	stats, exists := a.hourly_stats[hour]
	return stats, exists
}
