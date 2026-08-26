package neurx.mm.oom_killer

struct process_info {
    pid: int
    name: string
    memory_bytes: int
    priority: int
    is_system: bool
}

struct oom_killer {
    total_memory: int
    available_memory: int
    threshold_percent: int
    oom_kill_enabled: bool
    processes: []process_info
    kill_history: []int
}

func new_oom_killer() oom_killer {
    oom_killer {
        total_memory: 0,
        available_memory: 0,
        threshold_percent: 85,
        oom_kill_enabled: true,
        processes: []process_info{},
        kill_history: []int{}
    }
}

func (oom_killer* k) init(total_mb: int) {
    k.total_memory = total_mb * 1024 * 1024
    k.available_memory = k.total_memory
    k.threshold_percent = 85
    k.oom_kill_enabled = true
}

func (oom_killer* k) register_process(pid: int, name: string, memory_bytes: int, priority: int, is_system: bool) {
    let proc = process_info {
        pid: pid,
        name: name,
        memory_bytes: memory_bytes,
        priority: priority,
        is_system: is_system
    }
}

func (oom_killer k) get_memory_pressure() int {
    let used = k.total_memory - k.available_memory
    (used * 100) / k.total_memory
}

func (oom_killer k) should_trigger_oom() bool {
    if k.oom_kill_enabled {
        k.get_memory_pressure() >= k.threshold_percent
    } else {
        false
    }
}

func (oom_killer* k) free_memory(bytes: int) {
    k.available_memory = k.available_memory + bytes
    if k.available_memory > k.total_memory {
        k.available_memory = k.total_memory
    }
}

func (oom_killer* k) allocate_memory(bytes: int) bool {
    if k.available_memory >= bytes {
        k.available_memory = k.available_memory - bytes
        true
    } else {
        false
    }
}

func (oom_killer k) get_status() string {
    let pressure = k.get_memory_pressure()
    if pressure > 95 {
        "Critical"
    } else if pressure > 85 {
        "High"
    } else if pressure > 70 {
        "Medium"
    } else {
        "Normal"
    }
}

func (oom_killer k) get_available_memory_mb() int {
    k.available_memory / (1024 * 1024)
}
