package neurx.scheduler.advanced_scheduler
func new_request(int req_id, int input_len, int max_len) int[] {
    int[] req = int[]{req_id, 0, input_len, max_len, 0, 0, 0, input_len}
    return req
}
func get_req_id(int[] req) int {
    return req[0]
}
func get_req_status(int[] req) int {
    return req[1]
}
func get_input_tokens(int[] req) int {
    return req[2]
}
func get_max_tokens(int[] req) int {
    return req[3]
}
func get_priority(int[] req) int {
    return req[4]
}
func get_arrival_time(int[] req) int {
    return req[5]
}
func get_processed_tokens(int[] req) int {
    return req[6]
}
func get_seq_len(int[] req) int {
    return req[7]
}
func set_priority(int[] req, int priority) int[] {
    req[4] = priority
    return req
}
func set_status(int[] req, int status) int[] {
    req[1] = status
    return req
}
func calculate_sjf_priority(int[] req) int {
    int remaining = get_max_tokens(req) - get_processed_tokens(req)
    if remaining < 0 {
        remaining = 0
    }
    return remaining
}
func calculate_priority_priority(int[] req) int {
    return get_priority(req)
}
func calculate_length_aware_priority(int[] req) int {
    int status = get_req_status(req)
    if status == 0 {
        int input_len = get_input_tokens(req)
        return input_len
    }
    if status == 1 {
        return 1000
    }
    if status == 2 {
        int remaining = get_max_tokens(req) - get_processed_tokens(req)
        return 10000 - remaining
    }
    return 999999
}
func calculate_wait_time_priority(int[] req, int current_time) int {
    int arrival = get_arrival_time(req)
    int wait_time = current_time - arrival
    if wait_time < 100 {
        return 0
    }
    if wait_time < 500 {
        return 1
    }
    if wait_time < 1000 {
        return 2
    }
    return 3
}
func new_scheduler_state(int max_prefill, int max_decode, int policy) int[] {
    int[] state = int[]{max_prefill, max_decode, policy, 0, 0, 0}
    return state
}
func get_max_prefill(int[] state) int {
    return state[0]
}
func get_max_decode(int[] state) int {
    return state[1]
}
func get_policy(int[] state) int {
    return state[2]
}
func get_scheduled_prefill(int[] state) int {
    return state[3]
}
func get_scheduled_decode(int[] state) int {
    return state[4]
}
func get_iteration_count(int[] state) int {
    return state[5]
}
func select_requests_for_prefill(int[][] requests, int[] scheduler_state, int current_time) int[] {
    int max_prefill = get_max_prefill(scheduler_state)
    int policy = get_policy(scheduler_state)
    int[] candidates = []
    int i = 0
    for i < len(requests) {
        if requests[i][1] == 0 {
            candidates = append(candidates, i)
        }
        i = i + 1
    }
    if policy == 0 {
        int count = 0
        int[] result = int[]{}
        i = 0
        for i < len(candidates) {
            if count >= max_prefill {
                break
            }
            result = append(result, candidates[i])
            count = count + 1
            i = i + 1
        }
        return result
    }
    if policy == 1 {
        int min_idx = 0
        int min_val = 999999
        i = 0
        for i < len(candidates) {
            int idx = candidates[i]
            int remaining = get_max_tokens(requests[idx]) - get_processed_tokens(requests[idx])
            if remaining < min_val {
                min_val = remaining
                min_idx = i
            }
            i = i + 1
        }
        if len(candidates) > 0 {
            int[] result = []
            int min_element = candidates[min_idx]
            result = append(result, min_element)
            return result
        }
        int[] empty_result = int[]{}
        return empty_result
    }
    int[] result = int[]{}
    int count = 0
    i = 0
    for i < len(candidates) {
        if count >= max_prefill {
            break
        }
        result = append(result, candidates[i])
        count = count + 1
        i = i + 1
    }
    return result
}
func select_requests_for_decode(int[][] requests, int[] scheduler_state) int[] {
    int max_decode = get_max_decode(scheduler_state)
    int policy = get_policy(scheduler_state)
    int[] candidates = int[]{}
    int i = 0
    for i < len(requests) {
        if requests[i][1] == 2 {
            candidates = append(candidates, i)
        }
        i = i + 1
    }
    if policy == 1 {
        int min_idx = 0
        int min_remaining = 999999
        i = 0
        for i < len(candidates) {
            int idx = candidates[i]
            int remaining = get_max_tokens(requests[idx]) - get_processed_tokens(requests[idx])
            if remaining < min_remaining {
                min_remaining = remaining
                min_idx = i
            }
            i = i + 1
        }
        if len(candidates) > 0 {
            int[] result = []
            int min_element = candidates[min_idx]
            result = append(result, min_element)
            return result
        }
        return []
    }
    int[] result = int[]{}
    int count = 0
    i = 0
    for i < len(candidates) {
        if count >= max_decode {
            break
        }
        result = append(result, candidates[i])
        count = count + 1
        i = i + 1
    }
    return result
}
func form_prefill_batch(int[][] requests, int[] prefill_indices) int[][] {
    int[][] batch = []
    int i = 0
    for i < len(prefill_indices) {
        int idx = prefill_indices[i]
        batch = append(batch, requests[idx])
        i = i + 1
    }
    return batch
}
func form_decode_batch(int[][] requests, int[] decode_indices) int[][] {
    int[][] batch = []
    int i = 0
    for i < len(decode_indices) {
        int idx = decode_indices[i]
        batch = append(batch, requests[idx])
        i = i + 1
    }
    return batch
}
func calculate_batch_tokens(int[][] batch) int {
    int total = 0
    int i = 0
    for i < len(batch) {
        int seq_len = get_seq_len(batch[i])
        total = total + seq_len
        i = i + 1
    }
    return total
}
func calculate_batch_utilization(int[][] batch, int max_batch_tokens) float {
    int tokens = calculate_batch_tokens(batch)
    if max_batch_tokens <= 0 {
        return 0.0
    }
    return float(tokens) / float(max_batch_tokens)
}
func update_request_after_iteration(int[] req, int tokens_generated) int[] {
    req[6] = req[6] + tokens_generated
    if req[6] >= req[3] {
        req[1] = 3
    }
    return req
}
func update_requests_batch(int[][] requests, int[] batch_indices, int tokens_per_req) int[][] {
    int[][] updated = []
    int i = 0
    for i < len(requests) {
        int j = 0
        bool in_batch = false
        for j < len(batch_indices) {
            if batch_indices[j] == i {
                in_batch = true
                break
            }
            j = j + 1
        }
        int[] req = requests[i]
        if in_batch {
            req = update_request_after_iteration(req, tokens_per_req)
        }
        updated = append(updated, req)
        i = i + 1
    }
    return updated
}
func get_scheduler_metrics(int[][] requests, int[] scheduler_state) string {
    int total_requests = len(requests)
    int waiting = 0
    int prefilling = 0
    int decoding = 0
    int finished = 0
    int i = 0
    for i < len(requests) {
        int status = requests[i][1]
        if status == 0 {
            waiting = waiting + 1
        } else {
            if status == 1 {
                prefilling = prefilling + 1
            } else {
                if status == 2 {
                    decoding = decoding + 1
                } else {
                    if status == 3 {
                        finished = finished + 1
                    }
                }
            }
        }
        i = i + 1
    }
    string metrics = "SchedulerMetrics: Total="
    metrics = metrics + string(total_requests)
    metrics = metrics + " Waiting="
    metrics = metrics + string(waiting)
    metrics = metrics + " Prefilling="
    metrics = metrics + string(prefilling)
    metrics = metrics + " Decoding="
    metrics = metrics + string(decoding)
    metrics = metrics + " Finished="
    metrics = metrics + string(finished)
    return metrics
}
func format_policy_name(int policy) string {
    if policy == 0 {
        return "FIFO"
    }
    if policy == 1 {
        return "SJF"
    }
    if policy == 2 {
        return "PRIORITY"
    }
    if policy == 3 {
        return "LENGTH_AWARE"
    }
    return "UNKNOWN"
}
func estimate_completion_time(int[] req, int tokens_per_sec) int {
    int remaining = get_max_tokens(req) - get_processed_tokens(req)
    if remaining <= 0 {
        return 0
    }
    if tokens_per_sec <= 0 {
        return 999999
    }
    return remaining / tokens_per_sec
}
func is_request_stalled(int[] req, int current_time, int stall_threshold) bool {
    int arrival = get_arrival_time(req)
    int wait_time = current_time - arrival
    return wait_time > stall_threshold && get_req_status(req) == 0
}
