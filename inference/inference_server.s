package neurx.inference.inference_server
use neurx.inference.kv_cache_manager.{paged_kv_cache, new_paged_kv_cache, new_kv_cache_config}
use neurx.inference.sampling_strategies.{sampling_config, new_sampling_config}
struct inference_request {
    string request_id
    string prompt
    int max_tokens
    sampling_config sampling
    int priority
    int created_at_timestamp_ms
}

struct inference_response {
    string request_id
    string generated_text
    int generated_tokens
    float generation_time_ms
    []float token_logprobs
}

struct batch_scheduler {
    []inference_request pending_requests
    []inference_request active_requests
    paged_kv_cache kv_cache
    int max_batch_size
    int max_total_tokens
    int current_batch_tokens
}

struct inference_server {
    batch_scheduler scheduler
    int num_inference_workers
    bool streaming_enabled
    float target_batch_time_ms
    int max_queue_size
    int requests_processed
    int requests_failed
    int total_tokens_generated
    float avg_generation_time_ms
    float gpu_utilization_percent
}

struct server_stats {
    int requests_processed
    int requests_failed
    int total_tokens_generated
    float avg_generation_time_ms
    float avg_tokens_per_second
    float gpu_utilization_percent
}

func server_request_score(inference_request req) int {
    int priority_score = req.priority * 1000000
    int length_penalty = 0 - (req.max_tokens * 1000)
    int time_penalty = 0 - req.created_at_timestamp_ms
    priority_score + length_penalty + time_penalty
}

func server_request_list_copy([]inference_request requests) []inference_request {
    []inference_request copied = []inference_request{}
    int i = 0
    while i < len(requests) {
        copied = append(copied, requests[i])
        i = i + 1
    }
    copied
}

func server_remove_request_at([]inference_request requests, int index) []inference_request {
    []inference_request filtered = []inference_request{}
    int i = 0
    while i < len(requests) {
        if i != index {
            filtered = append(filtered, requests[i])
        }
        i = i + 1
    }
    filtered
}

func server_remove_requests_by_id([]inference_request requests, []inference_request selected) []inference_request {
    []inference_request remaining = []inference_request{}
    int i = 0
    while i < len(requests) {
        bool is_selected = false
        int j = 0
        while j < len(selected) {
            if requests[i].request_id == selected[j].request_id {
                is_selected = true
                break
            }
            j = j + 1
        }
        if !is_selected {
            remaining = append(remaining, requests[i])
        }
        i = i + 1
    }
    remaining
}

func server_best_request_index([]inference_request requests) int {
    if len(requests) == 0 {
        return -1
    }
    int best_index = 0
    int best_score = server_request_score(requests[0])
    int i = 1
    while i < len(requests) {
        int score = server_request_score(requests[i])
        if score > best_score {
            best_score = score
            best_index = i
        }
        i = i + 1
    }
    best_index
}

func prioritize_requests([]inference_request requests) []inference_request {
    []inference_request ordered = server_request_list_copy(requests)
    int i = 0
    while i < len(ordered) {
        int best_index = i
        int j = i + 1
        while j < len(ordered) {
            if server_request_score(ordered[j]) > server_request_score(ordered[best_index]) {
                best_index = j
            }
            j = j + 1
        }
        if best_index != i {
            inference_request tmp = ordered[i]
            ordered[i] = ordered[best_index]
            ordered[best_index] = tmp
        }
        i = i + 1
    }
    ordered
}

func new_batch_scheduler(int max_batch_size, int max_total_tokens) batch_scheduler {
    batch_scheduler {
        pending_requests: []inference_request{},
        active_requests: []inference_request{},
        kv_cache: new_paged_kv_cache(new_kv_cache_config()),
        max_batch_size: max_batch_size,
        max_total_tokens: max_total_tokens,
        current_batch_tokens: 0,
    }
}

func new_inference_server(int num_workers) inference_server {
    inference_server {
        scheduler: new_batch_scheduler(64, 100000),
        num_inference_workers: num_workers,
        streaming_enabled: true,
        target_batch_time_ms: 100.0,
        max_queue_size: 1000,
        requests_processed: 0,
        requests_failed: 0,
        total_tokens_generated: 0,
        avg_generation_time_ms: 0.0,
        gpu_utilization_percent: 0.0,
    }
}

func submit_request(inference_server server, inference_request req) bool {
    if len(server.scheduler.pending_requests) >= server.max_queue_size {
        server.requests_failed = server.requests_failed + 1
        return false
    }
    if req.created_at_timestamp_ms < 0 {
        req.created_at_timestamp_ms = 0
    }
    server.scheduler.pending_requests = append(server.scheduler.pending_requests, req)
    true
}

