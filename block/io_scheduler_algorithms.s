package neurx.block

struct io_scheduler_stats {
    int total_requests
    int total_sectors_read
    int total_sectors_written
    int avg_service_time_us
    int avg_wait_time_us
    int total_dispatches
    int total_completions
}

struct io_queue_entry {
    int request_id
    int device_id
    int sector_offset
    int sector_count
    bool is_read
    int priority
    int arrival_time_us
    int start_time_us
}

struct cfq_scheduler {
    io_queue_entry[] queue
    int quantum_us
    int time_slice_us
    int idle_slice_us
    int max_queues
    io_scheduler_stats stats
}

struct deadline_scheduler {
    io_queue_entry[] read_queue
    io_queue_entry[] write_queue
    int read_expire_ms
    int write_expire_ms
    int writes_starved
    io_scheduler_stats stats
}

struct bfq_scheduler {
    io_queue_entry[] queue
    int quantum_us
    int burst_detection
    int low_latency_mode
    io_scheduler_stats stats
}

func cfq_create() cfq_scheduler {
    sched := cfq_scheduler {
        queue: io_queue_entry[](),
        quantum_us: 10000,
        time_slice_us: 100000,
        idle_slice_us: 8000,
        max_queues: 64,
        stats: io_scheduler_stats {
            total_requests: 0,
            total_sectors_read: 0,
            total_sectors_written: 0,
            avg_service_time_us: 0,
            avg_wait_time_us: 0,
            total_dispatches: 0,
            total_completions: 0
        }
    }
    return sched
}

func (cfq_scheduler* sched) cfq_add_request(io_queue_entry req) {
    sched.queue = append(sched.queue, req)
    sched.stats.total_requests = sched.stats.total_requests + 1
}

func (cfq_scheduler* sched) cfq_dispatch_request() option[io_queue_entry] {
    if len(sched.queue) == 0 {
        return option::none
    }
    entry := len(sched.queue) - 1
    req := sched.queue[entry]
    sched.queue.pop()
    sched.stats.total_dispatches = sched.stats.total_dispatches + 1
    return option::some(req)
}

func (cfq_scheduler* sched) cfq_request_complete(io_queue_entry req) {
    if req.is_read {
        sched.stats.total_sectors_read = sched.stats.total_sectors_read + req.sector_count
    } else {
        sched.stats.total_sectors_written = sched.stats.total_sectors_written + req.sector_count
    }
    sched.stats.total_completions = sched.stats.total_completions + 1
}

func deadline_create() deadline_scheduler {
    sched := deadline_scheduler {
        read_queue: io_queue_entry[](),
        write_queue: io_queue_entry[](),
        read_expire_ms: 500,
        write_expire_ms: 5000,
        writes_starved: 2,
        stats: io_scheduler_stats {
            total_requests: 0,
            total_sectors_read: 0,
            total_sectors_written: 0,
            avg_service_time_us: 0,
            avg_wait_time_us: 0,
            total_dispatches: 0,
            total_completions: 0
        }
    }
    return sched
}

func (deadline_scheduler* sched) deadline_add_request(io_queue_entry req) {
    if req.is_read {
        sched.read_queue = append(sched.read_queue, req)
    } else {
        sched.write_queue = append(sched.write_queue, req)
    }
    sched.stats.total_requests = sched.stats.total_requests + 1
}

func (deadline_scheduler* sched) deadline_dispatch() option[io_queue_entry] {
    if len(sched.read_queue) > 0 {
        req := sched.read_queue[0]
        sched.read_queue.pop()
        sched.stats.total_dispatches = sched.stats.total_dispatches + 1
        return option::some(req)
    }
    if len(sched.write_queue) > 0 {
        req := sched.write_queue[0]
        sched.write_queue.pop()
        sched.stats.total_dispatches = sched.stats.total_dispatches + 1
        return option::some(req)
    }
    return option::none
}

func (deadline_scheduler* sched) deadline_complete(io_queue_entry req) {
    if req.is_read {
        sched.stats.total_sectors_read = sched.stats.total_sectors_read + req.sector_count
    } else {
        sched.stats.total_sectors_written = sched.stats.total_sectors_written + req.sector_count
    }
    sched.stats.total_completions = sched.stats.total_completions + 1
}

func bfq_create() bfq_scheduler {
    sched := bfq_scheduler {
        queue: io_queue_entry[](),
        quantum_us: 8000,
        burst_detection: 0,
        low_latency_mode: 1,
        stats: io_scheduler_stats {
            total_requests: 0,
            total_sectors_read: 0,
            total_sectors_written: 0,
            avg_service_time_us: 0,
            avg_wait_time_us: 0,
            total_dispatches: 0,
            total_completions: 0
        }
    }
    return sched
}

func (bfq_scheduler* sched) bfq_add_request(io_queue_entry req) {
    sched.queue = append(sched.queue, req)
    sched.stats.total_requests = sched.stats.total_requests + 1
}

func (bfq_scheduler* sched) bfq_dispatch() option[io_queue_entry] {
    if len(sched.queue) == 0 {
        return option::none
    }
    req := sched.queue[0]
    sched.queue.pop()
    sched.stats.total_dispatches = sched.stats.total_dispatches + 1
    return option::some(req)
}

func (bfq_scheduler* sched) bfq_complete(io_queue_entry req) {
    if req.is_read {
        sched.stats.total_sectors_read = sched.stats.total_sectors_read + req.sector_count
    } else {
        sched.stats.total_sectors_written = sched.stats.total_sectors_written + req.sector_count
    }
    sched.stats.total_completions = sched.stats.total_completions + 1
}
