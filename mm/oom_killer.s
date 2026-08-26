package neurx.mm.oom_killer

struct process_info {
    int pid
    int memory_bytes
    int priority
}

struct oom_killer {
    int total_memory
    int available_memory
    process_info[] processes
}

func new_oom_killer() oom_killer {
    oom_killer {
        total_memory: 0,
        available_memory: 0,
        processes: []process_info{}
    }
}

func (k oom_killer*) init(total_mb int) {
    k.total_memory = total_mb * 1024 * 1024
    k.available_memory = k.total_memory
}

func (k oom_killer) get_memory_pressure() int {
    let used = k.total_memory - k.available_memory
    (used * 100) / k.total_memory
}

func (k oom_killer) should_trigger_oom() bool {
    k.get_memory_pressure() >= 85
}

func (k oom_killer*) free_memory(bytes int) {
    k.available_memory = k.available_memory + bytes
}

func (k oom_killer*) allocate_memory(bytes int) bool {
    if k.available_memory >= bytes {
        k.available_memory = k.available_memory - bytes
        true
    } else {
        false
    }
}