func select_batch(batch_scheduler scheduler) []inference_request {
    if len(scheduler.pending_requests) == 0 {
        return []inference_request{}
    }
    []inference_request ordered = prioritize_requests(scheduler.pending_requests)
    int take_count = scheduler.max_batch_size
    if take_count > len(ordered) {
        take_count = len(ordered)
    }
    []inference_request batch = []inference_request{}
    int current_tokens = 0
    int i = 0
    while i < take_count {
        inference_request req = ordered[i]
        if current_tokens + req.max_tokens > scheduler.max_total_tokens && len(batch) > 0 {
            break
        }
        batch = append(batch, req)
        current_tokens = current_tokens + req.max_tokens
        scheduler.active_requests = append(scheduler.active_requests, req)
        i = i + 1
    }
    scheduler.pending_requests = server_remove_requests_by_id(scheduler.pending_requests, batch)
    scheduler.current_batch_tokens = current_tokens
    batch
}

func execute_batch(batch_scheduler scheduler, []inference_request batch) []inference_response {
    []inference_response responses = []inference_response{}
    int i = 0
    while i < len(batch) {
        inference_request req = batch[i]
        inference_response resp {
            request_id: req.request_id,
            generated_text: req.prompt + " [neurx batch]",
            generated_tokens: req.max_tokens,
            generation_time_ms: estimate_generation_time(req),
            token_logprobs: []float{},
        }
        responses = append(responses, resp)
        i = i + 1
    }
    scheduler.active_requests = []
    scheduler.current_batch_tokens = 0
    responses
}

func schedule_continuous_batching(inference_server server) int {
    int processed = 0
    while len(server.scheduler.pending_requests) > 0 {
        []inference_request batch = select_batch(server.scheduler)
        if len(batch) == 0 {
            break
        }
        if server.scheduler.max_total_tokens > 0 {
            server.gpu_utilization_percent = (
                float(server.scheduler.current_batch_tokens) /
                float(server.scheduler.max_total_tokens)
            ) * 100.0
        }
        []inference_response responses = execute_batch(server.scheduler, batch)
        int i = 0
        while i < len(responses) {
            server.requests_processed = server.requests_processed + 1
            server.total_tokens_generated = server.total_tokens_generated + responses[i].generated_tokens
            int request_count = server.requests_processed
            if request_count > 0 {
                server.avg_generation_time_ms = (
                    server.avg_generation_time_ms * float(request_count - 1) +
                    responses[i].generation_time_ms
                ) / float(request_count)
            }
            i = i + 1
        }
        processed = processed + len(responses)
    }
    processed
}

func stream_response(inference_request req, inference_response resp) string {
    resp.generated_text
}

func adjust_batch_size(server_stats stats, int current_batch_size) int {
    int next_batch_size = current_batch_size
    if stats.gpu_utilization_percent > 85.0 {
        next_batch_size = next_batch_size - 1
    } else if stats.gpu_utilization_percent < 55.0 && stats.avg_generation_time_ms < 250.0 {
        next_batch_size = next_batch_size + 1
    }
    if next_batch_size < 1 {
        next_batch_size = 1
    }
    if next_batch_size > 256 {
        next_batch_size = 256
    }
    next_batch_size
}

func prefill_decode_overlap(batch_scheduler scheduler) bool {
    len(scheduler.pending_requests) > 0 && len(scheduler.active_requests) > 0
}

func get_server_stats(inference_server server) server_stats {
    float total_generation_seconds = (
        server.avg_generation_time_ms * float(server.requests_processed)
    ) / 1000.0
    float avg_tps = 0.0
    if total_generation_seconds > 0.0 {
        avg_tps = float(server.total_tokens_generated) / total_generation_seconds
    }
    server_stats {
        requests_processed: server.requests_processed,
        requests_failed: server.requests_failed,
        total_tokens_generated: server.total_tokens_generated,
        avg_generation_time_ms: server.avg_generation_time_ms,
        avg_tokens_per_second: avg_tps,
        gpu_utilization_percent: server.gpu_utilization_percent,
    }
}

func shutdown_server(inference_server server) bool {
    server.scheduler.pending_requests = []
    server.scheduler.active_requests = []
    server.scheduler.current_batch_tokens = 0
    true
}

func health_check(inference_server server) bool {
    server.max_queue_size > 0 && server.scheduler.max_batch_size > 0
}
