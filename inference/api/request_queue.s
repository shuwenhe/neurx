package neurx.inference.api.request_queue
struct request_item {
    string request_id
    string prompt
    int max_tokens
    float timestamp_ms
    int priority
    int retry_count
}
struct queue_stats {
    int total_requests
    int pending_requests
    int completed_requests
    int failed_requests
    float avg_wait_time_ms
}
struct request_queue {
    []request_item items
    int max_queue_size
    int timeout_ms
}
func create_request_queue(int max_size, int timeout_ms) request_queue {
    return request_queue{
        items: []request_item{},
        max_queue_size: max_size,
        timeout_ms: timeout_ms,
    }
}
func enqueue_request(request_queue queue, request_item item) bool {
    if len(queue.items) >= queue.max_queue_size {
        print("error: request queue full\n")
        return false
    }
    queue.items = append(queue.items, item)
    return true
}
func dequeue_request(request_queue queue) request_item {
    if len(queue.items) == 0 {
        return request_item{
            request_id: "",
            prompt: "",
            max_tokens: 0,
            timestamp_ms: 0.0,
            priority: 0,
            retry_count: 0,
        }
    }
    item := queue.items[0]
    new_items := []request_item{}
    for i := 1; i < len(queue.items); i++ {
        new_items = append(new_items, queue.items[i])
    }
    queue.items = new_items
    return item
}
func peek_request(request_queue queue) request_item {
    if len(queue.items) == 0 {
        return request_item{
            request_id: "",
            prompt: "",
            max_tokens: 0,
            timestamp_ms: 0.0,
            priority: 0,
            retry_count: 0,
        }
    }
    return queue.items[0]
}
func queue_size(request_queue queue) int {
    return len(queue.items)
}
func is_queue_empty(request_queue queue) bool {
    return len(queue.items) == 0
}
func is_queue_full(request_queue queue) bool {
    return len(queue.items) >= queue.max_queue_size
}
func clear_queue(request_queue queue) {
    queue.items = []request_item{}
}
func get_queue_stats(request_queue queue) queue_stats {
    return queue_stats{
        total_requests: len(queue.items),
        pending_requests: len(queue.items),
        completed_requests: 0,
        failed_requests: 0,
        avg_wait_time_ms: 0.0,
    }
}
func prioritize_queue(request_queue queue) {
    for i := 0; i < len(queue.items)-1; i++ {
        for j := 0; j < len(queue.items)-i-1; j++ {
            if queue.items[j].priority < queue.items[j+1].priority {
                temp := queue.items[j]
                queue.items[j] = queue.items[j+1]
                queue.items[j+1] = temp
            }
        }
    }
}
func remove_expired_requests(request_queue queue, float current_time_ms) {
    new_items := []request_item{}
    for i := 0; i < len(queue.items); i++ {
        item := queue.items[i]
        elapsed := current_time_ms - item.timestamp_ms
        if elapsed < float(queue.timeout_ms) {
            new_items = append(new_items, item)
        } else {
            print("removed expired request: " + item.request_id + "\n")
        }
    }
    queue.items = new_items
}
func retry_failed_request(request_queue queue, string request_id) bool {
    for i := 0; i < len(queue.items); i++ {
        if queue.items[i].request_id == request_id {
            queue.items[i].retry_count = queue.items[i].retry_count + 1
            if queue.items[i].retry_count <= 3 {
                queue.items[i].timestamp_ms = 0.0
                return true
            } else {
                print("max retries exceeded for request: " + request_id + "\n")
                return false
            }
        }
    }
    return false
}
func find_request_by_id(request_queue queue, string request_id) request_item {
    for i := 0; i < len(queue.items); i++ {
        if queue.items[i].request_id == request_id {
            return queue.items[i]
        }
    }
    return request_item{
        request_id: "",
        prompt: "",
        max_tokens: 0,
        timestamp_ms: 0.0,
        priority: 0,
        retry_count: 0,
    }
}
func batch_requests(request_queue queue, int batch_size) [][]request_item {
    batches := [][]request_item{}
    for i := 0; i < len(queue.items); i = i + batch_size {
        end := i + batch_size
        if end > len(queue.items) {
            end = len(queue.items)
        }
        batch := []request_item{}
        for j := i; j < end; j++ {
            batch = append(batch, queue.items[j])
        }
        batches = append(batches, batch)
    }
    return batches
}
func print_queue_info(request_queue queue) {
    print("📊 Request Queue Status:\n")
    print("   Total items: " + int_to_string(len(queue.items)) + "\n")
    print("   Max size: " + int_to_string(queue.max_queue_size) + "\n")
    print("   Utilization: " + int_to_string((len(queue.items) * 100) / queue.max_queue_size) + "%\n")
    if len(queue.items) > 0 {
        print("   Next request ID: " + queue.items[0].request_id + "\n")
    }
    print("\n")
}
func int_to_string(int val) string {
    if val == 0 { return "0" }
    string res = ""
    int cur = val
    if cur < 0 { cur = -cur }
    while cur != 0 {
        int d = cur - (cur / 10) * 10
        res = string_at_index("0123456789", d) + res
        cur = cur / 10
    }
    return res
}
func string_at_index(string s, int idx) string {
    if idx < 0 || idx >= len(s) { return "" }
    return string(s[idx : idx+1])
}
