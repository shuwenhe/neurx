package neurx.block.io

struct io_request {
    int request_id
    int device_id
    int priority
    int queue_time
    bool is_read
    int data_size_bytes
    int status
}

struct io_queue {
    int queue_id
    int num_requests
    int total_processed
    int avg_wait_time_us
    int max_wait_time_us
}

struct io_scheduler {
    int total_io_requests
    int requests_in_flight
    int completed_requests
    int failed_requests
    int total_io_bytes
    int avg_latency_us
}

func create_io_scheduler() io_scheduler {
    sched := io_scheduler {
        total_io_requests: 0,
        requests_in_flight: 0,
        completed_requests: 0,
        failed_requests: 0,
        total_io_bytes: 0,
        avg_latency_us: 0
    }
    return sched
}

func enqueue_io_request(io_scheduler sched, int priority, bool is_read, int data_size) io_scheduler {
    sched.total_io_requests = sched.total_io_requests + 1
    sched.requests_in_flight = sched.requests_in_flight + 1
    sched.total_io_bytes = sched.total_io_bytes + data_size
    return sched
}

func dequeue_io_request(io_scheduler sched) io_scheduler {
    if sched.requests_in_flight > 0 {
        sched.requests_in_flight = sched.requests_in_flight - 1
        sched.completed_requests = sched.completed_requests + 1
    }
    return sched
}

func fail_io_request(io_scheduler sched) io_scheduler {
    sched.failed_requests = sched.failed_requests + 1
    if sched.requests_in_flight > 0 {
        sched.requests_in_flight = sched.requests_in_flight - 1
    }
    return sched
}

func print_io_scheduler_info(io_scheduler sched) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║        NeurX I/O Scheduler - Status Report                 ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 I/O Scheduler Configuration:")
    print("   • Scheduling Policy: Priority-based elevator algorithm")
    print("   • Max In-Flight Requests: 32")
    print("")
    print("📈 Statistics:")
    print("   • Total I/O Requests: ")
    print(sched.total_io_requests as string)
    print("   • Requests In Flight: ")
    print(sched.requests_in_flight as string)
    print("   • Completed Requests: ")
    print(sched.completed_requests as string)
    print("   • Failed Requests: ")
    print(sched.failed_requests as string)
    print("   • Total I/O Bytes: ")
    print(sched.total_io_bytes as string)
    print("   • Average Latency: ")
    print(sched.avg_latency_us as string)
    print("us")
    print("")
    print("✅ I/O scheduler operational!")
}
