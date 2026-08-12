package neurx.scheduler.request_scheduler
struct scheduled_request {
    string request_id
    int priority
    int arrival_time
    int estimated_tokens
    float temperature
    bool preemptible
}

struct scheduler_stats {
    int total_scheduled
    int total_completed
    int total_preempted
    int avg_wait_time
    float throughput
}

struct request_scheduler {
    []scheduled_request queue
    scheduler_stats stats
    string policy
    int max_inflight
    int inflight_count
}

func new_request_scheduler(string policy, int max_inflight) request_scheduler {
    request_scheduler sched
    sched.queue = []scheduled_request{}
    sched.stats = scheduler_stats{
        total_scheduled: 0,
        total_completed: 0,
        total_preempted: 0,
        avg_wait_time: 0,
        throughput: 0.0,
    }
    sched.policy = policy
    sched.max_inflight = max_inflight
    sched.inflight_count = 0
    sched
}

func add_request(
    request_scheduler sched,
    string request_id,
    int estimated_tokens,
    float temperature,
    bool preemptible,
) request_scheduler {
    scheduled_request req
    req.request_id = request_id
    req.priority = 0
    req.arrival_time = get_current_timestamp()
    req.estimated_tokens = estimated_tokens
    req.temperature = temperature
    req.preemptible = preemptible
    sched.queue = append_request(sched.queue, req)
    sched.stats.total_scheduled = sched.stats.total_scheduled + 1
    sched
}

func schedule_next_batch(
    request_scheduler sched,
    int batch_size,
) []scheduled_request {
    if sched.inflight_count >= sched.max_inflight {
        []scheduled_request{}
    }
    batch := []scheduled_request{}
    if sched.policy == "FCFS" {
        batch = schedule_fcfs(sched, batch_size)
    }
    if sched.policy == "SJF" {
        batch = schedule_sjf(sched, batch_size)
    }
    sched.inflight_count = sched.inflight_count + batch.len
    batch
}

func schedule_fcfs(
    request_scheduler sched,
    int batch_size,
) []scheduled_request {
    batch := []scheduled_request{}
    i := 0
    while i < sched.queue.len && batch.len < batch_size {
        if sched.inflight_count + batch.len < sched.max_inflight {
            batch = append_request(batch, sched.queue[i])
            i = i + 1
        } else {
            i = sched.queue.len
        }
    }
    batch
}

func schedule_sjf(
    request_scheduler sched,
    int batch_size,
) []scheduled_request {
    batch := []scheduled_request{}
    sorted := sort_requests_by_tokens(sched.queue)
    i := 0
    while i < sorted.len && batch.len < batch_size {
        if sched.inflight_count + batch.len < sched.max_inflight {
            batch = append_request(batch, sorted[i])
            i = i + 1
        } else {
            i = sorted.len
        }
    }
    batch
}

func mark_request_complete(
    request_scheduler sched,
    string request_id,
) request_scheduler {
    sched.inflight_count = sched.inflight_count - 1
    sched.stats.total_completed = sched.stats.total_completed + 1
    new_queue := []scheduled_request{}
    i := 0
    while i < sched.queue.len {
        if sched.queue[i].request_id != request_id {
            new_queue = append_request(new_queue, sched.queue[i])
        }
        i = i + 1
    }
    sched.queue = new_queue
    sched
}

func preempt_request(
    request_scheduler sched,
    string request_id,
) request_scheduler {
    sched.stats.total_preempted = sched.stats.total_preempted + 1
    new_queue := []scheduled_request{}
    i := 0
    while i < sched.queue.len {
        curr := sched.queue[i]
        if curr.request_id == request_id && curr.preemptible {
            i = i + 1
        } else {
            new_queue = append_request(new_queue, curr)
            i = i + 1
        }
    }
    sched.queue = new_queue
    if sched.inflight_count > 0 {
        sched.inflight_count = sched.inflight_count - 1
    }
    sched
}

func get_queue_length(request_scheduler sched) int {
    sched.queue.len
}

func get_scheduler_stats(request_scheduler sched) scheduler_stats {
    sched.stats
}

func sort_requests_by_tokens([]scheduled_request reqs) []scheduled_request {
    sorted := reqs
    i := 0
    while i < sorted.len {
        j := i + 1
        while j < sorted.len {
            if sorted[i].estimated_tokens > sorted[j].estimated_tokens {
                temp := sorted[i]
                sorted[i] = sorted[j]
                sorted[j] = temp
            }
            j = j + 1
        }
        i = i + 1
    }
    sorted
}

func append_request([]scheduled_request slice, scheduled_request elem) []scheduled_request {
    new_slice := make_request_slice(slice.len + 1)
    i := 0
    while i < slice.len {
        new_slice[i] = slice[i]
        i = i + 1
    }
    new_slice[slice.len] = elem
    new_slice
}

func make_request_slice(int len) []scheduled_request {
    []scheduled_request{}
}

func get_current_timestamp() int {
    0
}

