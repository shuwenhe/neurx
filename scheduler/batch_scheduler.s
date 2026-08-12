package neurx.scheduler.batch_scheduler
func new_batch_request(int req_id) []int {
    []int req = []int{req_id, 0, 0, 0}
    return req
}

func get_req_id([]int req) int {
    return req[0]
}

func get_req_status([]int req) int {
    return req[1]
}

func get_req_tokens([]int req) int {
    return req[2]
}

func get_req_step([]int req) int {
    return req[3]
}

func set_req_status([]int req, int status) []int {
    req[1] = status
    return req
}

func set_req_tokens([]int req, int tokens) []int {
    req[2] = tokens
    return req
}

func increment_req_step([]int req) []int {
    req[3] = req[3] + 1
    return req
}

func new_scheduler_state(int max_prefill, int max_decode) []int {
    []int state = []int{0, max_prefill, max_decode, 0, 0}
    return state
}

func add_request_to_queue([][]int queue, []int req) [][]int {
    [][]int new_queue = append(queue, req)
    return new_queue
}

func count_waiting_requests([][]int queue) int {
    int count = 0
    int i = 0
    for i < len(queue) {
        if queue[i][1] == 0 {
            count = count + 1
        }
        i = i + 1
    }
    return count
}

func count_prefill_requests([][]int queue) int {
    int count = 0
    int i = 0
    for i < len(queue) {
        if queue[i][1] == 1 {
            count = count + 1
        }
        i = i + 1
    }
    return count
}

func count_decode_requests([][]int queue) int {
    int count = 0
    int i = 0
    for i < len(queue) {
        if queue[i][1] == 2 {
            count = count + 1
        }
        i = i + 1
    }
    return count
}

func count_finished_requests([][]int queue) int {
    int count = 0
    int i = 0
    for i < len(queue) {
        if queue[i][1] == 3 {
            count = count + 1
        }
        i = i + 1
    }
    return count
}

func select_prefill_requests([][]int queue, int capacity) []int {
    []int selected = []
    int count = 0
    int i = 0
    for i < len(queue) {
        if count >= capacity {
            break
        }
        if queue[i][1] == 0 {
            selected = append(selected, i)
            count = count + 1
        }
        i = i + 1
    }
    return selected
}

func select_decode_requests([][]int queue, int capacity) []int {
    []int selected = []
    int count = 0
    int i = 0
    for i < len(queue) {
        if count >= capacity {
            break
        }
        if queue[i][1] == 2 {
            selected = append(selected, i)
            count = count + 1
        }
        i = i + 1
    }
    return selected
}

func get_batch_info([][]int queue, []int indices) string {
    string info = "Batch(n="
    info = info + string(len(indices)) + ")"
    return info
}

func update_prefill_batch([][]int queue, []int prefill_indices) [][]int {
    int i = 0
    for i < len(prefill_indices) {
        int idx = prefill_indices[i]
        queue[idx][1] = 1
        i = i + 1
    }
    return queue
}

func update_decode_batch([][]int queue, []int decode_indices) [][]int {
    int i = 0
    for i < len(decode_indices) {
        int idx = decode_indices[i]
        queue[idx][1] = 2
        i = i + 1
    }
    return queue
}

func mark_finished([][]int queue, []int finished_indices) [][]int {
    int i = 0
    for i < len(finished_indices) {
        int idx = finished_indices[i]
        queue[idx][1] = 3
        i = i + 1
    }
    return queue
}

func get_scheduler_stats([][]int queue) string {
    int total = len(queue)
    int waiting = count_waiting_requests(queue)
    int prefill = count_prefill_requests(queue)
    int decode = count_decode_requests(queue)
    int finished = count_finished_requests(queue)
    string stats = "Scheduler: Total="
    stats = stats + string(total)
    stats = stats + " Waiting="
    stats = stats + string(waiting)
    stats = stats + " Prefill="
    stats = stats + string(prefill)
    stats = stats + " Decode="
    stats = stats + string(decode)
    stats = stats + " Finished="
    stats = stats + string(finished)
    return stats
}

func get_prefill_indices([][]int queue, int prefill_capacity) []int {
    return select_prefill_requests(queue, prefill_capacity)
}

func get_decode_indices([][]int queue, int decode_capacity) []int {
    return select_decode_requests(queue, decode_capacity)
}

