package neurx.mm.oom_killer

struct process_info {
    int pid
    string name
    int memory_bytes
    int priority
    bool is_system
}

struct oom_killer {
    int total_memory
    int available_memory
    int threshold_percent
    bool oom_kill_enabled
    int last_kill_time_ms
    []process_info processes
    []int kill_history
}

func new_oom_killer() oom_killer {
    oom_killer {
        total_memory: 0,
        available_memory: 0,
        threshold_percent: 85,
        oom_kill_enabled: true,
        last_kill_time_ms: 0,
        processes: []process_info{},
        kill_history: []int{}
    }
}

func (oom_killer* k) init(int total_mb) {
    k.total_memory = total_mb * 1024 * 1024
    k.available_memory = k.total_memory
    k.threshold_percent = 85
    k.oom_kill_enabled = true
    k.last_kill_time_ms = 0
}

func (oom_killer k) get_memory_pressure() int {
    used := k.total_memory - k.available_memory
    (used * 100) / k.total_memory
}

func (oom_killer k) should_trigger_oom() bool {
    if k.oom_kill_enabled {
        k.get_memory_pressure() >= k.threshold_percent
    } else {
        false
    }
}

func (oom_killer* k) free_memory(int bytes) {
    k.available_memory = k.available_memory + bytes
    if k.available_memory > k.total_memory {
        k.available_memory = k.total_memory
    }
}

func (oom_killer* k) allocate_memory(int bytes) bool {
    if k.available_memory >= bytes {
        k.available_memory = k.available_memory - bytes
        true
    } else {
        false
    }
}

func (oom_killer k) get_status() string {
    pressure := k.get_memory_pressure()
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
